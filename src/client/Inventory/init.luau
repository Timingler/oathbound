-- Inventory and equipment screen. I or Tab opens it: the camera swings round to face your character, who stands on
-- a glowing pedestal; equipment slots are on the left, the bag on the right, and actions along the bottom. Hover an
-- item for its modifiers and how it compares with what you wear; click to equip it, or click a worn item to take it
-- off. Layout after the reference avatar menu Charles sent, restyled for classic fantasy.
-- The character stands in a relaxed pose with the weapon put away so the outfit is easy to see. Looking at
-- weapons (the Weapons tab or a weapon slot) or equipping one brings the weapon out in its combat hold.
-- The server owns the bag (server/Inventory.luau); this only asks and draws.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local AssetIds = require(Shared.AssetIds)
local Net = require(Shared.Net)
local Theme = require(script.Theme)
local Effects = require(script.Parent.Effects)

local Inventory = {}

local player = Players.LocalPlayer
local remote: RemoteEvent
local gui: ScreenGui
local ui: any = {}

local data: any = nil -- last snapshot from the server
local isOpen = false
local selectedSlot: string? = nil -- left list filter; nil shows every slot
local tab = "all"
local hovered: any = nil
local orbit = 0 -- camera angle around the character, radians
local orbitTarget = 0
local pedestal: Model? = nil
local savedCameraType: Enum.CameraType? = nil
local neutralTrack: AnimationTrack? = nil
local weaponShown = true
local hiddenParts: { [BasePart]: number } = {} -- weapon part -> its transparency before we hid it
local stanceUntil = 0 -- weapon hold stays out until this clock time after equipping a weapon

local updateStance: () -> () -- defined with the pose helpers below; render() calls it
local STANCE_AFTER_EQUIP = 4 -- seconds [Proto]
local STANCE_FADE = 0.3

local CAMERA_DISTANCE = 10 -- studs in front of the character [Proto]
local CAMERA_HEIGHT = 0.6
-- Movement is stopped by turning the character controls off (see Inventory.open); sinking held movement keys would
-- leave the character walking. These are the action keys a menu should swallow.
local BLOCKED_KEYS = {
	Enum.KeyCode.Q,
	Enum.KeyCode.E,
	Enum.KeyCode.R,
	Enum.KeyCode.T,
	Enum.KeyCode.F,
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
}

----------------------------------------------------------------------------------------------------
-- Building blocks

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: UDim?): UICorner
	return make("UICorner", { CornerRadius = radius or Theme.corner })
end

local function stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return make("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

local function text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.body,
		TextColor3 = Theme.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	if props.FontFace then
		defaults.Font = nil -- Font and FontFace overwrite each other; the caller's FontFace wins
	end
	for k, v in props do
		defaults[k] = v
	end
	return make("TextLabel", defaults)
end

local function title(props: { [string]: any }): TextLabel
	local l = text(props)
	l.FontFace = Theme.titleBold
	return l
end

local function tween(inst: Instance, props: { [string]: any }, info: TweenInfo?)
	TweenService:Create(inst, info or Theme.tween, props):Play()
end

-- A dark panel with a gold hairline and a short gold accent on its top edge, like the reference's panels.
local function panel(props: { [string]: any }): Frame
	local f = make("Frame", {
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = Theme.panelTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, { corner(UDim.new(0, 8)), stroke(Theme.goldDim, 1, 0.35) })
	for k, v in props do
		(f :: any)[k] = v
	end
	make("Frame", {
		Name = "Accent",
		BackgroundColor3 = Theme.gold,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.fromOffset(46, 2),
		Parent = f,
	})
	return f
end

local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	local b = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.row,
		BorderSizePixel = 0,
		Font = Theme.bodyBold,
		TextColor3 = Theme.text,
		TextSize = 13,
	}, { corner(UDim.new(0, 5)), stroke(Theme.goldDim, 1, 0.5) })
	for k, v in props do
		(b :: any)[k] = v
	end
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		tween(b, { BackgroundColor3 = Theme.rowHover })
	end)
	b.MouseLeave:Connect(function()
		tween(b, { BackgroundColor3 = base })
	end)
	b.Activated:Connect(onClick)
	return b
end

local function fmt(n: number): string
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function pct(x: number): string
	return string.format("%.1f%%", x * 100)
end

----------------------------------------------------------------------------------------------------
-- Data helpers

local function equippedIn(slot: string)
	if not data then
		return nil
	end
	local uid = data.equipped[slot]
	if not uid then
		return nil
	end
	for _, item in data.items do
		if item.uid == uid then
			return item
		end
	end
	return nil
end

local function isEquipped(item): boolean
	return data ~= nil and data.equipped[item.slot] == item.uid
end

