pragma solidity ^0.4.24;

import "./Ownable.sol";

// last implemented contract: 0x70ae5b30c81d00cc4b6cbe765a71ab89e35d2cc4
contract Institution is Ownable {
    
// ---------------------------- Company Information ------------------------------

    string public companyName;
    address public dataControllerAddress = 0xdb317E397CDcB8A9e9Cd70F06c981537b5258A69;
    
    function updateCompanyName(string _newName) public onlyOwner {
        companyName = _newName;
    }
    
    function updateDataControllerAddress(address _newAddr) public onlyOwner {
        dataControllerAddress = _newAddr;
    }

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
    function getRequiredPermissions() public view returns(uint256);

    // All the provided services of company.
    // Maximum list length : 256
    function getNumberOfServices()
        public view returns(uint256) ;
    
    // Returns the specific service name and fee in the above
    //  provided service list corresponding with the parameter:
    //  `_serviceIndex`.
    function getService(uint8 _serviceIndex)
        public view returns(string, uint256);
        
    
    // TODO(wlq): move the `registerInstitution` function into the general service
    // function registerInstitution() public;

    // More details information about service, such as
    //  the insurance acknowledge, scheme, ... etc.
    function getServiceInformation(uint8 _serviceIndex)
        public view returns(
          string, // service name
          uint256, // service fee
          string, // service description
          string // service notes
        );

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
    function getAvailableServices()
        public view returns(uint256)
    {
        return availableServicesByUser[msg.sender];
    }

// -------------------------- Service Purchase ---------------------------------
    function checkForAvailableServices(address _userAddr) public;
    
    function purchaseService(uint256 _serviceIndex)
      public payable;
}

contract Insurance is Institution {
    
// -------------------------- Basic Functions --------------------------------- 
    function getBalance() public view onlyOwner returns(uint256){
        return address(this).balance;
    }
    
    function withdraw(uint256 _value) public onlyOwner {
        require(address(this).balance >= _value, "Insufficient fund");
        msg.sender.transfer(_value);
    }
    
    function withdrawAll() public onlyOwner {
        require(address(this).balance > 0, "Insufficient fund");
        msg.sender.transfer(address(this).balance);
    }
    
    function deposit() public payable onlyOwner {
        require(msg.value > 0, "You have to deposit at least 1 unit of CTXC");
    }

// -------------------------- Warranty Service ---------------------------------

    function payment(uint256 _serviceIndex) public;
}

