--!strict
--[[
    PlayerController Module
    First-person camera controller for the Roblox Horror Game.
    Handles camera rotation, mouse look, and cursor locking.
    This is a client script that runs when the player spawns.
]]

-- Import shared types for type checking
local ReplicatedStorage: any = game:FindFirstChild("ReplicatedStorage")
local TypesModule: any = nil
local Types: any = nil

if ReplicatedStorage then
    TypesModule = ReplicatedStorage:FindFirstChild("Modules")
    if TypesModule then
        Types = require(TypesModule:FindFirstChild("Types"))
    end
end

-- Type definitions for camera configuration
export type CameraConfig = {
    fieldOfView: number,
    mouseSensitivity: number,
    maxLookUp: number,
    maxLookDown: number,
}

-- Camera state
export type CameraState = {
    yaw: number,        -- Horizontal rotation (left/right)
    pitch: number,      -- Vertical rotation (up/down)
    isFirstPerson: boolean,
}

-- Default camera configuration
local DEFAULT_CAMERA_CONFIG: CameraConfig = {
    fieldOfView = 70,
    mouseSensitivity = 0.002,
    maxLookUp = math.rad(80),    -- 80 degrees up
    maxLookDown = -math.rad(80), -- 80 degrees down
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

-- Update the camera on render step
local function OnRenderStep(): ()
    if not _cameraState.isFirstPerson then
        return
    end
    
    local camera, userInput, _run, players = GetServices()
    
    if camera and players and players.LocalPlayer then
        local character = players.LocalPlayer.Character
        if character then
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
    end
end

-- Initialize the controller
function PlayerController.Initialize(): ()
    if _isInitialized then
        return
    end
    
    -- Get services
    local _camera, userInput, runService, _players = GetServices()
    
    -- Connect input changed for mouse movement
    if userInput then
        userInput.InputChanged:Connect(OnInputChanged)
    end
    
    -- Connect render stepped for camera updates
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
    PlayerController.DisableFirstPerson()
    _isInitialized = false
    _cameraState.yaw = 0
    _cameraState.pitch = 0
    _cameraState.isFirstPerson = false
end

return PlayerController