local function visibleItems()
	local list = {}
	if not data then
		return list
	end
	for _, item in data.items do
		local slot = Items.SLOT_BY_ID[item.slot]
		local okSlot = selectedSlot == nil or item.slot == selectedSlot
		local okTab = tab == "all" or (slot and slot.group == tab)
		if okSlot and okTab then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		local ea, eb = isEquipped(a), isEquipped(b)
		if ea ~= eb then
			return ea
		end
		local ra, rb = Items.rarity(a.rarity).rank, Items.rarity(b.rarity).rank
		if ra ~= rb then
			return ra > rb
		end
		if a.itemLevel ~= b.itemLevel then
			return a.itemLevel > b.itemLevel
		end
		return (Items.SLOT_BY_ID[a.slot].index) < (Items.SLOT_BY_ID[b.slot].index)
	end)
	return list
end

local function ratingsOf(item): { [string]: number }
	local r = {}
	if item then
		for _, m in item.modifiers do
			r[m.stat] = (r[m.stat] or 0) + m.rating
		end
	end
	return r
end

----------------------------------------------------------------------------------------------------
-- Glow: a white light around the part of the body (or the gear) an item sits on, like the reference menu. Soft
-- while hovering, a bright flash and sparkles when it goes on.

local SLOT_LIMBS = {
	head = { "Head" },
	chest = { "Torso" },
	hands = { "Left Arm", "Right Arm" },
	legs = { "Left Leg", "Right Leg" },
	feet = { "Left Leg", "Right Leg" },
	neck = { "Torso" },
	ring = { "Right Arm" },
	mainHand = { "Right Arm" },
	offHand = { "Left Arm" },
}
local GLOW_COLOR = Color3.fromRGB(255, 250, 236)
local glows: { Highlight } = {}

local function clearGlow()
	for _, h in glows do
		h:Destroy()
	end
	table.clear(glows)
end

-- What lights up for `slot`: the gear built for it (server/Gear, server/Weapons), else the bare limbs.
local function glowTargets(slot: string): { Instance }
	local c = player.Character
	if not c then
		return {}
	end
	if slot == "mainHand" then
		local weapon = c:FindFirstChild("OathWeapon")
		if weapon and weaponShown then
			return { weapon }
		end
	else
		local gear = c:FindFirstChild("OathGear")
		local model = gear and gear:FindFirstChild(slot)
		if model then
			return { model }
		end
	end
	local list = {}
	for _, name in SLOT_LIMBS[slot] or {} do
		local part = c:FindFirstChild(name)
		if part then
			table.insert(list, part)
		end
	end
	return list
end

local function firstPart(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	return target:FindFirstChildWhichIsA("BasePart", true)
end

local function glow(slot: string, flash: boolean)
	clearGlow()
	for _, target in glowTargets(slot) do
		local h = Instance.new("Highlight")
		h.Adornee = target
		h.FillColor = GLOW_COLOR
		h.OutlineColor = GLOW_COLOR
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.FillTransparency = 1
		h.OutlineTransparency = 1
		h.Parent = target
		table.insert(glows, h)
		if flash then
			tween(h, { FillTransparency = 0.35, OutlineTransparency = 0 }, TweenInfo.new(0.12))
			task.delay(0.15, function()
				if h.Parent then
					tween(h, { FillTransparency = 0.85, OutlineTransparency = 0.35 }, TweenInfo.new(0.6, Enum.EasingStyle.Quad))
				end
			end)
			-- Sparkles off the piece.
			local part = firstPart(target)
			if part then
				local sparks = Instance.new("ParticleEmitter")
				sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				sparks.Color = ColorSequence.new(GLOW_COLOR)
				sparks.LightEmission = 1
				sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
				sparks.Lifetime = NumberRange.new(0.4, 0.8)
				sparks.Speed = NumberRange.new(3, 6)
				sparks.SpreadAngle = Vector2.new(180, 180)
				sparks.Rate = 0
				sparks.Parent = part
				sparks:Emit(18)
				task.delay(1, function()
					sparks:Destroy()
				end)
			end
		else
			tween(h, { FillTransparency = 0.82, OutlineTransparency = 0.3 })
		end
	end
end

local pendingFlash: string? = nil -- slot to flash once the server has rebuilt its gear

----------------------------------------------------------------------------------------------------
-- Tooltip

local function showTooltip(item)
	hovered = item
	local tip = ui.tooltip
	for _, child in tip.Body:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local rarity = Items.rarity(item.rarity)
	local slot = Items.SLOT_BY_ID[item.slot]
	tip.Stroke.Color = rarity.color
	local order = 0
	local function line(props)
		order += 1
		props.LayoutOrder = order
		props.Size = props.Size or UDim2.new(1, 0, 0, 18)
		props.Parent = tip.Body
		return text(props)
	end
	line({ Text = item.name, TextColor3 = rarity.color, TextSize = 18, FontFace = Theme.titleBold, Size = UDim2.new(1, 0, 0, 24) })
	line({ Text = string.format("%s %s  ·  Item Level %d", rarity.name, slot.name, item.itemLevel), TextColor3 = Theme.textDim, TextSize = 12 })
	if item.class then
		local mine = data and data.stats and data.stats.className
		line({
			Text = item.class .. " only",
			TextColor3 = if item.class == mine then Theme.textDim else Theme.bad,
			TextSize = 12,
			Font = Theme.bodyBold,
		})
	end
	order += 1
	make("Frame", { LayoutOrder = order, BackgroundColor3 = Theme.goldDim, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Parent = tip.Body })
	if #item.modifiers == 0 then
		line({ Text = "No modifiers", TextColor3 = Theme.textFaint, TextSize = 13 })
	end
	for _, m in item.modifiers do
		line({ Text = string.format("+%d %s", m.rating, Items.statName(m.stat)), TextColor3 = Theme.text, TextSize = 14 })
	end
	if item.unique then
		line({ Text = item.unique, TextColor3 = Items.rarity("unique").color, TextSize = 13, TextWrapped = true, Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.GothamMedium })
	end

	-- Compare with the item worn in the same slot.
	local worn = equippedIn(item.slot)
	if worn and worn.uid ~= item.uid then
		order += 1
		make("Frame", { LayoutOrder = order, BackgroundColor3 = Theme.goldDim, BorderSizePixel = 0, BackgroundTransparency = 0.5, Size = UDim2.new(1, 0, 0, 1), Parent = tip.Body })
		line({ Text = "Compared with " .. worn.name, TextColor3 = Theme.textDim, TextSize = 12 })
		local mine, theirs = ratingsOf(item), ratingsOf(worn)
		local dl = item.itemLevel - worn.itemLevel
		if dl ~= 0 then
			line({ Text = string.format("%+d Item Level", dl), TextColor3 = dl > 0 and Theme.good or Theme.bad, TextSize = 13 })
		end
		for _, stat in Items.STAT_ORDER do
			local d = (mine[stat] or 0) - (theirs[stat] or 0)
			if d ~= 0 then
				line({ Text = string.format("%+d %s", d, Items.statName(stat)), TextColor3 = d > 0 and Theme.good or Theme.bad, TextSize = 13 })
			end
		end
	end
	line({
		Text = if isEquipped(item) then "Click to take off" else "Click to equip",
		TextColor3 = Theme.gold,
		TextSize = 12,
		Font = Theme.bodyBold,
	})
	tip.Visible = true
	-- Weapons come out of the relaxed pose while you look at one.
	if item.slot == "mainHand" or item.slot == "offHand" then
		stanceUntil = math.max(stanceUntil, os.clock() + 1.5)
		updateStance()
	end
	glow(item.slot, false)
end

local function hideTooltip(item)
	if hovered == item then
		hovered = nil
		ui.tooltip.Visible = false
		clearGlow()
	end
end

----------------------------------------------------------------------------------------------------
-- Rendering

local function renderSlots()
	for _, slot in Items.SLOTS do
		local row = ui.slotRows[slot.id]
		local item = equippedIn(slot.id)
		local selected = selectedSlot == slot.id
		row.Frame.BackgroundColor3 = selected and Theme.rowSelected or Theme.row
		row.Marker.Visible = selected
		if item then
			local rarity = Items.rarity(item.rarity)
			row.Item.Text = item.name
			row.Item.TextColor3 = rarity.color
			row.Level.Text = "iL " .. item.itemLevel
			row.Icon.Stroke.Color = rarity.color
		else
			row.Item.Text = "Empty"
			row.Item.TextColor3 = Theme.textFaint
			row.Level.Text = ""
			row.Icon.Stroke.Color = Theme.goldDim
		end
	end
end

local function renderStats()
	local s = data and data.stats
	local list = ui.statList
	for _, child in list:GetChildren() do
		if not child:IsA("UIGridStyleLayout") then -- keep the grid layout itself
			child:Destroy()
		end
	end
	if not s then
		return
	end
	local d = s.derived or {}
	local rows = {
		{ "Item Level", string.format("%.1f", s.itemLevel) },
		{ "Weapon Damage", fmt(s.wd) },
		{ "Max HP", fmt(s.maxHealth) },
		{ "Armor", pct(s.armor or 0) },
		{ "Critical Strike", pct(d.critChance or 0) },
		{ "Critical Power", string.format("%.2fx", d.critMult or 1.5) },
		{ "Action Speed", pct(d.actionSpeed or 0) },
		{ "Ability Haste", string.format("%.0f", d.abilityHaste or 0) },
		{ "Healing Power", pct(d.healingPower or 0) },
		{ "Efficiency", string.format("%.0f", d.efficiency or 0) },
		{ "Regeneration", pct(d.regeneration or 0) },
		{ "Vitality", pct(d.vitality or 0) },
	}
	for i, r in rows do
		local f = make("Frame", { LayoutOrder = i, BackgroundTransparency = 1, Size = UDim2.new(0.5, -4, 0, 17), Parent = list })
		text({ Text = r[1], TextColor3 = Theme.textDim, TextSize = 12, Size = UDim2.fromScale(0.62, 1), Parent = f })
		text({
			Text = r[2],
			TextColor3 = i <= 3 and Theme.gold or Theme.text,
			Font = Theme.bodyBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.62, 0),
			Size = UDim2.fromScale(0.38, 1),
			Parent = f,
		})
	end
	ui.header.Sub.Text = string.format("INVENTORY  ·  %s", string.upper(s.className or ""))
