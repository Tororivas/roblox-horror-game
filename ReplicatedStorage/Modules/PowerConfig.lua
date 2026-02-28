--!strict
--[[
    PowerConfig Module
    Centralized configuration module for power system constants.
    Shared between server and client for consistent power system behavior.
]]

local PowerConfig = {
    -- Initial power percentage when game starts
    POWER_START = 100,
    
    -- Power consumed per light toggle (percent)
    POWER_COST_PER_TOGGLE = 10,
    
    -- Minimum power threshold (game over for power when this is reached)
    MIN_POWER = 0,
}

return PowerConfig
