-- Server-side combat state for anything that fights: players, the boss and the training dummy.
-- HP lives here, not on the Humanoid. The Humanoid only mirrors it for Roblox's own UI and respawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Scaling = require(Shared.Scaling)
local StatCurve = require(Shared.StatCurve)
local Timeline = require(Shared.Timeline)
local Constants = require(Shared.Constants)

local Actor = {}
Actor.__index = Actor

local nextId = 0

export type Options = {
	kind: string, -- "player" | "boss" | "dummy"
	name: string,
	team: string, -- "players" | "enemies"
	model: Model,
	level: number,
	itemLevel: number,
	armorType: string?,
	maxHealth: number?, -- overrides the class formula (boss, dummy)
	kit: any?,
	ratings: { [string]: number }?,
	player: Player?,
}

function Actor.new(opts: Options)
	nextId += 1
	local self = setmetatable({}, Actor)
	self.id = nextId
	self.kind = opts.kind
	self.name = opts.name
	self.team = opts.team
	self.model = opts.model
	self.player = opts.player
	self.level = opts.level
	self.itemLevel = opts.itemLevel
	self.ratings = opts.ratings or {}

	self.cooldowns = {} -- ability id -> time it is ready
	self.timeline = Timeline.new()
	self.blocking = false
	self.blockStart = 0
	self.dodgeUntil = 0
	self.lastDodge = -math.huge
	self.untargetableUntil = 0
	self.shield = 0
	self.dots = {} -- source id .. ability id -> { source, perTick, nextTick, expires, name }
	self.markedBy = {} -- source id -> expiry time
	self.interceptBy = nil -- Warden actor guarding this one
	self.interceptUntil = 0
	self.dead = false
	self.lastCombat = -math.huge

	self:applyKit(opts.kit, opts.armorType, opts.maxHealth)
	return self
end

-- (Re)builds stats, HP and resources. Used on spawn and on class switch.
function Actor:applyKit(kit, armorType: string?, maxHealth: number?)
	self.kit = kit
	self.armorType = armorType or (kit and kit.armor) or "light"
	self.isTank = kit ~= nil and kit.isTank == true
	self.stats = StatCurve.derive(self.ratings, self.level)
	self.wd = Scaling.weaponDamage(self.level, self.itemLevel)

	local roleBonus = self.isTank and Scaling.TANK_HP_BONUS or 0
	local hp = maxHealth or Scaling.maxHealth(self.armorType, self.level, self.itemLevel, roleBonus)
	self.maxHealth = hp * (1 + self.stats.vitality)
	self.health = self.maxHealth
	self.passiveDR = Scaling.armorDR(Scaling.armorRating(self.armorType, self.level), self.level)

	if kit then
		self.resourceName = kit.resource.name
		self.resourcePool = kit.resource.pool
		self.resourceRegen = kit.resource.regen
		self.resource = kit.resource.start
	else
		self.resourceName = nil
		self.resourcePool = 0
		self.resourceRegen = 0
		self.resource = 0
	end
	self.stamina = Constants.STAMINA_POOL
	self.combo = 0
	self.bulwark = 0
	self.shield = 0
	self.cooldowns = {}
	self.timeline = Timeline.new()
	self.blocking = false
	self.dead = false
end

-- New gear: rebuilds stats, WD and max HP from the equipped ratings and item level, keeping the HP fraction.
-- Unlike applyKit, it leaves resources, cooldowns and the timeline alone.
function Actor:refreshGear(ratings: { [string]: number }, itemLevel: number)
	local fraction = self.maxHealth > 0 and self.health / self.maxHealth or 1
	self.ratings = ratings
	self.itemLevel = itemLevel
	self.stats = StatCurve.derive(self.ratings, self.level)
	self.wd = Scaling.weaponDamage(self.level, self.itemLevel)
	local roleBonus = self.isTank and Scaling.TANK_HP_BONUS or 0
	self.maxHealth = Scaling.maxHealth(self.armorType, self.level, self.itemLevel, roleBonus) * (1 + self.stats.vitality)
	self.health = self.maxHealth * fraction
end

function Actor:root(): BasePart?
	local model = self.model
	if not model or not model.Parent then
		return nil
	end
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Actor:position(): Vector3?
	local root = self:root()
	return root and root.Position
end

function Actor:lookVector(): Vector3
	local root = self:root()
	return root and root.CFrame.LookVector or Vector3.zAxis
end

function Actor:humanoid(): Humanoid?
	return self.model and self.model:FindFirstChildOfClass("Humanoid")
end

function Actor:isAlive(): boolean
	return not self.dead and self:root() ~= nil
end

-- Dodge invulnerability or Smoke Step.
function Actor:isUntouchable(now: number): boolean
	return now < self.dodgeUntil or now < self.untargetableUntil
end

function Actor:isMarkedBy(source, now: number): boolean
	local expiry = self.markedBy[source.id]
	return expiry ~= nil and expiry > now
end

function Actor:cooldownLeft(abilityId: string, now: number): number
	local ready = self.cooldowns[abilityId]
	return ready and math.max(0, ready - now) or 0
end

function Actor:gainResource(amount: number)
	if self.resourcePool > 0 then
		self.resource = math.clamp(self.resource + amount, 0, self.resourcePool)
	end
end

return Actor
