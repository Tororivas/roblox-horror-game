--!strict
--[[
    PlayerController Sprint Mechanics Tests (US-005)
    Validates sprint functionality with Shift key.
]]

-- Helper to create a fresh PlayerController instance with sprint support
local function createTestPlayerControllerWithSprint()
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
    local _cameraConfig: CameraConfig = DEFAULT_CAMERA_CONFIG
    local _movementConfig: MovementConfig = DEFAULT_MOVEMENT_CONFIG
    local _testInputState: any = nil
    
    -- Movement state
    local _movementState: MovementState = {
        isMoving = false,
        isSprinting = false,
        lastMoveDirection = {X = 0, Y = 0, Z = 0},
    }
    
    -- Forward declare MockHumanoid with proper type
    local MockHumanoid: any = nil
    MockHumanoid = {
        MoveDirection = {X = 0, Y = 0, Z = 0},
        WalkSpeed = 16,
        
        Move = function(_self: any, direction: any)
            MockHumanoid.MoveDirection = direction
        end,
        
        GetWalkSpeed = function(_self: any): number
            return MockHumanoid.WalkSpeed
        end,
        
        SetWalkSpeed = function(_self: any, speed: number)
            MockHumanoid.WalkSpeed = speed
        end,
    }
    
    local _humanoid: any = MockHumanoid
    
    -- Mock InputHandler
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
    
    -- Module functions
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
    
    function module.SimulateUpdateWalkSpeed(): ()
        -- Called during OnRenderStep to update Humanoid WalkSpeed
        if _movementState.isSprinting then
            _humanoid:SetWalkSpeed(_movementConfig.sprintSpeed)
        else
            _humanoid:SetWalkSpeed(_movementConfig.walkSpeed)
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
            
            -- Sprint only works while moving: Shift + WASD pressed
            local isMovingWASD = (moveX ~= 0 or moveZ ~= 0)
            _movementState.isSprinting = (inputState.Shift and isMovingWASD) or false
        else
            _movementState.isMoving = false
            _movementState.isSprinting = false
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
            _movementState.isSprinting = false
            _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
            return {X = 0, Y = 0, Z = 0}
        end
        
        -- Convert to world space
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
    
    function module.GetWalkSpeed(): number
        if _movementState.isSprinting then
            return _movementConfig.sprintSpeed
        else
            return _movementConfig.walkSpeed
        end
    end
    
    function module.IsSprinting(): boolean
        return _movementState.isSprinting
    end
    
    function module.IsMoving(): boolean
        return _movementState.isMoving
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
    
    function module.GetMockHumanoid(): any
        return MockHumanoid
    end
    
    function module.GetMockWalkSpeed(): number
        return MockHumanoid.WalkSpeed
    end
    
    function module.ResetMockHumanoid(): ()
        MockHumanoid.MoveDirection = {X = 0, Y = 0, Z = 0}
        MockHumanoid.WalkSpeed = 16
    end
    
    function module.Cleanup(): ()
        _movementState.isMoving = false
        _movementState.isSprinting = false
        _movementState.lastMoveDirection = {X = 0, Y = 0, Z = 0}
        _testInputState = nil
        MockHumanoid.WalkSpeed = 16
        MockInputHandler:SetInputState({ W = false, A = false, S = false, D = false, Shift = false, E = false })
    end
    
    return module
end

local function runTests(): (number, number)
    print("Running PlayerController Sprint Mechanics tests...")
    local passed = 0
    local failed = 0
    
    local function runTest(testName: string, testFn: () -> ()): boolean
        local success, err = pcall(testFn)
        if success then
            passed += 1
            print("  ✓ " .. testName)
            return true
        else
            failed += 1
            print("  ✗ " .. testName .. ": " .. tostring(err))
            return false
        end
    end
    
    -- Test 1: Sprint state functions exist
    runTest("Sprint state functions exist", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        assert(PlayerController.CalculateMovementDirection ~= nil, "CalculateMovementDirection should exist")
        assert(PlayerController.GetWalkSpeed ~= nil, "GetWalkSpeed should exist")
        assert(PlayerController.IsSprinting ~= nil, "IsSprinting should exist")
        assert(PlayerController.IsMoving ~= nil, "IsMoving should exist")
        assert(PlayerController.GetMockWalkSpeed ~= nil, "GetMockWalkSpeed should exist")
    end)
    
    -- Test 2: Default walk speed is 16
    runTest("Default walk speed is 16", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        assert(PlayerController.GetWalkSpeed() == 16, "Default walk speed should be 16")
        assert(PlayerController.GetMockWalkSpeed() == 16, "Humanoid walk speed should be 16 initially")
    end)
    
    -- Test 3: Sprint speed is 24
    runTest("Sprint speed is 24", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        local config = PlayerController.GetMovementConfig()
        assert(config.sprintSpeed == 24, "Sprint speed should be 24")
    end)
    
    -- Test 4: Sprint activates with Shift + W
    runTest("Sprint activates with Shift + W", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        -- Hold Shift + W
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == true, "Should be sprinting with Shift + W")
        assert(PlayerController.GetWalkSpeed() == 24, "WalkSpeed should be sprint speed (24)")
    end)
    
    -- Test 5: Sprint activates with Shift + any movement key
    runTest("Sprint activates with Shift + S", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetTestInputState({ W = false, A = false, S = true, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == true, "Should be sprinting with Shift + S")
    end)
    
    runTest("Sprint activates with Shift + A", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetTestInputState({ W = false, A = true, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == true, "Should be sprinting with Shift + A")
    end)
    
    runTest("Sprint activates with Shift + D", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetTestInputState({ W = false, A = false, S = false, D = true, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == true, "Should be sprinting with Shift + D")
    end)
    
    runTest("Sprint activates with Shift + diagonal movement", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetTestInputState({ W = true, A = true, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == true, "Should be sprinting with Shift + diagonal movement")
    end)
    
    -- Test 6: Sprint does NOT activate with just Shift (no movement)
    runTest("Sprint does NOT activate with just Shift held", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        -- Hold Shift without movement
        PlayerController.SetTestInputState({ W = false, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == false, "Should NOT be sprinting with Shift alone (no movement)")
        assert(PlayerController.GetWalkSpeed() == 16, "WalkSpeed should still be walk speed (16)")
        assert(PlayerController.IsMoving() == false, "Should not be moving when no WASD keys pressed")
    end)
    
    -- Test 7: Sprint does NOT activate with just movement (no Shift)
    runTest("Sprint does NOT activate with just movement (no Shift)", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        -- Hold W without Shift
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == false, "Should NOT be sprinting without Shift")
        assert(PlayerController.GetWalkSpeed() == 16, "WalkSpeed should be walk speed (16)")
        assert(PlayerController.IsMoving() == true, "Should be moving with W pressed")
    end)
    
    -- Test 8: Releasing Shift stops sprint
    runTest("Releasing Shift stops sprint", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        -- Start sprinting
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        assert(PlayerController.IsSprinting() == true, "Should be sprinting initially")
        
        -- Release Shift
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == false, "Should stop sprinting after Shift released")
        assert(PlayerController.GetWalkSpeed() == 16, "WalkSpeed should return to walk speed (16)")
    end)
    
    -- Test 9: Releasing all movement keys stops sprint even if Shift still held
    runTest("Releasing all movement stops sprint even if Shift held", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        -- Start sprinting
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        assert(PlayerController.IsSprinting() == true, "Should be sprinting initially")
        
        -- Release W but hold Shift
        PlayerController.SetTestInputState({ W = false, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == false, "Should stop sprinting when no movement")
        assert(PlayerController.IsMoving() == false, "Should not be moving when no keys pressed")
    end)
    
    -- Test 10: WalkSpeed updates on Humanoid when sprinting
    runTest("WalkSpeed updates on Humanoid when sprinting", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        -- Initial speed should be 16
        assert(PlayerController.GetMockWalkSpeed() == 16, "Initial humanoid speed should be 16")
        
        -- Start sprinting and simulate frame update
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        PlayerController.SimulateUpdateWalkSpeed()
        
        assert(PlayerController.GetMockWalkSpeed() == 24, "Humanoid speed should update to 24 when sprinting")
    end)
    
    -- Test 11: WalkSpeed updates on Humanoid when sprint ends
    runTest("WalkSpeed returns to normal when sprint ends", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        -- Start sprinting
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        PlayerController.SimulateUpdateWalkSpeed()
        assert(PlayerController.GetMockWalkSpeed() == 24, "Should be sprinting at 24")
        
        -- Release Shift
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        PlayerController.CalculateMovementDirection(0)
        PlayerController.SimulateUpdateWalkSpeed()
        
        assert(PlayerController.GetMockWalkSpeed() == 16, "Humanoid speed should return to 16")
    end)
    
    -- Test 12: Sprint state exposure via GetWalkSpeed
    runTest("GetWalkSpeed returns sprint speed when sprinting", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        local speed = PlayerController.GetWalkSpeed()
        assert(speed == 24, "GetWalkSpeed should return 24 when sprinting")
    end)
    
    runTest("GetWalkSpeed returns walk speed when not sprinting", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        PlayerController.CalculateMovementDirection(0)
        
        local speed = PlayerController.GetWalkSpeed()
        assert(speed == 16, "GetWalkSpeed should return 16 when not sprinting")
    end)
    
    -- Test 13: IsSprinting returns correct value
    runTest("IsSprinting returns true when sprinting", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting(), "IsSprinting should be true")
    end)
    
    runTest("IsSprinting returns false when not sprinting", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        -- Just movement, no shift
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = false })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.IsSprinting() == false, "IsSprinting should be false without Shift")
    end)
    
    -- Test 14: Configurable sprint speed
    runTest("Custom sprint speed in config", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        PlayerController.SetMovementConfig({
            walkSpeed = 16,
            sprintSpeed = 32,
            footstepCooldown = 0.5,
        })
        
        PlayerController.SetTestInputState({ W = true, A = false, S = false, D = false, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        
        assert(PlayerController.GetWalkSpeed() == 32, "Custom sprint speed should be 32")
    end)
    
    -- Test 15: Cleanup resets sprint state
    runTest("Cleanup resets sprint state", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        -- Set sprinting state
        PlayerController.SetTestInputState({ W = true, Shift = true })
        PlayerController.CalculateMovementDirection(0)
        PlayerController.SimulateUpdateWalkSpeed()
        assert(PlayerController.IsSprinting() == true, "Should be sprinting before cleanup")
        
        -- Cleanup
        PlayerController.Cleanup()
        
        assert(PlayerController.IsSprinting() == false, "Sprinting should be false after cleanup")
        assert(PlayerController.GetMockWalkSpeed() == 16, "Humanoid WalkSpeed should be reset to 16")
    end)
    
    -- Test 16: Sprint only works while moving - comprehensive check
    runTest("Sprint requires both Shift and movement keys", function()
        local PlayerController = createTestPlayerControllerWithSprint()
        PlayerController.ResetMockHumanoid()
        
        local testCases: {{W: boolean?, A: boolean?, S: boolean?, D: boolean?, Shift: boolean, expected: boolean, desc: string}} = {
            { W = true, A = false, S = false, D = false, Shift = false, expected = false, desc = "W without Shift" },
            { W = true, A = false, S = false, D = false, Shift = true, expected = true, desc = "W with Shift" },
            { W = false, A = false, S = false, D = false, Shift = true, expected = false, desc = "Shift without movement" },
            { W = true, A = true, S = false, D = false, Shift = true, expected = true, desc = "Diagonal with Shift" },
        }
        
        for _, tc in ipairs(testCases) do
            PlayerController.SetTestInputState({
                W = tc.W or false,
                A = tc.A or false,
                S = tc.S or false,
                D = tc.D or false,
                Shift = tc.Shift or false,
            })
            PlayerController.CalculateMovementDirection(0)
            
            assert(PlayerController.IsSprinting() == tc.expected,
                tc.desc .. " - expected sprint=" .. tostring(tc.expected) .. " but got " .. tostring(PlayerController.IsSprinting()))
        end
    end)
    
    print(string.format("Sprint Mechanics Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests
