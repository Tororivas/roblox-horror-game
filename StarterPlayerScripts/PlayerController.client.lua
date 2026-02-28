--!strict
--[[
    PlayerController Module
    Main player controller for the Roblox Horror Game.
    Integrates all subsystems: Camera, Movement, Input, Interaction, Sanity, Footsteps.
    Handles initialization, update loop, lifecycle management, and player respawn.
]]

-- ==================== TYPE DEFINITIONS ====================

export type CameraConfig = {
    fieldOfView: number,
    mouseSensitivity: number,
    maxLookUp: number,
    maxLookDown: number,
}

export type MovementConfig = {
    walkSpeed: number,
    sprintSpeed: number,
    footstepCooldown: number,
}

export type CameraState = {
    yaw: number,
    pitch: number,
    isFirstPerson: boolean,
}

export type MovementState = {
    isMoving: boolean,
    isSprinting: boolean,
    lastMoveDirection: any, -- Vector3
}

export type IntegratedModule = {
    -- InputHandler
    InputHandler: any?,
    -- Interaction systems
    InteractionController: any?,
    InteractionDetector: any?,
    ObjectHighlighter: any?,
    -- Audio/Sanity
    FootstepSoundSystem: any?,
    SanityManager: any?,
}

export type LifecycleCallbacks = {
    OnSpawn: { () -> () },
    OnRespawn: { () -> () },
    OnDeath: { () -> () },
    OnCleanup: { () -> () },
}

-- ==================== MODULE SETUP ====================

local PlayerController = {}

-- Module references (loaded during initialization)
local Modules: IntegratedModule = {
    InputHandler = nil,
    InteractionController = nil,
    InteractionDetector = nil,
    ObjectHighlighter = nil,
    FootstepSoundSystem = nil,
    SanityManager = nil,
}

-- ==================== CONSTANTS ====================

local RAD_TO_DEG: number = 180 / math.pi
local DEG_TO_RAD: number = math.pi / 180

local DEFAULT_CAMERA_CONFIG: CameraConfig = {
    fieldOfView = 70,
    mouseSensitivity = 0.002,
    maxLookUp = math.rad(80),
    maxLookDown = -math.rad(80),
}

local DEFAULT_MOVEMENT_CONFIG: MovementConfig = {
    walkSpeed = 16,
    sprintSpeed = 24,
    footstepCooldown = 0.35,
}

-- ==================== PRIVATE STATE ====================

local _isInitialized: boolean = false
local _isUpdateRunning: boolean = false

-- Camera state
local _cameraConfig: CameraConfig = DEFAULT_CAMERA_CONFIG
local _cameraState: CameraState = {
    yaw = 0,
    pitch = 0,
    isFirstPerson = false,
}

-- Movement state
local _movementConfig: MovementConfig = DEFAULT_MOVEMENT_CONFIG
local _movementState: MovementState = {
    isMoving = false,
    isSprinting = false,
    lastMoveDirection = {X = 0, Y = 0, Z = 0},
}

-- References
local _humanoid: any? = nil
local _character: any? = nil
local _player: any? = nil

-- Connection handles
local _renderStepConnection: any? = nil
local _inputChangedConnection: any? = nil
local _characterAddedConnection: any? = nil
local _characterRemovingConnection: any? = nil
local _humanoidRunningConnection: any? = nil

-- Lifecycle
local _lifecycleCallbacks: LifecycleCallbacks = {
    OnSpawn = {},
    OnRespawn = {},
    OnDeath = {},
    OnCleanup = {},
}

-- Test input state (for testing without InputHandler)
local _testInputState: any? = nil

-- Last frame state for interaction
local _lastInteractionTime: number = 0
local _INTERACTION_COOLDOWN: number = 0.3

-- ==================== SERVICE GETTERS ====================

-- Mock services for testing
local MockServices: {[string]: any} = {
    Camera = {
        CameraType = 0,
        FieldOfView = 70,
        CFrame = {
            Position = {X = 0, Y = 0, Z = 0},
            LookVector = {X = 0, Y = 0, Z = -1},
        },
    },
    UserInputService = {
        MouseIconEnabled = true,
        MouseBehavior = 0,
        InputChanged = {
            Connect = function(_self: any, _callback: any): any
                return { Disconnect = function() end }
            end,
        },
        _mouseDelta = {X = 0, Y = 0},
        GetMouseDelta = function(self: any): any
            return self._mouseDelta
        end,
        SetMouseBehavior = function(self: any, behavior: number)
            self.MouseBehavior = behavior
        end,
    },
    RunService = {
        RenderStepped = {
            Connect = function(_self: any, _callback: any): any
                return { Disconnect = function() end }
            end,
        },
    },
    Players = {
        LocalPlayer = nil,
    },
    Workspace = {
        Camera = nil,
        Raycast = function(_origin: any, _direction: any, _params: any?): any
            return nil
        end,
    },
}

local _realServices: {[string]: any} = {}

local function GetService(serviceName: string): any
    -- Return cached service if available
    if _realServices[serviceName] then
        return _realServices[serviceName]
    end
    
    -- Try to get real service
    local success, result = pcall(function()
        return (game :: any):GetService(serviceName)
    end)
    
    if success and result then
        _realServices[serviceName] = result
        return result
    end
    
    -- Return mock
    return MockServices[serviceName]
end

local function GetPlayers(): any
    return GetService("Players")
end

local function GetUserInputService(): any
    return GetService("UserInputService")
end

local function GetRunService(): any
    return GetService("RunService")
end

local function GetWorkspace(): any
    local success, result = pcall(function()
        return (workspace :: any)
    end)
    if success then
        return result
    end
    return MockServices.Workspace
end

-- ==================== MODULE LOADING ====================

local function LoadModule(moduleName: string): any?
    local ReplicatedStorage = GetService("ReplicatedStorage")
    if not ReplicatedStorage then
        return nil
    end
    
    local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    if not modulesFolder then
        return nil
    end
    
    local moduleScript = modulesFolder:FindFirstChild(moduleName)
    if not moduleScript then
        return nil
    end
    
    local success, result = pcall(function()
        return require(moduleScript)
    end)
    
    if success then
        return result
    end
    
    return nil
end

local function LoadAllModules(): ()
    Modules.InputHandler = LoadModule("InputHandler")
    Modules.InteractionController = LoadModule("InteractionController")
    Modules.InteractionDetector = LoadModule("InteractionDetector")
    Modules.ObjectHighlighter = LoadModule("ObjectHighlighter")
    Modules.FootstepSoundSystem = LoadModule("FootstepSoundSystem")
    Modules.SanityManager = LoadModule("SanityManager")
end

-- ==================== LIFECYCLE CALLBACKS ====================

function PlayerController.RegisterOnSpawn(callback: () -> ()): () -> ()
    table.insert(_lifecycleCallbacks.OnSpawn, callback)
    local index = #_lifecycleCallbacks.OnSpawn
    
    return function()
        table.remove(_lifecycleCallbacks.OnSpawn, index)
    end
end

function PlayerController.RegisterOnRespawn(callback: () -> ()): () -> ()
    table.insert(_lifecycleCallbacks.OnRespawn, callback)
    local index = #_lifecycleCallbacks.OnRespawn
    
    return function()
        table.remove(_lifecycleCallbacks.OnRespawn, index)
    end
end

function PlayerController.RegisterOnDeath(callback: () -> ()): () -> ()
    table.insert(_lifecycleCallbacks.OnDeath, callback)
    local index = #_lifecycleCallbacks.OnDeath
    
    return function()
        table.remove(_lifecycleCallbacks.OnDeath, index)
    end
end

function PlayerController.RegisterOnCleanup(callback: () -> ()): () -> ()
    table.insert(_lifecycleCallbacks.OnCleanup, callback)
    local index = #_lifecycleCallbacks.OnCleanup
    
    return function()
        table.remove(_lifecycleCallbacks.OnCleanup, index)
    end
end

local function FireCallbacks(callbackList: { () -> () })
    for _, callback in ipairs(callbackList) do
        local success, err = pcall(callback)
        if not success then
            print("Lifecycle callback error: " .. tostring(err))
        end
    end
end

-- ==================== CAMERA FUNCTIONS ====================

function PlayerController.CalculateCameraCFrame(headPosition: any): any
    local pitchRotation: number = math.clamp(
        _cameraState.pitch,
        _cameraConfig.maxLookDown,
        _cameraConfig.maxLookUp
    )
    
    local cosPitch: number = math.cos(pitchRotation)
    local sinPitch: number = math.sin(pitchRotation)
    local cosYaw: number = math.cos(_cameraState.yaw)
    local sinYaw: number = math.sin(_cameraState.yaw)
    
    local lookX: number = -sinYaw * cosPitch
    local lookY: number = sinPitch
    local lookZ: number = -cosYaw * cosPitch
    
    return {
        Position = headPosition or {X = 0, Y = 0, Z = 0},
        LookVector = {X = lookX, Y = lookY, Z = lookZ},
    }
end

function PlayerController.SetCameraRotation(yawDegrees: number, pitchDegrees: number): ()
    _cameraState.yaw = yawDegrees * DEG_TO_RAD
    _cameraState.pitch = pitchDegrees * DEG_TO_RAD
end

function PlayerController.GetCameraRotation(): (number, number)
    local yawDegrees: number = _cameraState.yaw * RAD_TO_DEG
    local pitchDegrees: number = _cameraState.pitch * RAD_TO_DEG
    return yawDegrees, pitchDegrees
end

function PlayerController.GetCameraState(): CameraState
    return {
        yaw = _cameraState.yaw,
        pitch = _cameraState.pitch,
        isFirstPerson = _cameraState.isFirstPerson,
    }
end

function PlayerController.UpdateCamera(deltaX: number, deltaY: number): ()
    local sensitivity: number = _cameraConfig.mouseSensitivity
    _cameraState.yaw += deltaX * sensitivity
    _cameraState.pitch -= deltaY * sensitivity
    _cameraState.pitch = math.clamp(
        _cameraState.pitch,
        _cameraConfig.maxLookDown,
        _cameraConfig.maxLookUp
    )
end

function PlayerController.LockMouse(): ()
    local userInput = GetUserInputService()
    if userInput and userInput.SetMouseBehavior then
        userInput:SetMouseBehavior(1) -- LockCenter
        userInput.MouseIconEnabled = false
    end
end

function PlayerController.UnlockMouse(): ()
    local userInput = GetUserInputService()
    if userInput and userInput.SetMouseBehavior then
        userInput:SetMouseBehavior(0) -- Default
        userInput.MouseIconEnabled = true
    end
end

function PlayerController.EnableFirstPerson(): ()
    local workspaceService = GetWorkspace()
    if workspaceService then
        local camera = workspaceService:FindFirstChild("Camera")
        if camera then
            camera.CameraType = 0 -- Custom
            camera.FieldOfView = _cameraConfig.fieldOfView
        end
    end
    
    PlayerController.LockMouse()
    _cameraState.isFirstPerson = true
end

function PlayerController.DisableFirstPerson(): ()
    PlayerController.UnlockMouse()
    _cameraState.isFirstPerson = false
end

-- ==================== MOVEMENT FUNCTIONS ====================

function PlayerController.CalculateMovementDirection(yaw: number): any
    -- Get input state
    local inputState = PlayerController.GetInputStateForMovement()
    if not inputState then
        _movementState.isMoving = false
        _movementState.isSprinting = false
        return {X = 0, Y = 0, Z = 0}
    end
    
    -- Calculate local movement
    local moveX = 0 -- Left/right (A/D)
    local moveZ = 0 -- Forward/back (W/S)
    
    if inputState.W then moveZ -= 1 end
    if inputState.S then moveZ += 1 end
    if inputState.A then moveX -= 1 end
    if inputState.D then moveX += 1 end
    
    -- Check if moving via WASD
    local isMovingWASD = (moveX ~= 0 or moveZ ~= 0)
    _movementState.isSprinting = (inputState.Shift and isMovingWASD) or false
    _movementState.isMoving = isMovingWASD
    
    if not isMovingWASD then
        _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
        return {X = 0, Y = 0, Z = 0}
    end
    
    -- Normalize
    local magnitude = math.sqrt(moveX * moveX + moveZ * moveZ)
    moveX = moveX / magnitude
    moveZ = moveZ / magnitude
    
    -- Convert to world space
    local cosYaw = math.cos(yaw)
    local sinYaw = math.sin(yaw)
    
    local worldDirection = {
        X = (moveX * cosYaw) - (moveZ * sinYaw),
        Y = 0,
        Z = (moveX * sinYaw) + (moveZ * cosYaw),
    }
    
    _movementState.lastMoveDirection = worldDirection
    return worldDirection
end

function PlayerController.GetMovementState(): MovementState
    return {
        isMoving = _movementState.isMoving,
        isSprinting = _movementState.isSprinting,
        lastMoveDirection = _movementState.lastMoveDirection,
    }
end

function PlayerController.IsSprinting(): boolean
    return _movementState.isSprinting
end

function PlayerController.IsMoving(): boolean
    return _movementState.isMoving
end

-- ==================== INPUT HANDLING ====================

function PlayerController.SetTestInputState(inputState: any?): ()
    _testInputState = inputState
end

function PlayerController.ClearTestInputState(): ()
    _testInputState = nil
end

function PlayerController.GetInputStateForMovement(): any?
    if _testInputState then
        return _testInputState
    end
    
    if Modules.InputHandler and Modules.InputHandler.GetInputState then
        return Modules.InputHandler.GetInputState()
    end
    
    return nil
end

local function OnInputChanged(inputObject: any, gameProcessedEvent: boolean): ()
    if gameProcessedEvent then
        return
    end
    
    local userInputType = inputObject.UserInputType
    if userInputType then
        local typeName: string? = nil
        if type(userInputType) == "table" and userInputType.Name then
            typeName = userInputType.Name
        elseif type(userInputType) == "string" then
            typeName = userInputType
        end
        
        if typeName == "MouseMovement" then
            local delta = inputObject.Delta
            if delta then
                PlayerController.UpdateCamera(delta.X, delta.Y)
            end
        end
    end
end

-- ==================== UPDATE LOOP ====================

local _lastRenderTime: number = 0
local _frameCount: number = 0

local function OnRenderStep(): ()
    if not _isInitialized then
        return
    end
    
    local currentTime = tick and tick() or os.clock()
    local deltaTime = currentTime - _lastRenderTime
    _lastRenderTime = currentTime
    _frameCount += 1
    
    -- Only run when in first-person
    if not _cameraState.isFirstPerson then
        return
    end
    
    local players = GetPlayers()
    if not players or not players.LocalPlayer then
        return
    end
    
    local character = players.LocalPlayer.Character
    if not character then
        return
    end
    
    -- Update Humanoid reference
    if not _humanoid then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            _humanoid = humanoid
            -- Connect to Running event if not done
            if not _humanoidRunningConnection then
                _humanoidRunningConnection = humanoid.Running:Connect(function(speed: number)
                    -- Update footstep sounds
                    if Modules.FootstepSoundSystem and Modules.FootstepSoundSystem.Update then
                        Modules.FootstepSoundSystem.Update(speed, _movementState.isSprinting)
                    end
                end)
            end
        end
    end
    
    -- Handle camera
    local workspaceService = GetWorkspace()
    if workspaceService then
        local camera = workspaceService:FindFirstChild("Camera")
        if camera then
            local head = character:FindFirstChild("Head")
            if head then
                local cameraCFrame = PlayerController.CalculateCameraCFrame(head.Position)
                camera.CFrame = cameraCFrame
            end
        end
    end
    
    -- Handle movement
    local moveDirection = PlayerController.CalculateMovementDirection(_cameraState.yaw)
    
    if _humanoid then
        -- Update walk speed based on sprint
        if _movementState.isSprinting then
            _humanoid.WalkSpeed = _movementConfig.sprintSpeed
        else
            _humanoid.WalkSpeed = _movementConfig.walkSpeed
        end
        
        -- Apply movement
        _humanoid:Move(moveDirection)
    end
    
    -- Update Sanity (with sprint affecting depletion)
    if Modules.SanityManager and Modules.SanityManager.UpdateFromMovementState then
        Modules.SanityManager.UpdateFromMovementState(
            _movementState.isMoving,
            _movementState.isSprinting,
            deltaTime
        )
    end
    
    -- Update Interaction Detection and Highlighting
    if Modules.InteractionDetector and Modules.InteractionDetector.Detect then
        local detectionResult = Modules.InteractionDetector.Detect()
        
        if Modules.ObjectHighlighter and Modules.ObjectHighlighter.Update then
            Modules.ObjectHighlighter.Update(detectionResult)
        end
    end
    
    -- Update Interaction Controller (cooldowns, etc.)
    if Modules.InteractionController and Modules.InteractionController.Update then
        Modules.InteractionController.Update()
    end
end

-- ==================== CHARACTER LIFECYCLE ====================

local function ResetCameraState(): ()
    _cameraState.yaw = 0
    _cameraState.pitch = 0
end

local function ResetMovementState(): ()
    _movementState.isMoving = false
    _movementState.isSprinting = false
    _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
end

local function ResetInteractionState(): ()
    _lastInteractionTime = 0
    if Modules.ObjectHighlighter and Modules.ObjectHighlighter.Cleanup then
        Modules.ObjectHighlighter.Cleanup()
    end
    if Modules.ObjectHighlighter and Modules.ObjectHighlighter.Initialize then
        Modules.ObjectHighlighter.Initialize()
    end
end

local function ResetFootstepState(): ()
    if Modules.FootstepSoundSystem and Modules.FootstepSoundSystem.Cleanup then
        Modules.FootstepSoundSystem.Cleanup()
    end
end

local function OnCharacterSpawn(character: any): ()
    _character = character
    _humanoid = nil
    
    -- Reset subsystem states
    ResetCameraState()
    ResetMovementState()
    ResetInteractionState()
    
    -- Re-initialize systems that need character
    if Modules.SanityManager and Modules.SanityManager.Initialize then
        Modules.SanityManager.Initialize()
    end
    
    -- Re-enable first-person mode
    PlayerController.EnableFirstPerson()
    
    -- Fire spawn callbacks
    FireCallbacks(_lifecycleCallbacks.OnSpawn)
end

local function OnCharacterRemoving(): ()
    FireCallbacks(_lifecycleCallbacks.OnDeath)
    
    -- Clean up connections
    if _humanoidRunningConnection then
        _humanoidRunningConnection:Disconnect()
        _humanoidRunningConnection = nil
    end
    
    -- Reset states
    _character = nil
    _humanoid = nil
    
    ResetFootstepState()
    
    -- Fire respawn preparation callbacks
    FireCallbacks(_lifecycleCallbacks.OnRespawn)
end

-- ==================== INITIALIZATION ====================

function PlayerController.Initialize(): ()
    if _isInitialized then
        return
    end
    
    -- Load all modules
    LoadAllModules()
    
    -- Initialize InputHandler
    if Modules.InputHandler and Modules.InputHandler.Start then
        Modules.InputHandler.Start()
    end
    
    -- Initialize Interaction systems
    if Modules.InteractionController and Modules.InteractionController.Initialize then
        Modules.InteractionController.Initialize(
            Modules.InputHandler,
            Modules.InteractionDetector,
            Modules.ObjectHighlighter
        )
    end
    
    if Modules.InteractionDetector and Modules.InteractionDetector.Initialize then
        Modules.InteractionDetector.Initialize()
    end
    
    if Modules.ObjectHighlighter and Modules.ObjectHighlighter.Initialize then
        Modules.ObjectHighlighter.Initialize()
    end
    
    -- Initialize FootstepSoundSystem
    if Modules.FootstepSoundSystem and Modules.FootstepSoundSystem.Initialize then
        Modules.FootstepSoundSystem.Initialize()
    end
    
    -- Initialize SanityManager
    if Modules.SanityManager and Modules.SanityManager.Initialize then
        Modules.SanityManager.Initialize()
    end
    
    -- Connect input
    local userInput = GetUserInputService()
    if userInput and userInput.InputChanged then
        _inputChangedConnection = userInput.InputChanged:Connect(OnInputChanged)
    end
    
    -- Connect render stepped
    local runService = GetRunService()
    if runService and runService.RenderStepped then
        _renderStepConnection = runService.RenderStepped:Connect(OnRenderStep)
    end
    
    -- Connect character lifecycle
    local players = GetPlayers()
    if players then
        _player = players.LocalPlayer
        if _player then
            -- Connect to character events
            _characterAddedConnection = _player.CharacterAdded:Connect(OnCharacterSpawn)
            _characterRemovingConnection = _player.CharacterRemoving:Connect(OnCharacterRemoving)
            
            -- Initialize if character already exists
            if _player.Character then
                OnCharacterSpawn(_player.Character)
            end
        end
    end
    
    -- Enable first-person mode
    PlayerController.EnableFirstPerson()
    
    _isInitialized = true
    _isUpdateRunning = true
    _lastRenderTime = tick and tick() or os.clock()
end

function PlayerController.IsInitialized(): boolean
    return _isInitialized
end

-- ==================== CLEANUP ====================

