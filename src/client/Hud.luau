-- Placeholder HUD built from code: your bars and cooldowns, the boss bar with its Break meter,
-- attack warnings, the training dummy meter and a combat log. Function over looks for now.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Hud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local ui = {}
local logLines = {}
local myId: number? = nil

local WARNING = {
	white = { text = "block, dodge or parry", color = Color3.fromRGB(240, 240, 240) },
	orange = { text = "dodge or parry (block fails)", color = Color3.fromRGB(255, 150, 40) },
	red = { text = "dodge or get out", color = Color3.fromRGB(255, 70, 70) },
}

local function fmt(n: number): string
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function label(parent: Instance, props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.TextSize = 14
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- A bar with a fill and a text overlay. Returns a setter.
local function bar(parent: Instance, position: UDim2, size: UDim2, color: Color3)
	local back = frame(parent, { Position = position, Size = size, BackgroundColor3 = Color3.fromRGB(25, 25, 28) })
	local fill = frame(back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color })
	local text = label(back, { Size = UDim2.fromScale(1, 1), TextSize = 13 })
	return function(value: number, max: number, caption: string, newColor: Color3?)
		fill.Size = UDim2.fromScale(max > 0 and math.clamp(value / max, 0, 1) or 0, 1)
		text.Text = caption
		if newColor then
			fill.BackgroundColor3 = newColor
		end
	end, back
end

function Hud.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "OathboundHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	-- The inventory screen (client/Inventory) covers the whole view; the combat HUD would show through it.
	player:GetAttributeChangedSignal("UiOpen"):Connect(function()
		gui.Enabled = not player:GetAttribute("UiOpen")
	end)

	-- Boss, top centre
	ui.bossName = label(gui, { Position = UDim2.new(0.5, -250, 0, 18), Size = UDim2.fromOffset(500, 20), Font = Enum.Font.GothamBold, TextSize = 16 })
	ui.bossHp = bar(gui, UDim2.new(0.5, -250, 0, 40), UDim2.fromOffset(500, 20), Color3.fromRGB(170, 40, 40))
	ui.bossBreak = bar(gui, UDim2.new(0.5, -250, 0, 62), UDim2.fromOffset(500, 10), Color3.fromRGB(240, 200, 60))
	ui.bossCast = bar(gui, UDim2.new(0.5, -150, 0, 78), UDim2.fromOffset(300, 16), Color3.fromRGB(150, 90, 220))
	ui.warning = label(gui, { Position = UDim2.new(0.5, -300, 0, 100), Size = UDim2.fromOffset(600, 34), Font = Enum.Font.GothamBlack, TextSize = 26 })

	-- You, bottom centre
	ui.hp = bar(gui, UDim2.new(0.5, -200, 1, -150), UDim2.fromOffset(400, 22), Color3.fromRGB(60, 180, 80))
	ui.res = bar(gui, UDim2.new(0.5, -200, 1, -124), UDim2.fromOffset(400, 14), Color3.fromRGB(240, 210, 80))
	ui.stamina = bar(gui, UDim2.new(0.5, -200, 1, -106), UDim2.fromOffset(400, 8), Color3.fromRGB(120, 170, 230))
	ui.state = label(gui, { Position = UDim2.new(0.5, -200, 1, -176), Size = UDim2.fromOffset(400, 20) })
	ui.slots = {}
	for i, key in { "LMB", "Q", "E", "R", "T" } do
		local box = frame(gui, {
			Position = UDim2.new(0.5, -200 + (i - 1) * 82, 1, -92),
			Size = UDim2.fromOffset(76, 56),
			BackgroundColor3 = Color3.fromRGB(30, 30, 36),
			BackgroundTransparency = 0.15,
		})
		local name = label(box, { Size = UDim2.new(1, -4, 0, 30), Position = UDim2.fromOffset(2, 2), TextWrapped = true, TextSize = 11 })
		local cd = label(box, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 32), Font = Enum.Font.GothamBold, TextSize = 16 })
		label(box, { Size = UDim2.fromOffset(30, 12), Position = UDim2.fromOffset(2, 0), Text = key, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(180, 180, 190) })
		ui.slots[key] = { name = name, cd = cd, box = box }
	end

	-- Help, top left
	label(gui, {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(330, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 12,
		TextWrapped = true,
		Text = "LMB tap: basic   LMB hold: heavy\nRMB hold: block (first 200 ms parries)\nSpace: dodge   Q / E / R: skills\nT: Intercept (Warden)   F: ultimate (later)\n1 Assassin   2 Cleric   3 Warden   4 Ranger (out of combat)\nLeft Alt: free the mouse",
	})
	ui.class = label(gui, { Position = UDim2.fromOffset(12, 36), Size = UDim2.fromOffset(330, 20), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextSize = 16 })

	-- Dummy meter and log, right side
	ui.meter = label(gui, {
		Position = UDim2.new(1, -332, 0, 60),
		Size = UDim2.fromOffset(320, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 13,
	})
	ui.log = label(gui, {
		Position = UDim2.new(1, -332, 1, -260),
		Size = UDim2.fromOffset(320, 160),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextSize = 12,
		TextWrapped = true,
	})
end

function Hud.addLog(text: string)
	table.insert(logLines, text)
	while #logLines > 10 do
		table.remove(logLines, 1)
	end
	ui.log.Text = table.concat(logLines, "\n")
end

local function floatText(pos: Vector3?, text: string, color: Color3)
	if not pos then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = pos + Vector3.new(math.random(-15, 15) / 10, 4, 0)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 30)
	billboard.AlwaysOnTop = true
	local l = label(billboard, { Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color, Font = Enum.Font.GothamBlack, TextSize = 20 })
	l.TextStrokeTransparency = 0.2
	billboard.Parent = anchor
	anchor.Parent = workspace
	task.spawn(function()
		for _ = 1, 20 do
			anchor.Position += Vector3.new(0, 0.12, 0)
			task.wait(0.03)
		end
	end)
	Debris:AddItem(anchor, 0.8)
end

function Hud.onFx(event)
	local t = event.t
	if t == "log" then
		Hud.addLog(event.text)
	elseif t == "hit" and event.src == myId then
		floatText(event.pos, fmt(event.amount) .. (event.crit and "!" or ""), event.crit and Color3.fromRGB(255, 220, 60) or Color3.new(1, 1, 1))
	elseif t == "heal" and (event.src == myId or event.dst == myId) then
		floatText(event.pos, "+" .. fmt(event.amount), Color3.fromRGB(90, 230, 110))
	elseif t == "hurt" and event.dst == myId then
		floatText(event.pos, "-" .. fmt(event.amount), Color3.fromRGB(255, 80, 80))
	elseif t == "avoid" and (event.dst == myId or event.src == myId) then
		floatText(event.pos, event.text, Color3.fromRGB(150, 210, 255))
	elseif t == "broken" then
		Hud.addLog("The boss is BROKEN: 3 s free hits")
	elseif t == "bossDead" then
		Hud.addLog("The Ashen Sentinel falls. It returns in 15 s.")
	end
end

function Hud.onState(snap)
	local me = snap.self
	myId = me.id
	ui.class.Text = me.class .. (me.dead and "  (dead)" or "")

	ui.hp(me.hp, me.maxHp, string.format("%s / %s%s", fmt(me.hp), fmt(me.maxHp), me.shield > 0 and ("  +" .. fmt(me.shield)) or ""))
	ui.res(me.res, me.resPool, string.format("%s %d / %d", me.resName or "", math.floor(me.res), math.floor(me.resPool)))
	ui.stamina(me.stamina, 100, "")

	local extra = ""
	if me.combo then
		extra = "  Combo " .. me.combo .. "/5"
	elseif me.bulwark then
		extra = "  Bulwark " .. math.floor(me.bulwark) .. "/100"
	end
	local state = me.blocking and "Blocking" or (me.action and string.format("%s (%s %.2fs)", me.action, me.state, me.busy) or "Ready")
	ui.state.Text = state .. extra

	ui.slots.LMB.name.Text = "Basic / heavy"
	ui.slots.LMB.cd.Text = ""
	for _, key in { "Q", "E", "R", "T" } do
		local slot = ui.slots[key]
		local cd = me.cds[key]
		slot.box.Visible = cd ~= nil
		if cd then
			slot.name.Text = cd.name .. (cd.cost and ("\n" .. cd.cost) or "")
			slot.cd.Text = cd.left > 0 and string.format("%.1f", cd.left) or "ready"
			slot.cd.TextColor3 = cd.left > 0 and Color3.fromRGB(200, 120, 120) or Color3.fromRGB(140, 230, 140)
		end
	end

	local boss = snap.boss
	if boss and boss.engaged then
		ui.bossName.Text = boss.name .. (boss.broken and "  BROKEN" or "") .. string.format("   enrage %d:%02d", math.floor(boss.enrage / 60), math.floor(boss.enrage % 60))
		ui.bossHp(boss.hp, boss.maxHp, string.format("%s / %s (%.1f%%)", fmt(boss.hp), fmt(boss.maxHp), boss.hp / boss.maxHp * 100))
		ui.bossBreak(boss.breakMeter, boss.breakMax, boss.breakLocked and "Break locked" or "Break")
		if boss.cast then
			ui.bossCast(boss.cast.total - boss.cast.left, boss.cast.total, boss.cast.name .. (boss.cast.interruptible and "  (interrupt!)" or "  (cannot interrupt)"))
		else
			ui.bossCast(0, 1, "")
		end
		if boss.telegraph then
			local w = WARNING[boss.telegraph.color]
			ui.warning.Text = string.format("%s: %s", boss.telegraph.name, w.text)
			ui.warning.TextColor3 = w.color
		else
			ui.warning.Text = ""
		end
	else
		ui.bossName.Text = ""
		ui.bossHp(0, 1, "")
		ui.bossBreak(0, 1, "")
		ui.bossCast(0, 1, "")
		ui.warning.Text = ""
	end

	local d = snap.dummy
	if d then
		ui.meter.Text = string.format(
			"Training dummy\n%s damage in %.1f s\n%s DPS = %.2f x WD (target label 4 x WD)",
			fmt(d.total),
			d.duration,
			fmt(d.dps),
			d.wdps
		)
	else
		ui.meter.Text = "Hit the training dummy to measure your damage"
	end
end

return Hud
