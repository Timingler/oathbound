-- NPCs you talk to with E, their dialogue, and quest progress. Content is in shared/Quests; client/Dialogue shows
-- the talk box and the quest tracker. Quest state lives here per player and is not saved yet (no DataStore in
-- the prototype).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Content = require(Shared.Quests)
local AssetIds = require(Shared.AssetIds)

local Quests = {}

local TALK_RANGE = 10 -- studs to start talking [Proto]
local LEAVE_RANGE = 16 -- walk this far away and the talk closes [Proto]

-- Where each NPC stands, and what they wear (shared/Items outfits).
local POSTS = {
	aldric = {
		cframe = CFrame.lookAt(Vector3.new(14, 3.05, -48), Vector3.new(0, 3.05, -40)),
		shirt = "rbxassetid://9793008658", -- Templar Vestments (Excry)
		pants = "rbxassetid://9793004800",
		tint = Color3.fromRGB(210, 200, 186),
	},
}

local service
local inventory
local dialogueRemote: RemoteEvent
local questRemote: RemoteEvent
local states: { [Player]: { [string]: any } } = {}
local talking: { [Player]: { npc: string, node: string, model: Model } } = {}
local npcModels: { [string]: Model } = {}

local function stateOf(player: Player)
	local s = states[player]
	if not s then
		s = {}
		states[player] = s
	end
	return s
end

-- The tracker: every quest in progress or done, with its steps.
local function push(player: Player)
	local list = {}
	for id, q in stateOf(player) do
		local def = Content.LIST[id]
		local steps = {}
		for i, step in def.steps do
			table.insert(steps, {
				text = step.text,
				count = if i == q.step then q.count else (if i < q.step or q.done then step.goal else 0),
				goal = step.goal,
				done = q.done or i < q.step,
			})
		end
		table.insert(list, { id = id, name = def.name, steps = steps, step = q.step, done = q.done })
	end
	questRemote:FireClient(player, list)
end

local function close(player: Player)
	if talking[player] then
		talking[player] = nil
		dialogueRemote:FireClient(player, { close = true })
	end
end

local function show(player: Player, npcId: string, nodeId: string)
	local npc = Content.NPCS[npcId]
	local node = npc.nodes[nodeId]
	talking[player] = { npc = npcId, node = nodeId, model = npcModels[npcId] }
	local options = {}
	for _, option in node.options do
		table.insert(options, option.text)
	end
	dialogueRemote:FireClient(player, { npc = npc.name, title = npc.title, text = node.text, options = options })
end

local function runAction(player: Player, action: string)
	local verb, id = string.match(action, "^(%w+):(%w+)$")
	local def = id and Content.LIST[id]
	if not def then
		return
	end
	local state = stateOf(player)
	if verb == "accept" and not state[id] then
		state[id] = { step = 1, count = 0, done = false }
		service.log(service.byPlayer[player], "Quest started: " .. def.name)
	elseif verb == "complete" and state[id] and not state[id].done and state[id].step == #def.steps then
		state[id].done = true
		local reward = inventory.grant(player, def.reward)
		service.log(service.byPlayer[player], "Quest complete: " .. def.name .. (if reward then ". Reward: " .. reward else ""))
	end
	push(player)
end

-- Something happened that quests may count: `event` for `actor`'s player (shared/Quests step events).
function Quests.event(actor, event: string, amount: number?)
	local player = actor and actor.player
	if not player then
		return
	end
	for id, q in stateOf(player) do
		local def = Content.LIST[id]
		local step = not q.done and def.steps[q.step]
		if step and step.event == event then
			q.count += amount or 1
			if q.count >= step.goal then
				q.step += 1
				q.count = 0
				service.log(actor, "Objective complete: " .. step.text)
			end
			push(player)
		end
	end
end

local function buildNpc(id: string, post): Model
	local def = Content.NPCS[id]
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = Color3.fromRGB(204, 170, 140)
	local model = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R6)
	model.Name = def.name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	for _, c in model:GetChildren() do
		if c:IsA("Shirt") or c:IsA("Pants") then
			c:Destroy()
		end
	end
	local shirt = Instance.new("Shirt")
	shirt.ShirtTemplate = post.shirt
	shirt.Color3 = post.tint
	shirt.Parent = model
	local pants = Instance.new("Pants")
	pants.PantsTemplate = post.pants
	pants.Color3 = post.tint
	pants.Parent = model
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	model.PrimaryPart = root
	model:PivotTo(post.cframe)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.RichText = true
	label.Text = string.format('<font color="#d6b062">%s</font>\n<font size="12">%s</font>', def.name, def.title)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Parent = gui
	gui.Parent = model:FindFirstChild("Head")

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = def.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = TALK_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		if not talking[player] then
			show(player, id, def.start(stateOf(player)))
		end
	end)

	model.Parent = workspace
	-- The movement kit's idle, so they breathe instead of standing stiff.
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local idle = Instance.new("Animation")
	idle.AnimationId = AssetIds.uri(AssetIds.Move.Idle)
	local track = animator:LoadAnimation(idle)
	track.Looped = true
	track:Play()
	npcModels[id] = model
	return model
end

function Quests.start(combatService, inventoryModule)
	service = combatService
	inventory = inventoryModule
	local folder = ReplicatedStorage:WaitForChild(Net.FOLDER)
	dialogueRemote = Instance.new("RemoteEvent")
	dialogueRemote.Name = Net.DIALOGUE
	dialogueRemote.Parent = folder
	questRemote = Instance.new("RemoteEvent")
	questRemote.Name = Net.QUEST
	questRemote.Parent = folder

	for id, post in POSTS do
		buildNpc(id, post)
	end

	-- The player picked option `choice` of the node they are on.
	dialogueRemote.OnServerEvent:Connect(function(player, req)
		local talk = talking[player]
		if not talk or typeof(req) ~= "table" then
			return
		end
		if req.close then
			close(player)
			return
		end
		local node = Content.NPCS[talk.npc].nodes[talk.node]
		local option = typeof(req.choice) == "number" and node.options[req.choice]
		if not option then
			return
		end
		if option.action then
			runAction(player, option.action)
		end
		if option.to then
			show(player, talk.npc, option.to)
		else
			close(player)
		end
	end)

	-- Reaching the mesa top, and walking away from a talk.
	local mesa = workspace:FindFirstChild("Arena") and workspace.Arena:FindFirstChild("Mesa") :: BasePart?
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		for player, talk in talking do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or (root.Position - talk.model:GetPivot().Position).Magnitude > LEAVE_RANGE then
				close(player)
			end
		end
		if not mesa then
			return
		end
		local top = mesa.Position.Y + mesa.Size.Y / 2
		for player, state in states do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Y > top + 1 and root.Position.Y < top + 8 then
				local offset = mesa.CFrame:PointToObjectSpace(root.Position)
				if math.abs(offset.X) <= mesa.Size.X / 2 and math.abs(offset.Z) <= mesa.Size.Z / 2 then
					Quests.event(service.byPlayer[player], "reachMesa")
				end
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(push, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		talking[player] = nil
	end)
end

return Quests
