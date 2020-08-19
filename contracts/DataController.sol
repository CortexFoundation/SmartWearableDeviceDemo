pragma solidity ^0.4.18;

import "./Ownable.sol";
import "./SafeMath.sol";

contract dataController is Ownable {
    using SafeMath for uint256;
    //-------data storage structure
    //the heath information collect by wristband
    struct data {
        uint256 dataTimestamp;
        int8[28*28] Tdata; //low level feature data
    }
    //the data access log of information
    struct log {
        // string category;
        uint256 logTimestamp;
        string institutionName;
        uint8 cate; //what data has been visited,eg. 111, all 
    }

    struct person {
        bool exist;   //indicate that if has been register
        string name;
        data[] datas;
        log[] hospitalLogs;
        log[] insuranceLogs;
        //TODO: or use eg. 00001
        mapping(address => mapping(string => license)) permission; //the second string represent the dataCategorory
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
    
    //categorty of institution
    mapping (uint8 => string) numToCategory;
    uint256 INT_MAX = 2**256 - 1;

    uint8 NUMCATE = 3;  //number of institution category
    uint period = 5; //block number to time of permission
    string [NUMCATE] dataCategory = ["data","hospitalLog", "insuranceLog"];
    //every insurance contract has its own address;
    mapping (string => address) insuranceAddress;
    mapping (address => person) personInfo;
    mapping (address => institution) institutionInfo;

    event accessSuccess(address _address);

    modifier existOnly() {
        require(personInfo[msg.sender].exist == true, 
        "not register yet!");
        _;
    }
    modifier withPermit(address _address,uint8 category) {
        string memory c = numToCategory[category];
        license storage tlicense = personInfo[_address].permission[msg.sender][c]; 
        require(tlicense.existTime.add(5) < block.number, "not allowed to access the data");
        _;
    }

    constructor() public {
        numToCategory[1] = "data";  // 001--data allow
        numToCategory[2] = "hospitalLog";   //010--hospital record allow
        numToCategory[4] = "insuranceLog"; //100--insurance company record allow

    }

    //-------interface for people
    //register for self
    function registerPerson(string calldata name) public {
        person storage p = personInfo[msg.sender];
        p.exist = true;
        p.name = name;
    }
    //upload the data collect
    function uploadData(string calldata cData) public existOnly {
        data storage tData;
        tData.Tdata = cData;
        tData.dataTimestamp = block.timestamp;
        personInfo[msg.sender].datas.push(tData);
    }

    //grant acess to institution & change permission
    function authorize(address _iAddress,uint8 au,uint start,uint end) public existOnly {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if((au>>i) & 1) {
                string category = numToCategory[1 << i];
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

    //--------interface for insurance

    function registerInstitution(string calldata name, string calldata category) public {
        institution storage i = institutionInfo[msg.sender];
        i.exist = true;
        i.name = name;
        i.categorty = category;
    }

    //get the number of data struct
    function getDataNum(string calldata dataCategory,address people) public view withPermit(people,dataCategory) returns(uint){
        if(keccak256(abi.encodePacked(dataCategory)) == keccak256(abi.encodePacked("data"))) {
            return personInfo[people].datas.length;
        } else if(keccak256(abi.encodePacked(dataCategory)) == keccak256(abi.encodePacked("hospitalLog"))) {
            return personInfo[people].hospitalLogs.length;
        } else if(keccak256(abi.encodePacked(dataCategory)) == keccak256(abi.encodePacked("insuranceLog"))) {
            return personInfo[people].insuranceLog.length;
        } else {
            revert("wrong dataCategory");
        }
    }
    //get the health data
    //if access success,first return index(>0),or return 0
    function accessData(uint8 dataCategory,string calldata name,
                        string category, address people,uint index) public view withPermit(people,dataCategory)returns(uint, uint8[28*28]){
        require(personInfo[people].exist == true, "people don't exist");
        dataLog(dataCategory,category,name,people);
        data tdata = personInfo[people].datas[index];
        string memory c = numToCategory[category];
        license storage tlicense = personInfo[people].permission[msg.sender][c];
        if(timeFilter(tdata.dataTimestamp,tlicense.start,tlicense.end)) {
            return (index,tdata.Tdata);
        } else {
            return (0,tdata.Tdata);
        }
    }

    //get the log
    //if access success,first return index(>0),or return 0
    function accessLog(uint8 category, string calldata name, address people) public view withPermit(people,category) returns(uint8,string,uint8){
        require(personInfo[people].exist == true, "don't exist");
        dataLog(dataCategory,category,name,people);
        if(category == 2) {
            log tlog = personInfo[people].hospitalLogs[index];
            string memory c = numToCategory[category];
            license storage tlicense = personInfo[people].permission[msg.sender][c];
            if(timeFilter(tdata.dataTimestamp,tlicense.start,tlicense.end)) {
                return (index, tlog.institutionName, tlog.cate);
            } else {
                return (0, tlog.institutionName, tlog.cate);
            }
        } else if(category == 4) {
            log tlog = personInfo[people].insuranceLogs[index];
            string memory c = numToCategory[category];
            license storage tlicense = personInfo[people].permission[msg.sender][c];
            if(timeFilter(tdata.dataTimestamp,tlicense.start,tlicense.end)) {
                return (index, tlog.institutionName, tlog.cate);
            } else {
                return (0, tlog.institutionName, tlog.cate);
            }
        } else {
            revert("wrong dataCategory");
        }
    }

    //every insurance service has its own contract address
    function setInsuranceInstance(string calldata name, address _address) public onlyOwner {
        insuranceAddress[name] = _address;
    }

    function getInstitutionName(address _address) public view returns(string memory){
        require(institutionInfo[_address].exist == true, "this institution not exist");
        return institutionInfo[_address].name;
    }

    //-------basic function
    //cancel the permission of data access for institution
    function deauthorize(address _iAddress, uint8 au) internal {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if(((au>>i) & 1) == 0) {
                string category = numToCategory[1 << i];
                license storage tlicense = personInfo[msg.sender].permission[_iAddress][category];
                tlicense.existTime = INT_MAX;
            }
        }
    }
    //record who has access the person's data
    function dataLog(uint8 dataCategory,string calldata category,string calldata name, address people) internal {
        require(personInfo[people].exist == true, "don't exist");
        log storage tlog;
        tlog.cate.add(dataCategory);
        tlog.category = category;
        tlog.institutionName = name;
        tlog.logTimestamp = block.timestamp;
        if (keccak256(abi.encodePacked(category)) == keccak256(abi.encodePacked("hospital"))) {
            personInfo[people].hospitalLogs.push(tlog);
        }else if (keccak256(abi.encodePacked(category)) == keccak256(abi.encodePacked("insurance"))) {
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
    // function logArrange(uint8 dataCategory) internal {

    // }
}