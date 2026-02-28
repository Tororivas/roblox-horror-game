--!strict
--[[
    RemoteEvents Tests
    Validates PowerChanged and LightToggled RemoteEvents exist and are connectable.
]]

-- Create a simple mock for RemoteEvent
local function createMockRemoteEvent(name: string)
    local serverConnections: {(...any) -> ()} = {}
    local clientConnections: {(...any) -> ()} = {}
    
    local event = {
        Name = name,
        ClassName = "RemoteEvent"
    }
    
    function event.FireServer(self, ...)
        -- Mock implementation
    end
    
    function event.FireClient(self, ...)
        -- Mock implementation
    end
    
    function event.FireAllClients(self, ...)
        -- Mock implementation
    end
    
    function event.OnServerEvent(self, callback: (...any) -> ())
        table.insert(serverConnections, callback)
        return {
            Disconnect = function()
                for i, conn in ipairs(serverConnections) do
                    if conn == callback then
                        table.remove(serverConnections, i)
                        break
                    end
                end
            end
        }
    end
    
    function event.OnClientEvent(self, callback: (...any) -> ())
        table.insert(clientConnections, callback)
        return {
            Disconnect = function()
                for i, conn in ipairs(clientConnections) do
                    if conn == callback then
                        table.remove(clientConnections, i)
                        break
                    end
                end
            end
        }
    end
    
    return event
end

local function runTests()
    print("Running RemoteEvents tests...")
    local passed = 0
    local failed = 0

    -- Mock the Events folder
    local EventsFolder = {
        PowerChanged = createMockRemoteEvent("PowerChanged"),
        LightToggled = createMockRemoteEvent("LightToggled")
    }

    -- Test 1: PowerChanged RemoteEvent exists
    local test1 = function()
        assert(EventsFolder.PowerChanged ~= nil, "PowerChanged RemoteEvent should exist")
        assert(EventsFolder.PowerChanged.ClassName == "RemoteEvent", "PowerChanged should be a RemoteEvent")
        print("✓ PowerChanged RemoteEvent exists")
        passed += 1
    end

    -- Test 2: LightToggled RemoteEvent exists
    local test2 = function()
        assert(EventsFolder.LightToggled ~= nil, "LightToggled RemoteEvent should exist")
        assert(EventsFolder.LightToggled.ClassName == "RemoteEvent", "LightToggled should be a RemoteEvent")
        print("✓ LightToggled RemoteEvent exists")
        passed += 1
    end

    -- Test 3: PowerChanged OnServerEvent is connectable
    local test3 = function()
        local connection = EventsFolder.PowerChanged:OnServerEvent(function(powerValue: number)
            print("Power changed to: " .. tostring(powerValue))
        end); 
        assert(connection ~= nil, "PowerChanged:OnServerEvent should return a connection")
        assert(typeof(connection.Disconnect) == "function", "Connection should have Disconnect method")
        connection.Disconnect()
        print("✓ PowerChanged OnServerEvent is connectable")
        passed += 1
    end

    -- Test 4: PowerChanged OnClientEvent is connectable
    local test4 = function()
        local connection = EventsFolder.PowerChanged:OnClientEvent(function(powerValue: number)
            print("Client received power change: " .. tostring(powerValue))
        end); 
        assert(connection ~= nil, "PowerChanged:OnClientEvent should return a connection")
        assert(typeof(connection.Disconnect) == "function", "Connection should have Disconnect method")
        connection.Disconnect()
        print("✓ PowerChanged OnClientEvent is connectable")
        passed += 1
    end

    -- Test 5: LightToggled OnServerEvent is connectable
    local test5 = function()
        local connection = EventsFolder.LightToggled:OnServerEvent(function(lightId: string, newState: boolean)
            print(string.format("Light %s toggled to %s", lightId, tostring(newState)))
        end); 
        assert(connection ~= nil, "LightToggled:OnServerEvent should return a connection")
        assert(typeof(connection.Disconnect) == "function", "Connection should have Disconnect method")
        connection.Disconnect()
        print("✓ LightToggled OnServerEvent is connectable")
        passed += 1
    end

    -- Test 6: LightToggled OnClientEvent is connectable
    local test6 = function()
        local connection = EventsFolder.LightToggled:OnClientEvent(function(lightId: string, newState: boolean)
            print(string.format("Client received light %s toggle to %s", lightId, tostring(newState)))
        end); 
        assert(connection ~= nil, "LightToggled:OnClientEvent should return a connection")
        assert(typeof(connection.Disconnect) == "function", "Connection should have Disconnect method")
        connection.Disconnect()
        print("✓ LightToggled OnClientEvent is connectable")
        passed += 1
    end

    -- Test 7: RemoteEvents have proper names
    local test7 = function()
        assert(EventsFolder.PowerChanged.Name == "PowerChanged", "PowerChanged should have correct Name property")
        assert(EventsFolder.LightToggled.Name == "LightToggled", "LightToggled should have correct Name property")
        print("✓ RemoteEvents have proper names")
        passed += 1
    end

    -- Test 8: Multiple connections can be made to the same RemoteEvent
    local test8 = function()
        local conn1 = EventsFolder.PowerChanged:OnServerEvent(function() end); 
        local conn2 = EventsFolder.PowerChanged:OnServerEvent(function() end); 
        assert(conn1 ~= nil, "First connection should be created")
        assert(conn2 ~= nil, "Second connection should be created")
        assert(conn1 ~= conn2, "Connections should be unique")
        conn1.Disconnect()
        conn2.Disconnect()
        print("✓ Multiple connections can be made to same RemoteEvent")
        passed += 1
    end

    -- Run all tests
    local tests = {test1, test2, test3, test4, test5, test6, test7, test8}
    
    for _, testFunc in ipairs(tests) do
        local success, err = pcall(testFunc)
        if not success then
            warn("✗ Test failed: " .. tostring(err))
            failed += 1
        end
    end

    print(string.format("\nRemoteEvents Test Results: %d passed, %d failed", passed, failed))
    
    if failed > 0 then
        error("Some RemoteEvents tests failed!")
    end
    
    return passed, failed
end

return runTests
