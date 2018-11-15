pragma solidity ^0.4.24;

import "./ERC1155.sol";

/**
    @dev Extension to ERC1155 for Mixed Fungible and Non-Fungible Items support
    The main benefit is sharing of common type information, just like you do when
    creating a fungible id.
*/
contract ERC1155MixedFungible is ERC1155 {

    // Use a split bit implementation.
    // Store the type in the upper 128 bits..
    uint256 constant TYPE_MASK = uint256(uint128(~0)) << 128;

    // ..and the non-fungible index in the lower 128
    uint256 constant NF_INDEX_MASK = uint128(~0);

    // The top bit is a flag to tell if this is a NFI.
    uint256 constant TYPE_NF_BIT = 1 << 255;

    mapping (uint256 => address) nfOwners;

    // Only to make code clearer. Should not be functions
    function isNonFungible(uint256 _id) public pure returns(bool) {
        return _id & TYPE_NF_BIT == TYPE_NF_BIT;
    }
    function isFungible(uint256 _id) public pure returns(bool) {
        return _id & TYPE_NF_BIT == 0;
    }
    function getNonFungibleIndex(uint256 _id) public pure returns(uint256) {
        return _id & NF_INDEX_MASK;
    }
    function getNonFungibleBaseType(uint256 _id) public pure returns(uint256) {
        return _id & TYPE_MASK;
    }
    function isNonFungibleBaseType(uint256 _id) public pure returns(bool) {
        // A base type has the NF bit but does not have an index.
        return (_id & TYPE_NF_BIT == TYPE_NF_BIT) && (_id & NF_INDEX_MASK == 0);
    }
    function isNonFungibleItem(uint256 _id) public pure returns(bool) {
        // A base type has the NF bit but does has an index.
        return (_id & TYPE_NF_BIT == TYPE_NF_BIT) && (_id & NF_INDEX_MASK != 0);
    }
    function ownerOf(uint256 _id) public view returns (address) {
        return nfOwners[_id];
    }

    // overide
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes _data) external {

        require(_to != 0);
        require(_from == msg.sender || operatorApproval[_from][msg.sender] == true, "Need operator approval for 3rd party transfers.");

        if (isNonFungible(_id)) {
            require(nfOwners[_id] == _from);
            nfOwners[_id] = _to;
        } else {
            balances[_id][_from] = balances[_id][_from].sub(_value);
            balances[_id][_to]   = balances[_id][_to].add(_value);
        }

        emit Transfer(msg.sender, _from, _to, _id, _value);

        // solium-disable-next-line arg-overflow
        _checkAndCallSafeTransfer(_from, _to, _id, _value, _data);
    }

    // overide
    function safeBatchTransferFrom(address _from, address _to, uint256[] _ids, uint256[] _values, bytes _data) external {

        require(_to != 0);
        require(_ids.length == _values.length);

        // Solidity does not scope variables, so declare them here.
        uint256 id;
        uint256 value;
        uint256 i;

        // Only supporting a global operator approval allows us to do only 1 check and not to touch storage to handle allowances.
        require(_from == msg.sender || operatorApproval[_from][msg.sender] == true, "Need operator approval for 3rd party transfers.");

        // Optimize for when _to is not a contract.
        // This makes safe transfer virtually the same cost as a regular transfer
        // when not sending to a contract.
        if (!_to.isContract()) {
            // We assume _ids.length == _values.length
            // we don't check since out of bound access will throw.
            for (i = 0; i < _ids.length; ++i) {
                id = _ids[i];
                value = _values[i];

                if (isNonFungible(id)) {
                    require(nfOwners[id] == _from);
                    nfOwners[id] = _to;
                } else {
                    balances[id][_from] = balances[id][_from].sub(value);
                    balances[id][_to]   = value.add(balances[id][_to]);
                }

                emit Transfer(msg.sender, _from, _to, id, value);
            }
        } else {
            for (i = 0; i < _ids.length; ++i) {
                id = _ids[i];
                value = _values[i];

                if (isNonFungible(id)) {
                    require(nfOwners[id] == _from);
                    nfOwners[id] = _to;
                } else {
                    balances[id][_from] = balances[id][_from].sub(value);
                    balances[id][_to]   = value.add(balances[id][_to]);
                }

                emit Transfer(msg.sender, _from, _to, id, value);

                // We know _to is a contract.
                // Call onERC1155Received and throw if we don't get ERC1155_RECEIVED,
                // as per the standard requirement. This allows the receiving contract to perform actions
                require(IERC1155TokenReceiver(_to).onERC1155Received(msg.sender, _from, id, value, _data) == ERC1155_RECEIVED);
            }
        }
    }

    function balanceOf(address _owner, uint256 _id) external view returns (uint256) {
        if (isNonFungibleItem(_id))
            return nfOwners[_id] == _owner ? 1 : 0;
        return balances[_id][_owner];
    }
}
