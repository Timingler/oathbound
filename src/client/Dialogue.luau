-- The talk box for NPCs (E on their prompt; server/Quests runs the dialogue) and the quest tracker in the top
-- right. While talking, the mouse is free, attacks are not sent, and 1 to 4 pick an answer instead of the hotbar
-- (the "Talking" attribute on the player).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Theme = require(script.Parent.Inventory.Theme)

local Dialogue = {}

local TYPE_SPEED = 70 -- characters per second [Proto]
local OPTION_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

local player = Players.LocalPlayer
local remote: RemoteEvent
local box: Frame
local nameLabel: TextLabel
local textLabel: TextLabel
local optionList: Frame
local tracker: Frame
local current: any = nil
local typing = 0 -- bumped per node, so an older typewriter stops

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

local function corner(): UICorner
	return make("UICorner", { CornerRadius = Theme.corner })
end

local function stroke(color: Color3, transparency: number?): UIStroke
	return make("UIStroke", { Color = color, Thickness = 1, Transparency = transparency or 0 })
end

local function choose(index: number)
	if current and current.options[index] then
		remote:FireServer({ choice = index })
	end
end

local function render(node)
	current = node
	player:SetAttribute("Talking", true)
	box.Visible = true
	nameLabel.Text = string.format('%s  <font color="#968e80" size="14">%s</font>', node.npc, node.title or "")
	for _, child in optionList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	-- Type the line out, then show the answers.
	typing += 1
	local mine = typing
	textLabel.Text = node.text
	textLabel.MaxVisibleGraphemes = 0
	task.spawn(function()
		local shown = 0
		local total = utf8.len(node.text) or #node.text
		while shown < total and typing == mine do
			shown = math.min(total, shown + math.max(1, math.floor(TYPE_SPEED * task.wait())))
			textLabel.MaxVisibleGraphemes = shown
		end
		textLabel.MaxVisibleGraphemes = -1
	end)
	for i, text in node.options do
		local button = make("TextButton", {
			Name = "Option" .. i,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.row,
			BackgroundTransparency = 0.1,
			AutoButtonColor = false,
			RichText = true,
			Text = string.format('<font color="#d6b062">%d.</font>  %s', i, text),
			Font = Theme.body,
			TextSize = 15,
			TextColor3 = Theme.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = optionList,
		}, { corner(), make("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
		button.MouseEnter:Connect(function()
			TweenService:Create(button, Theme.tween, { BackgroundColor3 = Theme.rowHover }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(button, Theme.tween, { BackgroundColor3 = Theme.row }):Play()
		end)
		button.Activated:Connect(function()
			choose(i)
		end)
	end
end

local function hide()
	current = nil
	typing += 1
	box.Visible = false
	player:SetAttribute("Talking", nil)
end

-- Quest tracker: each quest's name, then its steps, the current one bright with its count.
local function renderTracker(list)
	for _, child in tracker:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local order = 0
	local function line(text: string, props)
		order += 1
		local l = make("TextLabel", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			RichText = true,
			TextWrapped = true,
			Text = text,
			Font = Theme.body,
			TextSize = 13,
			TextColor3 = Theme.textDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeTransparency = 0.6,
			Parent = tracker,
		})
		for k, v in props or {} do
			(l :: any)[k] = v
		end
	end
	for _, quest in list do
		line(quest.name .. (if quest.done then "  (complete)" else ""), {
			FontFace = Theme.titleBold,
			TextSize = 16,
			TextColor3 = if quest.done then Theme.textDim else Theme.gold,
		})
		if not quest.done then
			for i, step in quest.steps do
				local count = if step.goal > 1 then string.format("  %d/%d", step.count, step.goal) else ""
				if step.done then
					line("  ✓ " .. step.text, { TextColor3 = Theme.textFaint })
				elseif i == quest.step then
					line("  • " .. step.text .. count, { TextColor3 = Theme.text })
				end
			end
		end
	end
	tracker.Visible = #list > 0
end

local function build()
	local gui = make("ScreenGui", {
		Name = "OathDialogue",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		Parent = player:WaitForChild("PlayerGui"),
	})
	box = make("Frame", {
		Name = "Box",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(620, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = Theme.panelTransparency,
		Visible = false,
		Parent = gui,
	}, {
		corner(),
		stroke(Theme.goldDim),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}),
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	nameLabel = make("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		RichText = true,
		FontFace = Theme.titleBold,
		TextSize = 19,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = box,
	})
	textLabel = make("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextWrapped = true,
		Font = Theme.body,
		TextSize = 16,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = box,
	})
	optionList = make("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = box,
	}, { make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	tracker = make("Frame", {
		Name = "Tracker",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 130),
		Size = UDim2.fromOffset(280, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
end

function Dialogue.start()
	local folder = ReplicatedStorage:WaitForChild(Net.FOLDER)
	remote = folder:WaitForChild(Net.DIALOGUE) :: RemoteEvent
	local questRemote = folder:WaitForChild(Net.QUEST) :: RemoteEvent
	build()
	remote.OnClientEvent:Connect(function(node)
		if typeof(node) ~= "table" then
			return
		end
		if node.close then
			hide()
		else
			render(node)
		end
	end)
	questRemote.OnClientEvent:Connect(function(list)
		if typeof(list) == "table" then
			renderTracker(list)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not current then
			return
		end
		local index = OPTION_KEYS[input.KeyCode]
		if index then
			choose(index)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			remote:FireServer({ close = true })
		end
	end)
	player:GetAttributeChangedSignal("UiOpen"):Connect(function()
		tracker.Parent.Enabled = not player:GetAttribute("UiOpen")
	end)
end

return Dialogue
