pragma solidity ^0.4.18;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Services.sol";

contract DataController is Ownable {
    using SafeMath for uint256;

// -------------------------- Pre-defined Structure ----------------------------

    // the body feature data collected by smart wristband
    struct Statistic {
        // time duration of these statistics
        uint256 startTs;    //start timestamp
        uint256 stopTs;      //stop timestamp
        /**
       * Encoded Statistics API
       *
       * It's the Statistics collected through the smart bracelet.And the chip in 
       * the bracelet will encode the data
       **/
        uint[25] encodedData;
    }

    // the data access log of user's data
    struct Log {
        //string category;  // the category of institution who access the user data
        uint256 logTimestamp;   // when access the data
        // the name of the institution who access the information
        string institutionName;
        // what data has been visited
        //eg.00001-Statistic,00010--hospitalLog, 00100--insuranceLog,01000--hospitalReceipt,10000--insuranceReceipt
        uint cate;
    }

    // the feedback for service actions
    struct Receipt {
      uint256 receiptTimestamp;
      /**
       * Encoded Receipt API
       *
       * It's an public feedback after performing server, such as the
       *  insurance purchase, claim, ..., etc. We will define the feedback
       *  data encoder via communicating with all the service suppliers.
       **/
      uint[25] encodedData; // the encoded feedback for service
    }
    
    struct License {
        // when get the license (using blkNumber)
        uint existTime;
        // time period of data that can be accessed,[start,end]
        int start;
        int end;
        //show what kind of data access is allowed.
        mapping (uint => bool) permission;
    }

    struct Person {
        // indicate that if has been register
        bool exist;   
        string name;
        Statistic[] statistics;
        Log[] hospitalLogs;
        Log[] insuranceLogs;
        Receipt[] hospitalReceipts;
        Receipt[] insuranceReceipts;
        // address is the address id of an institution
        mapping(address => License) licenseList;
    }

    struct Institution {
        bool exist;
        string name;
        string category;    // now just 2 institution type: hospital and insurance
    }

// --------------------------------- Event -------------------------------------

    event registerSuccess(address _peopleAddress);


// ----------------------------- Private Members -------------------------------

    // categorty of data
    mapping (uint => string) numToCategory;
    uint256 INT_MAX = 2**256 - 1;
    // the number of data & log category,temporarily is 3
    uint constant NUMCATE = 5;
    // time period the number of the block
    uint constant PERIODBLOCK = 5;
    
    // every insurance contract has its own address;
    //mapping (string => address) insuranceAddress;
    
    // all the data about people
    mapping (address => Person) private personInfo;
    // all the data about institution
    mapping (address => Institution) private institutionInfo;

    constructor() public {
      // TODO(ljj): can the map be moved into the line 87?
      numToCategory[1] = "data";  // 00001--data record
      numToCategory[2] = "medicalLog";   // 00010--hospital access record
      numToCategory[4] = "insuranceLog"; // 00100--insurance company access record
      numToCategory[8] = "medicalReceipt";  //01000
      numToCategory[16] = "insuranceReceipt";    //10000
    }


// ------------------------- Contract Authorization ----------------------------

    // the person who has been register
    modifier personExistOnly() {
        require(personInfo[msg.sender].exist == true, 
        "this person has not register yet!");
        _;
    }
    // test if the _category is allowed by the people 
    modifier withPermit(address _personId,uint _permissionCategory) {
        License storage tmpLicense = personInfo[_personId].permissionList[msg.sender];
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
    function uploadData(address _personId, uint[25] _metaData)
        public
        personExistOnly
        onlyOwner 
    {
        Statistic storage tmpStatistic;
        tmpStatistic.encodedData = _metaData;
        tmpStatistic.dataTimestamp = block.timestamp;
        personInfo[_personId].datas.push(tmpStatistic);
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
    // _start = -1 --start at the first element
    //_stop = -1 -- stop at the newest element
    function authorize(
        address _institutionId,  // the adress of institution which is authorized to
        uint _au,   // what kind of permission (eg. 11111 - all the data &log could access)
        int _start, // the start of time period that data can be access
        int _stop   // the end of time period that data can be access
        )
        public
        personExistOnly 
    {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if((_au>>i) & 1 == 1) {
                //string storage category = numToCategory[1 << i];
                uint tmp = 1 << i;
                License storage tmpLicense = personInfo[msg.sender].licenseList[_institutionId];
                tmpLicense.existTime = block.number;
                tmpLicense.start = _start;
                tmpLicense.end = _stop;
                tmpLicense.permission[tmp] = true;
            }
        }
    }

    // user cacel the permission of all the category data access
    function personDeauthorize(address _institutionId) public personExistOnly {
        deauthorize(_institutionId,0); // 00000 cacel all the data permission
    }
    
    // user cacel his own account
    function cacelData() public personExistOnly {
        delete personInfo[msg.sender];
    }

    /**
     * User Service Wrapper API
     *
     * This section mainly does the wrapper of API functions in specific
     *  Service, exposing interface to user.
     **/

    // function getNumberOfServices() public view returns(uint256) {
    //   _;
    // }

    // function getService(uint8 _serviceIndex)
    //     public view returns(string, uint256) {
    //   _;
    // }

    // function isServiceActive(uint8 _serviceIndex)
    //     public view returns(bool) {
    //   _;
    // }

    // function getAvailableServices()
    //     public view returns(uint256) {
    //   _;
    // }

    // function getActiveServices()
    //     public view returns(uint256) {
    //   _;
    // }

// ------------------------- Institution Interface -----------------------------


    function registerInstitution(string _name, string _category) public onlyOwner{
        Institution storage i = institutionInfo[msg.sender];
        i.exist = true;
        i.name = _name;
        i.category = _category;
    }

    //obtain an index range of data want to get
    function getAvailableIndexRange(
        address _personId,
        uint _dataCategory
    )
    public
    view
    withPermit(_personId,_dataCategory)
    returns(uint, uint)
    {
        if (_dataCategory == 1) {
            return getAvailableStatisticIndex(_personId,msg.sender,_dataCategory);
        } 
        else if (_dataCategory == 2 || _dataCategory == 4) {
            return getAvailableLogIndex(_personId,msg.sender,_dataCategory);
        } 
        else if(_dataCategory == 8 || _dataCategory == 16) {
            return getAvailableReceiptIndex(_personId,msg.sender,_dataCategory);
        }
        else {
            revert("get the wrong _dataCategory code");
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
        Statistic tmpData = personInfo[_personId].datas[_index];
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

    // // every insurance service has its own contract address
    // function setInsuranceInstance(string _name, address _address) public onlyOwner {
    //     insuranceAddress[_name] = _address;
    // }

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
        address _personId
    ) 
        internal 
    {
        require(personInfo[_personId].exist == true, "don't exist");
        Log storage tmpLog;
        tmpLog.cate = _dataCategory;
        tmpLog.category = institutionInfo[msg.sender].category;
        tmpLog.institutionName = institutionInfo[msg.sender].name;
        tmpLog.logTimestamp = block.timestamp;

        if (stringEqual(tmpLog.category,"hospital")) {
            personInfo[_personId].hospitalLogs.push(tmpLog);
        } else if (stringEqual(tmpLog.category,"insurance")) {
            personInfo[_personId].insuranceLogs.push(tmpLog);
        } else {
            revert("unknown institution");
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

    // // get the number of data struct
    // function getDataNum(
    //     uint _dataCategory, // type of data&log wan to access[only use 001,010,100]
    //     address _personId   
    // ) 
    //     internal 
    //     view
    //     returns(uint)
    // {
    //     if(_dataCategory == 1) {
    //         return personInfo[_personId].datas.length;
    //     } 
    //     else if(_dataCategory == 2) {
    //         return personInfo[_personId].hospitalLogs.length;
    //     } 
    //     else if(_dataCategory == 4) {
    //         return personInfo[_personId].insuranceLogs.length;
    //     } 
    //     else {
    //         revert("get the wrong dataCategory");
    //     }
    // }
    
    function stringEqual(string a, string b) internal pure returns(bool) {
        if(keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b))) {
            return true;
        }else {
            return false;
        }
    }
    function getReceipt(uint8[28*28] _metaData,address _personId) internal {
        personInfo[_personId].feedbacks.push(_metaData);
    }
    // TODO : the timestamp problem 
    // function logArrange(uint dataCategory) internal
    
    function getAvailableStatisticIndex(
        address _personId, 
        address _institutionId, // who want to get the index
        uint _dataCategory  // the category of data want to obtain
    ) 
        internal 
        view
        returns(int, int) // -1 -- don't get exactly index
    {
        
        //the time duration of data can be accessed
        int beginLiceseTime = personInfo[_personId].liceseList[_institutionId].start;
        int endLiceseTime = personInfo[_personId].liceseList[_institutionId].end;
        
        Statistic[] tmpStatistics = personInfo[_personId].statistics;
        
       return (findStartReceiptIndex(beginLiceseTime,tmpStatistics),
            findStopReceiptIndex(endLiceseTime,tmpStatistics));
    }
    
    function findStartStatisticIndex(int beginLiceseTime,Statistic[] tmpStatistics) internal view returns(int) {
        //-1 indicate start with first element
        if (beginLiceseTime == -1) {
            return 0;
        }
        int startIndex = -1;
        beginLiceseTime = uint(beginLiceseTime);
        int len = tmpStatistics.length;
        for (int i = 0; i < len; i++) {
            uint currentElemTime = tmpStatistics[i].startTs;
            if(isEarly(beginLiceseTime, currentElemTime)) {
                startIndex = i;
                break;
            }
        }
        return startIndex;
    }
    
    function findStopStatisticIndex(int endLiceseTime,Log[] tmpStatistics) internal view returns(int) {
        int len = tmpStatistics.length;
        //-1 indicate start with first element
        if (endLiceseTime == -1) {
            return len-1;
        }
        int stopIndex = -1;
        uint beginLiceseTime = uint(beginLiceseTime);
        for (int i = len-1; i > 0; i--) {
            uint currentElemTime = tmpStatistics[i].stopTs;
            if(isEarly(currentElemTime,currentElemTime)) {
                stopIndex = i;
                break;
            }
        }
        return stopIndex;
    }
    
    
    function getAvailableLogIndex(
        address _personId, 
        address _institutionId, // who want to get the index
        uint _dataCategory  // the category of data want to obtain
    ) 
        internal 
        view
        returns(int, int) // -1 -- don't get exactly index
    {
        
        //the time duration of data can be accessed
        int beginLiceseTime = personInfo[_personId].liceseList[_institutionId].start;
        int endLiceseTime = personInfo[_personId].liceseList[_institutionId].end;
        
        Log[] tmpLogs;
        if (_dataCategory == 8) {
            tmpLogs = personInfo[_personId].hospitalLogs;
        }
        else {
            tmpLogs = personInfo[_personId].insuranceLogs;
        }
        
        return (findStartReceiptIndex(beginLiceseTime,tmpLogs),
            findStopReceiptIndex(endLiceseTime,tmpLogs));
    }
    
    function findStartLogIndex(int beginLiceseTime,Log[] tmpLogs) internal view returns(int) {
        //-1 indicate start with first element
        if (beginLiceseTime == -1) {
            return 0;
        }
        int startIndex = -1;
        beginLiceseTime = uint(beginLiceseTime);
        int len = tmpLogs.length;
        for (int i = 0; i < len; i++) {
            uint currentElemTime = tmpLogs[i].receiptTimestamp;
            if(isEarly(beginLiceseTime, currentElemTime)) {
                startIndex = i;
                break;
            }
        }
        return startIndex;
    }
    
    function findStopLogIndex(int endLiceseTime,Log[] tmpLogs) internal view returns(int) {
        int len = tmpLogs.length;
        //-1 indicate start with first element
        if (endLiceseTime == -1) {
            return len-1;
        }
        int stopIndex = -1;
        uint beginLiceseTime = uint(beginLiceseTime);
        for (int i = len-1; i > 0; i--) {
            uint currentElemTime = tmpLogs[i].receiptTimestamp;
            if(isEarly(currentElemTime,currentElemTime)) {
                stopIndex = i;
                break;
            }
        }
        return stopIndex;
    }
        
    //obtain an available index range of feedbacks of people
    //inclding hospitalRecipt & insuranceReceipts
    function getAvailableReceiptIndex(
        address _personId, 
        address _institutionId, // who want to get the index
        uint _dataCategory  // the category of data want to obtain
    ) 
        internal 
        view
        returns(int, int) // -1 -- don't get exactly index
    {
        //the time duration of data can be accessed
        int beginLiceseTime = personInfo[_personId].liceseList[_institutionId].start;
        int endLiceseTime = personInfo[_personId].liceseList[_institutionId].end;
        
        Receipt[] storage tmpReceipts;
        if (_dataCategory == 8) {
            tmpReceipts = personInfo[_personId].hospitalReceipts;
        }
        else {
            tmpReceipts = personInfo[_personId].insuranceReceipts;
        }
        
        return (findStartReceiptIndex(beginLiceseTime,tmpReceipts),
            findStopReceiptIndex(endLiceseTime,tmpReceipts));
    }
    
    function findStartReceiptIndex(int beginLiceseTime,Receipt[] tmpReceipts) internal view returns(int) {
        //-1 indicate start with first element
        if (beginLiceseTime == -1) {
            return 0;
        }
        int startIndex = -1;
        beginLiceseTime = uint(beginLiceseTime);
        int len = tmpReceipts.length;
        for (int i = 0; i < len; i++) {
            uint currentElemTime = tmpReceipts[i].receiptTimestamp;
            if(isEarly(beginLiceseTime, currentElemTime)) {
                startIndex = i;
                break;
            }
        }
        return startIndex;
    }
    
    function findStopReceiptIndex(int endLiceseTime,Receipt[] tmpReceipts) internal view returns(int) {
        int len = tmpReceipts.length;
        //-1 indicate start with first element
        if (endLiceseTime == -1) {
            return len-1;
        }
        int stopIndex = -1;
        uint beginLiceseTime = uint(beginLiceseTime);
        for (int i = len-1; i > 0; i--) {
            uint currentElemTime = tmpReceipts[i].receiptTimestamp;
            if(isEarly(currentElemTime,currentElemTime)) {
                stopIndex = i;
                break;
            }
        }
        return stopIndex;
    }
    
    
    //if the timestamp of _A is smaller than _B(_A is earlier than _B)
    function isEarly(uint _A, uint _B) internal pure returns(bool) {
        if (_A <= _B) {
            return true;
        } else {
            return false;
        }
    }
}
