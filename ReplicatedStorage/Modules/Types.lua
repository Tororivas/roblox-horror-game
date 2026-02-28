--!strict
--[[
    Types Module
    Shared type definitions for the Roblox Horror Game.
    All modules should reference types from here for consistency.
]]

-- Forward declare Roblox types for typechecking
local _Vector2: any = nil
local _Vector3: any = nil
local _Color3: any = nil
local _BasePart: any = nil
local _Model: any = nil
local _Player: any = nil

export type InputState = {
    -- Movement
    moveForward: boolean,
    moveBackward: boolean,
    moveLeft: boolean,
    moveRight: boolean,
    
    -- Actions
    sprinting: boolean,
    interacting: boolean,
    
    -- Camera
    lookDelta: any, -- Vector2 in Roblox
    
    -- Timestamps for cooldown tracking
    lastInteractTime: number,
    lastFootstepTime: number,
}

export type PlayerState = {
    -- Health/Sanity
    health: number,
    maxHealth: number,
    sanity: number,
    maxSanity: number,
    
    -- Movement state
    isSprinting: boolean,
    isMoving: boolean,
    walkSpeed: number,
    sprintSpeed: number,
    
    -- Ground detection
    isGrounded: boolean,
    
    -- Footstep tracking
    footstepCooldown: number,
}

export type Interactable = {
    -- Instance reference
    instance: any, -- BasePart | Model in Roblox
    
    -- Configuration
    interactionDistance: number,
    highlightColor: any, -- Color3 in Roblox
    interactionPrompt: string,
    
    -- State
    canInteract: boolean,
    isHighlighted: boolean,
    
    -- Callbacks
    onInteract: (player: any) -> (), -- Player in Roblox
    onHighlight: () -> (),
    onUnhighlight: () -> (),
}

export type FootstepConfig = {
    soundId: string,
    volume: number,
    playbackSpeed: number,
    cooldown: number,
}

export type CameraConfig = {
    fieldOfView: number,
    mouseSensitivity: number,
    maxLookUp: number,
    maxLookDown: number,
}

export type MovementConfig = {
    walkSpeed: number,
    sprintSpeed: number,
    footstepCooldown: number,
    footstepVolume: number,
}

export type MovementState = {
    velocity: any,           -- Vector3
    isMoving: boolean,
    isSprinting: boolean,
    moveDirection: any,    -- Vector3 (local space)
    worldDirection: any,   -- Vector3 (world space)
}

return {}
