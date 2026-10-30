-- Per-player gear: a bag of items and what is equipped in each slot. Equipped modifiers become the actor's
-- ratings, and the average item level of the equipped set becomes its item level, so gear changes WD, HP and every
-- secondary stat through the normal formulas. Prototype only: the bag is generated per player and not saved.
-- `service` is CombatService, passed in to avoid a require cycle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Net = require(Shared.Net)

local Inventory = {}

local COMBAT_TIMEOUT = 5 -- matches CombatService: no gear swaps until 5 s after the last hit [Proto]
local BASE_ITEM_LEVEL = 65 -- the starter set; matches the arena's item level so nothing changes until you swap [Proto]
local BAG_SIZE = 18 -- random items in the starter bag [Proto]

-- Name pools per slot. Classic fantasy, no brands.
local NAMES = {
	head = { "Iron Helm", "Hood of the Vigil", "Ashen Coif", "Warden's Greathelm", "Circlet of Dawn" },
	chest = { "Oathsworn Hauberk", "Pilgrim's Robe", "Gambeson", "Ember-Plate Cuirass", "Shadowweave Vest" },
	hands = { "Chain Gauntlets", "Fingerless Wraps", "Templar Gloves", "Ashwood Bracers" },
	legs = { "Tasset Greaves", "Wayfarer Trousers", "Scaled Leggings", "Vigil Legguards" },
	feet = { "Iron Sabatons", "Soft Boots", "Marching Boots", "Ashen Treads" },
	mainHand = { "Longsword", "Kingsguard Blade", "Rondel Dagger", "Ash Hammer", "War Pick", "Pilgrim's Mace" },
	offHand = { "Heater Shield", "Parrying Dagger", "Prayer Tome", "Kite Shield", "Lantern of Vigil" },
	neck = { "Amulet of Embers", "Pilgrim's Token", "Oathstone Pendant" },
	ring = { "Signet of the Warden", "Band of Ash", "Ring of Quiet Steps", "Gilded Loop" },
}

local UNIQUE_EFFECTS = {
	"Parries restore 5% of your HP",
	"Your first hit after a dodge deals 20% more damage",
	"Heals on allies below 30% HP are 15% stronger",
}

-- Weighted rarity roll for the starter bag [Proto].
local RARITY_WEIGHTS = { common = 30, uncommon = 28, rare = 20, epic = 12, legendary = 7, unique = 3 }

type PlayerInv = { items: { [string]: Items.Item }, order: { string }, equipped: { [string]: string }, nextUid: number }

local inventories: { [Player]: PlayerInv } = {}
local service
local remote: RemoteEvent

local function rollRarity(rng: Random): string
	local total = 0
	for _, w in RARITY_WEIGHTS do
		total += w
	end
	local pick = rng:NextNumber() * total
	for _, rarity in Items.RARITIES do
		pick -= RARITY_WEIGHTS[rarity.id]
		if pick <= 0 then
			return rarity.id
		end
	end
	return "common"
end

local function makeItem(inv: PlayerInv, rng: Random, slot: string, rarityId: string, itemLevel: number): Items.Item
	local rarity = Items.rarity(rarityId)
	local pool = table.clone(Items.STAT_ORDER)
	local modifiers = {}
	for _ = 1, rarity.modifiers do
		local stat = table.remove(pool, rng:NextInteger(1, #pool))
		local roll = Items.STATS[stat].roll
		local scale = 1 + 0.02 * (itemLevel - BASE_ITEM_LEVEL)
		table.insert(modifiers, { stat = stat, rating = math.floor(rng:NextInteger(roll[1], roll[2]) * scale) })
	end
	local names = NAMES[slot]
	inv.nextUid += 1
	return {
		uid = tostring(inv.nextUid),
		name = names[rng:NextInteger(1, #names)],
		slot = slot,
		rarity = rarityId,
		itemLevel = itemLevel,
		modifiers = modifiers,
		unique = rarityId == "unique" and UNIQUE_EFFECTS[rng:NextInteger(1, #UNIQUE_EFFECTS)] or nil,
	}
end

local function add(inv: PlayerInv, item: Items.Item)
	inv.items[item.uid] = item
	table.insert(inv.order, item.uid)
end

local function create(player: Player): PlayerInv
	local inv: PlayerInv = { items = {}, order = {}, equipped = {}, nextUid = 0 }
	local rng = Random.new(player.UserId + os.time())
	-- A Common starter set in every slot, equipped.
	for _, slot in Items.SLOTS do
		local item = makeItem(inv, rng, slot.id, "common", BASE_ITEM_LEVEL)
		add(inv, item)
		inv.equipped[slot.id] = item.uid
	end
	-- Loot to try on: one of each rarity first so every colour shows, then random.
	for i = 1, BAG_SIZE do
		local slot = Items.SLOTS[rng:NextInteger(1, #Items.SLOTS)].id
		local rarityId = if i <= #Items.RARITIES then Items.RARITIES[i].id else rollRarity(rng)
		add(inv, makeItem(inv, rng, slot, rarityId, rng:NextInteger(60, 72)))
	end
	return inv
end

-- Ratings and item level from the equipped set. Empty slots count at the starter item level.
local function gearStats(inv: PlayerInv)
	local ratings = {}
	local levels = 0
	for _, slot in Items.SLOTS do
		local item = inv.items[inv.equipped[slot.id] or ""]
		if item then
			levels += item.itemLevel
			for _, m in item.modifiers do
				ratings[m.stat] = (ratings[m.stat] or 0) + m.rating
			end
		else
			levels += BASE_ITEM_LEVEL
		end
	end
	return ratings, levels / #Items.SLOTS
end

local function actorOf(player: Player)
	return service.byPlayer[player]
end

local function applyTo(player: Player)
	local inv = inventories[player]
	local actor = actorOf(player)
	if not inv or not actor then
		return
	end
	local ratings, itemLevel = gearStats(inv)
	actor:refreshGear(ratings, itemLevel)
	local humanoid = actor:humanoid()
	if humanoid then
		humanoid.MaxHealth = actor.maxHealth
		humanoid.Health = actor.health
	end
end

local function snapshot(player: Player, message: string?)
	local inv = inventories[player]
	if not inv then
		return
	end
	local list = {}
	for _, uid in inv.order do
		table.insert(list, inv.items[uid])
	end
	local actor = actorOf(player)
	local stats = nil
	if actor then
		stats = {
			className = actor.kit and actor.kit.id,
			itemLevel = actor.itemLevel,
			wd = actor.wd,
			maxHealth = actor.maxHealth,
			armor = actor.passiveDR,
			derived = actor.stats,
			ratings = actor.ratings,
		}
	end
	remote:FireClient(player, { items = list, equipped = inv.equipped, stats = stats, message = message })
end

local function inCombat(actor): boolean
	return actor ~= nil and service.now - actor.lastCombat < COMBAT_TIMEOUT
end

local function handle(player: Player, req)
	local inv = inventories[player]
	if not inv or typeof(req) ~= "table" then
		return
	end
	if req.op == "sync" then
		snapshot(player)
		return
	end
	local actor = actorOf(player)
	if inCombat(actor) then
		snapshot(player, "Cannot change gear in combat")
		return
	end
	if req.op == "equip" and typeof(req.uid) == "string" then
		local item = inv.items[req.uid]
		if not item then
			return
		end
		inv.equipped[item.slot] = item.uid
	elseif req.op == "unequip" and typeof(req.slot) == "string" and Items.SLOT_BY_ID[req.slot] then
		inv.equipped[req.slot] = nil
	elseif req.op == "unequipAll" then
		table.clear(inv.equipped)
	elseif req.op == "equipBest" then
		-- Highest rarity, then highest item level, per slot.
		for _, slot in Items.SLOTS do
			local best, bestScore = nil, -1
			for _, item in inv.items do
				if item.slot == slot.id then
					local score = Items.rarity(item.rarity).rank * 1000 + item.itemLevel
					if score > bestScore then
						best, bestScore = item, score
					end
				end
			end
			inv.equipped[slot.id] = best and best.uid or nil
		end
	else
		return
	end
	applyTo(player)
	snapshot(player)
end

function Inventory.start(combatService)
	service = combatService
	local folder = ReplicatedStorage:WaitForChild(Net.FOLDER)
	remote = Instance.new("RemoteEvent")
	remote.Name = Net.INVENTORY
	remote.Parent = folder

	local budget: { [Player]: number } = {}
	remote.OnServerEvent:Connect(function(player, req)
		local used = budget[player] or 0
		if used >= 10 then
			return
		end
		budget[player] = used + 1
		task.delay(1, function()
			budget[player] = math.max(0, (budget[player] or 1) - 1)
		end)
		handle(player, req)
	end)

	local function onPlayer(player: Player)
		inventories[player] = create(player)
		-- A new character gets a fresh actor; put the gear back on it once CombatService has made it.
		local function onCharacter(character: Model)
			for _ = 1, 50 do
				local actor = actorOf(player)
				if actor and actor.model == character then
					applyTo(player)
					snapshot(player)
					return
				end
				task.wait(0.1)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
		budget[player] = nil
	end)
end

return Inventory
