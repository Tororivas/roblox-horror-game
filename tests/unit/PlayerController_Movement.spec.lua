--!strict
--[[
    PlayerController Movement Tests (US-004)
    Validates WASD movement functionality.
]]

-- Helper to create a fresh PlayerController instance
local function createTestPlayerControllerWithMovement()
    local module = {}
    
    -- Type definitions
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
        lastMoveDirection: any,
    }
    
    local RAD_TO_DEG: number = 180 / math.pi
    local DEG_TO_RAD: number = math.pi / 180
    
    -- Default configurations
    local DEFAULT_CAMERA_CONFIG: CameraConfig = {
        fieldOfView = 70,
        mouseSensitivity = 0.002,
        maxLookUp = math.rad(80),
        maxLookDown = -math.rad(80),
    }
    
    local DEFAULT_MOVEMENT_CONFIG: MovementConfig = {
        walkSpeed = 16,
        sprintSpeed = 24,
        footstepCooldown = 0.5,
    }
    
    -- State
    local _isInitialized: boolean = false
    local _isFirstPerson: boolean = false
    local _yaw: number = 0
    local _pitch: number = 0
    local _cameraConfig: CameraConfig = DEFAULT_CAMERA_CONFIG
    local _mouseLocked: boolean = false
    local _mouseHidden: boolean = false
    
    -- Movement state
    local _movementState: MovementState = {
        isMoving = false,
        isSprinting = false,
        lastMoveDirection = {X = 0, Y = 0, Z = 0},
    }
    
    local _movementConfig: MovementConfig = DEFAULT_MOVEMENT_CONFIG
    local _testInputState: any = nil
    
    -- Forward declare and define MockHumanoid
    local MockHumanoid: any = nil
    MockHumanoid = {
        MoveDirection = {X = 0, Y = 0, Z = 0},
        WalkSpeed = 16,
        
        Move = function(_self: any, direction: any)
            MockHumanoid.MoveDirection = direction
        end,
    }
    
    local _humanoid: any = MockHumanoid
    
    -- Mock services
    local MockInputHandler = {
        _state = { W = false, A = false, S = false, D = false, Shift = false, E = false },
        
        GetInputState = function(self): any
            return self._state
        end,
        
        SetInputState = function(self, state: any)
            self._state = state
        end,
        
        Start = function() end,
        Stop = function() end,
    }
    
    local MockUserInputService: any = nil
    MockUserInputService = {
        MouseIconEnabled = true,
        MouseBehavior = 0,
        
        SetMouseBehavior = function(_self: any, behavior: number)
            MockUserInputService.MouseBehavior = behavior
        end,
    }
    
    -- Module functions
    function module.SetCameraRotation(yawDegrees: number, pitchDegrees: number): ()
        _yaw = yawDegrees * DEG_TO_RAD
        _pitch = pitchDegrees * DEG_TO_RAD
    end
    
    function module.GetCameraRotation(): (number, number)
        local yawDegrees: number = _yaw * RAD_TO_DEG
        local pitchDegrees: number = _pitch * RAD_TO_DEG
        return yawDegrees, pitchDegrees
    end
    
    -- Movement functions
    function module.SetTestInputState(inputState: any): ()
        _testInputState = inputState
    end
    
    function module.ClearTestInputState(): ()
        _testInputState = nil
    end
    
    function module.GetInputStateForMovement(): any
        if _testInputState then
            return _testInputState
        else
            return MockInputHandler:GetInputState()
        end
    end
    
    function module.CalculateMovementDirection(yaw: number): any
        local inputState = module.GetInputStateForMovement()
        
        local moveX = 0
        local moveZ = 0
        
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
            
            _movementState.isSprinting = inputState.Shift or false
        else
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
            moveX = normalizedX
            moveZ = normalizedZ
        else
            _movementState.isMoving = false
            _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
            return {X = 0, Y = 0, Z = 0}
        end
        
        -- Convert to world space based on camera yaw
        local cosYaw = math.cos(yaw)
        local sinYaw = math.sin(yaw)
        
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
    
    function module.ApplyMovement(direction: any): ()
        if _humanoid then
            _humanoid:Move(direction)
        end
    end
    
    function module.GetMovementState(): MovementState
        return {
            isMoving = _movementState.isMoving,
            isSprinting = _movementState.isSprinting,
            lastMoveDirection = _movementState.lastMoveDirection,
        }
    end
    
    function module.GetMovementConfig(): MovementConfig
        return {
            walkSpeed = _movementConfig.walkSpeed,
            sprintSpeed = _movementConfig.sprintSpeed,
            footstepCooldown = _movementConfig.footstepCooldown,
        }
    end
    
    function module.SetMovementConfig(config: MovementConfig): ()
        _movementConfig = {
            walkSpeed = config.walkSpeed or DEFAULT_MOVEMENT_CONFIG.walkSpeed,
            sprintSpeed = config.sprintSpeed or DEFAULT_MOVEMENT_CONFIG.sprintSpeed,
            footstepCooldown = config.footstepCooldown or DEFAULT_MOVEMENT_CONFIG.footstepCooldown,
        }
    end
    
    function module.IsSprinting(): boolean
        return _movementState.isSprinting
    end
    
    function module.IsMoving(): boolean
        return _movementState.isMoving
    end
    
    function module.GetMoveDirection(): any
        return _movementState.lastMoveDirection
    end
    
    function module.GetMockHumanoid(): any
        return MockHumanoid
    end
    
    function module.ResetMockHumanoid(): ()
        MockHumanoid.MoveDirection = {X = 0, Y = 0, Z = 0}
        MockHumanoid.WalkSpeed = 16
    end
    
    function module.Cleanup(): ()
        _isInitialized = false
        _isFirstPerson = false
        _yaw = 0
        _pitch = 0
        _movementState.isMoving = false
        _movementState.isSprinting = false
        _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
        _testInputState = nil
        MockHumanoid.MoveDirection = {X = 0, Y = 0, Z = 0}
        MockInputHandler:SetInputState({ W = false, A = false, S = false, D = false, Shift = false, E = false })
    end
    
    return module
