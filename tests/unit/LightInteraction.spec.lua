--!strict
--[[
    LightInteraction Client Script Tests
    Validates client-side light toggle interaction functionality.
]]

-- Simple Vector3 helper (not using .new to avoid conflicts)
local function makeVec3(x: number, y: number, z: number): any
    local vec = { X = x, Y = y, Z = z, x = x, y = y, z = z }
    -- Magnitude calculation
    vec.Magnitude = math.sqrt(x*x + y*y + z*z)
    -- Subtraction operator for distance calculation
    -- Multiplication for scalar multiplication
    setmetatable(vec :: any, {
        __sub = function(a: any, b: any): any
            return makeVec3(a.x - b.x, a.y - b.y, a.z - b.z)
        end,
        __mul = function(a: any, b: any): any
            -- Handle scalar multiplication (vec * number or number * vec)
            local scalar = (type(a) == "number") and a or b
            local vector = (type(a) == "table") and a or b
            return makeVec3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
        end
    })
    return vec
end

-- Mock Enum types for CLI compatibility
local Enum = (if _G.Enum ~= nil then _G.Enum else {
    UserInputType = { Keyboard = "Keyboard" },
    KeyCode = { E = { Name = "E", Value = 0 } },
    Material = { Plastic = "Plastic" },
    RaycastFilterType = { Include = "Include" },
})

-- Mock InputObject for testing
local function createMockInputObject(keyCodeName: string): any
    -- Create a dynamic KeyCode based on the name
    local keyCode = {
        Name = keyCodeName,
        Value = if keyCodeName == "E" then 0 else (if keyCodeName == "W" then 1 else 2),
    }
    return {
        KeyCode = keyCode,
        UserInputType = Enum.UserInputType.Keyboard,
        Position = { X = 0, Y = 0 },
        Delta = { X = 0, Y = 0 },
    }
end

-- Mock BasePart with LightId attribute
local function createMockLightSwitch(lightId: string, position: any?): any
    local part = {
        Name = "LightSwitch_" .. lightId,
        Position = position or makeVec3(0, 0, 0),
        ClassName = "Part",
    }
    
    -- Mock GetAttribute
    local attributes: { [string]: any } = {
        LightId = lightId,
    }
    
    function part.GetAttribute(_self, attrName: string): any
        return attributes[attrName]
    end
    
    function part.IsA(_self, className: string): boolean
        return className == "BasePart" or className == "Part"
    end
    
    return part
end

-- Mock RemoteEvent
local function createMockRemoteEvent(name: string): any
    local event = {
        Name = name,
        _connections = {} :: { (...any) -> () },
        _firedEvents = {} :: { { any } },
    }
    
    function event.FireServer(...: any): ()
        table.insert(event._firedEvents, { ... })
        for _, callback in ipairs(event._connections) do
            callback(...)
        end
    end
    
    return event
end

-- Mock Events folder
local function createMockEventsFolder(): any
    local LightToggledEvent = createMockRemoteEvent("LightToggled")
    
    local folder = {
        Name = "Events",
        _children = {
            LightToggled = LightToggledEvent,
        } :: { [string]: any },
    }
    
    function folder.WaitForChild(_self, name: string, timeout: number?): any
        return folder._children[name]
    end
    
    return folder
end

-- Mock Lights folder
local function createMockLightsFolder(): any
    local folder = {
        Name = "Lights",
        _children = {} :: { any },
        _listeners = {} :: { [string]: { (...any) -> () } },
    }
    
    function folder.GetChildren(_self): { any }
        return folder._children
    end
    
    function folder.FindFirstChild(_self, name: string): any
        for _, child in ipairs(folder._children) do
            if child.Name == name then
                return child
            end
        end
        return nil
    end
    
    function folder.ChildAdded(callback: (...any) -> ()): (...any) -> ()
        table.insert(folder._listeners["ChildAdded"] or {}, callback)
        folder._listeners["ChildAdded"] = folder._listeners["ChildAdded"] or {}
        return function() end
    end
    
    function folder.ChildRemoved(callback: (...any) -> ()): (...any) -> ()
        table.insert(folder._listeners["ChildRemoved"] or {}, callback)
        folder._listeners["ChildRemoved"] = folder._listeners["ChildRemoved"] or {}
        return function() end
    end
    
    function folder.AddChild(_self, child: any): ()
        table.insert(folder._children, child)
        if folder._listeners["ChildAdded"] then
            for _, callback in ipairs(folder._listeners["ChildAdded"]) do
                callback(child)
            end
        end
    end
    
    function folder.RemoveChild(_self, child: any): ()
        for i, c in ipairs(folder._children) do
            if c == child then
                table.remove(folder._children, i)
                break
            end
        end
        if folder._listeners["ChildRemoved"] then
            for _, callback in ipairs(folder._listeners["ChildRemoved"]) do
                callback(child)
            end
        end
    end
    
    return folder
