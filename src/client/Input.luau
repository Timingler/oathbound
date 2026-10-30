-- PC controls from GDD v2 section 4 ("7 keys, 9 actions"), plus prototype keys.
--   Left click tap / hold   basic attack / heavy attack
--   Right click hold        block (the first 200 ms is a parry)
--   Space                   dodge roll
--   Q, E, R                 skills
--   T                       signature key (Warden Intercept)
--   F                       ultimate (not built yet)
--   1, 2, 3, 4              switch class out of combat [Proto]
--   Left Shift or Left Ctrl toggle the camera lock [Proto]
-- Camera lock is a toggle, like GPO or Vesteria: off (the default) is the normal Roblox camera with a free mouse
-- and your character facing where it moves; on hides the cursor, shows a small crosshair and turns your character
-- with the camera, so attacks go where you look.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Kits = require(Shared.Kits)
local Constants = require(Shared.Constants)
local AssetIds = require(Shared.AssetIds)

local R = Net.Request
local HEAVY_HOLD = 0.25 -- seconds of holding left click before it counts as a heavy attack [Proto]
local DODGE_SPEED = 55 -- studs per second [Proto]
local DODGE_TIME = 0.3 -- seconds [Proto]
-- The roll animation is 1.17 s with its tumble at 0.73 s. Skipping the crouch and playing the rest at 1.6x puts the
-- tumble at 0.3 s, as the dodge movement ends. [Proto]
local ROLL_ANIM_START = 0.25
local ROLL_ANIM_RATE = 1.6

local Input = {}

local player = Players.LocalPlayer
local actionRemote: RemoteEvent
local mouseFree = true -- camera lock starts off
local LOCK_KEYS = { [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.LeftControl] = true }
local LOCK_OFFSET = Vector3.new(1.75, 0, 0) -- over-the-shoulder offset while locked
local cameraOffset = Vector3.zero
local crosshair: Frame? = nil
local lmbDownAt: number? = nil
local heavySent = false

-- Where you are aiming: under the crosshair while the camera is locked, under the mouse while it is free. Attacks
-- carry this point so arrows fly to it and the character turns to face it (server/Projectiles, CombatService).
local AIM_REACH = 300 -- studs [Proto]
local function aimPoint(): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray
	if mouseFree then
		local m = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(m.X, m.Y)
	else
		local size = camera.ViewportSize
		ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_REACH, params)
	return if result then result.Position else ray.Origin + ray.Direction * AIM_REACH
end

local AIMED = { [R.BASIC] = true, [R.HEAVY] = true, [R.SKILL] = true, [R.SIGNATURE] = true, [R.ULTIMATE] = true }

local function send(kind: string, extra: { [string]: any }?)
	if player:GetAttribute("UiOpen") then
		return -- a full-screen menu (the inventory) has the mouse
	end
	local req = { kind = kind }
	if extra then
		for k, v in extra do
			req[k] = v
		end
	end
	if AIMED[kind] then
		local point = aimPoint()
		if point then
			req.aim = point
			-- With the camera free the character faces where it walks; turn it to the target so the swing goes
			-- where you clicked. (Locked, it already faces the camera.)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if mouseFree and root then
				local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
				if flat.Magnitude > 0.5 then
					root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
				end
			end
		end
	end
	actionRemote:FireServer(req)
end

local function rootAndHumanoid(): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

-- Plays the roll locally right away so it feels instant. The server owns the invulnerability window.
local lastRoll = 0
local rollTrack: AnimationTrack? = nil
local rollAnimator: Animator? = nil
function Input.playDodge()
	local root, humanoid = rootAndHumanoid()
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	lastRoll = os.clock()
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit

	-- Played here rather than by the server so the roll starts on the key press. It replicates from the owner.
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator and humanoid.RigType == Enum.HumanoidRigType.R6 then
		if not rollTrack or rollAnimator ~= animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = AssetIds.uri(AssetIds.Combat.Common.roll.id)
			rollTrack = animator:LoadAnimation(animation)
			rollTrack.Priority = Enum.AnimationPriority.Action3
			rollAnimator = animator
		end
		rollTrack:Play(0.05)
		rollTrack.TimePosition = ROLL_ANIM_START
		rollTrack:AdjustSpeed(ROLL_ANIM_RATE)
	end

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = 1e6
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(dir.X, dir.Z) * DODGE_SPEED
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Parent = root
	task.delay(DODGE_TIME, function()
		velocity:Destroy()
		attachment:Destroy()
	end)
end

local function bind(name: string, fn: (Enum.UserInputState) -> (), ...)
	ContextActionService:BindActionAtPriority(name, function(_, state)
		fn(state)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, ...)
end

-- The Ranger's Disengage: the server grants it (and the invulnerability), then this client, which owns the
-- character's physics, makes the leap: back along `dir` and a little up.
local LEAP_TIME = 0.35 -- seconds [Proto]
local LEAP_LIFT = 14 -- studs per second upward [Proto]
function Input.leap(dir: Vector3, distance: number)
	local root, humanoid = rootAndHumanoid()
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = 1e6
	velocity.VectorVelocity = dir * (distance / LEAP_TIME) + Vector3.new(0, LEAP_LIFT, 0)
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Parent = root
	task.delay(LEAP_TIME, function()
		velocity:Destroy()
		attachment:Destroy()
		-- Land where the leap ends instead of sliding on with its speed.
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
	end)
end

function Input.start()
	actionRemote = ReplicatedStorage:WaitForChild(Net.FOLDER):WaitForChild(Net.ACTION) :: RemoteEvent
	local fxRemote = ReplicatedStorage:WaitForChild(Net.FOLDER):WaitForChild(Net.FX) :: RemoteEvent
	fxRemote.OnClientEvent:Connect(function(event)
		if event.t == "leap" and event.player == player.UserId then
			Input.leap(event.dir, event.distance)
		end
	end)

	bind("OathAttack", function(state)
		if state == Enum.UserInputState.Begin then
			lmbDownAt = os.clock()
			heavySent = false
		elseif state == Enum.UserInputState.End then
			if lmbDownAt and not heavySent then
				send(R.BASIC)
			end
			lmbDownAt = nil
		end
	end, Enum.UserInputType.MouseButton1)

	-- Passed on as well as handled: with the camera free, right-drag still turns the camera while you block.
	ContextActionService:BindActionAtPriority("OathBlock", function(_, state)
		if state == Enum.UserInputState.Begin then
			send(R.BLOCK_START)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			send(R.BLOCK_END)
		end
		return if mouseFree then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton2)

	-- Space is jump by default; sinking it here turns it into dodge.
	bind("OathDodge", function(state)
		if state == Enum.UserInputState.Begin and os.clock() - lastRoll >= Constants.DODGE_COOLDOWN then
			Input.playDodge()
			send(R.DODGE)
		end
	end, Enum.KeyCode.Space)

	local slots = { [Enum.KeyCode.Q] = 1, [Enum.KeyCode.E] = 2, [Enum.KeyCode.R] = 3 }
	ContextActionService:BindActionAtPriority("OathSkill", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			send(R.SKILL, { slot = slots[input.KeyCode] })
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R)

	bind("OathSignature", function(state)
		if state == Enum.UserInputState.Begin then
			send(R.SIGNATURE)
		end
	end, Enum.KeyCode.T)

	bind("OathUltimate", function(state)
		if state == Enum.UserInputState.Begin then
			send(R.ULTIMATE)
		end
	end, Enum.KeyCode.F)

	local classKeys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
	ContextActionService:BindActionAtPriority("OathClass", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			send(R.CLASS, { class = Kits.ORDER[classKeys[input.KeyCode]] })
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four)

	UserInputService.InputBegan:Connect(function(input, processed)
		if LOCK_KEYS[input.KeyCode] and not processed and not player:GetAttribute("UiOpen") then
			mouseFree = not mouseFree
		end
	end)

	-- Small crosshair at the screen centre while locked, in place of the cursor.
	local crossGui = Instance.new("ScreenGui")
	crossGui.Name = "OathCrosshair"
	crossGui.ResetOnSpawn = false
	crossGui.IgnoreGuiInset = true
	crossGui.Parent = player:WaitForChild("PlayerGui")
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.BackgroundColor3 = Color3.fromRGB(240, 232, 214)
	dot.BackgroundTransparency = 0.15
	dot.BorderSizePixel = 0
	dot.Visible = false
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(0, 0, 0)
	ring.Transparency = 0.5
	ring.Thickness = 1
	ring.Parent = dot
	dot.Parent = crossGui
	crosshair = dot

	-- Runs right after the default camera so our mouse lock is not overwritten.
	RunService:BindToRenderStep("OathCamera", Enum.RenderPriority.Camera.Value + 1, function()
		-- Hold left click long enough and it becomes a heavy attack, sent once.
		if lmbDownAt and not heavySent and os.clock() - lmbDownAt >= HEAVY_HOLD then
			heavySent = true
			send(R.HEAVY)
		end

		-- Camera lock (toggle). A menu that has the mouse (the inventory) overrides it.
		local uiOpen = player:GetAttribute("UiOpen")
		local locked = not mouseFree and not uiOpen
		UserInputService.MouseBehavior = locked and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = not locked
		if crosshair then
			crosshair.Visible = locked
		end
		local root, humanoid = rootAndHumanoid()
		local camera = workspace.CurrentCamera
		if not uiOpen and root and humanoid and camera and humanoid.Health > 0 then
			humanoid.AutoRotate = mouseFree
			-- Ease the shoulder offset in and out instead of snapping.
			cameraOffset = cameraOffset:Lerp(locked and LOCK_OFFSET or Vector3.zero, 0.25)
			humanoid.CameraOffset = cameraOffset
			if not mouseFree then
				local look = camera.CFrame.LookVector
				local flatLook = Vector3.new(look.X, 0, look.Z)
				if flatLook.Magnitude > 0.01 then
					root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
				end
			end
		end
	end)
end

return Input
