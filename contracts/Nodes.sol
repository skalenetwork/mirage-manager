// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Nodes.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   fair-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   fair-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with fair-manager.  If not, see <https://www.gnu.org/licenses/>.
 */
pragma solidity ^0.8.24;

import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { ICommittee } from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import { INodes, NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { IStaking } from "@skalenetwork/fair-manager-interfaces/IStaking.sol";
import { IStatus } from "@skalenetwork/fair-manager-interfaces/IStatus.sol";

import { TypedMap } from "./structs/typed/TypedMap.sol";
import { TypedSet } from "./structs/typed/TypedSet.sol";

/**
 * @title Nodes
 * @notice Manages the registration, deletion, and status of nodes.
 */
contract Nodes is AccessManagedUpgradeable, INodes {

    using TypedSet for TypedSet.NodeIdSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using TypedMap for TypedMap.AddressToNodeIdMap;
    using TypedMap for TypedMap.AddressToNodeIdSetMap;

    struct NodeInfo {
        bytes32[2] publicKey;
    }

    /// @notice A zero-value IPv4 address.
    bytes4 public constant ZERO_IPV4 = bytes4(0);
    /// @notice A zero-value IPv6 address.
    bytes16 public constant ZERO_IPV6 = bytes16(0);

    /// @notice Mapping from node ID to Node data.
    mapping(NodeId nodeId => Node node) public nodes;

    /// @notice Mapping from node ID to a pending new owner address.
    mapping(NodeId nodeId => address newNodeOwner) public ownerChangeRequests;

    /// @notice The Committee contract instance.
    ICommittee public committeeContract;

    // Mapping from node ID to publicKey - only for active nodes, including deleted
    mapping(NodeId nodeId => NodeInfo nodeInfo) private _nodesInfo;

    //Maps addresses to NodeIds, includes deleted
    TypedMap.AddressToNodeIdMap private _activeNodesAddressToId;

    //Maps addresses to NodeIds
    TypedMap.AddressToNodeIdSetMap private _passiveNodeIdByAddress;
    // Set to track passive node addresses
    EnumerableSet.AddressSet private _passiveNodeAddresses;

    /// For node Id generation
    uint256 private _nodeIdCounter;

    // Set to track passive node IDs
    TypedSet.NodeIdSet private _passiveNodeIds;

    // Set to track active node IDs
    TypedSet.NodeIdSet private _activeNodeIds;

    error NodeIsInCommittee(NodeId nodeId);
    error AddressWasAlreadyAssignedToNode(address nodeAddress);
    error AddressIsNotAssignedToAnyNode(address nodeAddress);
    error PassiveNodeAlreadyExistsForAddress(address nodeAddress, NodeId nodeId);
    error AddressInUseByPassiveNodes(address nodeAddress);
    error InvalidPortNumber(uint16 port);
    error InvalidPublicKey(bytes32[2] publicKey);
    error InvalidPublicKeyForSender(bytes32[2] publicKey, address expected, address sender);
    error ActiveNodesCannotChangeOwnership();
    error InvalidIp(bytes ip);
    error NodeDoesNotExist(NodeId nodeId);
    error ActiveNodeWasNeverRegistered(NodeId nodeId);
    error PortShouldNotBeZero();
    error SenderIsNotNodeOwner();
    error SenderIsNotNewNodeOwner();
    error InvalidNodeId(NodeId nodeId, uint256 nodeIdCounter);

    modifier nodeNotInCurrentOrNextCommittee(NodeId nodeId) {
        require(!committeeContract.isNodeInCurrentOrNextCommittee(nodeId), NodeIsInCommittee(nodeId));
        _;
    }

    modifier nodeExists(NodeId nodeId) {
        require(_isActiveNode(nodeId) || _isPassiveNode(nodeId), NodeDoesNotExist(nodeId));
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

    modifier validPubKey(bytes32[2] memory publicKey) {
        require(publicKey[0] != bytes32(0) && publicKey[1] != bytes32(0), InvalidPublicKey(publicKey));
        _;
    }

    modifier onlyNodeOwner(NodeId nodeId) {
        require(msg.sender == nodes[nodeId].nodeAddress, SenderIsNotNodeOwner());
        _;
    }

    /**
     * @notice Initializes the Nodes contract.
     * @param initialAuthority The address of the initial authority.
     * @param initialNodes An array of initial nodes.
     * @param nodesPublicKeys An array of public keys for the initial nodes.
     */
    function initialize(
        address initialAuthority,
        Node[] calldata initialNodes,
        bytes32[2][] calldata nodesPublicKeys
    )
        external
        override
        initializer
    {
        __AccessManaged_init(initialAuthority);
        _initializeGroup(initialNodes, nodesPublicKeys);
    }

    /**
     * @notice Sets the Committee contract address.
     * @param committeeAddress The address of the Committee contract.
     */
    function setCommittee(ICommittee committeeAddress) external override restricted {
        committeeContract = committeeAddress;
    }

    /**
     * @notice Registers a new active node.
     * @param ip The IP address of the node.
     * @param publicKey The public key of the node.
     * @param port The port of the node.
     */
    function registerNode(
        bytes calldata ip,
        bytes32[2] calldata publicKey,
        uint16 port
    )
        external
        payable
        override
        validIp(ip)
        validPort(port)
        validPubKey(publicKey)
    {
        address nodeAddress = _publicKeyToAddress(publicKey);
        require(msg.sender == nodeAddress, InvalidPublicKeyForSender(publicKey, nodeAddress, msg.sender));
        NodeId nextNodeId = NodeId.wrap(_nodeIdCounter + 1);
        _createActiveNode({
            nodeId: nextNodeId,
            nodeAddress: msg.sender,
            ip: ip,
            port: port,
            domainName: "",
            publicKey: publicKey
        });
        // Node is first disabled by default.
        // It should send a heartbeat before being considered eligible
        committeeContract.staking().nodeCreated{ value: msg.value }(nextNodeId, msg.sender);
    }

    /**
     * @notice Deletes a node.
     * @param nodeId The ID of the node to delete.
     */
    function deleteNode(NodeId nodeId) external override nodeExists(nodeId) onlyNodeOwner(nodeId) {
        _deleteNode(nodeId);
    }

    /**
     * @notice Deletes a node by the foundation.
     * @param nodeId The ID of the node to delete.
     */
    function deleteNodeByFoundation(NodeId nodeId) external override nodeExists(nodeId) restricted {
        _deleteNode(nodeId);
    }

    /**
     * @notice Requests to change the owner of a passive node.
     * @param nodeId The ID of the node.
     * @param newOwner The address of the new owner.
     */
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
        require(!_isAddressOfActiveNode(newOwner), AddressWasAlreadyAssignedToNode(newOwner));
        emit NodeOwnerChangeRequested(nodeId, msg.sender, newOwner);
        ownerChangeRequests[nodeId] = newOwner;
    }

    /**
     * @notice Confirms the change of ownership of a passive node.
     * @param nodeId The ID of the node.
     */
    function confirmOwnerChange(NodeId nodeId) external override nodeExists(nodeId) {
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

    /**
     * @notice Registers a new passive node.
     * @param ip The IP address of the node.
     * @param port The port of the node.
     */
    function registerPassiveNode(bytes calldata ip, uint16 port) external override validIp(ip) validPort(port) {
        unchecked {
            ++_nodeIdCounter;
        }

        NodeId nodeId = NodeId.wrap(_nodeIdCounter);

        _addPassiveNodeId(nodeId);

        _setPassiveNodeIdForAddress(msg.sender, nodeId);

        nodes[nodeId] = Node({ id: nodeId, port: port, nodeAddress: msg.sender, ip: ip, domainName: "" });

        emit NodeRegistered(nodeId, msg.sender, ip, port);
    }

    /**
     * @notice Sets the IP address of a node.
     * @param nodeId The ID of the node.
     * @param ip The new IP address.
     * @param port The new port.
     */
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
        node.ip = ip;
        node.port = port;
        emit NodeIpChanged(nodeId, msg.sender, ip, port);
    }

    /**
     * @notice Sets the domain name of a node.
     * @param nodeId The ID of the node.
     * @param name The new domain name.
     */
    function setDomainName(
        NodeId nodeId,
        string calldata name
    )
        external
        override
        nodeExists(nodeId)
        onlyNodeOwner(nodeId)
        nodeNotInCurrentOrNextCommittee(nodeId)
    {
        Node storage node = nodes[nodeId];
        node.domainName = name;
        emit NodeDomainNameChanged(nodeId, msg.sender, name);
    }

    /**
     * @notice Retrieves the details of a node.
     * @param nodeId The ID of the node.
     * @return node The node details.
     */
    function getNode(NodeId nodeId) external view override nodeExists(nodeId) returns (Node memory node) {
        return nodes[nodeId];
    }

    /**
     * @notice Retrieves the ID of a node by its address.
     * @param nodeAddress The address of the node.
     * @return nodeId The ID of the node.
     */
    function getNodeId(address nodeAddress) external view override returns (NodeId nodeId) {
        require(_isAddressOfActiveNode(nodeAddress), AddressIsNotAssignedToAnyNode(nodeAddress));
        nodeId = _activeNodesAddressToId.get(nodeAddress);
    }

    /**
     * @notice Retrieves the passive node IDs for a given address.
     * @param nodeAddress The address to query.
     * @return nodeIds An array of passive node IDs.
     */
    function getPassiveNodeIdsForAddress(address nodeAddress)
        external
        view
        override
        returns (NodeId[] memory nodeIds)
    {
        require(_isAddressOfPassiveNodes(nodeAddress), AddressIsNotAssignedToAnyNode(nodeAddress));
        nodeIds = _passiveNodeIdByAddress.getValuesAt(nodeAddress);
    }

    /**
     * @notice Retrieves all passive node IDs.
     * @return nodeIds An array of all passive node IDs.
     */
    function getPassiveNodeIds() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _passiveNodeIds.values();
    }

    /**
     * @notice Retrieves the public key of a node.
     * @param nodeId The ID of the node.
     * @return publicKey The public key of the node.
     */
    function getPublicKey(NodeId nodeId) external view override returns (bytes32[2] memory publicKey) {
        publicKey = _nodesInfo[nodeId].publicKey;
        require(publicKey[0] != bytes32(0) && publicKey[1] != bytes32(0), ActiveNodeWasNeverRegistered(nodeId));
    }

    /**
     * @notice Retrieves all active node IDs.
     * @return nodeIds An array of all active node IDs.
     */
    function getActiveNodeIds() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _activeNodeIds.values();
    }

    /**
     * @notice Checks if an active node exists.
     * @param nodeId The ID of the node.
     * @return result True if the active node exists, false otherwise.
     */
    function activeNodeExists(NodeId nodeId) external view override returns (bool result) {
        result = _isActiveNode(nodeId);
    }

    /**
     * @notice Checks if a passive node exists.
     * @param nodeId The ID of the node.
     * @return result True if the passive node exists, false otherwise.
     */
    function passiveNodeExists(NodeId nodeId) external view override returns (bool result) {
        result = _isPassiveNode(nodeId);
    }

    /**
     * @notice Creates a new active node.
     * @param nodeId The ID of the new node.
     * @param nodeAddress The address of the new node.
     * @param ip The IP address of the new node.
     * @param port The port of the new node.
     * @param domainName The domain name of the new node.
     * @param publicKey The public key of the new node.
     */
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

        _nodeIdCounter = NodeId.unwrap(nodeId);
        _addActiveNodeId(nodeId);
        _setActiveNodeIdForAddress(nodeAddress, nodeId);

        nodes[nodeId] = Node({ id: nodeId, port: port, nodeAddress: nodeAddress, ip: ip, domainName: domainName });

        _nodesInfo[nodeId] = NodeInfo({ publicKey: publicKey });

        emit NodeRegistered(nodeId, nodeAddress, ip, port);
    }

    /**
     * @notice Deletes a node.
     * @param id The ID of the node to delete.
     */
    function _deleteNode(NodeId id) private nodeNotInCurrentOrNextCommittee(id) {
        Node storage node = nodes[id];
        address nodeOwner = node.nodeAddress;
        bytes memory ip = node.ip;
        uint16 port = node.port;
        delete nodes[id];

        IStatus statusContract = IStatus(committeeContract.status());
        bool isActive = _isActiveNode(id);
        IStaking stakingContract = IStaking(committeeContract.staking());

        if (isActive) {
            emit ActiveNodeDeleted(id, nodeOwner, ip, port);
            // flush before removal or rewards are split
            stakingContract.getRewardWallet(id).flush();

            assert(_activeNodeIds.remove(id));
            assert(_activeNodesAddressToId.remove(nodeOwner));
            committeeContract.nodeRemoved(id);
        } else {
            assert(_passiveNodeIds.remove(id));

            assert(_passiveNodeIdByAddress.remove(nodeOwner, id));
            if (_passiveNodeIdByAddress.lengthOf(nodeOwner) == 0) {
                assert(_passiveNodeAddresses.remove(nodeOwner));
            }
            delete ownerChangeRequests[id];
            emit PassiveNodeDeleted(id, nodeOwner, ip, port);
        }

        statusContract.nodeRemoved(id);
        // may send tokens, should be the very last
        if (isActive) {
            stakingContract.nodeRemoved(id);
        }
    }

    /**
     * @notice Adds a passive node ID to the set of passive node IDs.
     * @param nodeId The ID of the passive node to add.
     */
    function _addPassiveNodeId(NodeId nodeId) private {
        assert(_passiveNodeIds.add(nodeId));
    }

    /**
     * @notice Adds an active node ID to the set of active node IDs.
     * @param nodeId The ID of the active node to add.
     */
    function _addActiveNodeId(NodeId nodeId) private {
        assert(_activeNodeIds.add(nodeId));
    }

    /**
     * @notice Sets the active node ID for a given address.
     * @param nodeAddress The address to set the node ID for.
     * @param nodeId The node ID to set.
     */
    function _setActiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        require(!_isAddressOfPassiveNodes(nodeAddress), AddressInUseByPassiveNodes(nodeAddress));
        require(_activeNodesAddressToId.set(nodeAddress, nodeId), AddressWasAlreadyAssignedToNode(nodeAddress));
    }

    /**
     * @notice Sets the passive node ID for a given address.
     * @param nodeAddress The address to set the node ID for.
     * @param nodeId The node ID to set.
     */
    function _setPassiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        require(!_isAddressOfActiveNode(nodeAddress), AddressWasAlreadyAssignedToNode(nodeAddress));

        require(
            _passiveNodeIdByAddress.add(nodeAddress, nodeId), PassiveNodeAlreadyExistsForAddress(nodeAddress, nodeId)
        );

        if (!_isAddressOfPassiveNodes(nodeAddress)) {
            assert(_passiveNodeAddresses.add(nodeAddress));
        }
    }

    /**
     * @notice Initializes a group of nodes.
     * @param initialNodes An array of initial nodes.
     * @param publicKeys An array of public keys for the initial nodes.
     */
    function _initializeGroup(Node[] calldata initialNodes, bytes32[2][] calldata publicKeys) private {
        uint256 length = initialNodes.length;
        for (uint256 i; i < length; ++i) {
            Node calldata initNode = initialNodes[i];
            _createActiveNode({
                nodeId: initNode.id,
                nodeAddress: initNode.nodeAddress,
                ip: initNode.ip,
                port: initNode.port,
                domainName: initNode.domainName,
                publicKey: publicKeys[i]
            });
        }
    }

    /**
     * @notice Checks if a node is an active node.
     * @param nodeId The ID of the node to check.
     * @return result True if the node is an active node, false otherwise.
     */
    function _isActiveNode(NodeId nodeId) private view returns (bool result) {
        result = _activeNodeIds.contains(nodeId);
    }

    /**
     * @notice Checks if a node is a passive node.
     * @param nodeId The ID of the node to check.
     * @return result True if the node is a passive node, false otherwise.
     */
    function _isPassiveNode(NodeId nodeId) private view returns (bool result) {
        result = _passiveNodeIds.contains(nodeId);
    }

    /**
     * @notice Checks if an address is associated with any passive nodes.
     * @param nodeAddress The address to check.
     * @return result True if the address is associated with any passive nodes, false otherwise.
     */
    function _isAddressOfPassiveNodes(address nodeAddress) private view returns (bool result) {
        result = _passiveNodeAddresses.contains(nodeAddress);
    }

    /**
     * @notice Checks if an address is associated with an active node.
     * @param nodeAddress The address to check.
     * @return result True if the address is associated with an active node, false otherwise.
     */
    function _isAddressOfActiveNode(address nodeAddress) private view returns (bool result) {
        result = _activeNodesAddressToId.contains(nodeAddress);
    }

    /**
     * @notice Converts a public key to an address.
     * @param pubKey The public key to convert.
     * @return nodeAddress The address corresponding to the public key.
     */
    function _publicKeyToAddress(bytes32[2] memory pubKey) private pure returns (address nodeAddress) {
        bytes32 hash = keccak256(abi.encodePacked(pubKey[0], pubKey[1]));
        return address(uint160(uint256(hash)));
    }

}
