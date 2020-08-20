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
        uint8[28*28] metaData; 
    }

    // the data access log of user's data
    struct Log {
        // the category of institution who access the user data
        string category;  
        // when access the data
        uint256 logTimestamp;   
        // the name of the institution who access the information
        string institutionName; 
        // what data has been visited,[001 -- data,010 -- hospitalLog, 100 -- insuranceLog]
        uint cate;  
    }

    // the feedback for service actions
    struct Feedback {
      uint256 startTs; // start timestamp
      uint256 stopTs; // stop timestamp

      /**
       * Encoded Feedback API
       *
       * It's an public feedback after performing server, such as the
       *  insurance purchase, claim, ..., etc. We will define the feedback
       *  data encoder via communicating with all the service suppliers.
       **/
      uint8[28*28] encodedData; // the encoded feedback for service
    }
    
    struct License {
        // when get the license (using blkNumber)
        uint existTime;
        // time period of data that can be accessed,[start,end]
        uint start;
        uint end;
        //show what kind of data access is allowed.
        mapping (string => bool) permission;
    }

    struct Person {
        // indicate that if has been register
        bool exist;   
        string name;
        Data[] datas;
        Log[] hospitalLogs;
        Log[] insuranceLogs;
        // what is allowed to a institution
        mapping(address => License) permissionList; 
    }

    struct Institution {
        bool exist;
        string name;
        //now just 2 : hospital and insurance
        string category;
    }

// --------------------------------- Event -------------------------------------

    event registerSuccess(address _peopleAddress);


// ----------------------------- Private Members -------------------------------

    // categorty of data
    mapping (uint => string) numToCategory;
    uint256 INT_MAX = 2**256 - 1;
    // the number of data & log category,temporarily is 3
    uint constant NUMCATE = 3;
    // time period the number of the block
    uint constant PERIODBLOCK = 5;
    uint period = 5; // block number to time of permission
    // every insurance contract has its own address;
    mapping (string => address) insuranceAddress;
    // all the data about people
    mapping (address => Person) private personInfo;
    // all the data about institution
    mapping (address => Institution) private institutionInfo;
    
    // storage the information temporarily
    // Data private dataCache;
    // Log private logCache;

    constructor() public {
        numToCategory[1] = "data";  // 001--data record
        numToCategory[2] = "hospitalLog";   // 010--hospital access record
        numToCategory[4] = "insuranceLog"; // 100--insurance company access record
    }


// ------------------------- Contract Authorization ----------------------------

    // the person who has been register
    modifier personExistOnly() {
        require(personInfo[msg.sender].exist == true, 
        "this person has not register yet!");
        _;
    }
    // test if the _category is allowed by the people 
    modifier withPermit(address _peopleAddress,uint _permissionCategory) {
        License storage tmpLicense = personInfo[_peopleAddress].permissionList[msg.sender];
        // One authorization only takes effect within 5 blocks
        require(tmpLicense.existTime.add(PERIODBLOCK) < block.number,
          "is not allowed to accesss the data now!");
        _;
    }
    /**
     * Contract Authorization API (TODO)
     *
     * We need some extended permission management mechanism, such as
     *  the `registerUser` permission may authorize another organization.
     **/


// ----------------------------- User Interface --------------------------------

    /**
     * User Data Register API
     *
     * According to the privacy of users' requirements, we only accept the
     *  data of users who have the consistent face features extracted from
     *  local AI model in the credible and secure wearable device.
     *
     * In fact, the user devices may connect the blockchain via a optional
     *  intermediate layer, that is our server stack, which never stores
     *  the user privacy data and will use the blockchain as the backend
     *  database. The server plays a part for authorization mainly:
     *  
     *  - Data forwarding between the users' wearable devices and blockchain.
     *  - User validating for the correct face features and identifier address.
     *
     * The server register uses the indentifier as the storage map key. User
     *  would change the address after some time for privacy protection and
     *  need to re-register the public address with validating the user 
     *  pre-set name.
     **/

    // Register through the server if you own a bracelet(collect the informaion)
    function registerUser(address _personId, string _name) public onlyOwner {
        Person storage p = personInfo[_personId];
        p.exist = true;
        p.name = _name;
        emit registerSuccess(_personId);
    }
    
    // upload the preliminary data
    function uploadData(address _personId, uint8[28*28] _metaData)
      public personExistOnly onlyOwner {
        Data storage tmpData;
        tmpData.metaData = _metaData;
        tmpData.dataTimestamp = block.timestamp;
        personInfo[_personId].datas.push(tmpData);
    }

    /**
     * Authorization API
     *
     * We design the autorization with a period of time, instead of
     *  the number of calls. And the personal body features will
     *  be registered with different address and the same name.
     * 
     **/

    // grant acess to institution & change permission
    function authorize(
        address _institutionId,  // the adress of institution which is authorized to
        uint _au,   // what kind of permission (eg. 111 - all the data &log could access)
        uint _start, // the start of time period that data can be access
        uint _end   // the end of time period that data can be access
        )
        public
        personExistOnly 
    {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if((_au>>i) & 1 == 1) {
                string storage category = numToCategory[1 << i];
                License storage tmpLicense = personInfo[msg.sender].permissionList[_institutionId];
                tmpLicense.existTime = block.number;
                tmpLicense.start = _start;
                tmpLicense.end = _end;
            }
        }
    }

    // user cacel the permission of all the category data access
    function personDeauthorize(address _institutionId) public personExistOnly {
        deauthorize(_institutionId,0); // 000 cacel all the data
    }
    
    // user cacel his own account
    function cacelData() public personExistOnly {
        delete personInfo[msg.sender];
    }
