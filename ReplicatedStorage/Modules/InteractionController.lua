--!strict
--[[
    InteractionController Module
    Manages E key interactions with interactable objects.
    Handles input detection, raycast validation, server communication, and feedback.
]]

-- Maximum interaction distance
local MAX_INTERACTION_DISTANCE: number = 5

-- Cooldown between interactions (prevent spam)
local INTERACTION_COOLDOWN: number = 0.3 -- seconds

-- Module table
local InteractionController = {}

-- Private state
local _isInitialized: boolean = false
local _isEnabled: boolean = false
local _lastInteractionTime: number = 0
local _currentTarget: any? = nil

-- Dependencies (loaded in Initialize)
local _InputHandler: any? = nil
local _InteractionDetector: any? = nil
local _ObjectHighlighter: any? = nil

-- Event instances
local _InteractionRequest: any? = nil -- RemoteEvent

-- Local feedback system
local _feedbackActive: boolean = false
local _feedbackEndTime: number = 0
local _feedbackDuration: number = 0.1 -- seconds for highlight flash

-- Mock services for testing
local MockReplicatedStorage: any = {
    FindFirstChild = function(_self: any, _name: string): any?
        return nil
    end,
}

local MockSoundService: any = {
    PlaySound = function(_self: any, _soundId: string)
        -- Mock sound playback
    end,
}

-- Try to get real services
local ReplicatedStorage: any = MockReplicatedStorage
local SoundService: any = MockSoundService

local success, result = pcall(function()
    return (game :: any):GetService("ReplicatedStorage")
end)
if success then
    ReplicatedStorage = result
end

success, result = pcall(function()
    return (game :: any):GetService("SoundService")
end)
if success then
    SoundService = result
end

-- Get current time (frame-based for testing, actual time in Roblox)
local function GetCurrentTime(): number
    -- In Roblox, we could use tick() or time()
    -- For testing, we'll track via mock
    return tick and tick() or os.clock()
end

-- Load RemoteEvent or create mock
local function GetInteractionRequestEvent(): any?
    if _InteractionRequest then
        return _InteractionRequest
    end
    
    if ReplicatedStorage and ReplicatedStorage.FindFirstChild then
        local event = ReplicatedStorage:FindFirstChild("InteractionRequest")
        if event then
            _InteractionRequest = event
            return event
        end
    end
    
    -- Create mock for testing
    _InteractionRequest = {
        _lastFired = nil,
        FireServer = function(self: any, target: any, hitPosition: any)
            self._lastFired = {
                target = target,
                hitPosition = hitPosition,
                timestamp = GetCurrentTime(),
            }
        end,
        GetLastFired = function(self: any): any?
            return self._lastFired
        end,
        ClearLastFired = function(self: any)
            self._lastFired = nil
        end,
    }
    
    return _InteractionRequest
end

-- Check if on cooldown
local function IsOnCooldown(): boolean
    local currentTime = GetCurrentTime()
    return (currentTime - _lastInteractionTime) < INTERACTION_COOLDOWN
end

-- Play interaction feedback (sound + visual)
local function TriggerFeedback(): ()
    -- Visual feedback - flash highlight
    _feedbackActive = true
    _feedbackEndTime = GetCurrentTime() + _feedbackDuration
    
    -- Sound feedback (if available)
    -- In real Roblox, would play a sound here
end

-- Cancel feedback (prefixed with underscore since it's currently unused)
local function _CancelFeedback(): ()
    _feedbackActive = false
end

-- Update feedback state (called each frame)
local function UpdateFeedback(): ()
    if _feedbackActive then
        local currentTime = GetCurrentTime()
        if currentTime >= _feedbackEndTime then
            _feedbackActive = false
        end
    end
end

-- Attempt to interact with the current target
function InteractionController.TryInteract(): boolean
    if not _isInitialized or not _isEnabled then
        return false
    end
    
    -- Check cooldown
    if IsOnCooldown() then
        return false
    end
    
    -- Get detection result
    local detectionResult: any? = nil
    if _InteractionDetector then
        detectionResult = _InteractionDetector.Detect()
    end
    
    if not detectionResult then
        return false
    end
    
    -- Validate interactable
    local hitObject = detectionResult.hitObject
    local isInteractable = detectionResult.isInteractable
    local distance = detectionResult.distance
    
    if not hitObject or not isInteractable then
        return false
    end
    
    -- Check distance
    if distance > MAX_INTERACTION_DISTANCE then
        return false
    end
    
    -- Store current target
    _currentTarget = hitObject
    
    -- Fire RemoteEvent to server
    local event = GetInteractionRequestEvent()
    if event and event.FireServer then
        event:FireServer(hitObject, detectionResult.hitPosition)
    end
    
    -- Check for Interact BindableEvent on the object
    if hitObject and hitObject.FindFirstChild then
        local interactEvent = hitObject:FindFirstChild("Interact")
        if interactEvent and interactEvent.Fire then
            -- Fire the BindableEvent
            interactEvent:Fire()
        end
    end
    
    -- Update last interaction time
    _lastInteractionTime = GetCurrentTime()
    
    -- Trigger feedback
    TriggerFeedback()
    
    return true
end

-- Handle E key press
local function OnEKeyPressed(): boolean
    if not _isInitialized or not _isEnabled then
        return false
    end
    
    return InteractionController.TryInteract()
end

-- Handle input state changes (called from render step)
function InteractionController.Update(): ()
    if not _isInitialized or not _isEnabled then
        return
    end
    
    -- Update feedback timer
    UpdateFeedback()
    
    -- Check for E key press (only on frame where E transitions from false to true)
    -- Note: This is handled by OnInputEnded for E key to detect a full press
end

-- Initialize the controller
function InteractionController.Initialize(inputHandler: any?, interactionDetector: any?, objectHighlighter: any?): ()
    if _isInitialized then
        return
    end
    
    -- Store dependencies
    _InputHandler = inputHandler
    _InteractionDetector = interactionDetector
    _ObjectHighlighter = objectHighlighter
    
    -- Load modules if not provided
    if not _InputHandler then
        local success2, InputHandlerModule = pcall(function()
            local rs = (game :: any):GetService("ReplicatedStorage")
            local modules = rs:FindFirstChild("Modules")
            if modules then
                return require(modules:FindFirstChild("InputHandler"))
            end
            return nil
        end)
        if success2 then
            _InputHandler = InputHandlerModule
        end
    end
    
    if not _InteractionDetector then
        local success2, DetectorModule = pcall(function()
            local rs = (game :: any):GetService("ReplicatedStorage")
            local modules = rs:FindFirstChild("Modules")
            if modules then
                return require(modules:FindFirstChild("InteractionDetector"))
            end
            return nil
        end)
        if success2 then
            _InteractionDetector = DetectorModule
        end
    end
    
    if not _ObjectHighlighter then
        local success2, HighlighterModule = pcall(function()
            local rs = (game :: any):GetService("ReplicatedStorage")
            local modules = rs:FindFirstChild("Modules")
            if modules then
                return require(modules:FindFirstChild("ObjectHighlighter"))
            end
            return nil
        end)
        if success2 then
            _ObjectHighlighter = HighlighterModule
        end
    end
    
    -- Set up E key listening via InputEnded (full key press)
    if _InputHandler then
        -- Use OnInputEnded to detect when E key is released
        _InputHandler.OnInputEnded(function(inputObject: any, gameProcessedEvent: boolean)
            if gameProcessedEvent then
                return
            end
            
            local keyCodeName: string? = nil
            if inputObject.KeyCode then
                local keyCodeType = typeof(inputObject.KeyCode)
                if keyCodeType == "EnumItem" or keyCodeType == "table" then
                    local kc = inputObject.KeyCode :: { Name: string }
                    keyCodeName = kc.Name
                elseif type(inputObject.KeyCode) == "string" then
                    keyCodeName = inputObject.KeyCode
                end
            end
            
            if keyCodeName == "E" then
                OnEKeyPressed()
            end
        end)
    end
    
    -- Ensure InteractionRequest event exists (in real Roblox, this would be created by server)
    GetInteractionRequestEvent()
    
    _isInitialized = true
    _isEnabled = true
end

-- Check if initialized
function InteractionController.IsInitialized(): boolean
    return _isInitialized
end

-- Check if enabled
function InteractionController.IsEnabled(): boolean
    return _isEnabled
end

-- Enable/disable interaction
function InteractionController.SetEnabled(enabled: boolean): ()
    _isEnabled = enabled
end

-- Get current target
function InteractionController.GetCurrentTarget(): any?
    return _currentTarget
end

-- Check if currently interacting (on cooldown)
function InteractionController.IsOnCooldown(): boolean
    return IsOnCooldown()
end

-- Check if feedback is active
function InteractionController.IsFeedbackActive(): boolean
    return _feedbackActive
end

-- Get last interaction time
function InteractionController.GetLastInteractionTime(): number
    return _lastInteractionTime
end

-- Get interaction cooldown
function InteractionController.GetCooldown(): number
    return INTERACTION_COOLDOWN
end

-- Get max interaction distance
function InteractionController.GetMaxDistance(): number
    return MAX_INTERACTION_DISTANCE
end

-- Cleanup the controller
function InteractionController.Cleanup(): ()
    _isInitialized = false
    _isEnabled = false
    _lastInteractionTime = 0
    _currentTarget = nil
    _feedbackActive = false
    _InputHandler = nil
    _InteractionDetector = nil
    _ObjectHighlighter = nil
    _InteractionRequest = nil
end

-- Testing helpers
function InteractionController.SetMockInputHandler(mockHandler: any): ()
    _InputHandler = mockHandler
end

function InteractionController.SetMockInteractionDetector(mockDetector: any): ()
    _InteractionDetector = mockDetector
end

function InteractionController.SetMockObjectHighlighter(mockHighlighter: any): ()
    _ObjectHighlighter = mockHighlighter
end

function InteractionController.SetMockReplicatedStorage(mockRS: any): ()
    ReplicatedStorage = mockRS
end

-- For testing: Simulate E key press
function InteractionController.SimulateEKeyPress(): boolean
    return OnEKeyPressed()
end

-- For testing: Get the RemoteEvent
function InteractionController.GetRemoteEvent(): any?
    return GetInteractionRequestEvent()
end

-- For testing: Reset state
function InteractionController.ResetState(): ()
    _lastInteractionTime = 0
    _currentTarget = nil
    _feedbackActive = false
    if _InteractionRequest and _InteractionRequest.ClearLastFired then
        _InteractionRequest:ClearLastFired()
    end
end

-- For testing: Set cooldown manually
function InteractionController.SetLastInteractionTime(time: number): ()
    _lastInteractionTime = time
end

return InteractionController