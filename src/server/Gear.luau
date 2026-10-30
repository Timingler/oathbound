-- How equipped gear looks on the character. Only real assets from the cleared places, no placeholders:
--   * Clothing: chest items carry a Shirt template and legs items a Pants template, put on the character's Shirt and
--     Pants. The player's own avatar clothing comes back when the slot is empty.
--   * Meshes: helmets, hoods, cloaks, gauntlets, greaves, necklaces and the lantern are models in
--     ServerStorage.OathGear (rebuilt from vania, Excry and hxh; see docs/ASSETS.md), cloned and welded to the R6 limbs.
--     A model is either an Accessory (added through the Humanoid) or groups of parts whose root carries the limb it
--     sits on (`Limb`), where (`Offset`), and optionally a `Mirror` limb for the other arm or leg.
-- Items without a look (boots, rings, most off-hands) change stats only. Each slot's pieces sit in their own Model
-- under character.OathGear, so the inventory can make them glow.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)

local Gear = {}

local FOLDER = "OathGear"
local LEFT_RIGHT = { ["Left Arm"] = "Right Arm", ["Right Arm"] = "Left Arm", ["Left Leg"] = "Right Leg", ["Right Leg"] = "Left Leg" }

local function library(): Folder?
	return ServerStorage:FindFirstChild("OathGear") :: Folder?
end

local function weld(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = to
	w.Part1 = part
	w.C0 = offset
	w.Parent = part
end

-- One group of parts on the character. `mirrored` puts it on the other arm or leg (and every part riding its own
-- limb swaps sides too).
local function placeGroup(group: Model, character: Model, into: Model, mirrored: boolean)
	local clone = group:Clone()
	local root = clone.PrimaryPart -- the group's root part, the one other parts' `Rel` is measured from
	if not root then
		return
	end
	local function limbFor(name: string): BasePart?
		return character:FindFirstChild(if mirrored then LEFT_RIGHT[name] or name else name) :: BasePart?
	end
	local rootLimb = limbFor(root:GetAttribute("Limb"))
	if not rootLimb then
		return
	end
	local offset = root:GetAttribute("Offset") :: CFrame
	if mirrored then
		offset *= CFrame.Angles(0, 0, math.rad(root:GetAttribute("MirrorRotZ") or 0))
	end
	weld(root, rootLimb, offset)
	for _, p in clone:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			local rel = p:GetAttribute("Rel")
			local limbName = p:GetAttribute("Limb")
			if rel then
				weld(p, root, rel)
			elseif limbName then
				local l = limbFor(limbName)
				if l then
					weld(p, l, p:GetAttribute("Offset"))
				end
			end
		end
	end
	clone.Parent = into
end

-- Puts the look named `look` on `character`, inside `into`. Returns false if the library has no such look.
local function placeLook(look: string, character: Model, into: Model): boolean
	local lib = library()
	local source = lib and lib:FindFirstChild(look)
	if not source then
		return false
	end
	if source:GetAttribute("Kind") == "accessory" then
		-- Welded here rather than with Humanoid:AddAccessory, which welds later (deferred) and only while the
		-- accessory is a direct child of the character; this one lives in the slot's model.
		local accessory = source:FindFirstChildOfClass("Accessory")
		local clone = accessory and accessory:Clone()
		local handle = clone and clone:FindFirstChild("Handle") :: BasePart?
		local own = handle and handle:FindFirstChildOfClass("Attachment")
		local body: Attachment? = nil
		if own then
			for _, d in character:GetDescendants() do
				if d:IsA("Attachment") and d.Name == own.Name and d.Parent and d.Parent:IsA("BasePart") and d.Parent.Parent == character then
					body = d
					break
				end
			end
		end
		if clone and handle and own and body then
			local limbPart = body.Parent :: BasePart
			handle.CFrame = body.WorldCFrame * own.CFrame:Inverse()
			local w = Instance.new("Weld")
			w.Part0 = limbPart
			w.Part1 = handle
			w.C0 = body.CFrame
			w.C1 = own.CFrame
			w.Parent = handle
			for _, p in clone:GetDescendants() do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.Massless = true
				end
			end
			clone.Parent = into
		end
		return true
	end
	for _, group in source:GetChildren() do
		if group:IsA("Model") then
			local root = group.PrimaryPart
			placeGroup(group, character, into, false)
			if root and root:GetAttribute("Mirror") then
				placeGroup(group, character, into, true)
			end
		end
	end
	return true
end

-- Helmets and hoods hide hats and hair so they do not poke through. Restored when the head is bare again.
local function setHeadwearHidden(character: Model, hidden: boolean)
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") then
			local kind = accessory.AccessoryType
			if kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair then
				local handle = accessory:FindFirstChild("Handle") :: BasePart?
				if handle then
					local original = handle:GetAttribute("OathTransparency")
					if hidden then
						if original == nil then
							handle:SetAttribute("OathTransparency", handle.Transparency)
						end
						handle.Transparency = 1
					elseif original ~= nil then
						handle.Transparency = original
						handle:SetAttribute("OathTransparency", nil)
					end
				end
			end
		end
	end
end

-- Shirt or Pants: the item's template, or the avatar's own when the slot is empty. The avatar's templates are
-- remembered on the character the first time ("" when it had none); server/ForceR6 clears them after it dresses
-- the character, so they are read again from the avatar.
local function setClothing(character: Model, className: string, templateProp: string, template: number?)
	local attr = "Oath" .. className
	local clothing = character:FindFirstChildOfClass(className) :: any
	if character:GetAttribute(attr) == nil then
		character:SetAttribute(attr, if clothing then clothing[templateProp] else "")
	end
	local wanted = if template then "rbxassetid://" .. template else character:GetAttribute(attr)
	if wanted == "" then
		if clothing then
			clothing:Destroy()
		end
		return
	end
	if not clothing then
		clothing = Instance.new(className)
		clothing.Parent = character
	end
	clothing[templateProp] = wanted
end

-- Rebuilds every gear look on `character` from `equipped` (slot id -> item). Main hands are left to server/Weapons.
function Gear.apply(character: Model, equipped: { [string]: any })
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = FOLDER
	root.Parent = character
	local coveredHead = false
	for _, slot in Items.SLOTS do
		local item = equipped[slot.id]
		if item and item.look then
			local model = Instance.new("Model")
			model.Name = slot.id
			model.Parent = root
			if placeLook(item.look, character, model) and slot.id == "head" and item.look ~= "lostCrown" then
				coveredHead = true
			end
		end
	end
	local chest, legs = equipped.chest, equipped.legs
	setClothing(character, "Shirt", "ShirtTemplate", chest and chest.shirt)
	setClothing(character, "Pants", "PantsTemplate", legs and legs.pants)
	setHeadwearHidden(character, coveredHead)
end

return Gear
