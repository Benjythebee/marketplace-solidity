// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IERC20Registry {
    function register(
        address _addr,
        string memory _symbol,
        uint256 _decimals,
        string memory _name
    ) external payable returns (bool);

    function togglePause(bool _paused) external;

    function unregister(uint256 _id) external;

    function setFee(uint256 _fee) external;

    function drain() external;

    function token(uint256 _id)
        external
        view
        returns (
            address addr,
            string memory symbol,
            uint256 decimals,
            string memory name
        );

    function fromAddress(address _addr)
        external
        view
        returns (
            uint256 id,
            string memory symbol,
            uint256 decimals,
            string memory name
        );

    function fromSymbol(string memory _symbol)
        external
        view
        returns (
            uint256 id,
            address addr,
            uint256 decimals,
            string memory name
        );

    function registerAs(
        address _addr,
        string memory _symbol,
        uint256 _decimals,
        string memory _name
    ) external payable returns (bool);

    function isRegistered(address _addr) external returns (bool);
}
