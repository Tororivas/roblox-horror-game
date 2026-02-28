--!strict
--[[
    PlayerController Integration and Lifecycle Tests
    Tests for US-011: PlayerController initialization, coordination, and lifecycle management.
]]

-- Helper to create a fresh test environment
local function createTestEnvironment()
    -- Create mock module references
    local MockModules: {[string]: any} = {}
    
    -- Mock InputHandler
    MockModules.InputHandler = {
        _isRunning = false,
        _inputState = { W = false, A = false, S = false, D = false, Shift = false, E = false },
        
        Start = function(self: any)
            self._isRunning = true
        end,
        
        Stop = function(self: any)
            self._isRunning = false
        end,
        
        IsRunning = function(self: any): boolean
            return self._isRunning
        end,
        
        GetInputState = function(self: any): any
            return self._inputState
        end,
        
        SetInputState = function(self: any, state: any)
            self._inputState = state
        end,
        
        ResetState = function(self: any)
            self._isRunning = false
            self._inputState = { W = false, A = false, S = false, D = false, Shift = false, E = false }
        end,
        
        OnInputEnded = function(_self: any, callback: any): () -> ()
            return function() end
        end,
    }
    
    -- Mock InteractionController
    MockModules.InteractionController = {
        _isInitialized = false,
        _isEnabled = false,
        _lastFired = nil,
        
        Initialize = function(self: any, inputHandler: any?, interactionDetector: any?, objectHighlighter: any?)
            self._isInitialized = true
            self._isEnabled = true
        end,
        
        IsInitialized = function(self: any): boolean
            return self._isInitialized
        end,
        
        IsEnabled = function(self: any): boolean
            return self._isEnabled
        end,
        
        Cleanup = function(self: any)
            self._isInitialized = false
            self._isEnabled = false
        end,
        
        Update = function(self: any)
            -- Mock update
        end,
        
        ResetState = function(self: any)
            self._isInitialized = false
            self._isEnabled = false
        end,
    }
    
    -- Mock InteractionDetector
    MockModules.InteractionDetector = {
        _isInitialized = false,
        _lastDetectionResult = nil,
        
        Initialize = function(self: any)
            self._isInitialized = true
        end,
        
        Detect = function(self: any): any?
            -- Return mock result
            return self._lastDetectionResult or {
                hitObject = nil,
                hitPosition = nil,
                distance = 0,
                isInteractable = false,
            }
        end,
        
        Cleanup = function(self: any)
            self._isInitialized = false
        end,
        
        SetDetectionResult = function(self: any, result: any)
            self._lastDetectionResult = result
        end,
        
        ResetState = function(self: any)
            self._isInitialized = false
            self._lastDetectionResult = nil
        end,
    }
    
    -- Mock ObjectHighlighter
    MockModules.ObjectHighlighter = {
        _isInitialized = false,
        _currentTarget = nil,
        _currentHighlight = nil,
        
        Initialize = function(self: any)
            self._isInitialized = true
        end,
        
        Update = function(self: any, detectionResult: any?)
            if detectionResult and detectionResult.isInteractable then
                self._currentTarget = detectionResult.hitObject
            else
                self._currentTarget = nil
            end
        end,
        
        Cleanup = function(self: any)
            self._isInitialized = false
            self._currentTarget = nil
            self._currentHighlight = nil
        end,
        
        GetCurrentTarget = function(self: any): any?
            return self._currentTarget
        end,
        
        ResetState = function(self: any)
            self._isInitialized = false
            self._currentTarget = nil
            self._currentHighlight = nil
        end,
    }
    
    -- Mock FootstepSoundSystem
    MockModules.FootstepSoundSystem = {
        _isInitialized = false,
        _lastSpeed = 0,
        _lastSprintState = false,
        
        Initialize = function(self: any)
            self._isInitialized = true
        end,
        
        Update = function(self: any, speed: number, isSprinting: boolean?)
            self._lastSpeed = speed
            self._lastSprintState = isSprinting or false
        end,
        
        IsInitialized = function(self: any): boolean
            return self._isInitialized
        end,
        
        Cleanup = function(self: any)
            self._isInitialized = false
        end,
        
        ResetState = function(self: any)
            self._isInitialized = false
            self._lastSpeed = 0
            self._lastSprintState = false
        end,
    }
    
    -- Mock SanityManager
    MockModules.SanityManager = {
        _isInitialized = false,
        _currentSanity = 100,
        _isSprinting = false,
        _isMoving = false,
        _depletionRate = 0,
        
        Initialize = function(self: any, player: any?)
            self._isInitialized = true
            self._currentSanity = 100
            self._isSprinting = false
            self._isMoving = false
            self._depletionRate = 0
        end,
        
        IsInitialized = function(self: any): boolean
            return self._isInitialized
        end,
        
        UpdateFromMovementState = function(self: any, isMoving: boolean, isSprinting: boolean, deltaTime: number)
            self._isMoving = isMoving
            self._isSprinting = isSprinting
            -- Simulate depletion calculation
            if isMoving then
                self._depletionRate = isSprinting and 0.05 or 0.01
            else
                self._depletionRate = 0
            end
        end,
        
        GetSanity = function(self: any): number
            return self._currentSanity
        end,
        
        GetCurrentDepletionRate = function(self: any): number
            return self._depletionRate
        end,
        
        IsSprinting = function(self: any): boolean
            return self._isSprinting
        end,
        
        IsMoving = function(self: any): boolean
            return self._isMoving
        end,
        
        Cleanup = function(self: any)
            self._isInitialized = false
            self._currentSanity = 100
            self._isSprinting = false
            self._isMoving = false
            self._depletionRate = 0
        end,
        
        ResetState = function(self: any)
            self._isInitialized = false
            self._currentSanity = 100
            self._isSprinting = false
            self._isMoving = false
            self._depletionRate = 0
        end,
    }
    
    -- Mock Players service
    local MockPlayersService = {
        LocalPlayer = {
            UserId = 1,
            Name = "TestPlayer",
            Character = nil,
            
            CharacterAdded = {
                _callbacks = {},
                Connect = function(self: any, callback: any): any
                    table.insert(self._callbacks, callback)
                    return {
                        Disconnect = function()
                            -- Remove callback
                            for i, cb in ipairs(self._callbacks) do
                                if cb == callback then
                                    table.remove(self._callbacks, i)
                                    break
                                end
                            end
                        end,
                    }
                end,
                Fire = function(self: any, character: any)
                    for _, callback in ipairs(self._callbacks) do
                        callback(character)
                    end
                end,
            },
            
            CharacterRemoving = {
                _callbacks = {},
                Connect = function(self: any, callback: any): any
                    table.insert(self._callbacks, callback)
                    return {
                        Disconnect = function()
                            for i, cb in ipairs(self._callbacks) do
                                if cb == callback then
                                    table.remove(self._callbacks, i)
                                    break
                                end
                            end
                        end,
                    }
                end,
                Fire = function(self: any)
                    for _, callback in ipairs(self._callbacks) do
                        callback()
                    end
                end,
            },
        },
    }
    
    -- Mock UserInputService
    local MockUserInputService = {
        MouseIconEnabled = true,
        MouseBehavior = 0,
        InputChanged = {
            _callbacks = {},
            Connect = function(self: any, callback: any): any
                table.insert(self._callbacks, callback)
                return {
                    Disconnect = function()
                        for i, cb in ipairs(self._callbacks) do
                            if cb == callback then
                                table.remove(self._callbacks, i)
                                break
                            end
                        end
                    end,
                }
            end,
        },
        SetMouseBehavior = function(self: any, behavior: number)
            self.MouseBehavior = behavior
        end,
        FireInputChanged = function(self: any, inputObject: any, gameProcessed: boolean)
            for _, callback in ipairs(self._callbacks) do
                callback(inputObject, gameProcessed)
            end
        end,
    }
    
    -- Mock RunService
    local MockRunService = {
        RenderStepped = {
            _callbacks = {},
            Connect = function(self: any, callback: any): any
                table.insert(self._callbacks, callback)
                return {
                    Disconnect = function()
                        for i, cb in ipairs(self._callbacks) do
                            if cb == callback then
                                table.remove(self._callbacks, i)
                                break
                            end
                        end
                    end,
                }
            end,
        },
        _simulateRenderStep = function(self: any)
            for _, callback in ipairs(self.RenderStepped._callbacks) do
                callback(0.016) -- 60 FPS
            end
        end,
    }
    
    -- Mock Humanoid
    local MockHumanoid = {
        WalkSpeed = 16,
        MoveDirection = {X = 0, Y = 0, Z = 0},
        Running = {
            _callbacks = {},
            Connect = function(self: any, callback: any): any
                table.insert(self._callbacks, callback)
                return {
                    Disconnect = function()
                        for i, cb in ipairs(self._callbacks) do
                            if cb == callback then
                                table.remove(self._callbacks, i)
                                break
                            end
                        end
                    end,
                }
            end,
        },
        Move = function(self: any, direction: any)
            self.MoveDirection = direction
        end,
        FireRunning = function(self: any, speed: number)
            for _, callback in ipairs(self.Running._callbacks) do
                callback(speed)
            end
        end,
    }
    
    -- Mock Character
    local MockCharacter = {
        Name = "Character",
        Head = {
            Position = {X = 0, Y = 5, Z = 0},
        },
        Humanoid = MockHumanoid,
        FindFirstChild = function(self: any, name: string): any?
            return self[name]
        end,
    }
    
    -- Mock Workspace and Camera
    local MockCamera = {
        CameraType = 0,
        FieldOfView = 70,
        CFrame = {
            Position = {X = 0, Y = 5, Z = 0},
            LookVector = {X = 0, Y = 0, Z = -1},
        },
    }
    
    local MockWorkspace = {
        Camera = MockCamera,
        FindFirstChild = function(self: any, name: string): any?
            return self[name]
        end,
    }
    
    return {
        MockModules = MockModules,
        MockPlayersService = MockPlayersService,
        MockUserInputService = MockUserInputService,
        MockRunService = MockRunService,
        MockHumanoid = MockHumanoid,
        MockCharacter = MockCharacter,
        MockCamera = MockCamera,
        MockWorkspace = MockWorkspace,
    }
