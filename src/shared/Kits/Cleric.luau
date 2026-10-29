-- Cleric (healer): Mend, Sanctuary and healing basic attacks.
-- Tests Healing Power, Ability Haste, Efficiency and Regeneration.
-- Divine Grace (heavy attack at full Grace cleanses) is not in the placeholder table, so it is left out.

return {
	id = "Cleric",
	role = "healer",
	armor = "medium",
	isTank = false,
	resource = { name = "Faith", pool = 100, regen = 2, start = 100 },

	basic = {
		id = "basic",
		name = "Basic heal",
		effect = "heal",
		coeff = 0.6,
		windup = 0.40,
		recovery = 0.30,
		range = 40, -- [Proto]
		gain = 1, -- +1 Faith
		targeting = "lowestAlly", -- the prototype AI rule from the kit table
	},
	heavy = nil,
	skills = {
		{
			id = "mend",
			name = "Mend",
			effect = "heal",
			coeff = 3.0,
			windup = 1.00,
			recovery = 0.30,
			cooldown = 8,
			hasteTag = 1.0,
			cost = 20,
			range = 40, -- [Proto]
			targeting = "lowestAlly",
		},
		{
			id = "sanctuary",
			name = "Sanctuary",
			effect = "areaHeal",
			coeff = 1.5,
			radius = 21, -- 6 m is about 21 studs
			maxTargets = 5,
			windup = 1.00,
			recovery = 0.30,
			cooldown = 15,
			hasteTag = 1.0,
			cost = 30,
		},
	},
}
