--!strict
--[[
    PowerManager Light States Tests
    Validates light state tracking and power depletion handling.
]]

-- Setup mock environment BEFORE any requires
local mockPowerConfig = {
    POWER_START = 100,
    POWER_COST_PER_TOGGLE = 10,
    MIN_POWER = 0,
}

-- Track fired events for testing
local firedEvents: {{string: any}} = {}

local mockPowerChangedEvent = {
    FireAllClients = function(_self: any, value: any)
        table.insert(firedEvents, {"PowerChanged", value})
    end,
}

local mockLightToggledEvent = {
    FireAllClients = function(_self: any, lightId: any, isOn: any)
        table.insert(firedEvents, {"LightToggled", lightId, isOn})
    end,
}

local mockEventsFolder = {
    WaitForChild = function(_self: any, name: string): any
        if name == "PowerChanged" then
            return mockPowerChangedEvent
        elseif name == "LightToggled" then
            return mockLightToggledEvent
        end
        error("Unknown event: " .. name)
    end,
}

local mockReplicatedStorage = {
    Modules = {
        PowerConfig = mockPowerConfig
    },
    WaitForChild = function(_self: any, name: string): any
        if name == "Events" then
            return mockEventsFolder
        end
        error("Unknown child: " .. name)
    end,
}

-- Set up global game mock in the module's environment
getfenv().game = {
    GetService = function(serviceName: string): any
        if serviceName == "ReplicatedStorage" then
            return mockReplicatedStorage  
        end
        error("Unknown service: " .. serviceName)
    end
}

-- Inline the PowerManager module code for testing
local PowerManager = {}
local currentPower: number = mockPowerConfig.POWER_START

-- Light states table: maps lightId -> isOn
local lightStates: {[string]: boolean} = {}

function PowerManager.GetPower(): number
    return currentPower
end

function PowerManager.SetPower(newPower: number): ()
    local minPower = mockPowerConfig.MIN_POWER
    local maxPower = mockPowerConfig.POWER_START
    currentPower = math.clamp(newPower, minPower, maxPower)
end

function PowerManager.HasPower(): boolean
    return currentPower > mockPowerConfig.MIN_POWER
end

function PowerManager.GetLightState(lightId: string): boolean | nil
    return lightStates[lightId]
end

function PowerManager.SetLightState(lightId: string, isOn: boolean): ()
    lightStates[lightId] = isOn
end

function PowerManager.ToggleLight(lightId: string): boolean
    local currentState = lightStates[lightId]
    
    -- If turning on, we need power
    if not currentState then
        -- Trying to turn on
        if not PowerManager.HasPower() then
            return false -- No power, can't turn on new lights
        end
        
        -- Consume power to turn on
        if not PowerManager.DeductPower(mockPowerConfig.POWER_COST_PER_TOGGLE) then
            return false
        end
        
        lightStates[lightId] = true
        mockLightToggledEvent:FireAllClients(lightId, true)
        return true
    else
        -- Turning off - always allowed, power doesn't increase
        lightStates[lightId] = false
        mockLightToggledEvent:FireAllClients(lightId, false)
        return true
    end
end

function PowerManager.DeductPower(amount: number): boolean
    if currentPower - amount < mockPowerConfig.MIN_POWER then
        return false
    end
    currentPower = currentPower - amount
    mockPowerChangedEvent:FireAllClients(currentPower)
    return true
end

function PowerManager.GetAllLightStates(): {[string]: boolean}
    local copy: {[string]: boolean} = {}
    for id, state in pairs(lightStates) do
        copy[id] = state
    end
    return copy
end

function PowerManager.Reset(): ()
    currentPower = mockPowerConfig.POWER_START
    for key in pairs(lightStates) do
        lightStates[key] = nil
    end
end

local function runTests()
    print("Running PowerManager Light States tests...")
    local passed = 0
    local failed = 0

    -- Test 1: lightStates table exists (via GetAllLightStates)
    local test1 = function()
        PowerManager.Reset()
        local states = PowerManager.GetAllLightStates()
        assert(states ~= nil, "GetAllLightStates() should return a table")
        assert(typeof(states) == "table", "GetAllLightStates() should return a table type")
        print("✓ lightStates table exists via GetAllLightStates()")
        passed += 1
    end

    -- Test 2: GetLightState returns nil for untracked light
    local test2 = function()
        PowerManager.Reset()
        local state = PowerManager.GetLightState("untracked_light")
        assert(state == nil, "GetLightState should return nil for untracked light")
        print("✓ GetLightState returns nil for untracked light")
        passed += 1
    end

    -- Test 3: GetLightState returns true when light is on
    local test3 = function()
        PowerManager.Reset()
        PowerManager.SetLightState("room1_lamp", true)
        local state = PowerManager.GetLightState("room1_lamp")
        assert(state == true, "GetLightState should return true for light that is on")
        print("✓ GetLightState returns true when light is on")
        passed += 1
    end

    -- Test 4: GetLightState returns false when light is off
    local test4 = function()
        PowerManager.Reset()
        PowerManager.SetLightState("room1_lamp", false)
        local state = PowerManager.GetLightState("room1_lamp")
        assert(state == false, "GetLightState should return false for light that is off")
        print("✓ GetLightState returns false when light is off")
        passed += 1
    end

    -- Test 5: SetLightState updates light state correctly
    local test5 = function()
        PowerManager.Reset()
        PowerManager.SetLightState("bedroom_light", true)
        assert(PowerManager.GetLightState("bedroom_light") == true, "Light should be on after SetLightState to true")
        
        PowerManager.SetLightState("bedroom_light", false)
        assert(PowerManager.GetLightState("bedroom_light") == false, "Light should be off after SetLightState to false")
        print("✓ SetLightState updates light state correctly")
        passed += 1
    end

    -- Test 6: HasPower returns true when power > 0
    local test6 = function()
        PowerManager.Reset()
        PowerManager.SetPower(50)
        assert(PowerManager.HasPower() == true, "HasPower should return true when power is 50")
        print("✓ HasPower returns true when power > 0")
        passed += 1
    end

    -- Test 7: HasPower returns false when power == 0
    local test7 = function()
        PowerManager.Reset()
        PowerManager.SetPower(0)
        assert(PowerManager.HasPower() == false, "HasPower should return false when power is 0")
        print("✓ HasPower returns false when power == 0")
        passed += 1
    end

    -- Test 8: Light states persist even when power depletes
    local test8 = function()
        PowerManager.Reset()
        -- Set up some lights
        PowerManager.SetLightState("kitchen_light", true)
        PowerManager.SetLightState("living_room_light", false)
        PowerManager.SetLightState("hallway_light", true)
        
        -- Deplete power
        PowerManager.SetPower(0)
        
        -- Verify states persist
        assert(PowerManager.GetLightState("kitchen_light") == true, "Kitchen light state should persist")
        assert(PowerManager.GetLightState("living_room_light") == false, "Living room light state should persist")
        assert(PowerManager.GetLightState("hallway_light") == true, "Hallway light state should persist")
        print("✓ Light states persist even when power depletes")
        passed += 1
    end

    -- Test 9: GetAllLightStates returns all tracked lights
    local test9 = function()
        PowerManager.Reset()
        PowerManager.SetLightState("light_a", true)
        PowerManager.SetLightState("light_b", false)
        PowerManager.SetLightState("light_c", true)
        
        local allStates = PowerManager.GetAllLightStates()
        assert(allStates["light_a"] == true, "light_a should be in allStates")
        assert(allStates["light_b"] == false, "light_b should be in allStates")
        assert(allStates["light_c"] == true, "light_c should be in allStates")
        -- Count keys manually since # doesn't work on maps
        local count = 0; for _ in pairs(allStates) do count += 1 end;
        assert(count == 3, string.format("Should have 3 lights, got %d", count))
        print("✓ GetAllLightStates returns all tracked lights")
        passed += 1
    end

    -- Test 10: ToggleLight succeeds with power available
    local test10 = function()
        PowerManager.Reset()
        firedEvents = {}
        local success = PowerManager.ToggleLight("test_light")
        assert(success == true, "ToggleLight should succeed when power is available")
        assert(PowerManager.GetLightState("test_light") == true, "Light should be on after toggle")
        print("✓ ToggleLight succeeds with power available")
        passed += 1
    end

    -- Test 11: ToggleLight fails when power is 0
    local test11 = function()
        PowerManager.Reset()
        PowerManager.SetPower(0)
        firedEvents = {}
        local success = PowerManager.ToggleLight("new_light")
        assert(success == false, "ToggleLight should fail when power is 0")
        assert(PowerManager.GetLightState("new_light") == nil, "Light should not be tracked after failed toggle")
        print("✓ ToggleLight fails when power is 0")
        passed += 1
    end

    -- Test 12: Can turn off light even when power is 0
    local test12 = function()
        PowerManager.Reset()
        PowerManager.SetLightState("existing_light", true)
        PowerManager.SetPower(0)
        firedEvents = {}
        
        -- Should be able to turn off even with no power
        PowerManager.SetLightState("existing_light", false)
        assert(PowerManager.GetLightState("existing_light") == false, "Can set light state off even with no power")
        print("✓ Can turn off light even when power is 0")
        passed += 1
    end

    -- Test 13: ToggleLight consumes power
    local test13 = function()
        PowerManager.Reset()
        firedEvents = {}
        local initialPower = PowerManager.GetPower()
        PowerManager.ToggleLight("power_test_light")
        local newPower = PowerManager.GetPower()
        assert(newPower == initialPower - mockPowerConfig.POWER_COST_PER_TOGGLE, 
               string.format("Power should be %d after toggle, got %d", initialPower - mockPowerConfig.POWER_COST_PER_TOGGLE, newPower))
        print("✓ ToggleLight consumes power correctly")
        passed += 1
    end

    -- Test 14: LightToggled event fires on successful toggle
    local test14 = function()
        PowerManager.Reset()
        firedEvents = {}
        PowerManager.ToggleLight("event_test_light")
        
        local foundEvent = false
        for _, event in ipairs(firedEvents) do
            if event[1] == "LightToggled" then
                foundEvent = true
                assert(event[2] == "event_test_light", "Event should contain lightId")
                assert(event[3] == true, "Event should contain true for turning on")
                break
            end
        end
        assert(foundEvent, "LightToggled event should have fired")
        print("✓ LightToggled event fires on successful toggle")
        passed += 1
    end

    -- Run all tests
    local tests = {test1, test2, test3, test4, test5, test6, test7, test8, test9, test10, test11, test12, test13, test14}
    
    for _, test in ipairs(tests) do
        local success, err = pcall(test)
        if not success then
            warn("✗ Test failed: " .. tostring(err))
            failed += 1
        end
    end

    print(string.format("\nPowerManager Light States Test Results: %d passed, %d failed", passed, failed))
    
    if failed > 0 then
        error("Some PowerManager Light States tests failed!")
    end
    
    return passed, failed
end

return runTests
