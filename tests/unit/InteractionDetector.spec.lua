--!strict
--[[
    InteractionDetector Module Tests
    Validates raycast-based interaction detection functionality.
]]

-- Mock types for testing
export type MockVector3 = {
    X: number,
    Y: number,
    Z: number,
}

export type MockCFrame = {
    Position: MockVector3,
    LookVector: MockVector3,
}

export type MockCamera = {
    CFrame: MockCFrame,
}

export type MockInstance = {
    Name: string,
    ClassName: string,
    Attributes: { [string]: any },
    GetAttribute: (self: MockInstance, name: string) -> any?,    
    SetAttribute: (self: MockInstance, name: string, value: any) -> (),
}

export type RaycastResult = {
    Instance: MockInstance,
    Position: MockVector3,
    Distance: number,
}

-- Helper to create a mock Vector3
local function createMockVector3(x: number, y: number, z: number): MockVector3
    return {
        X = x,
        Y = y,
        Z = z,
    }
end

-- Helper to create a mock CFrame
local function createMockCFrame(position: MockVector3, lookVector: MockVector3): MockCFrame
    return {
        Position = position,
        LookVector = lookVector,
    }
end

-- Helper to create a mock instance
local function createMockInstance(name: string, className: string?): MockInstance
    local instance: MockInstance = {
        Name = name,
        ClassName = className or "Part",
        Attributes = {},
        GetAttribute = function(self: MockInstance, attrName: string): any?
            return self.Attributes[attrName]
        end,
        SetAttribute = function(self: MockInstance, attrName: string, value: any)
            self.Attributes[attrName] = value
        end,
    }
    return instance
end

