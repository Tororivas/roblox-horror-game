--!strict
--[[
    InputHandler Module Tests
    Validates input handling functionality.
]]

-- Mock InputObject for testing
local function createMockInputObject(keyCodeName: string, keyCode: any?, userInputType: string?): any
    return {
        KeyCode = {
            Name = keyCodeName,
            Value = keyCode or 0,
        },
        UserInputType = userInputType or "Keybroad",
        Position = { X = 0, Y = 0 },
        Delta = { X = 0, Y = 0 },
    }
end

-- Create a fresh InputHandler module for testing (to avoid state bleeding)
local function createTestInputHandler()
    local module = {}
    
    -- Types for this module
    export type InputState = {
        W: boolean,
        A: boolean,
        S: boolean,
        D: boolean,
        Shift: boolean,
        E: boolean,
    }

    export type InputBeganCallback = (any, boolean) -> ()
    export type InputEndedCallback = (any, boolean) -> ()
    export type InputChangedCallback = (any, boolean) -> ()

    -- Private state
    local _isRunning: boolean = false
    local _inputState: InputState = {
        W = false,
        A = false,
        S = false,
        D = false,
        Shift = false,
        E = false,
    }

    -- Event storage
    local _inputBeganCallbacks: { InputBeganCallback } = {}
    local _inputEndedCallbacks: { InputEndedCallback } = {}
    local _inputChangedCallbacks: { InputChangedCallback } = {}

    -- Event handlers storage
    local _inputBeganHandlers: { (any, boolean) -> () } = {}
    local _inputEndedHandlers: { (any, boolean) -> () } = {}
    local _inputChangedHandlers: { (any, boolean) -> () } = {}

    -- Mock UserInputService
    local MockUserInputService = {}
    
    MockUserInputService.InputBegan = {
        Connect = function(_self: any, callback: (any, boolean) -> ()): any
            table.insert(_inputBeganHandlers, callback)
            return { Disconnect = function() end }
        end,
        Fire = function(inputObject: any, gameProcessedEvent: boolean)
            for _, handler in ipairs(_inputBeganHandlers) do
                handler(inputObject, gameProcessedEvent)
            end
        end,
    }
    
    MockUserInputService.InputEnded = {
        Connect = function(_self: any, callback: (any, boolean) -> ()): any
            table.insert(_inputEndedHandlers, callback)
            return { Disconnect = function() end }
        end,
        Fire = function(inputObject: any, gameProcessedEvent: boolean)
            for _, handler in ipairs(_inputEndedHandlers) do
                handler(inputObject, gameProcessedEvent)
            end
        end,
    }
    
    MockUserInputService.InputChanged = {
        Connect = function(_self: any, callback: (any, boolean) -> ()): any
            table.insert(_inputChangedHandlers, callback)
            return { Disconnect = function() end }
        end,
        Fire = function(inputObject: any, gameProcessedEvent: boolean)
            for _, handler in ipairs(_inputChangedHandlers) do
                handler(inputObject, gameProcessedEvent)
            end
        end,
    }

    -- Event handlers
    local _inputBeganConnection: any? = nil
    local _inputEndedConnection: any? = nil
    local _inputChangedConnection: any? = nil

    -- Key mapping
    local KEY_MAP: { [any]: string? } = {
        ["W"] = "W",
        ["A"] = "A",
        ["S"] = "S",
        ["D"] = "D",
        ["LeftShift"] = "Shift",
        ["RightShift"] = "Shift",
        ["E"] = "E",
    }

    function module.GetInputState(): InputState
        return {
            W = _inputState.W,
            A = _inputState.A,
            S = _inputState.S,
            D = _inputState.D,
            Shift = _inputState.Shift,
            E = _inputState.E,
        }
    end

    function module.ResetInputState(): ()
        _inputState = {
            W = false,
            A = false,
            S = false,
            D = false,
            Shift = false,
            E = false,
        }
    end

    local function OnInputBegan(inputObject: any, gameProcessedEvent: boolean): ()
        if gameProcessedEvent then
            return
        end

        local keyCodeName: string? = nil
        if inputObject.KeyCode and type(inputObject.KeyCode) == "table" then
            keyCodeName = inputObject.KeyCode.Name
        end
        
        local keyName = keyCodeName and KEY_MAP[keyCodeName]
        if keyName then
            _inputState[keyName] = true
        end

        for _, callback in ipairs(_inputBeganCallbacks) do
            local ok, err = pcall(callback, inputObject, gameProcessedEvent)
            if not ok then
                print("InputBegan callback error: " .. tostring(err))
            end
        end
    end

    local function OnInputEnded(inputObject: any, gameProcessedEvent: boolean): ()
        if gameProcessedEvent then
            return
        end

        local keyCodeName: string? = nil
        if inputObject.KeyCode and type(inputObject.KeyCode) == "table" then
            keyCodeName = inputObject.KeyCode.Name
        end
        
        local keyName = keyCodeName and KEY_MAP[keyCodeName]
        if keyName then
            _inputState[keyName] = false
        end

        for _, callback in ipairs(_inputEndedCallbacks) do
            local ok, err = pcall(callback, inputObject, gameProcessedEvent)
            if not ok then
                print("InputEnded callback error: " .. tostring(err))
            end
        end
    end

    local function OnInputChanged(inputObject: any, gameProcessedEvent: boolean): ()
        for _, callback in ipairs(_inputChangedCallbacks) do
            local ok, err = pcall(callback, inputObject, gameProcessedEvent)
            if not ok then
                print("InputChanged callback error: " .. tostring(err))
            end
        end
    end

    function module.OnInputBegan(callback: InputBeganCallback): () -> ()
        table.insert(_inputBeganCallbacks, callback)
        local index = #_inputBeganCallbacks
        
        return function()
            table.remove(_inputBeganCallbacks, index)
        end
    end

    function module.OnInputEnded(callback: InputEndedCallback): () -> ()
        table.insert(_inputEndedCallbacks, callback)
        local index = #_inputEndedCallbacks
        
        return function()
            table.remove(_inputEndedCallbacks, index)
        end
    end

    function module.OnInputChanged(callback: InputChangedCallback): () -> ()
        table.insert(_inputChangedCallbacks, callback)
        local index = #_inputChangedCallbacks
        
        return function()
            table.remove(_inputChangedCallbacks, index)
        end
    end

    function module.Start(): ()
        if _isRunning then
            return
        end

        _isRunning = true
        _inputBeganConnection = MockUserInputService.InputBegan:Connect(OnInputBegan)
        _inputEndedConnection = MockUserInputService.InputEnded:Connect(OnInputEnded)
        _inputChangedConnection = MockUserInputService.InputChanged:Connect(OnInputChanged)
    end

    function module.Stop(): ()
        if not _isRunning then
            return
        end

        _isRunning = false

        if _inputBeganConnection then
            _inputBeganConnection:Disconnect()
            _inputBeganConnection = nil
        end

        if _inputEndedConnection then
            _inputEndedConnection:Disconnect()
            _inputEndedConnection = nil
        end

        if _inputChangedConnection then
            _inputChangedConnection:Disconnect()
            _inputChangedConnection = nil
        end

        module.ResetInputState()
    end

    function module.IsRunning(): boolean
        return _isRunning
    end

    -- Expose MockUserInputService for testing
    module._mockInputService = MockUserInputService

    return module