// --------------------------- Service Interface -------------------------------


    function registerInstitution(string _name, string _category) public {
        Institution storage i = institutionInfo[msg.sender];
        i.exist = true;
        i.name = _name;
        i.category = _category;
    }

    // get the number of data struct
    function getDataNum(
        uint _dataCategory, // type of data&log wan to access[only use 001,010,100]
        address _personId   
    ) 
        public 
        view
        withPermit(_personId,_dataCategory)
        returns(uint)
    {
        if(_dataCategory == 1) {
            return personInfo[_personId].datas.length;
        } 
        else if(_dataCategory == 2) {
            return personInfo[_personId].hospitalLogs.length;
        } 
        else if(_dataCategory == 4) {
            return personInfo[_personId].insuranceLogs.length;
        } 
        else {
            revert("get the wrong dataCategory");
        }
    }
    
    // get the body feature statistics.
    // if have the permit of data &access success,first return data index(>0) & the metadata
    // or not be allowed to get the time duration data return 0
    function accessData(
        uint _dataCategory,
        address _personId,
        uint _index
    ) 
        public 
        view 
        withPermit(_personId,_dataCategory)
        returns(uint, uint8[28*28])
    {
        require(personInfo[_personId].exist == true, "people don't exist");
        Data tmpData = personInfo[_personId].datas[_index];
        string memory c = numToCategory[_dataCategory];
        License storage tmpLicense = personInfo[_personId].permissionList[msg.sender];
        if(timeFilter(tmpData.dataTimestamp,tmpLicense.start,tmpLicense.end)) {
            recordDataAcess(1,_personId); // 001 -- data
            return (_index,tmpData.metaData);
        } else {
            return (0,[]);
        }
    }

    // get the log
    // if access success,first return index(>0),or return 0
    function accessHospitalLog(
        uint _dataCategory, 
        address _personId, 
        uint _index
    ) 
        public 
        view 
        withPermit(_personId,_dataCategory) 
        returns(
            uint,
            string,
            uint
        )
    {
        require(personInfo[_personId].exist == true, "don't exist");
        recordDataAcess(2,_personId); // 010 -- hospital
        Log tmpLog = personInfo[_personId].hospitalLogs[_index];
        string memory c = numToCategory[_dataCategory];
        License storage tmpLicense = personInfo[_personId].permissionList[msg.sender];
        if(timeFilter(tmpLog.logTimestamp,tmpLicense.start,tmpLicense.end)) {
            return (_index, tmpLog.institutionName, tmpLog.cate);
        } else {
            return (0, tmpLog.institutionName, tmpLog.cate);
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
    function deauthorize(address _institutionId, uint au) internal {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if(((au>>i) & 1) == 0) {
                string category = numToCategory[1 << i];
                License storage tmpLicense = personInfo[msg.sender].permissionList[_institutionId];
                //set existTime+5 will be bigger than any block.number
                tmpLicense.existTime = INT_MAX.sub(PERIODBLOCK);
            }
        }
    }
    // record log of  access the  data
    function recordDataAcess(
        uint _dataCategory, //kind of data&log be visited [001,010,100]
        address _personId,
    ) 
        internal 
    {
        require(personInfo[_personId].exist == true, "don't exist");
        Log storage tmpLog;
        tmpLog.cate = _dataCategory;
        tmplog.category = institutionInfo[msg.sender].category;
        tmplog.institutionName = institutionInfo[msg.sender].name;
        tmplog.logTimestamp = block.timestamp;

        // TODO(ljj): wrapper the keccak as a function returns string.
        if (keccak256(abi.encodePacked(tmplog.category)) == keccak256(abi.encodePacked("hospital"))) {
            personInfo[_personId].hospitalLogs.push(tmplog);
        }else if (keccak256(abi.encodePacked(tmplog.category)) == keccak256(abi.encodePacked("insurance"))) {
            personInfo[_personId].insuranceLogs.push(tmplog);
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

    // TODO : the timestamp problem 
    // function logArrange(uint dataCategory) internal

}
