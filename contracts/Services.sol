pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

// last implemented contract: 0x70ae5b30c81d00cc4b6cbe765a71ab89e35d2cc4
contract GeneralService {
    using SafeMath for uint;
    struct Service{
        string name;
        uint256 riskThreshold;
        uint256 fee;
        uint256 payment;
    }
    
    // address public modelAddr = 0xe2d50CFb680ffD3E39a187ae8C22B4f81b092A10;
    string public companyName = "XiHongShi Insurance";
    address public moderator;
    Service[] public services;
    uint256[] public inputData;
    uint8 public USER_DATA_COUNT = 10;
    // 0: low risk, 1: medium risk, 2: high risk
    uint8 public RISK_LEVEL_COUNT = 3;
    
    mapping(address => uint256) public availableServicesByUser;
    mapping(address => uint256) public activeServicesByUser;
    
    modifier moderatorOnly() {
        require(msg.sender == moderator, "Moderator Only");
        _;
    }
    
    constructor() public {
        moderator = msg.sender;
        // test only
        services.push(Service("1", 5, 1, 10));
        services.push(Service("2", 7, 2, 20));
        services.push(Service("3", 15, 3, 30));
    }
    
    function updateCompanyName(string _newName) public moderatorOnly {
        companyName = _newName;
    }
    
    // --- moderator functions --- 
    function addService(string _name, uint256 _riskThreshold, uint256 _fee, uint256 _payment) public moderatorOnly {
        services.push(Service(_name, _riskThreshold, _fee, _payment));
    }
    
    function updateService(uint256 _index, string _newName, uint256 _riskThreshold) public moderatorOnly {
        services[_index].name = _newName;
        services[_index].riskThreshold = _riskThreshold;
    }
    
    // TODO: check user's current health condition first,
    // require TRUE for payment
    function payment(address _userAddr, uint8 _serviceIndex) public moderatorOnly {
        if(isServiceActive(_userAddr, _serviceIndex)){
            _userAddr.transfer(services[_serviceIndex].payment);
        }
    }
    
    // --- getters --- 
    function getNumberOfServices() public view returns(uint256) {
        return services.length;
    }
    
    function getService(uint8 _serviceIndex) public view returns(Service) {
        return services[_serviceIndex];
    }
    
    function getAvaialbleServicesByUser(address _userAddr) public view returns(uint256){
        return availableServicesByUser[_userAddr];
    }
    
    function getActiveServicesByUser(address _userAddr) public view returns(uint256){
        return activeServicesByUser[_userAddr];
    }
    
    function isServiceActive(address _userAddr, uint8 _serviceIndex) public view returns(bool){
        if((availableServicesByUser[_userAddr] >> _serviceIndex & 1) == 1){
            return true;
        }
        return false;
    }
    
    // --- service AI inferences --- 
    // use compressed integer for requesting caterories
    // e.g., 0101 => cat 3 & 1
    function requestAuthorisation(address _clientAddr, uint256 _categories) public {
        _clientAddr = address(0);
        services[_categories] = Service("123", 2,2,4);
    }
    
    function getAvaialbleServices(address _userAddr, address _modelHash) public returns(uint256){
        // infer risk factor based on user's physical data
        uint256[] memory infer_output = new uint256[](1);
        uint256 overallRisk = 0;
        for(uint i = 0; i < USER_DATA_COUNT; ++i){
            getUserData(i);
            inferArray(_modelHash, inputData, infer_output);
            uint256 riskFactor = infer_output[0];
            uint256 riskIndex = 0;
            for(uint j = 1; j < RISK_LEVEL_COUNT; ++j){
                if(infer_output[i] > riskFactor){
                    riskFactor = infer_output[i];
                    riskIndex = j;
                }
            }
            overallRisk += riskIndex;
        }
        // evaluating the risk:
        uint256 availableServices = 0;
        for(i = 0; i < services.length; ++i){
            if(services[i].riskThreshold >= overallRisk){
                availableServices = availableServices | (1 << i);
            }
        }
        availableServicesByUser[_userAddr] = availableServices;
        return availableServices;
    }
    
    function getUserData(uint _dataCategory) internal {
        // FIXME: get user data from data contract
        inputData = new uint256[](_dataCategory);
    }
    
    
    // --- purchase services --- 
    function purchaseService(uint256 _serviceIndex) public payable {
        require(
            (availableServicesByUser[msg.sender] >> _serviceIndex & 1) == 1,
            "Not qualified"
            );
        require(msg.value >= services[_serviceIndex].fee, "Insufficient payment");
        if(msg.value > services[_serviceIndex].fee){
            // refund excess payment
            msg.sender.transfer(services[_serviceIndex].fee - msg.value);
        }
        activeServicesByUser[msg.sender] = activeServicesByUser[msg.sender] | (1 << _serviceIndex);
    }
    
    // get data from data contract
    // true 
    function checkCurrentHealthCondition(address _userAddr) public pure returns(bool){
        if(_userAddr == address(0)){
            return true;
        }
        else{
            return false;
        }
    }
}

// for future implementations
contract InsuranceService is GeneralService {
    
    constructor() public {
        
    }
    
}


library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b);

    return c;
  }

  /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}