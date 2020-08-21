pragma solidity ^0.4.24;

import "./Service.sol";
import "./SafeMath.sol";
import "./DataController.sol";

contract XiHongShiInsurance is Insurance {
    using SafeMath for uint;

    uint8 public USER_DATA_COUNT = 10;
    // 0: low risk, 1: medium risk, 2: high risk
    uint8 public RISK_LEVEL_COUNT = 3;
    
    // service structure for this insruance company.
    // other companies might have different structures
    struct Service{
        string name;
        uint256 riskThreshold;
        uint256 fee;
        uint256 payment;
    }
    
    Service[] services;
    uint256[] public inputData;
    
    constructor() public payable {
        companyName = "XiHongShi Insurance";
        services.push(Service("1", 5, 1, 10));
        services.push(Service("2", 7, 2, 20));
        services.push(Service("3", 15, 3, 30));
    }
    
    // --- moderator functions --- 
    function getAvaialbleServicesByUser(address _userAddr) 
        public view onlyOwner returns(uint256)
    {
        return availableServicesByUser[_userAddr];
    }
    
    function getActiveServicesByUser(address _userAddr) 
        public view onlyOwner returns(uint256)
    {
        return activeServicesByUser[_userAddr];
    }
    
    function isServiceActiveByUser(address _userAddr, uint256 _serviceIndex) 
        public view onlyOwner returns(bool)
    {
        if((availableServicesByUser[_userAddr] >> _serviceIndex & 1) == 1){
            return true;
        }
        return false;
    }
    
    function registerInstitution() public onlyOwner {
        DataController(dataControllerAddress).registerInstitution(
            companyName, 
            "Insurance"
        );
    }
    
    function addService(
        string _name, 
        uint256 _riskThreshold, 
        uint256 _fee, 
        uint256 _payment
    ) 
        public 
        onlyOwner 
    {
        services.push(Service(_name, _riskThreshold, _fee, _payment));
    }
    
    function updateService(
        uint256 _index, 
        string _newName, 
        uint256 _riskThreshold
    ) 
        public 
        onlyOwner 
    {
        services[_index].name = _newName;
        services[_index].riskThreshold = _riskThreshold;
    }
    
    function payment(address _userAddr, uint256 _serviceIndex) public onlyOwner {
        require(checkCurrentHealthCondition(_userAddr), 
            "User health condition not valid for payment");
        if(isServiceActiveByUser(_userAddr, _serviceIndex)){
            require(
                address(this).balance >= services[_serviceIndex].payment, 
                "Insufficient fund"
            );
            _userAddr.transfer(services[_serviceIndex].payment);
        }
        activeServicesByUser[msg.sender] = 
            activeServicesByUser[msg.sender] ^ (1 << _serviceIndex);
    }
    
    
    // --- getters --- 
    function getNumberOfServices() public view returns(uint256) {
        return services.length;
    }
    
    function getService(uint8 _serviceIndex) 
        public view returns(string, uint256) 
    {
        return (services[_serviceIndex].name, services[_serviceIndex].fee);
    }
    
    function isServiceActive(uint8 _serviceIndex) 
        public view returns(bool)
    {
        if((availableServicesByUser[msg.sender] >> _serviceIndex & 1) == 1){
            return true;
        }
        return false;
    }
    
    
    // --- service AI inferences --- 
    function checkForAvailbleServices(
        address _userAddr, 
        address _modelHash
    ) 
        public 
    {
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
    }
    
    function getUserData(uint _dataCategory) internal {
        // FIXME: check arguments
        uint index = 1;
        (index, inputData) = DataController(
            dataControllerAddress).accessData(_dataCategory, 
            address(this), 
            index
        );
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
        activeServicesByUser[msg.sender] = 
            activeServicesByUser[msg.sender] | (1 << _serviceIndex);
    }
    
    // TODO: implement
    // get data from data contract, used for insurance payment 
    function checkCurrentHealthCondition(address _userAddr) public returns(bool);
}
