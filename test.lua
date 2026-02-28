--!strict
-- Direct test file for running tests

local typesTest = require("./tests/unit/Types.spec")
local inputHandlerTest = require("./tests/unit/InputHandler.spec")

local totalPassed = 0
local totalFailed = 0

print("========================================")
print("Running Types Tests...")
print("========================================")
local typesPassed, typesFailed = typesTest()
totalPassed += typesPassed
totalFailed += typesFailed

print("")
print("========================================")
print("Running InputHandler Tests...")
print("========================================")
local inputPassed, inputFailed = inputHandlerTest()
totalPassed += inputPassed
totalFailed += inputFailed

print("")
print("========================================")
print("FINAL RESULTS")
print("========================================")
print(string.format("Total: %d passed, %d failed", totalPassed, totalFailed))

if totalFailed > 0 then
    error(string.format("Tests failed: %d", totalFailed))
end