-- Create a fresh InteractionDetector module for testing
local function createTestInteractionDetector()
    local module = {}
    
    -- Type exports
    export type DetectionResult = {
        hitObject: any?,
        hitPosition: any?,
        distance: number,
        isInteractable: boolean,
    }
    
    -- Maximum interaction distance
    local MAX_INTERACTION_DISTANCE: number = 5
    
    -- Private state
    local _isInitialized: boolean = false
    
    -- Mock services
    type TagsMap = { [any]: { [string]: boolean } }
    local MockCollectionService = {
        _tags = {} :: TagsMap,
        
        AddTag = function(self: any, instance: any, tag: string)
            if not (self :: any)._tags[instance] then
                (self :: any)._tags[instance] = {}
            end
            (self :: any)._tags[instance][tag] = true
        end,
        
        RemoveTag = function(self: any, instance: any, tag: string)
            if (self :: any)._tags[instance] then
                (self :: any)._tags[instance][tag] = false
            end
        end,
        
        HasTag = function(self: any, instance: any, tag: string): boolean
            return (self :: any)._tags[instance] and (self :: any)._tags[instance][tag] or false
        end,
    }
    
    -- Current camera
    local _currentCamera: MockCamera? = nil
    
    -- Raycast result to return (for testing)
    local _mockRaycastResult: RaycastResult? = nil
    
    -- Last raycast parameters (for verification)
    local _lastRaycastOrigin: MockVector3? = nil
    local _lastRaycastDirection: MockVector3? = nil
    
    local MockWorkspace = {
        CurrentCamera = nil,
        
        Raycast = function(self: any, origin: any, direction: any, _params: any?): RaycastResult?
            -- Store last raycast params for verification
            _lastRaycastOrigin = origin
            _lastRaycastDirection = direction
            
            -- Return preset result if set
            if _mockRaycastResult then
                return _mockRaycastResult
            end
            
            return nil -- No hit by default
        end,
        
        -- For testing: set custom result
        SetMockRaycastResult = function(result: RaycastResult?)
            _mockRaycastResult = result
        end,
        
        -- Get last raycast params
        GetLastRaycastOrigin = function(): MockVector3?
            return _lastRaycastOrigin
        end,
        
        GetLastRaycastDirection = function(): MockVector3?
            return _lastRaycastDirection
        end,
        
        -- Clear raycast params
        ClearLastRaycast = function()
            _lastRaycastOrigin = nil
            _lastRaycastDirection = nil
            _mockRaycastResult = nil
        end,
    }
    
    -- Services
    local Workspace = MockWorkspace
    local CollectionService = MockCollectionService
    
    -- Default raycast parameters
    local _defaultRaycastParams: any = {
        FilterType = 0,
        FilterDescendantsInstances = {},
        IgnoreWater = true,
    }
    
    -- Get the current camera
    local function GetCamera(): MockCamera?
        if Workspace and Workspace.CurrentCamera then
            return Workspace.CurrentCamera
        end
        return nil
    end
    
    -- Check if an object is tagged as Interactable
    function module.HasInteractableTag(instance: any): boolean
        if CollectionService and CollectionService.HasTag then
            return CollectionService:HasTag(instance, "Interactable")
        end
        return false
    end
    
    -- Check if an object has Interactable attribute set to true
    function module.HasInteractableAttribute(instance: any): boolean
        if instance and instance.GetAttribute then
            local hasAttr = instance:GetAttribute("Interactable")
            return hasAttr == true
        end
        return false
    end
    
    -- Check if an object is interactable
    function module.IsInteractable(instance: any): boolean
        if instance == nil then
            return false
        end
        
        return module.HasInteractableTag(instance) or 
               module.HasInteractableAttribute(instance)
    end
    
    -- Main detection function
    function module.Detect(): DetectionResult
        local camera = GetCamera()
        
        -- Default result with no hit
        local result: DetectionResult = {
            hitObject = nil,
            hitPosition = nil,
            distance = MAX_INTERACTION_DISTANCE,
            isInteractable = false,
        }
        
        if not camera then
            return result
        end
        
        -- Get camera CFrame
        local cameraCFrame = camera.CFrame
        if not cameraCFrame then
            return result
        end
        
        -- Get origin and direction
        local origin = cameraCFrame.Position
        local lookVector = cameraCFrame.LookVector
        
        if not origin or not lookVector then
            return result
        end
        
        -- Calculate ray end point (max distance)
        local direction = {
            X = lookVector.X * MAX_INTERACTION_DISTANCE,
            Y = lookVector.Y * MAX_INTERACTION_DISTANCE,
            Z = lookVector.Z * MAX_INTERACTION_DISTANCE,
        }
        
        -- Perform raycast
        local raycastResult: any? = nil
        
        if Workspace and Workspace.Raycast then
            raycastResult = Workspace:Raycast(origin, direction, _defaultRaycastParams)
        end
        
        -- Process raycast result
        if raycastResult then
            local hitInstance: any? = nil
            local hitPos: any? = nil
            local hitDistance: number = MAX_INTERACTION_DISTANCE
            
            if raycastResult.Instance then
                hitInstance = raycastResult.Instance
                hitPos = raycastResult.Position
                if raycastResult.Distance then
                    hitDistance = raycastResult.Distance
                else
                    -- Calculate distance
                    local dx = hitPos.X - origin.X
                    local dy = hitPos.Y - origin.Y
                    local dz = hitPos.Z - origin.Z
                    hitDistance = math.sqrt(dx * dx + dy * dy + dz * dz)
                end
            end
            
            local isInteractable = false
            if hitInstance then
                isInteractable = module.IsInteractable(hitInstance)
            end
            
            result = {
                hitObject = hitInstance,
                hitPosition = hitPos,
                distance = hitDistance,
                isInteractable = isInteractable,
            }
        end
        
        return result
    end
    
    -- Set raycast distance
    function module.SetMaxDistance(distance: number): ()
        MAX_INTERACTION_DISTANCE = distance
    end
    
    -- Get max distance
    function module.GetMaxDistance(): number
        return MAX_INTERACTION_DISTANCE
    end
    
    -- Initialize
    function module.Initialize(): ()
        _isInitialized = true
    end
    
    -- Check if initialized
    function module.IsInitialized(): boolean
        return _isInitialized
    end
    
    -- Cleanup
    function module.Cleanup(): ()
        _isInitialized = false
        Workspace.ClearLastRaycast()
    end
    
    -- For testing: Set camera directly
    function module.SetMockCamera(mockCamera: any): ()
        Workspace.CurrentCamera = mockCamera
    end
    
    -- For testing: Expose workspace for test control
    function module.GetMockWorkspace()
        return Workspace
    end
    
    -- For testing: Expose CollectionService
    function module.GetMockCollectionService()
        return CollectionService
    end
    
    return module
