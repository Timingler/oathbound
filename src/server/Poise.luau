-- Poise: how enemies take hits without being stun-locked by a group.
--
-- Hits from players drain an enemy's poise instead of flinching it. Only when poise runs out is it staggered:
-- its swing is cancelled and it flinches. Then it is stagger immune for a while, so a group piling on cannot keep
-- it helpless; their hits still deal full damage, they just stop interrupting it. Poise refills after a short
-- break from being hit.
-- Hyper armor: during some wind-ups (actor.armoredUntil) hits do not drain poise at all, so those attacks always
-- come out. The boss has hyper armor all the time (actor.hyperArmor): only its Break meter stops it.
-- Actors without poiseMax (players) keep the plain flinch from server/Animations.

local Animations = require(script.Parent.Animations)

local Poise = {}

-- [Proto] values, not in the design docs.
Poise.LIGHT = 10 -- poise damage of a quick hit
Poise.HEAVY = 25 -- an attack with a wind-up of HEAVY_WINDUP or more
Poise.HEAVY_WINDUP = 0.6
Poise.CRIT_MULT = 1.5
Poise.REFILL_AFTER = 2.5 -- seconds without a hit before poise is full again
Poise.IMMUNE = 5 -- seconds of stagger immunity after a stagger

function Poise.uses(actor): boolean
	return actor.poiseMax ~= nil or actor.hyperArmor == true
end

function Poise.armored(actor, now: number): boolean
	return actor.hyperArmor == true or now < (actor.armoredUntil or 0)
end

-- A player's hit (not a DoT tick) landed on `target`. Returns true if it staggered it.
function Poise.hit(target, source, def, crit: boolean, now: number): boolean
	if not target.poiseMax or Poise.armored(target, now) or now < (target.staggerImmuneUntil or 0) then
		return false
	end
	if now - (target.lastPoiseHit or -math.huge) > Poise.REFILL_AFTER then
		target.poise = target.poiseMax
	end
	target.lastPoiseHit = now
	local amount = def.poise or (if (def.windup or 0) >= Poise.HEAVY_WINDUP then Poise.HEAVY else Poise.LIGHT)
	if crit then
		amount *= Poise.CRIT_MULT
	end
	target.poise = (target.poise or target.poiseMax) - amount
	if target.poise > 0 then
		return false
	end
	target.poise = target.poiseMax
	target.staggerImmuneUntil = now + (target.staggerTime or 0) + Poise.IMMUNE
	if target.onPoiseBreak then
		target:onPoiseBreak(source) -- cancels its action
	end
	Animations.hurt(target)
	return true
end

return Poise
