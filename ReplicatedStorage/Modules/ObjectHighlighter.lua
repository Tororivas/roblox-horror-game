--!strict
--[[
    ObjectHighlighter Module
    Manages visual highlighting of interactable objects.
    Creates/destroys Highlight instances when objects enter/exit interaction range.
]]

-- Target colors for highlighting - use mock for typechecking
local Color3: any
local Instance: any = nil

-- Try to get real Color3
local success, result = pcall(function()
    return (game :: any):GetService("Color3")
end)
if success then
    Color3 = result
end

-- Mock Color3 for non-Roblox environments
if typeof(Color3) ~= "table" then
    Color3 = {
        fromRGB = function(r: number, g: number, b: number): any
            return { R = r, G = g, B = b }
        end
    }
end

-- Try to get real Instance (which is actually a global, not a service)
pcall(function()
    if typeof(Instance) ~= "nil" then
        -- Instance exists
    end
end)

local HIGHLIGHT_FILL_COLOR = Color3.fromRGB(255, 215, 0)   -- Gold/Yellow
local HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 0) -- Bright yellow

-- Module table
local ObjectHighlighter = {}

-- Private state
local _isInitialized: boolean = false
local _currentHighlight: any? = nil
local _currentTarget: any? = nil

-- Get RunService or use mock
local RunService: any

local MockRunService: any = {
    IsRunning = function(): boolean
        return false
    end,
}

-- Try to get real RunService
local success2: boolean, result2: any = pcall(function()
    return (game :: any):GetService("RunService")
end)

if success2 then
    RunService = result2
else
    RunService = MockRunService
end

-- Check if we're in a real Roblox environment
local function IsRealRobloxEnvironment(): boolean
    if RunService and RunService.IsRunning then
        return RunService:IsRunning()
    end
    return false
end

-- Create a highlight for a target object
-- Returns the highlight instance
function ObjectHighlighter.CreateHighlight(targetObject: any): any?
    if not targetObject then
        return nil
    end
    
    -- Clean up any existing highlight
    ObjectHighlighter.RemoveHighlight()
    
    -- Create new Highlight instance
    local highlight
    
    if IsRealRobloxEnvironment() then
        -- Real Roblox environment - create using Instance if available
        local inst = (Instance :: any)
        highlight = inst.new("Highlight")
        highlight.FillColor = HIGHLIGHT_FILL_COLOR
        highlight.OutlineColor = HIGHLIGHT_OUTLINE_COLOR
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = targetObject
    else
        -- Mock environment for testing
        highlight = {
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
    end
    
    -- Store current state
    _currentHighlight = highlight
    _currentTarget = targetObject
    
    return highlight
end

-- Remove the current highlight
function ObjectHighlighter.RemoveHighlight(): ()
    if _currentHighlight and _currentHighlight.Destroy then
        _currentHighlight:Destroy()
    end
    
    _currentHighlight = nil
    _currentTarget = nil
end

-- Update highlight based on detection result
-- Call this with the result from InteractionDetector.Detect()
function ObjectHighlighter.Update(detectionResult: any): ()
    if not _isInitialized then
        return
    end
    
    local hitObject = detectionResult and detectionResult.hitObject
    local isInteractable = detectionResult and detectionResult.isInteractable
    
    -- Check if we should highlight this object
    if hitObject and isInteractable then
        -- If it's a different object than current, update highlight
        if _currentTarget ~= hitObject then
            ObjectHighlighter.CreateHighlight(hitObject)
        end
    else
        -- Remove highlight if no valid interactable in range
        ObjectHighlighter.RemoveHighlight()
    end
end

-- Get the current highlighted target
function ObjectHighlighter.GetCurrentTarget(): any?
    return _currentTarget
end

-- Get the current highlight instance
function ObjectHighlighter.GetCurrentHighlight(): any?
    return _currentHighlight
end

-- Check if an object is currently highlighted
function ObjectHighlighter.IsHighlighted(targetObject: any): boolean
    return _currentTarget == targetObject and _currentTarget ~= nil
end

-- Initialize the highlighter
function ObjectHighlighter.Initialize(): ()
    _isInitialized = true
end

-- Check if initialized
function ObjectHighlighter.IsInitialized(): boolean
    return _isInitialized
end

-- Cleanup all highlights and reset state
function ObjectHighlighter.Cleanup(): ()
    ObjectHighlighter.RemoveHighlight()
    _isInitialized = false
end

-- Get the fill color constant
function ObjectHighlighter.GetFillColor(): any
    return HIGHLIGHT_FILL_COLOR
end

-- Get the outline color constant
function ObjectHighlighter.GetOutlineColor(): any
    return HIGHLIGHT_OUTLINE_COLOR
end

-- Private variable for mock instance creator
local _mockInstanceCreator: any? = nil

-- For testing: Set highlight directly
function ObjectHighlighter.SetMockHighlight(highlight: any): ()
    _currentHighlight = highlight
end

-- For testing: Set target directly
function ObjectHighlighter.SetMockTarget(target: any): ()
    _currentTarget = target
end

-- For testing: Mock instance creator
function ObjectHighlighter.SetMockInstanceCreator(mockCreator: any): ()
    -- Store for testing - this would replace Instance.new behavior
    _mockInstanceCreator = mockCreator
end

return ObjectHighlighter
