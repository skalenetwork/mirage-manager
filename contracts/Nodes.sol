// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Nodes.sol - mirage-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   mirage-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   mirage-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with mirage-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.24;
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ICommittee } from "@skalenetwork/professional-interfaces/ICommittee.sol";
import {
    INodes,
    NodeId
} from "@skalenetwork/professional-interfaces/INodes.sol";

import { TypedMap } from "./structs/typed/TypedMap.sol";
import { TypedSet } from "./structs/typed/TypedSet.sol";

contract Nodes is AccessManagedUpgradeable, INodes {

    using TypedSet for TypedSet.NodeIdSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using TypedMap for TypedMap.AddressToNodeIdMap;
    using TypedMap for TypedMap.AddressToNodeIdSetMap;

    bytes4 public constant ZERO_IPV4 = bytes4(0);
    bytes16 public constant ZERO_IPV6 = bytes16(0);

    // Mapping from node ID to Node struct
    mapping(NodeId nodeId => Node node) public nodes;

    // Stores requests to change owner before committing changes
    mapping(NodeId nodeId => address newNodeOwner) public ownerChangeRequests;

    ICommittee public committeeContract;

    //Maps addresses to NodeIds
    TypedMap.AddressToNodeIdMap private _activeNodesAddressToId;

    //Maps addresses to NodeIds
    TypedMap.AddressToNodeIdSetMap private _passiveNodeIdByAddress;
    // Set to track passive node addresses
    EnumerableSet.AddressSet private _passiveNodeAddresses;

    // Set to track IPs taken
    EnumerableSet.Bytes32Set private _usedIps;

    // Set to track domain Names taken
    EnumerableSet.Bytes32Set private _usedDomainNames;

    /// For node Id generation
    uint256 private _nodeIdCounter;

    // Set to track passive node IDs
    TypedSet.NodeIdSet private _passiveNodeIds;

    // Set to track active node IDs
    TypedSet.NodeIdSet private _activeNodeIds;

    error NodeIsInCommittee(NodeId nodeId);
    error AddressIsAlreadyAssignedToNode(address nodeAddress);
    error AddressIsNotAssignedToAnyNode(address nodeAddress);
    error PassiveNodeAlreadyExistsForAddress(address nodeAddress, NodeId nodeId);
    error AddressInUseByPassiveNodes(address nodeAddress);
    error InvalidPortNumber(uint16 port);
    error InvalidPublicKey(bytes32[2] publicKey);
    error InvalidPublicKeyForSender(bytes32[2] publicKey, address expected, address sender);
    error ActiveNodesCannotChangeOwnership();
    error InvalidIp(bytes ip);
    error IpIsNotAvailable(bytes ip);
    error DomainNameAlreadyTaken(string domainName);
    error NodeDoesNotExist(NodeId nodeId);
    error PortShouldNotBeZero();
    error SenderIsNotNodeOwner();
    error SenderIsNotNewNodeOwner();
    error InvalidNodeId(NodeId nodeId, uint256 nodeIdCounter);

    modifier nodeNotInCurrentOrNextCommittee(NodeId nodeId){
        require(
            !committeeContract.isNodeInCurrentOrNextCommittee(nodeId),
            NodeIsInCommittee(nodeId)
        );
        _;
    }

    modifier nodeExists(NodeId nodeId) {
        require(
            _isActiveNode(nodeId) || _isPassiveNode(nodeId),
            NodeDoesNotExist(nodeId)
        );
        _;
    }

    modifier validIp(bytes calldata ip) {
        // Check if IPv4 or IPv6
        if (ip.length == 4) {
            require(bytes4(ip) != ZERO_IPV4, InvalidIp(ip));
        } else if (ip.length == 16) {
            require(bytes16(ip) != ZERO_IPV6, InvalidIp(ip));
        } else {
            revert InvalidIp(ip);
        }
        _;
    }

    modifier validPort(uint16 port) {
        require(port > 0, PortShouldNotBeZero());
        _;
    }

    modifier validPubKey(bytes32[2] memory publicKey){
        require(publicKey[0] != bytes32(0) && publicKey[1] != bytes32(0), InvalidPublicKey(publicKey));
        _;
    }

    modifier onlyNodeOwner(NodeId nodeId){
        require(msg.sender == nodes[nodeId].nodeAddress, SenderIsNotNodeOwner());
        _;
    }

    function initialize(address initialAuthority, Node[] calldata initialNodes) public override initializer {
        __AccessManaged_init(initialAuthority);
        _initializeGroup(initialNodes);
    }

    function setCommittee(ICommittee committeeAddress) external override restricted {
        committeeContract = committeeAddress;
    }

    function registerNode(
        bytes calldata ip,
        bytes32[2] calldata publicKey,
        uint16 port
    )
        external
        override
        validIp(ip)
        validPort(port)
        validPubKey(publicKey)
    {
        address nodeAddress = _publicKeyToAddress(publicKey);
        require(
            msg.sender == nodeAddress,
            InvalidPublicKeyForSender(publicKey, nodeAddress, msg.sender)
        );
        NodeId nextNodeId = NodeId.wrap(_nodeIdCounter + 1);
        _createActiveNode({
            nodeId: nextNodeId,
            nodeAddress: msg.sender,
            ip: ip,
            port: port,
            domainName: "",
            publicKey: publicKey
        });
        committeeContract.nodeCreated(nextNodeId);
    }

    function requestChangeOwner(
        NodeId nodeId,
        address newOwner
    )
        external
        override
        nodeExists(nodeId)
        onlyNodeOwner(nodeId)
    {
        require(_isPassiveNode(nodeId), ActiveNodesCannotChangeOwnership());
        require(
            !_isAddressOfActiveNode(newOwner),
            AddressIsAlreadyAssignedToNode(newOwner)
        );

        ownerChangeRequests[nodeId] = newOwner;
    }

    function confirmOwnerChange(
        NodeId nodeId
    )
        external
        override
        nodeExists(nodeId)
    {
        require(_isPassiveNode(nodeId), ActiveNodesCannotChangeOwnership());
        address newOwner = ownerChangeRequests[nodeId];

        require(msg.sender == newOwner, SenderIsNotNewNodeOwner());

        address oldOwner = nodes[nodeId].nodeAddress;

        // Register new address
        _setPassiveNodeIdForAddress(newOwner, nodeId);

        assert(_passiveNodeIdByAddress.remove(oldOwner, nodeId));
        if (_passiveNodeIdByAddress.lengthOf(oldOwner) == 0) {
            assert(_passiveNodeAddresses.remove(oldOwner));
        }

        nodes[nodeId].nodeAddress = newOwner;
        delete ownerChangeRequests[nodeId];

        emit NodeOwnerChanged(nodeId, oldOwner, newOwner);
    }

    function registerPassiveNode(
        bytes calldata ip,
        uint16 port
    )
        external
        override
        validIp(ip)
        validPort(port)
    {
        unchecked {
            ++_nodeIdCounter;
        }

        NodeId nodeId = NodeId.wrap(_nodeIdCounter);

        _addPassiveNodeId(nodeId);

        _setPassiveNodeIdForAddress(msg.sender, nodeId);

        require(_usedIps.add(keccak256(ip)), IpIsNotAvailable(ip));

        nodes[nodeId] = Node({
            id: nodeId,
            publicKey: [bytes32(0),bytes32(0)],
            port: port,
            nodeAddress: msg.sender,
            ip: ip,
            domainName: ""
        });

        emit NodeRegistered(nodeId, msg.sender, ip, port);
    }

    function setIpAddress(
        NodeId nodeId,
        bytes calldata ip,
        uint16 port
        )
            external
            override
            nodeExists(nodeId)
            onlyNodeOwner(nodeId)
            nodeNotInCurrentOrNextCommittee(nodeId)
            validIp(ip)
            validPort(port)
        {
        Node storage node = nodes[nodeId];

        assert(_usedIps.remove(keccak256(node.ip)));
        require(_usedIps.add(keccak256(ip)), IpIsNotAvailable(ip));
        node.ip = ip;
        node.port = port;
        emit NodeIpChanged(nodeId, msg.sender, ip, port);

    }

    function setDomainName(NodeId nodeId, string calldata name)
        external
        override
        nodeExists(nodeId)
        onlyNodeOwner(nodeId)
    {
        Node storage node = nodes[nodeId];

        bytes32 newName = keccak256(abi.encodePacked(name));

        bytes32 oldName = keccak256(abi.encodePacked(node.domainName));
        if (oldName != keccak256("")) {
            assert(_usedDomainNames.remove(oldName));
        }

        require(_usedDomainNames.add(newName), DomainNameAlreadyTaken(name));

        node.domainName = name;

        emit NodeDomainNameChanged(nodeId, msg.sender, name);
    }

    function getNode(NodeId nodeId)
        external
        view
        override
        nodeExists(nodeId)
        returns (Node memory node)
    {
        return nodes[nodeId];
    }

    function getNodeId(address nodeAddress) external view override returns (NodeId nodeId) {
        // Getter for active node
        require(
            _isAddressOfActiveNode(nodeAddress),
            AddressIsNotAssignedToAnyNode(nodeAddress)
        );

        nodeId = _activeNodesAddressToId.get(nodeAddress);
    }

    function getPassiveNodeIdsForAddress(
        address nodeAddress
    )
        external
        view
        override
        returns (NodeId[] memory nodeIds)
    {
        require(
            _isAddressOfPassiveNodes(nodeAddress),
            AddressIsNotAssignedToAnyNode(nodeAddress)
        );
        nodeIds = _passiveNodeIdByAddress.getValuesAt(nodeAddress);
    }

    function getPassiveNodeIds() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _passiveNodeIds.values();
    }

    function getActiveNodeIds() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _activeNodeIds.values();
    }

    function activeNodeExists(NodeId nodeId) external view override returns(bool result){
        result = _isActiveNode(nodeId);
    }

    function _createActiveNode(
        NodeId nodeId,
        address nodeAddress,
        bytes calldata ip,
        uint16 port,
        string memory domainName,
        bytes32[2] memory publicKey
    )
        internal
    {
        require(NodeId.unwrap(nodeId) > _nodeIdCounter, InvalidNodeId(nodeId, _nodeIdCounter));
        require(_usedIps.add(keccak256(ip)), IpIsNotAvailable(ip));

        _nodeIdCounter = NodeId.unwrap(nodeId);
        _addActiveNodeId(nodeId);
        _setActiveNodeIdForAddress(nodeAddress, nodeId);

        nodes[nodeId] = Node({
            id: nodeId,
            publicKey: publicKey,
            port: port,
            nodeAddress: nodeAddress,
            ip: ip,
            domainName: domainName
        });

        emit NodeRegistered(nodeId, nodeAddress, ip, port);
    }

    function _addPassiveNodeId(NodeId nodeId) private {
        assert(_passiveNodeIds.add(nodeId));
    }

    function _addActiveNodeId(NodeId nodeId) private {
        assert(_activeNodeIds.add(nodeId));
    }

    function _setActiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        require(
            !_isAddressOfPassiveNodes(nodeAddress),
            AddressInUseByPassiveNodes(nodeAddress)
        );
        require(
            _activeNodesAddressToId.set(nodeAddress, nodeId),
            AddressIsAlreadyAssignedToNode(nodeAddress)
        );
    }

    function _setPassiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        require(
            !_isAddressOfActiveNode(nodeAddress),
            AddressIsAlreadyAssignedToNode(nodeAddress)
        );

        require(
            _passiveNodeIdByAddress.add(nodeAddress, nodeId),
            PassiveNodeAlreadyExistsForAddress(nodeAddress, nodeId)
        );

        if (!_isAddressOfPassiveNodes(nodeAddress)) {
            assert(_passiveNodeAddresses.add(nodeAddress));
        }
    }

    function _initializeGroup(Node[] calldata initialNodes) private {
        uint256 length = initialNodes.length;
        for (uint256 i; i < length; ++i) {
            Node calldata initNode = initialNodes[i];
            _createActiveNode({
                nodeId: initNode.id,
                nodeAddress: initNode.nodeAddress,
                ip: initNode.ip,
                port: initNode.port,
                domainName: initNode.domainName,
                publicKey: initNode.publicKey
            });
        }
    }

    function _isActiveNode(NodeId nodeId) private view returns (bool result) {
        result = _activeNodeIds.contains(nodeId);
    }

    function _isPassiveNode(NodeId nodeId) private view returns (bool result) {
        result = _passiveNodeIds.contains(nodeId);
    }

    function _isAddressOfPassiveNodes(address nodeAddress) private view returns (bool result) {
        result = _passiveNodeAddresses.contains(nodeAddress);
    }

    function _isAddressOfActiveNode(address nodeAddress) private view returns (bool result) {
        result = _activeNodesAddressToId.contains(nodeAddress);
    }

    function _publicKeyToAddress(
        bytes32[2] memory pubKey
    )
        private
        pure
        returns (address nodeAddress)
    {
        bytes32 hash = keccak256(abi.encodePacked(pubKey[0], pubKey[1]));
        return address(uint160(uint256(hash)));
    }
}
