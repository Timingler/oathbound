-- The prototype test boss, the Ashen Sentinel: a giant R6 knight with a great hammer, standing in its own ring far
-- from the spawn. Walk into the ring (Boss.AGGRO_RANGE) to start the fight. Its pattern combines encounters E4
-- (interrupts) and E6 (tank) from the Build System Review audit, section 5.3. Hit sizes are written against light
-- armor, as the GDD asks. Every attack is drawn on the floor first and fills up until it lands.
--
-- Phase 1
--   Cleave          white   3 swings, 7,000 each, on the top-threat target's cone      (block, parry or dodge)
--   Sundering Blow  orange  20,000 tank-buster in a long cone, every 18 s              (dodge or parry; block fails)
--   Ash Leap        red     jumps onto the farthest player: 9,000 in a circle there    (move out)
--   Ash Sweep       red     6,000 in a big circle around itself, every 15 s            (move out)
--   Doom Chant      cast    2 s, every 40 s; 40% of medium HP to everyone unless interrupted
-- Phase 2 (below 60% HP): it roars and catches fire, moves faster, chants every 30 s, and adds
--   Cinder Ring     red     8,000 in a ring around it; the middle is safe               (move in close)
--   Ember Lines     red     a cross of fire lines, then a second cross turned 45°      (stand between the lines)
--
-- It has hyper armor (server/Poise): hits never flinch it or stop its attacks. Only its Break meter does
-- (GDD section 4): parries and interrupts fill it; when full it is Broken for 3 s, its attack or cast is
-- cancelled, and the meter locks for 25 s.
--
-- Set the "DamageScale" attribute on the boss model while playing to make it easier for solo tests, and
-- "SetHealth" (a fraction, e.g. 0.55) to jump to that much HP, to try phase 2.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Scaling = require(Shared.Scaling)
local AssetIds = require(Shared.AssetIds)
local Animations = require(script.Parent.Animations)
local Weapons = require(script.Parent.Weapons)

local Boss = {}
Boss.__index = Boss

local MEDIUM_HP = Scaling.maxHealth("medium", 50, 65)

-- What each attack hits. `shape` is filled in by Boss:shapesFor when the telegraph starts.
Boss.ATTACKS = {
	cleave = { name = "Cleave", color = "white", written = 7000, shape = "cone", range = 15, degrees = 110 },
	buster = { name = "Sundering Blow", color = "orange", written = 20000, shape = "cone", range = 22, degrees = 50 },
	leap = { name = "Ash Leap", color = "red", written = 9000, shape = "leap", radius = 11 },
	sweep = { name = "Ash Sweep", color = "red", written = 6000, shape = "circle", radius = 18 },
	ring = { name = "Cinder Ring", color = "red", written = 8000, shape = "ring", inner = 8, outer = 30 },
	lines = { name = "Ember Lines", color = "red", written = 7000, shape = "lines", length = 64, width = 7 },
}

-- Moves: one or more telegraphed steps in a row. `anim` is the AssetIds.Combat.Boss clip; `turn` rotates a step's
-- lines. Listed in priority order: when several are due, the first goes and the rest wait their turn.
Boss.MOVES = {
	{ key = "buster", every = { 18, 16 }, first = 18, recovery = 1.2, steps = { { attack = "buster", anim = "buster", telegraph = 1.4 } } },
	{ key = "leap", every = { 22, 16 }, first = 10, recovery = 1.2, steps = { { attack = "leap", anim = "leap", telegraph = 1.6 } } },
	{ key = "ring", phase = 2, every = { 16, 16 }, first = 4, recovery = 1, steps = { { attack = "ring", anim = "slam", telegraph = 1.7 } } },
	{
		key = "lines",
		phase = 2,
		every = { 20, 20 },
		first = 12,
		recovery = 1,
		steps = { { attack = "lines", anim = "lines", telegraph = 1.3 }, { attack = "lines", anim = "slam", telegraph = 1.0, turn = 45 } },
	},
	{ key = "sweep", every = { 15, 15 }, first = 15, recovery = 1, steps = { { attack = "sweep", anim = "slam", telegraph = 1.6 } } },
	{
		key = "cleave",
		melee = true,
		every = { 2.5, 2 },
		first = 1.5,
		recovery = 0.8,
		steps = {
			{ attack = "cleave", anim = "cleave1", telegraph = 0.8 },
			{ attack = "cleave", anim = "cleave2", telegraph = 0.6 },
			{ attack = "cleave", anim = "cleave3", telegraph = 0.65 },
		},
	},
}
Boss.CAST = { name = "Doom Chant", duration = 2.0, every = { 40, 30 }, written = 0.40 * MEDIUM_HP }

-- [Proto] values below are not in the design docs.
Boss.MAX_HEALTH = 600000 -- dungeon boss time to kill 2 to 4 min [A] at about 4 x WD per damage dealer
Boss.PHASE2_AT = 0.6 -- of max HP
Boss.ROAR_TIME = 2.5 -- seconds it stands roaring when phase 2 starts
Boss.SCALE = 2.4 -- times a normal R6 character
Boss.BREAK_MAX = 100
Boss.BREAK_PARRY = 15
Boss.BREAK_INTERRUPT = 30
Boss.WALK_SPEED = { 15, 19 } -- studs per second, per phase
Boss.MELEE_REACH = 9 -- stops this far from its target's centre
Boss.AGGRO_RANGE = 35
Boss.LEASH_RANGE = 90
Boss.LEAP_MAX = 60 -- studs; farther players are jumped toward, not onto
Boss.LEAP_AIR = 0.8 -- seconds in the air, at the end of the telegraph
Boss.RESET_AFTER = 8 -- seconds with nobody in range
Boss.ENRAGE_AT = 600 -- seconds (10 min enrage [A])
Boss.ENRAGE_MULT = 2
Boss.RESPAWN = 15

local COLORS = {
	white = Color3.fromRGB(235, 235, 235),
	orange = Color3.fromRGB(255, 140, 30),
	red = Color3.fromRGB(230, 40, 40),
}
local RING_SEGMENTS = 36
local WALK_ANIM_SPEED = 14.5 -- studs per second the walk cycle is authored for at normal size (client/Locomotion)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

----------------------------------------------------------------------------------------------------
-- The model

-- The Nightwatch Coat outfit from Items, darkened to ash and soot.
local SHIRT = "rbxassetid://9963316538"
local PANTS = "rbxassetid://9962616226"
local CLOTH_TINT = Color3.fromRGB(120, 104, 100)
local WEAPON = "Great Hammer"
local WEAPON_FINISH = { 0.5, 0.45, 0.45 }

-- Builds the boss rig standing on `post` (a ground-level CFrame facing the way it looks). Yields while the hammer
-- loads.
function Boss.build(post: CFrame): Model
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = Color3.fromRGB(96, 90, 88)
	d.TorsoColor = Color3.fromRGB(48, 40, 40)
	for _, limb in { "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
		(d :: any)[limb] = Color3.fromRGB(60, 54, 54)
	end
	local model = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R6)
	model.Name = "Ashen Sentinel"
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- a LocalScript; this rig is animated from here
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) -- its HP lives on the actor
	humanoid.AutoRotate = false -- an AlignOrientation turns it
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	for _, c in model:GetChildren() do
		if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") then
			c:Destroy()
		end
	end
	local shirt = Instance.new("Shirt")
	shirt.ShirtTemplate = SHIRT
	shirt.Color3 = CLOTH_TINT
	shirt.Parent = model
	local pants = Instance.new("Pants")
	pants.PantsTemplate = PANTS
	pants.Color3 = CLOTH_TINT
	pants.Parent = model

	-- Embers for eyes.
	local head = model:FindFirstChild("Head") :: BasePart
	for _, x in { -0.22, 0.22 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.2, 0.12, 0.05)
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(255, 120, 40)
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Massless = true
		local offset = CFrame.new(x, 0.12, -0.6)
		eye.CFrame = head.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = eye
		weld.C0 = offset
		weld.Parent = eye
		eye.Parent = model
	end
	local face = head:FindFirstChildOfClass("Decal")
	if face then
		face:Destroy()
	end

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.PrimaryPart = root
	local torso = model:FindFirstChild("Torso") :: BasePart
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 50)
	light.Range = 10
	light.Brightness = 0.6
	light.Parent = torso
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60), Color3.fromRGB(200, 50, 20))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.25, 0)
	embers.Lifetime = NumberRange.new(0.8, 1.6)
	embers.Speed = NumberRange.new(2, 5)
	embers.SpreadAngle = Vector2.new(40, 40)
	embers.Acceleration = Vector3.new(0, 4, 0)
	embers.Rate = 6
	embers.Parent = torso

	model:PivotTo(post * CFrame.new(0, 3, 0))
	model.Parent = workspace
	Weapons.equip(model, "Boss", WEAPON, WEAPON_FINISH)
	model:ScaleTo(Boss.SCALE)
	model:PivotTo(post * CFrame.new(0, 3 * Boss.SCALE, 0))
	root:SetNetworkOwner(nil) -- server physics, so everyone sees the same leaps

	local attachment = Instance.new("Attachment")
	attachment.Name = "FacingAttachment"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "Facing"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.Responsiveness = 30
	align.CFrame = post.Rotation
	align.Parent = root

	-- Name and HP bar over the head.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 30)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Ashen Sentinel"
	label.TextColor3 = Color3.fromRGB(255, 200, 170)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = head

	model:SetAttribute("DamageScale", 1)
	return model
