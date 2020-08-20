pragma solidity ^0.4.24;
import "./Service.sol";

contract InsuranceService is GeneralService {
    
    // service structure for this insruance company.
    // other companies might have different structure
    struct Service{
        string name;
        uint256 riskThreshold;
        uint256 fee;
        uint256 payment;
    }
    
    address public moderator;
    Service[] services;
    uint256[] public inputData;
    
    constructor() public {
        moderator = msg.sender;
        companyName = "XiHongShi Insurance";
        services.push(Service("1", 5, 1, 10));
        services.push(Service("2", 7, 2, 20));
        services.push(Service("3", 15, 3, 30));
    }
    
    modifier moderatorOnly() {
        require(msg.sender == moderator, "Moderator Only");
        _;
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
    
    function getService(uint8 _serviceIndex) public view returns(string, uint256) {
        return (services[_serviceIndex].name, services[_serviceIndex].fee);
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
    // used for insurance payment 
    function checkCurrentHealthCondition(address _userAddr) public pure returns(bool){
        if(_userAddr == address(0)){
            return true;
        }
        else{
            return false;
        }
    }
}