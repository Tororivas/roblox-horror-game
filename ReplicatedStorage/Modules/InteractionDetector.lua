--!strict
--[[
    InteractionDetector Module
    Raycast-based detection system for interactable objects.
    Casts a ray from the camera and returns hit information.
]]

-- Maximum interaction distance in studs
local MAX_INTERACTION_DISTANCE: number = 5

-- Return type for Detect function
export type DetectionResult = {
    hitObject: any?,         -- BasePart | Model that was hit
    hitPosition: any?,       -- Vector3 where the ray hit
    distance: number,        -- Distance in studs from camera
    isInteractable: boolean, -- Whether the object is interactable
}

-- Module table
local InteractionDetector = {}

-- Private state
local _isInitialized: boolean = false

-- Get Workspace or use mock
local Workspace: any
local CollectionService: any

-- Mock services for testing
local MockWorkspace: any = {
    CurrentCamera = nil,
    
    Raycast = function(_origin: any, _direction: any, _params: any): any?
        return nil -- No hit by default in test environment
    end,
}

local MockCollectionService: any = {
    HasTag = function(_self: any, _instance: any, _tag: string): boolean
        return false
    end,
}

-- Try to get real services
local success, result = pcall(function()
    return (game :: any):GetService("Workspace")
end)
if success then
    Workspace = result
end

success, result = pcall(function()
    return (game :: any):GetService("CollectionService")
end)
if success then
    CollectionService = result
end

-- Use mocks if services not available
Workspace = Workspace or MockWorkspace
CollectionService = CollectionService or MockCollectionService

-- Default raycast parameters
local _defaultRaycastParams: any = {
    FilterType = 0, -- Enum.RaycastFilterType.Blacklist
    FilterDescendantsInstances = {},
    IgnoreWater = true,
}

-- Get the current camera
local function GetCamera(): any?
    if Workspace and Workspace.CurrentCamera then
        return Workspace.CurrentCamera
    end
    return nil
end

-- Check if an object is tagged as Interactable
function InteractionDetector.HasInteractableTag(instance: any): boolean
    if CollectionService and CollectionService.HasTag then
        return CollectionService:HasTag(instance, "Interactable")
    end
    return false
end

-- Check if an object has Interactable attribute set to true
function InteractionDetector.HasInteractableAttribute(instance: any): boolean
    if instance and typeof(instance.GetAttribute) == "function" then
        local hasAttr = instance:GetAttribute("Interactable")
        return hasAttr == true
    end
    return false
end

-- Check if an object is interactable
function InteractionDetector.IsInteractable(instance: any): boolean
    if instance == nil then
        return false
    end
    
    return InteractionDetector.HasInteractableTag(instance) or 
           InteractionDetector.HasInteractableAttribute(instance)
end

-- Main detection function
-- Returns: DetectionResult with hitObject, hitPosition, distance, and isInteractable
function InteractionDetector.Detect(): DetectionResult
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
        -- Create raycast parameters (if supported)
        local raycastParams = _defaultRaycastParams
        
        -- Perform the raycast
        raycastResult = Workspace:Raycast(origin, direction, raycastParams)
    
    elseif Workspace and Workspace.FindPartOnRay then
        -- Fallback for older API
        local ray = {
            Origin = origin,
            Direction = direction,
        }
        raycastResult = Workspace:FindPartOnRay(ray, _defaultRaycastParams.FilterDescendantsInstances, true)
    end
    
    -- Process raycast result
    if raycastResult then
        -- Get hit object from result
        local hitInstance: any? = nil
        local hitPos: any? = nil
        local hitDistance: number = MAX_INTERACTION_DISTANCE
        
        if raycastResult.Instance then
            -- Modern RaycastResult format
            hitInstance = raycastResult.Instance
            hitPos = raycastResult.Position
            if raycastResult.Distance then
                hitDistance = raycastResult.Distance
            else
                -- Calculate distance manually
                local dx = hitPos.X - origin.X
                local dy = hitPos.Y - origin.Y
                local dz = hitPos.Z - origin.Z
                hitDistance = math.sqrt(dx * dx + dy * dy + dz * dz)
            end
        else
            -- Legacy format (FindPartOnRay returns part, position, normal, material)
            hitInstance = raycastResult
            if raycastResult.Position then
                hitPos = raycastResult.Position
            end
        end
        
        -- Check if instance is interactable
        local isInteractable = false
        if hitInstance then
            isInteractable = InteractionDetector.IsInteractable(hitInstance)
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
function InteractionDetector.SetMaxDistance(distance: number): ()
    MAX_INTERACTION_DISTANCE = distance
end

-- Get max distance
function InteractionDetector.GetMaxDistance(): number
    return MAX_INTERACTION_DISTANCE
end

-- Initialize the detector (for setup if needed)
function InteractionDetector.Initialize(): ()
    _isInitialized = true
end

-- Check if initialized
function InteractionDetector.IsInitialized(): boolean
    return _isInitialized
end

-- Cleanup
function InteractionDetector.Cleanup(): ()
    _isInitialized = false
end

-- For testing: Set mock Workspace
function InteractionDetector.SetMockWorkspace(mockWorkspace: any): ()
    Workspace = mockWorkspace
end

-- For testing: Set mock CollectionService
function InteractionDetector.SetMockCollectionService(mockService: any): ()
    CollectionService = mockService
end

-- For testing: Set camera directly
function InteractionDetector.SetMockCamera(mockCamera: any): ()
    if Workspace then
        Workspace.CurrentCamera = mockCamera
    end
end

return InteractionDetector
