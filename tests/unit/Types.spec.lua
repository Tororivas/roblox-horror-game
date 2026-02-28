--!strict
--[[
    Types Module Tests
    Validates type definitions and their constructors.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Types)

local function runTests()
    print("Running Types module tests...")
    local passed = 0
    local failed = 0

    -- Test 1: Verify module loads
    local test1 = function()
        assert(Types ~= nil, "Types module should load successfully")
        print("✓ Types module loads successfully")
        passed += 1
    end

    -- Test 2: Verify InputState type structure (via assignment check)
    local test2 = function()
        local inputState: Types.InputState = {
            moveForward = false,
            moveBackward = false,
            moveLeft = false,
            moveRight = false,
            sprinting = false,
            interacting = false,
            lookDelta = Vector2.zero,
            lastInteractTime = 0,
            lastFootstepTime = 0,
        }
        assert(inputState.moveForward == false, "InputState.moveForward should be false")
        assert(inputState.sprinting == false, "InputState.sprinting should be false")
        print("✓ InputState type structure is valid")
        passed += 1
    end

    -- Test 3: Verify PlayerState type structure
    local test3 = function()
        local playerState: Types.PlayerState = {
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
        assert(playerState.health == 100, "PlayerState.health should be 100")
        assert(playerState.sanity == 100, "PlayerState.sanity should be 100")
        print("✓ PlayerState type structure is valid")
        passed += 1
    end

    -- Test 4: Verify Interactable type structure
    local test4 = function()
        local mockPart = Instance.new("Part")
        local interacted = false
        
        local interactable: Types.Interactable = {
            instance = mockPart,
            interactionDistance = 5,
            highlightColor = Color3.fromRGB(255, 255, 0),
            interactionPrompt = "Press E to interact",
            canInteract = true,
            isHighlighted = false,
            onInteract = function(player: Player)
                interacted = true
            end,
            onHighlight = function() end,
            onUnhighlight = function() end,
        }
        
        assert(interactable.instance == mockPart, "Interactable.instance should be the mockPart")
        assert(interactable.interactionDistance == 5, "Interactable.interactionDistance should be 5")
        assert(interactable.canInteract == true, "Interactable.canInteract should be true")
        
        -- Test callback
        interactable.onInteract(nil :: any)
        assert(interacted == true, "Interactable.onInteract callback should run")
        
        mockPart:Destroy()
        print("✓ Interactable type structure is valid")
        passed += 1
    end

    -- Test 5: Verify FootstepConfig type structure
    local test5 = function()
        local config: Types.FootstepConfig = {
            soundId = "rbxassetid://123456",
            volume = 0.5,
            playbackSpeed = 1,
            cooldown = 0.4,
        }
        assert(config.soundId == "rbxassetid://123456", "FootstepConfig.soundId should be set correctly")
        assert(config.cooldown == 0.4, "FootstepConfig.cooldown should be 0.4")
        print("✓ FootstepConfig type structure is valid")
        passed += 1
    end

    -- Test 6: Verify CameraConfig type structure
    local test6 = function()
        local config: Types.CameraConfig = {
            fieldOfView = 70,
            mouseSensitivity = 1,
            maxLookUp = 80,
            maxLookDown = -80,
        }
        assert(config.fieldOfView == 70, "CameraConfig.fieldOfView should be 70")
        assert(config.maxLookUp == 80, "CameraConfig.maxLookUp should be 80")
        print("✓ CameraConfig type structure is valid")
        passed += 1
    end

    -- Run all tests
    local tests = {test1, test2, test3, test4, test5, test6}
    
    for _, test in ipairs(tests) do
        local success, err = pcall(test)
        if not success then
            warn("✗ Test failed: " .. tostring(err))
            failed += 1
        end
    end

    print(string.format("\nTest Results: %d passed, %d failed", passed, failed))
    
    if failed > 0 then
        error("Some tests failed!")
    end
    
    return passed, failed
end

return runTests
