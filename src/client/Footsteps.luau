-- Footsteps: one step sound per stride for every walking character near the camera (players, NPCs and the boss),
-- instead of Roblox's looping run sound, which this mutes on player characters. Heavier rigs (the boss) step
-- slower and deeper, and shake the camera a little when close. Uses Roblox's built-in footstep sound.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Footsteps = {}

local SOUND = "rbxasset://sounds/action_footsteps_plastic.mp3"
local HEAR_RANGE = 80 -- studs from the camera [Proto]
local STRIDE = 3.6 -- studs per step at normal size [Proto]
local VOLUME = 0.35
local SCAN_EVERY = 0.5 -- seconds between looking for new characters

local GROUNDED = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
}

local tracked: { [Model]: { travelled: number, last: Vector3?, scale: number } } = {}
local onShake: ((number) -> ())? = nil

-- client/Effects' camera shake, for heavy steps.
function Footsteps.setShake(fn: (number) -> ())
	onShake = fn
end

local function step(root: BasePart, scale: number)
	local sound = Instance.new("Sound")
	sound.SoundId = SOUND
	sound.Volume = VOLUME * math.min(2.2, scale)
	sound.PlaybackSpeed = (0.9 + math.random() * 0.2) / math.sqrt(scale)
	sound.RollOffMaxDistance = HEAR_RANGE
	sound.Parent = root
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function muteDefault(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local running = root and root:WaitForChild("Running", 5)
	if running and running:IsA("Sound") then
		running.Volume = 0
	end
end

local function scan()
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") and not tracked[model] and model:FindFirstChildOfClass("Humanoid") then
			tracked[model] = { travelled = 0, last = nil, scale = model:GetScale() }
		end
	end
	for model in tracked do
		if not model.Parent then
			tracked[model] = nil
		end
	end
end

function Footsteps.start()
	local function onCharacter(character: Model)
		task.spawn(muteDefault, character)
	end
	for _, other in Players:GetPlayers() do
		other.CharacterAdded:Connect(onCharacter)
		if other.Character then
			onCharacter(other.Character)
		end
	end
	Players.PlayerAdded:Connect(function(other)
		other.CharacterAdded:Connect(onCharacter)
	end)

	local sinceScan = math.huge
	RunService.Heartbeat:Connect(function(dt)
		sinceScan += dt
		if sinceScan >= SCAN_EVERY then
			sinceScan = 0
			scan()
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		for model, info in tracked do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not humanoid or not root or humanoid.Health <= 0 then
				continue
			end
			local pos = root.Position
			local last = info.last
			info.last = pos
			if not last or not GROUNDED[humanoid:GetState()] or (pos - camera.CFrame.Position).Magnitude > HEAR_RANGE then
				info.travelled = 0
				continue
			end
			info.travelled += Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
			if info.travelled >= STRIDE * info.scale then
				info.travelled = 0
				step(root, info.scale)
				if info.scale > 1.5 and onShake and (pos - camera.CFrame.Position).Magnitude < 40 then
					onShake(0.25)
				end
			end
		end
	end)
end

return Footsteps
