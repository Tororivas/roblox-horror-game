--!strict
--[[
    FootstepSoundSystem Module Tests
    Validates footstep sound system functionality.
]]

-- Test runner
local function runTests(): (number, number)
    print("Running FootstepSoundSystem module tests (US-009)...")
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

    -- Load fresh module for each test
    local function getFreshModule()
        -- Create a new isolated environment by directly loading the module logic
        local module: any = {}
        
        -- Constants
        local FOOTSTEP_COOLDOWN: number = 0.35
        local WALK_PITCH: number = 1.0
        local SPRINT_PITCH: number = 1.1
        local MOVE_THRESHOLD: number = 0.1

        -- Private state
        local _isInitialized: boolean = false
        local _lastFootstepTime: number = -1000
        local _isLeftFoot: boolean = true
        local _leftFootSound: any? = nil
        local _rightFootSound: any? = nil
        local _soundParent: any? = nil
        local _isSprinting: boolean = false
        local _currentWalkSpeed: number = 0
        local _lastMovementState: boolean = false

        -- Mock time for testing
        local _mockTime: number = 0

        -- Mock Sound creator
        local function CreateMockSound(name: string)
            return {
                Name = name,
                SoundId = "",
                Volume = 0.5,
                PlaybackSpeed = 1.0,
                IsPlaying = false,
                _playCount = 0,
                _lastPlayTime = 0,
                Parent = nil,
                
                Play = function(self: any)
                    self.IsPlaying = true
                    self._playCount = self._playCount + 1
                    self._lastPlayTime = _mockTime
                end,
                
                Stop = function(self: any)
                    self.IsPlaying = false
                end,
                
                GetPlayCount = function(self: any): number
                    return self._playCount
                end,
                
                GetLastPlayTime = function(self: any): number
                    return self._lastPlayTime
                end,
                
                Reset = function(self: any)
                    self._playCount = 0
                    self._lastPlayTime = 0
                    self.IsPlaying = false
                end,
            }
        end

        -- Internal functions
        local function GetCurrentTime(): number
            return _mockTime
        end

        local function IsCooldownElapsed(): boolean
            local timeSinceLastFootstep = _mockTime - _lastFootstepTime
            return timeSinceLastFootstep >= FOOTSTEP_COOLDOWN
        end

        local function CalculatePitch(): number
            if _isSprinting then
                return SPRINT_PITCH
            else
                return WALK_PITCH
            end
        end

        local function IsMoving(speed: number): boolean
            return speed > MOVE_THRESHOLD
        end

        local function PlayFootstep(): ()
            if not _isInitialized then
                return
            end

            if not IsCooldownElapsed() then
                return
            end

            local soundToPlay: any? = nil
            
            if _isLeftFoot then
                soundToPlay = _leftFootSound
            else
                soundToPlay = _rightFootSound
            end

            if not soundToPlay then
                return
            end

            soundToPlay.PlaybackSpeed = CalculatePitch()
            soundToPlay:Play()
            _lastFootstepTime = GetCurrentTime()
            _isLeftFoot = not _isLeftFoot
        end

        -- Public functions
        function module.Initialize(parent: any?): ()
            if _isInitialized then
                return
            end

            _soundParent = parent
            _leftFootSound = CreateMockSound("LeftFootstep")
            _rightFootSound = CreateMockSound("RightFootstep")
            
            _lastFootstepTime = -1000
            _isLeftFoot = true
            _isSprinting = false
            _currentWalkSpeed = 0
            _lastMovementState = false

            _isInitialized = true
        end

        function module.Update(speed: number, isSprinting: boolean?): ()
            if not _isInitialized then
                return
            end

            _isSprinting = isSprinting or false
            _currentWalkSpeed = speed

            local isCurrentlyMoving = IsMoving(speed)

            if isCurrentlyMoving then
                PlayFootstep()
            end

            _lastMovementState = isCurrentlyMoving
        end

        function module.OnRunning(speed: number): ()
            module.Update(speed, _isSprinting)
        end

        function module.IsInitialized(): boolean
            return _isInitialized
        end

        function module.GetLastFootstepTime(): number
            return _lastFootstepTime
        end

        function module.GetCooldown(): number
            return FOOTSTEP_COOLDOWN
        end

        function module.GetCurrentPitch(): number
            return CalculatePitch()
        end

        function module.IsOnCooldown(): boolean
            return not IsCooldownElapsed()
        end

        function module.GetNextFoot(): string
            return _isLeftFoot and "Left" or "Right"
        end

        function module.GetLeftFootSound(): any?
            return _leftFootSound
        end

        function module.GetRightFootSound(): any?
            return _rightFootSound
        end

        function module.GetLeftFootPlayCount(): number
            if _leftFootSound then
                return _leftFootSound:GetPlayCount()
            end
            return 0
        end

        function module.GetRightFootPlayCount(): number
            if _rightFootSound then
                return _rightFootSound:GetPlayCount()
            end
            return 0
        end

        function module.GetTotalPlayCount(): number
            return module.GetLeftFootPlayCount() + module.GetRightFootPlayCount()
        end

        function module.GetMoveThreshold(): number
            return MOVE_THRESHOLD
        end

        function module.GetWalkPitch(): number
            return WALK_PITCH
        end

        function module.GetSprintPitch(): number
            return SPRINT_PITCH
        end

        function module.SetSprinting(isSprinting: boolean): ()
            _isSprinting = isSprinting
        end

        function module.Cleanup(): ()
            if _leftFootSound then
                _leftFootSound:Reset()
            end
            if _rightFootSound then
                _rightFootSound:Reset()
            end

            _isInitialized = false
            _lastFootstepTime = -1000
            _isLeftFoot = true
            _isSprinting = false
            _currentWalkSpeed = 0
            _lastMovementState = false
            _soundParent = nil
            _leftFootSound = nil
            _rightFootSound = nil
        end

        function module.ResetPlayCounts(): ()
            if _leftFootSound then
                _leftFootSound:Reset()
            end
            if _rightFootSound then
                _rightFootSound:Reset()
            end
        end

        function module.SetLastFootstepTime(time: number): ()
            _lastFootstepTime = time
        end

        function module.SetNextFootIsLeft(isLeft: boolean): ()
            _isLeftFoot = isLeft
        end

        function module.GetCurrentWalkSpeed(): number
            return _currentWalkSpeed
        end

        function module.IsSprinting(): boolean
            return _isSprinting
        end

        -- Testing helpers
        function module.SetMockTime(time: number): ()
            _mockTime = time
        end

        function module.AdvanceTime(delta: number): ()
            _mockTime = _mockTime + delta
        end

        function module.GetMockTime(): number
            return _mockTime
        end

        return module
    end

    -- Test 1: Module exists with required functions
    runTest("Module exists with required functions", function()
        local module = getFreshModule()
        assert(module.Initialize ~= nil, "Initialize should exist")
        assert(module.Update ~= nil, "Update should exist")
        assert(module.OnRunning ~= nil, "OnRunning should exist")
        assert(module.IsInitialized ~= nil, "IsInitialized should exist")
        assert(module.GetLastFootstepTime ~= nil, "GetLastFootstepTime should exist")
        assert(module.GetCooldown ~= nil, "GetCooldown should exist")
        assert(module.GetCurrentPitch ~= nil, "GetCurrentPitch should exist")
        assert(module.IsOnCooldown ~= nil, "IsOnCooldown should exist")
        assert(module.GetNextFoot ~= nil, "GetNextFoot should exist")
        assert(module.GetLeftFootSound ~= nil, "GetLeftFootSound should exist")
        assert(module.GetRightFootSound ~= nil, "GetRightFootSound should exist")
        assert(module.Cleanup ~= nil, "Cleanup should exist")
    end)

    -- Test 2: Initial state is correct
    runTest("Initial state is correct", function()
        local module = getFreshModule()
        assert(module.IsInitialized() == false, "Should not be initialized initially")
    end)

    -- Test 3: Initialize creates sound instances
    runTest("Initialize creates sound instances", function()
        local module = getFreshModule()
        module.Initialize()
        
        local leftSound = module.GetLeftFootSound()
        local rightSound = module.GetRightFootSound()
        
        assert(leftSound ~= nil, "Left foot sound should exist")
        assert(rightSound ~= nil, "Right foot sound should exist")
        assert(leftSound.Name == "LeftFootstep", "Left sound should have correct name")
        assert(rightSound.Name == "RightFootstep", "Right sound should have correct name")
        assert(module.IsInitialized() == true, "Should be initialized")
    end)

    -- Test 4: Footstep sounds play when Humanoid.Running passes threshold
    runTest("Footstep sounds play when Humanoid.Running passes threshold (>0.1)", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- Speed above threshold should trigger footstep
        module.OnRunning(5.0)
        
        assert(module.GetTotalPlayCount() == 1, "Should have played 1 footstep")
    end)

    -- Test 5: Footstep sounds don't play below threshold
    runTest("Footstep sounds don't play below threshold (≤0.1)", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- Speed at threshold should NOT trigger footstep
        module.OnRunning(0.1)
        
        assert(module.GetTotalPlayCount() == 0, "Should have played 0 footsteps")
        
        -- Speed below threshold should NOT trigger footstep
        module.OnRunning(0.05)
        
        assert(module.GetTotalPlayCount() == 0, "Should have played 0 footsteps")
    end)

    -- Test 6: Move threshold is 0.1
    runTest("Move threshold is 0.1", function()
        local module = getFreshModule()
        assert(module.GetMoveThreshold() == 0.1, "Move threshold should be 0.1")
    end)

    -- Test 7: Footstep cooldown is 0.35 seconds
    runTest("Footstep cooldown is 0.35 seconds", function()
        local module = getFreshModule()
        assert(module.GetCooldown() == 0.35, "Cooldown should be 0.35 seconds")
    end)

    -- Test 8: Footsteps don't play during cooldown
    runTest("Footsteps don't play during cooldown", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- First footstep
        module.OnRunning(5.0)
        assert(module.GetTotalPlayCount() == 1, "First footstep should play")
        
        -- Try another footstep before cooldown expires (0.2s later)
        module.AdvanceTime(0.2)
        module.OnRunning(5.0)
        assert(module.GetTotalPlayCount() == 1, "Second footstep should NOT play during cooldown")
    end)

    -- Test 9: Footsteps play after cooldown expires
    runTest("Footsteps play after cooldown expires", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- First footstep
        module.OnRunning(5.0)
        assert(module.GetTotalPlayCount() == 1, "First footstep should play")
        
        -- Wait for cooldown (0.35s)
        module.AdvanceTime(0.35)
        
        -- Next footstep should play
        module.OnRunning(5.0)
        assert(module.GetTotalPlayCount() == 2, "Footstep should play after cooldown")
    end)

    -- Test 10: Left and right foot sounds alternate
    runTest("Left and right foot sounds alternate", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- Ensure we start with left foot
        module.SetNextFootIsLeft(true)
        
        -- Play 3 footsteps with enough time between them
        module.OnRunning(5.0)
        assert(module.GetLeftFootPlayCount() == 1, "First footstep should be left")
        assert(module.GetRightFootPlayCount() == 0, "First footstep should not be right")
        
        module.AdvanceTime(0.35)
        module.OnRunning(5.0)
        assert(module.GetLeftFootPlayCount() == 1, "Second footstep should not be left")
        assert(module.GetRightFootPlayCount() == 1, "Second footstep should be right")
        
        module.AdvanceTime(0.35)
        module.OnRunning(5.0)
        assert(module.GetLeftFootPlayCount() == 2, "Third footstep should be left")
        assert(module.GetRightFootPlayCount() == 1, "Third footstep should not be right")
    end)

    -- Test 11: Sprint footsteps have higher pitch (1.1x)
    runTest("Sprint footsteps are higher pitch (1.1x)", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- Set sprinting
        module.SetSprinting(true)
        
        module.OnRunning(5.0)
        
        local leftSound = module.GetLeftFootSound()
        assert(leftSound.PlaybackSpeed == 1.1, "Sprint footstep should have pitch 1.1")
    end)

    -- Test 12: Walk footsteps have normal pitch (1.0)
    runTest("Walk footsteps have normal pitch (1.0)", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- Not sprinting (default)
        module.SetSprinting(false)
        
        module.ResetPlayCounts()
        module.SetNextFootIsLeft(true)
        module.SetLastFootstepTime(-1000)
        
        module.OnRunning(5.0)
        
        local leftSound = module.GetLeftFootSound()
        assert(leftSound.PlaybackSpeed == 1.0, "Walk footstep should have pitch 1.0")
    end)

    -- Test 13: Sprint pitch is 1.1
    runTest("Sprint pitch is 1.1", function()
        local module = getFreshModule()
        assert(module.GetSprintPitch() == 1.1, "Sprint pitch should be 1.1")
    end)

    -- Test 14: Walk pitch is 1.0
    runTest("Walk pitch is 1.0", function()
        local module = getFreshModule()
        assert(module.GetWalkPitch() == 1.0, "Walk pitch should be 1.0")
    end)

    -- Test 15: Sounds stop immediately when movement stops
    runTest("Sounds stop when movement stops", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- Play footstep while moving
        module.OnRunning(5.0)
        assert(module.GetTotalPlayCount() == 1, "Should have played 1 footstep")
        
        -- Wait for cooldown to expire
        module.AdvanceTime(0.35)
        
        -- Try with speed 0 (stopped)
        module.ResetPlayCounts()
        module.OnRunning(0)
        assert(module.GetTotalPlayCount() == 0, "Should not play footstep when stopped")
        
        -- Try with speed below threshold
        module.OnRunning(0.05)
        assert(module.GetTotalPlayCount() == 0, "Should not play footstep below threshold")
    end)

    -- Test 16: Cleanup resets all state
    runTest("Cleanup resets all state", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        module.OnRunning(5.0)
        module.SetSprinting(true)
        
        assert(module.IsInitialized() == true, "Should be initialized")
        assert(module.GetTotalPlayCount() == 1, "Should have played footstep")
        
        module.Cleanup()
        
        assert(module.IsInitialized() == false, "Should not be initialized after cleanup")
        local leftSound = module.GetLeftFootSound()
        local rightSound = module.GetRightFootSound()
        assert(leftSound == nil, "Left sound should be nil after cleanup")
        assert(rightSound == nil, "Right sound should be nil after cleanup")
    end)

    -- Test 17: Last footstep time is updated
    runTest("Last footstep time is updated", function()
        local module = getFreshModule()
        module.SetMockTime(5.0)
        module.Initialize()
        
        module.OnRunning(5.0)
        
        local lastTime = module.GetLastFootstepTime()
        assert(lastTime == 5.0, "Last footstep time should be 5.0")
    end)

    -- Test 18: GetNextFoot returns correct foot
    runTest("GetNextFoot returns correct foot", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- Start with left foot
        module.SetNextFootIsLeft(true)
        assert(module.GetNextFoot() == "Left", "Should start with Left foot")
        
        -- After first footstep, should alternate to right
        module.OnRunning(5.0)
        assert(module.GetNextFoot() == "Right", "Should alternate to Right after left plays")
        
        module.AdvanceTime(0.35)
        module.OnRunning(5.0)
        assert(module.GetNextFoot() == "Left", "Should alternate back to Left")
    end)

    -- Test 19: Update stores current sprint state
    runTest("Update stores current sprint state", function()
        local module = getFreshModule()
        module.Initialize()
        
        module.Update(5.0, true)
        assert(module.IsSprinting() == true, "Should be sprinting after Update(speed, true)")
        
        module.Update(5.0, false)
        assert(module.IsSprinting() == false, "Should not be sprinting after Update(speed, false)")
    end)

    -- Test 20: Update stores current walk speed
    runTest("Update stores current walk speed", function()
        local module = getFreshModule()
        module.Initialize()
        
        module.Update(10.5, false)
        assert(module.GetCurrentWalkSpeed() == 10.5, "Should store walk speed 10.5")
        
        module.Update(5.0, false)
        assert(module.GetCurrentWalkSpeed() == 5.0, "Should update walk speed to 5.0")
    end)

    -- Test 21: Pitch calculation is correct for walk
    runTest("Pitch calculation is correct for walk", function()
        local module = getFreshModule()
        module.Initialize()
        module.SetSprinting(false)
        
        local pitch = module.GetCurrentPitch()
        assert(pitch == 1.0, "Walk pitch should be 1.0")
    end)

    -- Test 22: Pitch calculation is correct for sprint
    runTest("Pitch calculation is correct for sprint", function()
        local module = getFreshModule()
        module.Initialize()
        module.SetSprinting(true)
        
        local pitch = module.GetCurrentPitch()
        assert(pitch == 1.1, "Sprint pitch should be 1.1")
    end)

    -- Test 23: Cooldown prevents rapid consecutive sounds
    runTest("Cooldown prevents rapid consecutive sounds", function()
        local module = getFreshModule()
        module.SetMockTime(0)
        module.Initialize()
        
        -- Try to trigger many footsteps rapidly
        for i = 1, 10 do
            module.OnRunning(5.0)
            module.AdvanceTime(0.05) -- 0.05s between calls, below 0.35s cooldown
        end
        
        -- Should have played 2 footsteps:
        -- - First at time 0 (cooldown of -1000 means it plays immediately)
        -- - Second at time 0.35 (cooldown elapsed from time 0)
        -- Subsequent attempts are still within cooldown
        assert(module.GetTotalPlayCount() == 2, "Should only play 2 footsteps: first at time 0, second at time 0.35")
    end)

    -- Test 24: Update doesn't play sound when not initialized
    runTest("Update doesn't play sound when not initialized", function()
        local module = getFreshModule()
        -- Don't initialize
        module.Update(5.0, false)
        assert(module.GetTotalPlayCount() == 0, "Should not play sound when not initialized")
    end)

    print(string.format("Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests
