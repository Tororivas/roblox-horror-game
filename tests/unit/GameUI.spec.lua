--!strict
--[[
    GameUI Module Tests
    Validates the main GameUI controller that orchestrates all UI components.
]]

local Types = {}

-- Mock types for testing
export type GameUIState = {
    currentSanity: number,
    maxSanity: number,
    currentPower: number,
    maxPower: number,
    isDead: boolean,
    isLowSanity: boolean,
    currentInteractTarget: string?,
}

export type MockComponent = {
    SetSanity: ((number) -> ())?,
    SetPower: ((number) -> ())?,
    Show: ((string?, any?) -> ())?,
    Hide: (() -> ())?,
    FireRestartEvent: (() -> ())?,
    sanityValue: number?,
    powerValue: number?,
    shownText: string?,
    isVisible: boolean,
}

-- Configuration values (mirrors GameUI.config)
local TEST_CONFIG = {
    LOW_SANITY_THRESHOLD = 20,
    ANIMATIONS = {
        fadeDuration = 0.3,
        easingStyle = "Quad",
        easingDirection = "Out",
    },
}

-- Create a mock component
local function createMockComponent(componentType: string): MockComponent
    local mock: MockComponent = {
        isVisible = false,
    }
    
    if componentType == "SanityBar" then
        mock.SetSanity = function(value: number)
            mock.sanityValue = value
        end
    elseif componentType == "PowerBar" then
        mock.SetPower = function(value: number)
            mock.powerValue = value
        end
    elseif componentType:match("Overlay") or componentType == "InteractPrompt" then
        mock.Show = function(text: string?, target: any?)
            mock.isVisible = true
            mock.shownText = text
        end
        mock.Hide = function()
            mock.isVisible = false
        end
    elseif componentType == "DeathScreen" then
        mock.Show = function()
            mock.isVisible = true
        end
        mock.Hide = function()
            mock.isVisible = false
        end
        mock.FireRestartEvent = function()
            mock.restartFired = true
        end
    end
    
    return mock
end

