--!strict
--[[
    InputHandler Module
    Centralized input handling for the Roblox Horror Game.
    Captures and dispatches keyboard and mouse input events.
]]

-- Types for this module
export type InputState = {
    W: boolean,
    A: boolean,
    S: boolean,
    D: boolean,
    Shift: boolean,
    E: boolean,
}

export type InputEventData = {
    inputObject: any, -- InputObject in Roblox
    gameProcessedEvent: boolean,
}

-- Callback types
export type InputBeganCallback = (any, boolean) -> () -- InputObject, gameProcessedEvent
export type InputEndedCallback = (any, boolean) -> () -- InputObject, gameProcessedEvent
export type InputChangedCallback = (any, boolean) -> () -- InputObject, gameProcessedEvent

-- Module table
local InputHandler = {}

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

-- Event storage - using tables as signal lists
local _inputBeganCallbacks: { InputBeganCallback } = {}
local _inputEndedCallbacks: { InputEndedCallback } = {}
local _inputChangedCallbacks: { InputChangedCallback } = {}

-- Mock ContextActionService for non-Roblox environments
local MockContextActionService = {
    BindAction = function(_actionName: string, _callback: any, _createTouchButton: boolean, ...)
        -- Mock implementation
    end,
    UnbindAction = function(_actionName: string)
        -- Mock implementation
    end,
}

-- Mock UserInputService for non-Roblox environments  
local MockUserInputService = {
    InputBegan = {
        Connect = function(_callback: any): any
            return { Disconnect = function() end }
        end,
    },
    InputEnded = {
        Connect = function(_callback: any): any
            return { Disconnect = function() end }
        end,
    },
    InputChanged = {
        Connect = function(_callback: any): any
            return { Disconnect = function() end }
        end,
    },
}

-- Initialize services with mocks
local ContextActionService: any = MockContextActionService
local UserInputService: any = MockUserInputService

-- Try to get real services if running in Roblox
local success: boolean, result: any = pcall(function()
    return (game :: any):GetService("ContextActionService")
end)
if success then
    ContextActionService = result
end

success, result = pcall(function()
    return (game :: any):GetService("UserInputService")
end)
if success then
    UserInputService = result
end

-- Event handlers
local _inputBeganConnection: any? = nil
local _inputEndedConnection: any? = nil
local _inputChangedConnection: any? = nil

-- Key mapping
local KEY_MAP: { [string]: string? } = {
    ["W"] = "W",
    ["A"] = "A",
    ["S"] = "S",
    ["D"] = "D",
    ["LeftShift"] = "Shift",
    ["RightShift"] = "Shift",
    ["E"] = "E",
}

--[[
    Get the current input state table
    Returns a copy of the current state
]]
function InputHandler.GetInputState(): InputState
    return {
        W = _inputState.W,
        A = _inputState.A,
        S = _inputState.S,
        D = _inputState.D,
        Shift = _inputState.Shift,
        E = _inputState.E,
    }
end

--[[
    Reset the input state (Useful for debugging/testing)
]]
function InputHandler.ResetInputState(): ()
    _inputState = {
        W = false,
        A = false,
        S = false,
        D = false,
        Shift = false,
        E = false,
    }
end

--[[
    Handle input began event
]]
local function OnInputBegan(inputObject: any, gameProcessedEvent: boolean): ()
    if gameProcessedEvent then
        return
    end

    local keyCodeName: string? = nil
    local keyCodeType = typeof(inputObject.KeyCode)
    if keyCodeType == "EnumItem" or keyCodeType == "table" then
        local kc = inputObject.KeyCode :: { Name: string }
        keyCodeName = kc.Name
    end
    
    local keyName = keyCodeName and KEY_MAP[keyCodeName]
    if keyName then
        _inputState[keyName] = true
    end

    -- Dispatch to all registered callbacks
    for _, callback in ipairs(_inputBeganCallbacks) do
        local ok, err = pcall(callback, inputObject, gameProcessedEvent)
        if not ok then
            print("InputBegan callback error: " .. tostring(err))
        end
    end
end

--[[
    Handle input ended event
]]
local function OnInputEnded(inputObject: any, gameProcessedEvent: boolean): ()
    if gameProcessedEvent then
        return
    end

    local keyCodeName: string? = nil
    local keyCodeType = typeof(inputObject.KeyCode)
    if keyCodeType == "EnumItem" or keyCodeType == "table" then
        local kc = inputObject.KeyCode :: { Name: string }
        keyCodeName = kc.Name
    end
    
    local keyName = keyCodeName and KEY_MAP[keyCodeName]
    if keyName then
        _inputState[keyName] = false
    end

    -- Dispatch to all registered callbacks
    for _, callback in ipairs(_inputEndedCallbacks) do
        local ok, err = pcall(callback, inputObject, gameProcessedEvent)
        if not ok then
            print("InputEnded callback error: " .. tostring(err))
        end
    end
end

--[[
    Handle input changed event
]]
local function OnInputChanged(inputObject: any, gameProcessedEvent: boolean): ()
    -- Dispatch to all registered callbacks
    for _, callback in ipairs(_inputChangedCallbacks) do
        local ok, err = pcall(callback, inputObject, gameProcessedEvent)
        if not ok then
            print("InputChanged callback error: " .. tostring(err))
        end
    end
end

--[[
    Register a callback for InputBegan events
    Returns a disconnect function
]]
function InputHandler.OnInputBegan(callback: InputBeganCallback): () -> ()
    table.insert(_inputBeganCallbacks, callback)
    local index = #_inputBeganCallbacks
    
    return function()
        table.remove(_inputBeganCallbacks, index)
    end
end

--[[
    Register a callback for InputEnded events
    Returns a disconnect function
]]
function InputHandler.OnInputEnded(callback: InputEndedCallback): () -> ()
    table.insert(_inputEndedCallbacks, callback)
    local index = #_inputEndedCallbacks
    
    return function()
        table.remove(_inputEndedCallbacks, index)
    end
end

--[[
    Register a callback for InputChanged events
    Returns a disconnect function
]]
function InputHandler.OnInputChanged(callback: InputChangedCallback): () -> ()
    table.insert(_inputChangedCallbacks, callback)
    local index = #_inputChangedCallbacks
    
    return function()
        table.remove(_inputChangedCallbacks, index)
    end
end

--[[
    Start the input handler
    Connects to UserInputService events
]]
function InputHandler.Start(): ()
    if _isRunning then
        print("InputHandler is already running")
        return
    end

    _isRunning = true
    _inputBeganConnection = (UserInputService.InputBegan).Connect(OnInputBegan)
    _inputEndedConnection = (UserInputService.InputEnded).Connect(OnInputEnded)
    _inputChangedConnection = (UserInputService.InputChanged).Connect(OnInputChanged)
end

--[[
    Stop the input handler
    Disconnects from UserInputService events
]]
function InputHandler.Stop(): ()
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

    -- Reset input state
    InputHandler.ResetInputState()
end

--[[
    Check if the handler is running
]]
function InputHandler.IsRunning(): boolean
    return _isRunning
end

-- Return the module
return InputHandler
