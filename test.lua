--!strict
-- Direct test file for running tests

local totalPassed = 0
local totalFailed = 0

-- Run Types module tests
local typesTest = require("./tests/unit/Types.spec")
local passed, failed = typesTest()
totalPassed += passed
totalFailed += failed

-- Run InputHandler module tests
local inputHandlerTest = require("./tests/unit/InputHandler.spec")
passed, failed = inputHandlerTest()
totalPassed += passed
totalFailed += failed

-- Run PlayerController camera tests
print("\n--- PlayerController Camera Tests ---")
local playerControllerTest = require("./tests/unit/PlayerController.spec")
passed, failed = playerControllerTest()
totalPassed += passed
totalFailed += failed

-- Run PlayerController movement tests (US-004)
print("\n--- PlayerController Movement Tests (US-004) ---")
local playerControllerMovementTest = require("./tests/unit/PlayerController_Movement.spec")
passed, failed = playerControllerMovementTest()
totalPassed += passed
totalFailed += failed

-- Run PlayerController sprint tests (US-005)
print("\n--- PlayerController Sprint Tests (US-005) ---")
local playerControllerSprintTest = require("./tests/unit/PlayerController_Sprint.spec")
passed, failed = playerControllerSprintTest()
totalPassed += passed
totalFailed += failed

-- Run InteractionDetector tests (US-006)
print("\n--- InteractionDetector Tests (US-006) ---")
local interactionDetectorTest = require("./tests/unit/InteractionDetector.spec")
passed, failed = interactionDetectorTest()
totalPassed += passed
totalFailed += failed

-- Run ObjectHighlighter tests (US-007)
print("\n--- ObjectHighlighter Tests (US-007) ---")
local objectHighlighterTest = require("./tests/unit/ObjectHighlighter.spec")
passed, failed = objectHighlighterTest()
totalPassed += passed
totalFailed += failed

-- Run InteractionController tests (US-008)
print("\n--- InteractionController Tests (US-008) ---")
local interactionControllerTest = require("./tests/unit/InteractionController.spec")
passed, failed = interactionControllerTest()
totalPassed += passed
totalFailed += failed

-- Run FootstepSoundSystem tests (US-009)
print("\n--- FootstepSoundSystem Tests (US-009) ---")
local footstepSoundTest = require("./tests/unit/FootstepSoundSystem.spec")
passed, failed = footstepSoundTest()
totalPassed += passed
totalFailed += failed

-- Run SanityManager tests (US-010)
print("\n--- SanityManager Tests (US-010) ---")
local sanityManagerTest = require("./tests/unit/SanityManager.spec")
passed, failed = sanityManagerTest()
totalPassed += passed
totalFailed += failed

-- Run UI Component Tests
print("\n--- Running GameUI Controller Tests ---")
local gameUITest = require("./tests/unit/GameUI.spec")
passed, failed = gameUITest()
totalPassed += passed
totalFailed += failed

print(string.format("\nFinal: %d passed, %d failed", totalPassed, totalFailed))

if totalFailed > 0 then
    error(string.format("Tests failed: %d", totalFailed))
end
