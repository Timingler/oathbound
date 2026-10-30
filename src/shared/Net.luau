-- Remote names shared by server and client. The server creates them under ReplicatedStorage.Remotes.

return {
	FOLDER = "Remotes",
	ACTION = "Action", -- client -> server: input requests
	STATE = "State", -- server -> client: HUD snapshot, about 10 per second
	FX = "Fx", -- server -> client: hits, heals, log lines
	INVENTORY = "Inventory", -- both ways: client sends { op = "sync" | "equip" | "unequip" | ... }, server sends the bag
	DIALOGUE = "Dialogue", -- server -> client: a talk box node or { close = true }; client -> server: { choice = n }
	QUEST = "Quest", -- server -> client: the quest tracker's list

	-- Request kinds sent on ACTION
	Request = {
		BASIC = "basic",
		HEAVY = "heavy",
		SKILL = "skill", -- with slot 1..3 (Z, X, C)
		SIGNATURE = "signature", -- own key (V), Warden Intercept in the prototype
		ULTIMATE = "ultimate", -- F, not built yet
		BLOCK_START = "blockStart",
		BLOCK_END = "blockEnd",
		DODGE = "dodge",
		CLASS = "class", -- with class name, out of combat only
		AIM_START = "aimStart", -- Ranger: right click held, the bow starts drawing
		AIM_END = "aimEnd",
		EXERT_START = "exertStart", -- with mode "sprint" | "climb" | "glide" (client/Sprint, client/Traversal)
		EXERT_END = "exertEnd",
		JUMP = "jump", -- the character jumped or leapt off a wall: costs stamina
	},

	SNAPSHOT_RATE = 0.1,
	MAX_REQUESTS_PER_SECOND = 30,
}
