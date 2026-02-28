--!strict
--[[
    PowerUI Client Script Tests
    Validates client-side power UI functionality.
]]

-- Mock Color3 for testing
local function createColor3(r: number, g: number, b: number): any
    return { R = r / 255, G = g / 255, B = b / 255, r = r, g = g, b = b }
end

-- Mock UDim types
local function createUDim(scale: number, offset: number): any
    return { Scale = scale, Offset = offset, scale = scale, offset = offset }
end

local function createUDim2(xScale: number, xOffset: number, yScale: number, yOffset: number): any
    return {
        X = createUDim(xScale, xOffset),
        Y = createUDim(yScale, yOffset),
        x = { Scale = xScale, Offset = xOffset },
        y = { Scale = yScale, Offset = yOffset },
    }
end

-- Mock Enum
local Enum = (if _G.Enum ~= nil then _G.Enum else {
    Font = {
        GothamBold = "GothamBold",
    },
})

-- Mock Instance creation
local mockInstances: { [string]: any } = {}

local function createMockInstance(className: string, name: string?): any
    local instance: any = {
        Name = name or className,
        ClassName = className,
        _children = {} :: { any },
        _properties = {} :: { [string]: any },
        _parent = nil,
    }
    
    function instance.new(subClassName: string): any
        return createMockInstance(subClassName)
    end
    
    function instance.IsA(self, class: string): boolean
        return self.ClassName == class
    end
    
    function instance.GetChildren(self): { any }
        local children: { any } = {}
        for _, child in pairs(self._children) do
            table.insert(children, child)
        end
        return children
    end
    
    function instance.FindFirstChild(self, name: string): any
        return self._children[name]
    end
    
    function instance.WaitForChild(self, name: string, timeout: number?): any
        local child = self._children[name]
        if child then
            return child
        end
        return self._children[name] -- Will be nil if not found
    end
    
    function instance.Destroy(self): ()
        if self._parent then
            self._parent._children[self.Name] = nil
        end
    end
    
    return instance
end

-- Mock Instance global
local MockInstance = {}
function MockInstance.new(className: string): any
    local instance = createMockInstance(className)
    mockInstances[className] = mockInstances[className] or {}
    table.insert(mockInstances[className], instance)
    return instance
end
setmetatable(MockInstance, {
    __index = function(_t, k)
        return { new = function(...) return createMockInstance(k, ...) end }
    end,
})

-- Mock RemoteEvent
local function createMockRemoteEvent(name: string): any
    local event = {
        Name = name,
        _connections = {} :: { (...any) -> () },
        _firedEvents = {} :: { { any } },
    }
    
    event.OnClientEvent = {
        Connect = function(_self: any, callback: (...any) -> ()): any
            table.insert(event._connections, callback)
            return { Disconnect = function() end }
        end,
        Fire = function(...: any): ()
            for _, callback in ipairs(event._connections) do
                callback(...)
            end
        end,
    }
    
    function event.FireClient(...: any): ()
        -- Simulate server firing to client
        event.OnClientEvent.Fire(...)
    end
    
    return event
end

-- Mock Events folder
local function createMockEventsFolder(): any
    local PowerChangedEvent = createMockRemoteEvent("PowerChanged")
    
    local folder = {
        Name = "Events",
        _children = {
            PowerChanged = PowerChangedEvent,
        } :: { [string]: any },
        _parent = nil,
    }
    
    function folder.WaitForChild(_self, name: string, timeout: number?): any
        return folder._children[name]
    end
    
    return folder
end

-- Mock PlayerGui
local function createMockPlayerGui(): any
    return {
        Name = "PlayerGui",
        _children = {} :: { [string]: any },
        _parent = nil,
    }
end

-- Mock Player
local function createMockPlayer(): any
    local playerGui = createMockPlayerGui()
    
    local player = {
        Name = "TestPlayer",
        _children = {
            PlayerGui = playerGui,
        } :: { [string]: any },
    }
    
    function player.WaitForChild(_self, name: string, timeout: number?): any
        return player._children[name]
    end
    
    return player
end

-- Mock Players service
local function createMockPlayers(): any
    local player = createMockPlayer()
    
    return {
        LocalPlayer = player,
    }
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

