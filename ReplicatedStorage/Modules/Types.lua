--!strict
--[[
    Types Module
    Shared type definitions for the Roblox Horror Game.
    All modules should reference types from here for consistency.
]]

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
    lookDelta: Vector2,
    
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
    instance: BasePart | Model,
    
    -- Configuration
    interactionDistance: number,
    highlightColor: Color3,
    interactionPrompt: string,
    
    -- State
    canInteract: boolean,
    isHighlighted: boolean,
    
    -- Callbacks
    onInteract: (player: Player) -> (),
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

return {}
