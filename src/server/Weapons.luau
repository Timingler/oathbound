-- Puts each class's weapon in the character's right hand. The combat animations come from vania's rig, which
-- moves a "Hilt" part joined to the Right Arm, so the weapon is welded to a Hilt joined the same way.
-- Weapon meshes and offsets are in shared/WeaponLibrary. R6 only.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponLibrary = require(Shared.WeaponLibrary)

local Weapons = {}

local FOLDER = "OathWeapon"
local HILT_C0 = CFrame.new(0, -0.65, 0) -- where vania's rig holds the Hilt, below the Right Arm's centre

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

-- Removes any weapon and gives the character the one for `className`. Yields while the meshes load.
function Weapons.equip(character: Model, className: string)
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local def = WeaponLibrary[className]
	local arm = character:WaitForChild("Right Arm", 10) :: BasePart?
	if not arm then
		return
	end
	local oldJoint = arm:FindFirstChild("WHilt")
	if oldJoint then
		oldJoint:Destroy()
	end
	if not def then
		return
	end

	local folder = Instance.new("Folder")
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
				part.CFrame = main.CFrame * cf(partDef.cframe)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = main
				weld.Part1 = part
				weld.Parent = part
			end
			part.Parent = folder
		end
	end

	folder.Parent = character
end

return Weapons
