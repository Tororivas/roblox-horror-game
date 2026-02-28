--!strict
--[[
    PowerManager Server Script
    Initializes the power system on server start.
    This script runs automatically when the server starts.
]]

local PowerManager = require(script.Parent.PowerManager)

-- Initialize power on server start
print("[PowerManager] Initializing power system...")
print(string.format("[PowerManager] Starting power: %d%%", PowerManager.GetPower()))
print("[PowerManager] Power system initialized successfully!")
