-- Warden (tank): block, Bulwark, Intercept and Shield Bash. Tests Vitality, defensive uptime and interrupts.

return {
	id = "Warden",
	role = "tank",
	armor = "heavy",
	isTank = true,
	resource = { name = "Grit", pool = 100, regen = 0, start = 0 },
	signature = { name = "Bulwark", max = 100 },
	onBlock = { grit = 8, bulwark = 10 },

	basic = {
		id = "basic",
		name = "Basic attack",
		effect = "strike",
		coeff = 0.7,
		windup = 0.35,
		recovery = 0.35,
		range = 10,
		gain = 5, -- +5 Grit
	},
	heavy = nil,
	skills = {
		{
			id = "bash",
			name = "Shield Bash",
			effect = "strike",
			coeff = 1.0,
			interrupts = true,
			windup = 0.40,
			recovery = 0.40,
			cooldown = 12,
			hasteTag = 0.5,
			cost = 20,
			range = 10,
		},
		{
			id = "cleave",
			name = "Cleave",
			effect = "cleave",
			coeff = 1.5,
			coneDegrees = 120, -- [Proto]
			windup = 0.50,
			recovery = 0.50,
			cooldown = 6,
			hasteTag = 1.0,
			cost = 15,
			range = 12,
		},
	},
	-- Intercept has its own key in the prototype (not dodge), per the validation finding.
	signatureAction = {
		id = "intercept",
		name = "Intercept",
		effect = "intercept",
		bulwarkCost = 50,
		windup = 0.30, -- the dash
		recovery = 0,
		range = 40, -- [Proto]
		targeting = "otherAlly", -- [Proto] the ally with the lowest HP %
		guardDuration = 4, -- [Proto] how long the guard waits for the next hit
	},
}
