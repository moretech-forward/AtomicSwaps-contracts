
// File: contracts/Swaps/interfaces/IERC20.sol


pragma solidity ^0.8.23;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

// File: contracts/Swaps/ERC20Swap.sol


pragma solidity ^0.8.23;

/// @title AtomicERC20Swap
/// @notice This contract facilitates atomic swaps of ERC20 tokens using a secret key for completion.
/// @dev The contract leverages the ERC20 `transferFrom` method for deposits, allowing token swaps based on a hash key and a deadline.
contract AtomicERC20Swap {
    /// @notice One day in timestamp
    /// @dev Used to protect side B
    uint256 constant DAY = 86400;

    /// @notice The owner of the contract who initiates the swap.
    /// @dev Set at deployment and cannot be changed.
    address public immutable owner;

    /// @notice The other party involved in the swap.
    /// @dev Set at deployment and cannot be changed.
    address public immutable otherParty;

    /// @notice The ERC20 token to be swapped.
    /// @dev The contract holds and transfers tokens of this ERC20 type.
    IERC20 public immutable token;

    /// @notice Amount of tokens for swap
    /// @dev Used when calling the deposit function
    uint256 public immutable amount;

    /// @notice Deadline after which the swap cannot be accepted.
    /// @dev Represented as a Unix timestamp.
    uint256 public deadline;

    /// @notice The cryptographic hash of the secret key required to complete the swap.
    /// @dev The hash is used to ensure that the swap cannot be completed without the correct secret key.
    bytes32 public hashKey;

    /// @notice Emitted when the swap is confirmed with the correct secret key.
    /// @param key The secret key that was used to confirm the swap.
    event Swap(string indexed key);

    /// @param _token The address of the ERC20 token contract.
    /// @param _otherParty The address of the other party in the swap.
    /// @param _amount Number of tokens to be deposited into the contract
    constructor(address _token, address _otherParty, uint256 _amount) payable {
        owner = msg.sender;
        token = IERC20(_token);
        otherParty = _otherParty;
        amount = _amount;
    }

    /// @notice Deposits ERC20 tokens into the contract from the owner's balance.
    /// @dev Requires that the owner has approved the contract to transfer the specified `amount` of tokens on their behalf.
    /// @param _hashKey The cryptographic hash of the secret key needed to complete the swap.
    /// @param _deadline The Unix timestamp after which the owner can withdraw the tokens if the swap hasn't been completed.
    /// @param _flag Determines who the swap initiator is.
    function deposit(bytes32 _hashKey, uint256 _deadline, bool _flag) external {
        hashKey = _hashKey;
        if (_flag) deadline = _deadline + DAY;
        else deadline = _deadline;
        require(
            token.transferFrom(owner, address(this), amount),
            "Transfer failed"
        );
    }

    /// @notice Confirms the swap and transfers the ERC20 tokens to the other party if the provided key matches the hash key.
    /// @dev Requires that the key provided hashes to the stored hash key and transfers the token balance from this contract to the other party.
    /// @param _key The secret key to unlock the swap.
    function confirmSwap(string calldata _key) external {
        require(
            hashKey == keccak256(abi.encodePacked(_key)),
            "The key does not match the hash"
        );

        emit Swap(_key);
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(otherParty, balance), "Transfer failed");
    }

    /// @notice Allows the owner to withdraw the tokens if the swap is not completed by the deadline.
    /// @dev Checks if the current time is past the deadline and transfers the token balance from this contract to the owner.
    function withdrawal() external {
        require(block.timestamp > deadline, "Swap not yet expired");
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner, balance), "Transfer failed");
    }
}