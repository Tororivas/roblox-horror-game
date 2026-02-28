--!strict
--[[
    PowerManager Module
    Server-side module for managing the house power system.
    Tracks power state and provides controlled access to power information.
    Also tracks light states and handles power depletion.
    Power is stored server-side only and replicated via PowerChanged event.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PowerConfig = require(ReplicatedStorage.Modules.PowerConfig)

local PowerManager = {}

-- Private state (server-side only)
local currentPower: number = PowerConfig.POWER_START

-- Light states table: maps lightId -> isOn
local lightStates: {[string]: boolean} = {}

-- Get reference to PowerChanged RemoteEvent
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local PowerChangedEvent: any = EventsFolder:WaitForChild("PowerChanged")
local LightToggledEvent: any = EventsFolder:WaitForChild("LightToggled")

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
    Checks if there is power available.
    Returns true if power > MIN_POWER
    @return boolean - True if power is available (> 0)
]]
function PowerManager.HasPower(): boolean
    return currentPower > PowerConfig.MIN_POWER
end

--[[
    Gets the current state of a light.
    @param lightId string - Unique identifier for the light
    @return boolean|nil - True if on, false if off, nil if not tracked
]]
function PowerManager.GetLightState(lightId: string): boolean | nil
    return lightStates[lightId]
end

--[[
    Sets the state of a light.
    Updates the lightStates table with the current on/off state.
    @param lightId string - Unique identifier for the light
    @param isOn boolean - Whether the light is on (true) or off (false)
]]
function PowerManager.SetLightState(lightId: string, isOn: boolean): ()
    lightStates[lightId] = isOn
end

--[[
    Toggles a light on or off.
    Returns true if toggle was successful.
    - If power == 0, cannot turn on new lights (returns false)
    - If light is already on, can always turn it off
    - When turning on a light, consumes power and requires HasPower()
    @param lightId string - Unique identifier for the light
    @return boolean - True if toggle was successful
]]
function PowerManager.ToggleLight(lightId: string): boolean
    local currentState = lightStates[lightId]
    
    -- If turning on, we need power
    if not currentState then
        -- Trying to turn on
        if not PowerManager.HasPower() then
            return false -- No power, can't turn on new lights
        end
        
        -- Consume power to turn on
        if not PowerManager.DeductPower(PowerConfig.POWER_COST_PER_TOGGLE) then
            return false
        end
        
        lightStates[lightId] = true
        LightToggledEvent:FireAllClients(lightId, true)
        return true
    else
        -- Turning off - always allowed, power doesn't increase
        lightStates[lightId] = false
        LightToggledEvent:FireAllClients(lightId, false)
        return true
    end
end

--[[
    Consumes power by a specified amount.
    Returns true if power was consumed, false if insufficient power.
    @param amount number - Amount of power to consume
    @return boolean - True if power was consumed successfully
]]
function PowerManager.ConsumePower(amount: number): boolean
    if not PowerManager.HasPower() then
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
    Deducts power by a specified amount.
    Returns true if deduction was successful (power >= 0 after deduction).
    Returns false if not enough power (power would go below MIN_POWER).
    When power changes, fires PowerChanged RemoteEvent to all clients.
    @param amount number - Amount of power to deduct
    @return boolean - True if deduction was successful
]]
function PowerManager.DeductPower(amount: number): boolean
    -- Cannot deduct if it would go below MIN_POWER
    if currentPower - amount < PowerConfig.MIN_POWER then
        return false
    end
    
    -- Deduct the power
    currentPower = currentPower - amount
    
    -- Fire event to all clients with new power value
    PowerChangedEvent:FireAllClients(currentPower)
    
    return true
end

--[[
    Gets a copy of all light states.
    Returns a table with lightId -> isOn mappings.
    @return {[string]: boolean} - Table of all light states
]]
function PowerManager.GetAllLightStates(): {[string]: boolean}
    local copy: {[string]: boolean} = {}
    for id, state in pairs(lightStates) do
        copy[id] = state
    end
    return copy
end

--[[
    Resets power to the starting value.
    Clears all light states as well.
    Used for testing or game restart scenarios.
]]
function PowerManager.Reset(): ()
    currentPower = PowerConfig.POWER_START
    
    -- Clear all light states
    for key in pairs(lightStates) do
        lightStates[key] = nil
    end
end

return PowerManager
