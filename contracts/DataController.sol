pragma solidity ^0.7.0;

import "./Ownable.sol";
import "./SafeMath.sol";

contract dataController is Ownable {
    using SafeMath for uint8;
    //-------data storage structure
    //the heath information collect by wristband
    struct data {
        uint256 dataTimestamp;
        string Tdata;
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
        mapping(address => mapping(string => bool)) permission; //use num to indicate category of permission
    }
    struct institution {
        bool exist;
        string name;
    }
    //categorty of institution
    mapping (uint8 => string) numToCategory;
    uint8 NUMCATE = 3;  //number of institution category
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
    modifier withPermit(address _address,string category) {
        require(personInfo[_address].permission[msg.sender][category] == true,
        "not allowed to access the data");
        _;
    }

    constructor() public {
        numToCategory[1] = "data";  // 001--data allow
        numToCategory[2] = "hospitalLog";   //010--hospital record allow
        numToCategory[4] = "insuranceLog"; //100--insurance company record allow
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
    function registerUser(string calldata name) public onlyOwner {
        person storage p = personInfo[msg.sender];
        p.exist = true;
        p.name = name;
    }
    // upload the data collect
    function uploadData(string calldata cData) public existOnly {
        data storage tData;
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
		 * TODO(ljj): Add the logic for auto deauthorized, since you can
		 *	get the block number. The `authorize` method gives an accessible
		 *	permission for a period of time counted via block number.
		 *
		 *	It's strange to request the user to deauthorize the permission
		 *	manually.
		 * 
		 *	blkNumber = block.number
		 **/

    // grant acess to institution & change permission
    function authorize(address _iAddress,uint8 au) public existOnly {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if((au>>i) & 1) {
                string category = numToCategory[1 << i];
                personInfo[msg.sender].permission[_iAddress][category] = true;
            }
        }
    }

    //user cacel the permission of all the category data access
    function personDeauthorize(address _iAddress) public existOnly {
        deauthorize(_iAddress,0); // 000 cacel all the data
    }

    //--------interface for insurance

    function accessData(string calldata dataCategory,string calldata name,
        string category, address people) pubic withPermit(people,dataCategory)returns(uint,log){
        require(personInfo[people].exist == true, "people don't exist");
        person storage p = personInfo[people];
        return (index,data)
        dataLog()
    }

    function accessData(string calldata category, string calldata name, address people) internal view withPermit(people,category) returns(person meomory){
        require(personInfo[people].exist == true, "don't exist");
        accessDataLog(category,name,people);
        emit accessSuccess(msg.sender);
        return personInfo[people];
    }

    //every insurance service has its own contract address
    function setInsuranceInstance(string calldata name, address _address) public onlyOwner {
        insuranceAddress[name] = _address;
    }

    function cacelData() public existOnly {
        delete personInfo[msg.sender];
    }

    function registerInstitution(string calldata name) public {
        institution storage i = institutionInfo[msg.sender];
        i.exist = true;
        i.name = name;
    }

    function getInstitutionName(address _address) public view returns(string memory){
        require(institutionInfo[_address].exist == true, "this institution not exist");
        return institutionInfo[_address].name;
    }




    // function pur;

    //-------basic function
    //cancel the permission of data access for institution
    function deauthorize(address _iAddress, uint8 au) internal {
        for (uint i = 0; i < NUMCATE; i.add(1)) {
            if(((au>>i) & 1) == 0) {
                string category = numToCategory[1 << i];
                personInfo[msg.sender].permission[_iAddress][category] = false;
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
    //TODO : the timestamp problem 
    function logArrange(uint8 dataCategory) internal {

    }
    function timeFilter()
}