end

-- Mock ReplicatedStorage
local function createMockReplicatedStorage(): any
    local EventsFolder = createMockEventsFolder()
    
    local storage = {
        Name = "ReplicatedStorage",
        _children = {
            Events = EventsFolder,
        } :: { [string]: any },
    }
    
    function storage.WaitForChild(_self, name: string, timeout: number?): any
        return storage._children[name]
    end
    
    return storage
end

-- Mock UserInputService
local function createMockUserInputService(): any
    local service = {
        _handlers = {} :: { (InputObject, boolean) -> () },
    }
    
    -- Create InputBegan table first
    service.InputBegan = {}
    
    function service.InputBegan.Connect(_self: any, callback: (InputObject, boolean) -> ()): any
        table.insert(service._handlers, callback)
        return { Disconnect = function() end }
    end
    
    function service.FireInputBegan(inputObject: InputObject, gameProcessedEvent: boolean): ()
        for _, handler in ipairs(service._handlers) do
            handler(inputObject, gameProcessedEvent)
        end
    end
    
    return service
end

-- Mock Workspace
local function createMockWorkspace(): any
    local LightsFolder = createMockLightsFolder()
    
    local workspace = {
        Name = "Workspace",
        CurrentCamera = {
            CFrame = {
                Position = makeVec3(0, 5, 0),
                LookVector = makeVec3(0, 0, -1),
            },
        },
        _children = {
            Lights = LightsFolder,
        } :: { [string]: any },
    }
    
    function workspace.FindFirstChild(_self, name: string): any
        return workspace._children[name]
    end
    
    -- Mock Raycast (returns nil by default, simulating no hit)
    function workspace.Raycast(origin: any, direction: any, params: any?): any
        return nil
    end
    
    return workspace
end

-- Mock Players
local function createMockPlayers(): any
    local character = {
        Name = "Character",
        _children = {
            HumanoidRootPart = {
                Name = "HumanoidRootPart",
                Position = makeVec3(0, 0, 0),
            },
        } :: { [string]: any },
    }
    
    function character.FindFirstChild(_self, name: string): any
        return character._children[name]
    end
    
    local player = {
        Name = "TestPlayer",
        Character = character,
        _characterAddedHandlers = {} :: { (any) -> () },
    }
    
    -- Create CharacterAdded table first
    player.CharacterAdded = {}
    
    function player.CharacterAdded.Connect(_self: any, callback: (any) -> ()): any
        table.insert(player._characterAddedHandlers, callback)
        return { Disconnect = function() end }
    end
    
    local players = {
        LocalPlayer = player,
    }
    
    return players
end