function PlayerController.Cleanup(): ()
    if not _isInitialized then
        return
    end
    
    -- Fire cleanup callbacks
    FireCallbacks(_lifecycleCallbacks.OnCleanup)
    
    -- Disable first-person
    PlayerController.DisableFirstPerson()
    
    -- Stop InputHandler
    if Modules.InputHandler and Modules.InputHandler.Stop then
        Modules.InputHandler.Stop()
    end
    
    -- Cleanup all subsystems
    if Modules.InteractionController and Modules.InteractionController.Cleanup then
        Modules.InteractionController.Cleanup()
    end
    
    if Modules.InteractionDetector and Modules.InteractionDetector.Cleanup then
        Modules.InteractionDetector.Cleanup()
    end
    
    if Modules.ObjectHighlighter and Modules.ObjectHighlighter.Cleanup then
        Modules.ObjectHighlighter.Cleanup()
    end
    
    if Modules.FootstepSoundSystem and Modules.FootstepSoundSystem.Cleanup then
        Modules.FootstepSoundSystem.Cleanup()
    end
    
    if Modules.SanityManager and Modules.SanityManager.Cleanup then
        Modules.SanityManager.Cleanup()
    end
    
    -- Disconnect all connections
    if _renderStepConnection then
        _renderStepConnection:Disconnect()
        _renderStepConnection = nil
    end
    
    if _inputChangedConnection then
        _inputChangedConnection:Disconnect()
        _inputChangedConnection = nil
    end
    
    if _characterAddedConnection then
        _characterAddedConnection:Disconnect()
        _characterAddedConnection = nil
    end
    
    if _characterRemovingConnection then
        _characterRemovingConnection:Disconnect()
        _characterRemovingConnection = nil
    end
    
    if _humanoidRunningConnection then
        _humanoidRunningConnection:Disconnect()
        _humanoidRunningConnection = nil
    end
    
    -- Reset state
    _isInitialized = false
    _isUpdateRunning = false
    _player = nil
    _character = nil
    _humanoid = nil
    
    ResetCameraState()
    ResetMovementState()
    ResetInteractionState()
    
    -- Clear modules
    Modules.InputHandler = nil
    Modules.InteractionController = nil
    Modules.InteractionDetector = nil
    Modules.ObjectHighlighter = nil
    Modules.FootstepSoundSystem = nil
    Modules.SanityManager = nil
end

-- ==================== GETTERS FOR TESTING ====================

function PlayerController.GetModules(): IntegratedModule
    return {
        InputHandler = Modules.InputHandler,
        InteractionController = Modules.InteractionController,
        InteractionDetector = Modules.InteractionDetector,
        ObjectHighlighter = Modules.ObjectHighlighter,
        FootstepSoundSystem = Modules.FootstepSoundSystem,
        SanityManager = Modules.SanityManager,
    }
end

function PlayerController.GetCharacter(): any?
    return _character
end

function PlayerController.GetHumanoid(): any?
    return _humanoid
end

function PlayerController.GetPlayer(): any?
    return _player
end

function PlayerController.GetConnections(): {[string]: any?}
    return {
        renderStep = _renderStepConnection,
        inputChanged = _inputChangedConnection,
        characterAdded = _characterAddedConnection,
        characterRemoving = _characterRemovingConnection,
        humanoidRunning = _humanoidRunningConnection,
    }
end

function PlayerController.GetFrameCount(): number
    return _frameCount
end

-- ==================== MOCK SETTERS FOR TESTING ====================

function PlayerController.SetMockModule(moduleName: string, mockModule: any): ()
    if Modules[moduleName] then
        Modules[moduleName] = mockModule
    end
end

function PlayerController.SetMockCharacter(character: any?): ()
    _character = character
end

function PlayerController.SetMockHumanoid(humanoid: any?): ()
    _humanoid = humanoid
end

function PlayerController.SetMockPlayer(player: any?): ()
    _player = player
end

function PlayerController.SetMockService(serviceName: string, mockService: any): ()
    MockServices[serviceName] = mockService
end

-- ==================== INTEGRATION HELPERS ====================

function PlayerController.IsInputHandlerConnected(): boolean
    return Modules.InputHandler ~= nil and Modules.InputHandler.IsRunning ~= nil and Modules.InputHandler.IsRunning()
end

function PlayerController.IsInteractionSystemActive(): boolean
    local controllerActive = Modules.InteractionController ~= nil 
        and Modules.InteractionController.IsInitialized ~= nil
        and Modules.InteractionController.IsInitialized()
    
    local detectorActive = Modules.InteractionDetector ~= nil
    
    local highlighterActive = Modules.ObjectHighlighter ~= nil
    
    return controllerActive and detectorActive and highlighterActive
end

function PlayerController.IsSanitySystemActive(): boolean
    return Modules.SanityManager ~= nil 
        and Modules.SanityManager.IsInitialized ~= nil
        and Modules.SanityManager.IsInitialized()
end

function PlayerController.IsFootstepSystemActive(): boolean
    return Modules.FootstepSoundSystem ~= nil
        and Modules.FootstepSoundSystem.IsInitialized ~= nil
        and Modules.FootstepSoundSystem.IsInitialized()
end

return PlayerController
