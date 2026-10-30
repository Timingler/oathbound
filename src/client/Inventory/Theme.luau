-- Look of the inventory: dark smoked panels with a thin gold trim, after the reference avatar menu but in the
-- classic fantasy palette. Rarity colours live in shared/Items.

return {
	panel = Color3.fromRGB(14, 13, 12),
	panelTransparency = 0.12,
	row = Color3.fromRGB(28, 26, 23),
	rowHover = Color3.fromRGB(44, 40, 33),
	rowSelected = Color3.fromRGB(52, 45, 32),
	card = Color3.fromRGB(24, 22, 20),
	cardHover = Color3.fromRGB(40, 36, 30),
	gold = Color3.fromRGB(214, 176, 98),
	goldDim = Color3.fromRGB(120, 98, 58),
	text = Color3.fromRGB(236, 228, 212),
	textDim = Color3.fromRGB(150, 142, 128),
	textFaint = Color3.fromRGB(96, 90, 80),
	good = Color3.fromRGB(120, 210, 110),
	bad = Color3.fromRGB(230, 96, 80),

	titleBold = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold),
	body = Enum.Font.Gotham,
	bodyBold = Enum.Font.GothamBold,

	corner = UDim.new(0, 6),
	tween = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	tweenSlow = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}
