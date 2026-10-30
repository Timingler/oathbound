-- Directional walk, run and idle from the Advanced R6 Run System kit. The camera works like shift lock, so the
-- character often strafes or backs up; this picks the forward, left, back or right cycle from the velocity
-- relative to where the character faces.
-- Plays at Movement priority over the default Animate script and steps aside while jumping, falling, climbing
-- or swimming, so Animate's own animations show then. R6 only: on an R15 rig it does nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared.AssetIds)

local FADE = 0.2 -- seconds [Proto]
local MOVING = 0.5 -- studs per second below which the character counts as standing still
local RUN_FROM = 20 -- studs per second; the prototype walks at 16 and has no sprint yet [Proto]
-- Speeds the kit's walk and run cycles were authored for, and its playback rate limits.
local WALK_ANIM_SPEED = 12
local RUN_ANIM_SPEED = 24
local MIN_RATE = 0.4
local MAX_RATE = 1.6

local OFF_GROUND = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

local Locomotion = {}

local warnedR15 = false

local function setup(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		if not warnedR15 then
			warnedR15 = true
			warn("[Locomotion] The movement animations are R6 only. Set Game Settings > Avatar to R6 to see them.")
		end
		return
	end
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	local tracks: { [string]: AnimationTrack } = {}
	for name, id in AssetIds.Move do
		local animation = Instance.new("Animation")
		animation.AnimationId = AssetIds.uri(id)
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Movement
		track.Looped = true
		tracks[name] = track
	end

	local current: string? = nil
	local function switch(name: string?, rate: number)
		if current ~= name then
			if current then
				tracks[current]:Stop(FADE)
			end
			current = name
			if name then
				tracks[name]:Play(FADE)
			end
		end
		if name then
			tracks[name]:AdjustSpeed(rate)
		end
	end

	local connection = RunService.RenderStepped:Connect(function()
		if OFF_GROUND[humanoid:GetState()] then
			switch(nil, 1)
			return
		end
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = flat.Magnitude
		if speed < MOVING then
			switch("Idle", 1)
			return
		end
		-- In object space, forward is -Z and right is +X.
		local localDir = root.CFrame:VectorToObjectSpace(flat)
		local dir
		if math.abs(localDir.Z) >= math.abs(localDir.X) then
			dir = if localDir.Z < 0 then "W" else "S"
		else
			dir = if localDir.X > 0 then "D" else "A"
		end
		local running = speed >= RUN_FROM
		local base = if running then RUN_ANIM_SPEED else WALK_ANIM_SPEED
		switch((if running then "Run " else "Walk ") .. dir, math.clamp(speed / base, MIN_RATE, MAX_RATE))
	end)

	humanoid.Died:Once(function()
		connection:Disconnect()
		switch(nil, 1)
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			connection:Disconnect()
		end
	end)
end

function Locomotion.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
end

return Locomotion