end

-- Run tests
local function runTests(): (number, number)
    print("Running InteractionDetector module tests...")
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
        local InteractionDetector = createTestInteractionDetector()
        assert(InteractionDetector.Detect ~= nil, "Detect function should exist")
        assert(InteractionDetector.HasInteractableTag ~= nil, "HasInteractableTag should exist")
        assert(InteractionDetector.HasInteractableAttribute ~= nil, "HasInteractableAttribute should exist")
        assert(InteractionDetector.IsInteractable ~= nil, "IsInteractable should exist")
        assert(InteractionDetector.SetMaxDistance ~= nil, "SetMaxDistance should exist")
        assert(InteractionDetector.GetMaxDistance ~= nil, "GetMaxDistance should exist")
        assert(InteractionDetector.Initialize ~= nil, "Initialize should exist")
        assert(InteractionDetector.Cleanup ~= nil, "Cleanup should exist")
    end)

    -- Test 2: Detect returns default result when no camera
    runTest("Detect returns default result when no camera", function()
        local InteractionDetector = createTestInteractionDetector()
        
        local result = InteractionDetector.Detect()
        
        assert(result.hitObject == nil, "hitObject should be nil when no camera")
        assert(result.hitPosition == nil, "hitPosition should be nil when no camera")
        assert(result.distance == 5, "distance should be MAX distance (5) when no camera")
        assert(result.isInteractable == false, "isInteractable should be false when no camera")
    end)

    -- Test 3: Raycast originates from camera position in look direction
    runTest("Raycast originates from camera position in lookDirection", function()
        local InteractionDetector = createTestInteractionDetector()
        local mockWorkspace = InteractionDetector.GetMockWorkspace()
        
        -- Create camera at position (10, 5, 0) looking in positive Z
        local cameraPos = createMockVector3(10, 5, 0)
        local lookVector = createMockVector3(0, 0, 1) -- Looking forward in Z direction
        local mockCamera: MockCamera = {
            CFrame = createMockCFrame(cameraPos, lookVector),
        }
        
        -- Set camera
        InteractionDetector.SetMockCamera(mockCamera)
        
        -- Run detection
        InteractionDetector.Detect()
        
        -- Verify raycast origin
        local origin = mockWorkspace.GetLastRaycastOrigin()
        assert(origin ~= nil, "Raycast origin should not be nil")
        assert(origin.X == 10, "Origin X should match camera position")
        assert(origin.Y == 5, "Origin Y should match camera position")
        assert(origin.Z == 0, "Origin Z should match camera position")
        
        -- Verify raycast direction (should be lookVector * max_distance = 5)
        local direction = mockWorkspace.GetLastRaycastDirection()
        assert(direction ~= nil, "Raycast direction should not be nil")
        assert(direction.X == 0, "Direction X should be 0 (no X component)")
        assert(direction.Y == 0, "Direction Y should be 0 (no Y component)")
        assert(direction.Z == 5, "Direction Z should be 5 (lookVector.Z * 5)")
    end)

    -- Test 4: Max raycast distance is exactly 5 studs
    runTest("Max raycast distance is exactly 5 studs", function()
        local InteractionDetector = createTestInteractionDetector()
        
        local maxDistance = InteractionDetector.GetMaxDistance()
        assert(maxDistance == 5, "Max distance should be exactly 5 studs")
    end)

    -- Test 5: Raycast direction scales correctly with different look vectors
    runTest("Raycast direction scales correctly with different look vectors", function()
        local InteractionDetector = createTestInteractionDetector()
        local mockWorkspace = InteractionDetector.GetMockWorkspace()
        
        -- Test with different look directions
        local cameraPos = createMockVector3(0, 0, 0)
        
        -- Looking right (positive X)
        local mockCamera: MockCamera = {
            CFrame = createMockCFrame(cameraPos, createMockVector3(1, 0, 0)),
        }
        InteractionDetector.SetMockCamera(mockCamera)
        InteractionDetector.Detect()
        
        local direction = mockWorkspace.GetLastRaycastDirection()
        assert(direction.X == 5, "Direction X should be 5 (looking right)")
        assert(direction.Y == 0, "Direction Y should be 0")
        assert(direction.Z == 0, "Direction Z should be 0")
        
        mockWorkspace.ClearLastRaycast()
        
        -- Looking up (positive Y)
        mockCamera = {
            CFrame = createMockCFrame(cameraPos, createMockVector3(0, 1, 0)),
        }
        InteractionDetector.SetMockCamera(mockCamera)
        InteractionDetector.Detect()
        
        direction = mockWorkspace.GetLastRaycastDirection()
        assert(direction.X == 0, "Direction X should be 0")
        assert(direction.Y == 5, "Direction Y should be 5 (looking up)")
        assert(direction.Z == 0, "Direction Z should be 0")
        
        mockWorkspace.ClearLastRaycast()
        
        -- Looking diagonally
        mockCamera = {
            CFrame = createMockCFrame(cameraPos, createMockVector3(0.7071, 0.7071, 0)), -- 45 degrees
        }
        InteractionDetector.SetMockCamera(mockCamera)
        InteractionDetector.Detect()
        
        direction = mockWorkspace.GetLastRaycastDirection()
        -- 0.7071 * 5 ≈ 3.5355
        local expected = 0.7071 * 5
        local tolerance = 0.001
        assert(math.abs(direction.X - expected) < tolerance, "Direction X should be scaled")
        assert(math.abs(direction.Y - expected) < tolerance, "Direction Y should be scaled")
        assert(direction.Z == 0, "Direction Z should be 0")
    end)

    -- Test 6: Returns hit object and position from raycast
    runTest("Returns hit object and position from raycast", function()
        local InteractionDetector = createTestInteractionDetector()
        local mockWorkspace = InteractionDetector.GetMockWorkspace()
        
        -- Create mock hit instance
        local hitInstance = createMockInstance("HitPart")
        local hitPosition = createMockVector3(3, 0, 0)
        
        -- Set up raycast result
        local raycastResult: RaycastResult = {
            Instance = hitInstance,
            Position = hitPosition,
            Distance = 3,
        }
        mockWorkspace.SetMockRaycastResult(raycastResult)
        
        -- Setup camera
        local mockCamera: MockCamera = {
            CFrame = createMockCFrame(createMockVector3(0, 0, 0), createMockVector3(1, 0, 0)),
        }
        InteractionDetector.SetMockCamera(mockCamera)
        
        -- Detect
        local result = InteractionDetector.Detect()
        
        assert(result.hitObject == hitInstance, "hitObject should be the hit instance")
        assert(result.hitPosition == hitPosition, "hitPosition should match")
        assert(result.distance == 3, "distance should match raycast result")
        assert(result.isInteractable == false, "isInteractable should be false (no tag/attr)")
        
        mockWorkspace.ClearLastRaycast()
    end)

    -- Test 7: HasInteractableTag returns true for tagged objects
    runTest("HasInteractableTag returns true for tagged objects", function()
        local InteractionDetector = createTestInteractionDetector()
        local collectionService = InteractionDetector.GetMockCollectionService()
        
        local instance = createMockInstance("TestPart")
        
        -- Should be false initially
        assert(InteractionDetector.HasInteractableTag(instance) == false, "Should be false initially")
        
        -- Add tag
        collectionService:AddTag(instance, "Interactable")
        
        -- Should be true after adding tag
        assert(InteractionDetector.HasInteractableTag(instance) == true, "Should be true after adding tag")
    end)

    -- Test 8: HasInteractableAttribute returns true when attribute is true
    runTest("HasInteractableAttribute returns true when attribute is true", function()
        local InteractionDetector = createTestInteractionDetector()
        
        local instance = createMockInstance("TestPart")
        
        -- Should be false initially
        assert(InteractionDetector.HasInteractableAttribute(instance) == false, "Should be false initially")
        
        -- Set attribute to true
        instance:SetAttribute("Interactable", true)
        
        -- Should be true after setting attribute
        assert(InteractionDetector.HasInteractableAttribute(instance) == true, "Should be true after setting attribute")
    end)

    -- Test 9: HasInteractableAttribute returns false for falsy attribute values
    runTest("HasInteractableAttribute returns false for falsy attribute values", function()
        local InteractionDetector = createTestInteractionDetector()
        
        local instance1 = createMockInstance("TestPart1")
        local instance2 = createMockInstance("TestPart2")
        local instance3 = createMockInstance("TestPart3")
        
        instance1:SetAttribute("Interactable", false)
        instance2:SetAttribute("Interactable", nil)
        instance3:SetAttribute("Interactable", "string")
        
        assert(InteractionDetector.HasInteractableAttribute(instance1) == false, "False value should return false")
        assert(InteractionDetector.HasInteractableAttribute(instance2) == false, "Nil value should return false")
        assert(InteractionDetector.HasInteractableAttribute(instance3) == false, "String value should return false")
    end)

    -- Test 10: IsInteractable returns true for tagged objects
    runTest("IsInteractable returns true for tagged objects", function()
        local InteractionDetector = createTestInteractionDetector()
        local mockWorkspace = InteractionDetector.GetMockWorkspace()
        local collectionService = InteractionDetector.GetMockCollectionService()
        
        local hitInstance = createMockInstance("TaggedPart")
        collectionService:AddTag(hitInstance, "Interactable")
        
        local raycastResult: RaycastResult = {
            Instance = hitInstance,
            Position = createMockVector3(2, 0, 0),
            Distance = 2,
        }
        mockWorkspace.SetMockRaycastResult(raycastResult)
        
        local mockCamera: MockCamera = {
            CFrame = createMockCFrame(createMockVector3(0, 0, 0), createMockVector3(1, 0, 0)),
        }
        InteractionDetector.SetMockCamera(mockCamera)
        
        local result = InteractionDetector.Detect()
        
        assert(result.isInteractable == true, "isInteractable should be true for tagged object")
        
        mockWorkspace.ClearLastRaycast()
    end)

    -- Test 11: IsInteractable returns true for objects with Interactable=true attribute
    runTest("IsInteractable returns true for objects with Interactable=true attribute", function()
        local InteractionDetector = createTestInteractionDetector()
        local mockWorkspace = InteractionDetector.GetMockWorkspace()
        
        local hitInstance = createMockInstance("AttributedPart")
        hitInstance:SetAttribute("Interactable", true)
        
        local raycastResult: RaycastResult = {
            Instance = hitInstance,
            Position = createMockVector3(2, 0, 0),
            Distance = 2,
        }
        mockWorkspace.SetMockRaycastResult(raycastResult)
        
        local mockCamera: MockCamera = {
            CFrame = createMockCFrame(createMockVector3(0, 0, 0), createMockVector3(1, 0, 0)),
        }
        InteractionDetector.SetMockCamera(mockCamera)
        
        local result = InteractionDetector.Detect()
        
        assert(result.isInteractable == true, "isInteractable should be true for attributed object")
        
        mockWorkspace.ClearLastRaycast()
    end)

    -- Test 12: IsInteractable returns false for objects without tag or attribute
    runTest("IsInteractable returns false for objects without tag or attribute", function()
        local InteractionDetector = createTestInteractionDetector()
        local mockWorkspace = InteractionDetector.GetMockWorkspace()
        
        local hitInstance = createMockInstance("RegularPart")
        -- No tag or attribute set
        
        local raycastResult: RaycastResult = {
            Instance = hitInstance,
            Position = createMockVector3(2, 0, 0),
            Distance = 2,
        }
        mockWorkspace.SetMockRaycastResult(raycastResult)
        
        local mockCamera: MockCamera = {
            CFrame = createMockCFrame(createMockVector3(0, 0, 0), createMockVector3(1, 0, 0)),
        }
        InteractionDetector.SetMockCamera(mockCamera)
        
        local result = InteractionDetector.Detect()
        
        assert(result.isInteractable == false, "isInteractable should be false for regular object")
        
        mockWorkspace.ClearLastRaycast()
    end)

    -- Test 13: SetMaxDistance changes the max distance
    runTest("SetMaxDistance changes the max distance", function()
        local InteractionDetector = createTestInteractionDetector()
        
        -- Default is 5
        assert(InteractionDetector.GetMaxDistance() == 5, "Default max distance should be 5")
        
        -- Change to 10
        InteractionDetector.SetMaxDistance(10)
        assert(InteractionDetector.GetMaxDistance() == 10, "Max distance should be 10 after setting")
        
        -- Change to 3
        InteractionDetector.SetMaxDistance(3)
        assert(InteractionDetector.GetMaxDistance() == 3, "Max distance should be 3 after setting")
        
        -- Reset to default for other tests
        InteractionDetector.SetMaxDistance(5)
    end)

    -- Test 14: Initialize and Cleanup work correctly
    runTest("Initialize and Cleanup work correctly", function()
        local InteractionDetector = createTestInteractionDetector()
        
        assert(InteractionDetector.IsInitialized() == false, "Should not be initialized initially")
        
        InteractionDetector.Initialize()
        assert(InteractionDetector.IsInitialized() == true, "Should be initialized after Initialize()")
        
        InteractionDetector.Cleanup()
        assert(InteractionDetector.IsInitialized() == false, "Should not be initialized after Cleanup()")
    end)

    -- Test 15: Detect returns nil for hitObject and hitPosition when no raycast hit
    runTest("Detect returns nil values when no raycast hit", function()
        local InteractionDetector = createTestInteractionDetector()
        local mockWorkspace = InteractionDetector.GetMockWorkspace()
        
        -- No hit set (nil result)
        
        local mockCamera: MockCamera = {
            CFrame = createMockCFrame(createMockVector3(0, 0, 0), createMockVector3(1, 0, 0)),
        }
        InteractionDetector.SetMockCamera(mockCamera)
        
        local result = InteractionDetector.Detect()
        
        assert(result.hitObject == nil, "hitObject should be nil when no hit")
        assert(result.hitPosition == nil, "hitPosition should be nil when no hit")
        assert(result.distance == 5, "distance should be max when no hit")
        assert(result.isInteractable == false, "isInteractable should be false when no hit")
    end)

    -- Test 16: IsInteractable handles nil instance gracefully
    runTest("IsInteractable handles nil instance gracefully", function()
        local InteractionDetector = createTestInteractionDetector()
        
        local result = InteractionDetector.IsInteractable(nil)
        assert(result == false, "IsInteractable should return false for nil")
    end)

    -- Test 17: Distance calculation when not provided in raycast result
    runTest("Distance calculation when not provided in raycast result", function()
        local InteractionDetector = createTestInteractionDetector()
        local mockWorkspace = InteractionDetector.GetMockWorkspace()
        
        -- Create a hit at position (3, 4, 0) from origin (0, 0, 0)
        -- Distance should be 5 (3-4-5 triangle)
        local hitInstance = createMockInstance("HitPart")
        local hitPosition = createMockVector3(3, 4, 0)
        
        local raycastResult = {
            Instance = hitInstance,
            Position = hitPosition,
            -- No Distance provided - should be calculated
        }
        mockWorkspace.SetMockRaycastResult(raycastResult)
        
        local mockCamera: MockCamera = {
            CFrame = createMockCFrame(createMockVector3(0, 0, 0), createMockVector3(1, 0, 0)),
        }
        InteractionDetector.SetMockCamera(mockCamera)
        
        local result = InteractionDetector.Detect()
        
        -- Distance is 3-4-5 triangle hypotenuse = 5
        assert(result.distance == 5, "Distance should be calculated from positions when not provided")
    end)

    -- Test 18: Returns hit object even when not interactable
    runTest("Returns hit object even when not interactable", function()
        local InteractionDetector = createTestInteractionDetector()
        local mockWorkspace = InteractionDetector.GetMockWorkspace()
        
        local hitInstance = createMockInstance("NonInteractable")
        -- No tag or attribute
        
        local raycastResult: RaycastResult = {
            Instance = hitInstance,
            Position = createMockVector3(3, 0, 0),
            Distance = 3,
        }
        mockWorkspace.SetMockRaycastResult(raycastResult)
        
        local mockCamera: MockCamera = {
            CFrame = createMockCFrame(createMockVector3(0, 0, 0), createMockVector3(1, 0, 0)),
        }
        InteractionDetector.SetMockCamera(mockCamera)
        
        local result = InteractionDetector.Detect()
        
        assert(result.hitObject == hitInstance, "hitObject should be returned even if not interactable")
        assert(result.hitPosition ~= nil, "hitPosition should be returned")
        assert(result.isInteractable == false, "isInteractable should be false")
    end)

    print(string.format("Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests
