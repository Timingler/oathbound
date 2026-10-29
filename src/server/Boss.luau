-- The prototype test boss. Its pattern combines encounters E4 (interrupts) and E6 (tank) from the
-- Build System Review audit, section 5.3. Hit sizes are written against light armor, as the GDD asks.
--
--   Heavy Swing     white   8,000 on the top-threat target's cone, every 2 s   (block, dodge or parry)
--   Sundering Blow  orange  20,000 tank-buster, every 20 s                      (dodge or parry; block fails)
--   Ash Sweep       red     6,000 to everyone in a circle, every 15 s           (dodge or move out)
--   Doom Chant      cast    2 s, every 40 s; 40% of medium HP to everyone unless interrupted
--
-- Break meter (GDD section 4): parries and interrupts fill it. When full the boss is Broken for 3 s,
-- its current cast is cancelled, and the meter locks for 25 s.
--
-- Set the "DamageScale" attribute on the boss model while playing to make it easier for solo tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Scaling = require(Shared.Scaling)

local Boss = {}
Boss.__index = Boss

local MEDIUM_HP = Scaling.maxHealth("medium", 50, 65)

Boss.ATTACKS = {
	swing = { name = "Heavy Swing", color = "white", written = 8000, telegraph = 0.8, every = 2, shape = "cone", range = 14, degrees = 100 },
	buster = { name = "Sundering Blow", color = "orange", written = 20000, telegraph = 1.2, every = 20, shape = "cone", range = 14, degrees = 100 },
	sweep = { name = "Ash Sweep", color = "red", written = 6000, telegraph = 1.5, every = 15, shape = "circle", radius = 18 },
}
Boss.CAST = { name = "Doom Chant", duration = 2.0, every = 40, written = 0.40 * MEDIUM_HP }

-- [Proto] values below are not in the design docs.
Boss.MAX_HEALTH = 600000 -- dungeon boss time to kill 2 to 4 min [A] at about 4 x WD per damage dealer
Boss.BREAK_MAX = 100
Boss.BREAK_PARRY = 15
Boss.BREAK_INTERRUPT = 30
Boss.MOVE_SPEED = 12 -- studs per second
Boss.MELEE_REACH = 9 -- stops this far from its target
Boss.AGGRO_RANGE = 45
Boss.LEASH_RANGE = 90
Boss.RESET_AFTER = 8 -- seconds with nobody in range
Boss.ENRAGE_AT = 600 -- seconds (10 min enrage [A])
Boss.ENRAGE_MULT = 2

local COLORS = {
	white = Color3.fromRGB(235, 235, 235),
	orange = Color3.fromRGB(255, 140, 30),
	red = Color3.fromRGB(230, 40, 40),
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Boss.new(service, actor, home: CFrame)
	local self = setmetatable({}, Boss)
	self.service = service
	self.actor = actor
	self.home = home
	actor.threat = {}
	actor.radius = 4
	actor.enemyDR = 0 -- [Proto]

	actor.onDamaged = function(_, source)
		self:engage(source)
	end
	actor.onParried = function(_, _parrier)
		self:addBreak(Boss.BREAK_PARRY)
	end
	actor.onInterrupted = function(_, source)
		self:interrupt(source)
	end

	self:reset()
	return self
end

function Boss:reset()
	local actor = self.actor
	actor.health = Boss.MAX_HEALTH
	actor.maxHealth = Boss.MAX_HEALTH
	actor.dead = false
	table.clear(actor.threat)
	table.clear(actor.dots)
	self.engaged = false
	self.engagedAt = 0
	self.lastSeen = 0
	self.telegraph = nil
	self.cast = nil
	self.brokenUntil = 0
	self.breakLockedUntil = 0
	self.breakMeter = 0
	self.interruptLockUntil = 0
	self.facing = nil
	if actor.model then
		actor.model:PivotTo(self.home)
	end
end

function Boss:engage(source)
	local now = self.service.now
	if not self.engaged and self.actor.health > 0 then
		self.engaged = true
		self.engagedAt = now
		self.next = {
			swing = now + 2,
			buster = now + 20,
			sweep = now + 15,
			cast = now + 40,
		}
		self.service.log(source, "The Ashen Sentinel engages")
	end
	self.lastSeen = now
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
		self:clearTelegraph()
		self.cast = nil
		self.service.fx({ t = "broken", dst = self.actor.id })
	end
end

function Boss:interrupt(source)
	local now = self.service.now
	local cast = self.cast
	if not cast then
		return
	end
	if now < self.interruptLockUntil then
		self.service.log(source, Boss.CAST.name .. " cannot be interrupted again yet")
		return
	end
	self.cast = nil
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

function Boss:clearTelegraph()
	if self.telegraph and self.telegraph.part then
		self.telegraph.part:Destroy()
	end
	self.telegraph = nil
end

local function drawTelegraph(attack, origin: CFrame): BasePart
	local part = Instance.new("Part")
	part.Name = "Telegraph"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = COLORS[attack.color]
	part.Transparency = 0.55
	local ground = origin.Position - Vector3.new(0, origin.Position.Y - 0.6, 0)
	if attack.shape == "circle" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.2, attack.radius * 2, attack.radius * 2)
		part.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
	else
		local width = 2 * attack.range * math.sin(math.rad(attack.degrees / 2))
		part.Size = Vector3.new(width, 0.2, attack.range)
		local look = flat(origin.LookVector).Unit
		local centre = ground + look * (attack.range / 2 + 2)
		part.CFrame = CFrame.lookAt(centre, centre + look)
	end
	part.Parent = workspace
	return part
