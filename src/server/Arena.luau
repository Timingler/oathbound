-- Builds the test arena from code, so the repo needs no place file: a floor, a spawn,
-- the Ashen Sentinel boss and a training dummy. Placeholder blocks until real art exists.

local Arena = {}

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function nameTag(parent: BasePart, text: string, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = parent
end

function Arena.build()
	local folder = Instance.new("Folder")
	folder.Name = "Arena"

	part({
		Name = "Floor",
		Size = Vector3.new(300, 2, 300),
		Position = Vector3.new(0, -0.95, 0), -- sits just above a default Baseplate to avoid flicker
		Color = Color3.fromRGB(70, 66, 60),
		Material = Enum.Material.Slate,
		Parent = folder,
	})

	if not workspace:FindFirstChildOfClass("SpawnLocation") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = Vector3.new(0, 0.5, -40)
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = folder
	end

	-- Boss: a body with a glowing face so players can read which way it points.
	local boss = Instance.new("Model")
	boss.Name = "Ashen Sentinel"
	local body = part({
		Name = "Body",
		Size = Vector3.new(8, 12, 8),
		Color = Color3.fromRGB(90, 30, 30),
		Material = Enum.Material.Basalt,
		CanCollide = true,
		Parent = boss,
	})
	part({
		Name = "Face",
		Size = Vector3.new(6, 2, 1),
		CFrame = CFrame.new(0, 3, -4.5),
		Color = Color3.fromRGB(255, 120, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = boss,
	})
	boss.PrimaryPart = body
	nameTag(body, "Ashen Sentinel", 9)
	boss:SetAttribute("DamageScale", 1)
	local bossHome = CFrame.lookAt(Vector3.new(0, 6, 50), Vector3.new(0, 6, 0))
	boss:PivotTo(bossHome)
	boss.Parent = folder

	-- Training dummy: never attacks, measures your damage.
	local dummy = Instance.new("Model")
	dummy.Name = "Training Dummy"
	local dummyBody = part({
		Name = "Body",
		Size = Vector3.new(4, 7, 4),
		Color = Color3.fromRGB(160, 130, 90),
		Material = Enum.Material.Wood,
		Parent = dummy,
	})
	dummy.PrimaryPart = dummyBody
	nameTag(dummyBody, "Training Dummy", 5.5)
	dummy:PivotTo(CFrame.lookAt(Vector3.new(-40, 3.5, -20), Vector3.new(0, 3.5, -40)))
	dummy.Parent = folder

	folder.Parent = workspace
	return {
		boss = boss,
		bossHome = bossHome,
		dummy = dummy,
	}
end

return Arena
