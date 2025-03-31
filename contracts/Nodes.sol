// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Nodes.sol - playa-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   playa-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   playa-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with playa-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.24;
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ICommittee } from "@skalenetwork/playa-manager-interfaces/contracts/ICommittee.sol";
import {
    INodes,
    NodeId
} from "@skalenetwork/playa-manager-interfaces/contracts/INodes.sol";


contract Nodes is AccessManagedUpgradeable, INodes {

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    bytes4 public constant ZERO_IPV4 = bytes4(0);
    bytes16 public constant ZERO_IPV6 = bytes16(0);

    // Mapping from node ID to Node struct
    mapping(NodeId nodeId => Node node) public nodes;

    // Stores requests to change address before committing changes
    mapping(NodeId nodeId => address nodeAddress) public addressChangeRequests;

    ICommittee public committeeContract;

    //Maps addresses to NodeIds
    EnumerableMap.AddressToUintMap private _activeNodesAddressToId;

    //Maps addresses to NodeIds
    mapping(address nodeAddress => EnumerableSet.UintSet nodeIds) private _passiveNodeIdByAddress;
    // Set to track passive node addresses
    EnumerableSet.AddressSet private _passiveNodeAddresses;

    // Set to track IPs taken
    EnumerableSet.Bytes32Set private _usedIps;

    // Set to track domain Names taken
    EnumerableSet.Bytes32Set private _usedDomainNames;

    /// For node Id generation
    uint256 private _nodeIdCounter;

    // Set to track passive node IDs
    EnumerableSet.UintSet private _passiveNodeIds;

    // Set to track active node IDs
    EnumerableSet.UintSet private _activeNodeIds;




    error NodeAlreadyExists(NodeId nodeId);
    error NodeIsInCommittee(NodeId nodeId);
    error AddressIsAlreadyAssignedToNode(address nodeAddress);
    error AddressIsNotAssignedToAnyNode(address nodeAddress);
    error PassiveNodeAlreadyExistsForAddress(address nodeAddress, NodeId nodeId);
    error AddressInUseByPassiveNodes(address nodeAddress);
    error InvalidPortNumber(uint16 port);
    error InvalidIp(bytes ip);
    error IpIsNotAvailable(bytes ip);
    error DomainNameAlreadyTaken(string domainName);

    modifier nodeNotInCommittee(NodeId nodeId){
        if (committeeContract.isNodeInCurrentOrNextCommittee(nodeId)) {
            revert NodeIsInCommittee(nodeId);
        }
        _;
    }

    modifier nodeExists(NodeId nodeId) {
        require(_isActiveNode(nodeId) || _isPassiveNode(nodeId), "Node must exist.");
        _;
    }
    modifier validIp(bytes calldata ip) {
        // Check if IPv4 or IPv6
        if (ip.length == 4) {
            if (bytes4(ip) == ZERO_IPV4){
                revert InvalidIp(ip);
            }
        } else if (ip.length == 16) {
            if (bytes16(ip) == ZERO_IPV6) {
                revert InvalidIp(ip);
            }
        } else {
            revert InvalidIp(ip);
        }
        _;
    }

    modifier validPort(uint16 port) {
        require(port > 0, "Port should not be 0.");
        _;
    }

    modifier onlyNodeOwner(NodeId nodeId){
        require(msg.sender == nodes[nodeId].nodeAddress, "Only Node Owner");
        _;
    }

    function initialize(address initialAuthority, ICommittee committeeAddress) public override initializer {
        __AccessManaged_init(initialAuthority);
        committeeContract = committeeAddress;
    }

    function registerNode(
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

        _addActiveNodeId(nodeId);

        _setActiveNodeIdForAddress(msg.sender, nodeId);

        if(!_usedIps.add(keccak256(ip))){
            revert IpIsNotAvailable(ip);
        }

        nodes[nodeId] = Node({
            id: nodeId,
            port: port,
            nodeAddress: msg.sender,
            ip: ip,
            domainName: ""
        });

        emit NodeRegistered(nodeId, msg.sender, ip, port);
    }


    function requestChangeAddress(
        NodeId nodeId,
        address newAddress
    )
        external
        override
        nodeExists(nodeId)
        onlyNodeOwner(nodeId)
    {
        if (_isPassiveNode(nodeId)) {
            if (_isAddressOfActiveNode(newAddress)) {
                revert AddressIsAlreadyAssignedToNode(newAddress);
            }
            addressChangeRequests[nodeId] = newAddress;
            return;
        }

        // Is active
        if (_isAddressOfPassiveNodes(newAddress)) {
            revert AddressInUseByPassiveNodes(newAddress);
        }
        if (_isAddressOfActiveNode(newAddress)) {
            revert AddressIsAlreadyAssignedToNode(newAddress);
        }
        addressChangeRequests[nodeId] = newAddress;

    }

    function confirmAddressChange(
        NodeId nodeId
    )
        external
        override
        nodeExists(nodeId)
        nodeNotInCommittee(nodeId)
    {
        address newOwner = addressChangeRequests[nodeId];

        require(newOwner != address(0), "Only valid addresses.");
        require(msg.sender == newOwner, "Only new owner.");

        address oldOwner = nodes[nodeId].nodeAddress;
        // Remove old address
        delete addressChangeRequests[nodeId];

        if (_isActiveNode(nodeId)) {
            assert(_activeNodesAddressToId.remove(oldOwner));

            // Register new address
            _setActiveNodeIdForAddress(newOwner, nodeId);
            nodes[nodeId].nodeAddress = newOwner;
        }
        if (_isPassiveNode(nodeId)) {

            // Register new address
            _setPassiveNodeIdForAddress(newOwner, nodeId);

            assert(_passiveNodeIdByAddress[oldOwner].remove(NodeId.unwrap(nodeId)));
            if (_passiveNodeIdByAddress[oldOwner].length() == 0) {
                assert(_passiveNodeAddresses.remove(oldOwner));
            }
            nodes[nodeId].nodeAddress = newOwner;
        }

        emit NodeAddressChanged(nodeId, oldOwner, newOwner);

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

        if(!_usedIps.add(keccak256(ip))){
            revert IpIsNotAvailable(ip);
        }

        nodes[nodeId] = Node({
            id: nodeId,
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
            nodeNotInCommittee(nodeId)
            validIp(ip)
            validPort(port)
        {
        Node storage node = nodes[nodeId];

        assert(_usedIps.remove(keccak256(node.ip)));
        if(!_usedIps.add(keccak256(ip))){
            revert IpIsNotAvailable(ip);
        }
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

        if(!_usedDomainNames.add(newName)){
            revert DomainNameAlreadyTaken(name);
        }
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
        if (!_isAddressOfActiveNode(nodeAddress)) {
            revert AddressIsNotAssignedToAnyNode(nodeAddress);
        }
        nodeId = NodeId.wrap(_activeNodesAddressToId.get(nodeAddress));
    }

    function getPassiveNodeIds(address nodeAddress) external view override returns (uint256[] memory nodeIds) {
        // Getter for passive nodes
        // Casting uint256[] to NodeId[] will come at a price if some other contract uses this function
        if (!_isAddressOfPassiveNodes(nodeAddress)) {
            revert AddressIsNotAssignedToAnyNode(nodeAddress);
        }
        nodeIds = _passiveNodeIdByAddress[nodeAddress].values();
    }

    function _addPassiveNodeId(NodeId nodeId) private {
        if(!_passiveNodeIds.add(NodeId.unwrap(nodeId))) {
            // Should be impossible to happen
            revert NodeAlreadyExists(nodeId);
        }
    }

    function _addActiveNodeId(NodeId nodeId) private {
        if(!_activeNodeIds.add(NodeId.unwrap(nodeId))) {
            // Should be impossible to happen
            revert NodeAlreadyExists(nodeId);
        }
    }

    function _setActiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        if (_isAddressOfPassiveNodes(nodeAddress)) {
            revert AddressInUseByPassiveNodes(nodeAddress);
        }
        if(!_activeNodesAddressToId.set(nodeAddress, NodeId.unwrap(nodeId))) {
            revert AddressIsAlreadyAssignedToNode(nodeAddress);
        }
    }

    function _setPassiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        if (_isAddressOfActiveNode(nodeAddress)) {
            revert AddressIsAlreadyAssignedToNode(nodeAddress);
        }
        bool result = _passiveNodeIdByAddress[nodeAddress].add(NodeId.unwrap(nodeId));
        if (!result) {
            revert PassiveNodeAlreadyExistsForAddress(nodeAddress, nodeId);
        }
        if (!_isAddressOfPassiveNodes(nodeAddress)) {
            assert(_passiveNodeAddresses.add(nodeAddress));

        }
    }

    function _isActiveNode(NodeId nodeId) private view returns (bool result) {
        result = _activeNodeIds.contains(NodeId.unwrap(nodeId));
    }

    function _isPassiveNode(NodeId nodeId) private view returns (bool result) {
        result = _passiveNodeIds.contains(NodeId.unwrap(nodeId));
    }

    function _isAddressOfPassiveNodes(address nodeAddress) private view returns (bool result) {
        result = _passiveNodeAddresses.contains(nodeAddress);
    }

    function _isAddressOfActiveNode(address nodeAddress) private view returns (bool result) {
        result = _activeNodesAddressToId.contains(nodeAddress);
    }

}
