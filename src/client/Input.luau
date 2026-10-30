-- PC controls from GDD v2 section 4 ("7 keys, 9 actions"), plus prototype keys.
--   Left click tap / hold   basic attack / heavy attack
--   Right click hold        block (the first 200 ms is a parry)
--   Space                   dodge roll
--   Q, E, R                 skills
--   T                       signature key (Warden Intercept)
--   F                       ultimate (not built yet)
--   1, 2, 3                 switch class out of combat [Proto]
--   Left Alt                free the mouse for the UI [Proto]
-- The camera works like shift lock: the mouse is locked to the centre and your character faces the camera,
-- so attacks go where you look.

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
local mouseFree = false
local lmbDownAt: number? = nil
local heavySent = false

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

function Input.start()
	actionRemote = ReplicatedStorage:WaitForChild(Net.FOLDER):WaitForChild(Net.ACTION) :: RemoteEvent

	bind("OathAttack", function(state)
		if mouseFree then
			return
		end
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

	bind("OathBlock", function(state)
		if state == Enum.UserInputState.Begin then
			send(R.BLOCK_START)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			send(R.BLOCK_END)
		end
	end, Enum.UserInputType.MouseButton2)

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

	local classKeys = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
	ContextActionService:BindActionAtPriority("OathClass", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			send(R.CLASS, { class = Kits.ORDER[classKeys[input.KeyCode]] })
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three)

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt then
			mouseFree = not mouseFree
		end
	end)

	-- Runs right after the default camera so our mouse lock is not overwritten.
	RunService:BindToRenderStep("OathCamera", Enum.RenderPriority.Camera.Value + 1, function()
		-- Hold left click long enough and it becomes a heavy attack, sent once.
		if lmbDownAt and not heavySent and os.clock() - lmbDownAt >= HEAVY_HOLD then
			heavySent = true
			send(R.HEAVY)
		end

		-- Shift-lock style camera.
		UserInputService.MouseBehavior = mouseFree and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
		local root, humanoid = rootAndHumanoid()
		local camera = workspace.CurrentCamera
		if player:GetAttribute("UiOpen") then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		elseif root and humanoid and camera and humanoid.Health > 0 then
			humanoid.AutoRotate = mouseFree
			humanoid.CameraOffset = mouseFree and Vector3.zero or Vector3.new(1.75, 0, 0)
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
