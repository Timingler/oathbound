-- Ranger (ranged physical damage): the base class that later branches into Marksman, Beastmaster and Druid.
-- Arrows are real projectiles (server/Projectiles): they fly where you aim, drop slightly, and stop at the first
-- enemy unless they pierce. Tests Action Speed and crit at range, where the melee classes cannot reach.
-- Every number here is [Proto]: the Ranger is not in the placeholder kit table yet.

return {
	id = "Ranger",
	role = "damage",
	armor = "light",
	isTank = false,
	resource = { name = "Focus", pool = 100, regen = 12, start = 100 },

	-- Quick Shot: a snap draw and release.
	basic = {
		id = "basic",
		name = "Quick Shot",
		effect = "shot",
		coeff = 0.7,
		windup = 0.35,
		recovery = 0.30,
		range = 60, -- arrows fall out of the sky past this [Proto]
		speed = 140, -- studs per second
		gain = 4, -- +4 Focus per shot
	},
	-- Hold left click: Aimed Shot, a full draw that hits much harder and flies faster.
	heavy = {
		id = "aimed",
		name = "Aimed Shot",
		effect = "shot",
		coeff = 2.2,
		windup = 0.90,
		recovery = 0.40,
		range = 90,
		speed = 220,
		cost = 15,
	},
	skills = {
		{
			id = "pierce",
			name = "Piercing Arrow",
			effect = "shot",
			pierce = true, -- passes through every enemy in its path
			coeff = 1.6,
			windup = 0.55,
			recovery = 0.40,
			cooldown = 8,
			hasteTag = 1.0,
			cost = 25,
			range = 80,
			speed = 200,
		},
		{
			id = "volley",
			name = "Volley",
			effect = "volley",
			coeff = 1.1, -- to each enemy in the circle
			radius = 10,
			delay = 0.6, -- seconds from the release until the arrows land
			windup = 0.60,
			recovery = 0.40,
			cooldown = 14,
			hasteTag = 1.0,
			cost = 35,
			range = 45, -- lands on the enemy you face within this, else this far ahead
		},
		{
			id = "disengage",
			name = "Disengage",
			effect = "disengage",
			instant = true,
			distance = 22, -- studs, straight back
			invuln = 0.30, -- seconds untouchable while leaping
			windup = 0,
			recovery = 0,
			cooldown = 12,
			hasteTag = 0.5, -- mobility, like Smoke Step
			cost = 0,
		},
	},
}
