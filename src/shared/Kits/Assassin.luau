-- Assassin (damage): Mark, combo points and finisher. Tests crit, Action Speed and Ability Haste.

return {
	id = "Assassin",
	role = "damage",
	armor = "light",
	isTank = false,
	resource = { name = "Energy", pool = 100, regen = 15, start = 100 },
	signature = { name = "Combo", max = 5 },
	markDuration = 10, -- [Proto] the kit says basic attacks apply Mark but gives no duration

	basic = {
		id = "basic",
		name = "Basic attack",
		effect = "strike",
		coeff = 0.8,
		windup = 0.25,
		recovery = 0.25,
		range = 9,
		combo = 1,
		applyMark = true,
	},
	-- Heavy attack (hold left click) at 5 combo points
	heavy = {
		id = "finisher",
		name = "Finisher",
		effect = "finisher",
		coeffPerPoint = 2.0,
		windup = 0.60,
		recovery = 0.50,
		range = 9,
		requiresCombo = 5,
		requiresMark = true,
	},
	skills = {
		{
			id = "backstab",
			name = "Backstab",
			effect = "strike",
			coeff = 3.0,
			frontPenalty = 0.5, -- 50% damage unless from behind
			windup = 0.30,
			recovery = 0.40,
			cooldown = 6,
			hasteTag = 1.0,
			cost = 45,
			range = 9,
			combo = 2,
		},
		{
			id = "poison",
			name = "Poison Blade",
			effect = "dot",
			dotCoeff = 6.0, -- total over the duration
			duration = 12,
			windup = 0.30,
			recovery = 0.30,
			cooldown = 10,
			hasteTag = 1.0,
			cost = 35,
			range = 9,
		},
		{
			id = "smoke",
			name = "Smoke Step",
			effect = "smokeStep",
			untargetable = 1.0,
			instant = true,
			useWindow = 0.35, -- [Proto] usable during a dodge or this long after it
			windup = 0,
			recovery = 0,
			cooldown = 20,
			hasteTag = 0.5,
			cost = 0,
		},
	},
}
