--!strict
--[[
    SanityManager Module
    Manages player sanity system for the Roblox Horror Game.
    Sanity depletes over time based on movement state (walking vs sprinting).
    Sanity is replicated to the server via a NumberValue in the player.
]]

-- Module table
local SanityManager = {}

-- Private state
local _isInitialized: boolean = false
local _currentSanity: number = 100
local _isSprinting: boolean = false
local _isMoving: boolean = false

-- Configuration
local SANITY_MIN: number = 0
local SANITY_MAX: number = 100
local SANITY_WALK_DEPLETION_RATE: number = 0.01 -- per second
local SANITY_SPRINT_DEPLETION_RATE: number = 0.05 -- per second
local SANITY_DEFAULT: number = 100

-- Rate tracking for testing
local _currentDepletionRate: number = 0

-- Replication
local _sanityValue: any? = nil
local _player: any? = nil

-- Mock services
local MockPlayers = {
    LocalPlayer = {
        UserId = 1,
        Name = "TestPlayer",
        FindFirstChild = function(_self: any, _name: string): any?
            return nil
        end,
        WaitForChild = function(_self: any, _name: string): any?
            return nil
        end,
    },
}

local Players: any = MockPlayers

-- Try to get real Players service
local success: boolean, result: any = pcall(function()
    return (game :: any):GetService("Players")
end)
if success then
    Players = result
end

-- Mock NumberValue for testing
local MockNumberValue: any = nil

MockNumberValue = {
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

-- Create a NumberValue (works in both Roblox and test environments)
local function CreateNumberValue(name: string, initialValue: number, parent: any?): any
    local value: any = nil
    
    -- Try to get Instance if available (Roblox environment)
    local success2: boolean = pcall(function()
        return _G.Instance or (game :: any).Instance
    end)
    
    if success2 then
        local Instance = _G.Instance or (game :: any).Instance
        value = Instance.new("NumberValue")
        value.Name = name
        value.Value = initialValue
        if parent then
            value.Parent = parent
        end
    else
        -- Use mock for testing
        value = MockNumberValue.new()
        value.Name = name
        value:SetValue(initialValue)
        if parent then
            value.Parent = parent
        end
    end
    
    return value
end

-- Get current time (tick for Roblox, os.clock for standard Lua)
local function _GetCurrentTime(): number
    if tick then
        return tick()
    end
    return os.clock()
end

-- Initialize the sanity manager
function SanityManager.Initialize(player: any?): ()
    if _isInitialized then
        return
    end
    
    -- Get player from argument or service
    if player then
        _player = player
    elseif Players and Players.LocalPlayer then
        _player = Players.LocalPlayer
    end
    
    -- Reset sanity to default
    _currentSanity = SANITY_DEFAULT
    _isSprinting = false
    _isMoving = false
    _currentDepletionRate = 0
    
    -- Create sanity value for replication
    if _player then
        -- Check if already exists
        local existingValue = _player:FindFirstChild("SanityValue")
        if existingValue then
            _sanityValue = existingValue
            if _sanityValue then
                _sanityValue.Value = _currentSanity
            end
        else
            _sanityValue = CreateNumberValue("SanityValue", _currentSanity, _player)
        end
    end
    
    _isInitialized = true
end

-- Get current sanity value
function SanityManager.GetSanity(): number
    return _currentSanity
end

-- Set sanity value (clamped to valid range)
function SanityManager.SetSanity(value: number): ()
    -- Clamp to valid range
    local clampedValue = math.clamp(value, SANITY_MIN, SANITY_MAX)
    _currentSanity = clampedValue
    
    -- Update replicated value
    if _sanityValue and _sanityValue.SetValue then
        _sanityValue:SetValue(_currentSanity)
    elseif _sanityValue then
        _sanityValue.Value = _currentSanity
    end
end

-- Get minimum sanity value
function SanityManager.GetMinSanity(): number
    return SANITY_MIN
end

-- Get maximum sanity value
function SanityManager.GetMaxSanity(): number
    return SANITY_MAX
end

-- Get current sanity as a percentage (0-100%)
function SanityManager.GetSanityPercent(): number
    return (_currentSanity / SANITY_MAX) * 100
end

-- Get default starting sanity
function SanityManager.GetDefaultSanity(): number
    return SANITY_DEFAULT
end

-- Check if initialized
function SanityManager.IsInitialized(): boolean
    return _isInitialized
end

-- Set sprint state
function SanityManager.SetSprinting(isSprinting: boolean): ()
    _isSprinting = isSprinting
end

-- Set moving state
function SanityManager.SetMoving(isMoving: boolean): ()
    _isMoving = isMoving
end

-- Get current sprint state
function SanityManager.IsSprinting(): boolean
    return _isSprinting
end

-- Get current moving state
function SanityManager.IsMoving(): boolean
    return _isMoving
end

-- Get current depletion rate
function SanityManager.GetCurrentDepletionRate(): number
    return _currentDepletionRate
end

-- Get depletion rates
function SanityManager.GetWalkDepletionRate(): number
    return SANITY_WALK_DEPLETION_RATE
end

function SanityManager.GetSprintDepletionRate(): number
    return SANITY_SPRINT_DEPLETION_RATE
end

-- Get the replicated NumberValue instance
function SanityManager.GetSanityValue(): any?
    return _sanityValue
end

-- Update sanity based on elapsed time and movement state
-- Call this from the main update loop (e.g., RenderStepped)
-- deltaTime: time since last update in seconds
function SanityManager.Update(deltaTime: number): ()
    if not _isInitialized then
        return
    end
    
    -- Only deplete sanity if moving
    if not _isMoving then
        _currentDepletionRate = 0
        return
    end
    
    -- Calculate depletion based on sprint state
    local depletionRate: number
    if _isSprinting then
        depletionRate = SANITY_SPRINT_DEPLETION_RATE
    else
        depletionRate = SANITY_WALK_DEPLETION_RATE
    end
    
    _currentDepletionRate = depletionRate
    
    -- Calculate sanity reduction
    local sanityLoss = depletionRate * deltaTime
    local newSanity = _currentSanity - sanityLoss
    
    -- Update sanity (clamped automatically by SetSanity)
    SanityManager.SetSanity(newSanity)
end

-- Update from movement state (convenience method)
-- Call this with current movement state from PlayerController
function SanityManager.UpdateFromMovementState(isMoving: boolean, isSprinting: boolean, deltaTime: number): ()
    _isMoving = isMoving
    _isSprinting = isSprinting
    SanityManager.Update(deltaTime)
end

-- Check if sanity is at minimum
function SanityManager.IsAtMinSanity(): boolean
    return _currentSanity <= SANITY_MIN
end

-- Check if sanity is at maximum
function SanityManager.IsAtMaxSanity(): boolean
    return _currentSanity >= SANITY_MAX
end

-- Reset sanity to default value
function SanityManager.ResetSanity(): ()
    SanityManager.SetSanity(SANITY_DEFAULT)
end

-- Calculate sanity after time elapsed (for testing/prediction)
-- Returns predicted sanity value without modifying current state
function SanityManager.CalculateSanityAfterSeconds(seconds: number, isMoving: boolean, isSprinting: boolean): number
    if not isMoving then
        return _currentSanity
    end
    
    local depletionRate = isSprinting and SANITY_SPRINT_DEPLETION_RATE or SANITY_WALK_DEPLETION_RATE
    local sanityLoss = depletionRate * seconds
    local predictedSanity = _currentSanity - sanityLoss
    
    return math.clamp(predictedSanity, SANITY_MIN, SANITY_MAX)
end

-- Force replicate current sanity (for debugging)
function SanityManager.ForceReplicate(): ()
    if _sanityValue then
        if _sanityValue.SetValue then
            _sanityValue:SetValue(_currentSanity)
        else
            _sanityValue.Value = _currentSanity
        end
    end
end

-- Get the internal player reference (for testing)
function SanityManager.GetPlayer(): any?
    return _player
end

-- Cleanup the sanity manager
function SanityManager.Cleanup(): ()
    -- Destroy sanity value
    if _sanityValue then
        local success2: boolean = pcall(function()
            if _sanityValue.Destroy then
                _sanityValue:Destroy()
            end
        end)
        -- Ignore pcall errors for mock cleanup
    end
    
    -- Reset state
    _isInitialized = false
    _currentSanity = SANITY_DEFAULT
    _isSprinting = false
    _isMoving = false
    _currentDepletionRate = 0
    _sanityValue = nil
    _player = nil
end

-- Set mock player and value directly (for testing)
function SanityManager.SetMockPlayer(player: any?): ()
    _player = player
end

-- Create mock sanity value directly (for testing)
function SanityManager.CreateMockSanityValue(): any
    local mockValue = MockNumberValue.new()
    mockValue:SetValue(_currentSanity)
    _sanityValue = mockValue
    return mockValue
end

return SanityManager