end

-- The ring on the floor around its post: step inside and it attacks.
local function drawAggroRing(post: CFrame, radius: number)
	local folder = Instance.new("Model")
	folder.Name = "BossRing"
	local ground = post.Position + Vector3.new(0, 0.12, 0)
	for i = 1, RING_SEGMENTS do
		local angle = (i - 0.5) / RING_SEGMENTS * 2 * math.pi
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(150, 40, 25)
		p.Transparency = 0.45
		p.Size = Vector3.new(2 * math.pi * radius / RING_SEGMENTS * 0.6, 0.1, 0.5)
		p.CFrame = CFrame.new(ground) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
		p.Parent = folder
	end
	local floor = Instance.new("Part")
	floor.Name = "Scorch"
	floor.Anchored = true
	floor.CanCollide = false
	floor.CanQuery = false
	floor.CanTouch = false
	floor.Shape = Enum.PartType.Cylinder
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(46, 40, 38)
	floor.Size = Vector3.new(0.1, radius * 2, radius * 2)
	floor.CFrame = CFrame.new(ground - Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	floor.Parent = folder
	folder.Parent = workspace:FindFirstChild("Arena") or workspace
end

----------------------------------------------------------------------------------------------------
-- State

function Boss.new(service, actor, post: CFrame)
	local self = setmetatable({}, Boss)
	self.service = service
	self.actor = actor
	self.post = post
	self.groundY = post.Position.Y
	self.home = post * CFrame.new(0, 3 * Boss.SCALE, 0)
	self.model = actor.model
	self.humanoid = self.model:FindFirstChildOfClass("Humanoid")
	self.root = self.model.PrimaryPart
	self.align = self.root:FindFirstChild("Facing")
	self.embers = self.model.Torso:FindFirstChild("Embers")
	self.light = self.model.Torso:FindFirstChildOfClass("PointLight")
	self.looks = {}
	for _, d in self.model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			self.looks[d] = d.Transparency
		end
	end

	actor.threat = {}
	actor.radius = 2.5
	actor.enemyDR = 0 -- [Proto]
	actor.kit = { id = "Boss" } -- which clips server/Animations plays (AssetIds.Combat.Boss)
	actor.hyperArmor = true -- server/Poise: hits never flinch it

	actor.onDamaged = function(_, source)
		self:engage(source)
	end
	actor.onParried = function(_, _parrier)
		self:addBreak(Boss.BREAK_PARRY)
	end
	actor.onInterrupted = function(_, source)
		self:interrupt(source)
	end

	local animator = self.humanoid:FindFirstChildOfClass("Animator")
	self.walkTrack = animator:LoadAnimation((function()
		local a = Instance.new("Animation")
		a.AnimationId = AssetIds.uri(AssetIds.Move["Walk W"])
		return a
	end)())
	self.walkTrack.Priority = Enum.AnimationPriority.Movement
	self.walkTrack.Looped = true

	drawAggroRing(post, Boss.AGGRO_RANGE + actor.radius)
	self:reset()
	return self
end

function Boss:setLook(visible: boolean)
	for part, transparency in self.looks do
		if part.Parent then
			if visible then
				part.Transparency = transparency
			else
				TweenService:Create(part, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			end
		end
	end
end

function Boss:setPhase(phase: number)
	self.phase = phase
	self.humanoid.WalkSpeed = Boss.WALK_SPEED[phase]
	self.embers.Rate = if phase == 2 then 40 else 6
	self.light.Brightness = if phase == 2 then 2 else 0.6
	self.light.Range = if phase == 2 then 18 else 10
end

function Boss:reset()
	local actor = self.actor
	self:clearAction()
	actor.health = Boss.MAX_HEALTH
	actor.maxHealth = Boss.MAX_HEALTH
	actor.dead = false
	table.clear(actor.threat)
	table.clear(actor.dots)
	self.engaged = false
	self.engagedAt = 0
	self.lastSeen = 0
	self.cast = nil
	self.roarUntil = 0
	self.brokenUntil = 0
	self.breakLockedUntil = 0
	self.breakMeter = 0
	self.interruptLockUntil = 0
	self:setPhase(1)
	self.root.Anchored = false
	self.humanoid.PlatformStand = false
	self.humanoid:Move(Vector3.zero)
	self.root.AssemblyLinearVelocity = Vector3.zero
	self.model:PivotTo(self.home)
	self.align.CFrame = self.home.Rotation
	self:setLook(true)
	self:walk(false)
end

function Boss:engage(source)
	local now = self.service.now
	if not self.engaged and self.actor.health > 0 then
		self.engaged = true
		self.engagedAt = now
		self.next = { cast = now + Boss.CAST.every[1] }
		for _, move in Boss.MOVES do
			self.next[move.key] = now + move.first
		end
		self:announce("The Ashen Sentinel rises")
	end
	self.lastSeen = now
end

-- A line in everyone's combat log who is near the fight.
function Boss:announce(text: string)
	for _, p in self.service.living("players") do
		if self.service.inRange(self.actor, p, Boss.LEASH_RANGE + 20) then
			self.service.log(p, text)
		end
	end
end

function Boss:addBreak(amount: number)
	local now = self.service.now
	if now < self.breakLockedUntil or now < self.brokenUntil then
		return
	end
	self.breakMeter = math.min(Boss.BREAK_MAX, self.breakMeter + amount)
	if self.breakMeter >= Boss.BREAK_MAX then
		self.breakMeter = 0
		self.brokenUntil = now + Constants.BREAK_STUN
		self.breakLockedUntil = now + Constants.BREAK_STUN + Constants.BREAK_LOCK
		self:clearAction()
		self.cast = nil
		Animations.hurt(self.actor)
		self.service.fx({ t = "broken", dst = self.actor.id, pos = self.actor:position() })
	end
end

function Boss:interrupt(source)
	local now = self.service.now
	if not self.cast then
		return
	end
	if now < self.interruptLockUntil then
		self.service.log(source, Boss.CAST.name .. " cannot be interrupted again yet")
		return
	end
	self.cast = nil
	Animations.cancel(self.actor)
	self.interruptLockUntil = now + Constants.INTERRUPT_LOCK
	self.service.log(source, "Interrupted " .. Boss.CAST.name)
	self:addBreak(Boss.BREAK_INTERRUPT)
end

function Boss:topTarget()
	local best, bestThreat = nil, -1
	for actor, threat in self.actor.threat do
		if actor:isAlive() and threat > bestThreat and self.service.inRange(self.actor, actor, Boss.LEASH_RANGE) then
			best, bestThreat = actor, threat
		end
	end
	if best then
		return best
	end
	-- Nobody has threat yet: the closest living player.
	local pos = self.actor:position()
	local bestDist = math.huge
	for _, actor in self.service.living("players") do
		local d = ((actor:position() :: Vector3) - (pos :: Vector3)).Magnitude
		if d < bestDist then
			best, bestDist = actor, d
		end
	end
	return best
end

function Boss:farthestTarget()
	local best, bestDist = nil, -1
	local pos = self.actor:position() :: Vector3
	for _, actor in self.service.living("players") do
		local d = ((actor:position() :: Vector3) - pos).Magnitude
		if d <= Boss.LEASH_RANGE and d > bestDist then
			best, bestDist = actor, d
		end
	end
	return best
end

function Boss:face(position: Vector3)
	local offset = flat(position - self.root.Position)
	if offset.Magnitude > 0.01 then
		self.align.CFrame = CFrame.lookAt(Vector3.zero, offset.Unit)
	end
end

function Boss:walk(on: boolean)
	if on and not self.walkTrack.IsPlaying then
		self.walkTrack:Play(0.25)
	elseif not on and self.walkTrack.IsPlaying then
		self.walkTrack:Stop(0.25)
	end
	if on then
		self.walkTrack:AdjustSpeed(self.humanoid.WalkSpeed / (WALK_ANIM_SPEED * Boss.SCALE)) -- longer legs, longer strides
	end
end

----------------------------------------------------------------------------------------------------
-- Telegraphs

local function floorPart(color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = "Telegraph"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	return p
end

-- Draws `shape` on the floor: a faint outline of the whole area and a brighter fill that grows until the hit
-- lands, so how long is left can be read at a glance.
function Boss:drawShape(shape, color: Color3, duration: number): { Instance }
	local y = self.groundY + 0.15
	local parts = {}
	local grow = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	if shape.kind == "circle" then
		local at = CFrame.new(Vector3.new(shape.center.X, y, shape.center.Z)) * CFrame.Angles(0, 0, math.rad(90))
		local outline = floorPart(color, 0.75)
		outline.Shape = Enum.PartType.Cylinder
		outline.Size = Vector3.new(0.1, shape.radius * 2, shape.radius * 2)
		outline.CFrame = at
		local fill = floorPart(color, 0.4)
		fill.Shape = Enum.PartType.Cylinder
		fill.Size = Vector3.new(0.12, 0.2, 0.2)
		fill.CFrame = at
		TweenService:Create(fill, grow, { Size = Vector3.new(0.12, shape.radius * 2, shape.radius * 2) }):Play()
		parts = { outline, fill }
	elseif shape.kind == "rect" then
		-- From `from` along `dir` for `length`; a cone is drawn as the rectangle that covers it.
		local base = Vector3.new(shape.from.X, y, shape.from.Z)
		local frame = CFrame.lookAt(base, base + shape.dir)
		local outline = floorPart(color, 0.75)
		outline.Size = Vector3.new(shape.width, 0.1, shape.length)
		outline.CFrame = frame * CFrame.new(0, 0, -shape.length / 2)
		local fill = floorPart(color, 0.4)
		fill.Size = Vector3.new(shape.width, 0.12, 0.2)
		fill.CFrame = frame * CFrame.new(0, 0, -0.1)
		TweenService:Create(fill, grow, { Size = Vector3.new(shape.width, 0.12, shape.length), CFrame = outline.CFrame }):Play()
		parts = { outline, fill }
	elseif shape.kind == "ring" then
		local centre = Vector3.new(shape.center.X, y, shape.center.Z)
		local width = shape.outer - shape.inner
		local mid = (shape.outer + shape.inner) / 2
		for i = 1, RING_SEGMENTS do
			local angle = (i - 0.5) / RING_SEGMENTS * 2 * math.pi
			local seg = floorPart(color, 0.8)
			seg.Size = Vector3.new(2 * math.pi * shape.outer / RING_SEGMENTS + 0.3, 0.1, width)
			seg.CFrame = CFrame.new(centre) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -mid)
			TweenService:Create(seg, grow, { Transparency = 0.35 }):Play()
			table.insert(parts, seg)
		end
		-- The safe middle, in a calm colour.
		local safe = floorPart(Color3.fromRGB(90, 160, 220), 0.7)
		safe.Shape = Enum.PartType.Cylinder
		safe.Size = Vector3.new(0.1, shape.inner * 2, shape.inner * 2)
		safe.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
		table.insert(parts, safe)
	end
	for _, p in parts do
		p.Parent = workspace
	end
	return parts
end

-- The areas a step will hit, fixed when its telegraph starts so they can be read and avoided.
function Boss:shapesFor(step, target): { any }
	local attack = Boss.ATTACKS[step.attack]
	local pos = self.root.Position
	local look = flat(self.root.CFrame.LookVector).Unit
	if attack.shape == "cone" then
		local width = 2 * attack.range * math.sin(math.rad(math.min(attack.degrees, 120) / 2))
		return { { kind = "rect", cone = true, from = pos, dir = look, length = attack.range, width = width, degrees = attack.degrees } }
	elseif attack.shape == "circle" then
		return { { kind = "circle", center = pos, radius = attack.radius } }
	elseif attack.shape == "ring" then
		return { { kind = "ring", center = pos, inner = attack.inner, outer = attack.outer } }
	elseif attack.shape == "leap" then
		local goal = target and target:position() or pos
		local offset = flat(goal - pos)
		if offset.Magnitude > Boss.LEAP_MAX then
			goal = pos + offset.Unit * Boss.LEAP_MAX
		end
		return { { kind = "circle", center = Vector3.new(goal.X, self.groundY, goal.Z), radius = attack.radius, leap = true } }
	elseif attack.shape == "lines" then
		local shapes = {}
		local base = math.rad(step.turn or 0)
		for i = 0, 1 do
			local dir = (CFrame.Angles(0, base + i * math.pi / 2, 0) * look)
			table.insert(shapes, { kind = "rect", from = pos - dir * attack.length / 2, dir = dir, length = attack.length, width = attack.width })
		end
		return shapes
	end
	return {}
end

local function inside(shape, point: Vector3): boolean
	local margin = 1.2 -- about a character's half width
	if shape.kind == "circle" then
		return flat(point - shape.center).Magnitude <= shape.radius + margin
	elseif shape.kind == "ring" then
		local d = flat(point - shape.center).Magnitude
		return d >= shape.inner + 0.5 and d <= shape.outer + margin
	elseif shape.kind == "rect" then
		local offset = flat(point - shape.from)
		if shape.cone then
			local d = offset.Magnitude
			return d <= shape.length + margin + 2 and (d < 0.01 or shape.dir:Dot(offset.Unit) >= math.cos(math.rad(shape.degrees / 2)))
		end
		local along = shape.dir:Dot(offset)
		local side = math.abs(shape.dir:Cross(Vector3.yAxis):Dot(offset))
		return along >= -margin and along <= shape.length + margin and side <= shape.width / 2 + margin
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- Moves

function Boss:clearAction()
	local action = self.action
	if action and action.parts then
		for _, p in action.parts do
			p:Destroy()
		end
	end
	self.action = nil
	local highlight = self.model:FindFirstChild("Telegraph")
	if highlight then
		highlight:Destroy()
	end
	if self.humanoid.PlatformStand then
		self.humanoid.PlatformStand = false
	end
	Animations.cancel(self.actor)
end

function Boss:setHighlight(color: string?)
	local highlight = self.model:FindFirstChild("Telegraph") :: Highlight?
	if not color then
		if highlight then
			highlight:Destroy()
		end
		return
	end
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "Telegraph"
		highlight.FillTransparency = 0.7
		highlight.OutlineTransparency = 0.1
		highlight.Parent = self.model
	end
	highlight.FillColor = COLORS[color]
	highlight.OutlineColor = COLORS[color]
end

function Boss:startMove(move, now: number)
	self.humanoid:Move(Vector3.zero)
	self:walk(false)
	self.action = { move = move, index = 0, parts = nil }
	self:startStep(now)
end

-- Starts the move's next step, or its recovery after the last one.
function Boss:startStep(now: number)
	local action = self.action
	action.index += 1
	local step = action.move.steps[action.index]
	if not step then
		action.step = nil
		action.recoverUntil = now + action.move.recovery
		self:setHighlight(nil)
		return
	end
	local target = if step.attack == "leap" then self:farthestTarget() else self:topTarget()
	if target and step.attack ~= "lines" then
		self:face(target:position())
		self.root.CFrame = CFrame.new(self.root.Position) * self.align.CFrame -- snap, so the cone is where it looks
	end
	local attack = Boss.ATTACKS[step.attack]
	action.step = step
	action.attack = attack
	action.fireAt = now + step.telegraph
	action.shapes = self:shapesFor(step, target)
	action.parts = {}
	for _, shape in action.shapes do
		for _, p in self:drawShape(shape, COLORS[attack.color], step.telegraph) do
			table.insert(action.parts, p)
		end
	end
	action.launched = false
	self:setHighlight(attack.color)
	Animations.action(self.actor, { id = step.anim, windup = step.telegraph }, now)
	self.service.fx({ t = "bossTelegraph", key = step.attack, color = attack.color, pos = self.root.Position })
end

-- Ash Leap: jump on a ballistic arc so it lands in the circle as the telegraph ends.
function Boss:launch(goal: Vector3)
	local from = self.root.Position
	local land = Vector3.new(goal.X, from.Y, goal.Z)
	local t = Boss.LEAP_AIR
	local g = workspace.Gravity
	self:face(land)
	self.humanoid.PlatformStand = true -- no walking control in the air; the AlignOrientation keeps it upright
	self.root.AssemblyLinearVelocity = (land - from) / t + Vector3.new(0, g * t / 2, 0)
end

function Boss:damageMult(now: number): number
	local mult = self.model:GetAttribute("DamageScale") or 1
	if now - self.engagedAt >= Boss.ENRAGE_AT then
		mult *= Boss.ENRAGE_MULT
	end
	return mult
end

function Boss:resolveStep(now: number)
	local action = self.action
	local attack = action.attack
	for _, p in action.parts do
		p:Destroy()
	end
	action.parts = nil
	if action.launched then
		self.humanoid.PlatformStand = false
		self.root.AssemblyLinearVelocity = Vector3.zero
	end
	self.actor.damageScale = self:damageMult(now)
	local hitAlready = {}
	for _, shape in action.shapes do
		self.service.fx({
			t = "bossAttack",
			key = action.step.attack,
			color = attack.color,
			pos = Vector3.new(
				(shape.center or (shape.from + shape.dir * shape.length / 2)).X,
				self.groundY,
				(shape.center or (shape.from + shape.dir * shape.length / 2)).Z
			),
			radius = shape.radius or shape.outer,
		})
		for _, target in self.service.living("players") do
			if not hitAlready[target] and inside(shape, target:position() :: Vector3) then
				hitAlready[target] = true
				self.service.enemyHit(self.actor, target, attack.written, attack)
			end
		end
	end
	self:startStep(now)
end

function Boss:startCast(now: number)
	self.humanoid:Move(Vector3.zero)
	self:walk(false)
	self.cast = { startedAt = now, endsAt = now + Boss.CAST.duration }
	self:setHighlight("red")
	Animations.action(self.actor, { id = "chant", windup = Boss.CAST.duration }, now)
	self.service.fx({ t = "cast", dst = self.actor.id, name = Boss.CAST.name, duration = Boss.CAST.duration, pos = self.actor:position() })
end

function Boss:resolveCast(now: number)
	self.cast = nil
	self:setHighlight(nil)
	self.actor.damageScale = self:damageMult(now)
	local attack = { name = Boss.CAST.name, color = "red" }
	self.service.fx({ t = "bossAttack", key = "chant", color = "red", pos = self.root.Position, radius = Boss.LEASH_RANGE })
	for _, target in self.service.living("players") do
		if self.service.inRange(self.actor, target, Boss.LEASH_RANGE) then
			self.service.enemyHit(self.actor, target, Boss.CAST.written, attack)
		end
	end
end

function Boss:die(now: number)
	self:clearAction()
	self.cast = nil
	self:walk(false)
	self.engaged = false
	self.actor.dead = true
	self.respawnAt = now + Boss.RESPAWN
	self.humanoid:Move(Vector3.zero)
	self.root.Anchored = true
	self:setLook(false)
	self.service.fx({ t = "bossDead", dst = self.actor.id, pos = self.root.Position })
end

function Boss:step(now: number)
	local actor = self.actor
	local root = self.root
	if not root or not root.Parent then
		return
	end

	if actor.dead then
		if self.respawnAt and now >= self.respawnAt then
			self.respawnAt = nil
			self:reset()
		end
		return
	end
	local setHealth = self.model:GetAttribute("SetHealth")
	if setHealth then
		self.model:SetAttribute("SetHealth", nil)
		actor.health = math.clamp(setHealth, 0, 1) * actor.maxHealth
	end
	if actor.health <= 0 then
		self:die(now)
		return
	end

	-- Aggro and reset
	local anyoneNear = false
	for _, p in self.service.living("players") do
		if self.service.inRange(actor, p, self.engaged and Boss.LEASH_RANGE or Boss.AGGRO_RANGE) then
			anyoneNear = true
			if not self.engaged then
				self:engage(p)
			end
		end
	end
	if not self.engaged then
		return
	end
	if anyoneNear then
		self.lastSeen = now
	elseif now - self.lastSeen > Boss.RESET_AFTER then
		self:reset()
		return
	end

	-- Phase 2: it roars and catches fire. Whatever it was doing is dropped.
	if self.phase == 1 and actor.health <= Boss.PHASE2_AT * actor.maxHealth then
		self:clearAction()
		self.cast = nil
		self:setPhase(2)
		self:walk(false)
		self.humanoid:Move(Vector3.zero)
		self.roarUntil = now + Boss.ROAR_TIME
		self.next.cast = now + Boss.ROAR_TIME + 8
		for _, move in Boss.MOVES do
			if move.phase == 2 then
				self.next[move.key] = now + Boss.ROAR_TIME + move.first - 4 -- the Cinder Ring comes right after the roar
			end
		end
		Animations.action(actor, { id = "chant", windup = Boss.ROAR_TIME }, now)
		self:setHighlight("orange")
		self.service.fx({ t = "bossPhase", dst = actor.id, pos = root.Position })
		self:announce("The Ashen Sentinel ignites! New attacks: Cinder Ring (get close) and Ember Lines (stand between).")
		return
	end
	if now < self.roarUntil then
		return
	elseif self.roarUntil > 0 then
		self.roarUntil = 0
		self:setHighlight(nil)
	end

	if now < self.brokenUntil then
		self.humanoid:Move(Vector3.zero)
		self:walk(false)
		return
	end

	-- Whatever is in progress.
	local action = self.action
	if action then
		if action.step then
			if action.step.attack == "leap" and not action.launched and now >= action.fireAt - Boss.LEAP_AIR then
				action.launched = true
				self:launch(action.shapes[1].center)
			end
			if now >= action.fireAt then
				self:resolveStep(now)
			end
			return
		end
		if now < action.recoverUntil then
			return
		end
		self.action = nil
	end
	if self.cast then
		if now >= self.cast.endsAt then
			self:resolveCast(now)
		end
		return
	end

	local target = self:topTarget()
	if not target then
		return
	end

	-- Face and walk toward the target.
	local tpos = target:position() :: Vector3
	local offset = flat(tpos - root.Position)
	local dist = offset.Magnitude
	self:face(tpos)
	if dist > Boss.MELEE_REACH then
		self.humanoid:Move(offset.Unit)
		self:walk(true)
	else
		self.humanoid:Move(Vector3.zero)
		self:walk(false)
	end

	-- Start the next move: the cast first, then MOVES in order. Melee moves wait until it is in reach.
	local due = self.next
	if now >= due.cast then
		due.cast = now + Boss.CAST.every[self.phase]
		self:startCast(now)
		return
	end
	for _, move in Boss.MOVES do
		if (move.phase or 1) <= self.phase and now >= due[move.key] and (not move.melee or dist <= Boss.MELEE_REACH + 4) then
			due[move.key] = now + move.every[self.phase]
			self:startMove(move, now)
			return
		end
	end
end

function Boss:snapshot(now: number)
	local actor = self.actor
	local action = self.action
	local step = action and action.step
	local cast = self.cast
	return {
		id = actor.id,
		name = actor.name,
		hp = actor.health,
		maxHp = actor.maxHealth,
		engaged = self.engaged,
		phase = self.phase,
		breakMeter = self.breakMeter,
		breakMax = Boss.BREAK_MAX,
		breakLocked = now < self.breakLockedUntil,
		broken = now < self.brokenUntil,
		telegraph = step and { name = action.attack.name, color = action.attack.color, left = math.max(0, action.fireAt - now) } or nil,
		cast = cast and {
			name = Boss.CAST.name,
			left = math.max(0, cast.endsAt - now),
			total = Boss.CAST.duration,
			interruptible = now >= self.interruptLockUntil,
		} or nil,
		enrage = math.max(0, Boss.ENRAGE_AT - (now - self.engagedAt)),
	}
end

return Boss