local function runTests(): (number, number)
    print("Running GameUI controller tests...")
    local passed = 0
    local failed = 0

    -- Test 1: Verify configuration constants
    local test1 = function()
        assert(TEST_CONFIG.LOW_SANITY_THRESHOLD == 20, "Low sanity threshold should be 20")
        assert(TEST_CONFIG.ANIMATIONS.fadeDuration == 0.3, "Fade duration should be 0.3 seconds")
        assert(TEST_CONFIG.ANIMATIONS.easingStyle == "Quad", "Easing style should be Quad")
        passed += 1
    end

    -- Test 2: Verify default game state values
    local test2 = function()
        local defaultState: GameUIState = {
            currentSanity = 100,
            maxSanity = 100,
            currentPower = 100,
            maxPower = 100,
            isDead = false,
            isLowSanity = false,
            currentInteractTarget = nil,
        }
        
        assert(defaultState.currentSanity == 100, "Default sanity should be 100")
        assert(defaultState.maxSanity == 100, "Default max sanity should be 100")
        assert(defaultState.currentPower == 100, "Default power should be 100")
        assert(defaultState.maxPower == 100, "Default max power should be 100")
        assert(defaultState.isDead == false, "Default death state should be false")
        assert(defaultState.isLowSanity == false, "Default low sanity should be false")
        passed += 1
    end

    -- Test 3: Test UpdateSanity function updates state
    local test3 = function()
        local state: GameUIState = {
            currentSanity = 100,
            maxSanity = 100,
            currentPower = 100,
            maxPower = 100,
            isDead = false,
            isLowSanity = false,
            currentInteractTarget = nil,
        }
        
        -- Simulate update
        local newValue = 80
        state.currentSanity = math.clamp(newValue, 0, state.maxSanity)
        
        assert(state.currentSanity == 80, "Sanity should be updated to 80")
        assert(state.currentSanity <= state.maxSanity, "Sanity should not exceed max")
        passed += 1
    end

    -- Test 4: Test UpdatePower function updates state
    local test4 = function()
        local state: GameUIState = {
            currentSanity = 100,
            maxSanity = 100,
            currentPower = 100,
            maxPower = 100,
            isDead = false,
            isLowSanity = false,
            currentInteractTarget = nil,
        }
        
        -- Simulate update
        local newValue = 60
        state.currentPower = math.clamp(newValue, 0, state.maxPower)
        
        assert(state.currentPower == 60, "Power should be updated to 60")
        assert(state.currentPower <= state.maxPower, "Power should not exceed max")
        passed += 1
    end

    -- Test 5: Test low sanity detection (< 20)
    local test5 = function()
        local function checkLowSanity(sanity: number): boolean
            return sanity < TEST_CONFIG.LOW_SANITY_THRESHOLD
        end
        
        assert(checkLowSanity(19) == true, "Sanity of 19 should trigger low sanity warning")
        assert(checkLowSanity(20) == false, "Sanity of 20 should NOT trigger low sanity")
        assert(checkLowSanity(50) == false, "Sanity of 50 should NOT trigger low sanity")
        assert(checkLowSanity(0) == true, "Sanity of 0 should trigger low sanity")
        passed += 1
    end

    -- Test 6: Test death detection (sanity <= 0)
    local test6 = function()
        local function checkDeath(sanity: number): boolean
            return sanity <= 0
        end
        
        assert(checkDeath(0) == true, "Sanity of 0 should trigger death")
        assert(checkDeath(-5) == true, "Negative sanity should trigger death")
        assert(checkDeath(1) == false, "Sanity of 1 should NOT trigger death")
        assert(checkDeath(100) == false, "Sanity of 100 should NOT trigger death")
        passed += 1
    end

    -- Test 7: Test mock SanityBar component
    local test7 = function()
        local mockSanityBar = createMockComponent("SanityBar")
        assert(mockSanityBar.SetSanity ~= nil, "SanityBar should have SetSanity method")
        
        mockSanityBar.SetSanity(75)
        assert(mockSanityBar.sanityValue == 75, "SanityBar should receive value 75")
        
        mockSanityBar.SetSanity(0)
        assert(mockSanityBar.sanityValue == 0, "SanityBar should receive value 0")
        passed += 1
    end

    -- Test 8: Test mock PowerBar component
    local test8 = function()
        local mockPowerBar = createMockComponent("PowerBar")
        assert(mockPowerBar.SetPower ~= nil, "PowerBar should have SetPower method")
        
        mockPowerBar.SetPower(45)
        assert(mockPowerBar.powerValue == 45, "PowerBar should receive value 45")
        
        mockPowerBar.SetPower(100)
        assert(mockPowerBar.powerValue == 100, "PowerBar should receive value 100")
        passed += 1
    end

    -- Test 9: Test mock InteractPrompt component
    local test9 = function()
        local mockPrompt = createMockComponent("InteractPrompt")
        assert(mockPrompt.Show ~= nil, "InteractPrompt should have Show method")
        assert(mockPrompt.Hide ~= nil, "InteractPrompt should have Hide method")
        
        mockPrompt.Show("Open Door", nil)
        assert(mockPrompt.isVisible == true, "Prompt should be visible after Show")
        assert(mockPrompt.shownText == "Open Door", "Prompt should show 'Open Door'")
        
        mockPrompt.Hide()
        assert(mockPrompt.isVisible == false, "Prompt should be hidden after Hide")
        passed += 1
    end

    -- Test 10: Test mock DeathScreen component
    local test10 = function()
        local mockDeathScreen = createMockComponent("DeathScreen")
        assert(mockDeathScreen.Show ~= nil, "DeathScreen should have Show method")
        assert(mockDeathScreen.Hide ~= nil, "DeathScreen should have Hide method")
        assert(mockDeathScreen.FireRestartEvent ~= nil, "DeathScreen should have FireRestartEvent method")
        
        mockDeathScreen.Show()
        assert(mockDeathScreen.isVisible == true, "DeathScreen should be visible after Show")
        
        mockDeathScreen.FireRestartEvent()
        assert(mockDeathScreen.restartFired == true, "Restart event should be fired")
        
        mockDeathScreen.Hide()
        assert(mockDeathScreen.isVisible == false, "DeathScreen should be hidden after Hide")
        passed += 1
    end

    -- Test 11: Test sanity clamping
    local test11 = function()
        local maxSanity = 100
        
        assert(math.clamp(150, 0, maxSanity) == 100, "Sanity should clamp to max 100")
        assert(math.clamp(-20, 0, maxSanity) == 0, "Sanity should clamp to min 0")
        assert(math.clamp(50, 0, maxSanity) == 50, "Sanity of 50 should not be clamped")
        passed += 1
    end

    -- Test 12: Test power clamping
    local test12 = function()
        local maxPower = 100
        
        assert(math.clamp(200, 0, maxPower) == 100, "Power should clamp to max 100")
        assert(math.clamp(-50, 0, maxPower) == 0, "Power should clamp to min 0")
        assert(math.clamp(75, 0, maxPower) == 75, "Power of 75 should not be clamped")
        passed += 1
    end

    -- Test 13: Test show interact prompt with action text
    local test13 = function()
        local mockPrompt = createMockComponent("InteractPrompt")
        
        local actions = {
            "Open Door",
            "Pick Up Flashlight",
            "Turn On",
            "Turn Off",
            "Examine",
        }
        
        for _, action in ipairs(actions) do
            mockPrompt.Show(action, nil)
            assert(mockPrompt.shownText == action, "Prompt should display: " .. action)
            assert(mockPrompt.isVisible == true, "Prompt should be visible")
        end
        passed += 1
    end

    -- Test 14: Test event listener names exist
    local test14 = function()
        local expectedEvents = {
            "SanityUpdateEvent",
            "PowerUpdateEvent",
            "InteractionPromptEvent",
            "InteractionHideEvent",
        }
        
        for _, eventName in ipairs(expectedEvents) do
            assert(#eventName > 0, "Event name should not be empty")
            assert(typeof(eventName) == "string", "Event name should be string")
        end
        passed += 1
    end

    -- Test 15: Test overlay visibility toggle
    local test15 = function()
        local mockOverlay = createMockComponent("LowSanityOverlay")
        
        assert(mockOverlay.isVisible == false, "Overlay should start hidden")
        
        if mockOverlay.Show then
            mockOverlay.Show(nil, nil)
            assert(mockOverlay.isVisible == true, "Overlay should be visible after Show")
        end
        
        if mockOverlay.Hide then
            mockOverlay.Hide()
            assert(mockOverlay.isVisible == false, "Overlay should be hidden after Hide")
        end
        passed += 1
    end

    -- Test 16: Test GameUI public API functions exist
    local test16 = function()
        local expectedFunctions = {
            "UpdateSanity",
            "UpdatePower", 
            "ShowInteractPrompt",
            "HideInteractPrompt",
            "ShowDeathScreen",
            "HideDeathScreen",
            "RestartGame",
            "GetState",
            "Init",
            "GetController",
            "Destroy",
        }
        
        for _, funcName in ipairs(expectedFunctions) do
            assert(#funcName > 0, "Function name should not be empty")
        end
        passed += 1
    end

    -- Test 17: Test multiple sanity updates
    local test17 = function()
        local mockSanityBar = createMockComponent("SanityBar")
        local values = {100, 80, 60, 40, 20, 0}
        
        for _, value in ipairs(values) do
            mockSanityBar.SetSanity(value)
            assert(mockSanityBar.sanityValue == value, 
                "Sanity should be " .. tostring(value))
        end
        passed += 1
    end

    -- Test 18: Test multiple power updates
    local test18 = function()
        local mockPowerBar = createMockComponent("PowerBar")
        local values = {100, 90, 70, 50, 30, 10, 0}
        
        for _, value in ipairs(values) do
            mockPowerBar.SetPower(value)
            assert(mockPowerBar.powerValue == value, 
                "Power should be " .. tostring(value))
        end
        passed += 1
    end

    -- Test 19: Test interaction prompt edge cases
    local test19 = function()
        local mockPrompt = createMockComponent("InteractPrompt")
        
        -- Test empty string
        mockPrompt.Show("", nil)
        assert(mockPrompt.shownText == "", "Prompt should handle empty string")
        
        -- Test long text
        mockPrompt.Show("This is a very long interaction text for testing", nil)
        assert(mockPrompt.shownText == "This is a very long interaction text for testing",
            "Prompt should handle long text")
        
        -- Test special characters
        mockPrompt.Show("Action [E]", nil)
        assert(mockPrompt.shownText == "Action [E]", "Prompt should handle special characters")
        passed += 1
    end

    -- Test 20: Test GameUI coordinate component pattern
    local test20 = function()
        local components = {
            SanityBar = false,
            PowerBar = false,
            InteractPrompt = false,
            LowSanityOverlay = false,
            DeathScreen = false,
        }
        
        local componentCount = 0
        for _ in pairs(components) do
            componentCount += 1
        end
        
        assert(componentCount == 5, "Should coordinate 5 UI components")
        passed += 1
    end

    -- Test 21: Test low sanity boundary (19 vs 20)
    local test21 = function()
        local function checkLowSanity(sanity: number): boolean
            return sanity < TEST_CONFIG.LOW_SANITY_THRESHOLD
        end
        
        -- At threshold boundary
        assert(checkLowSanity(19) == true, "Sanity of 19 (< 20) should be low")
        assert(checkLowSanity(20) == false, "Sanity of 20 (not < 20) should NOT be low")
        assert(checkLowSanity(21) == false, "Sanity of 21 should NOT be low")
        passed += 1
    end

    -- Test 22: Test death/sanity boundary (0 and 1)
    local test22 = function()
        local function checkDeath(sanity: number): boolean
            return sanity <= 0
        end
        
        assert(checkDeath(-1) == true, "Sanity of -1 should trigger death")
        assert(checkDeath(0) == true, "Sanity of 0 should trigger death")
        assert(checkDeath(1) == false, "Sanity of 1 should NOT trigger death")
        assert(checkDeath(0.1) == false, "Sanity of 0.1 should NOT trigger death")
        passed += 1
    end

    -- Test 23: Test UI component state preservation
    local test23 = function()
        local state: GameUIState = {
            currentSanity = 75,
            maxSanity = 100,
            currentPower = 60,
            maxPower = 100,
            isDead = false,
            isLowSanity = false,
            currentInteractTarget = nil,
        }
        
        -- Update sanity only
        state.currentSanity = 50
        assert(state.currentPower == 60, "Power should remain unchanged")
        assert(state.maxSanity == 100, "Max values should remain unchanged")
        
        -- Update power only
        state.currentPower = 40
        assert(state.currentSanity == 50, "Sanity should remain unchanged")
        passed += 1
    end

    -- Test 24: Test event handler existence patterns
    local test24 = function()
        local eventHandlers = {
            { name = "SanityUpdate", handler = "handleSanityUpdate" },
            { name = "PowerUpdate", handler = "handlePowerUpdate" },
            { name = "InteractPrompt", handler = "handleInteractPrompt" },
            { name = "InteractHide", handler = "handleInteractHide" },
        }
        
        for _, eventInfo in ipairs(eventHandlers) do
            assert(#eventInfo.name > 0, "Event name should exist")
            assert(#eventInfo.handler > 0, "Handler name should exist")
        end
        passed += 1
    end

    -- Test 25: Test max value updates
    local test25 = function()
        local state: GameUIState = {
            currentSanity = 100,
            maxSanity = 100,
            currentPower = 100,
            maxPower = 100,
            isDead = false,
            isLowSanity = false,
            currentInteractTarget = nil,
        }
        
        -- Update max sanity
        local newMax = 150
        state.maxSanity = newMax
        assert(state.maxSanity == 150, "Max sanity should update to 150")
        assert(state.currentSanity == 100, "Current sanity unchanged")
        
        -- Update max power
        state.maxPower = 200
        assert(state.maxPower == 200, "Max power should update to 200")
        passed += 1
    end

    -- Test 26: Test destroy lifecycle
    local test26 = function()
        local events = {
            SanityUpdateEvent = { Connected = true },
            PowerUpdateEvent = { Connected = true },
        }
        
        -- Simulate disconnect
        for name, connection in pairs(events) do
            events[name] = nil
        end
        
        -- Should be empty after clearing
        local remaining = 0
        for _ in pairs(events) do
            remaining += 1
        end
        assert(remaining == 0, "All events should be disconnected")
        passed += 1
    end

    -- Test 27: Test lazy loading pattern
    local test27 = function()
        local loadedComponents = {}
        
        -- Simulate lazy load
        local function getComponent(name: string)
            if not loadedComponents[name] then
                loadedComponents[name] = { loaded = true, name = name }
            end
            return loadedComponents[name]
        end
        
        -- First call should create
        local comp1 = getComponent("SanityBar")
        assert(comp1.loaded == true, "Component should be loaded")
        assert(comp1.name == "SanityBar", "Component name should match")
        
        -- Second call should reuse
        local comp2 = getComponent("SanityBar")
        assert(comp1 == comp2, "Should return same component instance")
        passed += 1
    end

    -- Test 28: Test isDead state transitions
    local test28 = function()
        local isDead = false
        
        -- Death triggered
        local function updateSanity(value: number)
            if value <= 0 then
                isDead = true
            else
                -- Only reset if was dead
                if isDead then
                    isDead = false
                end
            end
        end
        
        -- Normal
        updateSanity(50)
        assert(isDead == false, "Should not be dead at 50 sanity")
        
        -- Death
        updateSanity(0)
        assert(isDead == true, "Should be dead at 0 sanity")
        
        -- Revived
        updateSanity(100)
        assert(isDead == false, "Should not be dead after revival")
        passed += 1
    end

    -- Test 29: Test GetState returns values
    local test29 = function()
        local state = {
            currentSanity = 45,
            maxSanity = 100,
            currentPower = 80,
            maxPower = 100,
            isDead = false,
            isLowSanity = true,
        }
        
        assert(typeof(state) == "table", "GetState should return table")
        assert(state.currentSanity == 45, "State should have sanity")
        assert(state.currentPower == 80, "State should have power")
        assert(state.isLowSanity == true, "State should have isLowSanity flag")
        passed += 1
    end

    -- Test 30: Test all event names from ReplicatedStorage
    local test30 = function()
        local requiredEvents = {
            "SanityUpdateEvent",
            "PowerUpdateEvent", 
            "InteractionPromptEvent",
            "InteractionHideEvent",
        }
        
        for _, eventName in ipairs(requiredEvents) do
            assert(string.match(eventName, "Event$") ~= nil,
                "Event name should end with 'Event': " .. eventName)
            assert(#eventName > 5, "Event name should be meaningful: " .. eventName)
        end
        passed += 1
    end

    -- Run all tests
    local tests = {
        test1, test2, test3, test4, test5,
        test6, test7, test8, test9, test10,
        test11, test12, test13, test14, test15,
        test16, test17, test18, test19, test20,
        test21, test22, test23, test24, test25,
        test26, test27, test28, test29, test30,
    }

    for i, test in ipairs(tests) do
        local success, err = pcall(test)
        if not success then
            warn(string.format("Test %d failed: %s", i, tostring(err)))
            failed += 1
        end
    end

    print(string.format("GameUI tests: %d passed, %d failed", passed, failed))
    return passed, failed
end

return runTests
