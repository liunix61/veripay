// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAgentPayAccount {
    function executePayment(address merchant, uint256 amount) external;
    function checkLimits(address merchant, uint256 amount) external view returns (bool, bytes32);
    function sessionKey() external view returns (address);
}

/// @title ReceiptsRegistry — on-chain receipts for machine commerce
/// @notice Every settled payment leaves a receipt (merchant/amount/resourceHash).
///         Merchants and users verify delivery disputes against these receipts.
contract ReceiptsRegistry {
    struct Receipt {
        address account;
        address merchant;
        uint256 amount;
        bytes32 resourceHash;
        uint64 timestamp;
    }

    address public owner;
    mapping(address => bool) public settlementContracts;
    uint256 public nextId = 1;
    mapping(uint256 => Receipt) private receipts;

    event ReceiptLogged(uint256 indexed receiptId, address indexed account, address indexed merchant, uint256 amount, bytes32 resourceHash);
    event SettlementRegistered(address indexed settlement, bool enabled);

    error NotOwner();
    error NotSettlement();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerSettlement(address s, bool enabled) external onlyOwner {
        settlementContracts[s] = enabled;
        emit SettlementRegistered(s, enabled);
    }

    function log(address account, address merchant, uint256 amount, bytes32 resourceHash)
        external
        returns (uint256 receiptId)
    {
        if (!settlementContracts[msg.sender]) revert NotSettlement();
        receiptId = nextId++;
        receipts[receiptId] = Receipt({
            account: account,
            merchant: merchant,
            amount: amount,
            resourceHash: resourceHash,
            timestamp: uint64(block.timestamp)
        });
        emit ReceiptLogged(receiptId, account, merchant, amount, resourceHash);
    }

    function verify(uint256 receiptId) external view returns (Receipt memory) {
        return receipts[receiptId];
    }

    function receiptCount() external view returns (uint256) {
        return nextId - 1;
    }
}

/// @title FacilitatorSettlement — x402 settlement with agent-signed EIP-712 auths
/// @notice Flow: agent signs PaymentAuth(account, merchant, amount, nonce,
///         deadline, resourceHash) with its session key → anyone relays →
///         verify signature + limits → account pays merchant → receipt logged.
///         No trust in the facilitator required: the signature is the authority
///         and merchants watch ReceiptsRegistry events.
contract FacilitatorSettlement {
    struct PaymentAuth {
        address account;
        address merchant;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
        bytes32 resourceHash;
    }

    ReceiptsRegistry public immutable registry;
    address public owner;

    /// @notice per-account next expected nonce
    mapping(address => uint256) public nonces;

    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant AUTH_TYPEHASH =
        keccak256("PaymentAuth(address account,address merchant,uint256 amount,uint256 nonce,uint256 deadline,bytes32 resourceHash)");
    string public constant PAYMENT_AUTH_TYPEHASH_STR =
        "PaymentAuth(address account,address merchant,uint256 amount,uint256 nonce,uint256 deadline,bytes32 resourceHash)";
    bytes32 public immutable DOMAIN_SEPARATOR;

    event PaymentSettled(
        uint256 indexed receiptId,
        address indexed account,
        address indexed merchant,
        uint256 amount,
        bytes32 resourceHash
    );

    error NotOwner();
    error SignatureExpired();
    error NonceMismatch();
    error InvalidSignature();
    error ZeroAmount();
    error ZeroMerchant();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address registry_) {
        owner = msg.sender;
        registry = ReceiptsRegistry(registry_);
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256("VeriPay"), keccak256("1"), block.chainid, address(this))
        );
    }

    /// @notice Settle one payment. Relayer-agnostic: anyone can submit.
    function settle(PaymentAuth calldata auth, bytes calldata sig)
        external
        returns (uint256 receiptId)
    {
        if (auth.amount == 0) revert ZeroAmount();
        if (auth.merchant == address(0)) revert ZeroMerchant();
        if (block.timestamp > auth.deadline) revert SignatureExpired();
        if (auth.nonce != nonces[auth.account]) revert NonceMismatch();

        // signature must come from the account's current session key
        address expected = IAgentPayAccount(auth.account).sessionKey();
        bytes32 structHash = keccak256(abi.encode(
            AUTH_TYPEHASH, auth.account, auth.merchant, auth.amount, auth.nonce, auth.deadline, auth.resourceHash
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signer = _recover(digest, sig);
        if (signer == address(0) || signer != expected) revert InvalidSignature();

        // effects
        nonces[auth.account] = auth.nonce + 1;

        // interaction: account re-checks its own limits, then pays merchant
        IAgentPayAccount(auth.account).executePayment(auth.merchant, auth.amount);
        receiptId = registry.log(auth.account, auth.merchant, auth.amount, auth.resourceHash);

        emit PaymentSettled(receiptId, auth.account, auth.merchant, auth.amount, auth.resourceHash);
    }

    /// @notice Pre-settlement simulation for facilitators/merchants (eth_call).
    function verify(PaymentAuth calldata auth) external view returns (bool ok, bytes32 reason) {
        if (block.timestamp > auth.deadline) return (false, bytes32("EXPIRED"));
        if (auth.nonce != nonces[auth.account]) return (false, bytes32("NONCE"));
        return IAgentPayAccount(auth.account).checkLimits(auth.merchant, auth.amount);
    }

    function _recover(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        if (sig.length != 65) return address(0);
        bytes32 r = bytes32(sig[0:32]);
        bytes32 s = bytes32(sig[32:64]);
        uint8 v = uint8(sig[64]);
        if (v < 27) v += 27;
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return address(0);
        }
        return ecrecover(digest, v, r, s);
    }
}
