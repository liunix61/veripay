// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentPayAccount, AgentPayAccountFactory} from "../src/AgentPayAccount.sol";
import {FacilitatorSettlement, ReceiptsRegistry} from "../src/FacilitatorSettlement.sol";

contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address t, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a; balanceOf[t] += a; return true;
    }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

contract VeriPayTest is Test {
    MockUSDC internal usdc;
    AgentPayAccountFactory internal factory;
    ReceiptsRegistry internal registry;
    FacilitatorSettlement internal settlement;
    AgentPayAccount internal account;

    address internal owner = address(this);
    uint256 internal agentPk = 0xA6E7;
    address internal agentKey;
    address internal cmc = address(0x2001);        // whitelisted merchant
    address internal evilMerchant = address(0x2002);
    address internal relayer = address(0x2003);

    uint256 internal constant BUDGET   = 5_000_000;   // $5
    uint256 internal constant PER_TX   = 500_000;     // $0.50
    uint256 internal constant AMT      = 10_000;      // $0.01

    function setUp() public {
        agentKey = vm.addr(agentPk);
        usdc = new MockUSDC();
        factory = new AgentPayAccountFactory(address(usdc));
        registry = new ReceiptsRegistry();
        settlement = new FacilitatorSettlement(address(registry));
        registry.registerSettlement(address(settlement), true);

        address[] memory wl = new address[](1);
        wl[0] = cmc;
        AgentPayAccount.AccountPolicy memory p = AgentPayAccount.AccountPolicy({
            budget: BUDGET,
            perTxMax: PER_TX,
            expiresAt: uint64(block.timestamp + 48 hours),
            merchantWhitelist: wl
        });
        account = AgentPayAccount(factory.createAccount(agentKey, p));
        account.setFacilitator(address(settlement), true);

        usdc.mint(owner, BUDGET);
        usdc.approve(address(account), BUDGET);
        account.fund(BUDGET);
    }

    function _auth(address merchant, uint256 amount, uint256 nonce, uint256 deadline)
        internal view returns (FacilitatorSettlement.PaymentAuth memory)
    {
        return FacilitatorSettlement.PaymentAuth({
            account: address(account),
            merchant: merchant,
            amount: amount,
            nonce: nonce,
            deadline: deadline,
            resourceHash: keccak256("cmc:NVDA:quote")
        });
    }

    function _sign(FacilitatorSettlement.PaymentAuth memory a, uint256 pk)
        internal view returns (bytes memory)
    {
        bytes32 structHash = keccak256(abi.encode(
            settlement.AUTH_TYPEHASH(), a.account, a.merchant, a.amount, a.nonce, a.deadline, a.resourceHash
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", settlement.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    // ── factory ───────────────────────────────────

    function test_factory_createsAccount() public view {
        assertEq(account.owner(), owner);
        assertEq(account.sessionKey(), agentKey);
        assertEq(account.usdc(), address(usdc));
        (uint256 budget, uint256 perTx, uint64 exp) = account.getPolicy();
        assertEq(budget, BUDGET);
        assertEq(perTx, PER_TX);
        assertEq(exp, uint64(block.timestamp + 48 hours));
        assertTrue(account.isWhitelisted(cmc));
    }

    function test_factory_tracksAccountsPerOwner() public {
        address[] memory mine = factory.accountsOfOwner(owner);
        assertEq(mine.length, 1);
        assertEq(mine[0], address(account));
    }

    function test_fund_and_remaining() public view {
        assertEq(account.remaining(), BUDGET);
        assertEq(usdc.balanceOf(address(account)), BUDGET);
    }

    // ── limit checks (view order) ─────────────────

    function test_limits_allPass() public view {
        (bool ok, bytes32 reason) = account.checkLimits(cmc, AMT);
        assertTrue(ok);
        assertEq(reason, bytes32(0));
    }

    function test_limits_notWhitelisted() public view {
        (bool ok, bytes32 reason) = account.checkLimits(evilMerchant, AMT);
        assertFalse(ok);
        assertEq(reason, keccak256("NOT_WHITELISTED"));
    }

    function test_limits_txTooLarge() public view {
        (bool ok, bytes32 reason) = account.checkLimits(cmc, PER_TX + 1);
        assertFalse(ok);
        assertEq(reason, keccak256("TX_TOO_LARGE"));
    }

    function test_limits_expired() public {
        vm.warp(block.timestamp + 49 hours);
        (bool ok, bytes32 reason) = account.checkLimits(cmc, AMT);
        assertFalse(ok);
        assertEq(reason, keccak256("EXPIRED"));
    }

    function test_limits_revoked() public {
        account.revoke();
        (bool ok, bytes32 reason) = account.checkLimits(cmc, AMT);
        assertFalse(ok);
        assertEq(reason, keccak256("REVOKED"));
    }

    // ── x402 settlement happy path ────────────────

    function test_settle_success() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, AMT, 0, block.timestamp + 1 hours);
        vm.prank(relayer); // anyone can relay
        uint256 id = settlement.settle(a, _sign(a, agentPk));

        assertEq(id, 1);
        assertEq(usdc.balanceOf(cmc), AMT);
        assertEq(account.spent(), AMT);
        assertEq(account.remaining(), BUDGET - AMT);
        assertEq(settlement.nonces(address(account)), 1);
    }

    function test_settle_receiptLogged() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, AMT, 0, block.timestamp + 1 hours);
        uint256 id = settlement.settle(a, _sign(a, agentPk));
        ReceiptsRegistry.Receipt memory r = registry.verify(id);
        assertEq(r.account, address(account));
        assertEq(r.merchant, cmc);
        assertEq(r.amount, AMT);
        assertEq(r.resourceHash, keccak256("cmc:NVDA:quote"));
        assertEq(registry.receiptCount(), 1);
    }

    function test_settle_emitsEvent() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, AMT, 0, block.timestamp + 1 hours);
        vm.expectEmit(true, true, true, true);
        emit FacilitatorSettlement.PaymentSettled(1, address(account), cmc, AMT, keccak256("cmc:NVDA:quote"));
        settlement.settle(a, _sign(a, agentPk));
    }

    function test_settle_manyPaymentsConsumeBudget() public {
        vm.startPrank(relayer);
        for (uint256 i = 0; i < 5; i++) {
            FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, PER_TX, i, block.timestamp + 1 hours);
            settlement.settle(a, _sign(a, agentPk));
        }
        vm.stopPrank();
        assertEq(account.spent(), 5 * PER_TX);
        assertEq(account.remaining(), BUDGET - 5 * PER_TX);
    }

    // ── attack paths ──────────────────────────────

    function test_settle_replayReverts() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, AMT, 0, block.timestamp + 1 hours);
        bytes memory sig = _sign(a, agentPk);
        settlement.settle(a, sig);
        vm.expectRevert(FacilitatorSettlement.NonceMismatch.selector);
        settlement.settle(a, sig);
    }

    function test_settle_expiredReverts() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, AMT, 0, block.timestamp + 10);
        bytes memory sig = _sign(a, agentPk);
        vm.warp(block.timestamp + 11);
        vm.expectRevert(FacilitatorSettlement.SignatureExpired.selector);
        settlement.settle(a, sig);
    }

    function test_settle_wrongSignerReverts() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, AMT, 0, block.timestamp + 1 hours);
        bytes memory sig = _sign(a, 0xB0B);
        vm.expectRevert(FacilitatorSettlement.InvalidSignature.selector);
        settlement.settle(a, sig);
    }

    function test_settle_oldKeyInvalidAfterRotation() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, AMT, 0, block.timestamp + 1 hours);
        bytes memory sigWithOldKey = _sign(a, agentPk);
        address newKey = address(0x9999);
        account.rotateSessionKey(newKey);
        // leaked old key can no longer authorize payments
        vm.expectRevert(FacilitatorSettlement.InvalidSignature.selector);
        settlement.settle(a, sigWithOldKey);
    }

    function test_settle_overPerTx_revertsOnAccount() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, PER_TX + 1, 0, block.timestamp + 1 hours);
        bytes memory sig = _sign(a, agentPk);
        vm.expectRevert(AgentPayAccount.TxTooLarge.selector);
        settlement.settle(a, sig);
    }

    function test_settle_overBudget_revertsOnAccount() public {
        // pay $0.50 x10 = $5 budget hits the wall on the 11th... but perTx cap $0.50 →
        // 10 payments exhaust budget exactly; the 11th fails
        vm.startPrank(relayer);
        for (uint256 i = 0; i < 10; i++) {
            FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, PER_TX, i, block.timestamp + 1 hours);
            settlement.settle(a, _sign(a, agentPk));
        }
        FacilitatorSettlement.PaymentAuth memory last = _auth(cmc, PER_TX, 10, block.timestamp + 1 hours);
        bytes memory lastSig = _sign(last, agentPk);
        vm.expectRevert(AgentPayAccount.BudgetExhausted.selector);
        settlement.settle(last, lastSig);
        vm.stopPrank();
    }

    function test_settle_evilMerchant_reverts() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(evilMerchant, AMT, 0, block.timestamp + 1 hours);
        bytes memory sig = _sign(a, agentPk);
        vm.expectRevert(AgentPayAccount.NotWhitelisted.selector);
        settlement.settle(a, sig);
    }

    function test_settle_afterRevoke_reverts() public {
        account.revoke();
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, AMT, 0, block.timestamp + 1 hours);
        bytes memory sig = _sign(a, agentPk);
        vm.expectRevert(AgentPayAccount.AccountDead.selector);
        settlement.settle(a, sig);
    }

    function test_settle_notFacilitatorDirectCall_reverts() public {
        // calling executePayment directly without being registered facilitator
        address fakeFac = address(0x3001);
        vm.prank(fakeFac);
        vm.expectRevert(AgentPayAccount.NotFacilitator.selector);
        account.executePayment(cmc, AMT);
    }

    // ── verify pre-check ──────────────────────────

    function test_verify_preCheck() public view {
        FacilitatorSettlement.PaymentAuth memory good = _auth(cmc, AMT, 0, block.timestamp + 1 hours);
        (bool ok, bytes32 reason) = settlement.verify(good);
        assertTrue(ok);
        assertEq(reason, bytes32(0));

        FacilitatorSettlement.PaymentAuth memory bad = _auth(evilMerchant, AMT, 0, block.timestamp + 1 hours);
        (ok, reason) = settlement.verify(bad);
        assertFalse(ok);
        assertEq(reason, keccak256("NOT_WHITELISTED"));
    }

    // ── registry ──────────────────────────────────

    function test_registry_log_revertsNonSettlement() public {
        vm.prank(address(0x4001));
        vm.expectRevert(ReceiptsRegistry.NotSettlement.selector);
        registry.log(address(account), cmc, AMT, keccak256("x"));
    }

    function test_registry_registerSettlement_onlyOwner() public {
        vm.prank(address(0x4001));
        vm.expectRevert(ReceiptsRegistry.NotOwner.selector);
        registry.registerSettlement(address(0x4001), true);
    }

    // ── sweep ─────────────────────────────────────

    function test_sweep_returnsUnspent() public {
        FacilitatorSettlement.PaymentAuth memory a = _auth(cmc, AMT, 0, block.timestamp + 1 hours);
        settlement.settle(a, _sign(a, agentPk));
        uint256 ownerBefore = usdc.balanceOf(owner);
        account.sweep();
        assertEq(usdc.balanceOf(owner) - ownerBefore, BUDGET - AMT);
        assertEq(usdc.balanceOf(address(account)), 0);
    }

    function test_sweep_onlyOwner() public {
        vm.prank(address(0x4001));
        vm.expectRevert(AgentPayAccount.NotOwner.selector);
        account.sweep();
    }
}
