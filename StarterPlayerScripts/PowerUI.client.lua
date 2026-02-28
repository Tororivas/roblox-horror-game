--!strict
--[[
    PowerUI Client Script
    Displays the current power level as a UI element.
    Updates when PowerChanged event fires from server.
    Shows warning when power is low (<= 20%) and indicates when depleted (0%).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Get the local player
local player: any = Players.LocalPlayer
if not player then
    error("PowerUI: LocalPlayer not available")
end

-- Get PlayerGui
local playerGui: any = player:WaitForChild("PlayerGui")

-- Get RemoteEvent
local EventsFolder: any = ReplicatedStorage:WaitForChild("Events")
local PowerChangedEvent: RemoteEvent = EventsFolder:WaitForChild("PowerChanged") :: RemoteEvent

-- UI Configuration
local UI_CONFIG = {
    -- Position and size
    Position = UDim2.new(0.85, 0, 0.05, 0), -- Top-right corner
    Size = UDim2.new(0, 150, 0, 60),
    
    -- Colors for different power states
    Colors = {
        Normal = Color3.fromRGB(0, 255, 100),      -- Green for normal
        Warning = Color3.fromRGB(255, 165, 0),      -- Orange for low power
        Critical = Color3.fromRGB(255, 0, 0),       -- Red for depleted
        Background = Color3.fromRGB(40, 40, 40),    -- Dark background
        Text = Color3.fromRGB(255, 255, 255),       -- White text
    },
    
    -- Power thresholds
    WARNING_THRESHOLD = 20,  -- Power <= 20% shows warning
    CRITICAL_THRESHOLD = 0,  -- Power = 0% shows critical
}

-- UI Element references
local powerFrame: any? = nil
local powerLabel: any? = nil
local powerBar: any? = nil
local currentPower: number = 100

--[[
    Creates the power UI elements.
    Places a frame with a label and bar that displays the current power level.
]]
local function CreatePowerUI(): ()
    -- Create the main frame
    local frame: any = Instance.new("Frame")
    frame.Name = "PowerFrame"
    frame.Size = UI_CONFIG.Size
    frame.Position = UI_CONFIG.Position
    frame.BackgroundColor3 = UI_CONFIG.Colors.Background
    frame.BorderSizePixel = 2
    frame.BorderColor3 = UI_CONFIG.Colors.Normal
    frame.Parent = playerGui
    
    -- Create the UICorner for rounded corners
    local corner: any = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Create the title label
    local titleLabel: any = Instance.new("TextLabel")
    titleLabel.Name = "PowerTitle"
    titleLabel.Text = "BATTERY"
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.Position = UDim2.new(0, 0, 0, 2)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = UI_CONFIG.Colors.Text
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = frame
    
    -- Create the power percentage label
    local percentLabel: any = Instance.new("TextLabel")
    percentLabel.Name = "PowerLabel"
    percentLabel.Text = "100%"
    percentLabel.Size = UDim2.new(1, 0, 0, 20)
    percentLabel.Position = UDim2.new(0, 0, 0, 22)
    percentLabel.BackgroundTransparency = 1
    percentLabel.TextColor3 = UI_CONFIG.Colors.Normal
    percentLabel.TextScaled = true
    percentLabel.Font = Enum.Font.GothamBold
    percentLabel.Parent = frame
    
    -- Create the power bar background
    local barBackground: any = Instance.new("Frame")
    barBackground.Name = "PowerBarBackground"
    barBackground.Size = UDim2.new(0.9, 0, 0, 8)
    barBackground.Position = UDim2.new(0.05, 0, 0, 46)
    barBackground.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    barBackground.BorderSizePixel = 0
    barBackground.Parent = frame
    
    local barCorner: any = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = barBackground
    
    -- Create the power fill bar
    local barFill: any = Instance.new("Frame")
    barFill.Name = "PowerBarFill"
    barFill.Size = UDim2.new(1, 0, 1, 0)
    barFill.BackgroundColor3 = UI_CONFIG.Colors.Normal
    barFill.BorderSizePixel = 0
    barFill.Parent = barBackground
    
    local fillCorner: any = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = barFill
    
    -- Store references
    powerFrame = frame
    powerLabel = percentLabel
    powerBar = barFill
end

--[[
    Gets the color for the current power level.
    Returns different colors based on power thresholds.
    @param power number - Current power percentage
    @return Color3 - The color to use for UI elements
]]
local function GetPowerColor(power: number): any
    if power <= UI_CONFIG.CRITICAL_THRESHOLD then
        return UI_CONFIG.Colors.Critical
    elseif power <= UI_CONFIG.WARNING_THRESHOLD then
        return UI_CONFIG.Colors.Warning
    else
        return UI_CONFIG.Colors.Normal
    end
end

--[[
    Updates the power UI with the current power level.
    Changes color and text based on power percentage.
    @param power number - Current power percentage (0-100)
]]
local function UpdatePowerUI(power: number): ()
    if not powerLabel or not powerBar or not powerFrame then
        return
    end
    
    currentPower = math.clamp(power, 0, 100)
    
    local color = GetPowerColor(currentPower)
    
    -- Update label text
    powerLabel.Text = string.format("%d%%", math.floor(currentPower))
    powerLabel.TextColor3 = color
    
    -- Update bar fill
    powerBar.Size = UDim2.new(currentPower / 100, 0, 1, 0)
    powerBar.BackgroundColor3 = color
    
    -- Update frame border
    powerFrame.BorderColor3 = color
end

--[[
    Handles the PowerChanged event from server.
    @param newPower number - New power percentage
]]
local function OnPowerChanged(newPower: number): ()
    print(string.format("[PowerUI] Power changed: %d%%", newPower))
    UpdatePowerUI(newPower)
end

--[[
    Request initial power state from server.
    The server will fire PowerChanged with current value.
]]
local function RequestInitialState(): ()
    -- The UI will be updated when the first PowerChanged event fires
    -- Server typically fires this on player join or when any client connects
    print("[PowerUI] Waiting for initial power state...")
end

--[[
    Setup function.
    Creates UI and connects to events.
]]
local function Setup(): ()
    -- Create the UI
    CreatePowerUI()
    
    -- Connect to PowerChanged event
    PowerChangedEvent.OnClientEvent:Connect(OnPowerChanged)
    
    -- Request initial state
    RequestInitialState()
    
    print("[PowerUI] Client UI initialized")
end

-- Run setup
Setup()
