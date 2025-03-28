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

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {INodes, NodeId} from "@skalenetwork/playa-manager-interfaces/contracts/INodes.sol";


contract Nodes is INodes {

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes4 private constant ZERO_IPV4 = bytes4(0);
    bytes16 private constant ZERO_IPV6 = bytes16(0);
    /// For node Id generation
    uint256 private _nodeIdCounter;

    // Set to track passive node IDs
    EnumerableSet.UintSet private _passiveNodeIds;

    // Set to track active node IDs
    EnumerableSet.UintSet private _activeNodeIds;

    // Mapping from node ID to Node struct
    mapping(NodeId nodeId => Node node) public nodes;

    //Maps addresses to NodeIds
    mapping(address nodeAddress => NodeId nodeId) public activeNodeIdByAddress;
    // Set to track active node addresses
    EnumerableSet.AddressSet private _activeNodeAddresses;

    //Maps addresses to NodeIds
    mapping(address nodeAddress => EnumerableSet.UintSet nodeIds) private _passiveNodeIdByAddress;
    // Set to track passive node addresses
    EnumerableSet.AddressSet private _passiveNodeAddresses;

    // Set to track IPs taken
    EnumerableSet.Bytes32Set private _ips;

    // Set to track domain Names taken
    EnumerableSet.Bytes32Set private _domainNames;

    // Stores requests to change address before committing changes
    mapping(NodeId nodeId => address nodeAddress) public addressChangeRequests;

    error NodeDoesNotExist(NodeId nodeId);
    error NodeAlreadyExists(NodeId nodeId);
    error AddressAlreadyHasNode(address nodeAddress);
    error AddressIsNotAssignedToAnyNode(address nodeAddress);
    error PassiveNodeAlreadyExistsForAddress(address nodeAddress, NodeId nodeId);
    error AddressInUseByPassiveNodes(address nodeAddress);
    error InvalidPortNumber(uint16 port);
    error InvalidIp(bytes ip);
    error IpIsNotAvailable(bytes ip);
    error DomainNameAlreadyTaken(string domainName);
    error InvalidSender();
    error AddressIsZero();

    modifier checkNodeIndex(NodeId nodeId) {
        if (!_isActiveNode(nodeId) && !_isPassiveNode(nodeId)){
            revert NodeDoesNotExist(nodeId);
        }
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
        if (port == 0) {
            revert InvalidPortNumber(port);
        }
        _;
    }

    modifier isNodeOwner(NodeId nodeId){
        if (msg.sender != nodes[nodeId].nodeAddress) {
            revert InvalidSender();
        }
        _;
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

        if(!_ips.add(keccak256(ip))){
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
        checkNodeIndex(nodeId)
        isNodeOwner(nodeId)
    {
        if (_isPassiveNode(nodeId)) {
            if (_isAddressOfActiveNode(newAddress)) {
                revert AddressAlreadyHasNode(newAddress);
            }
            addressChangeRequests[nodeId] = newAddress;
            return;
        }

        // Is active
        if (_isAddressOfPassiveNodes(newAddress)) {
            revert AddressInUseByPassiveNodes(newAddress);
        }
        if (_isAddressOfActiveNode(newAddress)) {
            revert AddressAlreadyHasNode(newAddress);
        }
        addressChangeRequests[nodeId] = newAddress;

    }

    function confirmAddressChange(NodeId nodeId) external override {
        // TODO: Block if Node is in Committee ?

        address newAddress = addressChangeRequests[nodeId];
        if(newAddress == address(0)){
            revert AddressIsZero();
        }
        if (newAddress != msg.sender) {
            revert InvalidSender();
        }

        if (_isActiveNode(nodeId)) {

            address oldAddress = nodes[nodeId].nodeAddress;

            // Remove old address
            delete addressChangeRequests[nodeId];
            // slither-disable-next-line all
            _activeNodeAddresses.remove(oldAddress);
            activeNodeIdByAddress[oldAddress] = NodeId.wrap(0);

            // Register new address
            _setActiveNodeIdForAddress(newAddress, nodeId);
            nodes[nodeId].nodeAddress = newAddress;

            emit NodeAddressChanged(nodeId, oldAddress, newAddress);
        }
        else if (_isPassiveNode(nodeId)) {

            address oldAddress = nodes[nodeId].nodeAddress;

            // Remove old address
            delete addressChangeRequests[nodeId];
            // slither-disable-next-line all
            _passiveNodeIdByAddress[oldAddress].remove(NodeId.unwrap(nodeId));
            if (_passiveNodeIdByAddress[oldAddress].length() == 0) {
                // slither-disable-next-line all
                _passiveNodeAddresses.remove(oldAddress);
            }

            // Register new address
            _setPassiveNodeIdForAddress(newAddress, nodeId);
            nodes[nodeId].nodeAddress = newAddress;

            emit NodeAddressChanged(nodeId, oldAddress, newAddress);
        }
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

        if(!_ips.add(keccak256(ip))){
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
            checkNodeIndex(nodeId)
            isNodeOwner(nodeId)
            validIp(ip)
            validPort(port)
        {
        //TODO: Block if Node is in Committee
        Node storage node = nodes[nodeId];

        // slither-disable-next-line all
        _ips.remove(keccak256(node.ip));
        if(!_ips.add(keccak256(ip))){
            revert IpIsNotAvailable(ip);
        }
        node.ip = ip;
        node.port = port;
        emit NodeIpChanged(nodeId, msg.sender, ip, port);

    }
    function setDomainName(NodeId nodeId, string calldata name)
        external
        override
        checkNodeIndex(nodeId)
        isNodeOwner(nodeId)
    {
        Node storage node = nodes[nodeId];

        bytes32 newName = keccak256(abi.encodePacked(name));

        bytes32 oldName = keccak256(abi.encodePacked(node.domainName));
        if (oldName != keccak256("")) {
            // slither-disable-next-line all
            _domainNames.remove(oldName);
        }

        if(!_domainNames.add(newName)){
            revert DomainNameAlreadyTaken(name);
        }
        node.domainName = name;

        emit NodeDomainNameChanged(nodeId, msg.sender, name);
    }

    function getNode(NodeId nodeId)
        external
        view
        override
        checkNodeIndex(nodeId)
        returns (Node memory node)
    {
        return nodes[nodeId];
    }


    function getNodeId(address nodeAddress) external view override returns (NodeId nodeId) {
        // Getter for active node
        if (!_activeNodeAddresses.contains(nodeAddress)) {
            revert AddressIsNotAssignedToAnyNode(nodeAddress);
        }
        nodeId = activeNodeIdByAddress[nodeAddress];
    }

    function _addPassiveNodeId(NodeId nodeId) private {
        bool result = _passiveNodeIds.add(NodeId.unwrap(nodeId));
        if(!result) {
            // Should be impossible to happen
            revert NodeAlreadyExists(nodeId);
        }
    }

    function _addActiveNodeId(NodeId nodeId) private {
        bool result = _activeNodeIds.add(NodeId.unwrap(nodeId));
        if(!result) {
            // Should be impossible to happen
            revert NodeAlreadyExists(nodeId);
        }
    }

    function _setActiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        if (_isAddressOfPassiveNodes(nodeAddress)) {
            revert AddressInUseByPassiveNodes(nodeAddress);
        }
        bool result = _activeNodeAddresses.add(nodeAddress);
        if(!result) {
            revert AddressAlreadyHasNode(nodeAddress);
        }
        activeNodeIdByAddress[nodeAddress] = nodeId;
    }

    function _setPassiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        if (_isAddressOfActiveNode(nodeAddress)) {
            revert AddressAlreadyHasNode(nodeAddress);
        }
        bool result = _passiveNodeIdByAddress[nodeAddress].add(NodeId.unwrap(nodeId));
        if (!result) {
            revert PassiveNodeAlreadyExistsForAddress(nodeAddress, nodeId);
        }
        // Ignore result: passive node address can already exist
        // slither-disable-next-line all
        _passiveNodeAddresses.add(nodeAddress);
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
        result = _activeNodeAddresses.contains(nodeAddress);
    }

}