end

local function card(item, order: number): Frame
	local rarity = Items.rarity(item.rarity)
	local slot = Items.SLOT_BY_ID[item.slot]
	local worn = isEquipped(item)
	local c = make("TextButton", {
		Name = item.uid,
		LayoutOrder = order,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.card,
		BorderSizePixel = 0,
	}, { corner(UDim.new(0, 6)) })
	local edge = stroke(rarity.color, worn and 2 or 1, worn and 0 or 0.45)
	edge.Parent = c
	-- Rarity wash from the top, like a loot card.
	make("Frame", {
		BackgroundColor3 = rarity.color,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.55, 0),
	}, {
		corner(UDim.new(0, 6)),
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }),
	}).Parent = c
	text({
		Text = slot.icon,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 38),
		Parent = c,
	})
	text({
		Text = item.name,
		TextColor3 = rarity.color,
		Font = Theme.bodyBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 6, 0, 50),
		Size = UDim2.new(1, -12, 0, 16),
		Parent = c,
	})
	text({
		Text = string.format("%s  ·  iL %d", rarity.name, item.itemLevel),
		TextColor3 = Theme.textDim,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 6, 0, 66),
		Size = UDim2.new(1, -12, 0, 14),
		Parent = c,
	})
	if worn then
		make("TextLabel", {
			Text = "WORN",
			Font = Theme.bodyBold,
			TextSize = 9,
			TextColor3 = Theme.panel,
			BackgroundColor3 = Theme.gold,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(34, 14),
			Parent = c,
		}, { corner(UDim.new(0, 3)) })
	end
	c.MouseEnter:Connect(function()
		tween(c, { BackgroundColor3 = Theme.cardHover })
		tween(edge, { Transparency = 0, Thickness = 2 })
		showTooltip(item)
	end)
	c.MouseLeave:Connect(function()
		tween(c, { BackgroundColor3 = Theme.card })
		tween(edge, { Transparency = worn and 0 or 0.45, Thickness = worn and 2 or 1 })
		hideTooltip(item)
	end)
	c.Activated:Connect(function()
		if isEquipped(item) then
			remote:FireServer({ op = "unequip", slot = item.slot })
		else
			remote:FireServer({ op = "equip", uid = item.uid })
			pendingFlash = item.slot
			if Items.SLOT_BY_ID[item.slot].group == "weapon" then
				stanceUntil = os.clock() + STANCE_AFTER_EQUIP
			end
		end
	end)
	return c
end

local function renderBag()
	local grid = ui.grid
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local list = visibleItems()
	for i, item in list do
		card(item, i).Parent = grid
	end
	local slot = selectedSlot and Items.SLOT_BY_ID[selectedSlot]
	ui.bagTitle.Text = slot and slot.name or "Your Bag"
	ui.bagSub.Text = string.format("%d item%s", #list, #list == 1 and "" or "s")
	for id, b in ui.tabButtons do
		local on = id == tab
		b.BackgroundColor3 = on and Theme.rowSelected or Theme.row
		b.TextColor3 = on and Theme.gold or Theme.textDim
	end
	-- Hovered card may have been rebuilt: refresh its tooltip.
	if hovered then
		local still = nil
		for _, item in list do
			if item.uid == hovered.uid then
				still = item
			end
		end
		if still then
			showTooltip(still)
		else
			hovered = nil
			ui.tooltip.Visible = false
		end
	end
end

local function render()
	renderSlots()
	renderStats()
	renderBag()
	updateStance()
end

local function toast(message: string)
	ui.toast.Text = message
	ui.toast.TextTransparency = 0
	ui.toast.Visible = true
	task.delay(2.2, function()
		if ui.toast.Text == message then
			tween(ui.toast, { TextTransparency = 1 }, Theme.tweenSlow)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Layout

local function build()
	gui = make("ScreenGui", {
		Name = "OathInventory",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Darken the edges so the panels read against any background; the middle stays clear for the character.
	make("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, {
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.32, 0.55),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(0.68, 0.55),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})

	ui.root = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })

	-- Header
	local header = panel({ Position = UDim2.new(0.025, 0, 0, 18), Size = UDim2.new(0.95, 0, 0, 44), Parent = ui.root })
	ui.header = header
	title({ Text = "OATHBOUND", TextColor3 = Theme.gold, TextSize = 20, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0, 160, 1, 0), Parent = header })
	make("Frame", { BackgroundColor3 = Theme.goldDim, BorderSizePixel = 0, Position = UDim2.new(0, 168, 0.5, -9), Size = UDim2.fromOffset(1, 18), Parent = header })
	text({ Name = "Sub", Text = "INVENTORY", TextColor3 = Theme.textDim, Font = Theme.bodyBold, TextSize = 12, Position = UDim2.fromOffset(184, 0), Size = UDim2.new(0, 300, 1, 0), Parent = header })
	text({ Text = "I / Tab to close", TextColor3 = Theme.textFaint, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -218, 0, 0), Size = UDim2.new(0, 200, 1, 0), Parent = header })

	-- Left: equipment slots and stats
	local left = panel({ Position = UDim2.new(0.025, 0, 0, 78), Size = UDim2.new(0.25, 0, 1, -170), Parent = ui.root })
	ui.left = left
	title({ Text = "Equipment", TextSize = 24, Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 28), Parent = left })
	text({ Text = "What you wear shapes your build.", TextColor3 = Theme.textDim, TextSize = 12, Position = UDim2.fromOffset(18, 42), Size = UDim2.new(1, -36, 0, 16), Parent = left })

	local slotList = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 68), Size = UDim2.new(1, -24, 0.62, -68), Parent = left }, {
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	ui.slotRows = {}
	for i, slot in Items.SLOTS do
		local row = make("TextButton", {
			LayoutOrder = i,
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Theme.row,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1 / #Items.SLOTS, -4),
			Parent = slotList,
		}, { corner(UDim.new(0, 5)) })
		local marker = make("Frame", { BackgroundColor3 = Theme.gold, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, -8), Position = UDim2.fromOffset(0, 4), Visible = false, Parent = row })
		text({ Text = string.format("%02d", i), TextColor3 = Theme.textFaint, Font = Theme.bodyBold, TextSize = 11, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 20, 1, 0), Parent = row })
		local icon = make("TextLabel", {
			Text = slot.icon,
			TextSize = 16,
			BackgroundColor3 = Theme.panel,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 34, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			Parent = row,
		}, { corner(UDim.new(0, 4)) })
		local iconStroke = stroke(Theme.goldDim, 1, 0.2)
		iconStroke.Name = "Stroke"
		iconStroke.Parent = icon
		text({ Text = string.upper(slot.name), TextColor3 = Theme.textFaint, Font = Theme.bodyBold, TextSize = 9, Position = UDim2.new(0, 68, 0, 3), Size = UDim2.new(1, -120, 0.45, 0), TextYAlignment = Enum.TextYAlignment.Bottom, Parent = row })
		local itemName = text({ Text = "", TextSize = 13, Font = Enum.Font.GothamMedium, Position = UDim2.new(0, 68, 0.45, 0), Size = UDim2.new(1, -120, 0.5, 0), TextYAlignment = Enum.TextYAlignment.Top, Parent = row })
		local level = text({ Text = "", TextColor3 = Theme.textDim, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -54, 0, 0), Size = UDim2.new(0, 44, 1, 0), Parent = row })
		row.MouseEnter:Connect(function()
			if selectedSlot ~= slot.id then
				tween(row, { BackgroundColor3 = Theme.rowHover })
			end
			local item = equippedIn(slot.id)
			if item then
				showTooltip(item)
			end
		end)
		row.MouseLeave:Connect(function()
			if selectedSlot ~= slot.id then
				tween(row, { BackgroundColor3 = Theme.row })
			end
			if hovered then
				hideTooltip(hovered)
			end
		end)
		row.Activated:Connect(function()
			selectedSlot = if selectedSlot == slot.id then nil else slot.id
			tab = "all"
			render()
		end)
		-- Right click takes the item off.
		row.MouseButton2Click:Connect(function()
			if equippedIn(slot.id) then
				remote:FireServer({ op = "unequip", slot = slot.id })
			end
		end)
		ui.slotRows[slot.id] = { Frame = row, Marker = marker, Icon = icon, Item = itemName, Level = level }
	end

	make("Frame", { BackgroundColor3 = Theme.goldDim, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.new(0, 18, 0.62, 6), Size = UDim2.new(1, -36, 0, 1), Parent = left })
	title({ Text = "Attributes", TextSize = 16, Position = UDim2.new(0, 18, 0.62, 12), Size = UDim2.new(1, -36, 0, 20), Parent = left })
	ui.statList = make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0.62, 36), Size = UDim2.new(1, -36, 0.38, -48), Parent = left }, {
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 17), CellPadding = UDim2.fromOffset(12, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Right: the bag
	local right = panel({ Position = UDim2.new(0.725, 0, 0, 78), Size = UDim2.new(0.25, 0, 1, -170), Parent = ui.root })
	ui.right = right
	ui.bagTitle = title({ Text = "Your Bag", TextSize = 24, Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 28), Parent = right })
	ui.bagSub = text({ Text = "", TextColor3 = Theme.textDim, TextSize = 12, Position = UDim2.fromOffset(18, 42), Size = UDim2.new(1, -36, 0, 16), Parent = right })
	local tabs = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 66), Size = UDim2.new(1, -28, 0, 26), Parent = right }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	ui.tabButtons = {}
	for i, t in Items.TABS do
		ui.tabButtons[t.id] = button({ LayoutOrder = i, Text = t.name, TextSize = 12, Size = UDim2.new(0.25, -5, 1, 0), Parent = tabs }, function()
			tab = t.id
			selectedSlot = nil
			render()
		end)
	end
	ui.grid = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 102),
		Size = UDim2.new(1, -28, 1, -114),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.goldDim,
		Parent = right,
	}, {
		make("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 88), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }),
	})

	-- Bottom bar
	local bottom = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(560, 38),
		Parent = ui.root,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	ui.bottom = bottom
	button({ LayoutOrder = 1, Text = "◀", Size = UDim2.fromOffset(38, 38) }, function()
		orbitTarget -= math.rad(45)
	end).Parent = bottom
	button({ LayoutOrder = 2, Text = "▶", Size = UDim2.fromOffset(38, 38) }, function()
		orbitTarget += math.rad(45)
	end).Parent = bottom
	button({ LayoutOrder = 3, Text = "Equip best", Size = UDim2.fromOffset(130, 38) }, function()
		remote:FireServer({ op = "equipBest" })
	end).Parent = bottom
	button({ LayoutOrder = 4, Text = "Take off all", Size = UDim2.fromOffset(130, 38) }, function()
		remote:FireServer({ op = "unequipAll" })
	end).Parent = bottom
	button({ LayoutOrder = 5, Text = "Close", Size = UDim2.fromOffset(100, 38), TextColor3 = Theme.gold }, function()
		Inventory.close()
	end).Parent = bottom

	-- Character name plate above the pedestal, like the reference.
	ui.plate = make("TextLabel", {
		Text = player.DisplayName,
		FontFace = Theme.titleBold,
		TextSize = 16,
		TextColor3 = Theme.text,
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(180, 30),
		Parent = ui.root,
	}, { corner(UDim.new(0, 5)), stroke(Theme.goldDim, 1, 0.3) })

	ui.toast = text({
		Text = "",
		Visible = false,
		TextColor3 = Theme.bad,
		Font = Theme.bodyBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -74),
		Size = UDim2.fromOffset(400, 24),
		TextStrokeTransparency = 0.4,
		Parent = ui.root,
	})

	-- Tooltip, follows the mouse.
	local tip = make("Frame", {
		Name = "Tooltip",
		Visible = false,
		ZIndex = 20,
		BackgroundColor3 = Color3.fromRGB(10, 9, 8),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(270, 0),
		Parent = gui,
	}, { corner(UDim.new(0, 6)), padding(12) })
	local tipStroke = stroke(Theme.gold, 1.5, 0)
	tipStroke.Name = "Stroke"
	tipStroke.Parent = tip
	make("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 20,
		Parent = tip,
	}, { make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })
	ui.tooltip = tip

	-- A button as well as the key, bottom right of the HUD: the I key never reaches the game while Studio's focus is
	-- in another panel or a text box, and a click always works.
	local hintGui = make("ScreenGui", { Name = "OathInventoryHint", ResetOnSpawn = false, Parent = player.PlayerGui })
	local hint = make("TextButton", {
		Text = "[I]  Inventory",
		TextColor3 = Theme.gold,
		Font = Theme.bodyBold,
		TextSize = 14,
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.15,
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -14),
		Size = UDim2.fromOffset(140, 32),
		Parent = hintGui,
	}, { corner(UDim.new(0, 6)), make("UIStroke", { Color = Theme.goldDim, Thickness = 1 }) })
	hint.Activated:Connect(function()
		Inventory.toggle()
	end)
	ui.hintGui = hintGui
