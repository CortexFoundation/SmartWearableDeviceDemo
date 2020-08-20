pragma solidity ^0.4.18;

import "./Ownable.sol";
import "./SafeMath.sol";

contract DataController is Ownable {
    using SafeMath for uint256;

// -------------------------- Pre-defined Structure ----------------------------

    // the heath information collect by wristband
    struct Data {
        // when upload the data
        uint256 dataTimestamp;
        // low level feature data
        uint8[28*28] Tdata; 
    }
    // the data access log of information
    struct Log {
        // the category of institution who access the information
        string category;  
        // when access the data
        uint256 logTimestamp;   
        // the name of the institution who access the information
        string institutionName; 
        // what data has been visited,[001 -- data,010 -- hospitalLog, 100 -- insuranceLog]
        uint cate;  
    }
    
    struct License {
        // when get the license using blkNumber
        uint existTime;
        // time period of data that can be accessed,[start,end]
        uint start;
        uint end;
    }

    struct Person {
        // indicate that if has been register
        bool exist;   
        string name;
        Data[] datas;
        Log[] hospitalLogs;
        Log[] insuranceLogs;
        // inside the second mapping (the second string represent the types of data)
        mapping(address => mapping(string => License)) permission; 
    }

    struct Institution {
        bool exist;
        string name;
        string category;
    }


// ----------------------------- Private Members -------------------------------

    // categorty of institution
    mapping (uint => string) numToCategory;
    uint256 INT_MAX = 2**256 - 1;
    uint constant NUMCATE = 3;
    uint period = 5; // block number to time of permission
    string [NUMCATE] dataCategories = ["data","hospitalLog", "insuranceLog"];
    // every insurance contract has its own address;
    mapping (string => address) insuranceAddress;
    mapping (address => Person) personInfo;
    mapping (address => Institution) institutionInfo;

    modifier existOnly() {
        require(personInfo[msg.sender].exist == true, 
        "not register yet!");
        _;
    }
    modifier withPermit(address _address,uint _category) {
        string memory c = numToCategory[_category];
        License storage tlicense = personInfo[_address].permission[msg.sender][c]; 
        require(tlicense.existTime.add(5) < block.number, "not allowed to access the data");
        _;
    }

    constructor() public {
        numToCategory[1] = "data";  // 001--data allow
        numToCategory[2] = "hospitalLog";   // 010--hospital record allow
        numToCategory[4] = "insuranceLog"; // 100--insurance company record allow

    }


// ------------------------- Contract Authorization ----------------------------

		/**
		 * Contract Authorization API (TODO)
		 *
		 * We need some extended permission management mechanism, such as
		 *	the `registerUser` permission may authorize another organization.
		 **/
	

// ----------------------------- User Interface --------------------------------

		/**
		 * User Data Register API
		 *
		 * According to the privacy of users' requirements, we only accept the
		 *	data of users who have the consistent face features extracted from
		 *	local AI model in the credible and secure wearable device.
		 *
		 * In fact, the user devices may connect the blockchain via a optional
		 *	intermediate layer, that is our server stack, which never stores
		 *	the user privacy data and will use the blockchain as the backend
		 *	database. The server plays a part for authorization mainly:
		 *
		 *	- Data forwarding between the users' wearable devices and blockchain.
		 *	- User validating for the correct face features and identifier address.
		 *
		 * The server register uses the indentifier as the storage map key. User
		 *	would change the address after some time for privacy protection and
		 *	need to re-register the public address with validating the user 
		 *	pre-set name.
		 **/

    // register for self
    function registerUser(string name) public onlyOwner {
        Person storage p = personInfo[msg.sender];
        p.exist = true;
        p.name = name;
    }
    // upload the data collect
    function uploadData(uint8[28*28] cData) public existOnly {
        Data storage tData;
        // for (uint i = 0; i < 28*28; i++) {
        //     tData.Tdata[i] = cData[i];
        // }
        tData.Tdata = cData;
        tData.dataTimestamp = block.timestamp;
        personInfo[msg.sender].datas.push(tData);
    }

		/**
		 * Authorization API
		 *
		 * We design the autorization with a period of time, instead of
		 *	the number of calls. And the personal body features will
		 *	be registered with different address and the same name.
		 * 
		 *	It's strange to request the user to deauthorize the permission
		 *	manually.
		 * 
		 *	blkNumber = block.number
		 **/

    // grant acess to institution & change permission
    function authorize(
        address _iAddress,
        uint _au,
        uint _start,
        uint _end
        ) 
        public 
        existOnly 
    {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if((_au>>i) & 1 == 1) {
                string storage category = numToCategory[1 << i];
                License storage tlicense = personInfo[msg.sender].permission[_iAddress][category];
                tlicense.existTime = block.number;
                tlicense.start = _start;
                tlicense.end = _end;
            }
        }
    }

    //user cacel the permission of all the category data access
    function personDeauthorize(address _iAddress) public existOnly {
        deauthorize(_iAddress,0); // 000 cacel all the data
    }

    function cacelData() public existOnly {
        delete personInfo[msg.sender];
    }
