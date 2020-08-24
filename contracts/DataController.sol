pragma solidity ^0.4.18;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Institution.sol";

// 0x16d9a5c566d4bfd50a4a43a883faf5ac920c6b32
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
        uint256[25] encodedData;
    }

    // the data access log of user's data
    struct Log {
        //string category;  // the category of institution who access the user data
        uint logTimestamp;   // when access the data
        // the name of the institution who access the information
        string institutionName;
        // what data has been visited
        //eg.00001-Statistic,00010--hospitalLog, 00100--insuranceLog,01000--hospitalReceipt,10000--insuranceReceipt
        uint256 cate;
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
      uint256[25] encodedData; // the encoded feedback for service
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
        uint32 category;    // now just 2 institution type: hospital and insurance
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
    //number of intergate block statitic 
    uint constant DATABLOCK = 2;
    
    // every insurance contract has its own address;
    //mapping (string => address) insuranceAddress;

    // authorize who could register user
    mapping(address => bool) authorizationRegister;

    address[] personAddress;
    // all the data about people
    mapping (address => Person) private personInfo;
    // all the data about institution
    address[] institutionAddresses;
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

    /**
     * Contract Authorization API (TODO)
     *
     * We need some extended permission management mechanism, such as
     *  the `registerUser` permission may authorize another organization.
     **/
     
    // the person who has been register
    modifier personExistOnly(address _personAddr) {
        require(personInfo[_personAddr].exist == true, 
        "this person has not register yet!");
        _;
    }
    modifier institutionRegistered() {
        require(institutionInfo[msg.sender].exist == true,
        "the institution has not been registered");
        _;
    }
    //if the permission is effient
    modifier withPermit(address _personAddr, uint _dataCategory) {
        require(personInfo[_personAddr].exist, "personal not exist");

        License storage tmpLicense = personInfo[_personAddr].licenseList[msg.sender]; 
        // One authorization only takes effect within 5 blocks
        require(tmpLicense.existTime.add(PERIODBLOCK) < block.number,
          "is not allowed to accesss the data now!");


        for (int i = 0; i < 5; ++i) {
          uint32 mask = uint32(1) << i;
          if ((_dataCategory & mask) == mask) {
            require((tmpLicense.permission & mask) == mask, "check data");
          }
        }

        _;
    }

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
    function registerUser(address _personAddr, string _name) public onlyOwner {
        Person storage p = personInfo[_personAddr];
        p.exist = true;
        p.name = _name;
        personAddress.push(_personAddr);
        emit registerSuccess(_personAddr);
    }
    
    // upload the preliminary data
    function uploadData(
        address _personAddr, 
        uint[25] _metaData, 
        uint256 _startBlk, 
        uint256 _stopBlk) public
        personExistOnly(_personAddr)
    {
        Statistic memory tmpStatistic = Statistic(
            _startBlk, _stopBlk, _metaData);
        personInfo[_personAddr].statistics.push(tmpStatistic);
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
    function userAuthorization(
        address _institutionId,  // the adress of institution which is authorized to
        uint _au   // what kind of permission (eg. 11111 - all the data &log could access)
    )
        public
        personExistOnly(msg.sender)
    {
        License storage tmpLicense = personInfo[msg.sender].licenseList[_institutionId];
        tmpLicense.existTime = block.number;
        tmpLicense.permission = _au;
    }

    // user cacel the permission of the data access manually.
    function userDeauthorization(address _institutionId)
        public personExistOnly(msg.sender)
    {
        deauthorize(_institutionId,0); // 00000 cacel all the data permission
    }
    
    // user delete his own account
    function deleteData() public personExistOnly(msg.sender) onlyOwner {
        delete personInfo[msg.sender];
    }
    
    /**
     * User Service Wrapper API
     *
     * This section mainly does the wrapper of API functions in specific
     *  Service, exposing interface to user.
     **/

    function getNumberOfInstitutions()
        public view returns(uint256)
    {
      return institutionAddresses.length;
    }

    function getInstitution(uint256 _institutionIndex)
        public view returns(address)
    {
      return institutionAddresses[_institutionIndex];
    }

// ------------------------- Institution Interface -----------------------------

    function registerInstitution(address _institutionAddr,string _name, uint32 _category) private {
        Institution storage i = institutionInfo[_institutionAddr];
        i.exist = true;
        i.name = _name;
        i.category = _category;
        institutionAddresses.push(_institutionAddr);
    }

    function registerHospital(address hospitalAddr,string _name) public onlyOwner {
      registerInstitution(hospitalAddr,_name, 0);
    }

    function registerInsurance(address insuranceAddr,string _name) public onlyOwner {
      registerInstitution(insuranceAddr,_name, 1);
    }

    function registerAdvertisement(address advertisementAddr,string _name) public onlyOwner {
      registerInstitution(advertisementAddr,_name, 2);
    }
    
    function saveReceipt(
        address _personAddr,
        uint _timestamp,
        uint256[25] _receiptData,
        uint _category
    ) public institutionRegistered 
    {
        Receipt memory tmpReceipt = Receipt(_timestamp,_receiptData);
        if (_category == 0) {
            personInfo[_personAddr].hospitalReceipts.push(tmpReceipt);
        }
        else if(_category == 1) {
            personInfo[_personAddr].insuranceReceipts.push(tmpReceipt);
        }else {
            revert("unexpected _category(0 : hospital,1 : insurance)");
        }
    }

    // get the body feature statistics.
    // if have the permit of data &access success,first return data index(>0) & the metadata
    // or not be allowed to get the time duration data return 0
    function accessStatistic(
        address _personAddr,
        // address _institutionId,
        uint _dataCategory,
        uint _index
    ) 
        public 
        view 
        withPermit(_personAddr, _dataCategory)
        returns(uint256[25])
    {
        Statistic[] storage tmpStatistics = personInfo[_personAddr].statistics;
        uint len = tmpStatistics.length;
        require(_index + 1 > len, "data index out of bound");

        return tmpStatistics[len-1-_index].encodedData;
    }

    // get the log
    // function accessLog(
    //     address _personAddr,
    //     uint _dataCategory,
    //     uint _index) 
    //     public
    //     withPermit(_personAddr, _dataCategory) 
    //     returns(uint256[25])
    // {
    //     Log[] memory tmpLogs;
    //     uint len;

    //     if (institutionInfo[msg.sender].category == 0) {
    //         recordDataAcess(2,_personAddr);
    //         tmpLogs = personInfo[_personAddr].hospitalLogs;
    //         len = tmpLogs.length;
    //     } else if (institutionInfo[msg.sender].category == 1) {
    //         recordDataAcess(4,_personAddr);
    //         tmpLogs = personInfo[_personAddr].insuranceLogs;
    //         len = tmpReceipts.length;
    //     } else {
    //         revert("not supported");
    //     }

    //     require(_index + 1 > len, "data index out of bound");

    //     return tmpLogs[len-1-_index].encodedData;
    // }


    // get the receipt
    function accessReceipt(
        address _personAddr,
        uint _dataCategory,
        uint _index) 
        public
        withPermit(_personAddr, _dataCategory) 
        returns(uint256[25])
    {
        //TODO: index access right control
        Receipt[] memory tmpReceipts;
        uint len;

        if (institutionInfo[msg.sender].category == 0) {
            recordDataAcess(8,_personAddr);
            tmpReceipts = personInfo[_personAddr].hospitalReceipts;
            len = tmpReceipts.length;
        } else if (institutionInfo[msg.sender].category == 1) {
            recordDataAcess(16,_personAddr);
            tmpReceipts = personInfo[_personAddr].insuranceReceipts;
            len = tmpReceipts.length;
        } else {
            revert("not supported");
        }

        require(_index + 1 > len, "data index out of bound");

        return tmpReceipts[len-1-_index].encodedData;
    }


// ---------------------------- Helper Functions -------------------------------


    // function pur;

    // cancel the permission of data access for institution
    function deauthorize(address _institutionId, uint _au) internal {
        License storage tmpLicense = personInfo[msg.sender].licenseList[_institutionId];
        tmpLicense.permission = _au;
        tmpLicense.existTime = INT_MAX.sub(PERIODBLOCK);
    }
    // record log of  access the  data
    function recordDataAcess(
        uint256 _dataCategory, //kind of data&log be visited
        address _personAddr) internal 
    {
        Log memory tmpLog;
        tmpLog.cate = _dataCategory;
        tmpLog.institutionName = institutionInfo[msg.sender].name;
        tmpLog.logTimestamp = block.number;

        uint256 insuranceCategory = institutionInfo[msg.sender].category;
        if (insuranceCategory == 0) {
            personInfo[_personAddr].hospitalLogs.push(tmpLog);
        } else if (insuranceCategory == 1) {
            personInfo[_personAddr].insuranceLogs.push(tmpLog);
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
    // function getReceipt(uint8[28*28] _metaData,address _personAddr) internal {
    //     personInfo[_personAddr].feedbacks.push(_metaData);
    // }
    
    //when the data is too big,compressions it
    function statisticCollation() public onlyOwner{
        uint peopleNum = personAddress.length;
        for (uint256 i = 0; i < peopleNum; i++) {
            integrateData(i);
        }
    }

    function integrateData(uint256 _index) internal{
        address personAddr = personAddress[_index];
        Statistic[] storage personStatistics = personInfo[personAddr].statistics;
        uint256 len = personStatistics.length;
        uint256 cur = 0;
        //get the new cpmpression data
        for (uint i = 0; i < len; i += DATABLOCK) {
            if (i+1 >= len) {
                personStatistics[cur] = personStatistics[i];
                cur.add(1);
            }
            personStatistics[cur].startTs = personStatistics[i].startTs;
            personStatistics[cur].stopTs = personStatistics[i+1].stopTs;
            personStatistics[cur].encodedData = addStatistic(personStatistics[i].encodedData, personStatistics[i+1].encodedData);
            cur.add(1);
        }
        //pop the other thing
        while (cur < len) {
            delete personStatistics[cur];
            cur.add(1);
        }
    }

    function addStatistic(uint256[25] storage _meta1, uint256[25] storage _meta2) internal view returns(uint256[25]) {
        uint256[25] memory tmpData;
        for (uint i = 0 ; i < 25; i++) {
            tmpData[i] = (_meta1[i] + _meta2[i])/2;
        }
        return tmpData;
    }
}