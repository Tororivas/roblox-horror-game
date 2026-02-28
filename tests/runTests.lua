--!strict
--[[
    Test Runner
    Runs all unit and integration tests.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    local typesTest = require(script.Parent.unit.Types.spec)
    local passed, failed = typesTest()
    totalPassed += passed
    totalFailed += failed
    
    print()
    
    -- Run PowerConfig module tests
    print("-- Running PowerConfig Tests --")
    local powerConfigTest = require(script.Parent.unit.PowerConfig.spec)
    passed, failed = powerConfigTest()
    totalPassed += passed
    totalFailed += failed
    
    print()
    print("=" .. string.rep("=", 40))
    print(string.format("  FINAL RESULTS: %d passed, %d failed", totalPassed, totalFailed))
    print("=" .. string.rep("=", 40))
    
    return totalPassed, totalFailed
end

return Tests
