pragma solidity ^0.4.18;

import "./Ownable.sol";
import "./SafeMath.sol";

contract dataController is Ownable {
    using SafeMath for uint256;

// -------------------------- Pre-defined Structure ----------------------------

    // the heath information collect by wristband
    struct data {
        uint256 dataTimestamp;
        uint8[28*28] Tdata; // low level feature data
    }
    // the data access log of information
    struct log {
        string category;
        uint256 logTimestamp;
        string institutionName;
        uint cate; // what data has been visited,eg. 111, all 
    }

    struct person {
        bool exist;   // indicate that if has been register
        string name;
        data[] datas;
        log[] hospitalLogs;
        log[] insuranceLogs;
        // TODO: or use eg. 00001
        mapping(address => mapping(string => license)) permission; // the second string represent the dataCategorory
    }

    struct license {
        uint existTime;
        // the permission of the duration data 
        uint start;
        uint end;
    }

    struct institution {
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
    string [NUMCATE] dataCategory = ["data","hospitalLog", "insuranceLog"];
    // every insurance contract has its own address;
    mapping (string => address) insuranceAddress;
    mapping (address => person) personInfo;
    mapping (address => institution) institutionInfo;

    event accessSuccess(address _address);

    modifier existOnly() {
        require(personInfo[msg.sender].exist == true, 
        "not register yet!");
        _;
    }
    modifier withPermit(address _address,uint category) {
        string memory c = numToCategory[category];
        license storage tlicense = personInfo[_address].permission[msg.sender][c]; 
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
        person storage p = personInfo[msg.sender];
        p.exist = true;
        p.name = name;
    }
    // upload the data collect
    function uploadData(uint8[28*28] cData) public existOnly {
        data storage tData;
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
    function authorize(address _iAddress,uint au,uint start,uint end) public existOnly {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if((au>>i) & 1 == 1) {
                string category = numToCategory[uint(1) << i];
                license storage tlicense = personInfo[msg.sender].permission[_iAddress][category];
                tlicense.existTime = block.number;
                tlicense.start = start;
                tlicense.end = end;
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


    function registerInstitution(string name, string category) public {
        institution storage i = institutionInfo[msg.sender];
        i.exist = true;
        i.name = name;
        i.category = category;
    }

    //get the number of data struct
    function getDataNum(uint dataCategory,string Category,address people) public view withPermit(people,dataCategory) returns(uint){
        if(keccak256(abi.encodePacked(dataCategory)) == keccak256(abi.encodePacked("data"))) {
            return personInfo[people].datas.length;
        } else if(keccak256(abi.encodePacked(dataCategory)) == keccak256(abi.encodePacked("hospitalLog"))) {
            return personInfo[people].hospitalLogs.length;
        } else if(keccak256(abi.encodePacked(dataCategory)) == keccak256(abi.encodePacked("insuranceLog"))) {
            return personInfo[people].insuranceLogs.length;
        } else {
            revert("wrong dataCategory");
        }
    }
    // get the health data
    // if access success,first return index(>0),or return 0
    function accessData(uint dataCategory,string name,
                        string category, address people,uint index) public view withPermit(people,dataCategory)returns(uint, uint8[28*28]){
        require(personInfo[people].exist == true, "people don't exist");
        dataLog(dataCategory,category,name,people);
        data tdata = personInfo[people].datas[index];
        string memory c = numToCategory[dataCategory];
        license storage tlicense = personInfo[people].permission[msg.sender][c];
        if(timeFilter(tdata.dataTimestamp,tlicense.start,tlicense.end)) {
            return (index,tdata.Tdata);
        } else {
            return (0,tdata.Tdata);
        }
    }

    // get the log
    // if access success,first return index(>0),or return 0
    //TODO : the stack is too deep,split this function
    function accessLog(uint dataCategory, string category,string name, address people, uint index) public view withPermit(people,dataCategory) returns(uint,string,uint){
        require(personInfo[people].exist == true, "don't exist");
        dataLog(dataCategory,category,name,people);
        if(dataCategory == 2) {
            log tlog = personInfo[people].hospitalLogs[index];
            string memory c = numToCategory[dataCategory];
            license storage tlicense = personInfo[people].permission[msg.sender][c];
            if(timeFilter(tlog.logTimestamp,tlicense.start,tlicense.end)) {
                return (index, tlog.institutionName, tlog.cate);
            } else {
                return (0, tlog.institutionName, tlog.cate);
            }
        } else if(dataCategory == 4) {
            log tlog2 = personInfo[people].insuranceLogs[index];
            string memory c2 = numToCategory[dataCategory];
            license storage tlicense2 = personInfo[people].permission[msg.sender][c2];
            if(timeFilter(tlog2.logTimestamp,tlicense2.start,tlicense2.end)) {
                return (index, tlog2.institutionName, tlog2.cate);
            } else {
                return (0, tlog2.institutionName, tlog.cate);
            }
        } else {
            revert("wrong dataCategory");
        }
    }

    // every insurance service has its own contract address
    function setInsuranceInstance(string  name, address _address) public onlyOwner {
        insuranceAddress[name] = _address;
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
                license storage tlicense = personInfo[msg.sender].permission[_iAddress][category];
                tlicense.existTime = INT_MAX;
            }
        }
    }
    // record who has access the person's data
    function dataLog(uint dataCategory,string category,string name, address people) internal {
        require(personInfo[people].exist == true, "don't exist");
        log storage tlog;
        tlog.cate.add(dataCategory);
        tlog.category = category;
        tlog.institutionName = name;
        tlog.logTimestamp = block.timestamp;
        if (keccak256(abi.encodePacked(dataCategory)) == keccak256(abi.encodePacked("hospital"))) {
            personInfo[people].hospitalLogs.push(tlog);
        }else if (keccak256(abi.encodePacked(dataCategory)) == keccak256(abi.encodePacked("insurance"))) {
            personInfo[people].insuranceLogs.push(tlog);
        }
    }
    
    function timeFilter(uint ttime,uint start,uint end) internal view returns(bool) {
         if(ttime < start || ttime > end) {
             return false;
         } else {
             return true;
         }
    }

    //TODO : the timestamp problem 
    // function logArrange(uint dataCategory) internal

}