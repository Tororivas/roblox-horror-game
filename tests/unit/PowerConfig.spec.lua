--!strict
--[[
    PowerConfig Module Tests
    Validates power system configuration constants.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PowerConfig = require(ReplicatedStorage.Modules.PowerConfig)

local function runTests()
    print("Running PowerConfig module tests...")
    local passed = 0
    local failed = 0

    -- Test 1: Verify module loads
    local test1 = function()
        assert(PowerConfig ~= nil, "PowerConfig module should load successfully")
        print("✓ PowerConfig module loads successfully")
        passed += 1
    end

    -- Test 2: Verify POWER_START equals 100
    local test2 = function()
        assert(PowerConfig.POWER_START == 100, "POWER_START should equal 100")
        assert(typeof(PowerConfig.POWER_START) == "number", "POWER_START should be a number")
        print("✓ POWER_START equals 100")
        passed += 1
    end

    -- Test 3: Verify POWER_COST_PER_TOGGLE equals 10
    local test3 = function()
        assert(PowerConfig.POWER_COST_PER_TOGGLE == 10, "POWER_COST_PER_TOGGLE should equal 10")
        assert(typeof(PowerConfig.POWER_COST_PER_TOGGLE) == "number", "POWER_COST_PER_TOGGLE should be a number")
        print("✓ POWER_COST_PER_TOGGLE equals 10")
        passed += 1
    end

    -- Test 4: Verify MIN_POWER equals 0
    local test4 = function()
        assert(PowerConfig.MIN_POWER == 0, "MIN_POWER should equal 0")
        assert(typeof(PowerConfig.MIN_POWER) == "number", "MIN_POWER should be a number")
        print("✓ MIN_POWER equals 0")
        passed += 1
    end

    -- Test 5: Verify module returns a table with all constants accessible
    local test5 = function()
        assert(typeof(PowerConfig) == "table", "PowerConfig should be a table")
        assert(PowerConfig.POWER_START ~= nil, "POWER_START should be accessible")
        assert(PowerConfig.POWER_COST_PER_TOGGLE ~= nil, "POWER_COST_PER_TOGGLE should be accessible")
        assert(PowerConfig.MIN_POWER ~= nil, "MIN_POWER should be accessible")
        print("✓ Module returns table with all constants accessible")
        passed += 1
    end

    -- Test 6: Verify constants are positive or appropriate values
    local test6 = function()
        assert(PowerConfig.POWER_START >= 0, "POWER_START should be non-negative")
        assert(PowerConfig.POWER_COST_PER_TOGGLE > 0, "POWER_COST_PER_TOGGLE should be positive")
        assert(PowerConfig.MIN_POWER >= 0, "MIN_POWER should be non-negative")
        assert(PowerConfig.POWER_START > PowerConfig.MIN_POWER, "POWER_START should be greater than MIN_POWER")
        print("✓ All constant values are valid")
        passed += 1
    end

    -- Run all tests
    local tests = {test1, test2, test3, test4, test5, test6}
    
    for _, test in ipairs(tests) do
        local success, err = pcall(test)
        if not success then
            warn("✗ Test failed: " .. tostring(err))
            failed += 1
        end
    end

    print(string.format("\nPowerConfig Test Results: %d passed, %d failed", passed, failed))
    
    if failed > 0 then
        error("Some PowerConfig tests failed!")
    end
    
    return passed, failed
end

return runTests