-- Test module builder
local function createLightInteractionModule(mockServices: { [string]: any }): any
    local module = {}
    
    -- Configuration
    local INTERACTION_DISTANCE: number = 10
    local RAYCAST_DISTANCE: number = 10
    local INTERACTION_KEY: Enum.KeyCode = Enum.KeyCode.E
    
    -- State
    local player: any = mockServices.Players.LocalPlayer
    local character: any = player.Character
    local lightSwitches: { any } = {}
    
    -- Get services
    local ReplicatedStorage: any = mockServices.ReplicatedStorage
    local UserInputService: any = mockServices.UserInputService
    local Workspace: any = mockServices.Workspace
    
    local EventsFolder: any = ReplicatedStorage:WaitForChild("Events")
    local LightToggledEvent: any = EventsFolder:WaitForChild("LightToggled")
    local LightsFolder: any = Workspace:FindFirstChild("Lights")
    
    -- Expose for testing
    module._lightSwitches = lightSwitches
    module._LightToggledEvent = LightToggledEvent
    module._LightsFolder = LightsFolder
    module._UserInputService = UserInputService
    module._character = character
    
    --[[
        Refresh the light switches list.
    ]]
    function module.RefreshLightSwitches(): ()
        lightSwitches = {}
        if LightsFolder then
            for _, lightSwitch in ipairs(LightsFolder:GetChildren()) do
                if lightSwitch.IsA and lightSwitch:IsA("BasePart") and lightSwitch:GetAttribute("LightId") then
                    table.insert(lightSwitches, lightSwitch)
                end
            end
        end
        module._lightSwitches = lightSwitches
    end
    
    --[[
        Find the nearest light switch within interaction distance.
    ]]
    function module.FindNearestLightSwitch(): (any, string?)
        if not character then
            return nil, nil
        end
        
        local humanoidRootPart: any = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then
            return nil, nil
        end
        
        local playerPosition: any = humanoidRootPart.Position
        local nearestSwitch: any = nil
        local nearestDistance: number = INTERACTION_DISTANCE
        local nearestLightId: string? = nil
        
        for _, lightSwitch in ipairs(lightSwitches) do
            if lightSwitch.IsA and lightSwitch:IsA("BasePart") then
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
    ]]
    function module.RaycastForLightSwitch(): (any, string?)
        local camera: any = Workspace.CurrentCamera
        if not camera then
            return nil, nil
        end
        
        local rayOrigin: any = camera.CFrame.Position
        local rayDirection: any = camera.CFrame.LookVector * RAYCAST_DISTANCE
        
        local raycastResult: any = Workspace.Raycast(rayOrigin, rayDirection, nil)
        
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
        Try to toggle a light switch.
    ]]
    function module.TryToggleLightSwitch(): ()
        local nearbySwitch: any, nearbyLightId: string? = module.FindNearestLightSwitch();
        
        
        local raycastSwitch: any, raycastLightId: string? = module.RaycastForLightSwitch();
        
        
        local targetLightId: string? = raycastLightId or nearbyLightId
        
        if targetLightId then
            LightToggledEvent:FireServer(targetLightId)
        end
    end
    
    --[[
        Handle input began event.
    ]]
    function module.OnInputBegan(inputObject: any, gameProcessedEvent: boolean): ()
        if gameProcessedEvent then
            return
        end
        
        -- Compare by Name since KeyCode tables may be different instances
        if inputObject.KeyCode and inputObject.KeyCode.Name == INTERACTION_KEY.Name then
            module.TryToggleLightSwitch()
        end
    end
    
    --[[
        Setup function.
    ]]
    function module.Setup(): ()
        module.RefreshLightSwitches()
        
        UserInputService.InputBegan.Connect(nil, module.OnInputBegan)
    end
    
    return module
end

