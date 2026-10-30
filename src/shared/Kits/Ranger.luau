-- Ranger (ranged physical damage): the base class that later branches into Marksman, Beastmaster and Druid.
-- A skill class: hold right click to aim (the bow draws), left click to loose. Arrows are real projectiles
-- (server/Projectiles) that fly exactly where you point, with travel time and a slight drop, and no auto-aim.
-- The longer the draw, the harder and faster the arrow. Left click without aiming is a weaker hip-fire shot.
-- Every number here is [Proto]: the Ranger is not in the placeholder kit table yet.

return {
	id = "Ranger",
	role = "damage",
	armor = "light",
	isTank = false,
	resource = { name = "Focus", pool = 100, regen = 12, start = 100 },

	-- Quick Shot: hip fire, left click without aiming.
	basic = {
		id = "basic",
		name = "Quick Shot",
		effect = "shot",
		coeff = 0.6,
		windup = 0.22,
		recovery = 0.30,
		range = 110, -- arrows are removed past 1.3x this [Proto]
		speed = 190, -- studs per second
		gain = 4, -- +4 Focus per shot
	},
	-- Aimed Shot: left click while aiming. The draw is the time right click has been held, so the release itself
	-- is quick. Damage and speed grow from `minCoeff`/`minSpeed` at no draw to `coeff`/`speed` at `fullDraw`.
	heavy = {
		id = "aimed",
		name = "Aimed Shot",
		effect = "shot",
		needsAim = true,
		coeff = 2.4,
		minCoeff = 0.8,
		speed = 330,
		minSpeed = 210,
		fullDraw = 1.0, -- seconds of aiming for a full draw
		windup = 0.10,
		recovery = 0.35,
		range = 220,
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
			range = 180,
			speed = 300,
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
