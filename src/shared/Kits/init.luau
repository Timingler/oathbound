-- Placeholder kits for the prototype classes.
-- Source: Build System Review, audit tab, section 5.2. Every number there is a placeholder [A].
-- Values marked [Proto] were not in that table and were chosen to make the arena playable.

local Kits = {
	Assassin = require(script.Assassin),
	Cleric = require(script.Cleric),
	Warden = require(script.Warden),
	Ranger = require(script.Ranger), -- [Proto] not in the placeholder table yet
}

Kits.ORDER = { "Assassin", "Cleric", "Warden", "Ranger" }

return Kits