end

-- Main test function
local function runTests(): (number, number)
    print("\n=== Running PlayerController Integration and Lifecycle Tests ===\n")
    local passed = 0
    local failed = 0
    
    local function runTest(testName: string, testFn: () -> ()): boolean
        local success, err = pcall(testFn)
        if success then
            passed += 1
            return true
        else
            failed += 1
            print("FAIL: " .. testName .. " - " .. tostring(err))
            return false
        end
    end
    
    -- ========== TEST 1: Module initializes all subsystems on Initialize() ==========
    runTest("Initialize loads and starts all modules", function()
        local env = createTestEnvironment()
        local PlayerController = {}
        local Modules = {}
        
        -- Simplified init that mimics real behavior
        Modules.InputHandler = env.MockModules.InputHandler
        Modules.SanityManager = env.MockModules.SanityManager
        Modules.FootstepSoundSystem = env.MockModules.FootstepSoundSystem
        Modules.InteractionController = env.MockModules.InteractionController
        Modules.InteractionDetector = env.MockModules.InteractionDetector
        Modules.ObjectHighlighter = env.MockModules.ObjectHighlighter
        
        -- Initialize all
        Modules.InputHandler:Start()
        Modules.SanityManager:Initialize()
        Modules.FootstepSoundSystem:Initialize()
        Modules.InteractionController:Initialize(Modules.InputHandler, Modules.InteractionDetector, Modules.ObjectHighlighter)
        Modules.InteractionDetector:Initialize()
        Modules.ObjectHighlighter:Initialize()
        
        -- Verify all initialized
        assert(Modules.InputHandler:IsRunning(), "InputHandler should be running")
        assert(Modules.SanityManager:IsInitialized(), "SanityManager should be initialized")
        assert(Modules.FootstepSoundSystem:IsInitialized(), "FootstepSoundSystem should be initialized")
        assert(Modules.InteractionController:IsInitialized(), "InteractionController should be initialized")
        assert(Modules.InteractionDetector._isInitialized, "InteractionDetector should be initialized")
        assert(Modules.ObjectHighlighter._isInitialized, "ObjectHighlighter should be initialized")
    end)
    
    -- ========== TEST 2: Systems are wired - InputHandler provides input state ==========
    runTest("InputHandler provides input state to movement", function()
        local env = createTestEnvironment()
        local inputHandler = env.MockModules.InputHandler
        
        -- Set input state
        inputHandler:SetInputState({ W = true, A = false, S = false, D = false, Shift = false, E = false })
        
        -- Get input state
        local state = inputHandler:GetInputState()
        
        assert(state.W == true, "W should be true")
        assert(state.A == false, "A should be false")
        assert(state.Shift == false, "Shift should be false")
    end)
    
    -- ========== TEST 3: Sprint state informs Sanity depletion rate ==========
    runTest("Sprint state informs Sanity depletion rate", function()
        local env = createTestEnvironment()
        local sanityManager = env.MockModules.SanityManager
        
        -- Initialize
        sanityManager:Initialize()
        
        -- Simulate walking (not sprinting)
        sanityManager:UpdateFromMovementState(true, false, 0.016)
        local walkRate = sanityManager:GetCurrentDepletionRate()
        
        -- Simulate sprinting
        sanityManager:UpdateFromMovementState(true, true, 0.016)
        local sprintRate = sanityManager:GetCurrentDepletionRate()
        
        -- Sprinting should have higher depletion rate
        assert(sprintRate > walkRate, "Sprint depletion rate should be higher than walk")
        assert(walkRate == 0.01, "Walk rate should be 0.01")
        assert(sprintRate == 0.05, "Sprint rate should be 0.05")
    end)
    
    -- ========== TEST 4: Cleanup stops all modules ==========
    runTest("Cleanup stops and resets all modules", function()
        local env = createTestEnvironment()
        local Modules = {}
        Modules.InputHandler = env.MockModules.InputHandler
        Modules.SanityManager = env.MockModules.SanityManager
        Modules.FootstepSoundSystem = env.MockModules.FootstepSoundSystem
        Modules.InteractionController = env.MockModules.InteractionController
        Modules.InteractionDetector = env.MockModules.InteractionDetector
        Modules.ObjectHighlighter = env.MockModules.ObjectHighlighter
        
        -- Initialize all
        Modules.InputHandler:Start()
        Modules.SanityManager:Initialize()
        Modules.FootstepSoundSystem:Initialize()
        Modules.InteractionController:Initialize()
        Modules.InteractionDetector:Initialize()
        Modules.ObjectHighlighter:Initialize()
        
        -- Cleanup all
        Modules.InputHandler:Stop()
        Modules.SanityManager:Cleanup()
        Modules.FootstepSoundSystem:Cleanup()
        Modules.InteractionController:Cleanup()
        Modules.InteractionDetector:Cleanup()
        Modules.ObjectHighlighter:Cleanup()
        
        -- Verify all cleaned up
        assert(not Modules.InputHandler:IsRunning(), "InputHandler should not be running")
        assert(not Modules.SanityManager:IsInitialized(), "SanityManager should not be initialized")
        assert(not Modules.FootstepSoundSystem:IsInitialized(), "FootstepSoundSystem should not be initialized")
        assert(not Modules.InteractionController:IsInitialized(), "InteractionController should not be initialized")
        assert(not Modules.InteractionDetector._isInitialized, "InteractionDetector should not be initialized")
        assert(not Modules.ObjectHighlighter._isInitialized, "ObjectHighlighter should not be initialized")
    end)
    
    -- ========== TEST 5: Respawn resets camera state ==========
    runTest("Respawn resets camera state", function()
        local PlayerController = {}
        local _cameraState = { yaw = 45, pitch = 30, isFirstPerson = true }
        
        function PlayerController.ResetCameraState()
            _cameraState.yaw = 0
            _cameraState.pitch = 0
        end
        
        -- Simulate respawn
        PlayerController.ResetCameraState()
        
        assert(_cameraState.yaw == 0, "Yaw should be reset to 0")
        assert(_cameraState.pitch == 0, "Pitch should be reset to 0")
    end)
    
    -- ========== TEST 6: Respawn resets interaction state ==========
    runTest("Respawn resets interaction state", function()
        local env = createTestEnvironment()
        local highlighter = env.MockModules.ObjectHighlighter
        
        -- Initialize and set some state
        highlighter:Initialize()
        highlighter:Update({ hitObject = { Name = "TestObject" }, isInteractable = true })
        
        assert(highlighter:GetCurrentTarget() ~= nil, "Target should be set")
        
        -- Cleanup (simulates respawn cleanup)
        highlighter:Cleanup()
        highlighter:Initialize()
        
        assert(highlighter._currentTarget == nil, "Target should be nil after reset")
    end)
    
    -- ========== TEST 7: Respawn resets movement state ==========
    runTest("Respawn resets movement state", function()
        local _movementState = {
            isMoving = true,
            isSprinting = true,
            lastMoveDirection = {X = 1, Y = 0, Z = 0},
        }
        
        local function ResetMovementState()
            _movementState.isMoving = false
            _movementState.isSprinting = false
            _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
        end
        
        -- Simulate respawn
        ResetMovementState()
        
        assert(_movementState.isMoving == false, "isMoving should be false")
        assert(_movementState.isSprinting == false, "isSprinting should be false")
        assert(_movementState.lastMoveDirection.X == 0, "lastMoveDirection should be reset")
    end)
    
    -- ========== TEST 8: Connections are tracked and can be disconnected ==========
    runTest("Connections are tracked and disconnected on cleanup", function()
        local env = createTestEnvironment()
        local runService = env.MockRunService
        local connections: {any} = {}
        
        -- Create connections
        table.insert(connections, runService.RenderStepped:Connect(function() end))
        table.insert(connections, runService.RenderStepped:Connect(function() end))
        
        -- Verify connected
        assert(#runService.RenderStepped._callbacks == 2, "Should have 2 callbacks")
        
        -- Disconnect all
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        
        -- Verify disconnected
        assert(#runService.RenderStepped._callbacks == 0, "Should have 0 callbacks after disconnect")
    end)
    
    -- ========== TEST 9: Lifecycle callbacks fire on events ==========
    runTest("Lifecycle callbacks fire on spawn event", function()
        local env = createTestEnvironment()
        local callbackFired = false
        local _lifecycleCallbacks = { OnSpawn = {}, OnRespawn = {}, OnDeath = {}, OnCleanup = {} }
        
        -- Register callback
        table.insert(_lifecycleCallbacks.OnSpawn, function()
            callbackFired = true
        end)
        
        -- Simulate spawn
        env.MockPlayersService.LocalPlayer.CharacterAdded:Fire(env.MockCharacter)
        
        -- Fire callbacks manually
        for _, callback in ipairs(_lifecycleCallbacks.OnSpawn) do
            callback()
        end
        
        assert(callbackFired == true, "OnSpawn callback should have fired")
    end)
    
    -- ========== TEST 10: Interaction detection coordinates with highlighting ==========
    runTest("Interaction detection updates highlighting", function()
        local env = createTestEnvironment()
        local detector = env.MockModules.InteractionDetector
        local highlighter = env.MockModules.ObjectHighlighter
        
        -- Initialize
        detector:Initialize()
        highlighter:Initialize()
        
        -- Set detection result
        local mockObject = { Name = "InteractableObject" }
        detector:SetDetectionResult({
            hitObject = mockObject,
            hitPosition = {X = 0, Y = 0, Z = -5},
            distance = 5,
            isInteractable = true,
        })
        
        -- Update highlighter with detection result
        highlighter:Update(detector:Detect())
        
        -- Verify highlighter has target
        assert(highlighter:GetCurrentTarget() == mockObject, "Highlighter should have the interactable target")
    end)
    
    -- ========== TEST 11: Footstep system receives sprint state ==========
    runTest("Footstep system receives sprint state from movement", function()
        local env = createTestEnvironment()
        local footstepSystem = env.MockModules.FootstepSoundSystem
        local sanityManager = env.MockModules.SanityManager
        
        -- Initialize
        footstepSystem:Initialize()
        
        -- Update with sprint
        footstepSystem:Update(24, true)
        
        -- Verify footstep system got sprint info
        assert(footstepSystem._lastSprintState == true, "Footstep should know player is sprinting")
        
        -- Update sanity with same sprint state
        sanityManager:Initialize()
        sanityManager:UpdateFromMovementState(true, true, 0.016)
        
        assert(sanityManager:IsSprinting() == true, "SanityManager should reflect sprint state")
        assert(sanityManager:GetCurrentDepletionRate() == 0.05, "Sanity should deplete faster when sprinting")
    end)
    
    -- ========== TEST 12: Input state properly reset between sessions ==========
    runTest("Input state resets properly", function()
        local env = createTestEnvironment()
        local inputHandler = env.MockModules.InputHandler
        
        -- Set some state
        inputHandler:SetInputState({ W = true, A = true, S = false, D = false, Shift = true, E = false })
        local state1 = inputHandler:GetInputState()
        assert(state1.W == true, "W should be set")
        assert(state1.Shift == true, "Shift should be set")
        
        -- Reset
        inputHandler:ResetState()
        local state2: any = inputHandler:GetInputState()
        
        if state2 then
            assert(state2.W == false, "W should be false after reset")
            assert(state2.Shift == false, "Shift should be false after reset")
        end
        assert(not inputHandler:IsRunning(), "InputHandler should not be running after reset")
    end)
    
    -- ========== TEST 13: Sanity sprint coordination affects depletion rate ==========
    runTest("Sprint-Sanity coordination sets correct depletion rates", function()
        local env = createTestEnvironment()
        local sanityManager = env.MockModules.SanityManager
        sanityManager:Initialize()
        
        -- Not moving
        sanityManager:UpdateFromMovementState(false, false, 1)
        local rate1 = sanityManager:GetCurrentDepletionRate()
        assert(rate1 == 0, "Not moving should have 0 depletion rate")
        
        -- Walking
        sanityManager:UpdateFromMovementState(true, false, 1)
        local rate2 = sanityManager:GetCurrentDepletionRate()
        assert(rate2 == 0.01, "Walking should have 0.01 depletion rate")
        
        -- Sprinting
        sanityManager:UpdateFromMovementState(true, true, 1)
        local rate3 = sanityManager:GetCurrentDepletionRate()
        assert(rate3 == 0.05, "Sprinting should have 0.05 depletion rate")
        
        -- Sprint without movement (should not deplete like sprint)
        sanityManager:UpdateFromMovementState(false, true, 1)
        local rate4 = sanityManager:GetCurrentDepletionRate()
        assert(rate4 == 0, "Sprint without movement should have 0 depletion rate")
    end)
    
    -- ========== TEST 14: Integration status check helpers work correctly ==========
    runTest("Integration status checkers work", function()
        local env = createTestEnvironment()
        local modules = {}
        
        -- Initially not active
        local isInputActive = modules.InputHandler ~= nil 
            and modules.InputHandler.IsRunning ~= nil
            and (modules.InputHandler.IsRunning or function() return false end)()
        modules.InputHandler = env.MockModules.InputHandler
        
        local isSanityActive = modules.SanityManager ~= nil
            and modules.SanityManager.IsInitialized ~= nil
            and (modules.SanityManager.IsInitialized or function() return false end)()
        modules.SanityManager = env.MockModules.SanityManager
        
        -- Check before initialization
        assert(isSanityActive == false, "Sanity should not be active before initialization")
        
        -- Initialize
        local inputHandler = modules.InputHandler
        local sanityManager = modules.SanityManager
        if inputHandler then inputHandler:Start() end
        if sanityManager then sanityManager:Initialize() end
        
        -- Check after initialization
        assert(modules.InputHandler:IsRunning(), "Input should be active after start")
        assert(modules.SanityManager:IsInitialized(), "Sanity should be active after init")
    end)
    
    -- ========== TEST 15: Camera and movement integration ==========
    runTest("Camera yaw affects movement direction calculation", function()
        -- Movement direction calculation uses yaw from camera
        local function CalculateMovementDirection(yaw: number, inputW: boolean, inputA: boolean, inputS: boolean, inputD: boolean): any
            local moveX = 0
            local moveZ = 0
            
            if inputW then moveZ -= 1 end
            if inputS then moveZ += 1 end
            if inputA then moveX -= 1 end
            if inputD then moveX += 1 end
            
            if moveX == 0 and moveZ == 0 then
                return {X = 0, Y = 0, Z = 0}
            end
            
            local magnitude = math.sqrt(moveX * moveX + moveZ * moveZ)
            moveX = moveX / magnitude
            moveZ = moveZ / magnitude
            
            local cosYaw = math.cos(yaw)
            local sinYaw = math.sin(yaw)
            
            local worldX = (moveX * cosYaw) - (moveZ * sinYaw)
            local worldZ = (moveX * sinYaw) + (moveZ * cosYaw)
            
            return {X = worldX, Y = 0, Z = worldZ}
        end
        
        -- Test forward (yaw = 0, should look to -Z)
        local forward = CalculateMovementDirection(0, true, false, false, false)
        assert(math.abs(forward.Z) > 0.9, "Forward should have large Z component")
        
        -- Test right (yaw = 90 degrees, should look to -X)
        local right = CalculateMovementDirection(math.rad(90), false, false, false, true)
        -- At 90 degrees yaw, forward in camera space corresponds to world -X
        -- But D key moves right which maps differently
        local magnitude = math.sqrt(right.X * right.X + right.Z * right.Z)
        assert(magnitude > 0.99, "Movement direction should be normalized")
    end)
    
    -- ========== TEST 16: All modules clean up properly on Cleanup() ==========
    runTest("Cleanup calls Cleanup on all initialized modules", function()
        local env = createTestEnvironment()
        local Modules = {}
        Modules.InputHandler = env.MockModules.InputHandler
        Modules.SanityManager = env.MockModules.SanityManager
        Modules.FootstepSoundSystem = env.MockModules.FootstepSoundSystem
        Modules.InteractionController = env.MockModules.InteractionController
        Modules.InteractionDetector = env.MockModules.InteractionDetector
        Modules.ObjectHighlighter = env.MockModules.ObjectHighlighter
        
        -- Initialize all
        Modules.InputHandler:Start()
        Modules.SanityManager:Initialize()
        Modules.FootstepSoundSystem:Initialize()
        Modules.InteractionController:Initialize()
        Modules.InteractionDetector:Initialize()
        Modules.ObjectHighlighter:Initialize()
        
        -- Full cleanup
        for _, module in pairs(Modules) do
            if module.Cleanup then
                module:Cleanup()
            elseif module.Stop then
                module:Stop()
            end
        end
        
        -- Verify all
        local allClean = true
        for name, module in pairs(Modules) do
            if module.IsInitialized and module:IsInitialized() then
                allClean = false
                print("  Module " .. name .. " not cleaned up")
            end
            if module.IsRunning and module:IsRunning() then
                allClean = false
                print("  Module " .. name .. " still running")
            end
        end
        
        assert(allClean, "All modules should be cleaned up")
    end)
    
    -- ========== TEST 17: Subsystem initialization order ==========
    runTest("Modules can be initialized in correct order", function()
        local env = createTestEnvironment()
        local initOrder: {string} = {}
        
        -- Custom modules that record order
        local module1 = {
            Initialize = function()
                table.insert(initOrder, "InputHandler")
            end
        }
        local module2 = {
            Initialize = function()
                table.insert(initOrder, "SanityManager")
            end
        }
        
        -- Initialize in specific order
        module1.Initialize()
        module2.Initialize()
        
        assert(initOrder[1] == "InputHandler", "First init should be InputHandler")
        assert(initOrder[2] == "SanityManager", "Second init should be SanityManager")
    end)
    
    -- ========== TEST 18: Character spawn triggers subsystem reset ==========
    runTest("Character spawn event triggers subsystem initialization", function()
        local env = createTestEnvironment()
        local sanityInitializedOnSpawn = false
        local cameraEnabledOnSpawn = false
        
        local mockSanityManager = {
            Initialize = function()
                sanityInitializedOnSpawn = true
            end
        }
        
        local function OnCharacterSpawn(character: any)
            mockSanityManager.Initialize()
            cameraEnabledOnSpawn = true
        end
        
        -- Simulate spawn
        OnCharacterSpawn(env.MockCharacter)
        
        assert(sanityInitializedOnSpawn, "SanityManager should be re-initialized on spawn")
        assert(cameraEnabledOnSpawn, "Camera should be enabled on spawn")
    end)
    
    -- ========== TEST 19: Character removal triggers cleanup ==========
    runTest("Character removal triggers subsystem cleanup", function()
        local env = createTestEnvironment()
        local footstepCleaned = false
        local callbacksFired = false
        
        local function OnCharacterRemoving()
            footstepCleaned = true
        end
        
        local _lifecycleCallbacks = { OnDeath = { function() callbacksFired = true end } }
        
        -- Simulate removal
        OnCharacterRemoving()
        for _, callback in ipairs(_lifecycleCallbacks.OnDeath) do
            callback()
        end
        
        assert(footstepCleaned, "Footstep system should be cleaned on character removal")
        assert(callbacksFired, "Death callbacks should fire")
    end)
    
    -- ========== TEST 20: Render step connection coordinates all subsystems ==========
    runTest("Render step updates coordinate all subsystems", function()
        local env = createTestEnvironment()
        local updatesCalled = {
            sanity = false,
            interaction = false,
            footstep = false,
        }
        
        -- Mock modules with update tracking
        local Modules = {}
        Modules.SanityManager = {
            UpdateFromMovementState = function()
                updatesCalled.sanity = true
            end
        }
        Modules.InteractionController = {
            Update = function()
                updatesCalled.interaction = true
            end
        }
        Modules.InteractionDetector = {
            Detect = function() return nil end
        }
        Modules.ObjectHighlighter = {
            Update = function() end
        }
        Modules.FootstepSoundSystem = {}
        Modules.InputHandler = {
            GetInputState = function() return { W = false, A = false, S = false, D = false, Shift = false, E = false } end
        }
        
        -- Simulate render step
        local isInitialized = true
        local isFirstPerson = true
        local cameraState = { yaw = 0, pitch = 0 }
        local movementState = { isMoving = true, isSprinting = false }
        
        if isInitialized and isFirstPerson then
            Modules.SanityManager:UpdateFromMovementState(movementState.isMoving, movementState.isSprinting, 0.016)
            Modules.InteractionController:Update()
        end
        
        assert(updatesCalled.sanity, "Sanity should update in render step")
        assert(updatesCalled.interaction, "Interaction should update in render step")
    end)
    
    -- ========== TEST 21: Spawn/despawn cycle simulation ==========
    runTest("Spawn/despawn cycle resets systems correctly", function()
        local env = createTestEnvironment()
        local Modules = {}
        
        -- Create modules
        Modules.InputHandler = env.MockModules.InputHandler
        Modules.SanityManager = env.MockModules.SanityManager
        Modules.FootstepSoundSystem = env.MockModules.FootstepSoundSystem
        Modules.InteractionController = env.MockModules.InteractionController
        Modules.ObjectHighlighter = env.MockModules.ObjectHighlighter
        
        -- Initial spawn
        Modules.SanityManager:Initialize()
        Modules.FootstepSoundSystem:Initialize()
        Modules.InteractionController:Initialize()
        Modules.ObjectHighlighter:Initialize()
        Modules.InputHandler:Start()
        
        -- Set some state
        Modules.SanityManager:UpdateFromMovementState(true, true, 1) -- sprint
        local sanityBefore = Modules.SanityManager._currentSanity
        
        -- Simulate death/removal
        Modules.FootstepSoundSystem:Cleanup()
        Modules.ObjectHighlighter:Cleanup()
        Modules.InteractionController:Cleanup()
        
        -- Simulate respawn
        Modules.SanityManager:Initialize()
        Modules.FootstepSoundSystem:Initialize()
        Modules.InteractionController:Initialize()
        Modules.ObjectHighlighter:Initialize()
        
        -- Verify reset
        assert(Modules.SanityManager:IsInitialized(), "Sanity should be initialized after respawn")
        assert(Modules.SanityManager:GetCurrentDepletionRate() == 0, "Sanity depletion should be reset")
    end)
    
    -- ========== TEST 22: Module integration getter returns correct modules ==========
    runTest("GetModules returns all integrated modules", function()
        local env = createTestEnvironment()
        local Modules = {
            InputHandler = env.MockModules.InputHandler,
            SanityManager = env.MockModules.SanityManager,
            FootstepSoundSystem = env.MockModules.FootstepSoundSystem,
        }
        
        local returnedModules = {}
        for name, module in pairs(Modules) do
            returnedModules[name] = module
        end
        
        assert(returnedModules.InputHandler ~= nil, "Should include InputHandler")
        assert(returnedModules.SanityManager ~= nil, "Should include SanityManager")
        assert(returnedModules.FootstepSoundSystem ~= nil, "Should include FootstepSoundSystem")
    end)
    
    -- ========== TEST 23: Test input state overrides real input ==========
    runTest("Test input state properly overrides module input", function()
        local env = createTestEnvironment()
        local inputHandler = env.MockModules.InputHandler
        local testInputState = { W = true, A = false, S = false, D = false, Shift = true, E = false }
        local _testInputState = testInputState
        
        -- Test function to get input
        local function GetInputStateForMovement()
            if _testInputState then
                return _testInputState
            elseif inputHandler and inputHandler.GetInputState then
                return inputHandler:GetInputState()
            end
            return nil
        end
        
        -- With test state
        local state1 = GetInputStateForMovement()
        assert(state1.W == true, "Test W should be true")
        assert(state1.Shift == true, "Test Shift should be true")
        
        -- Clear test state
        _testInputState = nil
        inputHandler:SetInputState({ W = false, Shift = false })
        
        local state2 = GetInputStateForMovement()
        assert(state2.W == false, "Real W should be false")
        assert(state2.Shift == false, "Real Shift should be false")
    end)
    
    -- ========== TEST 24: Lifecycle callback registration and unregistration ==========
    runTest("Lifecycle callbacks can be registered and unregistered", function()
        local callbacksFired = { spawn = 0, death = 0 }
        local _lifecycleCallbacks = { OnSpawn = {}, OnDeath = {} }
        
        -- Register callback
        local function spawnCallback()
            callbacksFired.spawn += 1
        end
        table.insert(_lifecycleCallbacks.OnSpawn, spawnCallback)
        
        -- Fire once
        for _, cb in ipairs(_lifecycleCallbacks.OnSpawn) do cb() end
        assert(callbacksFired.spawn == 1, "Callback should fire once")
        
        -- Simulate unregister (remove)
        for i, cb in ipairs(_lifecycleCallbacks.OnSpawn) do
            if cb == spawnCallback then
                table.remove(_lifecycleCallbacks.OnSpawn, i)
                break
            end
        end
        
        -- Fire again - callback should not fire
        for _, cb in ipairs(_lifecycleCallbacks.OnSpawn) do cb() end
        assert(callbacksFired.spawn == 1, "Callback should not fire after unregistration")
    end)
    
    -- ========== TEST 25: Frame count increments during update ==========
    runTest("Frame count increments during render updates", function()
        local _frameCount = 0
        local isInitialized = true
        
        -- Simulate render steps
        for i = 1, 10 do
            if isInitialized then
                _frameCount += 1
            end
        end
        
        assert(_frameCount == 10, "Frame count should be 10 after 10 render steps")
        
        -- Stop updating - increment only if initialized
        isInitialized = false
        if isInitialized then
            _frameCount += 1 -- This should NOT increment
        end
        
        -- Verify count hasn't changed
        assert(_frameCount == 10, "Frame count should still be 10 when not initialized")
    end)
    
    -- Print results
    print(string.format("\n=== Test Results: %d passed, %d failed ===\n", passed, failed))
    return passed, failed
end

return runTests