end

local function runTests(): (number, number)
    print("Running PlayerController Movement tests...")
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
    
    -- Test 1: Movement state functions exist
    runTest("Movement state functions exist", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        assert(PlayerController.CalculateMovementDirection ~= nil, "CalculateMovementDirection should exist")
        assert(PlayerController.ApplyMovement ~= nil, "ApplyMovement should exist")
        assert(PlayerController.GetMovementState ~= nil, "GetMovementState should exist")
        assert(PlayerController.GetMovementConfig ~= nil, "GetMovementConfig should exist")
        assert(PlayerController.SetMovementConfig ~= nil, "SetMovementConfig should exist")
        assert(PlayerController.IsSprinting ~= nil, "IsSprinting should exist")
        assert(PlayerController.IsMoving ~= nil, "IsMoving should exist")
        assert(PlayerController.GetMoveDirection ~= nil, "GetMoveDirection should exist")
    end)
    
    -- Test 2: Initial movement state
    runTest("Initial movement state", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        local state = PlayerController.GetMovementState()
        assert(state.isMoving == false, "Should not be moving initially")
        assert(state.isSprinting == false, "Should not be sprinting initially")
        assert(state.lastMoveDirection.X == 0, "Move direction X should be 0 initially")
        assert(state.lastMoveDirection.Z == 0, "Move direction Z should be 0 initially")
    end)
    
    -- Test 3: Movement config defaults
    runTest("Movement config defaults", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        local config = PlayerController.GetMovementConfig()
        assert(config.walkSpeed == 16, "Default walk speed should be 16")
        assert(config.sprintSpeed == 24, "Default sprint speed should be 24")
        assert(config.footstepCooldown == 0.5, "Default footstep cooldown should be 0.5")
    end)
    
    -- Test 4: W key moves forward (negative Z in local space, transformed by yaw)
    runTest("W key moves forward relative to camera yaw", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- Set camera yaw to 0 (facing negative Z), press W
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(0)
        
        -- At yaw=0, forward is -Z, so we should move in negative Z
        assert(direction.Z < -0.9, "W at yaw=0 should move negative Z, got " .. tostring(direction.Z))
        assert(math.abs(direction.X) < 0.1, "W at yaw=0 should have X near 0")
    end)
    
    -- Test 5: S key moves backward
    runTest("S key moves backward relative to camera yaw", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- Set camera yaw to 0, press S
        PlayerController.SetTestInputState({ W = false, A = false, S = true, D = false, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(0)
        
        -- At yaw=0, backward is +Z
        assert(direction.Z > 0.9, "S at yaw=0 should move positive Z, got " .. tostring(direction.Z))
        assert(math.abs(direction.X) < 0.1, "S at yaw=0 should have X near 0")
    end)
    
    -- Test 6: A key moves left
    runTest("A key moves left relative to camera yaw", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- Set camera yaw to 0, press A
        PlayerController.SetTestInputState({ W = false, A = true, S = false, D = false, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(0)
        
        -- At yaw=0, left is -X
        assert(direction.X < -0.9, "A at yaw=0 should move negative X, got " .. tostring(direction.X))
        assert(math.abs(direction.Z) < 0.1, "A at yaw=0 should have Z near 0")
    end)
    
    -- Test 7: D key moves right
    runTest("D key moves right relative to camera yaw", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- Set camera yaw to 0, press D
        PlayerController.SetTestInputState({ W = false, A = false, S = false, D = true, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(0)
        
        -- At yaw=0, right is +X
        assert(direction.X > 0.9, "D at yaw=0 should move positive X, got " .. tostring(direction.X))
        assert(math.abs(direction.Z) < 0.1, "D at yaw=0 should have Z near 0")
    end)
    
    -- Test 8: Diagonal movement is normalized (W+D)
    runTest("Diagonal movement W+D is normalized", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- Press W and D together
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = true, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(0)
        
        -- Direction should be normalized (magnitude = 1)
        local magnitude = math.sqrt(direction.X * direction.X + direction.Z * direction.Z)
        assert(math.abs(magnitude - 1) < 0.01, "Diagonal movement should be normalized (magnitude = 1), got " .. tostring(magnitude))
        assert(direction.X > 0, "W+D should have positive X")
        assert(direction.Z < 0, "W+D should have negative Z")
    end)
    
    -- Test 9: Diagonal movement W+A is normalized
    runTest("Diagonal movement W+A is normalized", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetTestInputState({ W = true, A = true, S = false, D = false, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(0)
        
        local magnitude = math.sqrt(direction.X * direction.X + direction.Z * direction.Z)
        assert(math.abs(magnitude - 1) < 0.01, "W+A should be normalized, got magnitude " .. tostring(magnitude))
    end)
    
    -- Test 10: Diagonal movement S+D is normalized
    runTest("Diagonal movement S+D is normalized", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetTestInputState({ W = false, A = false, S = true, D = true, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(0)
        
        local magnitude = math.sqrt(direction.X * direction.X + direction.Z * direction.Z)
        assert(math.abs(magnitude - 1) < 0.01, "S+D should be normalized, got magnitude " .. tostring(magnitude))
    end)
    
    -- Test 11: Movement stops when no keys pressed
    runTest("Movement stops when no keys pressed", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- First press W to start moving
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        local _ = PlayerController.CalculateMovementDirection(0)
        
        -- Then release all keys
        PlayerController.SetTestInputState({ W = false, A = false, S = false, D = false, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(0)
        
        assert(direction.X == 0, "No keys should result in X = 0")
        assert(direction.Z == 0, "No keys should result in Z = 0")
        assert(PlayerController.IsMoving() == false, "IsMoving should be false when no keys pressed")
    end)
    
    -- Test 12: Movement direction follows camera yaw (90 degrees)
    runTest("Movement follows camera yaw 90 degrees", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- At yaw=90 (facing positive X), pressing W should move in +X direction
        -- cos(90)=0, sin(90)=1, W is (0,-1) local
        -- worldX = 0*0 - (-1)*1 = 1
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(math.rad(90))
        
        assert(direction.X > 0.9, "W at yaw=90 should move positive X, got " .. tostring(direction.X))
        assert(math.abs(direction.Z) < 0.1, "W at yaw=90 should have Z near 0")
    end)
    
    -- Test 13: Movement direction follows camera yaw (180 degrees)
    runTest("Movement follows camera yaw 180 degrees", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- At yaw=180 (facing positive Z), pressing W should move in +Z direction
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(math.rad(180))
        
        assert(direction.Z > 0.9, "W at yaw=180 should move positive Z, got " .. tostring(direction.Z))
        assert(math.abs(direction.X) < 0.1, "W at yaw=180 should have X near 0")
    end)
    
    -- Test 14: Movement direction follows camera yaw (-90 degrees)
    runTest("Movement follows camera yaw -90 degrees", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- At yaw=-90 (facing negative X), pressing W should move in -X direction
        -- cos(-90)=0, sin(-90)=-1, W is (0,-1) local
        -- worldX = 0*0 - (-1)*(-1) = -1
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        local direction = PlayerController.CalculateMovementDirection(math.rad(-90))
        
        assert(direction.X < -0.9, "W at yaw=-90 should move negative X, got " .. tostring(direction.X))
        assert(math.abs(direction.Z) < 0.1, "W at yaw=-90 should have Z near 0")
    end)
    
    -- Test 15: Sprint state is tracked
    runTest("Sprint state is tracked", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- Press W without shift
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        PlayerController.CalculateMovementDirection(0)
        assert(PlayerController.IsSprinting() == false, "Should not be sprinting without Shift")
        
        -- Press W with shift
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        assert(PlayerController.IsSprinting() == true, "Should be sprinting with Shift")
    end)
    
    -- Test 16: ApplyMovement calls Humanoid:Move
    runTest("ApplyMovement calls Humanoid Move", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        local testDirection = {X = 0.5, Y = 0, Z = -0.5}
        PlayerController.ApplyMovement(testDirection)
        
        local humanoid = PlayerController.GetMockHumanoid()
        assert(humanoid.MoveDirection.X == 0.5, "Humanoid MoveDirection X should be 0.5")
        assert(humanoid.MoveDirection.Z == -0.5, "Humanoid MoveDirection Z should be -0.5")
    end)
    
    -- Test 17: Movement config setter
    runTest("Movement config setter", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        
        PlayerController.SetMovementConfig({
            walkSpeed = 20,
            sprintSpeed = 30,
            footstepCooldown = 0.3,
        })
        
        local config = PlayerController.GetMovementConfig()
        assert(config.walkSpeed == 20, "Walk speed should be set to 20")
        assert(config.sprintSpeed == 30, "Sprint speed should be set to 30")
        assert(config.footstepCooldown == 0.3, "Footstep cooldown should be set to 0.3")
    end)
    
    -- Test 18: Cleanup resets movement state
    runTest("Cleanup resets movement state", function()
        local PlayerController = createTestPlayerControllerWithMovement()
        PlayerController.ResetMockHumanoid()
        
        -- Set some state
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(math.rad(45))
        
        -- Cleanup
        PlayerController.Cleanup()
        
        local state = PlayerController.GetMovementState()
        assert(state.isMoving == false, "isMoving should be false after cleanup")
        assert(state.isSprinting == false, "isSprinting should be false after cleanup")
        assert(state.lastMoveDirection.X == 0, "lastMoveDirection.X should be 0 after cleanup")
        assert(state.lastMoveDirection.Z == 0, "lastMoveDirection.Z should be 0 after cleanup")
    end)
    
    print(string.format("Movement Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests
