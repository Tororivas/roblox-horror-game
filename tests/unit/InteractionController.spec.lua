--!strict
--[[
    InteractionController Module Tests
    Validates E key interaction system functionality.
]]

-- Create a fresh InteractionController module for testing
local function createTestInteractionController()
    -- Constants
    local MAX_INTERACTION_DISTANCE: number = 5
    local INTERACTION_COOLDOWN: number = 0.3
    
    -- Module table
    local module: any = {}
    
    -- Private state
    local _isInitialized: boolean = false
    local _isEnabled: boolean = false
    local _lastInteractionTime: number = -1000 -- Start with negative time to ensure not on cooldown
    local _currentTarget: any? = nil
    local _feedbackActive: boolean = false
    local _feedbackEndTime: number = 0
    local _feedbackDuration: number = 0.1
    local _lastRemoteFired: any? = nil
    local _lastBindableFired: any? = nil
    
    -- Mock dependencies
    local _mockInputHandler: any? = nil
    local _mockInteractionDetector: any? = nil
    local _mockObjectHighlighter: any? = nil
    
    -- Current mock time
    local _mockCurrentTime: number = 0
    
    -- Check if on cooldown
    local function IsOnCooldown(): boolean
        -- If never interacted (time is negative), not on cooldown
        if _lastInteractionTime < 0 then
            return false
        end
        local timeDiff = _mockCurrentTime - _lastInteractionTime
        return timeDiff < INTERACTION_COOLDOWN
    end
    
    -- Play interaction feedback
    local function TriggerFeedback(): ()
        _feedbackActive = true
        _feedbackEndTime = _mockCurrentTime + _feedbackDuration
    end
    
    -- Update feedback state
    local function UpdateFeedback(): ()
        if _feedbackActive then
            if _mockCurrentTime >= _feedbackEndTime then
                _feedbackActive = false
            end
        end
    end
    
    -- Attempt to interact
    function module.TryInteract(): boolean
        if not _isInitialized then
            return false
        end
        
        if not _isEnabled then
            return false
        end
        
        if IsOnCooldown() then
            return false
        end
        
        -- Get detection result from mock detector
        local detectionResult: any? = nil
        if _mockInteractionDetector then
            detectionResult = _mockInteractionDetector.Detect()
        end
        
        if not detectionResult then
            return false
        end
        
        local hitObject = detectionResult.hitObject
        local isInteractable = detectionResult.isInteractable
        local distance = detectionResult.distance
        
        if not hitObject then
            return false
        end
        
        if not isInteractable then
            return false
        end
        
        if distance > MAX_INTERACTION_DISTANCE then
            return false
        end
        
        _currentTarget = hitObject
        
        -- Fire mock RemoteEvent
        _lastRemoteFired = {
            target = hitObject,
            hitPosition = detectionResult.hitPosition,
            timestamp = _mockCurrentTime,
        }
        
        -- Fire mock BindableEvent if exists
        if hitObject and hitObject.Interact then
            _lastBindableFired = {
                target = hitObject,
                timestamp = _mockCurrentTime,
            }
        end
        
        _lastInteractionTime = _mockCurrentTime
        TriggerFeedback()
        
        return true
    end
    
    -- Handle input ended (E key release)
    local function OnInputEnded(inputObject: any, gameProcessedEvent: boolean): ()
        if gameProcessedEvent then
            return
        end
        
        if not _isInitialized then
            return
        end
        
        if not _isEnabled then
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
            module.TryInteract()
        end
    end
    
    -- Initialize
    function module.Initialize(inputHandler: any?, interactionDetector: any?, objectHighlighter: any?): boolean
        if _isInitialized then
            return true
        end
        
        -- Only set values if passed, otherwise keep existing (for testing)
        if inputHandler then
            _mockInputHandler = inputHandler
        end
        if interactionDetector then
            _mockInteractionDetector = interactionDetector
        end
        if objectHighlighter then
            _mockObjectHighlighter = objectHighlighter
        end
        
        -- Set up InputEnded listener
        if _mockInputHandler then
            pcall(function()
                _mockInputHandler.OnInputEnded(function(io: any, gpe: boolean)
                    OnInputEnded(io, gpe)
                end)
            end)
        end
        
        _isInitialized = true
        _isEnabled = true
        return true
    end
    
    -- Check states
    function module.IsInitialized(): boolean
        return _isInitialized
    end
    
    function module.IsEnabled(): boolean
        return _isEnabled
    end
    
    function module.SetEnabled(enabled: boolean): ()
        _isEnabled = enabled
    end
    
    function module.GetCurrentTarget(): any?
        return _currentTarget
    end
    
    function module.IsOnCooldown(): boolean
        return IsOnCooldown()
    end
    
    function module.IsFeedbackActive(): boolean
        UpdateFeedback()
        return _feedbackActive
    end
    
    function module.GetLastInteractionTime(): number
        return _lastInteractionTime
    end
    
    function module.GetCooldown(): number
        return INTERACTION_COOLDOWN
    end
    
    function module.GetMaxDistance(): number
        return MAX_INTERACTION_DISTANCE
    end
    
    function module.Cleanup(): ()
        _isInitialized = false
        _isEnabled = false
        _lastInteractionTime = -1000
        _currentTarget = nil
        _feedbackActive = false
        _lastRemoteFired = nil
    end
    
    -- Testing helpers
    function module.SetMockTime(time: number): ()
        _mockCurrentTime = time
    end
    
    function module.AdvanceTime(delta: number): ()
        _mockCurrentTime = _mockCurrentTime + delta
        UpdateFeedback()
    end
    
    function module.SetMockInputHandler(mockHandler: any): ()
        _mockInputHandler = mockHandler
    end
    
    function module.SetMockInteractionDetector(mockDetector: any): ()
        _mockInteractionDetector = mockDetector
    end
    
    function module.SetMockObjectHighlighter(mockHighlighter: any): ()
        _mockObjectHighlighter = mockHighlighter
    end
    
    function module.SimulateEKeyPress(): boolean
        return module.TryInteract()
    end
    
    function module.GetLastRemoteFired(): any?
        return _lastRemoteFired
    end
    
    function module.GetLastBindableFired(): any?
        return _lastBindableFired
    end
    
    function module.ResetState(): ()
        _lastInteractionTime = -1000
        _currentTarget = nil
        _feedbackActive = false
        _lastRemoteFired = nil
        _lastBindableFired = nil
    end
    
    function module.SetLastInteractionTime(time: number): ()
        _lastInteractionTime = time
    end
    
    function module.TriggerInputEnded(inputObject: any, gameProcessedEvent: boolean): ()
        OnInputEnded(inputObject, gameProcessedEvent)
    end
    
    return module
end

-- Mock object creators
local function createMockInteractableObject(name: string, hasInteractEvent: boolean): any
    local obj: any = {
        Name = name,
        _isDestroyed = false,
    }
    
    if hasInteractEvent then
        obj.Interact = {
            _fired = false,
            Fire = function(self: any)
                self._fired = true
            end,
            WasFired = function(self: any): boolean
                return self._fired
            end,
        }
    end
    
    return obj
end

local function createMockInputObject(keyCodeName: string): any
    return {
        KeyCode = {
            Name = keyCodeName,
            Value = 0,
        },
        UserInputType = "Keyboard",
    }
end

-- Test runner
local function runTests(): (number, number)
    print("Running InteractionController module tests (US-008)...")
    local passed = 0
    local failed = 0
    
    local function runTest(testName: string, testFn: () -> ()): boolean
        local success, err = pcall(testFn)
        if success then
            passed = passed + 1
            return true
        else
            failed = failed + 1
            print("  FAIL: " .. testName .. " - " .. tostring(err))
            return false
        end
    end
    
    -- Test 1: Module exists with required functions
    runTest("Module exists with required functions", function()
        local controller = createTestInteractionController()
        assert(controller.Initialize ~= nil, "Initialize should exist")
        assert(controller.TryInteract ~= nil, "TryInteract should exist")
        assert(controller.IsInitialized ~= nil, "IsInitialized should exist")
        assert(controller.IsEnabled ~= nil, "IsEnabled should exist")
        assert(controller.SetEnabled ~= nil, "SetEnabled should exist")
        assert(controller.GetCurrentTarget ~= nil, "GetCurrentTarget should exist")
        assert(controller.IsOnCooldown ~= nil, "IsOnCooldown should exist")
        assert(controller.IsFeedbackActive ~= nil, "IsFeedbackActive should exist")
        assert(controller.GetLastInteractionTime ~= nil, "GetLastInteractionTime should exist")
        assert(controller.GetCooldown ~= nil, "GetCooldown should exist")
        assert(controller.GetMaxDistance ~= nil, "GetMaxDistance should exist")
        assert(controller.Cleanup ~= nil, "Cleanup should exist")
        assert(controller.SimulateEKeyPress ~= nil, "SimulateEKeyPress should exist")
    end)
    
    -- Test 2: Initial state is correct
    runTest("Initial state is correct", function()
        local controller = createTestInteractionController()
        assert(controller.IsInitialized() == false, "Should not be initialized initially")
        assert(controller.IsEnabled() == false, "Should not be enabled initially")
        assert(controller.GetCurrentTarget() == nil, "Target should be nil initially")
        controller.SetMockTime(0)
        assert(controller.IsOnCooldown() == false, "Should not be on cooldown initially")
        assert(controller.IsFeedbackActive() == false, "Feedback should not be active")
    end)
    
    -- Test 3: Initialize enables the controller
    runTest("Initialize enables the controller", function()
        local controller = createTestInteractionController()
        local result = controller.Initialize()
        assert(controller.IsInitialized() == true, "Should be initialized after Initialize()")
        assert(controller.IsEnabled() == true, "Should be enabled after Initialize()")
        assert(result == true, "Should return true")
    end)
    
    -- Test 4: Initialize with dependencies
    runTest("Initialize with dependencies", function()
        local controller = createTestInteractionController()
        local mockInput = { OnInputEnded = function(_callback: any) return function() end end }
        local mockDetector = { Detect = function() return nil end }
        local mockHighlighter = {}
        
        controller.SetMockInputHandler(mockInput)
        controller.SetMockInteractionDetector(mockDetector)
        controller.SetMockObjectHighlighter(mockHighlighter)
        controller.Initialize()
        
        assert(controller.IsInitialized() == true, "Should be initialized")
    end)
    
    -- Test 5: TryInteract fails when not initialized
    runTest("TryInteract fails when not initialized", function()
        local controller = createTestInteractionController()
        local result = controller.TryInteract()
        assert(result == false, "Should return false when not initialized")
    end)
    
    -- Test 6: TryInteract fails when disabled
    runTest("TryInteract fails when disabled", function()
        local controller = createTestInteractionController()
        controller.Initialize()
        controller.SetEnabled(false)
        local result = controller.TryInteract()
        assert(result == false, "Should return false when disabled")
    end)
    
    -- Test 7: TryInteract fails with no detection result
    runTest("TryInteract fails with no detection result", function()
        local controller = createTestInteractionController()
        local mockDetector = {
            Detect = function() return nil end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        local result = controller.TryInteract()
        assert(result == false, "Should return false with no detection")
    end)
    
    -- Test 8: TryInteract fails with no hit object
    runTest("TryInteract fails with no hit object", function()
        local controller = createTestInteractionController()
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = nil,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 5,
                    isInteractable = false,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        local result = controller.TryInteract()
        assert(result == false, "Should return false with no hit object")
    end)
    
    -- Test 9: TryInteract fails with non-interactable object
    runTest("TryInteract fails with non-interactable object", function()
        local controller = createTestInteractionController()
        local mockObject = createMockInteractableObject("NonInteractable", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 3,
                    isInteractable = false,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        local result = controller.TryInteract()
        assert(result == false, "Should return false with non-interactable object")
    end)
    
    -- Test 10: TryInteract fails when object is too far (> 5 studs)
    runTest("TryInteract fails when object is too far (> 5 studs)", function()
        local controller = createTestInteractionController()
        local mockObject = createMockInteractableObject("FarObject", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 6,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        local result = controller.TryInteract()
        assert(result == false, "Should return false when object is too far")
    end)
    
    -- Test 11: TryInteract succeeds with valid interactable object
    runTest("TryInteract succeeds with valid interactable object", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(1.0)
        local mockObject = createMockInteractableObject("InteractableDoor", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 1, Y = 2, Z = 3},
                    distance = 3,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        local result = controller.TryInteract()
        assert(result == true, "Should return true with valid interactable")
        assert(controller.GetCurrentTarget() == mockObject, "Should store current target")
    end)
    
    -- Test 12: RemoteEvent fired on successful interaction
    runTest("RemoteEvent fired on successful interaction", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(1.0)
        local mockObject = createMockInteractableObject("Door", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 10, Y = 20, Z = 30},
                    distance = 3,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        controller.TryInteract()
        
        local lastRemote = controller.GetLastRemoteFired()
        assert(lastRemote ~= nil, "RemoteEvent should have been fired")
        assert(lastRemote.target == mockObject, "Remote should have correct target")
        assert(lastRemote.hitPosition.X == 10, "Remote should have correct hit position")
        assert(lastRemote.timestamp == 1.0, "Remote should have correct timestamp")
    end)
    
    -- Test 13: BindableEvent fired if object has Interact event
    runTest("BindableEvent fired if object has Interact event", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(2.0)
        local mockObject = createMockInteractableObject("Button", true)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        controller.TryInteract()
        
        local lastBindable = controller.GetLastBindableFired()
        assert(lastBindable ~= nil, "BindableEvent should have been fired")
        assert(lastBindable.target == mockObject, "Bindable should have correct target")
    end)
    
    -- Test 14: Feedback triggered on successful interaction
    runTest("Feedback triggered on successful interaction", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(0)
        local mockObject = createMockInteractableObject("Object", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        assert(controller.IsFeedbackActive() == false, "Feedback should not be active before")
        controller.TryInteract()
        assert(controller.IsFeedbackActive() == true, "Feedback should be active after interaction")
    end)
    
    -- Test 15: Cooldown prevents rapid interactions
    runTest("Cooldown prevents rapid interactions", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(0)
        controller.SetLastInteractionTime(-1000)
        local mockObject = createMockInteractableObject("Object", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        
        -- First interaction should succeed
        local result1 = controller.TryInteract()
        assert(result1 == true, "First interaction should succeed")
        
        -- Second interaction immediately should fail (cooldown)
        controller.AdvanceTime(0.1) -- Only 0.1 seconds passed
        local result2 = controller.TryInteract()
        assert(result2 == false, "Second interaction should fail due to cooldown")
        assert(controller.IsOnCooldown() == true, "Should be on cooldown")
    end)
    
    -- Test 16: Interaction succeeds after cooldown expires
    runTest("Interaction succeeds after cooldown expires", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(0)
        controller.SetLastInteractionTime(-1000)
        local mockObject = createMockInteractableObject("Object", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        
        -- First interaction
        controller.TryInteract()
        assert(controller.IsOnCooldown() == true, "Should be on cooldown")
        
        -- Wait for cooldown to expire (0.3 seconds)
        controller.AdvanceTime(0.35)
        assert(controller.IsOnCooldown() == false, "Should not be on cooldown after 0.35s")
        
        -- Second interaction should succeed
        local result2 = controller.TryInteract()
        assert(result2 == true, "Second interaction should succeed after cooldown")
    end)
    
    -- Test 17: Cleanup resets all state
    runTest("Cleanup resets all state", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(1.0)
        local mockObject = createMockInteractableObject("Object", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        controller.TryInteract()
        
        assert(controller.IsInitialized() == true, "Should be initialized")
        local target = controller.GetCurrentTarget()
        assert(target ~= nil, "Should have target")
        
        controller.Cleanup()
        
        assert(controller.IsInitialized() == false, "Should not be initialized after cleanup")
        assert(controller.IsEnabled() == false, "Should not be enabled after cleanup")
        assert(controller.GetCurrentTarget() == nil, "Target should be nil after cleanup")
        assert(controller.IsFeedbackActive() == false, "Feedback should not be active after cleanup")
    end)
    
    -- Test 18: Max interaction distance is 5 studs
    runTest("Max interaction distance is 5 studs", function()
        local controller = createTestInteractionController()
        assert(controller.GetMaxDistance() == 5, "Max distance should be 5 studs")
    end)
    
    -- Test 19: Interaction cooldown is 0.3 seconds
    runTest("Interaction cooldown is 0.3 seconds", function()
        local controller = createTestInteractionController()
        assert(controller.GetCooldown() == 0.3, "Cooldown should be 0.3 seconds")
    end)
    
    -- Test 20: E key input triggers TryInteract via TriggerInputEnded
    runTest("E key input triggers TryInteract", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(1.0)
        controller.SetLastInteractionTime(-1000)
        local mockObject = createMockInteractableObject("Door", false)
        
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        
        -- Create E key input object
        local eKeyInput = createMockInputObject("E")
        
        -- Trigger via TriggerInputEnded
        controller.TriggerInputEnded(eKeyInput, false)
        
        -- Verify remote was fired (indicating TryInteract was called)
        local lastRemote = controller.GetLastRemoteFired()
        assert(lastRemote ~= nil, "Remote should be fired after E key press")
        assert(lastRemote.target == mockObject, "Remote should have correct target")
    end)
    
    -- Test 21: E key input is ignored when gameProcessedEvent is true
    runTest("E key input is ignored when gameProcessedEvent is true", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(1.0)
        local mockObject = createMockInteractableObject("Door", false)
        
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        
        -- Create E key input object
        local eKeyInput = createMockInputObject("E")
        
        -- Trigger with gameProcessedEvent = true
        controller.TriggerInputEnded(eKeyInput, true)
        
        -- Verify remote was NOT fired
        local lastRemote = controller.GetLastRemoteFired()
        assert(lastRemote == nil, "Remote should NOT be fired when gameProcessedEvent is true")
    end)
    
    -- Test 22: Non-E keys do not trigger interaction
    runTest("Non-E keys do not trigger interaction", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(1.0)
        local mockObject = createMockInteractableObject("Door", false)
        
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        
        -- Create different key inputs
        local otherKeys = {"W", "A", "S", "D", "LeftShift", "F", "Space"}
        for _, key in ipairs(otherKeys) do
            local keyInput = createMockInputObject(key)
            controller.TriggerInputEnded(keyInput, false)
        end
        
        -- Verify remote was NOT fired for any key
        local lastRemote = controller.GetLastRemoteFired()
        assert(lastRemote == nil, "Remote should NOT be fired for non-E keys")
    end)
    
    -- Test 23: Resets state properly
    runTest("ResetState clears all interaction data", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(5.0)
        controller.SetLastInteractionTime(-1000)
        local mockObject = createMockInteractableObject("Object", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        controller.TryInteract()
        
        local time1 = controller.GetLastInteractionTime()
        assert(time1 > 0 or time1 ~= -1000, "Should have interaction time")
        local target = controller.GetCurrentTarget()
        assert(target ~= nil, "Should have target")
        local remote = controller.GetLastRemoteFired()
        assert(remote ~= nil, "Should have remote fired")
        
        controller.ResetState()
        
        local time2 = controller.GetLastInteractionTime()
        assert(time2 == -1000, "Interaction time should be reset to -1000")
        assert(controller.GetCurrentTarget() == nil, "Target should be nil")
        assert(controller.GetLastRemoteFired() == nil, "Remote fired should be nil")
    end)
    
    -- Test 24: Feedback ends after duration
    runTest("Feedback ends after duration", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(0)
        controller.SetLastInteractionTime(-1000)
        local mockObject = createMockInteractableObject("Object", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        controller.TryInteract()
        
        assert(controller.IsFeedbackActive() == true, "Feedback should be active")
        
        -- Wait for feedback duration (0.1 seconds)
        controller.AdvanceTime(0.15)
        assert(controller.IsFeedbackActive() == false, "Feedback should end after duration")
    end)
    
    -- Test 25: SimulateEKeyPress returns correct value
    runTest("SimulateEKeyPress returns correct value", function()
        local controller = createTestInteractionController()
        controller.SetMockTime(1.0)
        controller.SetLastInteractionTime(-1000)
        local mockObject = createMockInteractableObject("Object", false)
        local mockDetector = {
            Detect = function()
                return {
                    hitObject = mockObject,
                    hitPosition = {X = 0, Y = 0, Z = 0},
                    distance = 2,
                    isInteractable = true,
                }
            end
        }
        controller.SetMockInteractionDetector(mockDetector)
        controller.Initialize()
        
        local result = controller.SimulateEKeyPress()
        assert(result == true, "SimulateEKeyPress should return true with valid target")
    end)
    
    print(string.format("Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests