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
	look: string?, -- how it looks on the character (server/Gear), for armour and off-hands
	shirt: number?, -- chest: Shirt template ID put on the character (server/Gear)
	pants: number?, -- legs: Pants template ID
	palette: string?, -- chest and legs: the outfit set it belongs to
	class: string?, -- weapons and off-hands: the only class that can equip it
	model: string?, -- main-hand weapons: the WeaponLibrary key (or bow tint in server/Weapons) it shows as
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

-- What each class can hold. Main hands name the weapon model they show (shared/WeaponLibrary keys, or a bow tint
-- in server/Weapons); off-hands name a look in server/Gear. The first of each list is the class's starter.
Items.CLASS_GEAR = {
	Warden = {
		kind = "Sword and shield",
		mainHand = {
			{ name = "Kingsguard Blade", model = "Warden" },
			{ name = "Arming Sword", model = "Sword" },
			{ name = "Sabre", model = "Sabre" },
			{ name = "Cutlass", model = "Cutlass" },
			{ name = "Rusted Sword", model = "Rusted Sword" },
		},
		offHand = {
			{ name = "Heater Shield" },
			{ name = "Kite Shield" },
			{ name = "Tower Shield" },
			{ name = "Round Buckler" },
		},
	},
	Assassin = {
		kind = "Daggers",
		mainHand = {
			{ name = "Long Dagger", model = "Assassin" },
			{ name = "Curved Dagger", model = "Curved Dagger" },
			{ name = "Rusted Dagger", model = "Rusted Dagger" },
		},
		offHand = {
			{ name = "Parrying Dagger" },
			{ name = "Smoke Pouch" },
		},
	},
	Cleric = {
		kind = "Hammer and relic",
		mainHand = {
			{ name = "Ash Hammer", model = "Cleric" },
			{ name = "Great Hammer", model = "Great Hammer" },
			{ name = "Rusted Hammer", model = "Rusted Hammer" },
		},
		offHand = {
			{ name = "Lantern of Vigil", look = "lantern" }, -- the starter: the only off-hand with a real model
			{ name = "Prayer Tome" },
			{ name = "Pilgrim's Buckler" },
		},
	},
	Ranger = {
		kind = "Bow and quiver",
		mainHand = {
			{ name = "Hunting Bow", model = "Hunting Bow" },
			{ name = "Ashwood Longbow", model = "Ashwood Longbow" },
			{ name = "Blackwood Recurve", model = "Blackwood Recurve" },
			{ name = "Gilded Warbow", model = "Gilded Warbow" },
		},
		offHand = {
			{ name = "Quiver" },
			{ name = "Hunter's Quiver" },
		},
	},
}

