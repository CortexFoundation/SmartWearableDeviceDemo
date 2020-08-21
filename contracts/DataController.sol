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
        uint logTimestamp;   // when access the data
        // the name of the institution who access the information
        string institutionName;
        // what data has been visited
        //eg.00001-Statistic,00010--hospitalLog, 00100--insuranceLog,01000--hospitalReceipt,10000--insuranceReceipt
        uint cate;
    }

    // the feedback for service actions
    struct Receipt {
      uint receiptTimestamp;
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
        //show what kind of data access is allowed.
        uint permission;
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
        License storage tmpLicense = personInfo[_personId].licenseList[msg.sender];
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
        tmpStatistic.startTs = block.timestamp;
        tmpStatistic.stopTs = block.timestamp;
        personInfo[_personId].statistics.push(tmpStatistic);
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
        uint _au   // what kind of permission (eg. 11111 - all the data &log could access)
    )
        public
        personExistOnly 
    {
        License storage tmpLicense = personInfo[msg.sender].licenseList[_institutionId];
        tmpLicense.existTime = block.number;
        tmpLicense.permission = _au;
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
    
    // get the body feature statistics.
    // if have the permit of data &access success,first return data index(>0) & the metadata
    // or not be allowed to get the time duration data return 0
    function accessStatistic(
        address _personId,
        address _institutionId,
        uint _dataCategory,
        uint _index
    ) 
        public 
        view 
        withPermit(_personId,_dataCategory)
        returns(uint, uint[25])
    {
        require(personInfo[_personId].exist == true, "people don't exist");
        Statistic[] tmpStatistics = personInfo[_personId].statistics;
        uint len = tmpStatistics.length;
        return (_index,tmpStatistics[len-1-_index].encodedData);
    }

    // get the log
    // if access success,first return index(>0),or return 0
    function accessLog(
        address _personId,
        address _institutionId,
        uint _dataCategory,
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
        //TODO: index access right control
        require(personInfo[_personId].exist == true, "don't exist");
        Log[] tmpLogs;
        uint len;
        if(stringEqual(institutionInfo[_institutionId].category,"hospital")) {
            recordDataAcess(2,_personId);
            tmpLogs = personInfo[_personId].hospitalLogs;
            len = tmpLogs.length;
        }
        else{
            recordDataAcess(4,_personId);
            tmpLogs = personInfo[_personId].insuranceLogs;
            len = tmpLogs.length;
        }
        return (_index, tmpLogs[len - _index -1].institutionName, tmpLogs[len - _index -1].cate);
    }
    
    // get the log
    // if access success,first return index(>0),or return 0
    function accessReceipt(
        address _personId,
        address _institutionId,
        uint _dataCategory,
        uint _index
    ) 
        public 
        view 
        withPermit(_personId,_dataCategory) 
        returns(uint, uint[25])
    {
        //TODO: index access right control
        require(personInfo[_personId].exist == true, "don't exist");
        Receipt[] tmpReceipts;
        uint len;
        if(stringEqual(institutionInfo[_institutionId].category,"hospital")) {
            recordDataAcess(8,_personId);
            tmpReceipts= personInfo[_personId].hospitalReceipts;
            len = tmpReceipts.length;
        }
        else{
            recordDataAcess(16,_personId);
            tmpReceipts= personInfo[_personId].insuranceReceipts;
            len = tmpReceipts.length;
        }
        return (_index, tmpReceipts[len-1-_index].encodedData);
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
        License storage tmpLicense = personInfo[msg.sender].licenseList[_institutionId];
        tmpLicense.existTime = INT_MAX.sub(PERIODBLOCK);
    }
    // record log of  access the  data
    function recordDataAcess(
        uint _dataCategory, //kind of data&log be visited
        address _personId
    ) 
        internal 
    {
        require(personInfo[_personId].exist == true, "don't exist");
        Log storage tmpLog;
        tmpLog.cate = _dataCategory;
        string insuranceCategory = institutionInfo[msg.sender].category;
        tmpLog.institutionName = institutionInfo[msg.sender].name;
        tmpLog.logTimestamp = block.timestamp;

        if (stringEqual(insuranceCategory,"hospital")) {
            personInfo[_personId].hospitalLogs.push(tmpLog);
        } else if (stringEqual(insuranceCategory,"insurance")) {
            personInfo[_personId].insuranceLogs.push(tmpLog);
        } else {
            revert("unknown institution");
        }
    }

    function stringEqual(string a, string b) internal pure returns(bool) {
        if(keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b))) {
            return true;
        }else {
            return false;
        }
    }
    // function getReceipt(uint8[28*28] _metaData,address _personId) internal {
    //     personInfo[_personId].feedbacks.push(_metaData);
    // }
    // TODO : the timestamp problem 
    // function logArrange(uint dataCategory) internal
}
