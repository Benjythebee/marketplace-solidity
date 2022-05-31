//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CryptovoxelsAccessControl.sol";
import "./Wrappers/ICollectionWrapper.sol";
/**
 * @dev This is a contract dedicating to registering CollectionWrappers made around other contracts in case they don't support ERC721 or ERC1155.
 * If a contract doesn't support ERC721 or ERC1155 we don't know how to interact with them.
 * Therefore we use wrappers (or proxies) to standardize them and tell us how to interact with those contracts.
 */
contract WrappersRegistryV1 is Pausable {
	// Contract name
    string private _name;
	///@dev Access control address
    address internal _accessControl;

	struct Wrapper {
		address wrapper;
		address implementation;
		string name;
		bool deleted;
	}

	event Registered(uint indexed id, address indexed implementation_,address indexed wrapper, string name);
	event Unregistered(uint indexed id, string name);

	mapping (address => uint) WrapperToId;
	mapping (string => uint) WrapperNameToId;
	mapping (address => uint) ImplementationToId;

	Wrapper[] wrappers;
	uint public wrapperCount = 0;

    function name() public view virtual returns (string memory) {
        return _name;
    }

	modifier whenAddressFree(address _addr) {
		if (isRegistered(_addr))
			return;
		_;
	}

	modifier whenWrapper(uint _id) {
		require(!wrappers[_id].deleted);
		_;
	}

	modifier whenNameFree(string memory name__) {
		if (WrapperNameToId[name__] != 0)
			return;
		_;
	}

    modifier onlyMember(address _addr){
        require(CryptovoxelsAccessControl(_accessControl).isMember(_addr),'Functionality limited to members');
    _;
    }

	constructor (address _accessControlImpl){
		_name = "Voxels Marketplace wrappers registy v1";
		_accessControl = _accessControlImpl;
	}

	function register(
		address implementation_,
		address wrapper_,
		string memory name_
	)
		external
		returns (bool)
	{
		return registerAs(
			implementation_,
   			wrapper_,
			name_
		);
	}

    function togglePause() public onlyMember(msg.sender){
        if(this.paused()){
            _unpause();
        }else{
            _pause();
        }
    }

	function unregister(uint _id)
		external
		whenWrapper(_id)
		onlyMember(msg.sender)
	{
		delete WrapperToId[wrappers[_id].wrapper];
		delete WrapperNameToId[wrappers[_id].name];
		delete ImplementationToId[wrappers[_id].implementation];
		wrappers[_id].deleted = true;
		wrapperCount = wrapperCount - 1;

        emit Unregistered(_id, wrappers[_id].name);
	}

	function getWrapper(uint _id)
		external
		view
		whenWrapper(_id)
		returns (
			address implementation,
			address wrapper,
			string memory name_
		)
	{
		Wrapper storage t = wrappers[_id];
		implementation = t.implementation;
		wrapper = t.wrapper;
		name_ = t.name;
	}

	function fromAddress(address _addr)
		external
		view
		whenWrapper(WrapperToId[_addr] - 1)
		returns (
			uint id_,
			address implementation_,
			address wrapper_,
			string memory name_
		)
	{
		id_ = WrapperToId[_addr] - 1;
		Wrapper storage t = wrappers[id_];
		implementation_ = t.implementation;
		wrapper_ = t.wrapper;
		name_ = t.name;
	}

	function fromImplementationAddress(address _addr)
		public
		view
		whenWrapper(ImplementationToId[_addr] - 1)
		returns (
			uint id_,
			address implementation_,
			address wrapper_,
			string memory name_
		)
	{
		id_ = ImplementationToId[_addr] - 1;
		Wrapper storage t = wrappers[id_];
		implementation_ = t.implementation;
		wrapper_ = t.wrapper;
		name_ = t.name;
	}

	function fromName(string memory name__)
		external
		view
		whenWrapper(WrapperNameToId[name__] - 1)
		returns (
			uint id_,
			address implementation_,
			address wrapper_,
			string memory name_
		)
	{
		id_ = WrapperNameToId[name__] - 1;
		Wrapper storage t = wrappers[id_];
		implementation_ = t.implementation;
		wrapper_ = t.wrapper;
		name_ = t.name;
	}

	function registerAs(
		address implementation_,
		address wrapper_,
		string memory name_
	)
		public
        whenNotPaused
		whenAddressFree(wrapper_)
		whenNameFree(name_)
		onlyMember(msg.sender)
		returns (bool registered)
	{
		require(IERC165(wrapper_).supportsInterface(type(ICollectionWrapper).interfaceId),"Contract does not support Wrapper interface");
		wrappers.push(Wrapper(
			implementation_,
            wrapper_,
			name_,
            false
		));
        uint length = wrappers.length;
		WrapperToId[wrapper_] = length;
		WrapperNameToId[name_] = length;
		ImplementationToId[implementation_] = length;

		emit Registered(
            wrappers.length - 1,
			implementation_,
			wrapper_,
			name_
		);

		wrapperCount = wrapperCount + 1;
		return true;
	}

    function isRegistered(address _address) public view returns(bool) {
        if (WrapperToId[_address] == 0) {
			return false;
        }
        return true;
    }


	function isWrapped(address _impl) public view returns (bool _isWrapped){
		return ImplementationToId[_impl]!=0;
	}
}