// --------------------------- Service Interface -------------------------------


    function registerInstitution(string _name, string _category) public {
        Institution storage i = institutionInfo[msg.sender];
        i.exist = true;
        i.name = _name;
        i.category = _category;
    }

    //get the number of data struct
    function getDataNum(
        uint _dataCategory,
        string _category,
        address _peopleAddress
    ) 
        public 
        view
        withPermit(_peopleAddress,_dataCategory)
        returns(uint)
    {
        if(keccak256(abi.encodePacked(_category)) == keccak256(abi.encodePacked("data"))) {
            return personInfo[_peopleAddress].datas.length;
        } else if(keccak256(abi.encodePacked(_category)) == keccak256(abi.encodePacked("hospitalLog"))) {
            return personInfo[_peopleAddress].hospitalLogs.length;
        } else if(keccak256(abi.encodePacked(_category)) == keccak256(abi.encodePacked("insuranceLog"))) {
            return personInfo[_peopleAddress].insuranceLogs.length;
        } else {
            revert("wrong dataCategory");
        }
    }
    
    // get the health data
    // if access success,first return index(>0),or return 0
    function accessData(
        uint _dataCategory,
        address _peopleAddress,
        uint _index
    ) 
        public 
        view 
        withPermit(_peopleAddress,_dataCategory)
        returns(uint, uint8[28*28])
    {
        require(personInfo[_peopleAddress].exist == true, "people don't exist");
        recordDataAcess(1,_peopleAddress); // 001 -- data
        Data tdata = personInfo[_peopleAddress].datas[_index];
        string memory c = numToCategory[_dataCategory];
        License storage tlicense = personInfo[_peopleAddress].permission[msg.sender][c];
        if(timeFilter(tdata.dataTimestamp,tlicense.start,tlicense.end)) {
            return (_index,tdata.Tdata);
        } else {
            return (0,tdata.Tdata);
        }
    }

    // get the log
    // if access success,first return index(>0),or return 0
    //TODO : the stack is too deep,split this function
    function accessHospitalLog(
        uint _dataCategory, 
        address _peopleAddress, 
        uint _index
    ) 
        public 
        view 
        withPermit(_peopleAddress,_dataCategory) 
        returns(uint,string,uint)
    {
        require(personInfo[_peopleAddress].exist == true, "don't exist");
        recordDataAcess(2,_peopleAddress); // 010 -- hospital
        Log tlog = personInfo[_peopleAddress].hospitalLogs[_index];
        string memory c = numToCategory[_dataCategory];
        License storage tlicense = personInfo[_peopleAddress].permission[msg.sender][c];
        if(timeFilter(tlog.logTimestamp,tlicense.start,tlicense.end)) {
            return (_index, tlog.institutionName, tlog.cate);
        } else {
            return (0, tlog.institutionName, tlog.cate);
        }
    }
    
    function accessInsuranceLog(
        uint _dataCategory,
        address _peopleAddress, 
        uint _index
    ) 
        public 
        view 
        withPermit(_peopleAddress,_dataCategory) 
        returns(uint,string,uint)
    {
        require(personInfo[_peopleAddress].exist == true, "don't exist");
        recordDataAcess(4,_peopleAddress); //100 -- insurance
        Log tlog = personInfo[_peopleAddress].insuranceLogs[_index];
        string memory c = numToCategory[_dataCategory];
        License storage tlicense = personInfo[_peopleAddress].permission[msg.sender][c];
        if(timeFilter(tlog.logTimestamp,tlicense.start,tlicense.end)) {
            return (_index, tlog.institutionName, tlog.cate);
        } else {
            return (0, tlog.institutionName, tlog.cate);
        }
    }

    // every insurance service has its own contract address
    function setInsuranceInstance(string _name, address _address) public onlyOwner {
        insuranceAddress[_name] = _address;
    }

    function getInstitutionName(address _address) public view returns(string memory){
        require(institutionInfo[_address].exist == true, "this institution not exist");
        return institutionInfo[_address].name;
    }



// ---------------------------- Helper Functions -------------------------------


    // function pur;

    // cancel the permission of data access for institution
    function deauthorize(address _iAddress, uint au) internal {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if(((au>>i) & 1) == 0) {
                string category = numToCategory[1 << i];
                License storage tlicense = personInfo[msg.sender].permission[_iAddress][category];
                tlicense.existTime = INT_MAX;
            }
        }
    }
    // record log of  access the  data
    function recordDataAcess(uint _dataCategory,address _peopleAddress) internal {
        require(personInfo[_peopleAddress].exist == true, "don't exist");
        Log storage tmplog;
        tmplog.cate = _dataCategory;
        tmplog.category = institutionInfo[msg.sender].category;
        tmplog.institutionName = institutionInfo[msg.sender].name;
        tmplog.logTimestamp = block.timestamp;
        if (keccak256(abi.encodePacked(tmplog.category)) == keccak256(abi.encodePacked("hospital"))) {
            personInfo[_peopleAddress].hospitalLogs.push(tmplog);
        }else if (keccak256(abi.encodePacked(tmplog.category)) == keccak256(abi.encodePacked("insurance"))) {
            personInfo[_peopleAddress].insuranceLogs.push(tmplog);
        }
    }
    
    function timeFilter(
        uint _tmpTime,
        uint _start,
        uint _end
    ) 
    internal 
    pure 
    returns(bool) 
    {
        if(_tmpTime < _start || _tmpTime > _end) {
            return false;
        } else {
            return true;
        }
    }

    //TODO : the timestamp problem 
    // function logArrange(uint dataCategory) internal

}