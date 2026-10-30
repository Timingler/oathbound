-- Climbing and gliding. Both drain the shared stamina pool on the server (CombatService, Constants.EXERTION_DRAIN);
-- when it runs out the server ends them and the snapshot tells this module, which lets go of the wall or folds
-- the cloak. While either is on, the player's "Traversal" attribute is set and attacks are not sent (client/Input).
--
-- Climb (our own R6 climb; the library's climb is R15 only): jump into a wall taller than you, or keep walking into
-- it for a moment, to grab it. W and S climb up and down, A and D move along it, Space leaps off. Reaching the top
-- mantles you onto it. Roblox's own R6 climb animation plays.
-- Glide (after the Glider System kit, BestRobloxLib, but with the character's cloak instead of a hang-glider):
-- press Space again while falling to spread your cloak and glide where the camera faces; Space again or landing
-- folds it.
-- Jumping costs stamina (Constants.JUMP_COST): without enough, Roblox's jump is turned off until it comes back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Constants = require(Shared.Constants)
local AssetIds = require(Shared.AssetIds)

local R = Net.Request
local ATTRIBUTE = "Traversal"
local SERVER_GRACE = 0.4 -- seconds to trust a local start before the server's snapshot has caught up

-- Climb [Proto]
local GRAB_AFTER = 0.3 -- seconds of walking into a wall before you grab it
local WALL_REACH = 2.6 -- studs from the root to a wall you can grab
local WALL_GAP = 1.15 -- studs the root keeps from the wall while climbing
local MIN_WALL = 7 -- a wall must reach this far above your feet to be climbable
local MAX_WALL_NORMAL_Y = 0.35 -- steeper than this is a floor or a slope, not a wall
local SIDE_SPEED = 0.75 -- of the climb speed
local MANTLE_TIME = 0.35 -- seconds
local LEAP_AWAY = 28 -- studs per second off the wall when you leap
local LEAP_UP = 38

-- Glide [Proto]
local GLIDE_TURN = 2.5 -- how quickly the glide turns toward the camera (per second)
local SAIL_COLOR = Color3.fromRGB(86, 66, 52)

local Traversal = {}

local player = Players.LocalPlayer
local actionRemote: RemoteEvent
local mode: string? = nil -- "climb" | "glide"
local startedAt = 0
local pushingSince: number? = nil

-- Physics movers on the root, made per character.
local rig: {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	velocity: LinearVelocity,
	align: AlignOrientation,
	climbTrack: AnimationTrack,
	glideTrack: AnimationTrack,
}? = nil

local climb = { normal = Vector3.zAxis, mantling = false }
local glide = { dir = Vector3.zAxis, sail = nil :: Model? }

local function rayParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	return params
end

-- A climbable wall in front of `root`: anchored, steep, and tall enough. Returns the hit or nil.
local function wallAhead(root: BasePart, forward: Vector3, params: RaycastParams): RaycastResult?
	local hit = workspace:Raycast(root.Position, forward * WALL_REACH, params)
	if not hit or not hit.Instance.Anchored or math.abs(hit.Normal.Y) > MAX_WALL_NORMAL_Y then
		return nil
	end
	return hit
end

local function wallTallEnough(root: BasePart, normal: Vector3, params: RaycastParams): boolean
	local feet = root.Position - Vector3.new(0, 3, 0)
	local high = workspace:Raycast(feet + Vector3.new(0, MIN_WALL, 0), -normal * (WALL_REACH + 0.5), params)
	return high ~= nil
end

local function setMode(new: string?)
	if mode == new then
		return
	end
	if mode then
		actionRemote:FireServer({ kind = R.EXERT_END })
	end
	mode = new
	player:SetAttribute(ATTRIBUTE, new)
	if new then
		startedAt = os.clock()
		actionRemote:FireServer({ kind = R.EXERT_START, mode = new })
	end
end

local function release()
	if not rig then
		return
	end
	rig.velocity.Enabled = false
	rig.align.Enabled = false
	rig.humanoid.AutoRotate = true
	rig.humanoid.PlatformStand = false
	rig.climbTrack:Stop(Constants.ANIM_FADE)
	rig.glideTrack:Stop(Constants.ANIM_FADE)
	if glide.sail then
		glide.sail:Destroy()
		glide.sail = nil
	end
end

local function stop()
	release()
	setMode(nil)
end

----------------------------------------------------------------------------------------------------
-- Climb

local function startClimb(hit: RaycastResult)
	if not rig then
		return
	end
	setMode("climb")
	climb.normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
	climb.mantling = false
	rig.humanoid.PlatformStand = true
	rig.humanoid.AutoRotate = false
	rig.align.CFrame = CFrame.lookAt(Vector3.zero, -climb.normal)
	rig.align.Enabled = true
	rig.velocity.VectorVelocity = Vector3.zero
	rig.velocity.Enabled = true
	rig.climbTrack:Play(Constants.ANIM_FADE)
end

-- Over the top: lift and step onto the ledge, then stand.
local function mantle(top: Vector3)
	if not rig then
		return
	end
	climb.mantling = true
	rig.climbTrack:AdjustSpeed(2) -- a quick pull over the edge
	local root = rig.root
	local from = root.CFrame
	local goal = CFrame.lookAt(top + Vector3.new(0, 3.1, 0), top + Vector3.new(0, 3.1, 0) - climb.normal)
	rig.velocity.Enabled = false
	root.Anchored = true
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - t0) / MANTLE_TIME, 0, 1)
		-- Up first, then over: an arc instead of a slide through the edge.
		local up = from.Position:Lerp(Vector3.new(from.X, goal.Y, from.Z), math.min(1, a * 1.6))
		local pos = up:Lerp(goal.Position, math.max(0, a * 1.6 - 0.6))
		root.CFrame = CFrame.lookAt(pos, pos - climb.normal)
		if a >= 1 then
			conn:Disconnect()
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
			stop()
			if rig then
				rig.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
	end)
