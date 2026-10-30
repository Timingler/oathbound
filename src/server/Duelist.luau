-- Animated R6 fighters for the arena, run by the server.
--
-- Duelist mode: a swordsman with the Warden's sword, hold pose and combat animations. It walks to you, swings
-- combos of white (block, parry or dodge) slashes, now and then a slow orange thrust (parry or dodge only),
-- blocks some of your attacks from the front, rolls away when you pile on hits, and is staggered when you parry
-- it. It dies, falls apart, and a new one walks out of its post after a few seconds.
--
-- Passive mode: the training dummy. An R6 straw figure that turns to face the nearest player and never attacks
-- or defends, so the DPS meter stays honest.
--
-- Every number here is [Proto]: none of it is in the design docs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared.AssetIds)
local Constants = require(Shared.Constants)

local Actor = require(script.Parent.Actor)
local Animations = require(script.Parent.Animations)
local Weapons = require(script.Parent.Weapons)

local Duelist = {}
Duelist.__index = Duelist

Duelist.MAX_HEALTH = 20000 -- about 25 s of an Assassin's basic attacks, longer with its blocks and rolls
Duelist.LEVEL = 50
Duelist.ITEM_LEVEL = 65
Duelist.AGGRO_RANGE = 30
Duelist.LEASH_RANGE = 55 -- from its post; past this it gives up and walks home
Duelist.REACH = 5.5 -- starts a swing from this far
Duelist.WALK_SPEED = 14
Duelist.RESPAWN = 8 -- seconds
-- Hit sizes are written against light armor, like the boss's: an Assassin standing still dies in about 8 slashes.
Duelist.SLASH = { id = "basic", name = "Duelist Slash", color = "white", written = 1100, windup = 0.5, recovery = 0.35, range = 7.5, degrees = 120 }
Duelist.THRUST = { id = "cleave", name = "Duelist Thrust", color = "orange", written = 3000, windup = 0.9, recovery = 0.7, range = 9, degrees = 70 }
Duelist.COMBO_MAX = 3 -- slashes in a row before it backs off
Duelist.THRUST_EVERY = 3 -- combos; every third ends in a thrust
Duelist.PAUSE = { 1.2, 2.2 } -- seconds between combos
Duelist.BLOCK_CHANCE = 0.25 -- per attack of yours it sees coming
Duelist.BLOCK_TIME = 0.9
Duelist.ROLL_AFTER = 3 -- hits taken within ROLL_WINDOW
Duelist.ROLL_WINDOW = 2
Duelist.ROLL_COOLDOWN = 6
Duelist.ROLL_SPEED = 38
Duelist.ROLL_TIME = 0.35
Duelist.STAGGER = 1.2 -- seconds helpless after you parry it
Duelist.DUMMY_TURN = 0.15 -- passive mode: fraction of the way it turns to you per tick

local TELEGRAPH = {
	white = Color3.fromRGB(235, 235, 235),
	orange = Color3.fromRGB(255, 140, 30),
}

local rng = Random.new()

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function description(passive: boolean): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local skin = if passive then Color3.fromRGB(196, 160, 104) else Color3.fromRGB(58, 60, 68)
	d.HeadColor = if passive then Color3.fromRGB(214, 182, 120) else Color3.fromRGB(150, 140, 130)
	d.TorsoColor = if passive then Color3.fromRGB(150, 110, 70) else Color3.fromRGB(70, 32, 34)
	d.LeftArmColor = skin
	d.RightArmColor = skin
	d.LeftLegColor = skin
	d.RightLegColor = skin
	return d
end

-- Name and HP bar over the head. Roblox's own name and health display are hidden.
local function nameplate(head: BasePart, text: string): (TextLabel, Frame)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(160, 34)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 80
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 22)
	back.Size = UDim2.new(1, 0, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = head
	return label, fill
end

-- opts = { name, home: CFrame, passive: boolean? }
function Duelist.new(service, opts)
	local self = setmetatable({}, Duelist)
	self.service = service
	self.name = opts.name
	self.home = opts.home
	self.passive = opts.passive == true
	self.actor = Actor.new({
		kind = if self.passive then "dummy" else "npc",
		name = opts.name,
		team = "enemies",
		model = nil :: any,
		level = Duelist.LEVEL,
		itemLevel = Duelist.ITEM_LEVEL,
		maxHealth = if self.passive then 1e9 else Duelist.MAX_HEALTH,
	})
	local actor = self.actor
	actor.kit = { id = "Warden" } -- which combat animations Animations plays for it
	actor.radius = 1.5
	actor.enemyDR = 0
	actor.onDamaged = function(_, source)
		self:onDamaged(source)
	end
	actor.onParried = function(_, parrier)
		self:stagger(parrier)
	end
	self:spawn()
	service.addEnemy(actor)
	table.insert(service.npcs, self)
	return self
end

function Duelist:spawn()
	local actor = self.actor
	local model = Players:CreateHumanoidModelFromDescription(description(self.passive), Enum.HumanoidRigType.R6)
	model.Name = self.name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- a LocalScript; this rig is animated from here
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = Duelist.WALK_SPEED
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = self.passive -- the dummy cannot be shoved around
	model.PrimaryPart = root -- so the home CFrame places the root, not the rig's default pivot
	model:PivotTo(self.home)
	self.label, self.fill = nameplate(model:FindFirstChild("Head") :: BasePart, self.name)
	self.fill.Parent.Visible = not self.passive -- the dummy cannot be hurt
	model.Parent = workspace
	if not self.passive then
		root:SetNetworkOwner(nil) -- server physics, so the AI's moves and rolls are what everyone sees
	end

	actor.model = model
	actor.health = actor.maxHealth
	actor.dead = false
	actor.blocking = false
	actor.dodgeUntil = 0
	table.clear(actor.dots)
	self.humanoid = humanoid
	self.root = root
	self.target = nil
	self.state = "idle" -- idle | windup | recovery | block | stagger | roll | dead
	self.stateEnds = 0
	self.attack = nil
	self.comboLeft = 0
	self.combos = 0
	self.nextAttack = 0
	self.lastRoll = -math.huge
	self.recentHits = {}
	self.seenWindup = nil
	self.moving = nil
	self.shownHealth = -1

	-- Walk, run and idle cycles from the movement kit, played from here like the player's Locomotion.
	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
	self.moves = {}
	for _, name in { "Idle", "Walk W", "Run W" } do
		local animation = Instance.new("Animation")
		animation.AnimationId = AssetIds.uri(AssetIds.Move[name])
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Movement
		track.Looped = true
		self.moves[name] = track
	end
	local rollAnimation = Instance.new("Animation")
	rollAnimation.AnimationId = AssetIds.uri(AssetIds.Combat.Common.roll.id)
	self.rollTrack = animator:LoadAnimation(rollAnimation)
	self.rollTrack.Priority = Enum.AnimationPriority.Action3

	if not self.passive then
		task.spawn(Weapons.equip, model, "Warden")
	end
	self:setMove("Idle", 1)
end

function Duelist:setMove(name: string?, rate: number)
	if self.moving ~= name then
		if self.moving then
			self.moves[self.moving]:Stop(0.2)
		end
		self.moving = name
		if name then
			self.moves[name]:Play(0.2)
		end
	end
	if name then
		self.moves[name]:AdjustSpeed(rate)
	end
end

function Duelist:setTelegraph(color: string?)
	local model = self.actor.model
	local highlight = model:FindFirstChild("Telegraph") :: Highlight?
	if not color then
		if highlight then
			highlight:Destroy()
		end
		return
	end
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "Telegraph"
		highlight.FillTransparency = 0.6
		highlight.OutlineTransparency = 0
		highlight.Parent = model
	end
	highlight.FillColor = TELEGRAPH[color]
	highlight.OutlineColor = TELEGRAPH[color]
end

function Duelist:onDamaged(source)
	local now = self.service.now
	self.target = source
	table.insert(self.recentHits, now)
	while self.recentHits[1] and now - self.recentHits[1] > Duelist.ROLL_WINDOW do
		table.remove(self.recentHits, 1)
	end
end

-- You parried it: the swing is lost and it is open for a moment.
function Duelist:stagger(parrier)
	local now = self.service.now
	self:endAction()
	self.state = "stagger"
	self.stateEnds = now + Duelist.STAGGER
	self.comboLeft = 0
	self.service.fx({ t = "avoid", src = parrier.id, dst = self.actor.id, text = "Staggered", pos = self.actor:position() })
end

function Duelist:endAction()
	self:setTelegraph(nil)
	self.attack = nil
	if self.actor.blocking then
		self.actor.blocking = false
		Animations.block(self.actor, false)
	end
	Animations.cancel(self.actor)
end

function Duelist:faceTowards(position: Vector3, fraction: number)
	local root = self.root
	local offset = flat(position - root.Position)
	if offset.Magnitude < 0.01 then
		return
	end
	local goal = CFrame.lookAt(root.Position, root.Position + offset)
	root.CFrame = root.CFrame:Lerp(goal, fraction)
end

function Duelist:startAttack(attack, now: number)
	local actor = self.actor
	self:faceTowards(self.target:position(), 1) -- facing locks for the wind-up, so it can be read and dodged
	self.humanoid:Move(Vector3.zero)
	self:setMove("Idle", 1)
	self.attack = attack
	self.state = "windup"
	self.stateEnds = now + attack.windup
	self:setTelegraph(attack.color)
	Animations.action(actor, attack, now)
	self.service.fx({ t = "swing", src = actor.id, pos = actor:position() })
end

function Duelist:resolveAttack(now: number)
	local actor = self.actor
	local attack = self.attack
	self:setTelegraph(nil)
	actor.damageScale = actor.model:GetAttribute("DamageScale") or 1
	local origin = self.root.CFrame
	local look = flat(origin.LookVector).Unit
	local minDot = math.cos(math.rad(attack.degrees / 2))
	for _, target in self.service.living("players") do
		local offset = flat((target:position() :: Vector3) - origin.Position)
		local dist = offset.Magnitude
		if dist <= attack.range and (dist < 0.01 or look:Dot(offset.Unit) >= minDot) then
			self.service.enemyHit(actor, target, attack.written, attack)
		end
	end
	self.state = "recovery"
	self.stateEnds = now + attack.recovery
end

function Duelist:roll(now: number)
	local root = self.root
	local away = flat(root.Position - self.target:position())
	away = if away.Magnitude > 0.01 then away.Unit else -root.CFrame.LookVector
	self:endAction()
	self.state = "roll"
	self.stateEnds = now + Duelist.ROLL_TIME
	self.lastRoll = now
	table.clear(self.recentHits)
	self.actor.dodgeUntil = now + Constants.DODGE_INVULN
	self.rollTrack:Play(0.05)
	self.rollTrack:AdjustSpeed(2)
	self.service.fx({ t = "avoid", src = self.target.id, dst = self.actor.id, text = "Roll", pos = root.Position })

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = 1e6
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(away.X, away.Z) * Duelist.ROLL_SPEED
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Parent = root
	task.delay(Duelist.ROLL_TIME, function()
		velocity:Destroy()
		attachment:Destroy()
	end)
end

function Duelist:die(now: number)
	local actor = self.actor
	self:endAction()
	self:setMove(nil, 1)
	self.state = "dead"
	self.stateEnds = now + Duelist.RESPAWN
	actor.dead = true
	self.humanoid.Health = 0 -- R6 falls apart
	self.fill.Size = UDim2.fromScale(0, 1)
	for _, p in self.service.living("players") do
		if self.service.inRange(actor, p, Duelist.LEASH_RANGE) then
			self.service.log(p, string.format("%s falls. Another steps up in %d s.", self.name, Duelist.RESPAWN))
		end
	end
	local model = actor.model
	task.delay(Duelist.RESPAWN - 0.5, function()
		model:Destroy()
	end)
end

-- Picks who to fight: whoever hit it last if still in leash range, else the closest player in aggro range.
function Duelist:pickTarget()
	local actor = self.actor
	local homePos = self.home.Position
	local current = self.target
	if current and current:isAlive() and ((current:position() :: Vector3) - homePos).Magnitude <= Duelist.LEASH_RANGE then
		return current
	end
	local best, bestDist = nil, Duelist.AGGRO_RANGE
	for _, p in self.service.living("players") do
		local d = ((p:position() :: Vector3) - (actor:position() :: Vector3)).Magnitude
		if d <= bestDist then
			best, bestDist = p, d
		end
	end
	return best
end

function Duelist:updateNameplate()
	local actor = self.actor
	if self.passive or actor.health == self.shownHealth then
		return
	end
	self.shownHealth = actor.health
	self.fill.Size = UDim2.fromScale(math.clamp(actor.health / actor.maxHealth, 0, 1), 1)
	self.label.Text = string.format("%s  %d%%", self.name, math.ceil(100 * actor.health / actor.maxHealth))
end

-- Passive mode: face the nearest player.
function Duelist:stepDummy()
	local actor = self.actor
	local best, bestDist = nil, Duelist.AGGRO_RANGE
	for _, p in self.service.living("players") do
		local d = ((p:position() :: Vector3) - (actor:position() :: Vector3)).Magnitude
		if d <= bestDist then
			best, bestDist = p, d
		end
	end
	if best then
		self:faceTowards(best:position(), Duelist.DUMMY_TURN)
	end
end

function Duelist:step(now: number)
	local actor = self.actor
	if self.state == "dead" then
		if now >= self.stateEnds then
			self:spawn()
		end
		return
	end
	if not actor.model.Parent or not self.root.Parent then
		return
	end
	if self.passive then
		self:stepDummy()
		return
	end
	if actor.health <= 0 then
		self:die(now)
		return
	end
	self:updateNameplate()

	-- Finish whatever is in progress.
	local state = self.state
	if state == "windup" then
		if now >= self.stateEnds then
			self:resolveAttack(now)
		end
		return
	elseif state == "recovery" then
		if now < self.stateEnds then
			return
		end
		self.state = "idle"
		if self.comboLeft > 0 and self.target and self.target:isAlive() and self.service.inRange(actor, self.target, Duelist.REACH + 1) then
			self.comboLeft -= 1
			local last = self.comboLeft == 0 and self.combos % Duelist.THRUST_EVERY == 0
			self:startAttack(if last then Duelist.THRUST else Duelist.SLASH, now)
			return
		end
		self.comboLeft = 0
		self.nextAttack = now + rng:NextNumber(Duelist.PAUSE[1], Duelist.PAUSE[2])
	elseif state == "block" or state == "stagger" or state == "roll" then
		if now < self.stateEnds then
			if state == "block" and self.target then
				self:faceTowards(self.target:position(), 0.3)
			end
			return
		end
		self:endAction()
		self.state = "idle"
	end

	local target = self:pickTarget()
	self.target = target
	local root = self.root
	local homeOffset = flat(self.home.Position - root.Position)

	if not target then
		-- Nobody to fight: walk back to the post, then heal up.
		if homeOffset.Magnitude > 2 then
			self.humanoid:MoveTo(self.home.Position)
			self:setMove("Walk W", Duelist.WALK_SPEED / 12)
		else
			self.humanoid:Move(Vector3.zero)
			self:setMove("Idle", 1)
			self:faceTowards((self.home * CFrame.new(0, 0, -10)).Position, 0.2)
			actor.health = actor.maxHealth
		end
		return
	end

	-- React to the target: roll away from a flurry, or block a swing it sees coming.
	local inReach = self.service.inRange(actor, target, Duelist.REACH)
	if #self.recentHits >= Duelist.ROLL_AFTER and now - self.lastRoll >= Duelist.ROLL_COOLDOWN then
		self:roll(now)
		return
	end
	local tl = target.timeline
	if inReach and tl.state == "windup" and self.seenWindup ~= tl.fireAt then
		self.seenWindup = tl.fireAt
		if rng:NextNumber() < Duelist.BLOCK_CHANCE then
			self.humanoid:Move(Vector3.zero)
			self:setMove("Idle", 1)
			self.state = "block"
			self.stateEnds = now + Duelist.BLOCK_TIME
			actor.blocking = true
			Animations.block(actor, true)
			return
		end
	end

	-- Close in, then attack.
	if not inReach then
		local toTarget = flat((target:position() :: Vector3) - root.Position)
		self.humanoid:MoveTo(root.Position + toTarget - toTarget.Unit * (Duelist.REACH - 1.5))
		self:setMove("Walk W", Duelist.WALK_SPEED / 12)
		return
	end
	self.humanoid:Move(Vector3.zero)
	self:setMove("Idle", 1)
	self:faceTowards(target:position(), 0.35)
	if now >= self.nextAttack then
		self.combos += 1
		self.comboLeft = rng:NextInteger(1, Duelist.COMBO_MAX) - 1
		local thrustNow = self.comboLeft == 0 and self.combos % Duelist.THRUST_EVERY == 0
		self:startAttack(if thrustNow then Duelist.THRUST else Duelist.SLASH, now)
	end
end

return Duelist
