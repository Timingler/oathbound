-- Starts and fires abilities from the kit tables. The server checks everything; the client only asks.
-- `service` is CombatService, passed in to avoid a require cycle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Animations = require(script.Parent.Animations)

local Abilities = {}

local RANGE_TOLERANCE = 4 -- studs of slack for latency [Proto]

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- True if `attacker` stands behind `target` (outside the target's front 180 degrees).
function Abilities.isBehind(attacker, target): boolean
	local a, t = attacker:position(), target:position()
	if not a or not t then
		return false
	end
	local toAttacker = flat(a - t)
	if toAttacker.Magnitude < 0.01 then
		return false
	end
	return flat(target:lookVector()).Unit:Dot(toAttacker.Unit) < 0
end

local function pickTarget(service, actor, def)
	if def.targeting == "lowestAlly" then
		return service.lowestAlly(actor, def.range, false)
	elseif def.targeting == "otherAlly" then
		return service.lowestAlly(actor, def.range, true)
	end
	if def.range then
		return service.enemyInFront(actor, def.range + RANGE_TOLERANCE)
	end
	return nil
end

-- Returns (ok, reason). On success the action is on the timeline, or applied at once if instant.
function Abilities.tryStart(service, actor, def, now: number): (boolean, string?)
	if not def then
		return false, "nothing bound"
	end
	if actor.dead then
		return false, "dead"
	end

	if def.instant then
		return Abilities.tryInstant(service, actor, def, now)
	end

	if actor.blocking then
		return false, "blocking"
	end
	if not actor.timeline:isIdle() then
		return false, "busy"
	end
	if actor:cooldownLeft(def.id, now) > 0 then
		return false, "cooldown"
	end
	local cost = def.cost and Formulas.cost(def.cost, actor.stats.efficiency) or 0
	if actor.resource < cost - 1e-6 then
		return false, "not enough " .. tostring(actor.resourceName)
	end
	if def.requiresCombo and actor.combo < def.requiresCombo then
		return false, "needs " .. def.requiresCombo .. " combo points"
	end
	if def.bulwarkCost and actor.bulwark < def.bulwarkCost then
		return false, "needs " .. def.bulwarkCost .. " Bulwark"
	end

	local target = pickTarget(service, actor, def)
	if def.effect == "strike" or def.effect == "smite" or def.effect == "finisher" or def.effect == "dot" then
		-- A basic attack swings even with nobody in reach, so a click always does something. It whiffs at fire time.
		if not target and def ~= actor.kit.basic then
			return false, "no target in range"
		end
	elseif def.effect == "heal" or def.effect == "intercept" then
		if not target then
			return false, "no ally in range"
		end
	end
	if def.requiresMark and not target:isMarkedBy(actor, now) then
		return false, "target not Marked"
	end

	actor.timeline:start(def, now, actor.stats.actionSpeed, { target = target })
	Animations.action(actor, def, now)
	service.fx({
		t = "swing",
		src = actor.id,
		class = actor.kit and actor.kit.id,
		ability = def.id,
		pos = actor:position(),
	})
	return true
end

function Abilities.tryInstant(service, actor, def, now: number): (boolean, string?)
	if actor:cooldownLeft(def.id, now) > 0 then
		return false, "cooldown"
	end
	if def.effect == "smokeStep" then
		local window = def.useWindow or 0
		if now > actor.dodgeUntil + window then
			return false, "use during a dodge"
		end
		actor.untargetableUntil = now + def.untargetable
		Abilities.startCooldown(actor, def, now)
		service.log(actor, def.name .. ": untargetable for " .. def.untargetable .. " s")
		return true
	end
	return false, "unknown instant"
end

function Abilities.startCooldown(actor, def, now: number)
	if def.cooldown then
		actor.cooldowns[def.id] = now + Formulas.cooldown(def.cooldown, actor.stats.abilityHaste, def.hasteTag or 1)
	end
end

-- Called on the tick the wind-up ends.
function Abilities.fire(service, actor, def, payload, now: number)
	if def.cost then
		actor:gainResource(-Formulas.cost(def.cost, actor.stats.efficiency))
	end
	Abilities.startCooldown(actor, def, now)

	local target = payload and payload.target
	-- The target may have moved or died during the wind-up. Re-check range at fire time.
	if target and (not target:isAlive() or not service.inRange(actor, target, (def.range or 0) + RANGE_TOLERANCE)) then
		target = def.targeting and pickTarget(service, actor, def) or nil
	end

	local wd = actor.wd
	local effect = def.effect

	if effect == "strike" then
		if def.gain then
			actor:gainResource(def.gain)
		end
		if not target then
			if def ~= actor.kit.basic then
				service.log(actor, def.name .. " missed")
			end
			return
		end
		local coeff = def.coeff
		if def.frontPenalty and not Abilities.isBehind(actor, target) then
			coeff *= def.frontPenalty
		end
		service.strike(actor, target, coeff * wd, def)
		if def.combo and actor.kit.signature then
			actor.combo = math.min(actor.kit.signature.max, actor.combo + def.combo)
		end
		if def.applyMark then
			target.markedBy[actor.id] = now + (actor.kit.markDuration or 10)
		end
		if def.interrupts then
			service.interrupt(actor, target)
		end
	elseif effect == "smite" then
		if def.gain then
			actor:gainResource(def.gain)
		end
		if target then
			service.strike(actor, target, def.coeff * wd, def)
		end
		local ally = service.lowestAlly(actor, def.healRange, false)
		if ally and ally.health < ally.maxHealth then
			service.heal(actor, ally, def.healCoeff * wd, def)
		end
	elseif effect == "finisher" then
		local points = actor.combo
		actor.combo = 0
		if not target then
			service.log(actor, def.name .. " missed")
			return
		end
		service.strike(actor, target, def.coeffPerPoint * points * wd, def)
	elseif effect == "dot" then
		if not target then
			service.log(actor, def.name .. " missed")
			return
		end
		service.applyDot(actor, target, def, def.dotCoeff * wd)
	elseif effect == "cleave" then
		local hit = service.enemiesInCone(actor, def.range + RANGE_TOLERANCE, def.coneDegrees)
		for _, enemy in hit do
			service.strike(actor, enemy, def.coeff * wd, def)
		end
		if #hit == 0 then
			service.log(actor, def.name .. " hit nothing")
		end
	elseif effect == "heal" then
		if def.gain then
			actor:gainResource(def.gain)
		end
		if target then
			service.heal(actor, target, def.coeff * wd, def)
		end
	elseif effect == "areaHeal" then
		local allies = service.alliesNear(actor, def.radius, def.maxTargets)
		service.fx({ t = "sanctuary", src = actor.id, pos = actor:position(), radius = def.radius })
		for _, ally in allies do
			service.heal(actor, ally, def.coeff * wd, def)
		end
	elseif effect == "intercept" then
		actor.bulwark -= def.bulwarkCost
		if target then
			service.intercept(actor, target, def, now)
		end
	end
end

return Abilities
