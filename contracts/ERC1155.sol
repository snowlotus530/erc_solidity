pragma solidity ^0.4.24;

import "./SafeMath.sol";

contract ERC1155 {
    using SafeMath for uint256;

    // Variables
    uint256 public index = 0;   // The last created itemId (items start at index 1)
    struct Items {
        string name;
        uint256 totalSupply;
        mapping (address => uint256) balances;
    }
    mapping (uint256 => uint8) public decimals;
    mapping (uint256 => string) public symbol;
    mapping (uint256 => mapping(address => mapping(address => uint256))) allowances;
    mapping (uint256 => Items) public items;
    mapping (uint256 => address) nfiOwners;
    mapping (uint256 => string) metadataURIs;

    // Events
    //event Transfer(address indexed _from, address indexed _to, uint256[] indexed _itemIds, uint256[] _values);
    //event Approval(address indexed _owner, address indexed _spender, uint256[] indexed _itemIds, uint256[] _values);
    event Approval(address indexed _owner, address indexed _spender, uint256 indexed _itemId, uint256 _value);
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _itemId, uint256 _value);

    // TEMP CONSTRUCTOR - Testing purposes
    /**
    constructor() public {
        items[1].balances[msg.sender] = 1000;
        items[2].balances[msg.sender] = 1000;
        items[3].balances[msg.sender] = 1000;
        items[4].balances[msg.sender] = 1000;
        items[5].balances[msg.sender] = 1000;
        items[6].balances[msg.sender] = 1000;
        items[7].balances[msg.sender] = 1000;
        items[8].balances[msg.sender] = 1000;
        items[9].balances[msg.sender] = 1000;
        items[10].balances[msg.sender] = 1000;
        items[11].balances[msg.sender] = 1000;
        items[12].balances[msg.sender] = 1000;
        items[13].balances[msg.sender] = 1000;
        items[14].balances[msg.sender] = 1000;
        items[15].balances[msg.sender] = 1000;
        items[16].balances[msg.sender] = 1000;
        items[17].balances[msg.sender] = 1000;
        items[18].balances[msg.sender] = 1000;
        items[19].balances[msg.sender] = 1000;
        items[20].balances[msg.sender] = 1000;
    }
    */

    // Required Functions
    function transferFrom(address _from, address _to, uint256 _itemId, uint256 _value) external {
        if(_from != msg.sender) {
            require(allowances[_itemId][_from][msg.sender] >= _value);
            allowances[_itemId][_from][msg.sender] = allowances[_itemId][_from][msg.sender].sub(_value);
        }
        items[_itemId].balances[_from] = items[_itemId].balances[_from].sub(_value);
        items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);

        Transfer(_from, _to, _itemId, _value);
    }

    function batchTransfer(address _to, uint256[] _itemIds, uint256[] _values) external {
        uint256 _itemId;
        uint256 _value;
        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _value = _values[i];
            items[_itemId].balances[msg.sender] = items[_itemId].balances[msg.sender].sub(_value);
            items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);
            Transfer(msg.sender, _to, _itemId, _value);
        }
    }

    function batchTransferFrom(address _from, address _to, uint256[] _itemIds, uint256[] _values) external {
        uint256 _itemId;
        uint256 _value;

        if(_from == msg.sender) {
            for (uint256 i = 0; i < _itemIds.length; ++i) {
                _itemId = _itemIds[i];
                _value = _values[i];
                items[_itemId].balances[_from] = items[_itemId].balances[_from].sub(_value);
                items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);
                Transfer(_from, _to, _itemId, _value);
            }
        }
        else {
            for (i = 0; i < _itemIds.length; ++i) {
                _itemId = _itemIds[i];
                _value = _values[i];
                require(allowances[_itemId][_from][msg.sender] >= _value);

                allowances[_itemId][_from][msg.sender] = allowances[_itemId][_from][msg.sender].sub(_value);
                items[_itemId].balances[_from] = items[_itemId].balances[_from].sub(_value);
                items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);
                Transfer(_from, _to, _itemId, _value);
            }
        }
    }

    function approve(address[] _spenders, uint256[] _itemIds, uint256[] _values) external  {
        uint256 _itemId;
        uint256 _value;
        address _spender;

        // if the allowance isn't 0, it can only be updated to 0 to prevent an allowance change immediately after withdrawal
        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _value = _values[i];
            _spender = _spenders[i];

            require(_value == 0 || allowances[_itemId][msg.sender][_spender] == 0);
            allowances[_itemId][msg.sender][_spender] = _value;
            Approval(msg.sender, _spender, _itemId, _value);
        }
    }

    function increaseApproval(address[] _spenders, uint256[] _itemIds, uint256[] _addedValues) external {
        uint256 _itemId;
        uint256 _addedValue;
        address _spender;

        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _addedValue = _addedValues[i];
            _spender = _spenders[i];

            allowances[_itemId][msg.sender][_spender] = _addedValue.add(allowances[_itemId][msg.sender][_spender]);
            Approval(msg.sender, _spender, _itemId, allowances[_itemId][msg.sender][_spender]);
        }
    }

    function decreaseApproval(address[] _spenders, uint256[] _itemIds, uint256[] _subtractedValues) external {
        uint256 _itemId;
        uint256 _subtractedValue;
        address _spender;

        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _subtractedValue = _subtractedValues[i];
            _spender = _spenders[i];
            uint256 oldValue = allowances[_itemId][msg.sender][_spender];
            if (_subtractedValue > oldValue) {
                allowances[_itemId][msg.sender][_spender] = 0;
            } else {
                allowances[_itemId][msg.sender][_spender] = oldValue.sub(_subtractedValue);
            }
            Approval(msg.sender, _spender, _itemId, allowances[_itemId][msg.sender][_spender]);
        }
    }

    // Required View Functions
    function totalSupply(uint256 _itemId) external view returns (uint256) {
        return items[_itemId].totalSupply;
    }
    function balanceOf(uint256 _itemId, address _owner) external view returns (uint256) {
        return items[_itemId].balances[_owner];
    }

    // Optional View Functions
    function name(uint256 _itemId) external view returns (string) {
        return items[_itemId].name;
    }

    // Optional Functions for Non-Fungible Items
    function ownerOf(uint256 _itemId) external view returns (address) {
        return nfiOwners[_itemId];
    }
    function itemURI(uint256 _itemId) external view returns (string) {
        return metadataURIs[_itemId];
    }
    function itemByIndex(uint256 _itemId, uint256 _index) external view returns (uint256) {

    }
    function itemOfOwnerByIndex(uint256 _itemId, address _owner, uint256 _index) external view returns (uint256) {

    }
}