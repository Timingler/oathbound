-- Remote names shared by server and client. The server creates them under ReplicatedStorage.Remotes.

return {
	FOLDER = "Remotes",
	ACTION = "Action", -- client -> server: input requests
	STATE = "State", -- server -> client: HUD snapshot, about 10 per second
	FX = "Fx", -- server -> client: hits, heals, log lines
	INVENTORY = "Inventory", -- both ways: client sends { op = "sync" | "equip" | "unequip" | ... }, server sends the bag

	-- Request kinds sent on ACTION
	Request = {
		BASIC = "basic",
		HEAVY = "heavy",
		SKILL = "skill", -- with slot 1..3 (Q, E, R)
		SIGNATURE = "signature", -- own key (T), Warden Intercept in the prototype
		ULTIMATE = "ultimate", -- F, not built yet
		BLOCK_START = "blockStart",
		BLOCK_END = "blockEnd",
		DODGE = "dodge",
		CLASS = "class", -- with class name, out of combat only
	},

	SNAPSHOT_RATE = 0.1,
	MAX_REQUESTS_PER_SECOND = 30,
}
