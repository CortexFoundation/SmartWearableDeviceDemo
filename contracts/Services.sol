pragma solidity ^0.4.18;
// pragma experimental ABIEncoderV2;

contract GeneralService {
    
    struct Service{
        string name;
        uint256 riskThreshold;
        uint256 fee;
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
    mapping(address => uint256) public activeServices;
    
    modifier moderatorOnly() {
        require(msg.sender == moderator, "Moderator Only");
        _;
    }
    
    constructor() public {
        moderator = msg.sender;
        // test only
        services.push(Service("1", 5, 1));
        services.push(Service("2", 7, 2));
        services.push(Service("3", 15, 3));
    }
    
    function updateCompanyName(string _newName) public moderatorOnly {
        companyName = _newName;
    }
    
    // --- moderator functions --- 
    function addService(string _name, uint256 _riskThreshold) public moderatorOnly {
        services.push(Service(_name, _riskThreshold, 0));
    }
    
    function updateService(uint256 _index, string _newName, uint256 _riskThreshold) public moderatorOnly {
        services[_index].name = _newName;
        services[_index].riskThreshold = _riskThreshold;
    }
    
    // --- getters --- 
    function getNumberOfServices() public view returns(uint256) {
        return services.length;
    }
    
    function isServiceActive(address _userAddr, uint256 _serviceIndex) public view returns(bool){
        if((availableServicesByUser[_userAddr] >> _serviceIndex & 1) == 1){
            return true;
        }
        return false;
    }
    
    // --- service AI inferences --- 
    // use compressed integer for requesting caterories
    // e.g., 0101 => cat 3 & 1
    function requestAuthorisation(address _clientAddr, uint256 _categories) public {
        
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
        inputData = new uint256[](1);
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
        activeServices[msg.sender] = activeServices[msg.sender] | (1 << _serviceIndex);
    }
}
