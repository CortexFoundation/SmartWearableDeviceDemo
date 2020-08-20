pragma solidity ^0.4.24;
// pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

// last implemented contract: 0x70ae5b30c81d00cc4b6cbe765a71ab89e35d2cc4
contract GeneralService {
    using SafeMath for uint;
    
    // address public modelAddr = 0xe2d50CFb680ffD3E39a187ae8C22B4f81b092A10;
    string public companyName;
    uint8 public USER_DATA_COUNT = 10;
    // 0: low risk, 1: medium risk, 2: high risk
    uint8 public RISK_LEVEL_COUNT = 3;
    
    mapping(address => uint256) public availableServicesByUser;
    mapping(address => uint256) public activeServicesByUser;
    
    
    // --- getters --- 
    function getNumberOfServices() public view returns(uint256) ;
    
    function getService(uint8 _serviceIndex) public view returns(string, uint256);
    
    function getAvaialbleServicesByUser(address _userAddr) public view returns(uint256);
    
    function getActiveServicesByUser(address _userAddr) public view returns(uint256);
    
    function isServiceActive(address _userAddr, uint8 _serviceIndex) public view returns(bool);
    
    
    // --- service AI inferences --- 
    function requestAuthorisation(address _clientAddr, uint256 _categories) public;
    
    function getAvaialbleServices(address _userAddr, address _modelHash) public returns(uint256);
    
    function getUserData(uint _dataCategory) internal;
    
    
    // --- purchase services --- 
    function purchaseService(uint256 _serviceIndex) public payable;
    
    function checkCurrentHealthCondition(address _userAddr) public pure returns(bool);
}

