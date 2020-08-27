pragma solidity ^0.4.24;

import "./Institution.sol";
import "./SafeMath.sol";
import "./DataController.sol";

// 0xb3643de74ad45387cd92320508ea6efd87d5de43
contract XiHongShiInsurance is Insurance {
    using SafeMath for uint;
    
    address public modelAddress = 0xfc1488AaCB44f7E94C7FcC19E7684219673902AB;
    uint256 EXPONENTIAL = 10**18;
    uint8 public USER_DATA_COUNT = 10;
    // 0: low risk, 1: medium risk, 2: high risk
    uint8 public RISK_LEVEL_COUNT = 3;
    
    // Service structure for this insruance company.
    // other companies might have different structures
    struct Service{
        string name;
        string statement;
        string notes;
        uint256 riskThreshold;
        // This fee is set to constant for this demo only.
        // Could be adjusted based on user's condition in future update.
        uint256 fee;
        uint256 payment;
    }
    
    Service[] services;

    mapping(address => uint256[]) inputs;
    
    constructor() public payable {
        companyName = "XiHongShi Insurance";
        services.push(
            Service(
                "Happiness", 
                "Cover some daily activities.",
                "For older people",
                5, 1 * EXPONENTIAL, 10 * EXPONENTIAL
            )
        );
        services.push(
            Service(
                "Hardworking",  
                "Cover most daily activities.",
                "For mid age people", 
                7, 2 * EXPONENTIAL, 20 * EXPONENTIAL
            )
        );
        services.push(
            Service(
                "Excitement",  
                "Cover extreme activities.",
                "For younger people", 
                15, 3 * EXPONENTIAL, 30 * EXPONENTIAL
            )
        );
    }
    
    // --- moderator functions ---
    // Moderator functions to check it's users' data
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
    
    // Add new service to this institution.
    function addService(
        string _name, 
        string _statement,
        string _notes,
        uint256 _riskThreshold, 
        uint256 _fee,
        uint256 _payment
    ) 
        public 
        onlyOwner 
    {
        services.push(Service(_name, _statement, _notes, _riskThreshold, _fee, _payment));
    }
    
    // Update existing service for this institution
    function updateService(
        uint256 _index, 
        string _newName, 
        string _statement,
        string _notes,
        uint256 _riskThreshold, 
        uint256 _fee,
        uint256 _payment
    ) 
        public 
        onlyOwner 
    {
        services[_index].name = _newName;
        services[_index].statement = _statement;
        services[_index].notes = _notes;
        services[_index].riskThreshold = _riskThreshold;
        services[_index].fee = _fee;
        services[_index].payment = _payment;
    }
    
    // Delete existing service for this institution
    function removeService(uint256 _index) public onlyOwner {
        if(_index == services.length - 1) {
            delete services[services.length - 1];
            --services.length;
            return;
        }
        services[_index] = services[services.length - 1];
        delete services[services.length - 1];
        --services.length;
    }
    
    // --- getters --- 
    // Below are the getter implementations for this institution
    function getRequiredPermissions() public view returns(uint256){
        return 3;
    }
    
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
    
    function getServiceInformation(uint8 _serviceIndex)
        public 
        view 
        returns(
            string,  // service name
            string,  // statement
            string,  // notes
            uint256, // riskThreshold
            uint256, // service fee
            uint256  // payment
        )
    {
        return (
            services[_serviceIndex].name, 
            services[_serviceIndex].statement,
            services[_serviceIndex].notes,
            services[_serviceIndex].riskThreshold,
            services[_serviceIndex].fee,
            services[_serviceIndex].payment
        );
    }
    
    // --- service AI inferences --- 
    // Function implementation for this institution
    function checkForAvailableServices(address _userAddr) public {
        // infer risk factor based on user's physical data
        uint256[] memory infer_output = new uint256[](3);
        uint256 overallRisk = 0;
        uint256 dataCount = DataController(dataControllerAddress).getPersonDataLen(_userAddr);
        if(USER_DATA_COUNT < dataCount){
            dataCount = USER_DATA_COUNT;
        }
        for(uint i = 0; i < dataCount; ++i){
            // uint256[] memory inputData2 = getUserData2(_userAddr,1,i);
            // category 1: user data
            getUserData(_userAddr, i);
            inferArray(modelAddress, inputs[_userAddr], infer_output);
            uint256 riskFactor = infer_output[0];
            uint256 riskIndex = 0;
            for(uint j = 1; j < RISK_LEVEL_COUNT; ++j){
                if(infer_output[j] > riskFactor){
                    riskFactor = infer_output[j];
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
    
    // Access user's physical data from the DataController contract.
    // Used for AI inference
    function getUserData(address _userAddr, uint _index) internal{
        inputs[_userAddr] = DataController(dataControllerAddress).accessStatistic(
            _userAddr, 
            _index
        );
    }
    
    // --- purchase services --- 
    // function implementation for this institution
    function purchaseService(uint256 _serviceIndex) public payable {
        require(
            ((availableServicesByUser[msg.sender] >> _serviceIndex) & 1) == 1,
            "Not qualified"
        );
        require(msg.value >= services[_serviceIndex].fee, "Insufficient payment");
        if(msg.value > services[_serviceIndex].fee){
            // refund excess payment
            msg.sender.transfer(msg.value - services[_serviceIndex].fee);
        }
        activeServicesByUser[msg.sender] = 
            activeServicesByUser[msg.sender] | (1 << _serviceIndex);
        DataController(dataControllerAddress).saveReceipt(
            msg.sender,
            block.timestamp,
            generateReceipt(msg.sender, _serviceIndex)
        );
    }
    
    // After user has successfully purchased a service, this institution will 
    // write a receipt to the DataController contract as a record
    function generateReceipt(
        address _userAddr, 
        uint256 _serviceIndex
    ) 
        internal 
        pure 
        returns(uint256[25])
    {
        uint256[25] memory receipt;
        receipt[0] = uint256(keccak256(_userAddr));
        for(uint8 i = 1; i < 25; ++i){
            receipt[i] = receipt[i - 1] + _serviceIndex;
        }
        return receipt;
    }
    
    // Use AI inference to check user's current health condition.
    // used for insurance payment 
    // @return bool: true for valid for payment, vice versa
    function checkCurrentHealthCondition(address _userAddr) internal returns(bool){
        // For this demo, we are using user's data for checking user's health condition
        // in the future, it would require receipt from the hospital/other institutions
        getUserData(_userAddr, 0);
        uint256[] memory infer_output = new uint256[](3);
        inferArray(modelAddress, inputs[_userAddr], infer_output);
        uint256 riskFactor = infer_output[0];
        uint256 riskIndex = 0;
        for(uint i = 1; i < RISK_LEVEL_COUNT; ++i){
            if(infer_output[i] > riskFactor){
                riskFactor = infer_output[i];
                riskIndex = i;
            }
        }
        if(riskIndex == 0){
            return true;
        }
        return false;
    }
    
    // Function implementation for this institution
    function payment(uint256 _serviceIndex) public {
        require(checkCurrentHealthCondition(msg.sender), 
            "User health condition not valid for payment");
        if(isServiceActiveByUser(msg.sender, _serviceIndex)){
            require(
                address(this).balance >= services[_serviceIndex].payment, 
                "Insufficient fund"
            );
            msg.sender.transfer(services[_serviceIndex].payment);
        }
        else{
            revert();
        }
        activeServicesByUser[msg.sender] = 
            activeServicesByUser[msg.sender] ^ (1 << _serviceIndex);
    }
}
