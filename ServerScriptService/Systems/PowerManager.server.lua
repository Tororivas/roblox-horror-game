--!strict
--[[
    PowerManager Server Script
    Initializes the power system on server start.
    Handles LightToggled remote events from clients to toggle lights.
    This script runs automatically when the server starts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PowerManager = require(script.Parent.PowerManager)

-- Get references to remote events
local EventsFolder = ReplicatedStorage:WaitForChild("Events")
local LightToggledEvent = EventsFolder:WaitForChild("LightToggled") :: RemoteEvent

--[[
    Find a light object in the workspace by its LightId.
    Looks for Parts or Models with a "LightId" attribute.
    @param lightId string - The unique identifier for the light
    @return BasePart|Model|nil - The light object, or nil if not found
]]
local function FindLightObject(lightId: string): any
    -- First check Lights folder in Workspace
    local LightsFolder = Workspace:FindFirstChild("Lights")
    if LightsFolder then
        for _, child in ipairs(LightsFolder:GetDescendants()) do
            local attrValue = child:GetAttribute("LightId")
            if attrValue and attrValue == lightId then
                return child
            end
        end
    end

    -- Also search for actual light objects (not switches) by name or attribute
    local LightObjectsFolder = Workspace:FindFirstChild("LightObjects")
    if LightObjectsFolder then
        for _, child in ipairs(LightObjectsFolder:GetDescendants()) do
            local attrValue = child:GetAttribute("LightId")
            if attrValue and attrValue == lightId then
                return child
            end
        end
    end

    return nil
end

--[[
    Set the enabled state of a light object.
    Supports PointLight, SpotLight, SurfaceLight objects as well as Parts/Models.
    @param lightObject any - The light object to control
    @param isEnabled boolean - Whether to enable (true) or disable (false)
]]
local function SetLightEnabled(lightObject: any, isEnabled: boolean): ()
    if not lightObject then
        return
    end

    -- Handle Light objects (PointLight, SpotLight, etc.)
    if lightObject:IsA("Light") then
        lightObject.Enabled = isEnabled
        return
    end

    -- Handle Parts/Models - look for Light children
    if lightObject:IsA("BasePart") or lightObject:IsA("Model") then
        -- Look for Light objects as children
        for _, child in ipairs(lightObject:GetDescendants()) do
            if child:IsA("Light") then
                child.Enabled = isEnabled
            end
        end

        -- Also look for SurfaceLights directly attached
        if lightObject:IsA("BasePart") then
            for _, child in ipairs(lightObject:GetChildren()) do
                if child:IsA("SurfaceLight") or child:IsA("PointLight") or child:IsA("SpotLight") then
                    child.Enabled = isEnabled
                end
            end
        end
    end
end

--[[
    Handle LightToggled remote event from client.
    Processes toggle requests and controls actual light objects.
    @param player Player - The player who sent the request
    @param lightId string - The unique identifier for the light to toggle
]]
local function OnLightToggled(player: Player, lightId: string): ()
    if typeof(lightId) ~= "string" then
        warn(string.format("[PowerManager] Invalid lightId from %s: %s", player.Name, tostring(lightId)))
        return
    end

    print(string.format("[PowerManager] Player %s requested toggle for light: %s", player.Name, lightId))

    -- Get current light state
    local currentState = PowerManager.GetLightState(lightId)
    local isCurrentlyOn = currentState == true

    local success: boolean = false

    if not isCurrentlyOn then
        -- Light is currently OFF, trying to turn ON
        -- Requires power to turn ON
        if not PowerManager.HasPower() then
            print(string.format("[PowerManager] Cannot turn on light %s - no power available", lightId))
            -- Still fire event but with isOn=false to indicate failure
            LightToggledEvent:FireAllClients(lightId, false)
            return
        end

        -- Try to turn on and consume power
        success = PowerManager.ToggleLight(lightId)

        if success then
            -- Find the actual light object and enable it
            local lightObject = FindLightObject(lightId)
            if lightObject then
                SetLightEnabled(lightObject, true)
                print(string.format("[PowerManager] Light %s turned ON, power: %d%%", lightId, PowerManager.GetPower()))
            else
                warn(string.format("[PowerManager] Light object %s not found in workspace", lightId))
            end
        end
    else
        -- Light is currently ON, turning OFF
        -- Turning OFF always works (no power check)
        success = PowerManager.ToggleLight(lightId)

        if success then
            -- Find the actual light object and disable it
            local lightObject = FindLightObject(lightId)
            if lightObject then
                SetLightEnabled(lightObject, false)
                print(string.format("[PowerManager] Light %s turned OFF", lightId))
            else
                warn(string.format("[PowerManager] Light object %s not found in workspace", lightId))
            end
        end
    end
end

-- Connect to LightToggled OnServerEvent
LightToggledEvent.OnServerEvent:Connect(OnLightToggled)

-- Initialize power on server start
print("[PowerManager] Initializing power system...")
print(string.format("[PowerManager] Starting power: %d%%", PowerManager.GetPower()))
print("[PowerManager] Power system initialized successfully!")
