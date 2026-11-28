// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRALevelController.sol";

contract CYBRALevelControllerTest is Test {
    CYBRALevelController controller;

    bytes32 constant EVIDENCE = keccak256("CYBRA-EVIDENCE");

    bytes32 constant SNAPSHOT = keccak256("CYBRA-SNAPSHOT");

    function setUp() public {
        controller = new CYBRALevelController(22);
    }

    function test_StartsBlocked() public {
        assertEq(controller.currentLevel(), 22);
        assertFalse(controller.true100());
        assertFalse(controller.mainnetGateOpen());
    }

    function test_Below100CannotBecomeTRUE100() public {
        controller.updateEvidence(100, 99, EVIDENCE);

        vm.expectRevert("NOT_ALL_CHECKS_PASSED");
        controller.confirmTRUE100();

        assertFalse(controller.true100());
    }

    function test_SnapshotRequiresTRUE100() public {
        controller.updateEvidence(100, 99, EVIDENCE);

        vm.expectRevert("TRUE100_REQUIRED");
        controller.createSnapshot(SNAPSHOT);
    }

    function test_100AllowsSnapshotLiveAndMainnetGate() public {
        controller.updateEvidence(100, 100, EVIDENCE);

        controller.confirmTRUE100();
        assertTrue(controller.true100());

        controller.createSnapshot(SNAPSHOT);
        controller.enableLive();
        controller.openMainnetGate();

        assertTrue(controller.mainnetGateOpen());
        assertTrue(controller.isTRUE100());
    }


    function test_ChangingEvidenceAfterLiveInvalidatesAllApprovals() public {
        controller.updateEvidence(10, 10, EVIDENCE);
        controller.confirmTRUE100();
        controller.createSnapshot(SNAPSHOT);
        controller.enableLive();
        controller.openMainnetGate();

        assertTrue(controller.isTRUE100());

        // Even a revised evidence set that still scores 100% must restart TEST.
        controller.updateEvidence(20, 20, keccak256("REVISED_EVIDENCE"));

        assertFalse(controller.true100());
        assertFalse(controller.mainnetGateOpen());
        assertFalse(controller.isTRUE100());

        (
            ,
            ,
            ,
            ,
            bool levelTRUE100,
            bool snapshotCreated,
            bool liveEnabled,
            bool levelMainnetGateOpen,
            CYBRALevelController.Mode currentMode,
            ,
        ) = controller.getCurrentState();

        assertFalse(levelTRUE100);
        assertFalse(snapshotCreated);
        assertFalse(liveEnabled);
        assertFalse(levelMainnetGateOpen);
        assertEq(uint256(currentMode), uint256(CYBRALevelController.Mode.TEST));
    }

    function test_CannotAdvanceUntilMainnetGateIsOpen() public {
        controller.updateEvidence(10, 10, EVIDENCE);
        controller.confirmTRUE100();
        controller.createSnapshot(SNAPSHOT);
        controller.enableLive();

        vm.expectRevert("CURRENT_MAINNET_GATE_CLOSED");
        controller.advanceLevel();
    }

    function test_NextLevelRequiresCurrentTRUE100() public {
        controller.updateEvidence(100, 99, EVIDENCE);

        vm.expectRevert("CURRENT_LEVEL_NOT_TRUE100");
        controller.advanceLevel();

        assertEq(controller.currentLevel(), 22);
    }

    function test_AdvanceCreatesNewBlockedLevel() public {
        controller.updateEvidence(100, 100, EVIDENCE);
        controller.confirmTRUE100();
        controller.createSnapshot(SNAPSHOT);
        controller.enableLive();

        controller.advanceLevel();

        assertEq(controller.currentLevel(), 23);
        assertFalse(controller.true100());
        assertFalse(controller.mainnetGateOpen());
    }
}
