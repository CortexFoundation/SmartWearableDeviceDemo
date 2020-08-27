// SPDX-License-Identifier: MIT

pragma solidity ^0.4.24;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Institution.sol";

// 0x113aEb08b9c79bAc21B2737317d5B239b6843A52
contract DataController is Ownable {
    using SafeMath for uint256;
    uint256 INT_MAX = 2**256 - 1;

// -------------------------- Pre-defined Structure ----------------------------

     /**
       * Encoded Statistics API
       *
       * It's the Statistics collected through the wearable devices.And the chip in 
       * the wearable devices will encode the data
      **/
    struct Statistic {
        uint256 startTs;    // start timestamp
        uint256 stopTs;      // stop timestamp
        uint256[25] encodedData;    // the body feature encoded data
    }

    // the access log of user's statistic
    struct Log {
        uint256 logTimestamp;   // when access the data
        string institutionName; // the name of the institution who access the data
        // category of data has been visited
        //eg.00001-Statistic,00010--hospitalLog, 00100--insuranceLog,01000--hospitalReceipt,10000--insuranceReceipt
        uint256 cate;
    }

    /**
       * Encoded Receipt API
       *
       * It's an public feedback after performing server, such as the
       *  insurance purchase, claim, ..., etc. We will define the feedback
       *  data encoder via communicating with all the service suppliers.
      **/
    struct Receipt {
      uint256 receiptTimestamp;    // when the service action
      uint256[25] encodedData; // the encoded feedback for service
    }
    
    //to indicate an institution could access permission of user's data
    struct License {
        uint256 existTime; // release time of the access data license (using blkNumber)
        // show what kind of data access is allowed.
        // eg. 11111 could access all kind of data
        uint256 permission;
    }

    //
    struct Person {
        bool exist;    // indicate that if has been register
        string name;
        Statistic[] statistics;   // statistic collected by smart bracelet
        Log[] hospitalLogs;     // the log of hospital access data
        Log[] insuranceLogs;
        Receipt[] hospitalReceipts;
        Receipt[] insuranceReceipts;
        mapping(address => License) licenseList;    // mapping institution address to its licese of this person
    }

    //
    struct Institution_ {
        bool exist;
        string name;
        uint32 category;    // now just 2 institution type: hospital and insurance
    }

// --------------------------------- Event -------------------------------------

    event registerPersonSuccess(address _personAddr);
    event uploadDataSuccess(address _personAddr);
    event registerInstitutionSuccess(address _institutionAddr);

// ----------------------------- Private Members -------------------------------

    /**
     * person data
     */
    // the number of data category,temporarily is 3
    uint constant NUMCATE = 5;
    // time period the licese is effective (using block number)
    // uint constant PERIODBLOCK = 5;
    uint PERIODBLOCK = 200;  // test
    // number of intergate statistics
    uint constant DATABLOCK = 2;

    //mask of data category
    uint constant STATISTIC = 1;    // 00001 -- statistic record
    uint constant MEDICALLOG = 2;    // 00010 -- medical access record
    uint constant INSURANCELOG = 4;    // 00100 -- insurance access record
    uint constant MEDICALRECEIPT = 8;    // 01000 -- medical receipt
    uint constant INSURANCERECEIPT = 16;    // 10000 -- insurance access record 

    address[] personAddress;    // the address of person already registered
    mapping(address => Person) private personInfo;    // all the data about people

    address[] institutionAddresses;    // the address of institution already registered 
    mapping(address => Institution_) private institutionInfo;    // all the data about institution


// ------------------------- Contract Authorization ----------------------------

    /**
     * Contract Authorization API
     *
     * some extended permission management mechanism
     **/
     
    // check if the person already registered
    modifier personExistOnly(address _personAddr) {
        require(
            personInfo[_personAddr].exist == true, 
            "the person has not been registered yet!"
        );
        _;
    }
    // check if the institution already registered
    modifier institutionRegistered() {
        require(
            institutionInfo[msg.sender].exist == true,
            "the institution has not been registered yet!"
        );
        _;
    }
    //check the licese is effective when access specific data
    modifier withPermit(address _personAddr, uint _dataCategory) {
        //the person is existed
        require(
            personInfo[_personAddr].exist, 
            "personal not exist"
        );
        // get the license of the institution to the person 
        License storage tmpLicense = personInfo[_personAddr].licenseList[msg.sender];

        // license only takes effect within PERIODBLOCK number of  blocks
        require(
            block.number < tmpLicense.existTime.add(PERIODBLOCK),
            "is not allowed to accesss the data now!"
        );

        // check the _datacategory of data is allowed to access
        require(
            (tmpLicense.permission & _dataCategory) == _dataCategory, 
            "please check datacategory"
        );

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
     *  In fact, the user devices may connect the blockchain via a optional
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

    // Register through the server if you own a wearable devices(collect the informaion)
    function registerUser(address _personAddr, string _name) public onlyOwner {
        Person storage p = personInfo[_personAddr];
        // one person id can just register for once
        if (p.exist == false) {
            p.exist = true;
            p.name = _name;
            personAddress.push(_personAddr);
            emit registerPersonSuccess(_personAddr);
        } else {
            revert("Already registered");
        }
    }

    // upload the statistic collected through wearable devices
    function uploadData(
        uint[25] _metaData, 
        uint256 _startBlk, 
        uint256 _stopBlk
    )
        public
        personExistOnly(msg.sender)
    {
        Statistic memory tmpStatistic = Statistic(_startBlk, _stopBlk, _metaData);
        personInfo[msg.sender].statistics.push(tmpStatistic);
        emit uploadDataSuccess(msg.sender);
    }

    /**
     * Authorization API
     *
     * We design the autorization with a period of time, instead of
     *  the number of calls. And the personal body features will
     *  be registered with different address and the same name.
     * 
     **/
    /// @param _institutionId the adress of institution which is authorized to
    /// @param _auth what kind of permission (eg. 11111 - all the data &log could access)
    function userAuthorization(address _institutionId, uint _auth) 
        public
        personExistOnly(msg.sender)
    {
        License storage tmpLicense = personInfo[msg.sender].licenseList[_institutionId];
        tmpLicense.existTime = block.number;
        tmpLicense.permission = _auth;
    }

    // user cacel the permission of the data access manually.
    function userDeauthorization(address _institutionId) public personExistOnly(msg.sender)
    {
        deauthorize(_institutionId); // 00000 cacel all the data permission
    }
    
    // user delete his own account
    function deleteAccount() public personExistOnly(msg.sender) {
        delete personInfo[msg.sender];
    }
    
    /**
     * User Service Wrapper API
     *
     * This section mainly does the wrapper of API functions in specific
     *  Service, exposing interface to user.
     **/

    function getNumberOfInstitutions() public view returns(uint256)
    {
      return institutionAddresses.length;
    }

    function getInstitution(uint256 _institutionIndex) public view returns(address)
    {
      return institutionAddresses[_institutionIndex];
    }

// ------------------------- Institution Interface -----------------------------

    /**
      * every institution has its own contract to provide service to people,if they want to
      * use user data to make some judgments & provide services,they should register in the 
      * dataContrllor to get permission first.
     */
    /// @param _institutionAddr the contract address of the institution
    /// @param _name the name of the institution
    /// @param _category what kind of institution is this 
    function registerInstitution(
        address _institutionAddr,
        string _name, 
        uint32 _category
    ) 
        private
    {
        Institution_ storage i = institutionInfo[_institutionAddr];
        if(i.exist == false) {
            i.exist = true;
            i.name = _name;
            i.category = _category;
            institutionAddresses.push(_institutionAddr);
            emit registerInstitutionSuccess(msg.sender);
        } else {
            revert("Already registered");
        }
        
    }
    //register a hospital organization
    function registerHospital(address _hospitalAddr,string _name) 
        public
        onlyOwner
    {
        registerInstitution(_hospitalAddr,_name, 0);
    }

    function registerInsurance(address _insuranceAddr,string _name) 
        public
        onlyOwner
    {
        registerInstitution(_insuranceAddr,_name, 1);
    }

    function registerAdvertisement(address _advertisementAddr,string _name)
        public
        onlyOwner
    {
        registerInstitution(_advertisementAddr,_name, 2);
    }
    
    
    // the receipt is encoded in the rules we have set up.
    /// @dev save the receipt get from the institution to the person's data
    /// @param _personAddr who is the owner of the receipt
    /// @param _timestamp the receipt generated time
    /// @param _receiptData the encoded receipt data
    function saveReceipt(
        address _personAddr,
        uint _timestamp,
        uint256[25] _receiptData
    )
        public
        institutionRegistered
    {
        Receipt memory tmpReceipt = Receipt(_timestamp, _receiptData);
        if (institutionInfo[msg.sender].category == uint32(0)) {
            personInfo[_personAddr].hospitalReceipts.push(tmpReceipt);
        } else if(institutionInfo[msg.sender].category == uint32(1)) {
            personInfo[_personAddr].insuranceReceipts.push(tmpReceipt);
        }else {
            revert("unexpected institution category(0 : hospital,1 : insurance).");
        }
    }

    // get the body feature statistics.
    function accessStatistic(address _personAddr,uint _index)
        public 
        view 
        withPermit(_personAddr, STATISTIC)
        returns(uint256[25])
    {
        Statistic[] storage tmpStatistics = personInfo[_personAddr].statistics;
        uint len = tmpStatistics.length;
        require(_index < len, "data index out of bound");
        // get the latest data, if index = 0, get the data at len-1;
        return tmpStatistics[len-1-_index].encodedData;
    }

    /**
     * receipt access API for institution contract, just get one record log once time
     * by the index,and should get the index range by the get the number of person's log
     * @param _personAddr the person address
     * @param _dataCategory the category of the data to access, technically 2 : MEDICALLOG & INSURANCELOG
     * @param _index the index of the receipt that want to access in a person's receipt arrary
     */
    function accessLog(
        address _personAddr,
        uint _dataCategory,
        uint _index
    ) 
        public
        withPermit(_personAddr, _dataCategory) 
        returns(
            string memory, 
            uint256
        )
    {
        Log[] memory tmpLogs;
        uint len;

        if (institutionInfo[msg.sender].category == 0) {
            recordDataAcess(MEDICALLOG,_personAddr);
            tmpLogs = personInfo[_personAddr].hospitalLogs;
            len = tmpLogs.length;
        } else if (institutionInfo[msg.sender].category == 1) {
            recordDataAcess(INSURANCELOG,_personAddr);
            tmpLogs = personInfo[_personAddr].insuranceLogs;
            len = tmpLogs.length;
        } else {
            revert("not supported");
        }

        require(_index < len, "data index out of bound");
        return (tmpLogs[len-1-_index].institutionName, tmpLogs[len-1-_index].cate);
    }

    /**
     * receipt access API for institution contract, just get one record receipt once time
     * by the index,and should get the index range by the get the number of person's receipt
     * @param _personAddr the person address
     * @param _dataCategory the category of the data to access,technically 2 : MEDICALRECEIPT & INSURANCERECEIPT
     * @param _index the index of the receipt that want to access in a person's receipt arrary
     */
    function accessReceipt(
        address _personAddr,
        uint _dataCategory,
        uint _index
    )
        public
        withPermit(_personAddr, _dataCategory)
        returns(uint256[25])
    {
        Receipt[] memory tmpReceipts;
        uint len;
        //
        if (institutionInfo[msg.sender].category == 0) {
            recordDataAcess(MEDICALRECEIPT,_personAddr);
            tmpReceipts = personInfo[_personAddr].hospitalReceipts;
            len = tmpReceipts.length;
        } else if (institutionInfo[msg.sender].category == 1) {
            recordDataAcess(INSURANCERECEIPT,_personAddr);
            tmpReceipts = personInfo[_personAddr].insuranceReceipts;
            len = tmpReceipts.length;
        } else {
            revert("not supported");
        }

        require(_index < len, "data index out of bound");
        return tmpReceipts[len-1-_index].encodedData;
    }


// ---------------------------- Helper Functions -------------------------------

    // Cancel authorization of all category data access for institution
    function deauthorize(address _institutionId) internal {
        delete personInfo[msg.sender].licenseList[_institutionId];
        // License storage tmpLicense = personInfo[msg.sender].licenseList[_institutionId];
        // tmpLicense.permission = _au;
        // tmpLicense.existTime = INT_MAX.sub(PERIODBLOCK);
    }

    // record the data access,and put it into the corresponding log
    function recordDataAcess(uint256 _dataCategory, address _personAddr) internal {
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

    /**
     * when statistic is too much, we will try to integrate data of the specefic person one
     * by one, not choose to integrate all the person's data to avoid over the gas limit of
     * the block
     * @param _index to indicate which person to deal with in the personAddress 
     */
    function integrateData(uint256 _index) public onlyOwner{
        address personAddr = personAddress[_index];
        Statistic[] storage personStatistics = personInfo[personAddr].statistics;
        uint256 len = personStatistics.length;
        uint256 cur = 0;
        //get the new compression data,wo simply integrate 2 items into 1
        for (uint i = 0; i < len; i += DATABLOCK) {
            // if the number is add, Use directly the last statistic
            if (i+1 >= len) {
                personStatistics[cur]= personStatistics[i];
            } else {
                personStatistics[cur].startTs = personStatistics[i].startTs;
                personStatistics[cur].stopTs = personStatistics[i+1].stopTs;
                personStatistics[cur].encodedData = addStatistic(personStatistics[i].encodedData, personStatistics[i+1].encodedData);
            }
            cur++;
        }
        //pop the other statistic
        personStatistics.length = cur;
    }

    //how to deal with 2 statistic, now just average them
    function addStatistic(uint256[25] storage _meta1, uint256[25] storage _meta2) internal view returns(uint256[25]) {
        uint256[25] memory tmpData;
        for (uint i = 0 ; i < 25; i++) {
            tmpData[i] = (_meta1[i] + _meta2[i])/2;
        }
        return tmpData;
    }

// -----------------------------test function ---------------------------
    function setTimePeriodBlock(uint _tpb) public onlyOwner {
        PERIODBLOCK = _tpb;
    }
    
    function getpeopleNUM() public view returns(uint) {
        return personAddress.length;
    }
    
    function getPersonDataLen(address _p) public view returns(uint) {
        return personInfo[_p].statistics.length;
    }
    
    function getStatistic(address _p, uint _index) public view returns(uint[25] memory) {
        Person storage p = personInfo[_p];
        return p.statistics[_index].encodedData;
    }
    
    function uploadTestStatistic(uint num) public personExistOnly(msg.sender){
        uint _startBlk = num;
        uint _stopBlk = num+7;
        uint[25] memory _metaData;
        for (uint i = 0; i < 25; i++) {
            _metaData[i] = num;
        }
        Statistic memory tmpStatistic = Statistic(
        _startBlk, _stopBlk, _metaData);
        personInfo[msg.sender].statistics.push(tmpStatistic);
    }
}