end

local function stepClimb(params: RaycastParams)
	if not rig or climb.mantling then
		return
	end
	local root = rig.root
	local humanoid = rig.humanoid
	local normal = climb.normal
	local chest = workspace:Raycast(root.Position, -normal * (WALL_REACH + 1), params)
	if not chest then
		-- The wall ended at chest height: is there a ledge to stand on?
		local probe = root.Position + Vector3.new(0, 4, 0) - normal * 1.8
		local floor = workspace:Raycast(probe, Vector3.new(0, -6, 0), params)
		if floor and floor.Normal.Y > 0.7 then
			mantle(floor.Position)
		else
			stop()
		end
		return
	end
	normal = Vector3.new(chest.Normal.X, 0, chest.Normal.Z)
	if normal.Magnitude < 0.5 then
		stop()
		return
	end
	normal = normal.Unit
	climb.normal = normal
	local head = workspace:Raycast(root.Position + Vector3.new(0, 2.2, 0), -normal * (WALL_REACH + 1), params)
	if not head then
		local probe = root.Position + Vector3.new(0, 4.5, 0) - normal * 1.8
		local floor = workspace:Raycast(probe, Vector3.new(0, -6, 0), params)
		if floor and floor.Normal.Y > 0.7 then
			mantle(floor.Position)
			return
		end
	end

	-- Move: into the wall is up, away is down, sideways is along it.
	local move = humanoid.MoveDirection
	local right = (-normal):Cross(Vector3.yAxis)
	local upInput = move:Dot(-normal)
	local sideInput = move:Dot(right)
	local up = if math.abs(upInput) > 0.3 then math.sign(upInput) else 0
	local side = if math.abs(sideInput) > 0.3 then math.sign(sideInput) else 0
	local snap = -normal * ((chest.Distance - WALL_GAP) * 10)
	rig.velocity.VectorVelocity = Vector3.yAxis * up * Constants.CLIMB_SPEED
		+ right * side * Constants.CLIMB_SPEED * SIDE_SPEED
		+ snap
	rig.align.CFrame = CFrame.lookAt(Vector3.zero, -normal)
	local moving = up ~= 0 or side ~= 0
	rig.climbTrack:AdjustSpeed(if moving then 1 else 0)

	-- Climbing down onto the ground lets go.
	if up < 0 and workspace:Raycast(root.Position, Vector3.new(0, -3.3, 0), params) then
		stop()
	end
end

----------------------------------------------------------------------------------------------------
-- Glide

local function makeSail(character: Model): Model?
	local torso = character:FindFirstChild("Torso") :: BasePart?
	if not torso then
		return nil
	end
	-- The cloak spread from the shoulders like two wings, held out by the arms, sagging toward the back.
	local sail = Instance.new("Model")
	sail.Name = "OathSailcloth"
	for _, side in { -1, 1 } do
		local panel = Instance.new("Part")
		panel.Name = "Wing"
		panel.Material = Enum.Material.Fabric
		panel.Color = SAIL_COLOR
		panel.Size = Vector3.new(2.6, 0.05, 3.2)
		panel.CanCollide = false
		panel.CanQuery = false
		panel.CanTouch = false
		panel.Massless = true
		local offset = CFrame.new(side * 1.25, 0.95, 1.2)
			* CFrame.Angles(math.rad(-20), 0, math.rad(side * -14))
		panel.CFrame = torso.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = panel
		weld.C0 = offset
		weld.Parent = panel
		panel.Parent = sail
	end
	sail.Parent = character
	return sail
end