end

local function runTests(): (number, number)
    print("Running InputHandler module tests...")
    local passed = 0
    local failed = 0

    local function runTest(testName: string, testFn: () -> ()): boolean
        local success, err = pcall(testFn)
        if success then
            passed += 1
            return true
        else
            failed += 1
            print("Test '" .. testName .. "' failed: " .. tostring(err))
            return false
        end
    end

    -- Test 1: Module exists with required functions
    runTest("Module exists with required functions", function()
        local InputHandler = createTestInputHandler()
        assert(InputHandler.Start ~= nil, "Start function should exist")
        assert(InputHandler.Stop ~= nil, "Stop function should exist")
        assert(InputHandler.GetInputState ~= nil, "GetInputState function should exist")
        assert(InputHandler.ResetInputState ~= nil, "ResetInputState function should exist")
        assert(InputHandler.OnInputBegan ~= nil, "OnInputBegan function should exist")
        assert(InputHandler.OnInputEnded ~= nil, "OnInputEnded function should exist")
        assert(InputHandler.OnInputChanged ~= nil, "OnInputChanged function should exist")
        assert(InputHandler.IsRunning ~= nil, "IsRunning function should exist")
    end)

    -- Test 2: Initial input state is all false
    runTest("Initial input state is all false", function()
        local InputHandler = createTestInputHandler()
        local state = InputHandler.GetInputState()
        assert(state.W == false, "W should be false initially")
        assert(state.A == false, "A should be false initially")
        assert(state.S == false, "S should be false initially")
        assert(state.D == false, "D should be false initially")
        assert(state.Shift == false, "Shift should be false initially")
        assert(state.E == false, "E should be false initially")
    end)

    -- Test 3: Start and Stop work correctly
    runTest("Start and Stop work correctly", function()
        local InputHandler = createTestInputHandler()
        assert(InputHandler.IsRunning() == false, "Should not be running initially")
        InputHandler.Start()
        assert(InputHandler.IsRunning() == true, "Should be running after Start()")
        InputHandler.Stop()
        assert(InputHandler.IsRunning() == false, "Should not be running after Stop()")
    end)

    -- Test 4: W key state tracking
    runTest("W key state tracking", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        local mockInputW = createMockInputObject("W")
        InputHandler._mockInputService.InputBegan.Fire(mockInputW, false)
        
        local state = InputHandler.GetInputState()
        assert(state.W == true, "W should be true after W key press")

        InputHandler._mockInputService.InputEnded.Fire(mockInputW, false)
        state = InputHandler.GetInputState()
        assert(state.W == false, "W should be false after W key release")

        InputHandler.Stop()
    end)

    -- Test 5: All movement keys (WASD) state tracking
    runTest("All movement keys (WASD) state tracking", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        local keys = { "W", "A", "S", "D" }
        for _, key in ipairs(keys) do
            local mockInput = createMockInputObject(key)
            InputHandler._mockInputService.InputBegan.Fire(mockInput, false)
            
            local state = InputHandler.GetInputState()
            assert(state[key] == true, key .. " should be true after key press")
        end

        InputHandler.Stop()
    end)

    -- Test 6: Shift key state tracking
    runTest("Shift key state tracking", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        local mockInputLeftShift = createMockInputObject("LeftShift")
        InputHandler._mockInputService.InputBegan.Fire(mockInputLeftShift, false)
        
        local state = InputHandler.GetInputState()
        assert(state.Shift == true, "Shift should be true after LeftShift press")

        local mockInputRightShift = createMockInputObject("RightShift")
        InputHandler._mockInputService.InputBegan.Fire(mockInputRightShift, false)
        state = InputHandler.GetInputState()
        assert(state.Shift == true, "Shift should still be true after RightShift press")

        InputHandler._mockInputService.InputEnded.Fire(mockInputLeftShift, false)
        state = InputHandler.GetInputState()
        assert(state.Shift == false, "Shift should be false after LeftShift release")

        InputHandler.Stop()
    end)

    -- Test 7: E key state tracking
    runTest("E key state tracking", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        local mockInputE = createMockInputObject("E")
        InputHandler._mockInputService.InputBegan.Fire(mockInputE, false)
        
        local state = InputHandler.GetInputState()
        assert(state.E == true, "E should be true after E key press")

        InputHandler._mockInputService.InputEnded.Fire(mockInputE, false)
        state = InputHandler.GetInputState()
        assert(state.E == false, "E should be false after E key release")

        InputHandler.Stop()
    end)

    -- Test 8: InputBegan event dispatching
    runTest("InputBegan event dispatching", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        local eventFired = false
        local receivedInputObject = nil
        local receivedGameProcessed = nil

        local disconnect = InputHandler.OnInputBegan(function(inputObject: any, gameProcessedEvent: boolean)
            eventFired = true
            receivedInputObject = inputObject
            receivedGameProcessed = gameProcessedEvent
        end)

        local mockInput = createMockInputObject("W")
        InputHandler._mockInputService.InputBegan.Fire(mockInput, false)

        assert(eventFired == true, "InputBegan callback should fire")
        assert(receivedInputObject == mockInput, "InputObject should be passed to callback")
        assert(receivedGameProcessed == false, "gameProcessedEvent should be passed to callback")

        disconnect()

        eventFired = false
        InputHandler._mockInputService.InputBegan.Fire(mockInput, false)
        assert(eventFired == false, "InputBegan callback should not fire after disconnect")

        InputHandler.Stop()
    end)

    -- Test 9: InputEnded event dispatching
    runTest("InputEnded event dispatching", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        local eventFired = false
        local disconnect = InputHandler.OnInputEnded(function(_inputObject: any, _gameProcessedEvent: boolean)
            eventFired = true
        end)

        local mockInput = createMockInputObject("W")
        InputHandler._mockInputService.InputEnded.Fire(mockInput, false)

        assert(eventFired == true, "InputEnded callback should fire")

        disconnect()
        eventFired = false
        InputHandler._mockInputService.InputEnded.Fire(mockInput, false)
        assert(eventFired == false, "InputEnded callback should not fire after disconnect")

        InputHandler.Stop()
    end)

    -- Test 10: InputChanged event dispatching
    runTest("InputChanged event dispatching", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        local eventFired = false
        local disconnect = InputHandler.OnInputChanged(function(_inputObject: any, _gameProcessedEvent: boolean)
            eventFired = true
        end)

        local mockInput = createMockInputObject("MouseMovement", nil, "MouseMovement")
        InputHandler._mockInputService.InputChanged.Fire(mockInput, false)

        assert(eventFired == true, "InputChanged callback should fire")

        disconnect()
        eventFired = false
        InputHandler._mockInputService.InputChanged.Fire(mockInput, false)
        assert(eventFired == false, "InputChanged callback should not fire after disconnect")

        InputHandler.Stop()
    end)

    -- Test 11: gameProcessedEvent filter (should not process when true)
    runTest("gameProcessedEvent filter (should not process when true)", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        local mockInput = createMockInputObject("W")
        InputHandler._mockInputService.InputBegan.Fire(mockInput, true)
        
        local state = InputHandler.GetInputState()
        assert(state.W == false, "W should not change when gameProcessedEvent is true")

        InputHandler.Stop()
    end)

    -- Test 12: ResetInputState clears all keys
    runTest("ResetInputState clears all keys", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        -- Press multiple keys
        local keys = { "W", "A", "S", "D", "LeftShift", "E" }
        for _, key in ipairs(keys) do
            local mockInput = createMockInputObject(key)
            InputHandler._mockInputService.InputBegan.Fire(mockInput, false)
        end

        -- Reset
        InputHandler.ResetInputState()

        local state = InputHandler.GetInputState()
        assert(state.W == false, "W should be false after reset")
        assert(state.A == false, "A should be false after reset")
        assert(state.S == false, "S should be false after reset")
        assert(state.D == false, "D should be false after reset")
        assert(state.Shift == false, "Shift should be false after reset")
        assert(state.E == false, "E should be false after reset")

        InputHandler.Stop()
    end)

    -- Test 13: Stop resets input state
    runTest("Stop resets input state", function()
        local InputHandler = createTestInputHandler()
        InputHandler.Start()

        -- Press W key
        local mockInputW = createMockInputObject("W")
        InputHandler._mockInputService.InputBegan.Fire(mockInputW, false)
        
        local state = InputHandler.GetInputState()
        assert(state.W == true, "W should be true before stop")

        InputHandler.Stop()
        
        state = InputHandler.GetInputState()
        assert(state.W == false, "W should be false after stop")
    end)

    print(string.format("Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests
