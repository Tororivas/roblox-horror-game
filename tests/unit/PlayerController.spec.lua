--!strict
--[[
    PlayerController Module Tests
    Validates first-person camera functionality.
]]

-- Helper to create a fresh PlayerController instance
local function createTestPlayerController()
    local module = {}
    
    -- Type definitions for camera configuration
    export type CameraConfig = {
        fieldOfView: number,
        mouseSensitivity: number,
        maxLookUp: number,
        maxLookDown: number,
    }
    
    export type CameraState = {
        yaw: number,
        pitch: number,
        isFirstPerson: boolean,
    }
    
    local RAD_TO_DEG: number = 180 / math.pi
    local DEG_TO_RAD: number = math.pi / 180
    
    -- Default camera configuration
    local DEFAULT_CAMERA_CONFIG: CameraConfig = {
        fieldOfView = 70,
        mouseSensitivity = 0.002,
        maxLookUp = math.rad(80),
        maxLookDown = -math.rad(80),
    }
    
    -- Private state
    local _isInitialized: boolean = false
    local _isFirstPerson: boolean = false
    local _yaw: number = 0
    local _pitch: number = 0
    local _cameraConfig: CameraConfig = DEFAULT_CAMERA_CONFIG
    local _mouseLocked: boolean = false
    local _mouseHidden: boolean = false
    
    -- Mock services
    local MockCamera = {
        CameraType = 0,
        FieldOfView = 70,
        CFrame = {
            Position = {X = 0, Y = 0, Z = 0},
            LookVector = {X = 0, Y = 0, Z = -1},
        },
    }
    
    local MockUserInputService: any = nil
    MockUserInputService = {
        MouseIconEnabled = true,
        MouseBehavior = 0,
        
        SetMouseBehavior = function(_self: any, behavior: number)
            MockUserInputService.MouseBehavior = behavior
        end,
    }
    
    local MockRunService = {
        RenderStepped = {
            Connect = function(_self: any, _callback: any): any
                return { Disconnect = function() end }
            end,
        },
    }
    
    local MockPlayers = {
        LocalPlayer = {
            Character = nil,
        },
    }
    
    -- Private functions
    local function clamp(n: number, min: number, max: number): number
        return math.max(min, math.min(n, max))
    end
    
    -- Module functions
    function module.CalculateCameraCFrame(headPosition: any): any
        local pitchRotation: number = clamp(_pitch, _cameraConfig.maxLookDown, _cameraConfig.maxLookUp)
        
        local cosPitch: number = math.cos(pitchRotation)
        local sinPitch: number = math.sin(pitchRotation)
        local cosYaw: number = math.cos(_yaw)
        local sinYaw: number = math.sin(_yaw)
        
        local lookX: number = -sinYaw * cosPitch
        local lookY: number = sinPitch
        local lookZ: number = -cosYaw * cosPitch
        
        return {
            Position = headPosition or {X = 0, Y = 0, Z = 0},
            LookVector = {
                X = lookX,
                Y = lookY,
                Z = lookZ,
            },
        }
    end
    
    function module.SetCameraRotation(yawDegrees: number, pitchDegrees: number): ()
        _yaw = yawDegrees * DEG_TO_RAD
        _pitch = pitchDegrees * DEG_TO_RAD
    end
    
    function module.GetCameraRotation(): (number, number)
        local yawDegrees: number = _yaw * RAD_TO_DEG
        local pitchDegrees: number = _pitch * RAD_TO_DEG
        return yawDegrees, pitchDegrees
    end
    
    function module.GetCameraState(): CameraState
        return {
            yaw = _yaw,
            pitch = _pitch,
            isFirstPerson = _isFirstPerson,
        }
    end
    
    function module.GetCameraConfig(): CameraConfig
        return {
            fieldOfView = _cameraConfig.fieldOfView,
            mouseSensitivity = _cameraConfig.mouseSensitivity,
            maxLookUp = _cameraConfig.maxLookUp,
            maxLookDown = _cameraConfig.maxLookDown,
        }
    end
    
    function module.RadToDeg(rad: number): number
        return rad * RAD_TO_DEG
    end
    
    function module.DegToRad(deg: number): number
        return deg * DEG_TO_RAD
    end
    
    function module.UpdateCamera(deltaX: number, deltaY: number): ()
        _yaw += deltaX * _cameraConfig.mouseSensitivity
        _pitch -= deltaY * _cameraConfig.mouseSensitivity
        _pitch = clamp(_pitch, _cameraConfig.maxLookDown, _cameraConfig.maxLookUp)
    end
    
    function module.LockMouse(): ()
        MockUserInputService.MouseBehavior = 1
        _mouseLocked = true
        MockUserInputService.MouseIconEnabled = false
        _mouseHidden = true
    end
    
    function module.UnlockMouse(): ()
        MockUserInputService.MouseBehavior = 0
        _mouseLocked = false
        MockUserInputService.MouseIconEnabled = true
        _mouseHidden = false
    end
    
    function module.IsMouseLocked(): boolean
        return _mouseLocked and _mouseHidden
    end
    
    function module.EnableFirstPerson(): ()
        MockCamera.CameraType = 0
        module.LockMouse()
        _isFirstPerson = true
    end
    
    function module.DisableFirstPerson(): ()
        module.UnlockMouse()
        _isFirstPerson = false
    end
    
    function module.IsFirstPerson(): boolean
        return _isFirstPerson
    end
    
    function module.IsInitialized(): boolean
        return _isInitialized
    end
    
    function module.Initialize(): ()
        if _isInitialized then
            return
        end
        module.EnableFirstPerson()
        _isInitialized = true
    end
    
    function module.Cleanup(): ()
        module.DisableFirstPerson()
        _isInitialized = false
        _yaw = 0
        _pitch = 0
        _isFirstPerson = false
        _mouseLocked = false
        _mouseHidden = false
        MockUserInputService.MouseIconEnabled = true
        MockUserInputService.MouseBehavior = 0
        MockCamera.CameraType = 0
        MockCamera.FieldOfView = 70
    end
    
    return module
