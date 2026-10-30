-- Builds the test arena from code, so the repo needs no place file: a floor, a spawn,
-- and posts for the boss, the training dummy and the duelist. Placeholder blocks until real art exists.

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

	folder.Parent = workspace
	return {
		-- Ground-level spot the Ashen Sentinel (server/Boss) stands on, far from the spawn so it is never pulled by
		-- accident. It faces the spawn.
		bossPost = CFrame.lookAt(Vector3.new(0, 0.05, 130), Vector3.new(0, 0.05, 0)),
		-- The training dummy and the duelist are R6 rigs built by server/Duelist; these are their posts.
		dummyHome = CFrame.lookAt(Vector3.new(-40, 3.1, -20), Vector3.new(0, 3.1, -40)),
		duelistHome = CFrame.lookAt(Vector3.new(40, 3.1, -20), Vector3.new(0, 3.1, -40)),
	}
end

return Arena
