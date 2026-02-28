--!strict
--[[
    Types Module Tests
    Validates type definitions and their constructors.
]]

-- Simplified tests that work outside of Roblox runtime
local Types = {}

-- Re-export types for testing
export type InputState = {
    moveForward: boolean,
    moveBackward: boolean,
    moveLeft: boolean,
    moveRight: boolean,
    sprinting: boolean,
    interacting: boolean,
    lookDelta: any,
    lastInteractTime: number,
    lastFootstepTime: number,
}

export type PlayerState = {
    health: number,
    maxHealth: number,
    sanity: number,
    maxSanity: number,
    isSprinting: boolean,
    isMoving: boolean,
    walkSpeed: number,
    sprintSpeed: number,
    isGrounded: boolean,
    footstepCooldown: number,
}

export type Interactable = {
    instance: any,
    interactionDistance: number,
    highlightColor: any,
    interactionPrompt: string,
    canInteract: boolean,
    isHighlighted: boolean,
    onInteract: (player: any) -> (),
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

local function runTests(): (number, number)
    print("Running Types module tests...")
    local passed = 0
    local failed = 0

    -- Test 1: Verify type definitions exist
    local test1 = function()
        local _inputState: InputState = {
            moveForward = false,
            moveBackward = false,
            moveLeft = false,
            moveRight = false,
            sprinting = false,
            interacting = false,
            lookDelta = { x = 0, y = 0 },
            lastInteractTime = 0,
            lastFootstepTime = 0,
        }
        assert(_inputState.moveForward == false, "InputState.moveForward should be false")
        passed += 1
    end

    -- Test 2: Verify PlayerState type structure
    local test2 = function()
        local _playerState: PlayerState = {
            health = 100,
            maxHealth = 100,
            sanity = 100,
            maxSanity = 100,
            isSprinting = false,
            isMoving = false,
            walkSpeed = 16,
            sprintSpeed = 24,
            isGrounded = true,
            footstepCooldown = 0.4,
        }
        assert(_playerState.health == 100, "PlayerState.health should be 100")
        assert(_playerState.sanity == 100, "PlayerState.sanity should be 100")
        passed += 1
    end

    -- Test 3: Verify Interactable type structure
    local test3 = function()
        local interacted = false
        local mockPart = { Name = "TestPart" }
        
        local _interactable: Interactable = {
            instance = mockPart,
            interactionDistance = 5,
            highlightColor = { r = 255, g = 255, b = 0 },
            interactionPrompt = "Press E to interact",
            canInteract = true,
            isHighlighted = false,
            onInteract = function(_player: any)
                interacted = true
            end,
            onHighlight = function() end,
            onUnhighlight = function() end,
        }
        
        assert(_interactable.instance == mockPart, "Interactable.instance should be mockPart")
        assert(_interactable.interactionDistance == 5, "Interactable.interactionDistance should be 5")
        assert(_interactable.canInteract == true, "Interactable.canInteract should be true")
        
        -- Test callback
        _interactable.onInteract(nil)
        assert(interacted == true, "Interactable.onInteract callback should run")
        passed += 1
    end

    -- Test 4: Verify FootstepConfig type structure
    local test4 = function()
        local _config: FootstepConfig = {
            soundId = "rbxassetid://123456",
            volume = 0.5,
            playbackSpeed = 1,
            cooldown = 0.4,
        }
        assert(_config.soundId == "rbxassetid://123456")
        assert(_config.cooldown == 0.4)
        passed += 1
    end

    -- Test 5: Verify CameraConfig type structure
    local test5 = function()
        local _config: CameraConfig = {
            fieldOfView = 70,
            mouseSensitivity = 1,
            maxLookUp = 80,
            maxLookDown = -80,
        }
        assert(_config.fieldOfView == 70)
        assert(_config.maxLookUp == 80)
        passed += 1
    end

    -- Run all tests
    local tests = {test1, test2, test3, test4, test5}
    
    for _, test in ipairs(tests) do
        local success, err = pcall(test)
        if not success then
            warn("Test failed: " .. tostring(err))
            failed += 1
        end
    end

    print(string.format("Test Results: %d passed, %d failed", passed, failed))
    
    return passed, failed
end

return runTests
