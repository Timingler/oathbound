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

-- Armour per slot. `look` names a model in ServerStorage.OathGear (server/Gear); `shirt` and `pants` are clothing
-- template IDs. Every look is a real asset from the cleared places (docs/ASSETS.md); feet and rings have none yet,
-- so they change stats only. The first of each list is the starter.
Items.ARMOR = {
	head = {
		{ name = "Warrior's Helm", look = "warriorHelm" }, -- vania
		{ name = "Fallen's Shroud", look = "fallenShroud" }, -- Excry
		{ name = "Wanderer's Hood", look = "hxhHood" }, -- hxh
		{ name = "Lost Crown", look = "lostCrown" }, -- vania
	},
	chest = {
		{ name = "Wayfarer's Longcoat", shirt = 12898857876 }, -- vania
		{ name = "Frostfur Hunter Coat", shirt = 4798579756 }, -- Excry
		{ name = "Shadowleather Jerkin", shirt = 6523934418 }, -- Excry
		{ name = "Wrapped Vest", shirt = 14945189243 }, -- Excry
		{ name = "Templar Vestments", shirt = 9793008658 }, -- Excry
		{ name = "Vigil Captain's Coat", shirt = 12898987440 }, -- vania
		{ name = "Beastfur Vest", shirt = 513647064 }, -- hxh
		{ name = "Priest's Cassock", shirt = 4299026991 }, -- hxh
		{ name = "Monster Hunter's Robe", look = "hunterRobe", shirt = 6523934418 }, -- vania robe over leather
		{ name = "Strapped Jerkin", look = "chestStrap", shirt = 14945189243 }, -- vania strap over wraps
	},
	hands = {
		{ name = "Leather Gauntlets", look = "leatherGauntlet" }, -- vania
	},
	legs = {
		{ name = "Wayfarer's Leggings", pants = 12898848920 }, -- vania
		{ name = "Frostfur Leggings", pants = 4798577670 }, -- Excry
		{ name = "Shadowleather Trousers", pants = 6522451827 }, -- Excry
		{ name = "Templar Greaves", pants = 9793004800 }, -- Excry
		{ name = "Vigil Captain's Breeches", pants = 12898979861 }, -- vania
		{ name = "Beastfur Greaves", pants = 513647982 }, -- hxh
		{ name = "Priest's Trousers", pants = 1670562937 }, -- hxh
		{ name = "Tasset Greaves", look = "warriorGreaves", pants = 12898848920 }, -- vania
	},
	feet = { -- no boots in the cleared places yet: stats only
		{ name = "Soft Boots" },
		{ name = "Iron Sabatons" },
		{ name = "Marching Boots" },
		{ name = "Ashen Treads" },
	},
	neck = {
		{ name = "Gold Necklace", look = "goldNecklace" }, -- Excry
		{ name = "Silver Necklace", look = "silverNecklace" }, -- Excry
		{ name = "Ragged Scarf", look = "raggedScarf" }, -- Excry
		{ name = "Fur Mantle", look = "furCloak" }, -- vania
	},
	ring = { -- too small to show on an R6 hand: stats only
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
