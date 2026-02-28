--!strict
--[[
    ObjectHighlighter Module Tests
    Validates highlighting behavior for interactable objects.
]]

-- Mock types for testing
export type MockInstance = {
    Name: string,
    ClassName: string,
    Parent: any?,
    Attributes: { [string]: any },
    GetAttribute: (self: MockInstance, name: string) -> any?,
    SetAttribute: (self: MockInstance, name: string, value: any) -> (),
    _children: { [any]: boolean },
}

export type MockHighlight = {
    Name: string,
    FillColor: { [string]: any },
    OutlineColor: { [string]: any },
    FillTransparency: number,
    OutlineTransparency: number,
    Parent: MockInstance?,
    _isDestroyed: boolean,
    Destroy: (self: MockHighlight) -> (),
}

-- Helper to create a mock instance
local function createMockInstance(name: string, className: string?): MockInstance
    local instance: MockInstance = {
        Name = name,
        ClassName = className or "Part",
        Parent = nil,
        Attributes = {},
        _children = {},
        GetAttribute = function(self: MockInstance, attrName: string): any?
            return self.Attributes[attrName]
        end,
        SetAttribute = function(self: MockInstance, attrName: string, value: any)
            self.Attributes[attrName] = value
        end,
    }
    return instance
end

-- Create a fresh ObjectHighlighter module for testing
local function createTestObjectHighlighter()
    local module = {}
    
    -- Constants
    local HIGHLIGHT_FILL_COLOR = { R = 255, G = 215, B = 0 }
    local HIGHLIGHT_OUTLINE_COLOR = { R = 255, G = 255, B = 0 }
    
    -- Private state
    local _isInitialized: boolean = false
    local _currentHighlight: any? = nil
    local _currentTarget: any? = nil
    
    -- Create a highlight for a target object
    function module.CreateHighlight(targetObject: any): any?
        if not targetObject then
            return nil
        end
        
        -- Clean up any existing highlight
        module.RemoveHighlight()
        
        -- Create mock highlight
        local highlight: MockHighlight = {
            Name = "Highlight",
            FillColor = HIGHLIGHT_FILL_COLOR,
            OutlineColor = HIGHLIGHT_OUTLINE_COLOR,
            FillTransparency = 0.5,
            OutlineTransparency = 0,
            Parent = targetObject,
            _isDestroyed = false,
            Destroy = function(self: any)
                self._isDestroyed = true
                self.Parent = nil
            end,
        }
        
        -- Store current state
        _currentHighlight = highlight
        _currentTarget = targetObject
        
        -- Track children on target for debugging
        targetObject._children = targetObject._children or {}
        targetObject._children[highlight] = true
        
        return highlight
    end
    
    -- Remove the current highlight
    function module.RemoveHighlight(): ()
        if _currentHighlight and _currentHighlight.Destroy then
            _currentHighlight:Destroy()
        end
        
        _currentHighlight = nil
        _currentTarget = nil
    end
    
    -- Update highlight based on detection result
    function module.Update(detectionResult: any): ()
        if not _isInitialized then
            return
        end
        
        local hitObject = detectionResult and detectionResult.hitObject
        local isInteractable = detectionResult and detectionResult.isInteractable
        
        -- Check if we should highlight this object
        if hitObject and isInteractable then
            -- If it's a different object than current, update highlight
            if _currentTarget ~= hitObject then
                module.CreateHighlight(hitObject)
            end
        else
            -- Remove highlight if no valid interactable in range
            module.RemoveHighlight()
        end
    end
    
    -- Get the current highlighted target
    function module.GetCurrentTarget(): any?
        return _currentTarget
    end
    
    -- Get the current highlight instance
    function module.GetCurrentHighlight(): any?
        return _currentHighlight
    end
    
    -- Check if an object is currently highlighted
    function module.IsHighlighted(targetObject: any): boolean
        return _currentTarget == targetObject and _currentTarget ~= nil
    end
    
    -- Initialize the highlighter
    function module.Initialize(): ()
        _isInitialized = true
    end
    
    -- Check if initialized
    function module.IsInitialized(): boolean
        return _isInitialized
    end
    
    -- Cleanup all highlights and reset state
    function module.Cleanup(): ()
        module.RemoveHighlight()
        _isInitialized = false
    end
    
    -- Get the fill color constant
    function module.GetFillColor(): any
        return HIGHLIGHT_FILL_COLOR
    end
    
    -- Get the outline color constant
    function module.GetOutlineColor(): any
        return HIGHLIGHT_OUTLINE_COLOR
    end
    
    -- For testing: Set highlight directly
    function module.SetMockHighlight(highlight: any): ()
        _currentHighlight = highlight
    end
    
    -- For testing: Set target directly
    function module.SetMockTarget(target: any): ()
        _currentTarget = target
    end
    
    return module
end

-- Run tests
local function runTests(): (number, number)
    print("Running ObjectHighlighter module tests...")
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
        local ObjectHighlighter = createTestObjectHighlighter()
        assert(ObjectHighlighter.CreateHighlight ~= nil, "CreateHighlight function should exist")
        assert(ObjectHighlighter.RemoveHighlight ~= nil, "RemoveHighlight function should exist")
        assert(ObjectHighlighter.Update ~= nil, "Update function should exist")
        assert(ObjectHighlighter.IsHighlighted ~= nil, "IsHighlighted function should exist")
        assert(ObjectHighlighter.Initialize ~= nil, "Initialize function should exist")
        assert(ObjectHighlighter.Cleanup ~= nil, "Cleanup function should exist")
        assert(ObjectHighlighter.GetFillColor ~= nil, "GetFillColor function should exist")
        assert(ObjectHighlighter.GetOutlineColor ~= nil, "GetOutlineColor function should exist")
        assert(ObjectHighlighter.GetCurrentTarget ~= nil, "GetCurrentTarget function should exist")
        assert(ObjectHighlighter.GetCurrentHighlight ~= nil, "GetCurrentHighlight function should exist")
    end)

    -- Test 2: CreateHighlight creates highlight with correct colors
    runTest("CreateHighlight sets correct fill and outline colors", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("TestPart")
        local highlight = ObjectHighlighter.CreateHighlight(target)
        
        assert(highlight ~= nil, "Highlight should be created")
        assert(highlight.FillColor ~= nil, "FillColor should be set")
        assert(highlight.FillColor.R == 255, "FillColor R should be 255")
        assert(highlight.FillColor.G == 215, "FillColor G should be 215")
        assert(highlight.FillColor.B == 0, "FillColor B should be 0")
        assert(highlight.OutlineColor ~= nil, "OutlineColor should be set")
        assert(highlight.OutlineColor.R == 255, "OutlineColor R should be 255")
        assert(highlight.OutlineColor.G == 255, "OutlineColor G should be 255")
        assert(highlight.OutlineColor.B == 0, "OutlineColor B should be 0")
    end)

    -- Test 3: CreateHighlight sets correct transparency values
    runTest("CreateHighlight sets correct transparency values", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("TestPart")
        local highlight = ObjectHighlighter.CreateHighlight(target)
        
        assert(highlight ~= nil, "Highlight should be created")
        assert(highlight.FillTransparency == 0.5, "FillTransparency should be 0.5")
        assert(highlight.OutlineTransparency == 0, "OutlineTransparency should be 0")
    end)

    -- Test 4: CreateHighlight sets parent to target object
    runTest("CreateHighlight sets parent to target object", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("TestPart")
        local highlight = ObjectHighlighter.CreateHighlight(target)
        
        assert(highlight ~= nil, "Highlight should be created")
        assert(highlight.Parent == target, "Highlight parent should be target object")
    end)

    -- Test 5: RemoveHighlight destroys current highlight
    runTest("RemoveHighlight destroys current highlight", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("TestPart")
        local highlight = ObjectHighlighter.CreateHighlight(target)
        
        assert(highlight ~= nil, "Highlight should be created")
        assert(highlight._isDestroyed == false, "Highlight should not be destroyed initially")
        
        ObjectHighlighter.RemoveHighlight()
        
        assert(highlight._isDestroyed == true, "Highlight should be destroyed after RemoveHighlight")
    end)

    -- Test 6: RemoveHighlight clears current target
    runTest("RemoveHighlight clears current target", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("TestPart")
        ObjectHighlighter.CreateHighlight(target)
        
        assert(ObjectHighlighter.GetCurrentTarget() == target, "Target should be set")
        
        ObjectHighlighter.RemoveHighlight()
        
        assert(ObjectHighlighter.GetCurrentTarget() == nil, "Target should be nil after RemoveHighlight")
    end)

    -- Test 7: CreateHighlight removes previous highlight when creating new one
    runTest("CreateHighlight removes previous highlight when creating new one", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target1 = createMockInstance("Part1")
        local target2 = createMockInstance("Part2")
        
        local highlight1 = ObjectHighlighter.CreateHighlight(target1)
        assert(highlight1 ~= nil, "First highlight should be created")
        
        local highlight2 = ObjectHighlighter.CreateHighlight(target2)
        assert(highlight2 ~= nil, "Second highlight should be created")
        
        assert(highlight1._isDestroyed == true, "First highlight should be destroyed")
        assert(highlight2._isDestroyed == false, "Second highlight should not be destroyed")
        assert(ObjectHighlighter.GetCurrentTarget() == target2, "Current target should be target2")
    end)

    -- Test 8: Update creates highlight for interactable object
    runTest("Update creates highlight for interactable object", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("InteractablePart")
        local detectionResult = {
            hitObject = target,
            hitPosition = { X = 3, Y = 0, Z = 0 },
            distance = 3,
            isInteractable = true,
        }
        
        ObjectHighlighter.Update(detectionResult)
        
        assert(ObjectHighlighter.GetCurrentTarget() == target, "Target should be set")
        assert(ObjectHighlighter.IsHighlighted(target), "Target should be highlighted")
    end)

    -- Test 9: Update removes highlight when object not interactable
    runTest("Update removes highlight when object not interactable", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("InteractablePart")
        
        -- First create a highlight
        ObjectHighlighter.CreateHighlight(target)
        assert(ObjectHighlighter.IsHighlighted(target), "Target should be highlighted initially")
        
        -- Update with non-interactable result
        local detectionResult = {
            hitObject = target,
            hitPosition = { X = 3, Y = 0, Z = 0 },
            distance = 3,
            isInteractable = false,
        }
        ObjectHighlighter.Update(detectionResult)
        
        assert(ObjectHighlighter.IsHighlighted(target) == false, "Target should NOT be highlighted")
        assert(ObjectHighlighter.GetCurrentTarget() == nil, "Current target should be nil")
    end)

    -- Test 10: Update removes highlight when no hit object
    runTest("Update removes highlight when no hit object", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("InteractablePart")
        
        -- First create a highlight
        ObjectHighlighter.CreateHighlight(target)
        assert(ObjectHighlighter.IsHighlighted(target), "Target should be highlighted initially")
        
        -- Update with no hit
        local detectionResult = {
            hitObject = nil,
            hitPosition = nil,
            distance = 5,
            isInteractable = false,
        }
        ObjectHighlighter.Update(detectionResult)
        
        assert(ObjectHighlighter.GetCurrentTarget() == nil, "Target should be nil after update")
    end)

    -- Test 11: Update does nothing when not initialized
    runTest("Update does nothing when not initialized", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        -- Do NOT initialize
        
        local target = createMockInstance("InteractablePart")
        local detectionResult = {
            hitObject = target,
            hitPosition = { X = 3, Y = 0, Z = 0 },
            distance = 3,
            isInteractable = true,
        }
        
        -- Should not create highlight because not initialized
        ObjectHighlighter.Update(detectionResult)
        
        assert(ObjectHighlighter.GetCurrentTarget() == nil, "Target should remain nil when not initialized")
    end)

    -- Test 12: Highlight switches to new interactable object
    runTest("Highlight switches to new interactable object", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target1 = createMockInstance("Part1")
        local target2 = createMockInstance("Part2")
        
        -- First highlight target1
        ObjectHighlighter.CreateHighlight(target1)
        assert(ObjectHighlighter.IsHighlighted(target1), "Target1 should be highlighted")
        
        -- Update with target2
        local detectionResult = {
            hitObject = target2,
            hitPosition = { X = 3, Y = 0, Z = 0 },
            distance = 3,
            isInteractable = true,
        }
        ObjectHighlighter.Update(detectionResult)
        
        assert(ObjectHighlighter.IsHighlighted(target1) == false, "Target1 should no longer be highlighted")
        assert(ObjectHighlighter.IsHighlighted(target2), "Target2 should be highlighted")
    end)

    -- Test 13: Initialize and Cleanup work correctly
    runTest("Initialize and Cleanup work correctly", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        
        assert(ObjectHighlighter.IsInitialized() == false, "Should not be initialized initially")
        
        ObjectHighlighter.Initialize()
        assert(ObjectHighlighter.IsInitialized() == true, "Should be initialized after Initialize()")
        
        ObjectHighlighter.Cleanup()
        assert(ObjectHighlighter.IsInitialized() == false, "Should not be initialized after Cleanup()")
    end)

    -- Test 14: Cleanup removes highlight
    runTest("Cleanup removes highlight", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("TestPart")
        ObjectHighlighter.CreateHighlight(target)
        assert(ObjectHighlighter.GetCurrentTarget() == target, "Target should be set")
        
        ObjectHighlighter.Cleanup()
        assert(ObjectHighlighter.GetCurrentTarget() == nil, "Target should be nil after Cleanup()")
        assert(ObjectHighlighter.IsInitialized() == false, "Should not be initialized")
    end)

    -- Test 15: GetFillColor returns correct color
    runTest("GetFillColor returns correct color", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        local fillColor = ObjectHighlighter.GetFillColor()
        
        assert(fillColor ~= nil, "Fill color should not be nil")
        assert(fillColor.R == 255, "FillColor R should be 255")
        assert(fillColor.G == 215, "FillColor G should be 215")
        assert(fillColor.B == 0, "FillColor B should be 0")
    end)

    -- Test 16: GetOutlineColor returns correct color
    runTest("GetOutlineColor returns correct color", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        local outlineColor = ObjectHighlighter.GetOutlineColor()
        
        assert(outlineColor ~= nil, "Outline color should not be nil")
        assert(outlineColor.R == 255, "OutlineColor R should be 255")
        assert(outlineColor.G == 255, "OutlineColor G should be 255")
        assert(outlineColor.B == 0, "OutlineColor B should be 0")
    end)

    -- Test 17: CreateHighlight returns nil for nil target
    runTest("CreateHighlight returns nil for nil target", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local highlight = ObjectHighlighter.CreateHighlight(nil)
        
        assert(highlight == nil, "Highlight should be nil for nil target")
    end)

    -- Test 18: GetCurrentHighlight returns the highlight instance
    runTest("GetCurrentHighlight returns the current highlight instance", function()
        local ObjectHighlighter = createTestObjectHighlighter()
        ObjectHighlighter.Initialize()
        
        local target = createMockInstance("TestPart")
        local highlight = ObjectHighlighter.CreateHighlight(target)
        
        assert(ObjectHighlighter.GetCurrentHighlight() == highlight, "GetCurrentHighlight should return the created highlight")
        
        ObjectHighlighter.RemoveHighlight()
        assert(ObjectHighlighter.GetCurrentHighlight() == nil, "GetCurrentHighlight should return nil after removal")
    end)

    print(string.format("Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests
