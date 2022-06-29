//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWrappersRegistry {

	struct Wrapper {
		address implementation;
		address wrapper;
		string name;
		bool deleted;
	}

	event Registered(uint indexed id, address indexed implementation_,address indexed wrapper, string name);
	event Unregistered(uint indexed id, string name);


    function name() external view returns (string memory);

	function register(
		address implementation_,
		address wrapper_,
		string memory name_
	)
		external
		returns (bool);

    function togglePause() external;

	function unregister(uint _id)
		external;

	function getWrapper(uint _id)
		external
		view
		returns (
			address implementation,
			address wrapper,
			string memory name_
		);

	function fromAddress(address _addr)
		external
		view
		returns (
			uint id_,
			address implementation_,
			address wrapper_,
			string memory name_
		);

	function fromImplementationAddress(address _addr)
		external
		view
		returns (
			uint id_,
			address implementation_,
			address wrapper_,
			string memory name_
		);

	function fromName(string memory name__)
		external
		view
		returns (
			uint id_,
			address implementation_,
			address wrapper_,
			string memory name_
		);

	function registerAs(
		address implementation_,
		address wrapper_,
		string memory name_
	)
		external
		returns (bool registered);

    function isRegistered(address _address) external view returns(bool);

	function isWrapped(address _impl) external view returns (bool _isWrapped);
}