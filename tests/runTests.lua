--!strict
--[[
    Test Runner
    Runs all unit and integration tests.
]]

local Tests = {}

function Tests.runAll(): (number, number)
    local totalPassed = 0
    local totalFailed = 0
    
    print("=" .. string.rep("=", 40))
    print("  RUNNING ALL TESTS")
    print("=" .. string.rep("=", 40))
    print()
    
    -- Run Types module tests
    print("-- Running Types Tests --")
    local typesTest = require("./unit/Types.spec")
    local passed, failed = typesTest()
    totalPassed += passed
    totalFailed += failed
    
    print()
    
    -- Run PowerConfig module tests
    print("-- Running PowerConfig Tests --")
    local powerConfigTest = require("./unit/PowerConfig.spec")
    passed, failed = powerConfigTest()
    totalPassed += passed
    totalFailed += failed
    
    print()
    
    -- Run RemoteEvents tests
    print("-- Running RemoteEvents Tests --")
    local remoteEventsTest = require("./unit/RemoteEvents.spec")
    passed, failed = remoteEventsTest()
    totalPassed += passed
    totalFailed += failed
    
    print()
    print("=" .. string.rep("=", 40))
    print(string.format("  FINAL RESULTS: %d passed, %d failed", totalPassed, totalFailed))
    print("=" .. string.rep("=", 40))
    
    return totalPassed, totalFailed
end

-- Run tests if executed directly
local testPassed, testFailed = Tests.runAll()
if testFailed > 0 then
    error("Some tests failed!")
end

return Tests
