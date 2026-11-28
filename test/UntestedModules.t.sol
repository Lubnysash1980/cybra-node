// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../modules/module_124_timelock/contracts/TimeLock.sol";
import "../modules/module_125_anchor/contracts/Anchor.sol";
import "../modules/module_137_escrow/contracts/Escrow.sol";
import "../modules/module_147_reputation_v2/contracts/Reputation.sol";
import "../src/CYBRASelfLearning.sol";
import "../src/CYBRASelfLearningV2.sol";

contract UntestedModulesTest is Test {
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
