// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20VA {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address a) external view returns (uint256);
}

/// @title AgentPayAccount — limit-enforced payment account for one AI agent
/// @notice The agent never custodies funds beyond its budget; every payment is
///         gated by four hard on-chain limits: TTL, merchant whitelist, per-tx
///         cap, and total budget. Owner can freeze instantly (revoke).
contract AgentPayAccount {
    struct AccountPolicy {
        uint256 budget;        // total budget (USDC 6dp)
        uint256 perTxMax;      // per-payment cap
        uint64 expiresAt;      // TTL
        address[] merchantWhitelist;
    }

    address public owner;        // creator/controller
    address public factory;
    address public usdc;
    address public sessionKey;   // the agent's signing key
    bool public revoked;
    bool public paused;

    uint256 public spent;
    AccountPolicy private policy;
    mapping(address => bool) private whitelist;

    /// @notice settlement contracts allowed to pull payments
    mapping(address => bool) public facilitator;

    event PaymentExecuted(address indexed merchant, uint256 amount, bytes32 reason);
    event Funded(uint256 amount);
    event Revoked();
    event SessionKeyRotated(address indexed oldKey, address indexed newKey);
    event FacilitatorSet(address indexed facilitator, bool enabled);

    error NotOwner();
    error NotFacilitator();
    error AccountDead();            // revoked or paused
    error Expired();
    error NotWhitelisted();
    error TxTooLarge();
    error BudgetExhausted();
    error KeyAlreadyBound();

    // reason codes for off-chain pre-checks (eth_call)
    bytes32 public constant R_EXPIRED        = keccak256("EXPIRED");
    bytes32 public constant R_REVOKED        = keccak256("REVOKED");
    bytes32 public constant R_NOT_WHITELISTED = keccak256("NOT_WHITELISTED");
    bytes32 public constant R_TX_TOO_LARGE   = keccak256("TX_TOO_LARGE");
    bytes32 public constant R_BUDGET         = keccak256("BUDGET_EXHAUSTED");

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address usdc_, address owner_, address sessionKey_, AccountPolicy memory p) {
        factory = msg.sender;
        usdc = usdc_;
        owner = owner_;
        sessionKey = sessionKey_;
        _setPolicy(p);
    }

    function _setPolicy(AccountPolicy memory p) internal {
        policy.budget = p.budget;
        policy.perTxMax = p.perTxMax;
        policy.expiresAt = p.expiresAt;
        for (uint256 i = 0; i < p.merchantWhitelist.length; i++) {
            whitelist[p.merchantWhitelist[i]] = true;
        }
    }

    // ──────────────────────────────────────────────
    // Funding & control
    // ──────────────────────────────────────────────

    /// @notice Pull budget from owner (owner must approve this account first).
    function fund(uint256 amount) external onlyOwner {
        IERC20VA(usdc).transferFrom(msg.sender, address(this), amount);
        emit Funded(amount);
    }

    /// @notice Return unspent balance to owner.
    function sweep() external onlyOwner {
        uint256 bal = IERC20VA(usdc).balanceOf(address(this));
        IERC20VA(usdc).transfer(owner, bal);
    }

    /// @notice Instant freeze — faster than a credit-card block.
    function revoke() external onlyOwner {
        revoked = true;
        emit Revoked();
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
    }

    function setFacilitator(address f, bool enabled) external onlyOwner {
        facilitator[f] = enabled;
        emit FacilitatorSet(f, enabled);
    }

    function rotateSessionKey(address newKey) external onlyOwner {
        emit SessionKeyRotated(sessionKey, newKey);
        sessionKey = newKey;
    }

    // ──────────────────────────────────────────────
    // Limits (the core)
    // ──────────────────────────────────────────────

    /// @notice Ordered limit check; off-chain /verify pre-checks via eth_call.
    function checkLimits(address merchant, uint256 amount)
        external view returns (bool ok, bytes32 reason)
    {
        if (revoked || paused) return (false, R_REVOKED);
        if (block.timestamp > policy.expiresAt) return (false, R_EXPIRED);
        if (!whitelist[merchant]) return (false, R_NOT_WHITELISTED);
        if (amount > policy.perTxMax) return (false, R_TX_TOO_LARGE);
        if (spent + amount > policy.budget) return (false, R_BUDGET);
        return (true, bytes32(0));
    }

    /// @notice Called by an authorized facilitator after signature verification.
    function executePayment(address merchant, uint256 amount) external {
        if (!facilitator[msg.sender]) revert NotFacilitator();
        (bool ok, bytes32 reason) = this.checkLimits(merchant, amount);
        if (!ok) {
            if (reason == R_EXPIRED) revert Expired();
            if (reason == R_NOT_WHITELISTED) revert NotWhitelisted();
            if (reason == R_TX_TOO_LARGE) revert TxTooLarge();
            if (reason == R_BUDGET) revert BudgetExhausted();
            revert AccountDead();
        }
        spent += amount;
        IERC20VA(usdc).transfer(merchant, amount);
        emit PaymentExecuted(merchant, amount, reason);
    }

    // ──────────────────────────────────────────────
    // Views
    // ──────────────────────────────────────────────

    function remaining() external view returns (uint256) {
        return policy.budget - spent;
    }

    function getPolicy() external view returns (uint256 budget, uint256 perTxMax, uint64 expiresAt) {
        return (policy.budget, policy.perTxMax, policy.expiresAt);
    }

    function isWhitelisted(address merchant) external view returns (bool) {
        return whitelist[merchant];
    }
}

/// @title AgentPayAccountFactory — one-click limit-enforced account per agent
contract AgentPayAccountFactory {
    address public usdc;
    mapping(address => address[]) private accountsOf;

    event AccountCreated(address indexed account, address indexed owner, address sessionKey);

    constructor(address usdc_) {
        usdc = usdc_;
    }

    function createAccount(address sessionKey, AgentPayAccount.AccountPolicy calldata p)
        external
        returns (address account)
    {
        account = address(new AgentPayAccount(usdc, msg.sender, sessionKey, p));
        accountsOf[msg.sender].push(account);
        emit AccountCreated(account, msg.sender, sessionKey);
    }

    function accountsOfOwner(address owner) external view returns (address[] memory) {
        return accountsOf[owner];
    }
}
