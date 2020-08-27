pragma solidity ^0.4.24;

import "./Ownable.sol";

contract Institution is Ownable {
    
// ---------------------------- Company Information ------------------------------
    string public companyName;
    address public dataControllerAddress = 0x2ac5eb61288c47297e4c7d64249ee5310dc8dccb;
    
    // Only accessible by the contract moderator.
    // For institution moderator to change it's company name.
    function updateCompanyName(string _newName) public onlyOwner {
        companyName = _newName;
    }
    
    // Only accessible by the contract moderator.
    // update to latest deployed DataController.sol's address.
    function updateDataControllerAddress(address _newAddr) public onlyOwner {
        dataControllerAddress = _newAddr;
    }
     
    // @return uint256: required permission for this institution in bitmap format.
    function getRequiredPermissions() public view returns(uint256);

    // @return uint256: number of services provided by the institution.
    // Maximum list length : 256
    function getNumberOfServices()
        public view returns(uint256) ;
    
    // @returns the specific service name and fee in the above
    //  provided service list corresponding with the parameter:
    //  `_serviceIndex`.
    function getService(uint8 _serviceIndex)
        public view returns(string, uint256);

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
    
    // used for checking whether a single service is active for a user
    // @return bool: true for active, false for inactive
    function isServiceActive(uint8 _serviceIndex)
        public view returns(bool);
    
    // @return uint: all the active services that user has selected in bitmap format
    function getActiveServices()
        public view returns(uint256)
    {
        return activeServicesByUser[msg.sender];
    }
    
    // @return uint: all the available services that user can choose from in bitmap format
    function getAvailableServices()
        public view returns(uint256)
    {
        return availableServicesByUser[msg.sender];
    }

// -------------------------- Service Purchase ---------------------------------
    // Execute AI inference on users' physical data, 
    // then update their available services based on it.
    function checkForAvailableServices(address _userAddr) public;
    
    // Payable API
    // users are able to purchase services that are available to them.
    // Transaction fails if the user don't pay enough fee.
    function purchaseService(uint256 _serviceIndex)
      public payable;
}

contract Insurance is Institution {
    
// -------------------------- Basic Functions --------------------------------- 
    // Allow moderator to check contract's current balance.
    function getBalance() public view onlyOwner returns(uint256){
        return address(this).balance;
    }
    
    // Allow moderator to withdraw fund from the contract.
    // @Key: amount of fund for withdrawal
    function withdraw(uint256 _value) public onlyOwner {
        require(address(this).balance >= _value, "Insufficient fund");
        msg.sender.transfer(_value);
    }
    
    // Allow moderator to withdraw remaining fund from the contract.
    function withdrawAll() public onlyOwner {
        require(address(this).balance > 0, "Insufficient fund");
        msg.sender.transfer(address(this).balance);
    }
    
    // Payable API
    // Allow moderator to deposit fund to the contract
    function deposit() public payable onlyOwner {
        require(msg.value > 0, "You have to deposit at least 1 unit of CTXC");
    }

// -------------------------- Warranty Service ---------------------------------
    // User API: redeem the insurance payment
    // Condition: the user has purchased the service, and it's health condition is valid
    function payment(uint256 _serviceIndex) public;
}

