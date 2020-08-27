pragma solidity ^0.4.24;

import "./Ownable.sol";

contract Panel is Ownable {

// ----------------------- Admin Function ---------------------------

    /**
     * Administration Authorization
     *
     * Only the CortexBand has the permission to register new user. A smart wearable
     *  device will validate the user's address with server and then register account
     *  into blockchain.
     **/
    function registerUser(address _personAddr, string _name) public;

    function registerHospital(address _hospitalAddr,string _name) public;

    function registerInsurance(address _insuranceAddr,string _name) public;
        
    function registerAdvertisement(
        address _advertisementAddr,string _name) public;

    /**
     * when statistic is too much, we will try to integrate data of the specefic person one
     * by one, not choose to integrate all the person's data to avoid over the gas limit of
     * the block
     * @param _index to indicate which person to deal with in the personAddress 
     */
    function integrateData(uint256 _index) public;

// ------------------------- User Interface -------------------------

    function uploadData(
        uint[25] _metaData, 
        uint256 _startBlk, 
        uint256 _stopBlk
    ) public;

    function userAuthorization(
        address _institutionId, uint _auth) public;

    function userDeauthorization(address _institutionId) public;

    function deleteAccount() public;

    function getNumberOfInstitutions() public view returns(uint256);

    function getInstitution(uint256 _institutionIndex)
        public view returns(address, uint32);

// --------------------- Institution Interface -----------------------

    function saveReceipt(
        address _personAddr,
        uint _timestamp,
        uint256[25] _receiptData
    ) public;

    function getPersonDataLen(address _personAddr)
        public view returns(uint256);

    // access data | log | receipt

    function accessStatistic(address _personAddr,uint _index)
        public returns(uint256[25]);

    function accessLog(
        address _personAddr,
        uint _dataCategory,
        uint _index
    ) public returns(string memory, uint256);

    function accessReceipt(
        address _personAddr,
        uint _dataCategory,
        uint _index
    ) public returns(uint256[25]);

}
