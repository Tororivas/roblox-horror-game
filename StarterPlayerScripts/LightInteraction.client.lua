--!strict
--[[
    LightInteraction Client Script
    Handles player interaction with light switches via 'E' key.
    When player presses 'E' near a light switch, sends toggle request to server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Get the local player
local player: any = Players.LocalPlayer
if not player then
    error("LightInteraction: LocalPlayer not available")
end

-- Wait for player character to load
local character: any = player.Character or player.CharacterAdded:Wait()

-- Configuration for interaction
local INTERACTION_DISTANCE: number = 10 -- studs
local RAYCAST_DISTANCE: number = 10 -- studs
local INTERACTION_KEY: Enum.KeyCode = Enum.KeyCode.E

-- Get RemoteEvents
local EventsFolder: any = ReplicatedStorage:WaitForChild("Events")
local LightToggledEvent: RemoteEvent = EventsFolder:WaitForChild("LightToggled") :: RemoteEvent

-- Get light switches collection (Lights folder in Workspace)
local lightSwitches: { any } = {}
local LightsFolder: any = Workspace:FindFirstChild("Lights")

--[[
    Refresh the light switches list from the Lights folder.
    Called on setup and can be called to refresh if lights are added/removed.
]]
local function RefreshLightSwitches(): ()
    lightSwitches = {}
    if LightsFolder then
        for _, lightSwitch in ipairs(LightsFolder:GetChildren()) do
            if lightSwitch:IsA("BasePart") and lightSwitch:GetAttribute("LightId") then
                table.insert(lightSwitches, lightSwitch)
            end
        end
    end
end

--[[
    Find the nearest light switch within interaction distance.
    Uses position-based distance check from the player's character.
    @return BasePart|nil - The nearest light switch part, or nil if none in range
    @return string|nil - The LightId of the switch, or nil if none found
]]
local function FindNearestLightSwitch(): (any, string?)
    if not character then
        return nil, nil
    end
    
    local humanoidRootPart: any = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return nil, nil
    end
    
    local playerPosition: Vector3 = humanoidRootPart.Position
    local nearestSwitch: any = nil
    local nearestDistance: number = INTERACTION_DISTANCE
    local nearestLightId: string? = nil
    
    for _, lightSwitch in ipairs(lightSwitches) do
        if lightSwitch:IsA("BasePart") then
            local distance: number = (lightSwitch.Position - playerPosition).Magnitude
            if distance <= INTERACTION_DISTANCE and distance < nearestDistance then
                nearestDistance = distance
                nearestSwitch = lightSwitch
                nearestLightId = lightSwitch:GetAttribute("LightId") :: string
            end
        end
    end
    
    return nearestSwitch, nearestLightId
end

--[[
    Raycast forward from camera to find light switches.
    Alternative to proximity check for more precise aiming.
    @return BasePart|nil - The light switch hit by raycast, or nil
    @return string|nil - The LightId of the switch, or nil
]]
local function RaycastForLightSwitch(): (any, string?)
    local camera: any = Workspace.CurrentCamera
    if not camera then
        return nil, nil
    end
    
    local rayOrigin: Vector3 = camera.CFrame.Position
    local rayDirection: Vector3 = camera.CFrame.LookVector * RAYCAST_DISTANCE
    
    -- Create raycast params to only hit light switches
    local raycastParams: any = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = { LightsFolder }
    
    local raycastResult: any = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if raycastResult then
        local hitInstance: any = raycastResult.Instance
        if hitInstance and hitInstance:IsA("BasePart") then
            local lightId: any = hitInstance:GetAttribute("LightId")
            if lightId then
                return hitInstance, lightId :: string
            end
        end
    end
    
    return nil, nil
end

--[[
    Check if player is near a light switch and toggle it.
    Combines proximity check with optional raycast for accuracy.
]]
local function TryToggleLightSwitch(): ()
    -- Try proximity check first
    local nearbySwitch: any, nearbyLightId: string? = FindNearestLightSwitch()
    
    -- Also try raycast for more precise targeting
    local raycastSwitch: any, raycastLightId: string? = RaycastForLightSwitch()
    
    -- Use raycast result if available, otherwise use proximity
    local targetLightId: string? = raycastLightId or nearbyLightId
    
    if targetLightId then
        -- Fire event to server with the lightId
        LightToggledEvent:FireServer(targetLightId)
    end
end

--[[
    Handle input began event.
    Checks for 'E' key press and triggers light toggle if near a switch.
]]
local function OnInputBegan(inputObject: InputObject, gameProcessedEvent: boolean): ()
    -- Ignore if game already processed this input (e.g., typing in chat)
    if gameProcessedEvent then
        return
    end
    
    -- Check if the pressed key is 'E'
    if inputObject.KeyCode == INTERACTION_KEY then
        TryToggleLightSwitch()
    end
end

--[[
    Setup function called when character is ready.
]]
local function Setup(): ()
    -- Initial refresh of light switches
    RefreshLightSwitches()
    
    -- Connect to UserInputService for key detection
    UserInputService.InputBegan:Connect(OnInputBegan)
    
    -- Watch for Lights folder changes to refresh switches
    if LightsFolder then
        LightsFolder.ChildAdded:Connect(function(child: any)
            if child:IsA("BasePart") and child:GetAttribute("LightId") then
                RefreshLightSwitches()
            end
        end)
        
        LightsFolder.ChildRemoved:Connect(function(_child: any)
            RefreshLightSwitches()
        end)
    end
    
    -- Refresh switches when character changes
    player.CharacterAdded:Connect(function(newCharacter: any)
        character = newCharacter
        RefreshLightSwitches()
    end)
end

-- Run setup
Setup()

print("[LightInteraction] Client script initialized")
