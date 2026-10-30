-- The combat loop. Runs in fixed 50 ms ticks. Each tick, in order (GDD section 4):
--   incoming damage -> death checks -> resource regeneration -> actions whose wind-up ends fire -> new actions start
-- Client requests are queued and handled in the last step, so input never jumps the order.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Formulas = require(Shared.Formulas)
local Kits = require(Shared.Kits)
local Net = require(Shared.Net)
local Scaling = require(Shared.Scaling)

local Actor = require(script.Parent.Actor)
local Abilities = require(script.Parent.Abilities)
local Animations = require(script.Parent.Animations)

local CombatService = {}

CombatService.now = 0
CombatService.actors = {} :: { [number]: any }
CombatService.byPlayer = {} :: { [Player]: any }
CombatService.classOf = {} :: { [Player]: string }
CombatService.boss = nil
CombatService.dummy = nil
CombatService.meters = {} -- training dummy meters: actor id -> { first, last, total }

local queues = {} :: { [Player]: { any } }
local requestBudget = {} :: { [Player]: number }
local remotes = {}
local rng = Random.new()

local PLAYER_LEVEL = 50 -- [Proto] the arena runs at the tier 1 reference point
local PLAYER_ITEM_LEVEL = 65
local DUMMY_RESET = 6 -- seconds without hits before the dummy meter resets [Proto]
local COMBAT_TIMEOUT = 5 -- seconds after the last hit before you count as out of combat [Proto]

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function fmt(n: number): string
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

----------------------------------------------------------------------------------------------------
-- Messaging

function CombatService.fx(event)
	remotes.fx:FireAllClients(event)
end

function CombatService.log(actor, text: string)
	if actor and actor.player then
		remotes.fx:FireClient(actor.player, { t = "log", text = text })
	end
end

----------------------------------------------------------------------------------------------------
-- Queries

-- Measured to the edge of big models like the boss, not to their centre.
function CombatService.inRange(a, b, range: number): boolean
	local pa, pb = a:position(), b:position()
	return pa ~= nil and pb ~= nil and (pa - pb).Magnitude - (b.radius or 0) <= range
end

local function living(team: string?)
	local list = {}
	for _, actor in CombatService.actors do
		if actor:isAlive() and (team == nil or actor.team == team) then
			table.insert(list, actor)
		end
	end
	return list
end
CombatService.living = living

-- Soft lock-on: the closest enemy within range, preferring ones in front of you.
function CombatService.enemyInFront(actor, range: number)
	local pos = actor:position()
	if not pos then
		return nil
	end
	local look = flat(actor:lookVector()).Unit
	local best, bestScore = nil, math.huge
	for _, other in living() do
		if other.team ~= actor.team then
			local offset = flat((other:position() :: Vector3) - pos)
			local dist = offset.Magnitude
			-- Big models: measure to the edge, not the centre.
			local edge = math.max(0, dist - (other.radius or 1.5))
			if edge <= range then
				local facing = dist > 0.01 and look:Dot(offset.Unit) or 1
				local score = edge + (facing < 0 and 50 or 0)
				if score < bestScore then
					best, bestScore = other, score
				end
			end
		end
	end
	return best
end

function CombatService.enemiesInCone(actor, range: number, degrees: number)
	local pos = actor:position()
	local hit = {}
	if not pos then
		return hit
	end
	local look = flat(actor:lookVector()).Unit
	local minDot = math.cos(math.rad(degrees / 2))
	for _, other in living() do
		if other.team ~= actor.team then
			local offset = flat((other:position() :: Vector3) - pos)
			local edge = math.max(0, offset.Magnitude - (other.radius or 1.5))
			if edge <= range and (offset.Magnitude < 0.01 or look:Dot(offset.Unit) >= minDot) then
				table.insert(hit, other)
			end
		end
	end
	return hit
end

-- The ally with the lowest HP fraction in range. The healer's prototype targeting rule.
function CombatService.lowestAlly(actor, range: number, excludeSelf: boolean?)
	local best, bestFrac = nil, math.huge
	for _, other in living(actor.team) do
		if not (excludeSelf and other == actor) and other.kind == "player" and CombatService.inRange(actor, other, range) then
			local frac = other.health / other.maxHealth
			if frac < bestFrac then
				best, bestFrac = other, frac
			end
		end
	end
	return best
end

