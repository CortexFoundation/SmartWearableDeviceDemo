pragma solidity ^0.4.24;
// pragma experimental ABIEncoderV2;

// last implemented contract: 0x70ae5b30c81d00cc4b6cbe765a71ab89e35d2cc4
contract GeneralService {
    
    string public companyName;
    uint8 public USER_DATA_COUNT = 10;
    // 0: low risk, 1: medium risk, 2: high risk
    uint8 public RISK_LEVEL_COUNT = 3;
    
    mapping(address => uint256) availableServicesByUser;
    mapping(address => uint256) activeServicesByUser;
    
// ---------------------------- Service Preview --------------------------------
    
    function getNumberOfServices()
        public view returns(uint256) ;
    
    function getService(uint8 _serviceIndex)
        public view returns(string, uint256);
    
    function isServiceActive(uint8 _serviceIndex)
        public view returns(bool);
    
    function getAvailbleServices()
        public view returns(uint256) {
      return availableServicesByUser[msg.sender];
    }
    
    function getActiveServices()
        public view returns(uint256) {
      return activeServicesByUser[msg.sender];
    }

    /**
     * Data Authorization API
     *
     * The users' data will be permitted and accessible to an
     *  organization or institution, instead of the specific service
     *  in it. It's a straight-forward sense and simpilify the process
     *  logic in the interaction between users' wearable devices and
     *  the smart contract.
     *
     * @return uint:data category
     *    The authorization levels of necessary data access for all
     *    the services in this company.
     **/
    function authRequest() public pure returns(uint);
    
    
    // --- service AI inferences --- 
    function requestAuthorisation(
        address _clientAddr,
        uint256 _categories) public;
    
    function getAvailbleServices(
        address _userAddr,
        address _modelHash) public returns(uint256);
    
    function getUserData(uint _dataCategory) internal;

// -------------------------- Service Purchase ---------------------------------
    
    function purchaseService(uint256 _serviceIndex)
        public payable;

// -------------------------- Warranty Service ---------------------------------
    
    function checkCurrentHealthCondition(address _userAddr)
        public pure returns(bool);
}

