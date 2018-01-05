pragma solidity ^0.4.18; // solhint-disable-line compiler-fixed

import "./node_modules/eip672/contracts/EIP672.sol";
import "./EIP777.sol";
import "./ITokenRecipient.sol";


contract ReferenceToken is EIP777, EIP672 {
    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint) private balances;
    mapping(address => mapping(address => bool)) private authorized;

    modifier onlyOwner () {
        require(msg.sender == owner);
        _;
    }

    function ReferenceToken(string _name, string _symbol, uint8 _decimals) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
    }

    function balanceOf(address _tokenHolder) public constant returns (uint256) {
        return balances[_tokenHolder];
    }

    function send(address _to, uint256 _value) public {
        bytes memory empty;
        doSend(msg.sender, _to, _value, empty, msg.sender, empty);
    }

    function send(address _to, uint256 _value, bytes _userData) public {
        bytes memory empty;
        doSend(msg.sender, _to, _value, _userData, msg.sender, empty);
    }

    function authorizeOperator(address _operator, bool _authorized) public {
        if (_operator == msg.sender) { return; } // TODO Should we throw?
        authorized[_operator][msg.sender] = _authorized;
        AuthorizeOperator(_operator, msg.sender, _authorized);
    }

    function isOperatorAuthorizedFor(address _operator, address _tokenHolder) public constant returns (bool) {
        return _operator == _tokenHolder || authorized[_operator][_tokenHolder];
    }

    function operatorSend(address _from, address _to, uint256 _value, bytes _userData, bytes _operatorData) public {
        require(isOperatorAuthorizedFor(msg.sender, _from) || msg.sender == _from);
        doSend(_from, _to, _value, _userData, msg.sender, _operatorData);
    }

    function burn(address _tokenHolder, uint256 _value) public onlyOwner returns(bool) {
        require(balanceOf(_tokenHolder) >= _value);

        balances[_tokenHolder] -= _value;
        totalSupply -= _value;

        Burn(_tokenHolder, _value); // TODO should we call tokenFallback on _tokenholder?

        return true;
    }

    function ownerMint(address _tokenHolder, uint256 _value, bytes _operatorData) public onlyOwner returns(bool) {
        balances[_tokenHolder] += _value;
        totalSupply += _value;

        bytes memory empty;

        address recipientImplementation = interfaceAddr(_tokenHolder, "ITokenRecipient");
        if (recipientImplementation != 0) {
            ITokenRecipient(recipientImplementation).tokensReceived(
                0x0, _tokenHolder, _value, empty, msg.sender, _operatorData);
        } else {
            require(!isContract(_tokenHolder));
        }
        Mint(_tokenHolder, _value, msg.sender, _operatorData);
    }

    function doSend(
        address _from,
        address _to,
        uint256 _value,
        bytes _userData,
        address _operator,
        bytes _operatorData
    )
        private
    {
        require(_to != 0);                  // forbid sending to 0x0 (=burning)
        require(_value >= 0);               // only send positive amounts
        require(balances[_from] >= _value); // ensure enough funds

        balances[_from] -= _value;
        balances[_to] += _value;

        address recipientImplementation = interfaceAddr(_to, "ITokenRecipient");
        if (recipientImplementation != 0) {
            ITokenRecipient(recipientImplementation).tokensReceived(
                _from, _to, _value, _userData, _operator, _operatorData);
        } else {
            require(!isContract(_to));
        }
        Send(_from, _to, _value, _userData, _operator, _operatorData);
    }
}