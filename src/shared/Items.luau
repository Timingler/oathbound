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
	shirt: number?, -- body armour: Shirt template ID put on the character (server/Gear)
	pants: number?, -- body armour: Pants template ID, always worn with its Shirt
	tint: { number }?, -- body armour: RGB multiplied into the Shirt and Pants, so every outfit sits in one palette
	class: string?, -- weapons and off-hands: the only class that can equip it
	model: string?, -- main-hand weapons: the WeaponLibrary key (or bow tint in server/Weapons) it shows as
	finish: { number }?, -- main-hand weapons: RGB multipliers for a blackened or gilded variant of the model
	tool: string?, -- utility tools: the Items.TOOLS id; they sit on the hotbar, not in an equipment slot
}

-- Equipment slots in the order the UI lists them.
Items.SLOTS = {
	{ id = "body", name = "Body Armor", icon = "🥋", group = "armor" },
	{ id = "hands", name = "Hands", icon = "🧤", group = "armor" },
	{ id = "feet", name = "Feet", icon = "👢", group = "armor" },
	{ id = "mainHand", name = "Main hand", icon = "⚔", group = "weapon" },
	{ id = "offHand", name = "Off hand", icon = "🛡", group = "weapon" },
	{ id = "neck", name = "Neck", icon = "📿", group = "jewelry" },
	{ id = "belt", name = "Belt", icon = "🎒", group = "jewelry" },
}

Items.SLOT_BY_ID = {}
for i, slot in Items.SLOTS do
	slot.index = i
	Items.SLOT_BY_ID[slot.id] = slot
end
-- Utility tools have a slot entry so the bag can list and sort them, but no equipment slot: they live on the hotbar.
Items.SLOT_BY_ID.tool = { id = "tool", name = "Tool", icon = "⛏", group = "tool", index = #Items.SLOTS + 1 }

-- Bag tabs: id = slot group, or "all".
Items.TABS = {
	{ id = "all", name = "All" },
	{ id = "weapon", name = "Weapons" },
	{ id = "armor", name = "Armor" },
	{ id = "jewelry", name = "Jewelry" },
	{ id = "tool", name = "Tools" },
}

-- The hotbar (client/Hotbar, server/Inventory): number keys 1 to 5 pull out what is in each slot. "weapon" stands
-- for your equipped main hand; any other entry is a tool. Tools are for activities like mining, so they are one key
-- away instead of in a menu. Using one does nothing yet: gathering is not built [Proto].
Items.HOTBAR_SIZE = 5
Items.TOOLS = {
	{ id = "pickaxe", name = "Miner's Pickaxe", icon = "⛏", verb = "mine", target = "ore" },
	{ id = "hatchet", name = "Woodcutter's Hatchet", icon = "🪓", verb = "chop", target = "trees" },
	{ id = "fishingRod", name = "Fishing Rod", icon = "🎣", verb = "fish", target = "water" },
	{ id = "torch", name = "Torch", icon = "🔥", light = true },
}
Items.TOOL_BY_ID = {}
for _, tool in Items.TOOLS do
	Items.TOOL_BY_ID[tool.id] = tool
end

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
-- Weapon finishes: multiplied into every part of the weapon model (server/Weapons). [Proto]
local BLACKENED = { 0.45, 0.43, 0.45 }
local GILDED = { 1.15, 0.95, 0.55 }

Items.CLASS_GEAR = {
	Warden = {
		kind = "Sword and shield",
		mainHand = {
			{ name = "Kingsguard Blade", model = "Warden" },
			{ name = "Arming Sword", model = "Sword" },
			{ name = "Sabre", model = "Sabre" },
			{ name = "Cutlass", model = "Cutlass" },
			{ name = "Rusted Sword", model = "Rusted Sword" },
			{ name = "Camilla Sabre", model = "Camilla Sabre" },
			{ name = "Blackened Arming Sword", model = "Sword", finish = BLACKENED },
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
			{ name = "Bloodfang", model = "Vamp Dagger" },
			{ name = "Nightfang", model = "Vamp Dagger 2" },
			{ name = "Blackened Long Dagger", model = "Assassin", finish = BLACKENED },
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
			{ name = "Gilded Ash Hammer", model = "Cleric", finish = GILDED },
			{ name = "Blackened Great Hammer", model = "Great Hammer", finish = BLACKENED },
			{ name = "Gilded Great Hammer", model = "Great Hammer", finish = GILDED },
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
			{ name = "Bone Bow", model = "Bone Bow" },
			{ name = "Bloodwood Bow", model = "Bloodwood Bow" },
		},
		offHand = {
			{ name = "Quiver" },
			{ name = "Hunter's Quiver" },
		},
	},
}

-- Armour per slot. Body Armor is a whole outfit: a matching Shirt and Pants from one source, always worn together
-- (server/Gear), so the look never clashes. It carries the stat budget of a chest and legs piece: its modifier rolls
-- are BODY_ROLL_SCALE times larger [Proto]. `tint` [Proto] grades every outfit into one muted Oathbound palette.
-- The small pieces stay modular: gauntlets (hands), Tasset Greaves (feet), necklaces, scarf and mantle (neck).
-- Every armour item is visible; head and ring slots are hidden until they have real models. Sources and the art rule are in docs/ASSETS.md. The first of each
-- list is the starter.
Items.BODY_ROLL_SCALE = 1.6

-- The shared grade, slightly warm and dim, and stronger grades for outfits much brighter than the rest.
local GRADE = { 232, 224, 212 }
local GRADE_BRIGHT = { 200, 192, 180 } -- white trousers, white fur
local GRADE_VIVID = { 185, 182, 190 } -- saturated blue plate

Items.ARMOR = {
	body = {
		{ name = "Wayfarer's Garb", shirt = 12898857876, pants = 12898848920, tint = GRADE }, -- vania
		{ name = "Vigil Captain's Uniform", shirt = 12898987440, pants = 12898979861, tint = GRADE }, -- vania
		{ name = "Nobleman's Frock", shirt = 12898946049, pants = 12898939449, tint = GRADE_BRIGHT }, -- vania
		{ name = "Navy Nobleman's Frock", shirt = 12898960235, pants = 12898956879, tint = GRADE_BRIGHT }, -- vania
		{ name = "Nightwatch Coat", shirt = 9963316538, pants = 9962616226, tint = GRADE }, -- Excry
		{ name = "Sapphire Plate", shirt = 6700094348, pants = 6700096491, tint = GRADE_VIVID }, -- vania
		{ name = "Frostfur Hunter's Garb", shirt = 4798579756, pants = 4798577670, tint = GRADE_BRIGHT }, -- Excry
		{ name = "Beastfur Harness", shirt = 513647064, pants = 513647982, tint = GRADE }, -- hxh
		{ name = "Shadowleather Garb", shirt = 6523934418, pants = 6522451827, tint = GRADE }, -- Excry
		{ name = "Wrapped Leathers", shirt = 14945189243, pants = 14945190355, tint = GRADE }, -- Excry
		{ name = "Bandaged Leathers", shirt = 97795805, pants = 97795809, tint = GRADE }, -- Excry
		{ name = "Gravecloth", shirt = 4644385653, pants = 4644385578, tint = GRADE }, -- Excry
		{ name = "Duskwalker Coat", shirt = 8721840456, pants = 8721833084, tint = GRADE }, -- Excry
		{ name = "Tattered Wanderer's Rags", shirt = 2602452291, pants = 2602453636, tint = GRADE }, -- Excry
		{ name = "Templar Vestments", shirt = 9793008658, pants = 9793004800, tint = GRADE }, -- Excry
		{ name = "Priest's Cassock", shirt = 4299026991, pants = 1670562937, tint = GRADE }, -- hxh
	},
	hands = {
		{ name = "Leather Gauntlets", look = "leatherGauntlet" }, -- vania
		{ name = "Linen Wraps", look = "wraps" }, -- vania Arms.Wraps
	},
	feet = {
		{ name = "Leather Shin Guards", look = "shinGuards" }, -- vania Warrior Greaves leg plates, on the shins
		{ name = "Iron Shin Guards", look = "shinGuardsIron" },
		{ name = "Blackened Shin Guards", look = "shinGuardsBlack" },
		{ name = "Bone Shin Guards", look = "shinGuardsBone" },
	},
	neck = {
		{ name = "Wool Scarf", look = "scarf" }, -- vania
		{ name = "Gold Necklace", look = "goldNecklace" }, -- Excry
		{ name = "Silver Necklace", look = "silverNecklace" }, -- Excry
		{ name = "Holy Chain", look = "holyChain" }, -- vania
		{ name = "Ragged Scarf", look = "raggedScarf" }, -- Excry
		{ name = "Crimson Cowl", look = "scarf2" }, -- vania Scarf 2
		{ name = "Checked Scarf", look = "squaredScarf" }, -- hxh Squared Scarf
		{ name = "Fur Mantle", look = "furCloak" }, -- vania OldFur Cloak
		{ name = "Snow Fur Mantle", look = "furCloakBack" }, -- vania Back.Fur Cloak
	},
	belt = {
		{ name = "Leather Strap", look = "chestStrap" }, -- vania Chest Strap
		{ name = "Traveller's Harness", look = "chestStrap2" }, -- vania Chest Strap2
		{ name = "Crossed Bandolier", look = "chestStrap3" }, -- vania Chest Strap3
		{ name = "Satchel", look = "bag" }, -- vania Chest.Bag
		{ name = "Wool Sash", look = "waistband" }, -- hxh Waistband
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
