// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Nodes.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *
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
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { ICommittee } from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import {
    INodes,
    NodeId
} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { IStaking } from "@skalenetwork/fair-manager-interfaces/IStaking.sol";
import { IStatus } from "@skalenetwork/fair-manager-interfaces/IStatus.sol";
import { TypedMap } from "./structs/typed/TypedMap.sol";
import { TypedSet } from "./structs/typed/TypedSet.sol";
import { AddressIsZero, NodeDoesNotExist } from "./utils/errors.sol";

/**
 * @title Nodes
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 *
 * @notice Manages node registration, configuration, and lifecycle in the FAIR network
 * @dev Handles both active nodes (participate in consensus) and passive nodes (indexers, archival, etc.)
 */
contract Nodes is AccessManagedUpgradeable, INodes {

    using TypedSet for TypedSet.NodeIdSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using TypedMap for TypedMap.AddressToNodeIdMap;
    using TypedMap for TypedMap.AddressToNodeIdSetMap;

    /// @notice Helper structure to store additional node information
    struct NodeInfo {
        bytes32[2] publicKey;
    }

    /// @notice Zero IPv4 address constant used for validation
    bytes4 public constant ZERO_IPV4 = bytes4(0);

    /// @notice Zero IPv6 address constant used for validation
    bytes16 public constant ZERO_IPV6 = bytes16(0);

    /// @notice Mapping from node ID to Node struct
    mapping(NodeId nodeId => Node node) public nodes;

    /// @notice Stores pending requests to change node ownership
    mapping(NodeId nodeId => address newNodeOwner) public ownerChangeRequests;

    /// @notice Reference to the Committee contract
    ICommittee public committeeContract;

    /// @dev Mapping from node ID to public key information for active nodes (including deleted)
    mapping(NodeId nodeId => NodeInfo nodeInfo) private _nodesInfo;

    /// @dev Maps addresses to NodeIds for active nodes
    TypedMap.AddressToNodeIdMap private _activeNodesAddressToId;

    /// @dev Maps addresses to sets of passive NodeIds
    TypedMap.AddressToNodeIdSetMap private _passiveNodeIdByAddress;

    /// @dev Set to track passive node addresses
    EnumerableSet.AddressSet private _passiveNodeAddresses;

    /// @dev Counter for generating unique node IDs
    uint256 private _nodeIdCounter;

    /// @dev Set to track passive node IDs
    TypedSet.NodeIdSet private _passiveNodeIds;

    /// @dev Set to track active node IDs
    TypedSet.NodeIdSet private _activeNodeIds;

    /**
     * @notice Emitted when the Committee contract reference is updated
     * @param newCommittee The new Committee contract address
     */
    event CommitteeUpdated(ICommittee newCommittee);

    /**
     * @notice Thrown when attempting to modify a node that is in the committee
     * @param nodeId The ID of the node in the committee
     */
    error NodeIsInCommittee(NodeId nodeId);

    /**
     * @notice Thrown when an address is already assigned to a node
     * @param nodeAddress The address that is already assigned
     */
    error AddressWasAlreadyAssignedToNode(address nodeAddress);

    /**
     * @notice Thrown when an address is not assigned to any node
     * @param nodeAddress The address that is not assigned
     */
    error AddressIsNotAssignedToAnyNode(address nodeAddress);

    /**
     * @notice Thrown when a passive node already exists for an address
     * @param nodeAddress The address with an existing passive node
     * @param nodeId The ID of the existing passive node
     */
    error PassiveNodeAlreadyExistsForAddress(address nodeAddress, NodeId nodeId);

    /**
     * @notice Thrown when an address is in use by passive nodes
     * @param nodeAddress The address in use
     */
    error AddressInUseByPassiveNodes(address nodeAddress);

    /**
     * @notice Thrown when an invalid public key is provided
     * @param publicKey The invalid public key
     */
    error InvalidPublicKey(bytes32[2] publicKey);

    /**
     * @notice Thrown when the public key doesn't match the sender
     * @param publicKey The provided public key
     * @param expected The expected address derived from the public key
     * @param sender The actual sender address
     */
    error InvalidPublicKeyForSender(bytes32[2] publicKey, address expected, address sender);

    /// @notice Thrown when attempting to change ownership of an active node
    error ActiveNodesCannotChangeOwnership();

    /**
     * @notice Thrown when an invalid IP address is provided
     * @param ip The invalid IP address
     */
    error InvalidIp(bytes ip);

    /**
     * @notice Thrown when requesting public key for a node that was never registered as active
     * @param nodeId The ID of the node
     */
    error ActiveNodeWasNeverRegistered(NodeId nodeId);

    /// @notice Thrown when port is set to zero
    error PortShouldNotBeZero();

    /// @notice Thrown when sender is not the node owner
    error SenderIsNotNodeOwner();

    /// @notice Thrown when sender is not the new node owner in ownership transfer
    error SenderIsNotNewNodeOwner();

    /**
     * @notice Thrown when an invalid node ID is provided
     * @param nodeId The invalid node ID
     * @param nodeIdCounter The current node ID counter
     */
    error InvalidNodeId(NodeId nodeId, uint256 nodeIdCounter);

    /**
     * @dev Ensures that the node is not in the current or next committee
     * @param nodeId The node ID to check
     */
    modifier nodeNotInCurrentOrNextCommittee(NodeId nodeId){
        require(
            !committeeContract.isNodeInCurrentOrNextCommittee(nodeId),
            NodeIsInCommittee(nodeId)
        );
        _;
    }

    /**
     * @dev Ensures that the node exists (either active or passive)
     * @param nodeId The node ID to check
     */
    modifier nodeExists(NodeId nodeId) {
        require(
            _isActiveNode(nodeId) || _isPassiveNode(nodeId),
            NodeDoesNotExist(nodeId)
        );
        _;
    }

    /**
     * @dev Checks if a provided IP address is valid IPv4 or IPv6
     * @param ip The IP address to validate
     */
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

    /**
     * @dev Validates that a port number is not zero
     * @param port The port to validate
     */
    modifier validPort(uint16 port) {
        require(port > 0, PortShouldNotBeZero());
        _;
    }

    /**
     * @dev Validates that the public key is not zero
     * @param publicKey The public key to validate
     */
    modifier validPubKey(bytes32[2] memory publicKey){
        require(publicKey[0] != bytes32(0) && publicKey[1] != bytes32(0), InvalidPublicKey(publicKey));
        _;
    }

    /**
     * @dev Ensures that the caller is the owner of the specified node
     * @param nodeId The node ID to check ownership for
     */
    modifier onlyNodeOwner(NodeId nodeId){
        require(msg.sender == nodes[nodeId].nodeAddress, SenderIsNotNodeOwner());
        _;
    }

    /**
     * @notice Initializes the Nodes contract
     * @dev This function is called only once during contract deployment following the proxy pattern
     * @param initialAuthority The address of the initial access control authority
     * @param initialNodes Array of initial nodes to register
     * @param nodesPublicKeys Array of public keys corresponding to initial nodes
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
     * @notice Sets the Committee contract address
     * @dev Only callable by authorized addresses (restricted)
     * @param committeeAddress The address of the Committee contract
     */
    function setCommittee(ICommittee committeeAddress) external override restricted {
        require(address(committeeAddress) != address(0), AddressIsZero());
        committeeContract = committeeAddress;
        emit CommitteeUpdated(committeeAddress);
    }

    /**
     * @notice Registers a new active node
     * @dev Validates IP, port, and public key, then creates the node as disabled (in staking) by default
     * @dev The sender must match the address derived from the public key
     * @dev Can include initial stake via msg.value (should be not less than minimum required)
     * @param ip The IP address of the node (IPv4 or IPv6)
     * @param publicKey The node's public key
     * @param port The port number the node listens on
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
        // Node is first disabled by default.
        // It should send a heartbeat before being considered eligible
        committeeContract.staking().nodeCreated{value: msg.value}(nextNodeId, msg.sender);
    }

    /**
     * @notice Deletes a node owned by the caller
     * @dev Only callable by the node owner
     * @dev Node must not be in current or next committee
     * @param nodeId The ID of the node to delete
     */
    function deleteNode(
        NodeId nodeId
    )
        external
        override
        nodeExists(nodeId)
        onlyNodeOwner(nodeId)
    {
        _deleteNode(nodeId);
    }

    /**
     * @notice Deletes a node — restricted to the foundation
     * @dev Node must not be in the current or next committee
     * @param nodeId The ID of the node to delete
     */
    function deleteNodeByFoundation(NodeId nodeId) external override nodeExists(nodeId) restricted {
        _deleteNode(nodeId);
    }

    /**
     * @notice Requests to change the owner of a passive node
     * @dev Only callable by the current node owner
     * @dev Only works for passive nodes (active nodes cannot change ownership)
     * @dev New owner must not already own an active node
     * @param nodeId The ID of the node
     * @param newOwner The address of the new owner
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
        require(
            !_isAddressOfActiveNode(newOwner),
            AddressWasAlreadyAssignedToNode(newOwner)
        );
        emit NodeOwnerChangeRequested(nodeId, msg.sender, newOwner);
        ownerChangeRequests[nodeId] = newOwner;
    }

    /**
     * @notice Confirms a pending ownership change for a passive node
     * @dev Only callable by the new owner specified in the ownership change request
     * @dev Only works for passive nodes
     * @param nodeId The ID of the node
     */
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

    /**
     * @notice Registers a new passive node
     * @dev Passive nodes don't participate in consensus
     * @dev Multiple passive nodes can be registered per address
     * @param ip The IP address of the node (IPv4 or IPv6)
     * @param port The port number the node listens on
     */
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

        nodes[nodeId] = Node({
            id: nodeId,
            port: port,
            nodeAddress: msg.sender,
            ip: ip,
            domainName: ""
        });

        emit NodeRegistered(nodeId, msg.sender, ip, port);
    }

    /**
     * @notice Sets the IP address and port for a node
     * @dev Only callable by the node owner
     * @dev Node must not be in the current or next committee
     * @param nodeId The ID of the node
     * @param ip The new IP address (IPv4 or IPv6)
     * @param port The new port number
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
     * @notice Sets the domain name for a node
     * @dev Only callable by the node owner
     * @dev Node must not be in the current or next committee
     * @param nodeId The ID of the node
     * @param name The domain name to set
     */
    function setDomainName(NodeId nodeId, string calldata name)
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
     * @notice Gets the node information for a specific node ID
     * @dev Reverts if the node doesn't exist
     * @param nodeId The ID of the node to query
     * @return node The node information
     */
    function getNode(NodeId nodeId)
        external
        view
        override
        nodeExists(nodeId)
        returns (Node memory node)
    {
        return nodes[nodeId];
    }

    /**
     * @notice Gets the node ID for an active node address
     * @dev Reverts if the address is not assigned to any active node
     * @param nodeAddress The address to query
     * @return nodeId The node ID associated with the address
     */
    function getNodeId(address nodeAddress) external view override returns (NodeId nodeId) {
        require(
            _isAddressOfActiveNode(nodeAddress),
            AddressIsNotAssignedToAnyNode(nodeAddress)
        );
        nodeId = _activeNodesAddressToId.get(nodeAddress);
    }

    /**
     * @notice Gets all passive node IDs for a specific address
     * @dev Reverts if the address has no passive nodes
     * @param nodeAddress The address to query
     * @return nodeIds Array of passive node IDs associated with the address
     */
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

    /**
     * @notice Gets all passive node IDs in the system
     * @return nodeIds Array of all passive node IDs
     */
    function getPassiveNodeIds() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _passiveNodeIds.values();
    }

    /**
     * @notice Gets the public key for an active node
     * @dev Reverts if the node was never registered as an active node
     * @param nodeId The ID of the node
     * @return publicKey The node's public key
     */
    function getPublicKey(NodeId nodeId) external view override returns (bytes32[2] memory publicKey) {
        publicKey = _nodesInfo[nodeId].publicKey;
        require(publicKey[0] != bytes32(0) && publicKey[1] != bytes32(0), ActiveNodeWasNeverRegistered(nodeId));
    }

    /**
     * @notice Gets all active node IDs in the system
     * @return nodeIds Array of all active node IDs
     */
    function getActiveNodeIds() external view override returns (NodeId[] memory nodeIds) {
        nodeIds = _activeNodeIds.values();
    }

    /**
     * @notice Checks if an active node exists
     * @param nodeId The ID of the node to check
     * @return result True if the node exists and is active, false otherwise
     */
    function activeNodeExists(NodeId nodeId) external view override returns(bool result){
        result = _isActiveNode(nodeId);
    }

    /**
     * @notice Checks if a passive node exists
     * @param nodeId The ID of the node to check
     * @return result True if the node exists and is passive, false otherwise
     */
    function passiveNodeExists(NodeId nodeId) external view override returns(bool result){
        result = _isPassiveNode(nodeId);
    }

    /**
     * @notice Creates an active node with the specified parameters
     * @dev Internal function called during node registration
     * @param nodeId The ID to assign to the new node
     * @param nodeAddress The owner address of the node
     * @param ip The IP address of the node
     * @param port The port number
     * @param domainName The domain name (can be empty)
     * @param publicKey The node's public key
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

        nodes[nodeId] = Node({
            id: nodeId,
            port: port,
            nodeAddress: nodeAddress,
            ip: ip,
            domainName: domainName
        });

        _nodesInfo[nodeId] = NodeInfo({
            publicKey: publicKey
        });

        emit NodeRegistered(nodeId, nodeAddress, ip, port);
    }

    /**
     * @notice Deletes a node and cleans up all associated data
     * @dev Handles active and passive nodes differently
     * @dev For active nodes: flushes rewards, removes from committee, and cleans up staking
     * @dev For passive nodes: removes from passive node tracking and cleans up ownership requests
     * @param id The ID of the node to delete
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
        }
        else {
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
     * @notice Adds a node ID to the passive nodes set
     * @dev Asserts that the addition is successful
     * @param nodeId The node ID to add
     */
    function _addPassiveNodeId(NodeId nodeId) private {
        assert(_passiveNodeIds.add(nodeId));
    }

    /**
     * @notice Adds a node ID to the active nodes set
     * @dev Asserts that the addition is successful
     * @param nodeId The node ID to add
     */
    function _addActiveNodeId(NodeId nodeId) private {
        assert(_activeNodeIds.add(nodeId));
    }

    /**
     * @notice Maps an address to an active node ID
     * @dev Validates that the address is not already used by passive nodes
     * @dev Reverts if address is already assigned to another active node
     * @param nodeAddress The address to map
     * @param nodeId The node ID to associate with the address
     */
    function _setActiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        require(
            !_isAddressOfPassiveNodes(nodeAddress),
            AddressInUseByPassiveNodes(nodeAddress)
        );
        require(
            _activeNodesAddressToId.set(nodeAddress, nodeId),
            AddressWasAlreadyAssignedToNode(nodeAddress)
        );
    }

    /**
     * @notice Maps an address to a passive node ID
     * @dev Validates that the address is not already used by an active node
     * @dev Adds address to passive node addresses set if it's the first passive node
     * @param nodeAddress The address to map
     * @param nodeId The node ID to associate with the address
     */
    function _setPassiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        require(
            !_isAddressOfActiveNode(nodeAddress),
            AddressWasAlreadyAssignedToNode(nodeAddress)
        );

        require(
            _passiveNodeIdByAddress.add(nodeAddress, nodeId),
            PassiveNodeAlreadyExistsForAddress(nodeAddress, nodeId)
        );

        if (!_isAddressOfPassiveNodes(nodeAddress)) {
            assert(_passiveNodeAddresses.add(nodeAddress));
        }
    }

    /**
     * @notice Initializes a group of nodes during contract initialization
     * @dev Creates all initial nodes as active nodes
     * @param initialNodes Array of node data to initialize
     * @param publicKeys Array of public keys corresponding to each node
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
     * @notice Checks if a node ID corresponds to an active node
     * @param nodeId The node ID to check
     * @return result True if the node is active, false otherwise
     */
    function _isActiveNode(NodeId nodeId) private view returns (bool result) {
        result = _activeNodeIds.contains(nodeId);
    }

    /**
     * @notice Checks if a node ID corresponds to a passive node
     * @param nodeId The node ID to check
     * @return result True if the node is passive, false otherwise
     */
    function _isPassiveNode(NodeId nodeId) private view returns (bool result) {
        result = _passiveNodeIds.contains(nodeId);
    }

    /**
     * @notice Checks if an address has any passive nodes associated with it
     * @param nodeAddress The address to check
     * @return result True if the address has passive nodes, false otherwise
     */
    function _isAddressOfPassiveNodes(address nodeAddress) private view returns (bool result) {
        result = _passiveNodeAddresses.contains(nodeAddress);
    }

    /**
     * @notice Checks if an address is associated with an active node
     * @param nodeAddress The address to check
     * @return result True if the address owns an active node, false otherwise
     */
    function _isAddressOfActiveNode(address nodeAddress) private view returns (bool result) {
        result = _activeNodesAddressToId.contains(nodeAddress);
    }

    /**
     * @notice Converts a public key to an Ethereum address
     * @dev Uses keccak256 hash of the concatenated public key components
     * @param pubKey The public key as a 2-element bytes32 array
     * @return nodeAddress The derived Ethereum address
     */
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
