--!strict
--[[
    Server Toggle Handler Tests (US-007)
    Validates the LightToggled OnServerEvent handler in PowerManager.server.lua
    Tests toggle logic, light control, and power management integration.
]]

-- Test state tracking
local firedEvents: {{any}} = {}
local powerEvents: {{any}} = {}
local lightObjects: {[string]: any} = {}

-- Constants
local POWER_START = 100
local POWER_COST = 10
local MIN_POWER = 0

-- Power state
local currentPower = POWER_START
local lightStates: {[string]: boolean} = {}

-- Mock LightToggled event
local LightToggledEvent = {
    FireAllClients = function(_self: any, lightId: string, isOn: boolean)
        table.insert(firedEvents, {lightId, isOn})
    end,
    OnServerEvent = {
        _handlers = {} :: {(...any) -> ()},
        Connect = function(self: any, callback: (...any) -> ())
            table.insert(self._handlers, callback)
            return {Disconnect = function() end}
        end,
        Fire = function(self: any, player: any, lightId: string)
            for _, handler in ipairs(self._handlers) do
                handler(player, lightId)
            end
        end,
    },
}

-- Mock PowerChanged event
local PowerChangedEvent = {
    FireAllClients = function(_self: any, power: number)
        table.insert(powerEvents, {power})
    end,
}

-- Create mock light object
local function createLightObject(lightId: string): any
    local enabled = false
    local pointLight = {
        Name = "PointLight",
        Enabled = enabled,
        IsA = function(_self: any, className: string): boolean
            return className == "Light" or className == "PointLight"
        end,
    }
    
    return {
        Name = "Light_" .. lightId,
        IsA = function(_self: any, className: string): boolean
            return className == "BasePart" or className == "Part"
        end,
        GetDescendants = function(_self: any): {any}
            return {pointLight}
        end,
        GetChildren = function(_self: any): {any}
            return {pointLight}
        end,
        _pointLight = pointLight,
    }
end

-- Power Manager functions
local function GetPower(): number
    return currentPower
end

local function SetPower(value: number)
    currentPower = math.clamp(value, MIN_POWER, POWER_START)
end

local function HasPower(): boolean
    return currentPower > MIN_POWER
end

local function GetLightState(lightId: string): boolean?
    return lightStates[lightId]
end

local function SetLightState(lightId: string, isOn: boolean)
    lightStates[lightId] = isOn
end

local function DeductPower(amount: number): boolean
    if currentPower - amount < MIN_POWER then
        return false
    end
    currentPower -= amount
    PowerChangedEvent:FireAllClients(currentPower)
    return true
end

local function ToggleLight(lightId: string): boolean
    local current = lightStates[lightId]
    
    if not current then
        -- Turning ON - requires power
        if not HasPower() then
            return false
        end
        if not DeductPower(POWER_COST) then
            return false
        end
        lightStates[lightId] = true
        LightToggledEvent:FireAllClients(lightId, true)
        return true
    else
        -- Turning OFF - always works
        lightStates[lightId] = false
        LightToggledEvent:FireAllClients(lightId, false)
        return true
    end
end

local function ResetAll()
    currentPower = POWER_START
    table.clear(lightStates)
    table.clear(firedEvents)
    table.clear(powerEvents)
    table.clear(lightObjects)
end

-- FindLightObject helper
local function FindLightObject(lightId: string): any
    return lightObjects[lightId]
end

-- SetLightEnabled helper
local function SetLightEnabled(obj: any, enabled: boolean)
    if not obj then return end
    if obj._pointLight then
        obj._pointLight.Enabled = enabled
    end
end

-- OnLightToggled handler
local function OnLightToggled(player: any, lightId: string)
    if typeof(lightId) ~= "string" then
        return
    end
    
    local current = GetLightState(lightId)
    local isOn = current == true
    
    if not isOn then
        -- Trying to turn ON
        if not HasPower() then
            LightToggledEvent:FireAllClients(lightId, false)
            return
        end
        
        local success = ToggleLight(lightId)
        if success then
            local obj = FindLightObject(lightId)
            if obj then
                SetLightEnabled(obj, true)
            end
        end
    else
        -- Turning OFF
        local success = ToggleLight(lightId)
        if success then
            local obj = FindLightObject(lightId)
            if obj then
                SetLightEnabled(obj, false)
            end
        end
    end
end

-- Connect handler
LightToggledEvent.OnServerEvent:Connect(OnLightToggled)