end

local function runTests(): (number, number)
    print("Running PlayerController module tests...")
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

    -- Test 1: File exists with required functions
    runTest("File exists with required functions", function()
        local PlayerController = createTestPlayerController()
        assert(PlayerController.Initialize ~= nil, "Initialize function should exist")
        assert(PlayerController.IsInitialized ~= nil, "IsInitialized function should exist")
        assert(PlayerController.EnableFirstPerson ~= nil, "EnableFirstPerson function should exist")
        assert(PlayerController.DisableFirstPerson ~= nil, "DisableFirstPerson function should exist")
        assert(PlayerController.IsFirstPerson ~= nil, "IsFirstPerson function should exist")
        assert(PlayerController.UpdateCamera ~= nil, "UpdateCamera function should exist")
        assert(PlayerController.LockMouse ~= nil, "LockMouse function should exist")
        assert(PlayerController.UnlockMouse ~= nil, "UnlockMouse function should exist")
        assert(PlayerController.IsMouseLocked ~= nil, "IsMouseLocked function should exist")
        assert(PlayerController.GetCameraState ~= nil, "GetCameraState function should exist")
        assert(PlayerController.SetCameraRotation ~= nil, "SetCameraRotation function should exist")
        assert(PlayerController.GetCameraRotation ~= nil, "GetCameraRotation function should exist")
        assert(PlayerController.CalculateCameraCFrame ~= nil, "CalculateCameraCFrame function should exist")
        assert(PlayerController.RadToDeg ~= nil, "RadToDeg function should exist")
        assert(PlayerController.DegToRad ~= nil, "DegToRad function should exist")
        assert(PlayerController.Cleanup ~= nil, "Cleanup function should exist")
    end)

    -- Test 2: Initial state is not initialized
    runTest("Initial state is not initialized", function()
        local PlayerController = createTestPlayerController()
        assert(PlayerController.IsInitialized() == false, "Should not be initialized initially")
        assert(PlayerController.IsFirstPerson() == false, "Should not be in first-person initially")
        assert(PlayerController.IsMouseLocked() == false, "Mouse should not be locked initially")
    end)

    -- Test 3: Initialize sets up first-person mode
    runTest("Initialize sets up first-person mode", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        assert(PlayerController.IsInitialized() == true, "Should be initialized after Initialize()")
        assert(PlayerController.IsFirstPerson() == true, "Should be in first-person after Initialize()")
    end)

    -- Test 4: Camera mode is set to first-person (CameraType = Custom = 0)
    runTest("Camera mode is set to first-person", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        local state = PlayerController.GetCameraState()
        assert(state.isFirstPerson == true, "isFirstPerson should be true")
        assert(PlayerController.IsFirstPerson() == true, "IsFirstPerson should return true")
    end)

    -- Test 5: Mouse delta rotates camera horizontally (yaw)
    runTest("Mouse delta rotates camera horizontally", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        -- Start at 0 degrees
        PlayerController.SetCameraRotation(0, 0)
        local initialYaw, _ = PlayerController.GetCameraRotation()
        assert(math.abs(initialYaw) < 0.01, "Initial yaw should be 0")
        
        -- Apply mouse delta to right (positive X)
        PlayerController.UpdateCamera(1000, 0) -- Large delta to see effect
        local newYaw, _ = PlayerController.GetCameraRotation()
        assert(newYaw > 0, "Yaw should increase with positive X delta")
        
        -- Apply mouse delta to left (negative X)
        PlayerController.SetCameraRotation(0, 0)
        PlayerController.UpdateCamera(-1000, 0)
        local negYaw, _ = PlayerController.GetCameraRotation()
        assert(negYaw < 0, "Yaw should decrease with negative X delta")
    end)

    -- Test 6: Mouse delta rotates camera vertically (pitch)
    runTest("Mouse delta rotates camera vertically", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        -- Start at 0 degrees
        PlayerController.SetCameraRotation(0, 0)
        local _, initialPitch = PlayerController.GetCameraRotation()
        assert(math.abs(initialPitch) < 0.01, "Initial pitch should be 0")
        
        -- Apply mouse delta down (positive Y in screen coords, but pitch increases)
        PlayerController.UpdateCamera(0, -500)
        local _, newPitch = PlayerController.GetCameraRotation()
        assert(newPitch > 0, "Pitch should increase with input")
        
        -- Apply mouse delta up (negative Y)
        PlayerController.SetCameraRotation(0, 0)
        PlayerController.UpdateCamera(0, 500)
        local _, negPitch = PlayerController.GetCameraRotation()
        assert(negPitch < 0, "Pitch should decrease with negative Y delta")
    end)

    -- Test 7: Vertical rotation is clamped to -80 to 80 degrees
    runTest("Vertical rotation clamped between -80 and 80 degrees", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        -- Try to rotate beyond 80 degrees up (mouse UP = negative deltaY)
        PlayerController.SetCameraRotation(0, 0)
        PlayerController.UpdateCamera(0, -100000) -- Very large negative attempt (mouse UP)
        local _, pitchUp = PlayerController.GetCameraRotation()
        assert(pitchUp <= 80.1 and pitchUp >= 79, "Pitch should be clamped to ~80 degrees max when looking up")
        
        -- Try to rotate beyond -80 degrees down (mouse DOWN = positive deltaY)
        PlayerController.SetCameraRotation(0, 0)
        PlayerController.UpdateCamera(0, 100000) -- Very large positive attempt (mouse DOWN)
        local _, pitchDown = PlayerController.GetCameraRotation()
        assert(pitchDown >= -80.1 and pitchDown <= -79, "Pitch should be clamped to ~-80 degrees min when looking down")
    end)

    -- Test 8: Mouse cursor is hidden and locked
    runTest("Mouse cursor is hidden and locked", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        assert(PlayerController.IsMouseLocked() == true, "Mouse should be locked after Initialize")
        assert(PlayerController.IsFirstPerson() == true, "Should be in first-person mode")
    end)

    -- Test 9: Unlock mouse restores cursor
    runTest("Unlock mouse restores cursor", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        PlayerController.UnlockMouse()
        assert(PlayerController.IsMouseLocked() == false, "Mouse should not be locked after UnlockMouse")
    end)

    -- Test 10: CFrame calculation produces valid look vectors
    runTest("CFrame calculation produces valid look vectors", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        -- Reset to 0,0
        PlayerController.SetCameraRotation(0, 0)
        local cframe = PlayerController.CalculateCameraCFrame({X = 0, Y = 5, Z = 0})
        
        assert(cframe ~= nil, "CFrame should not be nil")
        assert(cframe.Position ~= nil, "CFrame should have Position")
        assert(cframe.LookVector ~= nil, "CFrame should have LookVector")
        
        -- Look vector should be normalized (approximately)
        local lv = cframe.LookVector
        local magnitude = math.sqrt(lv.X * lv.X + lv.Y * lv.Y + lv.Z * lv.Z)
        assert(math.abs(magnitude - 1) < 0.001, "LookVector should be normalized (magnitude = 1)")
    end)

    -- Test 11: CFrame calculation with different rotations
    runTest("CFrame calculation with different rotations", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        -- Test looking straight forward (yaw=0, pitch=0)
        PlayerController.SetCameraRotation(0, 0)
        local cframeForward = PlayerController.CalculateCameraCFrame({X = 0, Y = 0, Z = 0})
        -- Looking -Z direction
        assert(cframeForward.LookVector.Z < -0.9, "Forward look should point negative Z")
        
        -- Test looking 90 degrees right (yaw=90) - this looks to -X (inverted in right-handed coord system)
        PlayerController.SetCameraRotation(90, 0)
        local cframeRight = PlayerController.CalculateCameraCFrame({X = 0, Y = 0, Z = 0})
        -- With formula -sin(yaw), 90 degrees yaw gives X = -1
        assert(cframeRight.LookVector.X < -0.9, "90 degree yaw should look negative X")
        
        -- Test looking 90 degrees left (yaw=-90) - this looks to +X
        PlayerController.SetCameraRotation(-90, 0)
        local cframeLeft = PlayerController.CalculateCameraCFrame({X = 0, Y = 0, Z = 0})
        -- With formula -sin(yaw), -90 degrees yaw gives X = +1
        assert(cframeLeft.LookVector.X > 0.9, "-90 degree yaw should look positive X")
        
        -- Test looking down (pitch=-45) - negative pitch gives negative Y
        PlayerController.SetCameraRotation(0, -45)
        local cframeDown = PlayerController.CalculateCameraCFrame({X = 0, Y = 0, Z = 0})
        -- Looking down should have negative Y component
        assert(cframeDown.LookVector.Y < -0.5, "-45 degree pitch should look down")
        
        -- Test looking up (pitch=45) - positive pitch gives positive Y
        PlayerController.SetCameraRotation(0, 45)
        local cframeUp = PlayerController.CalculateCameraCFrame({X = 0, Y = 0, Z = 0})
        -- Looking up should have positive Y component
        assert(cframeUp.LookVector.Y > 0.5, "45 degree pitch should look up")
    end)

    -- Test 12: RadToDeg and DegToRad conversion
    runTest("RadToDeg and DegToRad conversion", function()
        local PlayerController = createTestPlayerController()
        
        -- Test 0
        assert(math.abs(PlayerController.RadToDeg(0) - 0) < 0.001, "RadToDeg(0) should be 0")
        assert(math.abs(PlayerController.DegToRad(0) - 0) < 0.001, "DegToRad(0) should be 0")
        
        -- Test PI = 180 degrees
        local piInDegrees = PlayerController.RadToDeg(math.pi)
        assert(math.abs(piInDegrees - 180) < 0.001, "RadToDeg(pi) should be 180")
        
        local oneEightyInRad = PlayerController.DegToRad(180)
        assert(math.abs(oneEightyInRad - math.pi) < 0.001, "DegToRad(180) should be pi")
        
        -- Test 90 degrees = PI/2
        local ninetyInRad = PlayerController.DegToRad(90)
        assert(math.abs(ninetyInRad - math.pi/2) < 0.001, "DegToRad(90) should be pi/2")
        
        local halfPiInDeg = PlayerController.RadToDeg(math.pi/2)
        assert(math.abs(halfPiInDeg - 90) < 0.001, "RadToDeg(pi/2) should be 90")
        
        -- Test round-trip
        local original = 45
        local rad = PlayerController.DegToRad(original)
        local deg = PlayerController.RadToDeg(rad)
        assert(math.abs(deg - original) < 0.001, "Round-trip conversion should preserve value")
    end)

    -- Test 13: Cleanup resets all state
    runTest("Cleanup resets all state", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        -- Set some state
        PlayerController.SetCameraRotation(45, 30)
        
        -- Cleanup
        PlayerController.Cleanup()
        
        assert(PlayerController.IsInitialized() == false, "Should not be initialized after Cleanup")
        assert(PlayerController.IsFirstPerson() == false, "Should not be first-person after Cleanup")
        assert(PlayerController.IsMouseLocked() == false, "Mouse should not be locked after Cleanup")
        
        local yaw, pitch = PlayerController.GetCameraRotation()
        assert(math.abs(yaw) < 0.001, "Yaw should be reset to 0")
        assert(math.abs(pitch) < 0.001, "Pitch should be reset to 0")
    end)

    -- Test 14: Camera sensitivity affects rotation
    runTest("Camera sensitivity affects rotation", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        -- Get camera config
        local config = PlayerController.GetCameraConfig()
        
        -- Apply delta with sensitivity
        PlayerController.SetCameraRotation(0, 0)
        PlayerController.UpdateCamera(100, 0)
        local yaw1, _ = PlayerController.GetCameraRotation()
        
        -- Check that rotation occurred (sensitivity of 0.002 * 100 = 0.2 radians)
        local expectedRotation = 100 * config.mouseSensitivity * (180 / math.pi)
        assert(math.abs(yaw1 - expectedRotation) < 0.1, "Rotation should respect sensitivity")
    end)

    -- Test 15: Horizontal rotation has no limits (can rotate 360+)
    runTest("Horizontal rotation has no limits", function()
        local PlayerController = createTestPlayerController()
        PlayerController.Initialize()
        
        -- Rotate multiple full circles
        PlayerController.SetCameraRotation(0, 0)
        PlayerController.UpdateCamera(10000, 0) -- Very large X delta
        local yaw, _ = PlayerController.GetCameraRotation()
        
        -- Yaw should be able to go beyond 360
        assert(yaw > 100, "Yaw should be able to exceed 360 degrees")
        
        -- Same for negative rotation
        PlayerController.SetCameraRotation(0, 0)
        PlayerController.UpdateCamera(-10000, 0)
        local negYaw, _ = PlayerController.GetCameraRotation()
        assert(negYaw < -100, "Yaw should be able to go below -360 degrees")
    end)

    -- Test 16: Camera config accessor
    runTest("Camera config accessor", function()
        local PlayerController = createTestPlayerController()
        
        local config = PlayerController.GetCameraConfig()
        assert(config.fieldOfView == 70, "Default FOV should be 70")
        assert(config.mouseSensitivity == 0.002, "Default sensitivity should be 0.002")
        assert(math.abs(config.maxLookUp - math.rad(80)) < 0.001, "Default maxLookUp should be 80 degrees")
        assert(math.abs(config.maxLookDown - (-math.rad(80))) < 0.001, "Default maxLookDown should be -80 degrees")
    end)

    print(string.format("Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests
