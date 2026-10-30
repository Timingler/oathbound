-- Puts each class's weapon in the character's right hand. The combat animations come from vania's rig, which
-- moves a "Hilt" part joined to the Right Arm, so the weapon is welded to a Hilt joined the same way. Like vania,
-- a looping hold pose (AssetIds.Hold) keeps the arm up and the weapon in the hand between attacks.
-- Weapon meshes and offsets are in shared/WeaponLibrary. R6 only.
-- Which weapon a class holds comes from the player's equipped main-hand item (server/Inventory sets
-- Weapons.variantFor); without one, the class default. The weapon is a Model so the inventory can highlight it.
-- The Ranger's bow is the exception: it comes from the Bow & Arrow System kit, whose animations move a "RootPart"
-- joined to the Left Arm, so the bow hangs off a part of that name in the left hand.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponLibrary = require(Shared.WeaponLibrary)
local AssetIds = require(Shared.AssetIds)

local Weapons = {}

local FOLDER = "OathWeapon"
local HILT_C0 = CFrame.new(0, -0.65, 0) -- where vania's rig holds the Hilt, below the Right Arm's centre
local HOLD_ATTRIBUTE = "WeaponHold" -- client/Locomotion leaves the standing pose to the hold while this is set
local HOLD_FADE = 0.2 -- seconds [Proto]

-- The bow, from the Bow & Arrow System kit's model: two meshes at fixed offsets from its RootPart.
-- Bow looks: the same Bow & Arrow System meshes, stained differently [Proto].
local BOW_TINTS = {
	["Hunting Bow"] = Color3.fromRGB(106, 57, 9),
	["Ashwood Longbow"] = Color3.fromRGB(196, 170, 128),
	["Blackwood Recurve"] = Color3.fromRGB(44, 36, 34),
	["Gilded Warbow"] = Color3.fromRGB(214, 176, 98),
	["Bone Bow"] = Color3.fromRGB(214, 204, 176),
	["Bloodwood Bow"] = Color3.fromRGB(104, 38, 30),
}

-- Returns the equipped variant name for `character` as `className`, or nil. Set by server/Inventory.
Weapons.variantFor = function(_character: Model, _className: string): (string?, { number }?)
	return nil
end

local BOW = {
	color = Color3.fromRGB(106, 57, 9),
	parts = {
		{ name = "BowBody", meshId = "rbxassetid://114741889137943", size = Vector3.new(1.6249, 6.3576, 0.2384), offset = CFrame.new(-0.7212, -0.003, 0) },
		{ name = "BowString", meshId = "rbxassetid://84384875676666", size = Vector3.new(0.0365, 6.0925, 0.1024), offset = CFrame.new(-1.4696, -0.0169, 0.007) },
	},
}

-- Per character: the looping hold pose, and a count of equips so one that finishes loading late can tell a newer
-- one has started.
local holds: { [Model]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any
local equips: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Loops the class's hold pose, under every other animation, so the arm grips the weapon. Played by the server so
-- the track replicates to everyone, like the combat animations.
local function hold(character: Model, className: string?)
	local old = holds[character]
	if old then
		old:Stop(HOLD_FADE)
		holds[character] = nil
	end
	character:SetAttribute(HOLD_ATTRIBUTE, nil)
	local id = className and AssetIds.Hold[className]
	if not id or id == 0 then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = AssetIds.uri(id)
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Idle
	track.Looped = true
	track:Play(HOLD_FADE)
	holds[character] = track
	character:SetAttribute(HOLD_ATTRIBUTE, true)
end

local function cf(c): CFrame
	return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
end

local function materialFrom(value: number): Enum.Material
	for _, item in Enum.Material:GetEnumItems() do
		if item.Value == value then
			return item
		end
	end
	return Enum.Material.Plastic
end

local function makePart(def): MeshPart?
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(def.meshId)
	end)
	if not ok or not part then
		warn("[Weapons] could not load mesh " .. tostring(def.meshId) .. ": " .. tostring(part))
		return nil
	end
	part.Size = Vector3.new(def.size[1], def.size[2], def.size[3])
	part.Color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
	part.Material = materialFrom(def.material)
	part.Transparency = def.transparency or 0
	part.Reflectance = def.reflectance or 0
	if def.textureId then
		part.TextureID = def.textureId
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	return part
end