function CombatService.alliesNear(actor, radius: number, maxTargets: number)
	local list = {}
	for _, other in living(actor.team) do
		if other.kind == "player" and CombatService.inRange(actor, other, radius) then
			table.insert(list, other)
		end
	end
	-- Most hurt first, so a full circle heals the people who need it.
	table.sort(list, function(a, b)
		return a.health / a.maxHealth < b.health / b.maxHealth
	end)
	while #list > maxTargets do
		table.remove(list)
	end
	return list
end

----------------------------------------------------------------------------------------------------
-- Damage and healing

local function addThreat(enemy, source, amount: number)
	if enemy.threat and source.team ~= enemy.team then
		enemy.threat[source] = (enemy.threat[source] or 0) + amount
	end
end

local function meter(source, amount: number)
	local now = CombatService.now
	local m = CombatService.meters[source.id]
	if not m or now - m.last > DUMMY_RESET then
		m = { first = now, last = now, total = 0 }
		CombatService.meters[source.id] = m
	end
	m.last = now
	m.total += amount
end

-- Player damage onto an enemy. `amount` is coefficient * WD before crits and modifiers.
function CombatService.strike(source, target, amount: number, def, isTick: boolean?)
	local now = CombatService.now
	local mult, crit = 1, false
	if not isTick then -- DoT ticks never crit
		mult, crit = Formulas.rollCrit(source.stats.critChance, source.stats.critMult, rng:NextNumber())
	end
	local damage = amount * mult * Formulas.outgoingMultiplier(nil)
	damage *= 1 - Formulas.totalDR({ passive = target.enemyDR or 0 })

	source.lastCombat = now
	target.lastCombat = now

	if target.kind == "dummy" then
		meter(source, damage)
	else
		target.health = math.max(0, target.health - damage)
		local tankMult = source.isTank and Constants.TANK_THREAT_MULT or 1
		addThreat(target, source, damage * tankMult)
		if target.onDamaged then
			target:onDamaged(source, damage)
		end
	end

	local pos = target:position()
	CombatService.fx({
		t = "hit",
		src = source.id,
		dst = target.id,
		amount = damage,
		crit = crit,
		pos = pos,
		class = source.kit and source.kit.id,
	})
	CombatService.log(
		source,
		string.format("%s hit %s for %s%s", def.name, target.name, fmt(damage), crit and " (crit)" or "")
	)
end

function CombatService.applyDot(source, target, def, total: number)
	local now = CombatService.now
	local ticks = math.floor(def.duration)
	-- Reapplying replaces the remaining duration. It never stacks.
	target.dots[tostring(source.id) .. def.id] = {
		source = source,
		def = def,
		perTick = total / ticks,
		nextTick = now + 1,
		expires = now + def.duration + 1e-6,
	}
	CombatService.log(source, def.name .. " applied to " .. target.name)
end

function CombatService.heal(source, target, amount: number, def)
	local now = CombatService.now
	local mult, crit = Formulas.rollCrit(source.stats.critChance, Constants.HEAL_CRIT_MULT, rng:NextNumber())
	local raw = amount * mult * (1 + source.stats.healingPower)
	local effective, overheal = Formulas.clampHeal(raw, target.health, target.maxHealth)
	target.health += effective
	source.lastCombat = now

	-- Healing draws threat from any boss already fighting the healer's group.
	local boss = CombatService.boss
	if boss and boss.engaged and effective > 0 then
		addThreat(boss.actor, source, effective * Constants.HEAL_THREAT_MULT)
	end

	CombatService.fx({ t = "heal", src = source.id, dst = target.id, amount = effective, crit = crit, pos = target:position() })
	CombatService.log(
		source,
		string.format(
			"%s healed %s for %s%s%s",
			def.name,
			target == source and "you" or target.name,
			fmt(effective),
			overheal > 1 and (" (" .. fmt(overheal) .. " over)") or "",
			crit and " (crit)" or ""
		)
	)
end

function CombatService.interrupt(source, target)
	if target.onInterrupted then
		target:onInterrupted(source)
	end
end

function CombatService.intercept(warden, ally, def, now: number)
	local wp, ap = warden:root(), ally:root()
	if wp and ap then
		-- Dash: land just in front of the ally.
		local destination = ap.Position + ap.CFrame.LookVector * 3
		warden.model:PivotTo(CFrame.lookAt(destination, destination + ap.CFrame.LookVector))
	end
	ally.interceptBy = warden
	ally.interceptUntil = now + def.guardDuration
	CombatService.log(warden, "Intercept: guarding " .. ally.name)
	CombatService.log(ally, warden.name .. " is guarding you")
end

-- An enemy attack landing on a player. `written` is the hit size against light armor.
-- attack = { name, color = "white" | "orange" | "red", frontal = bool }
function CombatService.enemyHit(enemy, target, written: number, attack)
	local now = CombatService.now
	if target.dead then
		return
	end

	-- Intercept: the Warden takes the next hit, with only the Warden's own defenses.
	if target.interceptBy and now < target.interceptUntil and target.interceptBy:isAlive() then
		local warden = target.interceptBy
		target.interceptBy = nil
		CombatService.log(target, warden.name .. " intercepted " .. attack.name)
		target = warden
	end

	target.lastCombat = now
	enemy.lastCombat = now

	if target:isUntouchable(now) then
		CombatService.fx({ t = "avoid", dst = target.id, text = "Dodged", pos = target:position() })
		CombatService.log(target, "Dodged " .. attack.name)
		return
	end

	local ep, tp = enemy:position(), target:position()
	local facing = false
	if ep and tp then
		local toEnemy = flat(ep - tp)
		facing = toEnemy.Magnitude < 0.01 or flat(target:lookVector()).Unit:Dot(toEnemy.Unit) > 0.2
	end

	local blockDR = 0
	if target.blocking and facing and attack.color ~= "red" then
		if now - target.blockStart <= Constants.PARRY_WINDOW then
			CombatService.fx({ t = "avoid", dst = target.id, text = "Parry!", pos = tp })
			CombatService.log(target, "Parried " .. attack.name)
			Animations.parry(target)
			if enemy.onParried then
				enemy:onParried(target)
			end
			return
		end
		if attack.color == "white" then
			if target.stamina >= Constants.STAMINA_PER_BLOCK then
				target.stamina -= Constants.STAMINA_PER_BLOCK
				blockDR = Constants.BLOCK_DR
				local onBlock = target.kit and target.kit.onBlock
				if onBlock then
					target:gainResource(onBlock.grit)
					target.bulwark = math.min(target.kit.signature.max, target.bulwark + onBlock.bulwark)
				end
			else
				target.stamina = 0
				CombatService.log(target, "Guard broken: out of Stamina")
			end
		else
			CombatService.log(target, attack.name .. " is orange: block does nothing, dodge or parry")
		end
	end

	local referenceDR = Formulas.totalDR({ passive = target.referenceDR })
	local raw = Formulas.rawFromWritten(written, referenceDR) * (enemy.damageScale or 1)
	local dr = Formulas.totalDR({ passive = target.passiveDR, block = blockDR })
	local damage = raw * (1 - dr)
	local toHealth
	toHealth, target.shield = Formulas.absorb(damage, target.shield)
	target.health = math.max(0, target.health - toHealth)

	CombatService.fx({ t = "hurt", dst = target.id, amount = toHealth, pos = tp, blocked = blockDR > 0 })
	CombatService.log(
		target,
		string.format("%s hit you for %s%s", attack.name, fmt(toHealth), blockDR > 0 and " (blocked)" or "")
	)
end

----------------------------------------------------------------------------------------------------
-- Players

local function spawnActor(player: Player, character: Model)
	local className = CombatService.classOf[player] or "Assassin"
	local kit = Kits[className]
	local actor = Actor.new({
		kind = "player",
		name = player.DisplayName,
		team = "players",
		model = character,
		player = player,
		level = PLAYER_LEVEL,
		itemLevel = PLAYER_ITEM_LEVEL,
		kit = kit,
	})
	-- Enemy hits are written against light armor; this converts them for heavier armor.
	actor.referenceDR = Scaling.armorDR(Scaling.armorRating(Constants.REFERENCE_ARMOR, actor.level), actor.level)

	local old = CombatService.byPlayer[player]
	if old then
		CombatService.actors[old.id] = nil
	end
	CombatService.byPlayer[player] = actor
	CombatService.actors[actor.id] = actor

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = actor.maxHealth
	humanoid.Health = actor.maxHealth
	humanoid.Died:Connect(function()
		actor.dead = true
		actor.health = 0
	end)
	CombatService.log(actor, "You are " .. className .. ". Press 1, 2 or 3 out of combat to switch class.")
end

function CombatService.setClass(actor, className: string)
	local kit = Kits[className]
	if not kit then
		return
	end
	if CombatService.now - actor.lastCombat < COMBAT_TIMEOUT then
		CombatService.log(actor, "Cannot switch class in combat")
		return
	end
	CombatService.classOf[actor.player] = className
	actor:applyKit(kit)
	CombatService.log(actor, "Switched to " .. className)
end

----------------------------------------------------------------------------------------------------
-- Requests

local R = Net.Request

local function handleRequest(actor, req)
	local now = CombatService.now
	local kind = req.kind
	local kit = actor.kit
	if kind == R.CLASS then
		CombatService.setClass(actor, req.class)
		return
	end
	if actor.dead then
		return
	end

	if kind == R.DODGE then
		if now - actor.lastDodge < Constants.DODGE_COOLDOWN then
			return
		end
		if actor.timeline.state == "recovery" then
			return -- recovery commits you
		end
		actor.timeline:cancel()
		actor.blocking = false
		Animations.cancel(actor)
		actor.lastDodge = now
		actor.dodgeUntil = now + Constants.DODGE_INVULN
	elseif kind == R.BLOCK_START then
		if actor.timeline.state == "recovery" then
			return
		end
		actor.timeline:cancel()
		actor.blocking = true
		actor.blockStart = now
		Animations.block(actor, true)
	elseif kind == R.BLOCK_END then
		actor.blocking = false
		Animations.block(actor, false)
	elseif kind == R.BASIC then
		local ok, why = Abilities.tryStart(CombatService, actor, kit.basic, now)
		if not ok and why ~= "busy" then
			CombatService.log(actor, kit.basic.name .. ": " .. tostring(why))
		end
	elseif kind == R.HEAVY then
		-- Kits without a heavy attack fall back to the basic attack.
		local def = kit.heavy or kit.basic
		local ok, why = Abilities.tryStart(CombatService, actor, def, now)
		if not ok and why ~= "busy" then
			CombatService.log(actor, def.name .. ": " .. tostring(why))
		end
	elseif kind == R.SKILL then
		local def = typeof(req.slot) == "number" and kit.skills[req.slot] or nil
		if not def then
			return
		end
		local ok, why = Abilities.tryStart(CombatService, actor, def, now)
		if not ok then
			CombatService.log(actor, def.name .. ": " .. tostring(why))
		end
	elseif kind == R.SIGNATURE then
		local def = kit.signatureAction
		if not def then
			CombatService.log(actor, kit.id .. " has no signature key in this prototype")
			return
		end
		local ok, why = Abilities.tryStart(CombatService, actor, def, now)
		if not ok then
			CombatService.log(actor, def.name .. ": " .. tostring(why))
		end
	elseif kind == R.ULTIMATE then
		CombatService.log(actor, "Ultimates are not in the first prototype")
	end
end

----------------------------------------------------------------------------------------------------
-- Tick

local function tick()
	CombatService.now += Constants.TICK
	local now = CombatService.now
	local dt = Constants.TICK

	-- 1. Incoming damage: enemy AI, then damage over time.
	if CombatService.boss then
		CombatService.boss:step(now)
	end
	for _, actor in CombatService.actors do
		for key, dot in actor.dots do
			if now >= dot.nextTick - 1e-6 then
				if actor:isAlive() and dot.source.player then
					CombatService.strike(dot.source, actor, dot.perTick, dot.def, true)
				end
				dot.nextTick += 1
			end
			if now >= dot.expires then
				actor.dots[key] = nil
			end
		end
	end

	-- 2. Death checks.
	for _, actor in CombatService.actors do
		if actor.kind == "player" and not actor.dead and actor.health <= 0 then
			actor.dead = true
			actor.timeline:cancel()
			actor.blocking = false
			Animations.cancel(actor)
			local humanoid = actor:humanoid()
			if humanoid then
				humanoid.Health = 0
			end
			CombatService.log(actor, "You died. You respawn in a few seconds.")
		end
	end

	-- 3. Resource regeneration.
	for _, actor in CombatService.actors do
		if actor.kind == "player" and not actor.dead then
			if actor.resourceRegen > 0 then
				actor:gainResource(actor.resourceRegen * (1 + actor.stats.regeneration) * dt)
			end
			if not actor.blocking then
				actor.stamina = math.min(Constants.STAMINA_POOL, actor.stamina + Constants.STAMINA_REGEN * dt)
			end
			if actor.interceptBy and now >= actor.interceptUntil then
				actor.interceptBy = nil
			end
		end
	end

	-- 4. Actions whose wind-up ends this tick fire.
	for _, actor in CombatService.actors do
		if actor.kind == "player" and not actor.dead then
			local def, payload = actor.timeline:step(now)
			if def then
				Abilities.fire(CombatService, actor, def, payload, now)
			end
		end
	end

	-- 5. New actions start.
	for player, queue in queues do
		local actor = CombatService.byPlayer[player]
		if actor then
			for _, req in queue do
				handleRequest(actor, req)
			end
		end
		table.clear(queue)
	end

	-- Mirror HP onto Humanoids so Roblox's own UI and respawn agree with combat.
	for _, actor in CombatService.actors do
		if actor.kind == "player" and not actor.dead then
			local humanoid = actor:humanoid()
			if humanoid then
				humanoid.MaxHealth = actor.maxHealth
				humanoid.Health = math.max(actor.health, 0.01)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Snapshots for the HUD

local function snapshotFor(actor)
	local now = CombatService.now
	local kit = actor.kit
	local cds = {}
	local function slot(key, def)
		if def then
			cds[key] = { name = def.name, left = actor:cooldownLeft(def.id, now), cost = def.cost }
		end
	end
	for i, def in kit.skills do
		slot(({ "Q", "E", "R" })[i], def)
	end
	slot("T", kit.signatureAction)

	local snap = {
		self = {
			id = actor.id,
			class = kit.id,
			hp = actor.health,
			maxHp = actor.maxHealth,
			shield = actor.shield,
			res = actor.resource,
			resPool = actor.resourcePool,
			resName = actor.resourceName,
			stamina = actor.stamina,
			combo = kit.signature and kit.signature.name == "Combo" and actor.combo or nil,
			bulwark = kit.signature and kit.signature.name == "Bulwark" and actor.bulwark or nil,
			state = actor.timeline.state,
			action = actor.timeline.action and actor.timeline.action.name or nil,
			busy = actor.timeline:busyFor(now),
			blocking = actor.blocking,
			dead = actor.dead,
			cds = cds,
			wd = actor.wd,
		},
	}

	local boss = CombatService.boss
	if boss then
		snap.boss = boss:snapshot(now)
	end

	local m = CombatService.meters[actor.id]
	if m and now - m.last <= DUMMY_RESET then
		local duration = math.max(1, m.last - m.first)
		snap.dummy = { total = m.total, duration = duration, dps = m.total / duration, wdps = m.total / duration / actor.wd }
	end
	return snap
end

----------------------------------------------------------------------------------------------------
-- Setup

function CombatService.addEnemy(actor)
	CombatService.actors[actor.id] = actor
end

function CombatService.start()
	local folder = Instance.new("Folder")
	folder.Name = Net.FOLDER
	local function remote(name: string): RemoteEvent
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		return r
	end
	remotes.action = remote(Net.ACTION)
	remotes.state = remote(Net.STATE)
	remotes.fx = remote(Net.FX)
	folder.Parent = ReplicatedStorage

	remotes.action.OnServerEvent:Connect(function(player: Player, req)
		if typeof(req) ~= "table" or typeof(req.kind) ~= "string" then
			return
		end
		local budget = requestBudget[player] or 0
		if budget >= Net.MAX_REQUESTS_PER_SECOND then
			return
		end
		requestBudget[player] = budget + 1
		local queue = queues[player]
		if queue then
			table.insert(queue, { kind = req.kind, slot = req.slot, class = req.class })
		end
	end)

	local function onPlayer(player: Player)
		queues[player] = {}
		player.CharacterAdded:Connect(function(character)
			spawnActor(player, character)
		end)
		if player.Character then
			spawnActor(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local actor = CombatService.byPlayer[player]
		if actor then
			CombatService.actors[actor.id] = nil
		end
		CombatService.byPlayer[player] = nil
		CombatService.classOf[player] = nil
		queues[player] = nil
		requestBudget[player] = nil
	end)

	local accumulator = 0
	local sinceSnapshot = 0
	local sinceBudget = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += math.min(dt, 0.25) -- never try to catch up more than 5 ticks after a hitch
		while accumulator >= Constants.TICK do
			accumulator -= Constants.TICK
			tick()
		end

		sinceBudget += dt
		if sinceBudget >= 1 then
			sinceBudget = 0
			table.clear(requestBudget)
		end

		sinceSnapshot += dt
		if sinceSnapshot >= Net.SNAPSHOT_RATE then
			sinceSnapshot = 0
			for player, actor in CombatService.byPlayer do
				remotes.state:FireClient(player, snapshotFor(actor))
			end
		end
	end)
end

return CombatService