-- UI Creator module (like the actual PowerUI but testable)
local function createPowerUIModule(mockServices: { [string]: any }): any
    local module = {}
    
    local Players = mockServices.Players
    local ReplicatedStorage = mockServices.ReplicatedStorage
    
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    local EventsFolder = ReplicatedStorage:WaitForChild("Events")
    local PowerChangedEvent = EventsFolder:WaitForChild("PowerChanged")
    
    local UI_CONFIG = {
        Position = createUDim2(0.85, 0, 0.05, 0),
        Size = createUDim2(0, 150, 0, 60),
        Colors = {
            Normal = createColor3(0, 255, 100),
            Warning = createColor3(255, 165, 0),
            Critical = createColor3(255, 0, 0),
            Background = createColor3(40, 40, 40),
            Text = createColor3(255, 255, 255),
        },
        WARNING_THRESHOLD = 20,
        CRITICAL_THRESHOLD = 0,
    }
    
    local powerFrame: any? = nil
    local powerLabel: any? = nil
    local powerBar: any? = nil
    local currentPower: number = 100
    local eventConnection: any? = nil
    
    function module.GetUIConfig(): any
        return UI_CONFIG
    end
    
    function module.GetCurrentPower(): number
        return currentPower
    end
    
    function module.HasPowerFrame(): boolean
        return powerFrame ~= nil
    end
    
    function module.HasPowerLabel(): boolean
        return powerLabel ~= nil
    end
    
    function module.HasPowerBar(): boolean
        return powerBar ~= nil
    end
    
    function module.GetPowerFrame(): any
        return powerFrame
    end
    
    function module.GetPowerLabel(): any
        return powerLabel
    end
    
    function module.GetPowerBar(): any
        return powerBar
    end
    
    function module.CreatePowerUI(): ()
        local frame: any = {
            Name = "PowerFrame",
            Size = UI_CONFIG.Size,
            Position = UI_CONFIG.Position,
            BackgroundColor3 = UI_CONFIG.Colors.Background,
            BorderSizePixel = 2,
            BorderColor3 = UI_CONFIG.Colors.Normal,
            _parent = nil,
        }
        
        function frame.SetParent(self, parent: any): ()
            self._parent = parent
            if parent then
                parent._children[self.Name] = self
            end
        end
        
        -- Mock UICorner
        local corner: any = {
            Name = "UICorner",
            CornerRadius = { Scale = 0, Offset = 8 },
        }
        corner.Parent = frame
        
        -- Title label
        local titleLabel: any = {
            Name = "PowerTitle",
            Text = "BATTERY",
            Size = createUDim2(1, 0, 0, 20),
            Position = createUDim2(0, 0, 0, 2),
            BackgroundTransparency = 1,
            TextColor3 = UI_CONFIG.Colors.Text,
            TextScaled = true,
            Font = Enum.Font.GothamBold,
            Parent = frame,
        }
        
        -- Percentage label
        local percentLabel: any = {
            Name = "PowerLabel",
            Text = "100%",
            Size = createUDim2(1, 0, 0, 20),
            Position = createUDim2(0, 0, 0, 22),
            BackgroundTransparency = 1,
            TextColor3 = UI_CONFIG.Colors.Normal,
            TextScaled = true,
            Font = Enum.Font.GothamBold,
            Parent = frame,
        }
        
        -- Bar background
        local barBackground: any = {
            Name = "PowerBarBackground",
            Size = createUDim2(0.9, 0, 0, 8),
            Position = createUDim2(0.05, 0, 0, 46),
            BackgroundColor3 = createColor3(20, 20, 20),
            BorderSizePixel = 0,
            Parent = frame,
        }
        
        -- Bar fill
        local barFill: any = {
            Name = "PowerBarFill",
            Size = createUDim2(1, 0, 1, 0),
            BackgroundColor3 = UI_CONFIG.Colors.Normal,
            BorderSizePixel = 0,
            Parent = barBackground,
        }
        
        frame:SetParent(playerGui)
        
        powerFrame = frame
        powerLabel = percentLabel
        powerBar = barFill
    end
    
    function module.GetPowerColor(power: number): any
        if power <= UI_CONFIG.CRITICAL_THRESHOLD then
            return UI_CONFIG.Colors.Critical
        elseif power <= UI_CONFIG.WARNING_THRESHOLD then
            return UI_CONFIG.Colors.Warning
        else
            return UI_CONFIG.Colors.Normal
        end
    end
    
    function module.UpdatePowerUI(power: number): ()
        if not powerLabel or not powerBar or not powerFrame then
            return
        end
        
        currentPower = math.clamp(power, 0, 100)
        
        local color = module.GetPowerColor(currentPower)
        
        powerLabel.Text = string.format("%d%%", math.floor(currentPower))
        powerLabel.TextColor3 = color
        
        powerBar.Size = { X = { Scale = currentPower / 100, Offset = 0 }, Y = { Scale = 1, Offset = 0 } }
        powerBar.BackgroundColor3 = color
        
        powerFrame.BorderColor3 = color
    end
    
    function module.OnPowerChanged(newPower: number): ()
        module.UpdatePowerUI(newPower)
    end
    
    function module.Setup(): ()
        module.CreatePowerUI()
        eventConnection = PowerChangedEvent.OnClientEvent:Connect(module.OnPowerChanged)
    end
    
    function module.GetEventConnection(): any
        return eventConnection
    end
    
    function module.SimulatePowerChanged(newPower: number): ()
        module.OnPowerChanged(newPower)
    end
    
    return module
end

-- Run tests
local function runTests(): (number, number)
    print("Running PowerUI client script tests...")
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
    
    -- Test 1: UI Config has required values
    runTest("UI Config has required values", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        local config = module.GetUIConfig()
        
        assert(config ~= nil, "UI_CONFIG should exist")
        assert(config.Colors ~= nil, "Colors should exist")
        assert(config.Colors.Normal ~= nil, "Normal color should exist")
        assert(config.Colors.Warning ~= nil, "Warning color should exist")
        assert(config.Colors.Critical ~= nil, "Critical color should exist")
        assert(config.Colors.Background ~= nil, "Background color should exist")
        assert(config.Colors.Text ~= nil, "Text color should exist")
        assert(config.WARNING_THRESHOLD == 20, "WARNING_THRESHOLD should be 20")
        assert(config.CRITICAL_THRESHOLD == 0, "CRITICAL_THRESHOLD should be 0")
    end)
    
    -- Test 2: CreatePowerUI creates required UI elements
    runTest("CreatePowerUI creates required UI elements", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.CreatePowerUI()
        
        assert(module.HasPowerFrame() == true, "PowerFrame should be created")
        assert(module.HasPowerLabel() == true, "PowerLabel should be created")
        assert(module.HasPowerBar() == true, "PowerBar should be created")
    end)
    
    -- Test 3: UI elements have correct initial properties
    runTest("UI elements have correct initial properties", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.CreatePowerUI()
        
        local frame = module.GetPowerFrame()
        local label = module.GetPowerLabel()
        local bar = module.GetPowerBar()
        local config = module.GetUIConfig()
        
        assert(frame.Name == "PowerFrame", "Frame should be named PowerFrame")
        assert(label.Name == "PowerLabel", "Label should be named PowerLabel")
        assert(bar.Name == "PowerBarFill", "Bar should be named PowerBarFill")
        assert(label.Text == "100%", "Initial text should be 100%")
        assert(label.TextColor3 == config.Colors.Normal, "Initial color should be Normal")
    end)
    
    -- Test 4: GetPowerColor returns correct colors
    runTest("GetPowerColor returns correct colors for power levels", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        local config = module.GetUIConfig()
        
        -- Normal power
        local normalColor = module.GetPowerColor(100)
        local normalColor2 = module.GetPowerColor(50)
        local normalColor3 = module.GetPowerColor(21)
        assert(normalColor == config.Colors.Normal, "100% power should return Normal color")
        assert(normalColor2 == config.Colors.Normal, "50% power should return Normal color")
        assert(normalColor3 == config.Colors.Normal, "21% power should return Normal color")
        
        -- Warning power
        local warningColor = module.GetPowerColor(20)
        local warningColor2 = module.GetPowerColor(10)
        local warningColor3 = module.GetPowerColor(1)
        assert(warningColor == config.Colors.Warning, "20% power should return Warning color")
        assert(warningColor2 == config.Colors.Warning, "10% power should return Warning color")
        assert(warningColor3 == config.Colors.Warning, "1% power should return Warning color")
        
        -- Critical power
        local criticalColor = module.GetPowerColor(0)
        assert(criticalColor == config.Colors.Critical, "0% power should return Critical color")
    end)
    
    -- Test 5: UpdatePowerUI updates label text correctly
    runTest("UpdatePowerUI updates label text correctly", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.CreatePowerUI()
        
        module.UpdatePowerUI(75)
        local label = module.GetPowerLabel()
        assert(label.Text == "75%", "Label should show 75%")
        
        module.UpdatePowerUI(30)
        assert(label.Text == "30%", "Label should show 30%")
        
        module.UpdatePowerUI(0)
        assert(label.Text == "0%", "Label should show 0%")
    end)
    
    -- Test 6: UpdatePowerUI clamps values
    runTest("UpdatePowerUI clamps values to 0-100 range", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.CreatePowerUI()
        
        module.UpdatePowerUI(150)
        assert(module.GetCurrentPower() == 100, "Power should be clamped to 100")
        
        module.UpdatePowerUI(-10)
        assert(module.GetCurrentPower() == 0, "Power should be clamped to 0")
    end)
    
    -- Test 7: Warning color shown at threshold (20%)
    runTest("Warning color shown at 20% threshold", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.CreatePowerUI()
        module.UpdatePowerUI(20)
        
        local label = module.GetPowerLabel()
        local bar = module.GetPowerBar()
        local frame = module.GetPowerFrame()
        local config = module.GetUIConfig()
        
        assert(label.Text == "20%", "Label should show 20%")
        assert(label.TextColor3 == config.Colors.Warning, "Label should be Warning color at 20%")
        assert(bar.BackgroundColor3 == config.Colors.Warning, "Bar should be Warning color at 20%")
        assert(frame.BorderColor3 == config.Colors.Warning, "Frame border should be Warning color at 20%")
    end)
    
    -- Test 8: Critical color shown at threshold (0%)
    runTest("Critical color shown at 0% threshold", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.CreatePowerUI()
        module.UpdatePowerUI(0)
        
        local label = module.GetPowerLabel()
        local bar = module.GetPowerBar()
        local frame = module.GetPowerFrame()
        local config = module.GetUIConfig()
        
        assert(label.Text == "0%", "Label should show 0%")
        assert(label.TextColor3 == config.Colors.Critical, "Label should be Critical color at 0%")
        assert(bar.BackgroundColor3 == config.Colors.Critical, "Bar should be Critical color at 0%")
        assert(frame.BorderColor3 == config.Colors.Critical, "Frame border should be Critical color at 0%")
    end)
    
    -- Test 9: OnPowerChanged calls UpdatePowerUI
    runTest("OnPowerChanged updates UI", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.CreatePowerUI()
        
        module.OnPowerChanged(45)
        assert(module.GetCurrentPower() == 45, "Power should be 45% after OnPowerChanged")
        
        local label = module.GetPowerLabel()
        assert(label.Text == "45%", "Label should show 45%")
    end)
    
    -- Test 10: Setup creates UI and connects to PowerChanged event
    runTest("Setup creates UI and connects to PowerChanged event", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.Setup()
        
        assert(module.HasPowerFrame() == true, "PowerFrame should be created after Setup")
        assert(module.HasPowerLabel() == true, "PowerLabel should be created after Setup")
        assert(module.HasPowerBar() == true, "PowerBar should be created after Setup")
        assert(module.GetEventConnection() ~= nil, "Event connection should be established")
    end)
    
    -- Test 11: PowerChanged event triggers UI update
    runTest("PowerChanged event triggers UI update", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.Setup()
        
        local EventsFolder = mockServices.ReplicatedStorage:WaitForChild("Events")
        local PowerChangedEvent = EventsFolder:WaitForChild("PowerChanged")
        
        PowerChangedEvent.OnClientEvent.Fire(35)
        
        assert(module.GetCurrentPower() == 35, "Power should update to 35%")
        local label = module.GetPowerLabel()
        assert(label.Text == "35%", "Label should show 35%")
    end)
    
    -- Test 12: Multiple power changes update sequentially
    runTest("Multiple power changes update sequentially", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.Setup()
        
        local EventsFolder = mockServices.ReplicatedStorage:WaitForChild("Events")
        local PowerChangedEvent = EventsFolder:WaitForChild("PowerChanged")
        local label = module.GetPowerLabel()
        
        -- Simulate multiple power changes
        PowerChangedEvent.OnClientEvent.Fire(90)
        assert(module.GetCurrentPower() == 90, "Power should be 90%")
        assert(label.Text == "90%", "Label should show 90%")
        
        PowerChangedEvent.OnClientEvent.Fire(80)
        assert(module.GetCurrentPower() == 80, "Power should be 80%")
        assert(label.Text == "80%", "Label should show 80%")
        
        PowerChangedEvent.OnClientEvent.Fire(20)
        assert(module.GetCurrentPower() == 20, "Power should be 20%")
        assert(label.Text == "20%", "Label should show 20%")
        
        PowerChangedEvent.OnClientEvent.Fire(0)
        assert(module.GetCurrentPower() == 0, "Power should be 0%")
        assert(label.Text == "0%", "Label should show 0%")
    end)
    
    -- Test 13: UI bar size scales with power percentage
    runTest("UI bar size scales with power percentage", function()
        local mockServices = {
            Players = createMockPlayers(),
            ReplicatedStorage = createMockReplicatedStorage(),
        }
        
        local module = createPowerUIModule(mockServices)
        module.CreatePowerUI()
        
        module.UpdatePowerUI(100)
        local bar = module.GetPowerBar()
        assert(bar.Size.X.Scale == 1.0, "Bar should be full size at 100%")
        
        module.UpdatePowerUI(50)
        assert(bar.Size.X.Scale == 0.5, "Bar should be half size at 50%")
        
        module.UpdatePowerUI(10)
        assert(bar.Size.X.Scale == 0.1, "Bar should be 10% size at 10%")
        
        module.UpdatePowerUI(0)
        assert(bar.Size.X.Scale == 0, "Bar should be zero size at 0%")
    end)
    
    print(string.format("Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests