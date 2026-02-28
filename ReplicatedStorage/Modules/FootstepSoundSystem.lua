--!strict
--[[
    FootstepSoundSystem Module
    Manages footstep sounds for the player character.
    Handles sound playback, alternation between left/right feet, cooldown, and pitch adjustment based on movement state.
]]

-- Constants
local FOOTSTEP_COOLDOWN: number = 0.35 -- seconds between footsteps
local WALK_PITCH: number = 1.0 -- Normal pitch for walking
local SPRINT_PITCH: number = 1.1 -- Higher pitch (1.1x) for sprinting
local MOVE_THRESHOLD: number = 0.1 -- Humanoid.Running speed threshold to trigger footsteps

-- Module table
local FootstepSoundSystem = {}

-- Private state
local _isInitialized: boolean = false
local _lastFootstepTime: number = -1000 -- Start negative to allow immediate first step
local _isLeftFoot: boolean = true -- Track which foot to play next

-- Sound instances
local _leftFootSound: any? = nil
local _rightFootSound: any? = nil

-- Parent for sounds (character's HumanoidRootPart or Torso)
local _soundParent: any? = nil

-- Current movement state
local _isSprinting: boolean = false
local _currentWalkSpeed: number = 0
local _lastMovementState: boolean = false

-- Sound IDs (using empty strings as placeholders, will be configured later)
local FOOTSTEP_SOUND_ID: string = "rbxassetid://0" -- Placeholder sound ID

-- Mock instances for testing
local MockSound: any = nil

-- Initialize MockSound
MockSound = {
    new = function(name: string)
        local sound = {
            Name = name,
            SoundId = "",
            Volume = 0.5,
            PlaybackSpeed = 1.0,
            IsPlaying = false,
            _playCount = 0,
            _lastPlayTime = 0,
            Parent = nil,
            
            Play = function(self: any)
                self.IsPlaying = true
                self._playCount += 1
                self._lastPlayTime = tick()
            end,
            
            Stop = function(self: any)
                self.IsPlaying = false
            end,
            
            GetPlayCount = function(self: any): number
                return self._playCount
            end,
            
            GetLastPlayTime = function(self: any): number
                return self._lastPlayTime
            end,
            
            Reset = function(self: any)
                self._playCount = 0
                self._lastPlayTime = 0
                self.IsPlaying = false
            end,
        }
        return sound
    end
}

-- Current time function
local function GetCurrentTime(): number
    return tick and tick() or os.clock()
end

-- Check if cooldown has elapsed
local function IsCooldownElapsed(): boolean
    local currentTime = GetCurrentTime()
    local timeSinceLastFootstep = currentTime - _lastFootstepTime
    return timeSinceLastFootstep >= FOOTSTEP_COOLDOWN
end

-- Calculate pitch based on movement state
local function CalculatePitch(): number
    if _isSprinting then
        return SPRINT_PITCH
    else
        return WALK_PITCH
    end
end

-- Play footstep sound
local function PlayFootstep(): ()
    if not _isInitialized then
        return
    end

    if not IsCooldownElapsed() then
        return
    end

    local soundToPlay: any? = nil
    
    if _isLeftFoot then
        soundToPlay = _leftFootSound
    else
        soundToPlay = _rightFootSound
    end

    if not soundToPlay then
        return
    end

    -- Set pitch based on sprint state
    soundToPlay.PlaybackSpeed = CalculatePitch()

    -- Play the sound
    soundToPlay:Play()

    -- Update state
    _lastFootstepTime = GetCurrentTime()
    _isLeftFoot = not _isLeftFoot -- Alternate feet
end

-- Check if player is moving based on speed
local function IsMoving(speed: number): boolean
    return speed > MOVE_THRESHOLD
end

-- Declare global Instance for Roblox environment
local Instance: any = nil

-- Create a Sound instance (works in both Roblox and test environments)
local function CreateSound(name: string, parent: any?): any
    local sound: any = nil
    
    -- Try to get Instance if available (Roblox environment)
    local success = pcall(function()
        Instance = _G.Instance or (game :: any).Instance
    end)
    
    if success and Instance then
        sound = Instance.new("Sound")
        sound.Name = name
        sound.SoundId = FOOTSTEP_SOUND_ID
        sound.Volume = 0.5
        sound.PlaybackSpeed = 1.0
        if parent then
            sound.Parent = parent
        end
    else
        -- Use mock for testing
        sound = MockSound.new(name)
        if parent then
            sound.Parent = parent
        end
    end
    
    return sound
end

-- Initialize the footstep system
function FootstepSoundSystem.Initialize(parent: any?): ()
    if _isInitialized then
        return
    end

    _soundParent = parent

    -- Create left foot sound
    _leftFootSound = CreateSound("LeftFootstep", _soundParent)

    -- Create right foot sound
    _rightFootSound = CreateSound("RightFootstep", _soundParent)

    -- Reset state
    _lastFootstepTime = -1000
    _isLeftFoot = true
    _isSprinting = false
    _currentWalkSpeed = 0
    _lastMovementState = false

    _isInitialized = true
end

-- Update the footstep system (called each frame or on Running event)
-- speed: the current movement speed (Humanoid.Running provides this)
-- isSprinting: whether the player is currently sprinting
function FootstepSoundSystem.Update(speed: number, isSprinting: boolean?): ()
    if not _isInitialized then
        return
    end

    _isSprinting = isSprinting or false
    _currentWalkSpeed = speed

    local isCurrentlyMoving = IsMoving(speed)

    if isCurrentlyMoving then
        -- Player is moving, try to play footstep
        PlayFootstep()
    else
        -- Player stopped moving - footstep system stops naturally
        -- (sounds naturally stop when cooldown prevents new plays)
    end

    _lastMovementState = isCurrentlyMoving
end

-- Handle Humanoid.Running event
function FootstepSoundSystem.OnRunning(speed: number): ()
    FootstepSoundSystem.Update(speed, _isSprinting)
end

-- Check if the system is initialized
function FootstepSoundSystem.IsInitialized(): boolean
    return _isInitialized
end

-- Get the last footstep time
function FootstepSoundSystem.GetLastFootstepTime(): number
    return _lastFootstepTime
end

-- Get the cooldown duration
function FootstepSoundSystem.GetCooldown(): number
    return FOOTSTEP_COOLDOWN
end

-- Get current pitch based on movement state
function FootstepSoundSystem.GetCurrentPitch(): number
    return CalculatePitch()

end

-- Check if currently on cooldown
function FootstepSoundSystem.IsOnCooldown(): boolean
    return not IsCooldownElapsed()
end

-- Get which foot is next (for testing/display)
function FootstepSoundSystem.GetNextFoot(): string
    return _isLeftFoot and "Left" or "Right"
end

-- Get the left foot sound instance
function FootstepSoundSystem.GetLeftFootSound(): any?
    return _leftFootSound
end

-- Get the right foot sound instance
function FootstepSoundSystem.GetRightFootSound(): any?
    return _rightFootSound
end

-- Get play counts for testing
function FootstepSoundSystem.GetLeftFootPlayCount(): number
    if _leftFootSound and _leftFootSound.GetPlayCount then
        return _leftFootSound:GetPlayCount()
    end
    return 0
end

function FootstepSoundSystem.GetRightFootPlayCount(): number
    if _rightFootSound and _rightFootSound.GetPlayCount then
        return _rightFootSound:GetPlayCount()
    end
    return 0
end

function FootstepSoundSystem.GetTotalPlayCount(): number
    return FootstepSoundSystem.GetLeftFootPlayCount() + FootstepSoundSystem.GetRightFootPlayCount()
end

-- Get movement threshold
function FootstepSoundSystem.GetMoveThreshold(): number
    return MOVE_THRESHOLD
end

-- Get walk pitch
function FootstepSoundSystem.GetWalkPitch(): number
    return WALK_PITCH
end

-- Get sprint pitch
function FootstepSoundSystem.GetSprintPitch(): number
    return SPRINT_PITCH
end

-- Set sprint state directly (for testing)
function FootstepSoundSystem.SetSprinting(isSprinting: boolean): ()
    _isSprinting = isSprinting
end

-- Cleanup the footstep system
function FootstepSoundSystem.Cleanup(): ()
    -- Destroy sound instances if they exist
    if _leftFootSound then
        local success = pcall(function()
            if _leftFootSound.Destroy then
                _leftFootSound:Destroy()
            end
        end)
        if not success and _leftFootSound.Reset then
            _leftFootSound:Reset()
        end
        _leftFootSound = nil
    end

    if _rightFootSound then
        local success = pcall(function()
            if _rightFootSound.Destroy then
                _rightFootSound:Destroy()
            end
        end)
        if not success and _rightFootSound.Reset then
            _rightFootSound:Reset()
        end
        _rightFootSound = nil
    end

    -- Reset state
    _isInitialized = false
    _lastFootstepTime = -1000
    _isLeftFoot = true
    _isSprinting = false
    _currentWalkSpeed = 0
    _lastMovementState = false
    _soundParent = nil
end

-- For testing: Reset play counts
function FootstepSoundSystem.ResetPlayCounts(): ()
    if _leftFootSound and _leftFootSound.Reset then
        _leftFootSound:Reset()
    end
    if _rightFootSound and _rightFootSound.Reset then
        _rightFootSound:Reset()
    end
end

-- For testing: Set last footstep time directly
function FootstepSoundSystem.SetLastFootstepTime(time: number): ()
    _lastFootstepTime = time
end

-- For testing: Set which foot is next
function FootstepSoundSystem.SetNextFootIsLeft(isLeft: boolean): ()
    _isLeftFoot = isLeft
end

-- For testing: Get current walk speed
function FootstepSoundSystem.GetCurrentWalkSpeed(): number
    return _currentWalkSpeed
end

-- For testing: Get current sprint state
function FootstepSoundSystem.IsSprinting(): boolean
    return _isSprinting
end

return FootstepSoundSystem