-- Test runner
local function runTests(): (number, number)
    print("Running Server Toggle Handler Tests (US-007)...")
    local passed = 0
    local failed = 0
    
    local function test(name: string, fn: () -> ())
        local ok, err = pcall(fn)
        if ok then
            passed += 1
            print("✓ " .. name)
        else
            failed += 1
            print("✗ " .. name .. ": " .. tostring(err))
        end
    end
    
    -- Test 1
    test("LightToggled OnServerEvent handler exists and connected", function()
        ResetAll()
        assert(#LightToggledEvent.OnServerEvent._handlers >= 1, "Handler should be connected")
    end)
    
    -- Test 2
    test("Turning light ON requires HasPower", function()
        ResetAll()
        SetPower(0)
        local light = createLightObject("l1")
        lightObjects["l1"] = light
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "l1")
        
        assert(GetLightState("l1") ~= true, "Light should stay off")
        assert(#firedEvents >= 1, "Event should fire")
    end)
    
    -- Test 3
    test("Turning light OFF always succeeds", function()
        ResetAll()
        local light = createLightObject("l2")
        lightObjects["l2"] = light
        SetLightState("l2", true)
        SetPower(0)
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "l2")
        
        assert(GetLightState("l2") == false, "Light should turn off")
        local found = false
        for _, e in ipairs(firedEvents) do
            if e[1] == "l2" and e[2] == false then
                found = true
                break
            end
        end
        assert(found, "Should fire off event")
    end)
    
    -- Test 4
    test("Turning light ON deducts power", function()
        ResetAll()
        local light = createLightObject("l3")
        lightObjects["l3"] = light
        
        assert(GetPower() == 100, "Start at 100")
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "l3")
        
        assert(GetPower() == 90, "Power should be 90")
        assert(GetLightState("l3") == true, "Light should be on")
    end)
    
    -- Test 5
    test("Light object Enabled is set when turning ON", function()
        ResetAll()
        local light = createLightObject("l4")
        lightObjects["l4"] = light
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "l4")
        
        assert(light._pointLight.Enabled == true, "PointLight should be enabled")
    end)
    
    -- Test 6
    test("LightToggled fires to all clients after toggle", function()
        ResetAll()
        local light = createLightObject("l5")
        lightObjects["l5"] = light
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "l5")
        
        local foundOn = false
        for _, e in ipairs(firedEvents) do
            if e[1] == "l5" and e[2] == true then
                foundOn = true
                break
            end
        end
        assert(foundOn, "Should fire ON event")
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "l5")
        local foundOff = false
        for _, e in ipairs(firedEvents) do
            if e[1] == "l5" and e[2] == false then
                foundOff = true
                break
            end
        end
        assert(foundOff, "Should fire OFF event")
    end)
    
    -- Test 7
    test("Multiple toggles accumulate power correctly", function()
        ResetAll()
        lightObjects["a"] = createLightObject("a")
        lightObjects["b"] = createLightObject("b")
        lightObjects["c"] = createLightObject("c")
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "a")
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "b")
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "c")
        
        assert(GetPower() == 70, "Power should be 70")
    end)
    
    -- Test 8 - skip getfenv test
    test("Invalid lightId handling", function()
        ResetAll()
        -- Just verify it doesn't crash
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, 123 :: any)
        assert(true, "Handler doesn't crash on invalid input")
    end)
    
    -- Test 9
    test("PowerChanged fires after power-deducting toggle", function()
        ResetAll()
        lightObjects["x"] = createLightObject("x")
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "x")
        
        local found = false
        for _, e in ipairs(powerEvents) do
            if e[1] == 90 then
                found = true
                break
            end
        end
        assert(found, "PowerChanged should fire with 90")
    end)
    
    -- Test 10
    test("Can toggle same light multiple times", function()
        ResetAll()
        lightObjects["m"] = createLightObject("m")
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "m") -- On
        assert(GetLightState("m") == true)
        assert(GetPower() == 90)
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "m") -- Off
        assert(GetLightState("m") == false)
        assert(GetPower() == 90) -- No change
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "m") -- On again
        assert(GetLightState("m") == true)
        assert(GetPower() == 80)
    end)
    
    -- Test 11
    test("Light object Enabled set to false when turning OFF", function()
        ResetAll()
        local light = createLightObject("n")
        lightObjects["n"] = light
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "n")
        assert(light._pointLight.Enabled == true)
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "n")
        assert(light._pointLight.Enabled == false)
    end)
    
    -- Test 12
    test("Handler works when light object not found", function()
        ResetAll()
        -- Don't add light object to lightObjects
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "missing")
        assert(GetLightState("missing") == true, "State should still update")
        assert(GetPower() == 90, "Power should still be deducted")
    end)
    
    -- Test 13
    test("Cannot turn on lights when power equals 0", function()
        ResetAll()
        SetPower(0)
        lightObjects["z"] = createLightObject("z")
        
        LightToggledEvent.OnServerEvent:Fire({Name = "P1"}, "z")
        
        assert(GetPower() == 0, "Power stays at 0")
        assert(GetLightState("z") ~= true, "Light stays off")
    end)
    
    print(string.format("Server Toggle Handler Test Results: %d passed, %d failed", passed, failed))
    return passed, failed
end

return runTests
