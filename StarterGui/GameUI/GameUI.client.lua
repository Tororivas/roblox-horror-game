--!strict
--[[
    GameUI.client.lua
    Main UI controller that orchestrates all UI components.
    Listens for game events from ReplicatedStorage and coordinates
    between SanityBar, PowerBar, InteractPrompt, LowSanityOverlay, and DeathScreen.
]]

-- Forward declare Roblox globals
local _task: any = nil
local _RBXScriptConnection: any = nil
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if not player then
    warn("GameUI: Cannot find LocalPlayer")
    return
end

-- Configuration
local CONFIG: any = {
    -- Low sanity threshold
    lowSanityThreshold = 20,
}

local GameUIController = {}
GameUIController.__index = GameUIController

-- Create the GameUI controller
function GameUIController.new()
    local self = setmetatable({}, GameUIController)
    
    -- Initialize component references (will be loaded lazily)
    self.components = {
        SanityBar = nil,
        PowerBar = nil,
        InteractPrompt = nil,
        LowSanityOverlay = nil,
        DeathScreen = nil,
    }
    
    -- Initialize state
    self.state = {
        currentSanity = 100,
        maxSanity = 100,
        currentPower = 100,
        maxPower = 100,
        isDead = false,
        isLowSanity = false,
        currentInteractTarget = nil,
    }
    
    -- Store references to events
    self.events = {}
    
    return self
end

-- Lazy load component helper
function GameUIController._getSanityBar(self: any)
    if not self.components.SanityBar then
        local success, SanityBar = pcall(function()
            local module = script.Parent:FindFirstChild("SanityBar")
            if module then
                local m = require(module)
                if m.Init then
                    m.Init()
                end
                return m
            end
            return nil
        end)
        if success then
            self.components.SanityBar = SanityBar
        end
    end
    return self.components.SanityBar
end

function GameUIController._getPowerBar(self: any)
    if not self.components.PowerBar then
        local success, PowerBar = pcall(function()
            local module = script.Parent:FindFirstChild("PowerBar")
            if module then
                local m = require(module)
                if m.Init then
                    m.Init()
                end
                return m
            end
            return nil
        end)
        if success then
            self.components.PowerBar = PowerBar
        end
    end
    return self.components.PowerBar
end

function GameUIController._getInteractPrompt(self: any)
    if not self.components.InteractPrompt then
        local success, InteractPrompt = pcall(function()
            local module = script.Parent:FindFirstChild("InteractPrompt")
            if module then
                local m = require(module)
                if m.Init then
                    m.Init()
                end
                return m
            end
            return nil
        end)
        if success then
            self.components.InteractPrompt = InteractPrompt
        end
    end
    return self.components.InteractPrompt
end

function GameUIController._getLowSanityOverlay(self: any)
    if not self.components.LowSanityOverlay then
        local success, LowSanityOverlay = pcall(function()
            local module = script.Parent:FindFirstChild("LowSanityOverlay")
            if module then
                local m = require(module)
                if m.Init then
                    m.Init()
                end
                return m
            end
            return nil
        end)
        if success then
            self.components.LowSanityOverlay = LowSanityOverlay
        end
    end
    return self.components.LowSanityOverlay
end

function GameUIController._getDeathScreen(self: any)
    if not self.components.DeathScreen then
        local success, DeathScreen = pcall(function()
            local module = script.Parent:FindFirstChild("DeathScreen")
            if module then
                local m = require(module)
                if m.Init then
                    m.Init()
                end
                return m
            end
            return nil
        end)
        if success then
            self.components.DeathScreen = DeathScreen
        end
    end
    return self.components.DeathScreen
end

-- Update sanity across all components
function GameUIController.updateSanity(self: any, value: number, maxValue: number?)
    local maxSanity: number = maxValue or self.state.maxSanity
    
    -- Update state
    self.state.currentSanity = math.clamp(value, 0, maxSanity)
    self.state.maxSanity = maxSanity
    
    -- Update SanityBar if available
    local sanityBar = self:_getSanityBar()
    if sanityBar and sanityBar.SetSanity then
        sanityBar.SetSanity(self.state.currentSanity)
    end
    
    -- Check for death
    if self.state.currentSanity <= 0 then
        self.state.isDead = true
        self:showDeathScreen()
    else
        -- Check for low sanity warning
        self:updateLowSanityState()
        
        -- Hide death screen if revived
        if self.state.isDead then
            self.state.isDead = false
            self:hideDeathScreen()
        end
    end
