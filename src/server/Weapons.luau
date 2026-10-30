-- Puts each class's weapon in the character's right hand. The combat animations come from vania's rig, which
-- moves a "Hilt" part joined to the Right Arm, so the weapon is welded to a Hilt joined the same way. Like vania,
-- a looping hold pose (AssetIds.Hold) keeps the arm up and the weapon in the hand between attacks.
-- Weapon meshes and offsets are in shared/WeaponLibrary. R6 only.

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

-- Removes any weapon and gives the character the one for `className`. Yields while the meshes load.
function Weapons.equip(character: Model, className: string)
	local equip = (equips[character] or 0) + 1
	equips[character] = equip
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	hold(character, nil)
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
				-- A Weld with an explicit offset, not a WeldConstraint: a WeldConstraint keeps whatever offset it sees
				-- when it activates, and the hold pose can move the Hilt in that moment, tearing the weapon apart.
				part.CFrame = main.CFrame * cf(partDef.cframe)
				local weld = Instance.new("Weld")
				weld.Part0 = main
				weld.Part1 = part
				weld.C0 = cf(partDef.cframe)
				weld.Parent = part
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
