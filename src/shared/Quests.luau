-- Quest and dialogue content for the arena, read by server/Quests (and client/Dialogue for display). [Proto]:
-- placeholder writing until the real story exists. Follows the GDD: quests teach and reward, they never gate
-- anything behind a grind.

local Quests = {}

-- A quest is a list of steps; each step counts an event up to `goal`. Rewards are rolled by server/Inventory.
Quests.LIST = {
	trial = {
		name = "The Arena Trial",
		giver = "aldric",
		steps = {
			{ text = "Strike the training dummy", event = "hitDummy", goal = 10 },
			{ text = "Climb the rock mesa west of the spawn", event = "reachMesa", goal = 1 },
			{ text = "Defeat the Hollow Duelist", event = "killDuelist", goal = 1 },
			{ text = "Return to Sergeant Aldric", event = "talk:aldric", goal = 1 },
		},
		reward = "rare",
	},
}

-- Dialogue trees per NPC. Each node has text and options; an option goes `to` another node, runs an `action`
-- (handled by server/Quests), or ends the talk. `when` picks the start node from the player's quest state.
Quests.NPCS = {
	aldric = {
		name = "Sergeant Aldric",
		title = "Arena Warden",
		start = function(state)
			local q = state.trial
			if not q then
				return "greet"
			elseif q.done then
				return "after"
			elseif q.step == 4 then
				return "turnIn"
			end
			return "progress"
		end,
		nodes = {
			greet = {
				text = "Another blade for the arena. Before you go hunting the Ashen Sentinel, show me you can handle yourself.",
				options = {
					{ text = "What do you need?", to = "offer" },
					{ text = "Who is the Sentinel?", to = "lore" },
					{ text = "Not now." },
				},
			},
			lore = {
				text = "A knight of the old watch, burned hollow. It guards the far ring. Step inside and it will come for you, so mind the floor: every blow it throws is marked there first.",
				options = {
					{ text = "And the trial?", to = "offer" },
					{ text = "I'll keep my distance." },
				},
			},
			offer = {
				text = "Strike the straw man ten times. Climb the mesa to the west. Then put the Hollow Duelist down and come back to me.",
				options = {
					{ text = "I'll do it.", action = "accept:trial" },
					{ text = "Maybe later." },
				},
			},
			progress = {
				text = "The trial is not done. Check your list, top right.",
				options = { { text = "On my way." } },
			},
			turnIn = {
				text = "The Duelist fell? Good work. Take this; you have earned it.",
				options = { { text = "Thank you.", action = "complete:trial" } },
			},
			after = {
				text = "You are ready for the Sentinel. Burn bright, and do not stand in the fire.",
				options = { { text = "Farewell." } },
			},
		},
	},
}

return Quests