-- Builds the bow in `folder`: a RootPart joined to the Left Arm (the part the bow animations move) and the meshes
-- welded to it.
local function buildBow(folder: Model, leftArm: BasePart, color: Color3)
	local root = Instance.new("Part")
	root.Name = "RootPart" -- the bow animations' Pose name; must match
	root.Size = Vector3.new(0.13, 0.13, 0.06)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CFrame = leftArm.CFrame
	root.Parent = folder

	local joint = Instance.new("Motor6D")
	joint.Name = "WBow"
	joint.Part0 = leftArm
	joint.Part1 = root
	joint.Parent = leftArm

	for _, partDef in BOW.parts do
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync(partDef.meshId)
		end)
		if not ok or not part then
			warn("[Weapons] could not load bow mesh " .. partDef.meshId .. ": " .. tostring(part))
			continue
		end
		part.Name = partDef.name
		part.Size = partDef.size
		part.Color = color
		part.Material = Enum.Material.Wood
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = root.CFrame * partDef.offset
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = partDef.offset
		weld.Parent = part
		part.Parent = folder
	end
end

-- Puts the weapon away: no weapon in the hand and no hold pose. A tool from the hotbar takes its place
-- (server/Tools); an equip still loading is dropped.
function Weapons.stow(character: Model)
	equips[character] = (equips[character] or 0) + 1
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	hold(character, nil)
	local arm = character:FindFirstChild("Right Arm")
	local leftArm = character:FindFirstChild("Left Arm")
	local oldHilt = arm and arm:FindFirstChild("WHilt")
	if oldHilt then
		oldHilt:Destroy()
	end
	local oldBow = leftArm and leftArm:FindFirstChild("WBow")
	if oldBow then
		oldBow:Destroy()
	end
end

-- Removes any weapon and gives the character the one for `className`. Yields while the meshes load. While a tool
-- is out (server/Tools), the weapon stays put away. `variant` and `finish` pick the weapon instead of the inventory
-- (the boss uses this).
function Weapons.equip(character: Model, className: string, variant: string?, finish: { number }?)
	if character:GetAttribute("HeldTool") then
		Weapons.stow(character)
		return
	end
	local equip = (equips[character] or 0) + 1
	equips[character] = equip
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	hold(character, nil)
	if not variant then
		variant, finish = Weapons.variantFor(character, className)
	end
	local def = (variant and WeaponLibrary[variant]) or WeaponLibrary[className]
	local arm = character:WaitForChild("Right Arm", 10) :: BasePart?
	local leftArm = character:WaitForChild("Left Arm", 10) :: BasePart?
	if not arm or not leftArm then
		return
	end
	local oldHilt = arm:FindFirstChild("WHilt")
	if oldHilt then
		oldHilt:Destroy()
	end
	local oldBow = leftArm:FindFirstChild("WBow")
	if oldBow then
		oldBow:Destroy()
	end
	if className == "Ranger" then
		local folder = Instance.new("Model")
		folder.Name = FOLDER
		buildBow(folder, leftArm, (variant and BOW_TINTS[variant]) or BOW.color)
		if equips[character] ~= equip then
			folder:Destroy()
			return
		end
		folder.Parent = character
		hold(character, className)
		return
	end
	if not def then
		return
	end

	local folder = Instance.new("Model")
	folder.Name = FOLDER

	local hilt = Instance.new("Part")
	hilt.Name = "Hilt" -- the combat animations' Pose name; must match
	hilt.Size = Vector3.new(0.2, 0.2, 0.2)
	hilt.Transparency = 1
	hilt.CanCollide = false
	hilt.CanQuery = false
	hilt.CanTouch = false
	hilt.Massless = true
	hilt.CFrame = arm.CFrame * HILT_C0
	hilt.Parent = folder

	local joint = Instance.new("Motor6D")
	joint.Name = "WHilt"
	joint.Part0 = arm
	joint.Part1 = hilt
	joint.C0 = HILT_C0
	joint.Parent = arm

	local main: MeshPart? = nil
	for index, partDef in def.parts do
		local part = makePart(partDef)
		if part then
			if index == 1 then
				main = part
				-- weapon * grip = hilt, so the weapon sits at hilt * grip:Inverse().
				part.CFrame = hilt.CFrame * cf(def.grip):Inverse()
				local weld = Instance.new("Weld")
				weld.Part0 = part
				weld.Part1 = hilt
				weld.C0 = cf(def.grip)
				weld.Parent = part
			elseif main then
				-- A Weld with an explicit offset, not a WeldConstraint: a WeldConstraint keeps whatever offset it sees
				-- when it activates, and the hold pose can move the Hilt in that moment, tearing the weapon apart.
				part.CFrame = main.CFrame * cf(partDef.cframe)
				local weld = Instance.new("Weld")
				weld.Part0 = main
				weld.Part1 = part
				weld.C0 = cf(partDef.cframe)
				weld.Parent = part
			end
			if finish then
				local c = part.Color
				part.Color = Color3.new(math.min(1, c.R * finish[1]), math.min(1, c.G * finish[2]), math.min(1, c.B * finish[3]))
			end
			part.Parent = folder
		end
	end

	if equips[character] ~= equip then
		folder:Destroy() -- switched class again while the meshes loaded; the newer equip owns the hand
		return
	end
	folder.Parent = character
	hold(character, className)
end

return Weapons