local function startGlide()
	if not rig then
		return
	end
	setMode("glide")
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	glide.dir = if flat.Magnitude > 0.01 then flat.Unit else rig.root.CFrame.LookVector
	rig.humanoid.AutoRotate = false
	rig.align.CFrame = CFrame.lookAt(Vector3.zero, glide.dir)
	rig.align.Enabled = true
	rig.velocity.Enabled = true
	rig.glideTrack:Play(Constants.ANIM_FADE)
	glide.sail = makeSail(rig.character)
end

local function stepGlide(dt: number)
	if not rig then
		return
	end
	local state = rig.humanoid:GetState()
	if state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running then
		stop()
		return
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		glide.dir = glide.dir:Lerp(flat.Unit, math.min(1, GLIDE_TURN * dt)).Unit
	end
	rig.velocity.VectorVelocity = glide.dir * Constants.GLIDE_SPEED - Vector3.new(0, Constants.GLIDE_SINK, 0)
	-- Lean into the glide a little.
	rig.align.CFrame = CFrame.lookAt(Vector3.zero, glide.dir) * CFrame.Angles(math.rad(-12), 0, 0)
end

----------------------------------------------------------------------------------------------------

local function setup(character: Model)
	stop()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local attachment = Instance.new("Attachment")
	attachment.Name = "OathTraversal"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = 1e6
	velocity.Enabled = false
	velocity.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = 1e6
	align.Responsiveness = 25
	align.Enabled = false
	align.Parent = root
	local function load(id: number, priority: Enum.AnimationPriority): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = AssetIds.uri(id)
		local track = animator:LoadAnimation(animation)
		track.Priority = priority
		track.Looped = true
		return track
	end
	rig = {
		character = character,
		humanoid = humanoid,
		root = root,
		velocity = velocity,
		align = align,
		-- Above everything else (the weapon and tool holds, swings): the whole body climbs or glides.
		climbTrack = load(AssetIds.Traversal.Climb, Enum.AnimationPriority.Action4),
		glideTrack = load(AssetIds.Traversal.Glide, Enum.AnimationPriority.Action4),
	}
	humanoid.Died:Once(stop)
	-- Each jump costs stamina on the server.
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping and actionRemote then
			actionRemote:FireServer({ kind = R.JUMP })
		end
	end)
end

function Traversal.isActive(): boolean
	return mode ~= nil
end

-- From the server's snapshot: it ended the climb or glide (out of stamina).
-- Also turns Roblox's jump off while you lack the stamina for it.
function Traversal.onState(snap)
	local me = snap and snap.self
	if not me then
		return
	end
	if mode and me.exertion ~= mode and os.clock() - startedAt > SERVER_GRACE and not climb.mantling then
		stop()
	end
	if rig then
		rig.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, me.stamina >= Constants.JUMP_COST and not me.dead)
	end
end

-- Space on the wall: let go and spring away from it.
local function leapOff()
	if not rig then
		return
	end
	local normal = climb.normal
	stop()
	rig.root.AssemblyLinearVelocity = normal * LEAP_AWAY + Vector3.new(0, LEAP_UP, 0)
	actionRemote:FireServer({ kind = R.JUMP })
end

function Traversal.start()
	actionRemote = ReplicatedStorage:WaitForChild(Net.FOLDER):WaitForChild(Net.ACTION) :: RemoteEvent
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not rig or player:GetAttribute("UiOpen") then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.Space then
			return
		end
		if mode == "climb" and not climb.mantling then
			leapOff()
		elseif mode == "glide" then
			stop()
		elseif not mode and rig.humanoid:GetState() == Enum.HumanoidStateType.Freefall then
			startGlide() -- a second Space in the air
		end
	end)
	player:GetAttributeChangedSignal("UiOpen"):Connect(function()
		if player:GetAttribute("UiOpen") and mode == "glide" then
			stop()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local r = rig
		if not r or not r.character.Parent or r.humanoid.Health <= 0 then
			return
		end
		local params = rayParams(r.character)
		if mode == "climb" then
			stepClimb(params)
		elseif mode == "glide" then
			stepGlide(dt)
		elseif not player:GetAttribute("UiOpen") then
			-- Jumping into a tall wall grabs it at once; walking into one grabs it after a moment.
			local move = r.humanoid.MoveDirection
			local hit = move.Magnitude > 0.5 and wallAhead(r.root, Vector3.new(move.X, 0, move.Z).Unit, params)
			if hit and move:Dot(-hit.Normal) > 0.7 and wallTallEnough(r.root, hit.Normal, params) then
				pushingSince = pushingSince or os.clock()
				local airborne = r.humanoid:GetState() == Enum.HumanoidStateType.Jumping
					or r.humanoid:GetState() == Enum.HumanoidStateType.Freefall
				if airborne or os.clock() - pushingSince >= GRAB_AFTER then
					pushingSince = nil
					startClimb(hit)
				end
			else
				pushingSince = nil
			end
		end
	end)
end

return Traversal