-- Armour per slot. Only worn clothing shows: chest items carry a Shirt template and legs items a Pants template
-- (server/Gear puts them on the character; the avatar's own come back when the slot is empty). Every outfit is a
-- matching Shirt and Pants set from one source, so chest and legs share a name and a `palette`; Equip best keeps
-- the legs in the chest's palette. Chest and legs are clothing only; small 3D pieces (gauntlets, Tasset Greaves on
-- the feet slot, necklaces, scarf, mantle) stay. Head and ring have no look for now: stats only.
-- Sources and the art rule are in docs/ASSETS.md. The first of each list is the starter.
Items.ARMOR = {
	head = {
		{ name = "Iron Helm" },
		{ name = "Leather Cap" },
		{ name = "Traveller's Hood" },
		{ name = "Circlet of Dawn" },
	},
	chest = {
		{ name = "Wayfarer's Longcoat", shirt = 12898857876, palette = "leather" }, -- vania
		{ name = "Vigil Captain's Coat", shirt = 12898987440, palette = "noble" }, -- vania
		{ name = "Nobleman's Frock Coat", shirt = 12898946049, palette = "noble" }, -- vania
		{ name = "Navy Nobleman's Coat", shirt = 12898960235, palette = "noble" }, -- vania
		{ name = "Nightwatch Coat", shirt = 9963316538, palette = "noble" }, -- Excry
		{ name = "Sapphire Plate", shirt = 6700094348, palette = "steel" }, -- vania
		{ name = "Frostfur Hunter Coat", shirt = 4798579756, palette = "hunter" }, -- Excry
		{ name = "Beastfur Vest", shirt = 513647064, palette = "hunter" }, -- hxh
		{ name = "Shadowleather Jerkin", shirt = 6523934418, palette = "dark" }, -- Excry
		{ name = "Wrapped Vest", shirt = 14945189243, palette = "dark" }, -- Excry
		{ name = "Bandaged Leathers", shirt = 97795805, palette = "dark" }, -- Excry
		{ name = "Gravecloth Tunic", shirt = 4644385653, palette = "dark" }, -- Excry
		{ name = "Duskwalker Coat", shirt = 8721840456, palette = "dark" }, -- Excry
		{ name = "Tattered Wanderer's Tunic", shirt = 2602452291, palette = "dark" }, -- Excry
		{ name = "Templar Vestments", shirt = 9793008658, palette = "priest" }, -- Excry
		{ name = "Priest's Cassock", shirt = 4299026991, palette = "priest" }, -- hxh
	},
	hands = {
		{ name = "Leather Gauntlets", look = "leatherGauntlet" }, -- vania (small 3D pieces stay)
		{ name = "Leather Gloves" },
		{ name = "Chain Gauntlets" },
		{ name = "Ashwood Bracers" },
	},
	legs = {
		{ name = "Wayfarer's Leggings", pants = 12898848920, palette = "leather" },
		{ name = "Vigil Captain's Breeches", pants = 12898979861, palette = "noble" },
		{ name = "Nobleman's Breeches", pants = 12898939449, palette = "noble" },
		{ name = "Navy Nobleman's Breeches", pants = 12898956879, palette = "noble" },
		{ name = "Nightwatch Trousers", pants = 9962616226, palette = "noble" },
		{ name = "Sapphire Greaves", pants = 6700096491, palette = "steel" },
		{ name = "Frostfur Leggings", pants = 4798577670, palette = "hunter" },
		{ name = "Beastfur Greaves", pants = 513647982, palette = "hunter" },
		{ name = "Shadowleather Trousers", pants = 6522451827, palette = "dark" },
		{ name = "Wrapped Trousers", pants = 14945190355, palette = "dark" },
		{ name = "Bandaged Trousers", pants = 97795809, palette = "dark" },
		{ name = "Gravecloth Trousers", pants = 4644385578, palette = "dark" },
		{ name = "Duskwalker Trousers", pants = 8721833084, palette = "dark" },
		{ name = "Tattered Wanderer's Trousers", pants = 2602453636, palette = "dark" },
		{ name = "Templar Greaves", pants = 9793004800, palette = "priest" },
		{ name = "Priest's Trousers", pants = 1670562937, palette = "priest" },
	},
	feet = {
		{ name = "Soft Boots" },
		{ name = "Tasset Greaves", look = "warriorGreaves" }, -- vania
		{ name = "Iron Sabatons" },
		{ name = "Marching Boots" },
		{ name = "Ashen Treads" },
	},
	neck = {
		{ name = "Pilgrim's Token" },
		{ name = "Gold Necklace", look = "goldNecklace" }, -- Excry
		{ name = "Silver Necklace", look = "silverNecklace" }, -- Excry
		{ name = "Ragged Scarf", look = "raggedScarf" }, -- Excry
		{ name = "Fur Mantle", look = "furCloak" }, -- vania
		{ name = "Amulet of Embers" },
		{ name = "Oathstone Pendant" },
	},
	ring = {
		{ name = "Band of Ash" },
		{ name = "Signet of the Warden" },
		{ name = "Ring of Quiet Steps" },
		{ name = "Gilded Loop" },
	},
}

function Items.rarity(id: string)
	return Items.RARITY_BY_ID[id] or Items.RARITIES[1]
end

function Items.statName(stat: string): string
	local s = Items.STATS[stat]
	return s and s.name or stat
end

return Items
