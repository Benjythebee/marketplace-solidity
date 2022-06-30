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
	/// Contract name
    string private _name;
	///@dev Access control address
    address internal _accessControl;

	/**
	* Wrapper struct
	* @dev implementation - the contract the wrapper is for
	* @dev wrapper - the address of the wrapper
	* @dev name - name of the wrapper
	* @dev deleted - Know if wrapper is deleted or not.
	*/
	struct Wrapper {
		address implementation;
		address wrapper;
		string name;
		bool deleted;
	}

	event Registered(uint indexed id, address indexed implementation_,address indexed wrapper, string name);
	event Unregistered(uint indexed id, string name);

	mapping (address => uint) WrapperToId;
	mapping (string => uint) WrapperNameToId;
	mapping (address => uint) ImplementationToId;
	mapping (address => bool) registeredImplementationLookup;

	Wrapper[] wrappers;

	///@dev name of the contract
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

		//@dev we add address 0 as the first wrapper, so we know index 0 is invalid
		WrapperToId[address(0)]=0;
		WrapperNameToId['']=0;
		ImplementationToId[address(0)]=0;
		wrappers.push(Wrapper(
			address(0),
            address(0),
			'',
            false
		));
	}

    function togglePause() public onlyMember(msg.sender){
        if(this.paused()){
            _unpause();
        }else{
            _pause();
        }
    }
	/**
	 * @notice remove a wrapper, its name and implementation from the registry
	 * @param _id uint, Id of the wrapper.
	 */
	function unregister(uint _id)
		external
		whenWrapper(_id)
		onlyMember(msg.sender)
	{
		delete WrapperToId[wrappers[_id].wrapper];
		delete WrapperNameToId[wrappers[_id].name];
		delete ImplementationToId[wrappers[_id].implementation];
		delete registeredImplementationLookup[wrappers[_id].implementation];
		wrappers[_id].deleted = true;

        emit Unregistered(_id, wrappers[_id].name);
	}
	/**
	 * @notice Get a wrapper given an ID
	 * @param _id uint, Id of the wrapper.
	 */
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
	/**
	 * @notice Get a wrapper from its address
	 * @param _addr address, address of the wrapper
	 */
	function fromAddress(address _addr)
		external
		view
		whenWrapper(WrapperToId[_addr])
		returns (
			uint id_,
			address implementation_,
			address wrapper_,
			string memory name_
		)
	{
		id_ = WrapperToId[_addr];
		Wrapper storage t = wrappers[id_];
		implementation_ = t.implementation;
		wrapper_ = t.wrapper;
		name_ = t.name;
	}
	/**
	 * @notice Get a wrapper from the implementation address
	 * @param _addr address, address of the implementation
	 */
	function fromImplementationAddress(address _addr)
		public
		view
		whenWrapper(ImplementationToId[_addr])
		returns (
			uint id_,
			address implementation_,
			address wrapper_,
			string memory name_
		)
	{
		id_ = ImplementationToId[_addr];
		Wrapper storage t = wrappers[id_];
		implementation_ = t.implementation;
		wrapper_ = t.wrapper;
		name_ = t.name;
	}
	/**
	 * @notice Get a wrapper from its name
	 * @param name__ string, the name of the wrapper
	 */
	function fromName(string memory name__)
		external
		view
		whenWrapper(WrapperNameToId[name__])
		returns (
			uint id_,
			address implementation_,
			address wrapper_,
			string memory name_
		)
	{
		id_ = WrapperNameToId[name__];
		Wrapper storage t = wrappers[id_];
		implementation_ = t.implementation;
		wrapper_ = t.wrapper;
		name_ = t.name;
	}

	/**
	 * @notice register an implementation, its wrapper and the wrapper's name
	 * @param implementation_ address of the implementation
	 * @param wrapper_ address of the wrapper contract
	 * @param name_ string
	 */
	function register(
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
		WrapperToId[wrapper_] = length -1;
		WrapperNameToId[name_] = length -1;
		registeredImplementationLookup[implementation_] =true;
		ImplementationToId[implementation_] = length -1;

		emit Registered(
            wrappers.length - 1,
			implementation_,
			wrapper_,
			name_
		);
		return true;
	}
	///@dev check if wrapper address exists
    function isRegistered(address _address) public view returns(bool) {
        return WrapperToId[_address] != 0;
    }

	/**
	 * @param _impl implementation address
	 * @return _isWrapped bool whether or not the implementation is wrapped
	 */
	function isWrapped(address _impl) public view returns (bool _isWrapped){
		return registeredImplementationLookup[_impl];
	}
}