-- Gear data shared by the server inventory and the inventory UI: slots, the rarity ladder and modifier stats.
-- Rarity follows GDD v2: one random modifier per tier above Common, Legendary has 4, Unique adds a unique effect.
-- Every number here is a prototype placeholder [Proto], listed in docs/PLACEHOLDERS.md.

local Items = {}

export type Modifier = { stat: string, rating: number }
export type Item = {
	uid: string,
	name: string,
	slot: string,
	rarity: string,
	itemLevel: number,
	modifiers: { Modifier },
	unique: string?, -- text of the unique effect (not simulated yet)
}

-- Equipment slots in the order the UI lists them.
Items.SLOTS = {
	{ id = "head", name = "Head", icon = "⛑", group = "armor" },
	{ id = "chest", name = "Chest", icon = "🥋", group = "armor" },
	{ id = "hands", name = "Hands", icon = "🧤", group = "armor" },
	{ id = "legs", name = "Legs", icon = "👖", group = "armor" },
	{ id = "feet", name = "Feet", icon = "👢", group = "armor" },
	{ id = "mainHand", name = "Main hand", icon = "⚔", group = "weapon" },
	{ id = "offHand", name = "Off hand", icon = "🛡", group = "weapon" },
	{ id = "neck", name = "Neck", icon = "📿", group = "jewelry" },
	{ id = "ring", name = "Ring", icon = "💍", group = "jewelry" },
}

Items.SLOT_BY_ID = {}
for i, slot in Items.SLOTS do
	slot.index = i
	Items.SLOT_BY_ID[slot.id] = slot
end

-- Bag tabs: id = slot group, or "all".
Items.TABS = {
	{ id = "all", name = "All" },
	{ id = "weapon", name = "Weapons" },
	{ id = "armor", name = "Armor" },
	{ id = "jewelry", name = "Jewelry" },
}

Items.RARITIES = {
	{ id = "common", name = "Common", modifiers = 0, color = Color3.fromRGB(200, 196, 186) },
	{ id = "uncommon", name = "Uncommon", modifiers = 1, color = Color3.fromRGB(98, 200, 92) },
	{ id = "rare", name = "Rare", modifiers = 2, color = Color3.fromRGB(80, 150, 240) },
	{ id = "epic", name = "Epic", modifiers = 3, color = Color3.fromRGB(176, 104, 240) },
	{ id = "legendary", name = "Legendary", modifiers = 4, color = Color3.fromRGB(245, 150, 40) },
	{ id = "unique", name = "Unique", modifiers = 4, color = Color3.fromRGB(232, 206, 120) },
}

Items.RARITY_BY_ID = {}
for i, rarity in Items.RARITIES do
	rarity.rank = i
	Items.RARITY_BY_ID[rarity.id] = rarity
end

-- Modifier stats are the secondary ratings StatCurve turns into effects. `roll` is the rating range at item
-- level 65 [Proto]; at level 50, K = 1182, so 250 rating is about 17% of a stat's ceiling.
Items.STATS = {
	critChance = { name = "Critical Strike", roll = { 120, 260 } },
	critEffect = { name = "Critical Power", roll = { 120, 260 } },
	actionSpeed = { name = "Action Speed", roll = { 100, 220 } },
	abilityHaste = { name = "Ability Haste", roll = { 120, 260 } },
	healingPower = { name = "Healing Power", roll = { 120, 260 } },
	efficiency = { name = "Efficiency", roll = { 100, 220 } },
	regeneration = { name = "Regeneration", roll = { 100, 220 } },
	vitality = { name = "Vitality", roll = { 120, 260 } },
}

Items.STAT_ORDER = {
	"critChance",
	"critEffect",
	"actionSpeed",
	"abilityHaste",
	"healingPower",
	"efficiency",
	"regeneration",
	"vitality",
}

function Items.rarity(id: string)
	return Items.RARITY_BY_ID[id] or Items.RARITIES[1]
end

function Items.statName(stat: string): string
	local s = Items.STATS[stat]
	return s and s.name or stat
end

return Items
