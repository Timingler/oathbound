-- Pure combat math from Oathbound GDD v2, section 4. No Roblox APIs, so tests can run it outside Studio.

local Constants = require(script.Parent.Constants)

local Formulas = {}

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

-- Action Speed is capped at 30% and quantized to 5% steps so the server can validate action counts.
function Formulas.quantizeActionSpeed(actionSpeed: number): number
	local capped = clamp(actionSpeed, 0, Constants.ACTION_SPEED_CAP)
	-- small epsilon so 0.15 stays 0.15 despite float error
	return math.floor(capped / Constants.ACTION_SPEED_STEP + 1e-9) * Constants.ACTION_SPEED_STEP
end

-- Wind-up and recovery last base / (1 + Action Speed).
function Formulas.actionTime(base: number, actionSpeed: number): number
	return base / (1 + Formulas.quantizeActionSpeed(actionSpeed))
end

-- Cooldown = base * 100 / (100 + AH * s), with the ability's haste tag s in {1.0, 0.5, 0}.
function Formulas.cooldown(base: number, abilityHaste: number, tag: number): number
	return base * 100 / (100 + abilityHaste * tag)
end

-- Cost = base * 100 / (100 + E)
function Formulas.cost(base: number, efficiency: number): number
	return base * 100 / (100 + efficiency)
end

-- Expected damage per hit multiplies by 1 + p(m - 1).
function Formulas.expectedCrit(critChance: number, critMult: number): number
	return 1 + critChance * (critMult - 1)
end

-- Rolls a crit. `roll` is a uniform number in [0, 1) so callers own the random source.
function Formulas.rollCrit(critChance: number, critMult: number, roll: number): (number, boolean)
	if roll < critChance then
		return critMult, true
	end
	return 1, false
end

export type Outgoing = {
	ownBonus: number?, -- O_self, additive within the class
	externalBonus: number?, -- O_ext, strongest single source
	vulnerability: number?, -- V on the target, strongest single source
}

-- Outgoing multiplier: each category is capped, then the categories multiply.
function Formulas.outgoingMultiplier(o: Outgoing?): number
	if not o then
		return 1
	end
	local own = clamp(o.ownBonus or 0, 0, Constants.CAP_O_SELF)
	local ext = clamp(o.externalBonus or 0, 0, Constants.CAP_O_EXT)
	local vuln = clamp(o.vulnerability or 0, 0, Constants.CAP_VULN)
	return (1 + own) * (1 + ext) * (1 + vuln)
end

export type Defense = {
	passive: number?, -- armor and other passive DR, already summed
	block: number?, -- 0.7 on a blocked white frontal hit, else 0
	external: number?, -- strongest single external DR source
}

-- Total damage reduction. Passive is capped at 40% and external at 20%.
-- The layers combine multiplicatively, then the total is capped at 80%.
-- The GDD gives the caps but not how layers combine; multiplicative is a prototype choice [Proto].
function Formulas.totalDR(d: Defense): number
	local passive = clamp(d.passive or 0, 0, Constants.CAP_PASSIVE_DR)
	local block = clamp(d.block or 0, 0, 1)
	local external = clamp(d.external or 0, 0, Constants.CAP_EXTERNAL_DR)
	local taken = (1 - passive) * (1 - block) * (1 - external)
	return math.min(1 - taken, Constants.CAP_TOTAL_DR)
end

-- Boss hits are written against light armor. Converts a written hit into damage before this target's DR.
function Formulas.rawFromWritten(written: number, referenceDR: number): number
	return written / (1 - referenceDR)
end

-- Shields absorb after DR. Returns (damage that reaches HP, shield left).
function Formulas.absorb(damage: number, shield: number): (number, number)
	if shield <= 0 then
		return damage, 0
	end
	local absorbed = math.min(damage, shield)
	return damage - absorbed, shield - absorbed
end

-- Caps a new shield total at 30% of max HP.
function Formulas.capShield(shield: number, maxHealth: number): number
	return math.min(shield, maxHealth * Constants.CAP_SHIELD_FRACTION)
end

-- Heals are clamped to missing HP. Returns (effective heal, overheal).
function Formulas.clampHeal(amount: number, health: number, maxHealth: number): (number, number)
	local effective = math.max(0, math.min(amount, maxHealth - health))
	return effective, amount - effective
end

-- Revive charges per boss attempt: ceil(players / 5).
function Formulas.reviveCharges(players: number): number
	return math.ceil(players / 5)
end

return Formulas
