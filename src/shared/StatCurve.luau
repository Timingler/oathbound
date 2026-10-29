-- The secondary stat curve from Oathbound GDD v2, section 5.
-- Every secondary uses Effect = Ceiling * R / (R + K), with K = 300F. Ceilings are placeholders [A].
-- Mastery is left out of the first prototype because no per-class effect is designed.

local Scaling = require(script.Parent.Scaling)

local StatCurve = {}

StatCurve.CEILING = {
	critChance = 0.45, -- added to the 5% base, for 50% total
	critEffect = 0.5, -- added to the 1.5x base, for 2.0x
	actionSpeed = 0.30,
	abilityHaste = 100,
	healingPower = 0.60,
	efficiency = 60,
	regeneration = 0.60,
	vitality = 0.40,
}

function StatCurve.k(level: number): number
	return 300 * Scaling.levelFactor(level)
end

function StatCurve.effect(rating: number, ceiling: number, level: number): number
	if rating <= 0 then
		return 0
	end
	return ceiling * rating / (rating + StatCurve.k(level))
end

export type Derived = {
	critChance: number,
	critMult: number,
	actionSpeed: number,
	abilityHaste: number,
	healingPower: number,
	efficiency: number,
	regeneration: number,
	vitality: number,
}

-- Turns a table of ratings (from gear modifiers) into the effects combat reads.
function StatCurve.derive(ratings: { [string]: number }?, level: number): Derived
	local r = ratings or {}
	local function e(name: string): number
		return StatCurve.effect(r[name] or 0, StatCurve.CEILING[name], level)
	end
	return {
		critChance = 0.05 + e("critChance"),
		critMult = 1.5 + e("critEffect"),
		actionSpeed = e("actionSpeed"),
		abilityHaste = e("abilityHaste"),
		healingPower = e("healingPower"),
		efficiency = e("efficiency"),
		regeneration = e("regeneration"),
		vitality = e("vitality"),
	}
end

return StatCurve