end

-- Update power across relevant components
function GameUIController.updatePower(self: any, value: number, maxValue: number?)
    local maxPower: number = maxValue or self.state.maxPower
    
    -- Update state
    self.state.currentPower = math.clamp(value, 0, maxPower)
    self.state.maxPower = maxPower
    
    -- Update PowerBar if available
    local powerBar = self:_getPowerBar()
    if powerBar and powerBar.SetPower then
        powerBar.SetPower(self.state.currentPower)
    end
end

-- Show interaction prompt
function GameUIController.showInteractPrompt(self: any, actionText: string, target: any?)
    self.state.currentInteractTarget = target
    
    local interactPrompt = self:_getInteractPrompt()
    if interactPrompt and interactPrompt.Show then
        interactPrompt.Show(actionText, target)
    end
end

-- Hide interaction prompt
function GameUIController.hideInteractPrompt(self: any)
    self.state.currentInteractTarget = nil
    
    local interactPrompt = self:_getInteractPrompt()
    if interactPrompt and interactPrompt.Hide then
        interactPrompt.Hide()
    end
end

-- Update low sanity overlay state
function GameUIController.updateLowSanityState(self: any)
    local isLowSanity: boolean = self.state.currentSanity < CONFIG.lowSanityThreshold
    
    -- Only update if state changed
    if isLowSanity ~= self.state.isLowSanity then
        self.state.isLowSanity = isLowSanity
        
        -- Update LowSanityOverlay if available
        local overlay = self:_getLowSanityOverlay()
        if overlay then
            if isLowSanity and overlay.Show then
                overlay.Show()
            elseif not isLowSanity and overlay.Hide then
                overlay.Hide()
            end
        end
    end
end

-- Show death screen
function GameUIController.showDeathScreen(self: any)
    local deathScreen = self:_getDeathScreen()
    if deathScreen and deathScreen.Show then
        deathScreen.Show()
    end
end

-- Hide death screen
function GameUIController.hideDeathScreen(self: any)
    local deathScreen = self:_getDeathScreen()
    if deathScreen and deathScreen.Hide then
        deathScreen.Hide()
    end
end

-- Restart game (fire restart event)
function GameUIController.restartGame(self: any)
    local deathScreen = self:_getDeathScreen()
    if deathScreen and deathScreen.FireRestartEvent then
        deathScreen.FireRestartEvent()
    end
end

-- Event handlers
function GameUIController.handleSanityUpdate(self: any, value: number, maxValue: number?)
    self:updateSanity(value, maxValue)
end

function GameUIController.handlePowerUpdate(self: any, value: number, maxValue: number?)
    self:updatePower(value, maxValue)
end

function GameUIController.handleInteractPrompt(self: any, actionText: string, target: any?)
    self:showInteractPrompt(actionText, target)
end

function GameUIController.handleInteractHide(self: any)
    self:hideInteractPrompt()
end

