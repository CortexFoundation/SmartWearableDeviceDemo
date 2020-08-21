pragma solidity ^0.4.24;
// pragma experimental ABIEncoderV2;

// last implemented contract: 0x70ae5b30c81d00cc4b6cbe765a71ab89e35d2cc4
contract Institution {
    
// ---------------------------- Company Information ------------------------------

    string public companyName;

    /**
     * Data Authorization API
     *
     * The users' data will be permitted and accessible to an
     *  organization or institution, instead of the specific service
     *  in it. It's a straight-forward sense and simpilify the process
     *  logic in the interaction between users' wearable devices and
     *  the smart contract.
     *
     * @return uint:data category
     *    The authorization levels of necessary data access for all
     *    the services in this company.
     **/
    function authRequest() public pure returns(uint);

    // All the provided services of company.
    // Maximum list length : 256
    function getNumberOfServices()
        public view returns(uint256) ;
    
    // Returns the specific service name and fee in the above
    //  provided service list corresponding with the parameter:
    //  `_serviceIndex`.
    function getService(uint8 _serviceIndex)
        public view returns(string, uint256);

// --------------------------- Personal Services ------------------------------

    /**
     * The services mapping with users
     *
     * @key: user public address
     * @value: the bitmap of provided services index.
     *    Eg. 0101 indicates the index 0 and 2 of provided service list
     *      are selected.
     **/
    mapping(address => uint256) availableServicesByUser;
    mapping(address => uint256) activeServicesByUser;
    
    function isServiceActive(uint8 _serviceIndex)
        public view returns(bool);
    
    // all the active services that user has selected
    function getActiveServices()
        public view returns(uint256)
    {
        return activeServicesByUser[msg.sender];
    }
    
    // all the available services that user can choose
    function getAvailbleServices()
        public view returns(uint256)
    {
        return availableServicesByUser[msg.sender];
    }

// -------------------------- Service Purchase ---------------------------------
    
    function purchaseService(uint256 _serviceIndex)
      public payable;
}

contract Insurance is Institution {

    modifier moderatorOnly() {
        require(msg.sender == moderator, "Moderator Only");
        _;
    }

// -------------------------- Warranty Service ---------------------------------

    function payment(address _userAddr) public moderatorOnly;
}
