-- The hotbar: five round slots along the bottom of the screen, keys 1 to 5. Slot 1 starts with your weapon and the
-- rest with tools (pickaxe, hatchet, rod, torch), so activities are a key away instead of in a menu. Pressing a
-- slot's key takes out what is in it; pressing a tool's key again puts it away and draws the weapon.
-- With the inventory open, hover a weapon or tool and press 1 to 5 to put it in that slot; right-click a slot to
-- empty it. The server owns the layout (server/Inventory); this only shows it and sends requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Theme = require(script.Parent.Inventory.Theme)

local Hotbar = {}

local player = Players.LocalPlayer
local remote: RemoteEvent
local gui: ScreenGui
local bar: Frame
local nameLabel: TextLabel
local hint: TextLabel
local slots = {}
local data: any = nil

local SLOT_SIZE = 62
local GAP = 12
local BOTTOM = 16 -- px above the screen's bottom edge
local BOTTOM_MENU = 78 -- with the inventory open, clear of its bottom buttons

local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

-- The weapon slot's icon follows your class.
local CLASS_ICONS = { Warden = "⚔", Assassin = "🗡", Cleric = "🔨", Ranger = "🏹" }

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function tween(inst: Instance, props: { [string]: any }, info: TweenInfo?)
	TweenService:Create(inst, info or Theme.tween, props):Play()
end

local function itemByUid(uid: string)
	for _, item in data and data.items or {} do
		if item.uid == uid then
			return item
		end
	end
	return nil
end

-- What slot `index` shows: icon and name, or nil when empty.
local function describe(index: number): (string?, string?)
	local entry = data and data.hotbar and data.hotbar[index]
	if not entry then
		return nil
	end
	if entry == "weapon" then
		local className = data.stats and data.stats.className
		local uid = data.equipped and data.equipped.mainHand
		local item = uid and itemByUid(uid)
		return CLASS_ICONS[className] or "⚔", item and item.name or (className and className .. " weapon") or "Weapon"
	end
	local item = itemByUid(entry)
	local tool = item and item.tool and Items.TOOL_BY_ID[item.tool]
	if not tool then
		return nil
	end
	return tool.icon, item.name
end

local function flashName(text: string)
	nameLabel.Text = text
	nameLabel.TextTransparency = 0
	nameLabel.TextStrokeTransparency = 0.4
	task.delay(1.6, function()
		if nameLabel.Text == text then
			tween(nameLabel, { TextTransparency = 1, TextStrokeTransparency = 1 }, Theme.tweenSlow)
		end
	end)
end

local function render()
	for index, slot in slots do
		local icon, name = describe(index)
		local active = data and data.active == index and icon ~= nil
		slot.icon.Text = icon or ""
		slot.name = name
		slot.frame.BackgroundTransparency = if icon then 0.15 else 0.45
		tween(slot.stroke, {
			Color = if active then Theme.gold else Theme.goldDim,
			Thickness = if active then 3 else 2,
			Transparency = if icon then 0 else 0.4,
		})
		tween(slot.scale, { Scale = if active then 1.1 else 1 })
		tween(slot.frame, { BackgroundColor3 = if active then Theme.rowSelected else Theme.panel })
		slot.pip.Visible = active
		slot.key.TextColor3 = if active then Theme.gold else Theme.textDim
	end
end

local function select(index: number)
	remote:FireServer({ op = "hotbarSelect", slot = index })
	local _, name = describe(index)
	if name then
		flashName(name)
	end
end

local function build()
	gui = make("ScreenGui", {
		Name = "OathHotbar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 11, -- above the inventory, which hides the rest of the HUD
		Parent = player:WaitForChild("PlayerGui"),
	})
	local width = Items.HOTBAR_SIZE * SLOT_SIZE + (Items.HOTBAR_SIZE - 1) * GAP
	bar = make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM),
		Size = UDim2.fromOffset(width, SLOT_SIZE + 14),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- A dark band behind the slots, fading out at both ends.
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 14 + SLOT_SIZE / 2),
		Size = UDim2.new(1, 80, 0, 26),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = bar,
	}, {
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0),
				NumberSequenceKeypoint.new(0.85, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 14 + SLOT_SIZE / 2),
		Size = UDim2.new(1, 40, 0, 1),
		BackgroundColor3 = Theme.goldDim,
		BorderSizePixel = 0,
		Parent = bar,
	}, {
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.2),
				NumberSequenceKeypoint.new(0.8, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	for index = 1, Items.HOTBAR_SIZE do
		local x = (index - 1) * (SLOT_SIZE + GAP) + SLOT_SIZE / 2
		local frame = make("TextButton", {
			Name = "Slot" .. index,
			AutoButtonColor = false,
			Text = "",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, 14 + SLOT_SIZE / 2),
			Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
			BackgroundColor3 = Theme.panel,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Parent = bar,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local scale = make("UIScale", { Parent = frame })
		local stroke = make("UIStroke", {
			Color = Theme.goldDim,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
		-- Inner ring, like a medallion.
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -10, 1, -10),
			BackgroundTransparency = 1,
			Parent = frame,
		}, {
			make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			make("UIStroke", { Color = Theme.goldDim, Thickness = 1, Transparency = 0.55 }),
		})
		local icon = make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextSize = 28,
			Font = Theme.bodyBold,
			TextColor3 = Theme.text,
			Parent = frame,
		})
		-- Key badge on the top edge.
		local key = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, -1),
			Size = UDim2.fromOffset(22, 16),
			BackgroundColor3 = Theme.panel,
			BorderSizePixel = 0,
			Text = tostring(index),
			Font = Theme.bodyBold,
			TextSize = 11,
			TextColor3 = Theme.textDim,
			ZIndex = 3,
			Parent = frame,
		}, {
			make("UICorner", { CornerRadius = UDim.new(0, 4) }),
			make("UIStroke", { Color = Theme.goldDim, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		-- Gold pip under the slot in hand.
		local pip = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 5),
			Size = UDim2.fromOffset(14, 3),
			BackgroundColor3 = Theme.gold,
			BorderSizePixel = 0,
			Visible = false,
			Parent = frame,
		}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })

		local slot = { frame = frame, stroke = stroke, scale = scale, icon = icon, key = key, pip = pip, name = nil }
		slots[index] = slot

		frame.MouseEnter:Connect(function()
			if slot.name then
				flashName(slot.name)
			end
			tween(frame, { BackgroundTransparency = 0 })
		end)
		frame.MouseLeave:Connect(function()
			render()
		end)
		frame.Activated:Connect(function()
			if not player:GetAttribute("UiOpen") then
				select(index)
			end
		end)
		frame.MouseButton2Click:Connect(function()
			if player:GetAttribute("UiOpen") then
				remote:FireServer({ op = "hotbarSet", slot = index, uid = nil })
			end
		end)
	end

	nameLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(320, 22),
		BackgroundTransparency = 1,
		Text = "",
		FontFace = Theme.titleBold,
		TextSize = 18,
		TextColor3 = Theme.gold,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = bar,
	})
	hint = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(480, 18),
		BackgroundTransparency = 1,
		Text = "Hover a weapon or tool and press 1 to 5 to place it  ·  right-click a slot to empty it",
		Font = Theme.body,
		TextSize = 12,
		TextColor3 = Theme.textDim,
		Visible = false,
		Parent = bar,
	})
end

local function onMenu()
	local open = player:GetAttribute("UiOpen") == true
	hint.Visible = open
	nameLabel.Visible = not open
	tween(bar, { Position = UDim2.new(0.5, 0, 1, -(if open then BOTTOM_MENU else BOTTOM)) }, Theme.tweenSlow)
end

-- `getHovered` returns the inventory's hovered bag item while it is open (client/Inventory).
function Hotbar.start(getHovered: () -> any)
	remote = ReplicatedStorage:WaitForChild(Net.FOLDER):WaitForChild(Net.INVENTORY) :: RemoteEvent
	build()
	remote.OnClientEvent:Connect(function(snapshot)
		if typeof(snapshot) == "table" and snapshot.hotbar then
			data = snapshot
			render()
		end
	end)
	player:GetAttributeChangedSignal("UiOpen"):Connect(onMenu)

	UserInputService.InputBegan:Connect(function(input)
		local index = KEYS[input.KeyCode]
		if not index or UserInputService:GetFocusedTextBox() then
			return
		end
		if player:GetAttribute("UiOpen") then
			local item = getHovered()
			if item and (item.tool or item.slot == "mainHand") then
				remote:FireServer({ op = "hotbarSet", slot = index, uid = item.uid })
			end
			return
		end
		select(index)
	end)
	remote:FireServer({ op = "sync" })
end

return Hotbar
