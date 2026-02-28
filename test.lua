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

print(string.format("\nFinal: %d passed, %d failed", totalPassed, totalFailed))

if totalFailed > 0 then
    error(string.format("Tests failed: %d", totalFailed))
end
