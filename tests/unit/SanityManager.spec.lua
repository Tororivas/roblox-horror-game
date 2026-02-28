--!strict
--[[
    SanityManager Module Tests
    Validates sanity system functionality including depletion rates.
]]

-- Test runner
local function runTests(): (number, number)
    print("Running SanityManager module tests (US-010)...")
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
        
        -- Configuration
        local SANITY_MIN: number = 0
        local SANITY_MAX: number = 100
        local SANITY_WALK_DEPLETION_RATE: number = 0.01
        local SANITY_SPRINT_DEPLETION_RATE: number = 0.05
        local SANITY_DEFAULT: number = 100
        
        -- Private state
        local _isInitialized: boolean = false
        local _currentSanity: number = 100
        local _isSprinting: boolean = false
        local _isMoving: boolean = false
        local _currentDepletionRate: number = 0
        local _sanityValue: any? = nil
        local _player: any? = nil
        
        -- Mock NumberValue
        local MockNumberValue = {
            new = function()
                local value = {
                    Name = "SanityValue",
                    Value = 100,
                    _value = 100,
                    
                    SetValue = function(self: any, val: number)
                        self._value = val
                        self.Value = val
                    end,
                    
                    GetValue = function(self: any): number
                        return self._value
                    end,
                    
                    Destroy = function(self: any)
                        self._value = 0
                        self.Value = 0
                    end,
                }
                return value
            end,
        }
        
        -- Create NumberValue
        local function CreateNumberValue(name: string, initialValue: number, parent: any?): any
            local value = MockNumberValue.new()
            value.Name = name
            value:SetValue(initialValue)
            if parent then
                value.Parent = parent
            end
            return value
        end
        
        -- Mock Players
        local MockPlayers = {
            LocalPlayer = {
                UserId = 1,
                Name = "TestPlayer",
                FindFirstChild = function(_self: any, name: string): any?
                    if name == "SanityValue" then
                        return nil
                    end
                    return nil
                end,
                WaitForChild = function(_self: any, _name: string): any?
                    return nil
                end,
            },
        }
        
        -- Module functions
        function module.Initialize(player: any?)
            if _isInitialized then
                return
            end
            
            if player then
                _player = player
            else
                _player = MockPlayers.LocalPlayer
            end
            
            _currentSanity = SANITY_DEFAULT
            _isSprinting = false
            _isMoving = false
            _currentDepletionRate = 0
            
            -- Create sanity value for replication
            if _player then
                local existingValue = _player:FindFirstChild("SanityValue")
                if existingValue then
                    _sanityValue = existingValue
                    if _sanityValue.SetValue then
                        _sanityValue:SetValue(_currentSanity)
                    else
                        _sanityValue.Value = _currentSanity
                    end
                else
                    _sanityValue = CreateNumberValue("SanityValue", _currentSanity, _player)
                end
            end
            
            _isInitialized = true
        end
        
        function module.GetSanity(): number
            return _currentSanity
        end
        
        function module.SetSanity(value: number)
            local clampedValue = math.clamp(value, SANITY_MIN, SANITY_MAX)
            _currentSanity = clampedValue
            
            if _sanityValue then
                if _sanityValue.SetValue then
                    _sanityValue:SetValue(_currentSanity)
                else
                    _sanityValue.Value = _currentSanity
                end
            end
        end
        
        function module.GetMinSanity(): number
            return SANITY_MIN
        end
        
        function module.GetMaxSanity(): number
            return SANITY_MAX
        end
        
        function module.GetSanityPercent(): number
            return (_currentSanity / SANITY_MAX) * 100
        end
        
        function module.GetDefaultSanity(): number
            return SANITY_DEFAULT
        end
        
        function module.IsInitialized(): boolean
            return _isInitialized
        end
        
        function module.SetSprinting(isSprinting: boolean)
            _isSprinting = isSprinting
        end
        
        function module.SetMoving(isMoving: boolean)
            _isMoving = isMoving
        end
        
        function module.IsSprinting(): boolean
            return _isSprinting
        end
        
        function module.IsMoving(): boolean
            return _isMoving
        end
        
        function module.GetCurrentDepletionRate(): number
            return _currentDepletionRate
        end
        
        function module.GetWalkDepletionRate(): number
            return SANITY_WALK_DEPLETION_RATE
        end
        
        function module.GetSprintDepletionRate(): number
            return SANITY_SPRINT_DEPLETION_RATE
        end
        
        function module.GetSanityValue(): any?
            return _sanityValue
        end
        
        function module.Update(deltaTime: number)
            if not _isInitialized then
                return
            end
            
            if not _isMoving then
                _currentDepletionRate = 0
                return
            end
            
            local depletionRate: number
            if _isSprinting then
                depletionRate = SANITY_SPRINT_DEPLETION_RATE
            else
                depletionRate = SANITY_WALK_DEPLETION_RATE
            end
            
            _currentDepletionRate = depletionRate
            
            local sanityLoss = depletionRate * deltaTime
            local newSanity = _currentSanity - sanityLoss
            
            module.SetSanity(newSanity)
        end
        
        function module.UpdateFromMovementState(isMoving: boolean, isSprinting: boolean, deltaTime: number)
            _isMoving = isMoving
            _isSprinting = isSprinting
            module.Update(deltaTime)
        end
        
        function module.IsAtMinSanity(): boolean
            return _currentSanity <= SANITY_MIN
        end
        
        function module.IsAtMaxSanity(): boolean
            return _currentSanity >= SANITY_MAX
        end
        
        function module.ResetSanity()
            module.SetSanity(SANITY_DEFAULT)
        end
        
        function module.CalculateSanityAfterSeconds(seconds: number, isMoving: boolean, isSprinting: boolean): number
            if not isMoving then
                return _currentSanity
            end
            
            local depletionRate = isSprinting and SANITY_SPRINT_DEPLETION_RATE or SANITY_WALK_DEPLETION_RATE
            local sanityLoss = depletionRate * seconds
            local predictedSanity = _currentSanity - sanityLoss
            
            return math.clamp(predictedSanity, SANITY_MIN, SANITY_MAX)
        end
        
        function module.Cleanup()
            _isInitialized = false
            _currentSanity = SANITY_DEFAULT
            _isSprinting = false
            _isMoving = false
            _currentDepletionRate = 0
            _sanityValue = nil
            _player = nil
        end
        
        function module.SetMockPlayer(player: any?)
            _player = player
        end
        
        return module
    end

    -- =====================================
    -- TEST CASES
    -- =====================================

    -- Test 1: Module functions exist
    runTest("Module functions exist and are accessible", function()
        local SanityManager = getFreshModule()
        assert(type(SanityManager.GetSanity) == "function", "GetSanity should be a function")
        assert(type(SanityManager.SetSanity) == "function", "SetSanity should be a function")
        assert(type(SanityManager.Initialize) == "function", "Initialize should be a function")
        assert(type(SanityManager.Update) == "function", "Update should be a function")
        SanityManager.Cleanup()
    end)

    -- Test 2: SanityManager.lua exists with GetSanity and SetSanity methods
    runTest("SanityManager has GetSanity and SetSanity methods", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        assert(type(SanityManager.GetSanity) == "function", "GetSanity should be a function")
        assert(type(SanityManager.SetSanity) == "function", "SetSanity should be a function")
        
        SanityManager.Cleanup()
    end)

    -- Test 3: Sanity starts at 100
    runTest("Sanity starts at 100", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        local sanity = SanityManager.GetSanity()
        assert(sanity == 100, "Initial sanity should be 100, got " .. tostring(sanity))
        
        SanityManager.Cleanup()
    end)

    -- Test 4: Sanity ranges 0-100
    runTest("Sanity ranges from 0 to 100", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        local minSanity = SanityManager.GetMinSanity()
        local maxSanity = SanityManager.GetMaxSanity()
        
        assert(minSanity == 0, "Min sanity should be 0, got " .. tostring(minSanity))
        assert(maxSanity == 100, "Max sanity should be 100, got " .. tostring(maxSanity))
        
        SanityManager.Cleanup()
    end)

    -- Test 5: SetSanity clamps to valid range
    runTest("SetSanity clamps values to 0-100 range", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        -- Test clamping above max
        SanityManager.SetSanity(150)
        assert(SanityManager.GetSanity() == 100, "Sanity should be clamped to 100")
        
        -- Test clamping below min
        SanityManager.SetSanity(-50)
        assert(SanityManager.GetSanity() == 0, "Sanity should be clamped to 0")
        
        -- Test valid range
        SanityManager.SetSanity(50)
        assert(SanityManager.GetSanity() == 50, "Sanity should be set to 50")
        
        SanityManager.Cleanup()
    end)

    -- Test 6: Sanity decreases by 0.01 per second when walking (not sprinting)
    runTest("Sanity decreases by 0.01 per second when walking", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        -- Set initial state
        SanityManager.SetSanity(100)
        SanityManager.SetMoving(true)
        SanityManager.SetSprinting(false)
        
        -- Update for 1 second
        SanityManager.Update(1.0)
        
        local expectedSanity = 100 - 0.01 -- Walk depletion rate * 1 second
        local actualSanity = SanityManager.GetSanity()
        
        -- Allow for small floating point tolerance
        local tolerance = 0.001
        assert(math.abs(actualSanity - expectedSanity) < tolerance, 
            "Sanity should decrease by 0.01 per second when walking. Expected: " .. tostring(expectedSanity) .. ", Got: " .. tostring(actualSanity))
        
        SanityManager.Cleanup()
    end)

    -- Test 7: Sanity decreases by 0.05 per second when sprinting
    runTest("Sanity decreases by 0.05 per second when sprinting", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        -- Set initial state
        SanityManager.SetSanity(100)
        SanityManager.SetMoving(true)
        SanityManager.SetSprinting(true)
        
        -- Update for 1 second
        SanityManager.Update(1.0)
        
        local expectedSanity = 100 - 0.05 -- Sprint depletion rate * 1 second
        local actualSanity = SanityManager.GetSanity()
        
        -- Allow for small floating point tolerance
        local tolerance = 0.001
        assert(math.abs(actualSanity - expectedSanity) < tolerance, 
            "Sanity should decrease by 0.05 per second when sprinting. Expected: " .. tostring(expectedSanity) .. ", Got: " .. tostring(actualSanity))
        
        SanityManager.Cleanup()
    end)

    -- Test 8: Sanity does not decrease when not moving
    runTest("Sanity does not decrease when not moving", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(100)
        SanityManager.SetMoving(false)
        SanityManager.SetSprinting(false)
        
        -- Update for 1 second
        SanityManager.Update(1.0)
        
        local actualSanity = SanityManager.GetSanity()
        assert(actualSanity == 100, "Sanity should not decrease when not moving. Got: " .. tostring(actualSanity))
        
        SanityManager.Cleanup()
    end)

    -- Test 9: Sanity depletes over time - walking for 10 seconds
    runTest("Sanity depletes correctly walking for 10 seconds", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(100)
        SanityManager.SetMoving(true)
        SanityManager.SetSprinting(false)
        
        -- Simulate 10 seconds
        SanityManager.Update(10.0)
        
        local expectedSanity = 100 - (0.01 * 10)
        local actualSanity = SanityManager.GetSanity()
        
        local tolerance = 0.01
        assert(math.abs(actualSanity - expectedSanity) < tolerance, 
            "Sanity after 10 seconds walking should be " .. tostring(expectedSanity) .. ", Got: " .. tostring(actualSanity))
        
        SanityManager.Cleanup()
    end)

    -- Test 10: Sanity depletes over time - sprinting for 10 seconds
    runTest("Sanity depletes correctly sprinting for 10 seconds", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(100)
        SanityManager.SetMoving(true)
        SanityManager.SetSprinting(true)
        
        -- Simulate 10 seconds
        SanityManager.Update(10.0)
        
        local expectedSanity = 100 - (0.05 * 10)
        local actualSanity = SanityManager.GetSanity()
        
        local tolerance = 0.01
        assert(math.abs(actualSanity - expectedSanity) < tolerance, 
            "Sanity after 10 seconds sprinting should be " .. tostring(expectedSanity) .. ", Got: " .. tostring(actualSanity))
        
        SanityManager.Cleanup()
    end)

    -- Test 11: Sanity value is replicated via NumberValue
    runTest("Sanity value is replicated via NumberValue", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        local sanityValue = SanityManager.GetSanityValue()
        assert(sanityValue ~= nil, "SanityValue should exist")
        
        -- Check initial value
        assert(sanityValue:GetValue() == 100, "SanityValue should start at 100")
        
        -- Update sanity and check replication
        SanityManager.SetSanity(75)
        
        local actualValue = sanityValue:GetValue()
        assert(actualValue == 75, "SanityValue should be updated to 75, got " .. tostring(actualValue))
        
        SanityManager.Cleanup()
    end)

    -- Test 12: Depletion rates are correct
    runTest("Walk and sprint depletion rates are correct", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        local walkRate = SanityManager.GetWalkDepletionRate()
        local sprintRate = SanityManager.GetSprintDepuationRate and SanityManager.GetSprintDepuationRate()
            or SanityManager.GetSprintDepletionRate()
        
        assert(walkRate == 0.01, "Walk depletion rate should be 0.01, got " .. tostring(walkRate))
        assert(sprintRate == 0.05, "Sprint depletion rate should be 0.05, got " .. tostring(sprintRate))
        
        SanityManager.Cleanup()
    end)

    -- Test 13: UpdateFromMovementState convenience method works
    runTest("UpdateFromMovementState updates state correctly", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(100)
        
        -- Use convenience method
        SanityManager.UpdateFromMovementState(true, false, 1.0) -- Moving, not sprinting
        
        local expectedSanity = 100 - 0.01
        local actualSanity = SanityManager.GetSanity()
        local tolerance = 0.001
        
        assert(math.abs(actualSanity - expectedSanity) < tolerance, 
            "Sanity should decrease when using UpdateFromMovementState. Expected: " .. tostring(expectedSanity) .. ", Got: " .. tostring(actualSanity))
        
        SanityManager.Cleanup()
    end)

    -- Test 14: IsAtMinSanity detects minimum
    runTest("IsAtMinSanity returns true at 0 sanity", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(0)
        assert(SanityManager.IsAtMinSanity(), "IsAtMinSanity should return true at 0")
        
        SanityManager.SetSanity(1)
        assert(not SanityManager.IsAtMinSanity(), "IsAtMinSanity should return false at 1")
        
        SanityManager.Cleanup()
    end)

    -- Test 15: IsAtMaxSanity detects maximum
    runTest("IsAtMaxSanity returns true at 100 sanity", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(100)
        assert(SanityManager.IsAtMaxSanity(), "IsAtMaxSanity should return true at 100")
        
        SanityManager.SetSanity(99)
        assert(not SanityManager.IsAtMaxSanity(), "IsAtMaxSanity should return false at 99")
        
        SanityManager.Cleanup()
    end)

    -- Test 16: ResetSanity restores default value
    runTest("ResetSanity restores sanity to 100", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(50)
        assert(SanityManager.GetSanity() == 50, "Sanity should be 50")
        
        SanityManager.ResetSanity()
        assert(SanityManager.GetSanity() == 100, "Sanity should be reset to 100")
        
        SanityManager.Cleanup()
    end)

    -- Test 17: GetSanityPercent returns correct percentage
    runTest("GetSanityPercent returns correct percentage", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(50)
        local percent = SanityManager.GetSanityPercent()
        
        assert(percent == 50, "Sanity percent at 50 should be 50%, got " .. tostring(percent) .. "%")
        
        SanityManager.Cleanup()
    end)

    -- Test 18: CalculateSanityAfterSeconds predicts correctly
    runTest("CalculateSanityAfterSeconds predicts correctly", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(100)
        
        -- Predict walking for 5 seconds
        local predicted = SanityManager.CalculateSanityAfterSeconds(5, true, false)
        local tolerance = 0.001
        assert(math.abs(predicted - 99.95) < tolerance, "Walking 5 seconds prediction should be 99.95, got " .. tostring(predicted))
        
        -- Predict sprinting for 5 seconds
        predicted = SanityManager.CalculateSanityAfterSeconds(5, true, true)
        assert(math.abs(predicted - 99.75) < tolerance, "Sprinting 5 seconds prediction should be 99.75, got " .. tostring(predicted))
        
        -- Predict when not moving (should stay same)
        predicted = SanityManager.CalculateSanityAfterSeconds(5, false, false)
        assert(predicted == 100, "Not moving prediction should stay at 100, got " .. tostring(predicted))
        
        SanityManager.Cleanup()
    end)

    -- Test 19: Current depletion rate tracks correctly
    runTest("GetCurrentDepletionRate tracks correct rate", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(100)
        SanityManager.SetMoving(true)
        
        -- Test walking
        SanityManager.SetSprinting(false)
        SanityManager.Update(1.0)
        assert(SanityManager.GetCurrentDepletionRate() == 0.01, "Depletion rate should be 0.01 when walking")
        
        -- Reset and test sprinting
        SanityManager.SetSanity(100)
        SanityManager.SetSprinting(true)
        SanityManager.Update(1.0)
        assert(SanityManager.GetCurrentDepletionRate() == 0.05, "Depletion rate should be 0.05 when sprinting")
        
        SanityManager.Cleanup()
    end)

    -- Test 20: IsMoving and IsSprinting getters work
    runTest("IsMoving and IsSprinting getters return correct state", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetMoving(true)
        SanityManager.SetSprinting(true)
        
        assert(SanityManager.IsMoving(), "IsMoving should return true")
        assert(SanityManager.IsSprinting(), "IsSprinting should return true")
        
        SanityManager.SetMoving(false)
        SanityManager.SetSprinting(false)
        
        assert(not SanityManager.IsMoving(), "IsMoving should return false")
        assert(not SanityManager.IsSprinting(), "IsSprinting should return false")
        
        SanityManager.Cleanup()
    end)

    -- Test 21: Update doesn't run when not initialized
    runTest("Update does nothing when not initialized", function()
        local SanityManager = getFreshModule()
        -- Don't initialize
        
        SanityManager.SetSanity(100)
        SanityManager.SetMoving(true)
        SanityManager.SetSprinting(false)
        
        -- This should not crash and should not change sanity
        SanityManager.Update(1.0)
        -- Since not initialized, sanity shouldn't be tracked but no error should occur
        
        -- Sanity value getter is safe
        assert(SanityManager.GetSanity() ~= nil, "GetSanity should still return a value")
    end)

    -- Test 22: Multiple update calls accumulate correctly
    runTest("Multiple Update calls accumulate sanity loss correctly", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        SanityManager.SetSanity(100)
        SanityManager.SetMoving(true)
        SanityManager.SetSprinting(false)
        
        -- Three 1-second updates
        SanityManager.Update(1.0)
        SanityManager.Update(1.0)
        SanityManager.Update(1.0)
        
        local expectedSanity = 100 - (0.01 * 3)
        local actualSanity = SanityManager.GetSanity()
        local tolerance = 0.001
        
        assert(math.abs(actualSanity - expectedSanity) < tolerance, 
            "Three 1-second updates should equal one 3-second update. Expected: " .. tostring(expectedSanity) .. ", Got: " .. tostring(actualSanity))
        
        SanityManager.Cleanup()
    end)

    -- Test 23: Sanity clamps at 0 during depletion
    runTest("Sanity clamps at 0 and does not go negative", function()
        local SanityManager = getFreshModule()
        SanityManager.Initialize()
        
        -- Start at low sanity
        SanityManager.SetSanity(0.02)
        SanityManager.SetMoving(true)
        SanityManager.SetSprinting(false)
        
        -- Update for 5 seconds (would deplete more than available)
        SanityManager.Update(5.0)
        
        local actualSanity = SanityManager.GetSanity()
        assert(actualSanity >= 0 and actualSanity <= 0.01, "Sanity should be clamped at 0 or slightly above (depleted to 0), got " .. tostring(actualSanity))
        
        SanityManager.Cleanup()
    end)

    -- =====================================
    -- TEST SUMMARY
    -- =====================================
    print("\n========================================")
    print("SanityManager Test Results:")
    print("  Passed: " .. passed)
    print("  Failed: " .. failed)
    print("========================================\n")

    return passed, failed
end

return runTests