-- Setup event listeners
function GameUIController.setupEventListeners(self: any)
    -- Sanity update event
    local sanityUpdateEvent = ReplicatedStorage:FindFirstChild("SanityUpdateEvent")
    if sanityUpdateEvent then
        self.events.SanityUpdateEvent = sanityUpdateEvent.OnClientEvent:Connect(
            function(value: number, maxValue: number?)
                self:handleSanityUpdate(value, maxValue)
            end
        )
    else
        warn("GameUI: SanityUpdateEvent not found in ReplicatedStorage")
    end
    
    -- Power update event  
    local powerUpdateEvent = ReplicatedStorage:FindFirstChild("PowerUpdateEvent")
    if powerUpdateEvent then
        self.events.PowerUpdateEvent = powerUpdateEvent.OnClientEvent:Connect(
            function(value: number, maxValue: number?)
                self:handlePowerUpdate(value, maxValue)
            end
        )
    else
        warn("GameUI: PowerUpdateEvent not found in ReplicatedStorage")
    end
    
    -- Interaction prompt event
    local interactionPromptEvent = ReplicatedStorage:FindFirstChild("InteractionPromptEvent")
    if interactionPromptEvent then
        self.events.InteractionPromptEvent = interactionPromptEvent.OnClientEvent:Connect(
            function(actionText: string, target: any?)
                self:handleInteractPrompt(actionText, target)
            end
        )
    else
        warn("GameUI: InteractionPromptEvent not found in ReplicatedStorage")
    end
    
    -- Interaction hide event
    local interactionHideEvent = ReplicatedStorage:FindFirstChild("InteractionHideEvent")
    if interactionHideEvent then
        self.events.InteractionHideEvent = interactionHideEvent.OnClientEvent:Connect(
            function()
                self:handleInteractHide()
            end
        )
    else
        warn("GameUI: InteractionHideEvent not found in ReplicatedStorage")
    end
end

-- Cleanup
function GameUIController.destroy(self: any)
    -- Disconnect all events
    for name, connection in pairs(self.events) do
        if connection and connection.Disconnect then
            local conn: any = connection
            conn:Disconnect()
        end
        self.events[name] = nil
    end
    
    -- Clean up components
    self.components.SanityBar = nil
    self.components.PowerBar = nil
    self.components.InteractPrompt = nil
    self.components.LowSanityOverlay = nil
    self.components.DeathScreen = nil
    
    setmetatable(self, nil)
end

-- Singleton instance
local gameUIInstance: any = nil

-- Initialize module
local function init()
    if gameUIInstance then
        gameUIInstance:destroy()
    end
    
    local newInstance = GameUIController.new()
    gameUIInstance = newInstance
    
    -- Setup event listeners
    local task: any = _task
    task.spawn(function()
        newInstance:setupEventListeners()
    end)
    
    return newInstance
end

-- Public API
local Module: { [string]: any } = {}

-- Initialize the GameUI controller
function Module.Init()
    return init()
end

-- Get the GameUI controller instance
function Module.GetController()
    return gameUIInstance
end

-- Update sanity value (public API)
function Module.UpdateSanity(value: number, maxValue: number?)
    if gameUIInstance then
        gameUIInstance:updateSanity(value, maxValue)
    end
end

-- Update power value (public API)
function Module.UpdatePower(value: number, maxValue: number?)
    if gameUIInstance then
        gameUIInstance:updatePower(value, maxValue)
    end
end

-- Show interact prompt (public API)
function Module.ShowInteractPrompt(actionText: string, target: any?)
    if gameUIInstance then
        gameUIInstance:showInteractPrompt(actionText, target)
    end
end

-- Hide interact prompt (public API)
function Module.HideInteractPrompt()
    if gameUIInstance then
        gameUIInstance:hideInteractPrompt()
    end
end

-- Show death screen (public API)
function Module.ShowDeathScreen()
    if gameUIInstance then
        gameUIInstance:showDeathScreen()
    end
end

-- Hide death screen (public API)
function Module.HideDeathScreen()
    if gameUIInstance then
        gameUIInstance:hideDeathScreen()
    end
end

-- Restart game (public API)
function Module.RestartGame()
    if gameUIInstance then
        gameUIInstance:restartGame()
    end
end

-- Get current game state
function Module.GetState(): { [string]: any }?
    if gameUIInstance then
        return {
            currentSanity = gameUIInstance.state.currentSanity,
            maxSanity = gameUIInstance.state.maxSanity,
            currentPower = gameUIInstance.state.currentPower,
            maxPower = gameUIInstance.state.maxPower,
            isDead = gameUIInstance.state.isDead,
            isLowSanity = gameUIInstance.state.isLowSanity,
        }
    end
    return nil
end

-- For testing
function Module.CreateMock(newInstance: any)
    gameUIInstance = newInstance
end

-- Cleanup function
function Module.Destroy()
    if gameUIInstance then
        gameUIInstance:destroy()
        gameUIInstance = nil
    end
end

return Module