end

function Boss:startTelegraph(key: string, now: number)
	local attack = Boss.ATTACKS[key]
	local origin = (self.actor:root() :: BasePart).CFrame
	self.telegraph = {
		key = key,
		attack = attack,
		fireAt = now + attack.telegraph,
		origin = origin, -- facing locks when the wind-up starts, so the cone can be read
		part = drawTelegraph(attack, origin),
	}
end

function Boss:resolveTelegraph(now: number)
	local tele = self.telegraph
	self:clearTelegraph()
	local attack = tele.attack
	local origin = tele.origin
	local mult = (self.actor.model:GetAttribute("DamageScale") or 1)
	if now - self.engagedAt >= Boss.ENRAGE_AT then
		mult *= Boss.ENRAGE_MULT
	end
	self.actor.damageScale = mult

	local look = flat(origin.LookVector).Unit
	local minDot = attack.degrees and math.cos(math.rad(attack.degrees / 2)) or -1
	for _, target in self.service.living("players") do
		local offset = flat((target:position() :: Vector3) - origin.Position)
		local dist = offset.Magnitude
		local hit
		if attack.shape == "circle" then
			hit = dist <= attack.radius + 1.5
		else
			hit = dist <= attack.range + 3.5 and (dist < 0.01 or look:Dot(offset.Unit) >= minDot)
		end
		if hit then
			self.service.enemyHit(self.actor, target, attack.written, attack)
		end
	end
end

function Boss:resolveCast(now: number)
	self.cast = nil
	local mult = (self.actor.model:GetAttribute("DamageScale") or 1)
	if now - self.engagedAt >= Boss.ENRAGE_AT then
		mult *= Boss.ENRAGE_MULT
	end
	self.actor.damageScale = mult
	local attack = { name = Boss.CAST.name, color = "red" }
	for _, target in self.service.living("players") do
		if self.service.inRange(self.actor, target, Boss.LEASH_RANGE) then
			self.service.enemyHit(self.actor, target, Boss.CAST.written, attack)
		end
	end
end

function Boss:step(now: number)
	local actor = self.actor
	local root = actor:root()
	if not root then
		return
	end

	if actor.health <= 0 then
		if self.engaged then
			self.service.fx({ t = "bossDead", dst = actor.id })
			self:clearTelegraph()
			self.cast = nil
			self.engaged = false
			actor.dead = true
			self.respawnAt = now + 15
		end
		if self.respawnAt and now >= self.respawnAt then
			self.respawnAt = nil
			self:reset()
		end
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
		self:clearTelegraph()
		self:reset()
		return
	end

	if now < self.brokenUntil then
		return
	end

	-- Resolve whatever is in progress.
	if self.telegraph then
		if now >= self.telegraph.fireAt then
			self:resolveTelegraph(now)
		end
		return
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
	local pos = root.Position
	local tpos = target:position() :: Vector3
	local offset = flat(tpos - pos)
	local dist = offset.Magnitude
	if dist > 0.01 then
		local dir = offset.Unit
		local step = math.min(Boss.MOVE_SPEED * Constants.TICK, math.max(0, dist - Boss.MELEE_REACH))
		local newPos = pos + dir * step
		actor.model:PivotTo(CFrame.lookAt(newPos, newPos + dir))
	end

	-- Start the next attack. Priority: cast, buster, sweep, swing. Anything due waits for its turn.
	local due = self.next
	if now >= due.cast then
		due.cast = now + Boss.CAST.every
		self.cast = { startedAt = now, endsAt = now + Boss.CAST.duration }
		self.service.fx({ t = "cast", dst = actor.id, name = Boss.CAST.name, duration = Boss.CAST.duration })
	elseif now >= due.buster then
		due.buster = now + Boss.ATTACKS.buster.every
		self:startTelegraph("buster", now)
	elseif now >= due.sweep then
		due.sweep = now + Boss.ATTACKS.sweep.every
		self:startTelegraph("sweep", now)
	elseif now >= due.swing and dist <= Boss.ATTACKS.swing.range + 2 then
		due.swing = now + Boss.ATTACKS.swing.every
		self:startTelegraph("swing", now)
	end
end

function Boss:snapshot(now: number)
	local actor = self.actor
	local tele = self.telegraph
	local cast = self.cast
	return {
		id = actor.id,
		name = actor.name,
		hp = actor.health,
		maxHp = actor.maxHealth,
		engaged = self.engaged,
		breakMeter = self.breakMeter,
		breakMax = Boss.BREAK_MAX,
		breakLocked = now < self.breakLockedUntil,
		broken = now < self.brokenUntil,
		telegraph = tele and { name = tele.attack.name, color = tele.attack.color, left = math.max(0, tele.fireAt - now) } or nil,
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