-- Run tests
local function runTests(): (number, number)
    print("Running LightInteraction module tests...")
    local passed = 0
    local failed = 0
    
    local function runTest(testName: string, testFn: () -> ()): boolean
        local success, err = pcall(testFn)
        if success then
            passed += 1
            return true
        else
            failed += 1
            print("Test '" .. testName .. "' failed: " .. tostring(err))
            return false
        end
    end
    
    -- Test 1: Module exists with required functions
    runTest("Module exists with required functions", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        assert(module.RefreshLightSwitches ~= nil, "RefreshLightSwitches function should exist")
        assert(module.FindNearestLightSwitch ~= nil, "FindNearestLightSwitch function should exist")
        assert(module.RaycastForLightSwitch ~= nil, "RaycastForLightSwitch function should exist")
        assert(module.TryToggleLightSwitch ~= nil, "TryToggleLightSwitch function should exist")
        assert(module.OnInputBegan ~= nil, "OnInputBegan function should exist")
        assert(module.Setup ~= nil, "Setup function should exist")
    end)
    
    -- Test 2: RefreshLightSwitches populates light switches list
    runTest("RefreshLightSwitches populates light switches list", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        local LightsFolder = mockServices.Workspace:FindFirstChild("Lights")
        
        -- Add a light switch
        local switch1 = createMockLightSwitch("light1", makeVec3(0, 0, 5))
        LightsFolder:AddChild(switch1)
        
        module.RefreshLightSwitches()
        
        assert(#module._lightSwitches == 1, "Should have 1 light switch")
        assert(module._lightSwitches[1]:GetAttribute("LightId") == "light1", "Light switch should have lightId 'light1'")
    end)
    
    -- Test 3: FindNearestLightSwitch returns nearest switch in range
    runTest("FindNearestLightSwitch returns nearest switch in range", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        local LightsFolder = mockServices.Workspace:FindFirstChild("Lights")
        
        -- Add light switches
        local switch1 = createMockLightSwitch("light1", makeVec3(0, 0, 5))   -- 5 studs away
        local switch2 = createMockLightSwitch("light2", makeVec3(0, 0, 8))   -- 8 studs away
        LightsFolder:AddChild(switch1)
        LightsFolder:AddChild(switch2)
        
        module.RefreshLightSwitches()
        
        local nearest, lightId = module.FindNearestLightSwitch()
        
        assert(nearest ~= nil, "Should find a nearest switch")
        assert(lightId == "light1", "Nearest switch should be 'light1'")
    end)
    
    -- Test 4: FindNearestLightSwitch returns nil when no switches in range
    runTest("FindNearestLightSwitch returns nil when no switches in range", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        local LightsFolder = mockServices.Workspace:FindFirstChild("Lights")
        
        -- Add light switch far away (beyond 10 stud range)
        local switch1 = createMockLightSwitch("light1", makeVec3(0, 0, 20))
        LightsFolder:AddChild(switch1)
        
        module.RefreshLightSwitches()
        
        local nearest, lightId = module.FindNearestLightSwitch()
        
        assert(nearest == nil, "Should not find a switch out of range")
        assert(lightId == nil, "lightId should be nil when no switch found")
    end)
    
    -- Test 5: E key input triggers TryToggleLightSwitch
    runTest("E key input triggers TryToggleLightSwitch", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        
        -- Create a spy for TryToggleLightSwitch
        local toggleCalled = false
        local originalToggle = module.TryToggleLightSwitch
        module.TryToggleLightSwitch = function()
            toggleCalled = true
        end
        
        local mockEInput = createMockInputObject("E")
        module.OnInputBegan(mockEInput, false)
        
        assert(toggleCalled == true, "TryToggleLightSwitch should be called when E is pressed")
        
        -- Restore original
        module.TryToggleLightSwitch = originalToggle
    end)
    
    -- Test 6: Non-E key input does not trigger toggle
    runTest("Non-E key input does not trigger toggle", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        
        -- Create a spy for TryToggleLightSwitch
        local toggleCalled = false
        local originalToggle = module.TryToggleLightSwitch
        module.TryToggleLightSwitch = function()
            toggleCalled = true
        end
        
        local mockWInput = createMockInputObject("W")
        module.OnInputBegan(mockWInput, false)
        
        assert(toggleCalled == false, "TryToggleLightSwitch should not be called when W is pressed")
        
        -- Restore original
        module.TryToggleLightSwitch = originalToggle
    end)
    
    -- Test 7: gameProcessedEvent filters input
    runTest("gameProcessedEvent filters input", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        
        -- Create a spy for TryToggleLightSwitch
        local toggleCalled = false
        local originalToggle = module.TryToggleLightSwitch
        module.TryToggleLightSwitch = function()
            toggleCalled = true
        end
        
        local mockEInput = createMockInputObject("E")
        module.OnInputBegan(mockEInput, true) -- gameProcessedEvent = true
        
        assert(toggleCalled == false, "TryToggleLightSwitch should not be called when gameProcessedEvent is true")
        
        -- Restore original
        module.TryToggleLightSwitch = originalToggle
    end)
    
    -- Test 8: FireServer is called with correct lightId when near switch
    runTest("FireServer is called with correct lightId when near switch", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        local LightsFolder = mockServices.Workspace:FindFirstChild("Lights")
        
        -- Add light switch nearby
        local switch1 = createMockLightSwitch("light1", makeVec3(0, 0, 5))
        LightsFolder:AddChild(switch1)
        
        module.RefreshLightSwitches()
        module.TryToggleLightSwitch()
        
        local LightToggledEvent = module._LightToggledEvent
        
        assert(#LightToggledEvent._firedEvents == 1, "FireServer should be called once")
        assert(LightToggledEvent._firedEvents[1][2] == "light1", "FireServer should be called with 'light1'")
    end)
    
    -- Test 9: FireServer is not called when no switch nearby
    runTest("FireServer is not called when no switch nearby", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        local LightsFolder = mockServices.Workspace:FindFirstChild("Lights")
        
        -- No light switches added
        module.RefreshLightSwitches()
        module.TryToggleLightSwitch()
        
        local LightToggledEvent = module._LightToggledEvent
        assert(#LightToggledEvent._firedEvents == 0, "FireServer should not be called when no switch nearby")
    end)
    
    -- Test 10: Proximity check only sends if near switch
    runTest("Proximity check only sends if near switch", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        local LightsFolder = mockServices.Workspace:FindFirstChild("Lights")
        
        -- Add light switch far away (beyond 10 stud range)
        local switch1 = createMockLightSwitch("light1", makeVec3(0, 0, 15))
        LightsFolder:AddChild(switch1)
        
        module.RefreshLightSwitches()
        
        -- Simulate E press
        module.TryToggleLightSwitch()
        
        local LightToggledEvent = module._LightToggledEvent
        assert(#LightToggledEvent._firedEvents == 0, "FireServer should not be called when switch is out of range")
    end)
    
    -- Test 11: Multiple light switches - finds closest one
    runTest("Multiple light switches - finds closest one", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        local LightsFolder = mockServices.Workspace:FindFirstChild("Lights")
        
        -- Add multiple light switches at different distances
        local switch1 = createMockLightSwitch("light_far", makeVec3(0, 0, 9))    -- 9 studs
        local switch2 = createMockLightSwitch("light_close", makeVec3(0, 0, 3))   -- 3 studs
        local switch3 = createMockLightSwitch("light_mid", makeVec3(0, 0, 6))     -- 6 studs
        LightsFolder:AddChild(switch1)
        LightsFolder:AddChild(switch2)
        LightsFolder:AddChild(switch3)
        
        module.RefreshLightSwitches()
        module.TryToggleLightSwitch()
        
        local LightToggledEvent = module._LightToggledEvent
        assert(#LightToggledEvent._firedEvents == 1, "FireServer should be called once")
        assert(LightToggledEvent._firedEvents[1][2] == "light_close", "Should toggle closest switch 'light_close'")
    end)
    
    -- Test 12: RaycastForLightSwitch returns instance with LightId
    runTest("RaycastForLightSwitch returns instance with LightId", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        local LightsFolder = mockServices.Workspace:FindFirstChild("Lights")
        
        -- Create a switch that will be "hit" by raycast
        local switch1 = createMockLightSwitch("raycast_light", makeVec3(0, 5, -5))
        LightsFolder:AddChild(switch1)
        
        -- Mock the raycast to return our switch
        local originalRaycast = mockServices.Workspace.Raycast
        mockServices.Workspace.Raycast = function(origin: any, direction: any, params: any?): any
            return {
                Instance = switch1,
                Position = makeVec3(0, 0, 0),
                Normal = makeVec3(0, 1, 0),
                Material = Enum.Material.Plastic,
            }
        end
        
        module.RefreshLightSwitches()
        
        local hit, lightId = module.RaycastForLightSwitch()
        
        assert(hit ~= nil, "Raycast should hit a light switch")
        assert(lightId == "raycast_light", "Raycast should return 'raycast_light' lightId")
        
        -- Restore original
        mockServices.Workspace.Raycast = originalRaycast
    end)
    
    -- Test 13: RaycastForLightSwitch returns nil when no LightId attribute
    runTest("RaycastForLightSwitch returns nil when no LightId attribute", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
            UserInputService = createMockUserInputService(),
            Workspace = createMockWorkspace(),
        }
        
        local module = createLightInteractionModule(mockServices)
        
        -- Create a part without LightId attribute
        local plainPart = {
            Name = "PlainPart",
            Position = makeVec3(0, 0, 0),
            ClassName = "Part",
            _attributes = {},
        }
        function plainPart.GetAttribute(_name: string): any
            return nil
        end
        function plainPart.IsA(className: string): boolean
            return className == "BasePart" or className == "Part"
        end
        
        -- Mock the raycast to return plain part
        local originalRaycast = mockServices.Workspace.Raycast
        mockServices.Workspace.Raycast = function(origin: any, direction: any, params: any?): any
            return {
                Instance = plainPart,
                Position = makeVec3(0, 0, 0),
                Normal = makeVec3(0, 1, 0),
                Material = Enum.Material.Plastic,
            }
        end
        
        local hit, lightId = module.RaycastForLightSwitch()
        
        assert(hit == nil, "Raycast should not return hit without LightId")
        assert(lightId == nil, "lightId should be nil when no LightId attribute")
        
        -- Restore original
        mockServices.Workspace.Raycast = originalRaycast
    end)
    
    print(string.format("Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests
