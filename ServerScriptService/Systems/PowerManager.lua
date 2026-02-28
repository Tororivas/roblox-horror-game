--!strict
--[[
    PowerManager Module
    Server-side module for managing the house power system.
    Tracks power state and provides controlled access to power information.
    Power is stored server-side only and not directly replicated.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PowerConfig = require(ReplicatedStorage.Modules.PowerConfig)

local PowerManager = {}

-- Private state (server-side only)
local currentPower: number = PowerConfig.POWER_START

--[[
    Returns the current power value.
    @return number - Current power percentage (0-100)
]]
function PowerManager.GetPower(): number
    return currentPower
end

--[[
    Sets the current power value.
    This is an internal function used by the power system.
    @param newPower number - New power value
]]
function PowerManager.SetPower(newPower: number): ()
    currentPower = math.clamp(newPower, PowerConfig.MIN_POWER, PowerConfig.POWER_START)
end

--[[
    Consumes power by a specified amount.
    Returns true if power was consumed, false if insufficient power.
    @param amount number - Amount of power to consume
    @return boolean - True if power was consumed successfully
]]
function PowerManager.ConsumePower(amount: number): boolean
    if currentPower <= PowerConfig.MIN_POWER then
        return false
    end
    
    local newPower = currentPower - amount
    if newPower < PowerConfig.MIN_POWER then
        currentPower = PowerConfig.MIN_POWER
    else
        currentPower = newPower
    end
    
    return true
end

--[[
    Checks if there is power available.
    @return boolean - True if power is available (> 0)
]]
function PowerManager.HasPower(): boolean
    return currentPower > PowerConfig.MIN_POWER
end

--[[
    Resets power to the starting value.
    Used for testing or game restart scenarios.
]]
function PowerManager.Reset(): ()
    currentPower = PowerConfig.POWER_START
end

return PowerManager
