// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../modules/module_124_timelock/contracts/TimeLock.sol";
import "../modules/module_125_anchor/contracts/Anchor.sol";
import "../modules/module_137_escrow/contracts/Escrow.sol";
import "../modules/module_147_reputation_v2/contracts/Reputation.sol";
import "../src/CYBRASelfLearning.sol";
import "../src/CYBRASelfLearningV2.sol";
import "../src/CYBRADualLicenseRoyalty15.sol";

contract UntestedModulesTest is Test {
    receive() external payable {}
    function test_TimeLockReleaseAndCancelRules() public {
        TimeLock t = new TimeLock();
        address beneficiary = address(0xBEEF);
        vm.deal(address(this), 3 ether);
        bytes32 id = t.create{value: 1 ether}(keccak256("cid"), beneficiary, 1 days, 1 hours, "");
        vm.expectRevert(TimeLock.StillLocked.selector); t.release(id);
        vm.warp(block.timestamp + 1 days);
        uint256 beforeBal = beneficiary.balance;
        t.release(id);
        assertEq(beneficiary.balance, beforeBal + 1 ether);
        assertTrue(t.get(id).released);

        bytes32 cancelId = t.create{value: 1 ether}(keccak256("cancel"), beneficiary, 1 days, 1 hours, "");
        uint256 ownerBefore = address(this).balance;
        t.cancel(cancelId);
        assertEq(address(this).balance, ownerBefore + 1 ether);
        assertTrue(t.get(cancelId).cancelled);
    }

    function test_TimeLockRejectsZeroBeneficiaryAndZeroValue() public {
        TimeLock t = new TimeLock();
        vm.deal(address(this), 1 ether);
        vm.expectRevert(TimeLock.BadTimes.selector);
        t.create{value: 1 ether}(keccak256("zero-beneficiary"), address(0), 1 days, 1 hours, "");
        vm.expectRevert(TimeLock.BadTimes.selector);
        t.create(keccak256("zero-value"), address(0xBEEF), 1 days, 1 hours, "");
    }

    function test_AnchorIsImmutableAndVerifiable() public {
        Anchor a = new Anchor();
        bytes32 h = keccak256("document");
        a.anchor(keccak256("cid"), h, "evidence");
        (bool exists, address publisher, uint64 at) = a.verify(h);
        assertTrue(exists); assertEq(publisher, address(this)); assertEq(at, uint64(block.timestamp));
        vm.expectRevert(Anchor.AlreadyAnchored.selector);
        a.anchor(keccak256("other"), h, "overwrite");
    }

    function test_ReputationScoreBoundsAndDuplicateProtection() public {
        Reputation r = new Reputation();
        address subject = address(0xBEEF);
        bytes32 cid = keccak256("review");
        r.rate(subject, 5, cid);
        vm.expectRevert(bytes("already rated for this cid"));
        r.rate(subject, 4, cid);
        vm.expectRevert(bytes("score 1-5"));
        r.rate(subject, 0, keccak256("bad"));
        vm.prank(address(0xCAFE)); r.rate(subject, 3, keccak256("second"));
        assertEq(r.total(subject), 2);
        assertEq(r.avgScore(subject), 400);
    }

    function test_ModuleEscrowDisputeAndArbitration() public {
        Escrow e = new Escrow();
        address seller = address(0xBEEF);
        address arbiter = address(0xCAFE);
        vm.deal(address(this), 2 ether);
        bytes32 id = e.create{value: 1 ether}(keccak256("cid"), seller, arbiter, uint64(block.timestamp + 1 days), "");
        e.dispute(id, "delivery issue");
        uint256 beforeBal = address(this).balance;
        vm.prank(arbiter); e.arbitrate(id, false);
        assertEq(address(this).balance, beforeBal + 1 ether);
        (,,,,,,Escrow.State state,,) = e.deals(id);
        assertEq(uint256(state), uint256(Escrow.State.Refunded));
    }

    function test_ModuleEscrowRejectsInvalidPartiesAndZeroValue() public {
        Escrow e = new Escrow();
        address seller = address(0xBEEF);
        address arbiter = address(0xCAFE);
        uint64 deadline = uint64(block.timestamp + 1 days);
        vm.deal(address(this), 1 ether);

        vm.expectRevert(Escrow.NotParty.selector);
        e.create{value: 1 ether}(keccak256("zero-seller"), address(0), arbiter, deadline, "");
        vm.expectRevert(Escrow.NotParty.selector);
        e.create{value: 1 ether}(keccak256("zero-arbiter"), seller, address(0), deadline, "");
        vm.expectRevert(Escrow.BadState.selector);
        e.create(keccak256("zero-value"), seller, arbiter, deadline, "");
        vm.expectRevert(Escrow.TooLate.selector);
        e.create{value: 1 ether}(keccak256("expired"), seller, arbiter, uint64(block.timestamp), "");
    }

    function test_ModuleEscrowSameBlockSameCIDCreatesDistinctDeals() public {
        Escrow e = new Escrow();
        address seller = address(0xBEEF);
        address arbiter = address(0xCAFE);
        bytes32 cid = keccak256("same-cid");
        uint64 deadline = uint64(block.timestamp + 1 days);
        vm.deal(address(this), 2 ether);
        bytes32 first = e.create{value: 1 ether}(cid, seller, arbiter, deadline, "first");
        bytes32 second = e.create{value: 1 ether}(cid, seller, arbiter, deadline, "second");
        assertTrue(first != second);
        assertEq(e.dealIds(0), first);
        assertEq(e.dealIds(1), second);
    }

    function test_DualLicenseCannotOverwriteOrMutateAfterTRUE100() public {
        address verifier1 = address(0xBEEF);
        address verifier2 = address(0xCAFE);
        CYBRADualLicenseRoyalty15 license = new CYBRADualLicenseRoyalty15(verifier1, verifier2);
        bytes32 id = keccak256("license");
        bytes32 evidence = keccak256("evidence");
        license.registerLicense(id, keccak256("commit"), keccak256("repo"), address(0xD00D));
        vm.expectRevert(bytes("LICENSE_ALREADY_REGISTERED"));
        license.registerLicense(id, keccak256("other-commit"), keccak256("other-repo"), address(0xD00D));
        vm.prank(verifier1); license.approveViolation(id, evidence);
        vm.prank(verifier2); license.approveViolation(id, evidence);
        license.confirmProfit(id, 100 ether);
        license.updateConfirmation(id, 1, 1);
        license.confirmTRUE100(id);
        vm.expectRevert(bytes("LICENSE_FINALIZED"));
        license.confirmProfit(id, 200 ether);
        vm.expectRevert(bytes("LICENSE_FINALIZED"));
        license.updateConfirmation(id, 2, 2);
        assertTrue(license.isTRUE100(id));
        (uint256 profit, uint256 royalty) = license.getRoyaltyState(id);
        assertEq(profit, 100 ether);
        assertEq(royalty, 15 ether);
    }

    function test_SelfLearningRequiresAllNineChecks() public {
        address verifier = address(0xBEEF);
        CYBRASelfLearning s = new CYBRASelfLearning(verifier);
        bytes32 ds = keccak256("ds"); bytes32 runId = keccak256("run");
        s.registerDataset(ds, keccak256("content"), keccak256("manifest"), "dataset", "source", 10);
        s.freezeDataset(ds);
        s.createLearningRun(runId, ds, keccak256("input"));
        s.startLearning(runId);
        s.completeLearning(runId, keccak256("output"), keccak256("evidence"), 10, 2, 2, 0);
        vm.prank(verifier);
        vm.expectRevert(bytes("CHECKS_INCOMPLETE"));
        s.approveTrue100(runId);
        bytes32[9] memory checks = [s.CHECK_DATASET(), s.CHECK_INPUT(), s.CHECK_OUTPUT(), s.CHECK_EVIDENCE(), s.CHECK_REPRODUCIBILITY(), s.CHECK_INDEPENDENT_VERIFICATION(), s.CHECK_CROSS_RUNTIME(), s.CHECK_HOLDOUT(), s.CHECK_EVO()];
        for (uint256 i; i < 9; ++i) { vm.prank(verifier); s.passCheck(runId, checks[i]); }
        vm.prank(verifier); s.approveTrue100(runId);
        assertTrue(s.isTRUE100(runId));
    }

    function test_SelfLearningV2RequiresHoldoutAndNineChecks() public {
        CYBRASelfLearningV2 s = new CYBRASelfLearningV2();
        bytes32 ds = keccak256("ds"); bytes32 runId = keccak256("run");
        bytes32 hyp = keccak256("hyp"); bytes32 exp1 = keccak256("exp1"); bytes32 exp2 = keccak256("exp2");
        s.registerDataset(ds, keccak256("content"), keccak256("manifest"), "dataset", "source", 10);
        s.freezeDataset(ds);
        s.createRun(runId, ds, keccak256("input"));
        s.createHypothesis(hyp, runId, keccak256("rule"), "test hypothesis");
        s.createExperiment(exp1, runId, hyp, keccak256("input1"), keccak256("expected1"), false);
        s.completeExperiment(exp1, keccak256("actual1"), keccak256("evidence1"), true);
        s.startHoldout(runId);
        s.createExperiment(exp2, runId, hyp, keccak256("input2"), keccak256("expected2"), true);
        s.completeExperiment(exp2, keccak256("actual2"), keccak256("evidence2"), true);
        s.finishResearch(runId, keccak256("output"), keccak256("final-evidence"));
        vm.expectRevert(bytes("NOT_ALL_CHECKS")); s.approveTrue100(runId);
        for (uint256 i = 1; i <= 9; ++i) s.passCheck(runId, i);
        s.approveTrue100(runId);
        assertTrue(s.isTRUE100(runId));
        assertTrue(s.isVerified(runId));
    }
}
