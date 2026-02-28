--!strict
--[[
    PlayerController Module
    First-person camera controller for the Roblox Horror Game.
    Handles camera rotation, mouse look, cursor locking, and WASD movement.
    This is a client script that runs when the player spawns.
]]

-- Import shared types and modules for type checking
local ReplicatedStorage: any = nil
local TypesModule: any = nil
local Types: any = nil
local InputHandler: any = nil

-- Safely get ReplicatedStorage
local success, result = pcall(function()
    return (game :: any):GetService("ReplicatedStorage")
end)
if success then
    ReplicatedStorage = result
end

-- Require modules if available
if ReplicatedStorage then
    local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    if modulesFolder then
        local typesModule = modulesFolder:FindFirstChild("Types")
        local inputModule = modulesFolder:FindFirstChild("InputHandler")
        
        if typesModule then
            local ok, mod = pcall(require, typesModule)
            if ok then
                Types = mod
            end
        end
        
        if inputModule then
            local ok, mod = pcall(require, inputModule)
            if ok then
                InputHandler = mod
            end
        end
    end
end

-- Type definitions for camera configuration
export type CameraConfig = {
    fieldOfView: number,
    mouseSensitivity: number,
    maxLookUp: number,
    maxLookDown: number,
}

-- Movement configuration
export type MovementConfig = {
    walkSpeed: number,
    sprintSpeed: number,
    footstepCooldown: number,
}

-- Camera state
export type CameraState = {
    yaw: number,        -- Horizontal rotation (left/right)
    pitch: number,      -- Vertical rotation (up/down)
    isFirstPerson: boolean,
}

-- Movement state
export type MovementState = {
    isMoving: boolean,
    isSprinting: boolean,
    lastMoveDirection: any, -- Vector3
}

-- Default camera configuration
local DEFAULT_CAMERA_CONFIG: CameraConfig = {
    fieldOfView = 70,
    mouseSensitivity = 0.002,
    maxLookUp = math.rad(80),    -- 80 degrees up
    maxLookDown = -math.rad(80), -- 80 degrees down
}

-- Default movement configuration
local DEFAULT_MOVEMENT_CONFIG: MovementConfig = {
    walkSpeed = 16,
    sprintSpeed = 24,
    footstepCooldown = 0.5,
}

-- Constants
local RAD_TO_DEG: number = 180 / math.pi
local DEG_TO_RAD: number = math.pi / 180

-- Module table
local PlayerController = {}

-- Private state
local _camera: any? = nil
local _userInputService: any? = nil
local _runService: any? = nil
local _playersService: any? = nil
local _isInitialized: boolean = false
local _isUpdateRunning: boolean = false

-- Camera state
local _cameraState: CameraState = {
    yaw = 0,
    pitch = 0,
    isFirstPerson = false,
}

-- Camera configuration
local _cameraConfig: CameraConfig = DEFAULT_CAMERA_CONFIG

-- Movement state
local _movementState: MovementState = {
    isMoving = false,
    isSprinting = false,
    lastMoveDirection = {X = 0, Y = 0, Z = 0},
}

-- Movement configuration
local _movementConfig: MovementConfig = DEFAULT_MOVEMENT_CONFIG

-- Humanoid reference for movement
local _humanoid: any? = nil

-- Mock services for testing environment
local MockCamera: any = {
    CameraType = 0,
    FieldOfView = 70,
    CFrame = {
        Position = {X = 0, Y = 0, Z = 0},
        LookVector = {X = 0, Y = 0, Z = -1},
    },
}

-- Forward declare MockUserInputService so it can reference itself
local MockUserInputService: any = nil

-- Initialize MockUserInputService after declaration
MockUserInputService = {
    MouseIconEnabled = true,
    MouseDeltaSensitivity = 1,
    
    InputChanged = {
        Connect = function(_self: any, _callback: any): any
            return { Disconnect = function() end }
        end,
    },
    
    -- Mouse delta tracking for testing
    _mouseDelta = {X = 0, Y = 0},
    
    GetMouseDelta = function(_self: any): any
        return MockUserInputService._mouseDelta
    end,
    
    -- Update cursor state
    SetMouseBehavior = function(_self: any, behavior: number)
        -- 1 = LockCenter
        MockUserInputService.MouseBehavior = behavior
    end,
    
    MouseBehavior = 0, -- Default
}

local MockRunService: any = {
    RenderStepped = {
        Connect = function(_self: any, _callback: any): any
            return { Disconnect = function() end }
        end,
    },
}

local MockPlayers: any = {
    LocalPlayer = {
        Character = nil,
    },
}

-- Forward declare MockHumanoid for testing
local MockHumanoid: any = nil

-- Define MockHumanoid after forward declaration
MockHumanoid = {
    MoveDirection = {X = 0, Y = 0, Z = 0},
    WalkSpeed = 16,
    
    Move = function(_self: any, direction: any)
        MockHumanoid.MoveDirection = direction
    end,
    
    GetMoveDirection = function(_self: any): any
        return MockHumanoid.MoveDirection
    end,
    
    GetWalkSpeed = function(_self: any): number
        return MockHumanoid.WalkSpeed
    end,
    
    SetWalkSpeed = function(_self: any, speed: number)
        MockHumanoid.WalkSpeed = speed
    end,
}

-- Get real services or use mocks
local function GetServices(): (any, any, any, any)
    local camera = _camera
    local userInput = _userInputService
    local runService = _runService
    local players = _playersService
    
    -- Try to get real services
    if camera == nil then
        local success: boolean, result: any = pcall(function()
            return (workspace :: any):FindFirstChild("Camera")
        end)
        if success and result then
            camera = result
        end
    end
    
    if userInput == nil then
        local success: boolean, result: any = pcall(function()
            return (game :: any):GetService("UserInputService")
        end)
        if success then
            userInput = result
        end
    end
    
    if runService == nil then
        local success: boolean, result: any = pcall(function()
            return (game :: any):GetService("RunService")
        end)
        if success then
            runService = result
        end
    end
    
    if players == nil then
        local success: boolean, result: any = pcall(function()
            return (game :: any):GetService("Players")
        end)
        if success then
            players = result
        end
    end
    
    -- Use mocks if services not available
    return 
        camera or MockCamera,
        userInput or MockUserInputService,
        runService or MockRunService,
        players or MockPlayers
end

-- Calculate camera rotation from yaw and pitch
-- Returns a CFrame that can be applied to the camera
function PlayerController.CalculateCameraCFrame(headPosition: any): any
    -- Create rotation angles (using Euler angles)
    local yawRotation: number = _cameraState.yaw
    local pitchRotation: number = math.clamp(_cameraState.pitch, _cameraConfig.maxLookDown, _cameraConfig.maxLookUp)
    
    -- Calculate look direction
    local cosPitch: number = math.cos(pitchRotation)
    local sinPitch: number = math.sin(pitchRotation)
    local cosYaw: number = math.cos(yawRotation)
    local sinYaw: number = math.sin(yawRotation)
    
    -- Calculate look vector (forward direction)
    local lookX: number = -sinYaw * cosPitch
    local lookY: number = sinPitch
    local lookZ: number = -cosYaw * cosPitch
    
    -- Return rotation as a table with Position and LookVector
    -- In real Roblox, this would be a proper CFrame
    return {
        Position = headPosition or {X = 0, Y = 0, Z = 0},
        LookVector = {
            X = lookX,
            Y = lookY,
            Z = lookZ,
        },
    }
end

-- Convert rotation angles from degrees
function PlayerController.SetCameraRotation(yawDegrees: number, pitchDegrees: number): ()
    _cameraState.yaw = yawDegrees * DEG_TO_RAD
    _cameraState.pitch = pitchDegrees * DEG_TO_RAD
end

-- Get current camera rotation in degrees
function PlayerController.GetCameraRotation(): (number, number)
    local yawDegrees: number = _cameraState.yaw * RAD_TO_DEG
    local pitchDegrees: number = _cameraState.pitch * RAD_TO_DEG
    return yawDegrees, pitchDegrees
end

-- Get current camera state
function PlayerController.GetCameraState(): CameraState
    return {
        yaw = _cameraState.yaw,
        pitch = _cameraState.pitch,
        isFirstPerson = _cameraState.isFirstPerson,
    }
end

-- Get camera configuration
function PlayerController.GetCameraConfig(): CameraConfig
    return {
        fieldOfView = _cameraConfig.fieldOfView,
        mouseSensitivity = _cameraConfig.mouseSensitivity,
        maxLookUp = _cameraConfig.maxLookUp,
        maxLookDown = _cameraConfig.maxLookDown,
    }
end

-- Set camera configuration
function PlayerController.SetCameraConfig(config: CameraConfig): ()
    _cameraConfig = {
        fieldOfView = config.fieldOfView or DEFAULT_CAMERA_CONFIG.fieldOfView,
        mouseSensitivity = config.mouseSensitivity or DEFAULT_CAMERA_CONFIG.mouseSensitivity,
        maxLookUp = config.maxLookUp or DEFAULT_CAMERA_CONFIG.maxLookUp,
        maxLookDown = config.maxLookDown or DEFAULT_CAMERA_CONFIG.maxLookDown,
    }
end

-- Convert radians to degrees helper
function PlayerController.RadToDeg(rad: number): number
    return rad * RAD_TO_DEG
end

-- Convert degrees to radians helper
function PlayerController.DegToRad(deg: number): number
    return deg * DEG_TO_RAD
end

-- Update camera rotation based on mouse delta
function PlayerController.UpdateCamera(deltaX: number, deltaY: number): ()
    local sensitivity: number = _cameraConfig.mouseSensitivity
    
    -- Update yaw (horizontal rotation) - unlimited
    _cameraState.yaw += deltaX * sensitivity
    
    -- Update pitch (vertical rotation) - clamped
    -- Subtract deltaY because mouse UP (negative deltaY) should pitch UP (positive)
    _cameraState.pitch -= deltaY * sensitivity
    
    -- Clamp pitch between maxLookDown and maxLookUp
    _cameraState.pitch = math.clamp(
        _cameraState.pitch,
        _cameraConfig.maxLookDown,
        _cameraConfig.maxLookUp
    )
end

-- Lock and hide the mouse cursor
function PlayerController.LockMouse(): ()
    local _camera, userInput, _run, _players = GetServices()
    
    if userInput then
        -- Set mouse behavior to LockCenter
        if userInput.SetMouseBehavior then
            -- 1 = Enum.MouseBehavior.LockCenter
            userInput:SetMouseBehavior(1)
        end
        
        -- Hide mouse icon
        if userInput.MouseIconEnabled ~= nil then
            userInput.MouseIconEnabled = false
        end
    end
end

-- Unlock and show the mouse cursor
function PlayerController.UnlockMouse(): ()
    local _camera, userInput, _run, _players = GetServices()
    
    if userInput then
        -- Set mouse behavior to Default
        if userInput.SetMouseBehavior then
            -- 0 = Enum.MouseBehavior.Default
            userInput:SetMouseBehavior(0)
        end
        
        -- Show mouse icon
        if userInput.MouseIconEnabled ~= nil then
            userInput.MouseIconEnabled = true
        end
    end
end

-- Get mouse lock state
function PlayerController.IsMouseLocked(): boolean
    local _camera, userInput, _run, _players = GetServices()
    
    if userInput then
        return userInput.MouseBehavior == 1 and userInput.MouseIconEnabled == false
    end
    
    return false
end

-- Enable first-person mode
function PlayerController.EnableFirstPerson(): ()
    local camera, userInput, _run, players = GetServices()
    
    -- Set camera to first-person
    if camera then
        -- Set CameraType to Custom (0 = Custom, 1 = Fixed, etc.)
        camera.CameraType = 0 -- Enum.CameraType.Custom
        camera.FieldOfView = _cameraConfig.fieldOfView
    end
    
    -- Lock and hide mouse
    PlayerController.LockMouse()
    
    _cameraState.isFirstPerson = true
end

-- Disable first-person mode
function PlayerController.DisableFirstPerson(): ()
    local camera, userInput, _run, players = GetServices()
    
    -- Unlock mouse
    PlayerController.UnlockMouse()
    
    _cameraState.isFirstPerson = false
end

-- Check if first-person mode is active
function PlayerController.IsFirstPerson(): boolean
    return _cameraState.isFirstPerson
end

-- ========== MOVEMENT FUNCTIONS ==========

-- Calculate world movement direction based on camera yaw and WASD input
-- Returns a normalized direction vector (no vertical component)
function PlayerController.CalculateMovementDirection(yaw: number): any
    -- Get input state from InputHandler or test state
    local inputState = PlayerController.GetInputStateForMovement()
    
    -- Calculate local movement direction from WASD
    local moveX = 0 -- Left/right (A/D)
    local moveZ = 0 -- Forward/back (W/S)
    
    if inputState then
        if inputState.W then
            moveZ -= 1
        end
        if inputState.S then
            moveZ += 1
        end
        if inputState.A then
            moveX -= 1
        end
        if inputState.D then
            moveX += 1
        end
        
        -- Track sprint state
        _movementState.isSprinting = inputState.Shift or false
    else
        -- No input handler and no test input, no movement
        _movementState.isMoving = false
        _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
        return {X = 0, Y = 0, Z = 0}
    end
    
    -- Normalize diagonal movement
    local magnitude = math.sqrt(moveX * moveX + moveZ * moveZ)
    if magnitude > 0 then
        local normalizedX = moveX / magnitude
        local normalizedZ = moveZ / magnitude
        _movementState.isMoving = true
        
        -- Update with normalized values
        moveX = normalizedX
        moveZ = normalizedZ
    else
        _movementState.isMoving = false
        _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
        return {X = 0, Y = 0, Z = 0}
    end
    
    -- Convert to world space based on camera yaw
    -- Yaw represents rotation around Y axis
    local cosYaw = math.cos(yaw)
    local sinYaw = math.sin(yaw)
    
    -- Transform local direction to world direction
    -- Forward/back (Z) affects X/Z based on yaw
    -- Left/right (X) affects X/Z perpendicular to forward
    local worldX = (moveX * cosYaw) - (moveZ * sinYaw)
    local worldZ = (moveX * sinYaw) + (moveZ * cosYaw)
    
    local worldDirection = {
        X = worldX,
        Y = 0,
        Z = worldZ,
    }
    
    _movementState.lastMoveDirection = worldDirection
    return worldDirection
end

-- Apply movement to character's Humanoid
function PlayerController.ApplyMovement(direction: any): ()
    if _humanoid then
        -- In Roblox, Humanoid:Move(directionVector) accepts a Vector3
        -- In our mock, we call the Move method
        _humanoid:Move(direction)
    end
end

-- Get current movement state
function PlayerController.GetMovementState(): MovementState
    return {
        isMoving = _movementState.isMoving,
        isSprinting = _movementState.isSprinting,
        lastMoveDirection = _movementState.lastMoveDirection,
    }
end

-- Get movement configuration
function PlayerController.GetMovementConfig(): MovementConfig
    return {
        walkSpeed = _movementConfig.walkSpeed,
        sprintSpeed = _movementConfig.sprintSpeed,
        footstepCooldown = _movementConfig.footstepCooldown,
    }
end

-- Set movement configuration
function PlayerController.SetMovementConfig(config: MovementConfig): ()
    _movementConfig = {
        walkSpeed = config.walkSpeed or DEFAULT_MOVEMENT_CONFIG.walkSpeed,
        sprintSpeed = config.sprintSpeed or DEFAULT_MOVEMENT_CONFIG.sprintSpeed,
        footstepCooldown = config.footstepCooldown or DEFAULT_MOVEMENT_CONFIG.footstepCooldown,
    }
end

-- Get current walk speed
function PlayerController.GetWalkSpeed(): number
    if _movementState.isSprinting then
        return _movementConfig.sprintSpeed
    else
        return _movementConfig.walkSpeed
    end
end

-- Check if currently sprinting
function PlayerController.IsSprinting(): boolean
    return _movementState.isSprinting
end

-- Check if currently moving
function PlayerController.IsMoving(): boolean
    return _movementState.isMoving
end

-- Get last calculated move direction
function PlayerController.GetMoveDirection(): any
    return _movementState.lastMoveDirection
end

-- ========== END MOVEMENT FUNCTIONS ==========

-- Handle input changed (mouse movement)
local function OnInputChanged(inputObject: any, gameProcessedEvent: boolean): ()
    if gameProcessedEvent then
        return
    end
    
    -- Check if this is mouse movement
    local userInputType = inputObject.UserInputType
    if userInputType then
        local typeName = nil
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

-- Update the camera and movement on render step
local function OnRenderStep(): ()
    if not _cameraState.isFirstPerson then
        return
    end
    
    local camera, userInput, _run, players = GetServices()
    
    if players and players.LocalPlayer then
        local character = players.LocalPlayer.Character
        if character then
            -- Update Humanoid reference
            if not _humanoid then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    _humanoid = humanoid
                    -- Wire up MockHumanoid in test environment
                    if _humanoid.Move == nil then
                        -- In test environment, swap with MockHumanoid
                        _humanoid = MockHumanoid
                    end
                end
            end
            
            -- Handle camera
            if camera then
                local head = character:FindFirstChild("Head")
                if head then
                    -- Calculate camera CFrame
                    local headPos = head.Position
                    local cameraCFrame = PlayerController.CalculateCameraCFrame(headPos)
                    
                    -- Apply to camera
                    if camera.CFrame and type(camera.CFrame) == "table" then
                        camera.CFrame = cameraCFrame
                    end
                end
            end
            
            -- Handle movement - calculate direction from camera yaw
            local moveDirection = PlayerController.CalculateMovementDirection(_cameraState.yaw)
            
            -- Update walk speed based on sprint state
            if _humanoid and _humanoid.WalkSpeed ~= nil then
                if _movementState.isSprinting then
                    _humanoid.WalkSpeed = _movementConfig.sprintSpeed
                else
                    _humanoid.WalkSpeed = _movementConfig.walkSpeed
                end
            end
            
            -- Apply movement to Humanoid
            if _humanoid then
                PlayerController.ApplyMovement(moveDirection)
            end
        end
    end
end

-- Initialize the controller
function PlayerController.Initialize(): ()
    if _isInitialized then
        return
    end
    
    -- Get services
    local _camera, userInput, runService, _players = GetServices()
    
    -- Start InputHandler for WASD input
    if InputHandler then
        InputHandler.Start()
    end
    
    -- Connect input changed for mouse movement
    if userInput then
        userInput.InputChanged:Connect(OnInputChanged)
    end
    
    -- Connect render stepped for camera and movement updates
    if runService then
        runService.RenderStepped:Connect(OnRenderStep)
    end
    
    -- Enable first-person mode
    PlayerController.EnableFirstPerson()
    
    _isInitialized = true
end

-- Check if initialized
function PlayerController.IsInitialized(): boolean
    return _isInitialized
end

-- Cleanup the controller
function PlayerController.Cleanup(): ()
    -- Stop InputHandler
    if InputHandler then
        InputHandler.Stop()
    end
    
    PlayerController.DisableFirstPerson()
    _isInitialized = false
    _cameraState.yaw = 0
    _cameraState.pitch = 0
    _cameraState.isFirstPerson = false
    
    -- Reset movement state
    _movementState.isMoving = false
    _movementState.isSprinting = false
    _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
    _humanoid = nil
end

-- Set a mock humanoid for testing
function PlayerController.SetMockHumanoid(humanoid: any): ()
    _humanoid = humanoid or MockHumanoid
end

-- Set a mock InputHandler for testing
function PlayerController.SetMockInputHandler(inputHandler: any): ()
    InputHandler = inputHandler
end

-- Get MockHumanoid reference (for test assertion)
function PlayerController.GetMockHumanoid(): any
    return MockHumanoid
end

-- Get MockHumanoid's current move direction (for testing)
function PlayerController.GetMockMoveDirection(): any
    return MockHumanoid.MoveDirection
end

-- Reset MockHumanoid state (for testing)
function PlayerController.ResetMockHumanoid(): ()
    MockHumanoid.MoveDirection = {X = 0, Y = 0, Z = 0}
    MockHumanoid.WalkSpeed = 16
end

-- Internal: Set InputState directly for testing
-- This allows tests to control movement without needing InputHandler
local _testInputState: any = nil

function PlayerController.SetTestInputState(inputState: any): ()
    _testInputState = inputState
end

function PlayerController.ClearTestInputState(): ()
    _testInputState = nil
end

-- Get input state (using test state if set, otherwise InputHandler)
function PlayerController.GetInputStateForMovement(): any
    if _testInputState then
        return _testInputState
    elseif InputHandler then
        return InputHandler.GetInputState()
    else
        return nil
    end
end

-- Modify CalculateMovementDirection to use test input state
-- (Need to update the function to use GetInputStateForMovement)

-- Re-define CalculateMovementDirection with test input support
-- (The actual function is defined elsewhere in the module)

return PlayerController