end

----------------------------------------------------------------------------------------------------
-- Pose: neutral to show the outfit, weapon stance to show the weapon

local function weaponFocus(): boolean
	if os.clock() < stanceUntil or tab == "weapon" then
		return true
	end
	local slot = selectedSlot and Items.SLOT_BY_ID[selectedSlot]
	return slot ~= nil and slot.group == "weapon"
end

-- Hides or shows the weapon on this client only (server/Weapons puts it in an "OathWeapon" folder).
local function showWeapon(show: boolean)
	if show == weaponShown then
		return
	end
	weaponShown = show
	if show then
		for part, transparency in hiddenParts do
			if part.Parent then
				part.Transparency = transparency
			end
		end
		table.clear(hiddenParts)
		return
	end
	local c = player.Character
	local folder = c and c:FindFirstChild("OathWeapon")
	if not folder then
		return
	end
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") then
			hiddenParts[part] = part.Transparency
			part.Transparency = 1
		end
	end
end

-- The relaxed idle, played over the weapon hold (which is Idle priority) while the menu is open.
local function neutral(): AnimationTrack?
	if neutralTrack then
		return neutralTrack
	end
	local c = player.Character
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = AssetIds.uri(AssetIds.Move.Idle)
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	neutralTrack = track
	return track
end

function updateStance()
	local weapon = isOpen and weaponFocus()
	local track = isOpen and neutral() or neutralTrack
	if track then
		if isOpen and not weapon then
			if not track.IsPlaying then
				track:Play(STANCE_FADE)
			end
		elseif track.IsPlaying then
			track:Stop(STANCE_FADE)
		end
	end
	showWeapon(not isOpen or weapon)
end

----------------------------------------------------------------------------------------------------
-- Pedestal and camera

local function character(): (Model?, BasePart?)
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	return c, root
end

local function buildPedestal(root: BasePart)
	local floor = Effects.ground(root.Position)
	local model = Instance.new("Model")
	model.Name = "OathPedestal"
	local function disc(diameter: number, height: number, color: Color3, material: Enum.Material, transparency: number, y: number)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(height, diameter, diameter)
		p.CFrame = CFrame.new(floor + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Color = color
		p.Material = material
		p.Transparency = transparency
		p.Parent = model
		return p
	end
	disc(7.2, 0.3, Color3.fromRGB(30, 27, 24), Enum.Material.Slate, 0, 0.0)
	local ring = disc(7.6, 0.08, Theme.gold, Enum.Material.Neon, 0.25, 0.12)
	disc(5.4, 0.1, Theme.gold, Enum.Material.Neon, 0.7, 0.18)
	disc(5.1, 0.12, Color3.fromRGB(22, 20, 18), Enum.Material.Slate, 0, 0.19)

	local light = Instance.new("PointLight")
	light.Color = Theme.gold
	light.Brightness = 1.6
	light.Range = 12
	light.Parent = ring

	-- Embers rising off the rim.
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(Theme.gold)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	motes.Lifetime = NumberRange.new(1.4, 2.4)
	motes.Rate = 18
	motes.Speed = NumberRange.new(1.2, 2.4)
	motes.SpreadAngle = Vector2.new(8, 8)
	motes.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up after the 90 degree turn
	motes.Shape = Enum.ParticleEmitterShape.Cylinder
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	motes.Parent = ring

	model.Parent = workspace
	pedestal = model

	-- Slow pulse on the ring.
	task.spawn(function()
		local up = true
		while pedestal == model and model.Parent do
			tween(ring, { Transparency = up and 0.05 or 0.45 }, TweenInfo.new(1.2, Enum.EasingStyle.Sine))
			up = not up
			task.wait(1.2)
		end
	end)
end

local function cameraTarget(root: BasePart): CFrame
	local focus = root.Position + Vector3.new(0, CAMERA_HEIGHT, 0)
	local facing = CFrame.lookAt(root.Position, root.Position + Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z))
	local offset = (facing * CFrame.Angles(0, orbit, 0)).LookVector * CAMERA_DISTANCE
	return CFrame.lookAt(focus + offset + Vector3.new(0, 0.8, 0), focus)
end

----------------------------------------------------------------------------------------------------
-- Open / close

-- Roblox's default control module (PlayerModule), whose Disable() drops any held movement.
local function playerControls(): any
	local ok, controls = pcall(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 2)
		return module and (require(module) :: any):GetControls()
	end)
	return if ok then controls else nil
end

local function sinkKeys()
	return Enum.ContextActionResult.Sink
end

function Inventory.open()
	local _, root = character()
	if isOpen or not root then
		return
	end
	isOpen = true
	player:SetAttribute("UiOpen", true)
	-- Stop walking: a key held when the menu opens would otherwise keep the character moving out of frame.
	local controls = playerControls()
	if controls then
		controls:Disable()
	end
	local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero)
	end
	root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	ContextActionService:BindActionAtPriority("OathInventoryBlock", sinkKeys, false, Enum.ContextActionPriority.High.Value + 50, table.unpack(BLOCKED_KEYS))
	remote:FireServer({ op = "sync" })

	orbit, orbitTarget = 0, 0
	buildPedestal(root)
	local camera = workspace.CurrentCamera
	savedCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	tween(camera, { CFrame = cameraTarget(root) }, Theme.tweenSlow)

	gui.Enabled = true
	-- Panels slide in from their edges.
	ui.left.Position = UDim2.new(-0.3, 0, 0, 78)
	ui.right.Position = UDim2.new(1.05, 0, 0, 78)
	ui.bottom.Position = UDim2.new(0.5, 0, 1, 40)
	tween(ui.left, { Position = UDim2.new(0.025, 0, 0, 78) }, Theme.tweenSlow)
	tween(ui.right, { Position = UDim2.new(0.725, 0, 0, 78) }, Theme.tweenSlow)
	tween(ui.bottom, { Position = UDim2.new(0.5, 0, 1, -24) }, Theme.tweenSlow)
	render()
end

function Inventory.close()
	if not isOpen then
		return
	end
	isOpen = false
	hovered = nil
	pendingFlash = nil
	clearGlow()
	ui.tooltip.Visible = false
	local controls = playerControls()
	if controls then
		controls:Enable()
	end
	gui.Enabled = false
	player:SetAttribute("UiOpen", nil)
	ContextActionService:UnbindAction("OathInventoryBlock")
	stanceUntil = 0
	updateStance()
	if pedestal then
		pedestal:Destroy()
		pedestal = nil
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = savedCameraType or Enum.CameraType.Custom
end

function Inventory.toggle()
	if isOpen then
		Inventory.close()
	else
		Inventory.open()
	end
end

----------------------------------------------------------------------------------------------------

function Inventory.start()
	build()
	local remotes = ReplicatedStorage:WaitForChild(Net.FOLDER)
	remote = remotes:WaitForChild(Net.INVENTORY) :: RemoteEvent
	remote.OnClientEvent:Connect(function(snap)
		data = snap
		if snap.message and isOpen then
			toast(snap.message)
		end
		if isOpen then
			render()
			local slot = pendingFlash
			pendingFlash = nil
			if slot then
				-- The server rebuilt the piece just before this; give the new parts a moment to arrive.
				task.delay(0.12, function()
					if isOpen then
						glow(slot, true)
					end
				end)
			end
		end
	end)
	remote:FireServer({ op = "sync" })

	-- I (or Tab) toggles it. Read straight from UserInputService so nothing else bound to the key, such as the
	-- camera's keyboard zoom, can swallow it; ignored only while typing in a text box (chat).
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.I and input.KeyCode ~= Enum.KeyCode.Tab then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		Inventory.toggle()
	end)
	-- Keep the camera from zooming on I while the key opens the menu.
	ContextActionService:BindActionAtPriority("OathInventoryKey", function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 60, Enum.KeyCode.I, Enum.KeyCode.Tab)

	player.CharacterAdded:Connect(function()
		Inventory.close()
		neutralTrack = nil
		weaponShown = true
		table.clear(hiddenParts)
	end)

	-- Drag with the right mouse button to turn the view.
	local dragging = false
	UserInputService.InputBegan:Connect(function(input, processed)
		if isOpen and input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
			dragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if isOpen and dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			orbitTarget -= input.Delta.X * 0.01
		end
	end)

	RunService:BindToRenderStep("OathInventory", Enum.RenderPriority.Camera.Value + 5, function(dt)
		if not isOpen then
			return
		end
		local _, root = character()
		if not root then
			Inventory.close()
			return
		end
		if stanceUntil > 0 and os.clock() >= stanceUntil then
			stanceUntil = 0
			updateStance()
		end
		-- Ease the orbit and keep the camera on the character.
		local before = orbit
		orbit += (orbitTarget - orbit) * math.min(1, dt * 8)
		if math.abs(orbit - before) > 1e-4 or math.abs(orbitTarget - orbit) > 1e-3 then
			workspace.CurrentCamera.CFrame = cameraTarget(root)
		end
		if ui.tooltip.Visible then
			local mouse = UserInputService:GetMouseLocation()
			local size = ui.tooltip.AbsoluteSize
			local screen = gui.AbsoluteSize
			local x = mouse.X + 18
			if x + size.X > screen.X - 8 then
				x = mouse.X - size.X - 18
			end
			local y = math.clamp(mouse.Y + 12, 8, math.max(8, screen.Y - size.Y - 8))
			ui.tooltip.Position = UDim2.fromOffset(x, y)
		end
	end)
end

return Inventory
