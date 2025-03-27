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

    /// For node Id generation
    uint256 private _nodeIdCounter;

    // Set to track passive node IDs
    EnumerableSet.UintSet private _passiveNodeIds;

    // Set to track active node IDs
    EnumerableSet.UintSet private _activeNodeIds;

    // Mapping from node ID to Node struct
    mapping(NodeId => Node) public nodes;

    //Maps addresses to NodeIds
    mapping(address => NodeId) public activeNodeIdByAddress;
    // Set to track active node addresses
    EnumerableSet.AddressSet private _activeNodeAddresses;

    //Maps addresses to NodeIds
    mapping(address => EnumerableSet.UintSet) private _passiveNodeIdByAddress;
    // Set to track passive node addresses
    EnumerableSet.AddressSet private _passiveNodeAddresses;

    // Set to track IPs taken
    EnumerableSet.Bytes32Set private _ips;

    // Set to track domain Names taken
    EnumerableSet.Bytes32Set private _domainNames;

    // Stores requests to change address before commiting changes
    mapping(NodeId => address) public addressChangeRequests;

    error NodeDoesNotExist(NodeId nodeId);
    error NodeAlreadyExists(NodeId nodeId);
    error AddressAlreadyHasNode(address nodeAddress);
    error AddressIsNotAssignedToAnyNode(address nodeAddress);
    error PassiveNodeAlreadyExistsForAddress(address nodeAdress, NodeId nodeId);
    error AddressInUseByPassiveNodes(address nodeAddress);
    error InvalidPortNumber(uint16 port);
    error InvalidIp(bytes ip);
    error IpIsNotAvailable(bytes ip);
    error DomainNameAlreadyTaken(string domainName);

    function registerNode(bytes calldata ip, uint16 port) external override {

        if (_passiveNodeAddresses.contains(msg.sender)) {
            revert AddressInUseByPassiveNodes(msg.sender);
        }

        _validateNewNodeInput(msg.sender, ip, port);

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


    function requestChangeAddress(NodeId nodeId, address newAddress) external override {
        if (_isPassiveNode(nodeId)) {
            require(nodes[nodeId].nodeAddress == msg.sender, "You are not authorized to perform this request");
            if (_isAddressOfActiveNode(newAddress)) {
                revert AddressAlreadyHasNode(newAddress);
            }
            addressChangeRequests[nodeId] = newAddress;
        }
        else if (_isActiveNode(nodeId)) {
            require(nodes[nodeId].nodeAddress == msg.sender, "You are not authorized to perform this request");
            if (_isAddressOfPassiveNodes(newAddress)) {
                revert AddressInUseByPassiveNodes(newAddress);
            }
            if (_isAddressOfActiveNode(newAddress)) {
                revert AddressAlreadyHasNode(newAddress);
            }
            addressChangeRequests[nodeId] = newAddress;
        }
        else{
            revert NodeDoesNotExist(nodeId);
        }
    }

    function confirmAddressChange(NodeId nodeId) external override {
        // TODO: Block if Node is in Committee ?

        address newAddress = addressChangeRequests[nodeId];
        require(newAddress != address(0), "There is no address change request reccorded for this node.");
        require(newAddress == msg.sender, "You are not authorized to perform this operation.");

        if (_isActiveNode(nodeId)) {
            if (_isAddressOfPassiveNodes(msg.sender)) {
                revert AddressInUseByPassiveNodes(msg.sender);
            }
            if (_isAddressOfActiveNode(msg.sender)) {
                revert AddressAlreadyHasNode(msg.sender);
            }

            address oldAddress = nodes[nodeId].nodeAddress;

            // Remove old address
            delete addressChangeRequests[nodeId];
            _activeNodeAddresses.remove(oldAddress);
            activeNodeIdByAddress[oldAddress] = NodeId.wrap(0);

            // Register new address
            _setActiveNodeIdForAddress(newAddress, nodeId);
            nodes[nodeId].nodeAddress = newAddress;

            //emit NodeAddressChanged(nodeId, oldAddress, newAddress);
        }
        else if (_isPassiveNode(nodeId)) {

            if (_isAddressOfActiveNode(newAddress)) {
                revert AddressAlreadyHasNode(newAddress);
            }
            address oldAddress = nodes[nodeId].nodeAddress;

            // Remove old address
            delete addressChangeRequests[nodeId];
            _passiveNodeIdByAddress[oldAddress].remove(NodeId.unwrap(nodeId));
            if (_passiveNodeIdByAddress[oldAddress].length() == 0) {
                _passiveNodeAddresses.remove(oldAddress);
            }

            // Register new address
            _setPassiveNodeIdForAddress(newAddress, nodeId);
            nodes[nodeId].nodeAddress = newAddress;

            //emit NodeAddressChanged(nodeId, oldAddress, newAddress);
        }
    }

    function registerPassiveNode(
        bytes calldata ip,
        uint16 port
    ) external override {

        _validateNewNodeInput(msg.sender, ip, port);

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

    function setIpAddress(NodeId nodeId, bytes calldata ip, uint16 port) external override {
        //TODO: Block if Node is in Committee
        _checkNodeIndex(nodeId);
        Node storage node = nodes[nodeId];

        require(msg.sender == node.nodeAddress, "You are not authorized to perform this operation");

        _validatePort(port);
        _validateIp(ip);


        _ips.remove(keccak256(node.ip));
        if(!_ips.add(keccak256(ip))){
            revert IpIsNotAvailable(ip);
        }
        node.ip = ip;
        node.port = port;
        //emit NodeIpChanged(nodeId, msg.sender, ip, port);

    }
    function setDomainName(NodeId nodeId, string calldata name) external override {
        _checkNodeIndex(nodeId);
        Node storage node = nodes[nodeId];

        require(msg.sender == node.nodeAddress, "You are not authorized to perform this operation");

        bytes32 newName = keccak256(abi.encodePacked(name));
        require(newName != keccak256(""), "Provide a non empty name");

        bytes32 oldName = keccak256(abi.encodePacked(node.domainName));
        if (oldName != keccak256("")) {
            _domainNames.remove(oldName);
        }

        if(!_domainNames.add(newName)){
            revert DomainNameAlreadyTaken(name);
        }
        node.domainName = name;

        //emit NodeDomainNameChanged(nodeId, msg.sender, name);
    }

    function getNode(NodeId nodeId)
        external
        view
        override
        returns (Node memory node)
    {
        _checkNodeIndex(nodeId);
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
            revert NodeAlreadyExists(nodeId);
        }
    }

    function _addActiveNodeId(NodeId nodeId) private {
        bool result = _activeNodeIds.add(NodeId.unwrap(nodeId));
        if(!result) {
            revert NodeAlreadyExists(nodeId);
        }
    }

    function _setActiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        bool result = _activeNodeAddresses.add(nodeAddress);
        if(!result) {
            revert NodeAlreadyExists(nodeId);
        }
        activeNodeIdByAddress[nodeAddress] = nodeId;
    }

    function _setPassiveNodeIdForAddress(address nodeAddress, NodeId nodeId) private {
        bool result = _passiveNodeIdByAddress[nodeAddress].add(NodeId.unwrap(nodeId));
        if (!result) {
            revert PassiveNodeAlreadyExistsForAddress(nodeAddress, nodeId);
        }
        // Ignore result: passive node address can already exist
        _passiveNodeAddresses.add(nodeAddress);
    }

    function _checkNodeIndex(NodeId nodeId) private view {
        if (!_isActiveNode(nodeId) && !_isPassiveNode(nodeId)){
            revert NodeDoesNotExist(nodeId);
        }
    }

    function _validateNewNodeInput(address nodeAddress, bytes calldata ip, uint16 port) private view {

        _validatePort(port);
        _validateIp(ip);
        if (_isAddressOfActiveNode(nodeAddress)){
            revert AddressAlreadyHasNode(nodeAddress);
        }
    }
    function _validatePort(uint16 port) private pure {
        if (port == 0) {
            revert InvalidPortNumber(port);
        }
    }
    function _validateIp(bytes calldata ip) private view {
        // Check if IPv4 or IPv6
        if (ip.length != 4 && ip.length != 16) {
            revert InvalidIp(ip);
        }

        bytes32 raw;
        assembly {
            raw := calldataload(ip.offset)
        }
        if (raw == bytes32(0)) {
            revert InvalidIp(ip);
        }
        if (_ips.contains(keccak256(ip))) {
            revert IpIsNotAvailable(ip);
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
        result = _activeNodeAddresses.contains(nodeAddress);
    }

}
