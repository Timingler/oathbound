-- Placeholder looks for equipped gear, built from plain parts welded to the R6 limbs: helmets, hoods, chest
-- pieces, gauntlets, greaves, boots, jewellery and each class's off-hand (shields, a parrying dagger, a tome, a
-- quiver). Built on the server so everyone sees them. Each slot is its own Model under character.OathGear, so the
-- inventory can highlight it. Rarity shows as a trim colour; Legendary and Unique trims glow.
-- Replace with real meshes later; the item `look` names stay the same.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)

local Gear = {}

local FOLDER = "OathGear"

local IRON = Color3.fromRGB(150, 152, 158)
local DARK_IRON = Color3.fromRGB(78, 80, 86)
local LEATHER = Color3.fromRGB(102, 70, 44)
local DARK_LEATHER = Color3.fromRGB(58, 40, 28)
local CLOTH = Color3.fromRGB(176, 160, 128)
local DARK_CLOTH = Color3.fromRGB(48, 44, 52)
local WOOD = Color3.fromRGB(110, 76, 44)
local GOLD = Color3.fromRGB(214, 176, 98)

type Ctx = { model: Model, character: Model, trim: Color3, glow: boolean }

local function limb(character: Model, name: string): BasePart?
	return character:FindFirstChild(name) :: BasePart?
end

-- One part welded to `limbName` at `offset`.
local function piece(
	ctx: Ctx,
	limbName: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part?
	local body = limb(ctx.character, limbName)
	if not body then
		return nil
	end
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = ctx.model
	return p
end

-- A thin band in the rarity colour.
local function trim(ctx: Ctx, limbName: string, size: Vector3, offset: CFrame)
	piece(ctx, limbName, size, offset, ctx.trim, if ctx.glow then Enum.Material.Neon else Enum.Material.Metal)
end

local function both(fn: (string, number) -> ())
	fn("Left Arm", -1)
	fn("Right Arm", 1)
end

local function legs(fn: (string, number) -> ())
	fn("Left Leg", -1)
	fn("Right Leg", 1)
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis from X to Y

local LOOKS: { [string]: (Ctx) -> () } = {}

-- Head ------------------------------------------------------------------------------------------------------------

LOOKS.helm = function(ctx)
	piece(ctx, "Head", Vector3.new(1.3, 1.2, 1.3), CFrame.new(0, 0.12, 0), IRON, Enum.Material.Metal)
	piece(ctx, "Head", Vector3.new(0.95, 0.12, 0.06), CFrame.new(0, 0.05, -0.66), Color3.new(0.05, 0.05, 0.05), Enum.Material.SmoothPlastic)
	piece(ctx, "Head", Vector3.new(0.14, 0.7, 0.08), CFrame.new(0, -0.15, -0.67), IRON, Enum.Material.Metal) -- nasal
	trim(ctx, "Head", Vector3.new(1.36, 0.12, 1.36), CFrame.new(0, -0.42, 0))
end

LOOKS.greathelm = function(ctx)
	piece(ctx, "Head", Vector3.new(1.4, 1.35, 1.4), CFrame.new(0, 0.1, 0), DARK_IRON, Enum.Material.Metal)
	piece(ctx, "Head", Vector3.new(1.0, 0.1, 0.06), CFrame.new(0, 0.12, -0.71), Color3.new(0.03, 0.03, 0.03), Enum.Material.SmoothPlastic)
	piece(ctx, "Head", Vector3.new(0.08, 0.5, 0.06), CFrame.new(0, -0.25, -0.71), Color3.new(0.03, 0.03, 0.03), Enum.Material.SmoothPlastic)
	piece(ctx, "Head", Vector3.new(0.16, 0.55, 1.2), CFrame.new(0, 0.95, 0.05), ctx.trim, Enum.Material.Fabric) -- crest
	trim(ctx, "Head", Vector3.new(1.44, 0.12, 1.44), CFrame.new(0, 0.3, 0))
end

local function hood(ctx: Ctx, color: Color3, material: Enum.Material)
	piece(ctx, "Head", Vector3.new(1.4, 0.28, 1.4), CFrame.new(0, 0.62, 0.02), color, material)
	piece(ctx, "Head", Vector3.new(1.4, 1.3, 0.22), CFrame.new(0, 0.08, 0.6), color, material)
	piece(ctx, "Head", Vector3.new(0.22, 1.25, 1.35), CFrame.new(-0.6, 0.1, 0.02), color, material)
	piece(ctx, "Head", Vector3.new(0.22, 1.25, 1.35), CFrame.new(0.6, 0.1, 0.02), color, material)
	piece(ctx, "Torso", Vector3.new(2.15, 0.35, 1.2), CFrame.new(0, 0.86, 0), color, material) -- drape on the shoulders
	trim(ctx, "Head", Vector3.new(1.42, 0.1, 0.1), CFrame.new(0, 0.62, -0.66))
end

LOOKS.hood = function(ctx)
	hood(ctx, DARK_CLOTH, Enum.Material.Fabric)
end

LOOKS.coif = function(ctx)
	hood(ctx, DARK_IRON, Enum.Material.DiamondPlate)
end

LOOKS.circlet = function(ctx)
	piece(ctx, "Head", Vector3.new(0.12, 1.24, 1.24), CFrame.new(0, 0.32, 0) * UP, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece(ctx, "Head", Vector3.new(0.18, 0.18, 0.1), CFrame.new(0, 0.34, -0.62), ctx.trim, Enum.Material.Neon)
end

-- Chest ------------------------------------------------------------------------------------------------------------

local function pauldrons(ctx: Ctx, color: Color3, material: Enum.Material)
	both(function(arm, side)
		piece(ctx, arm, Vector3.new(1.25, 0.6, 1.25), CFrame.new(0.05 * side, 0.78, 0), color, material)
		trim(ctx, arm, Vector3.new(1.28, 0.1, 1.28), CFrame.new(0.05 * side, 0.5, 0))
	end)
end

LOOKS.plate = function(ctx)
	piece(ctx, "Torso", Vector3.new(2.15, 2.05, 1.2), CFrame.new(0, 0, 0), IRON, Enum.Material.Metal)
	piece(ctx, "Torso", Vector3.new(0.12, 1.6, 0.06), CFrame.new(0, 0.1, -0.62), DARK_IRON, Enum.Material.Metal) -- ridge
	pauldrons(ctx, IRON, Enum.Material.Metal)
	trim(ctx, "Torso", Vector3.new(2.2, 0.2, 1.25), CFrame.new(0, -0.88, 0))
end

LOOKS.padded = function(ctx)
	piece(ctx, "Torso", Vector3.new(2.12, 2.03, 1.15), CFrame.new(0, 0, 0), CLOTH, Enum.Material.Fabric)
	for i = -1, 1 do
		piece(ctx, "Torso", Vector3.new(2.13, 0.06, 1.16), CFrame.new(0, i * 0.5, 0), Color3.fromRGB(140, 126, 100), Enum.Material.Fabric)
	end
	trim(ctx, "Torso", Vector3.new(2.16, 0.16, 1.18), CFrame.new(0, -0.9, 0))
end

LOOKS.robe = function(ctx)
	local color = Color3.fromRGB(198, 190, 172)
	piece(ctx, "Torso", Vector3.new(2.12, 2.04, 1.16), CFrame.new(0, 0, 0), color, Enum.Material.Fabric)
	piece(ctx, "Torso", Vector3.new(2.16, 1.5, 1.2), CFrame.new(0, -1.7, 0), color, Enum.Material.Fabric) -- skirt
	piece(ctx, "Torso", Vector3.new(0.45, 3.4, 0.06), CFrame.new(0, -0.7, -0.62), ctx.trim, Enum.Material.Fabric) -- stole
	trim(ctx, "Torso", Vector3.new(2.18, 0.14, 1.22), CFrame.new(0, -0.95, 0))
end

LOOKS.leather = function(ctx)
	piece(ctx, "Torso", Vector3.new(2.12, 1.7, 1.15), CFrame.new(0, 0.15, 0), DARK_LEATHER, Enum.Material.Leather)
	piece(ctx, "Torso", Vector3.new(0.18, 2.3, 1.18), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(35)), LEATHER, Enum.Material.Leather) -- strap
	trim(ctx, "Torso", Vector3.new(2.16, 0.18, 1.2), CFrame.new(0, -0.82, 0))
end

-- Hands ------------------------------------------------------------------------------------------------------------

LOOKS.gauntlets = function(ctx)
	both(function(arm)
		piece(ctx, arm, Vector3.new(1.15, 0.95, 1.15), CFrame.new(0, -0.55, 0), IRON, Enum.Material.Metal)
		trim(ctx, arm, Vector3.new(1.18, 0.1, 1.18), CFrame.new(0, -0.08, 0))
	end)
end

LOOKS.gloves = function(ctx)
	both(function(arm)
		piece(ctx, arm, Vector3.new(1.1, 0.65, 1.1), CFrame.new(0, -0.7, 0), LEATHER, Enum.Material.Leather)
		trim(ctx, arm, Vector3.new(1.13, 0.1, 1.13), CFrame.new(0, -0.38, 0))
	end)
end

LOOKS.bracers = function(ctx)
	both(function(arm)
		piece(ctx, arm, Vector3.new(1.12, 0.55, 1.12), CFrame.new(0, -0.35, 0), WOOD, Enum.Material.Wood)
		trim(ctx, arm, Vector3.new(1.14, 0.08, 1.14), CFrame.new(0, -0.35, 0))
	end)
end

LOOKS.wraps = function(ctx)
	both(function(arm)
		piece(ctx, arm, Vector3.new(1.06, 0.55, 1.06), CFrame.new(0, -0.7, 0), Color3.fromRGB(222, 214, 196), Enum.Material.Fabric)
	end)
end

-- Legs -------------------------------------------------------------------------------------------------------------

LOOKS.greaves = function(ctx)
	legs(function(leg)
		piece(ctx, leg, Vector3.new(1.12, 1.05, 1.15), CFrame.new(0, 0.2, 0), IRON, Enum.Material.Metal)
		piece(ctx, leg, Vector3.new(0.5, 0.4, 0.15), CFrame.new(0, -0.15, -0.6), DARK_IRON, Enum.Material.Metal) -- knee
		trim(ctx, leg, Vector3.new(1.15, 0.1, 1.18), CFrame.new(0, 0.7, 0))
	end)
end

LOOKS.trousers = function(ctx)
	legs(function(leg)
		piece(ctx, leg, Vector3.new(1.06, 1.5, 1.06), CFrame.new(0, 0.22, 0), Color3.fromRGB(86, 74, 60), Enum.Material.Fabric)
	end)
end

LOOKS.legguards = function(ctx)
	legs(function(leg)
		piece(ctx, leg, Vector3.new(1.1, 0.85, 1.15), CFrame.new(0, 0.3, 0), LEATHER, Enum.Material.Leather)
		trim(ctx, leg, Vector3.new(1.13, 0.08, 1.18), CFrame.new(0, -0.1, 0))
	end)
end

-- Feet -------------------------------------------------------------------------------------------------------------

LOOKS.sabatons = function(ctx)
	legs(function(leg)
		piece(ctx, leg, Vector3.new(1.15, 0.62, 1.3), CFrame.new(0, -0.72, -0.1), IRON, Enum.Material.Metal)
		trim(ctx, leg, Vector3.new(1.18, 0.08, 1.33), CFrame.new(0, -0.42, -0.1))
	end)
end

LOOKS.boots = function(ctx)
	legs(function(leg)
		piece(ctx, leg, Vector3.new(1.12, 0.75, 1.22), CFrame.new(0, -0.66, -0.06), DARK_LEATHER, Enum.Material.Leather)
		trim(ctx, leg, Vector3.new(1.14, 0.08, 1.24), CFrame.new(0, -0.3, -0.06))
	end)
end

LOOKS.softBoots = function(ctx)
	legs(function(leg)
		piece(ctx, leg, Vector3.new(1.08, 0.55, 1.16), CFrame.new(0, -0.76, -0.05), LEATHER, Enum.Material.Fabric)
	end)
end

-- Jewellery --------------------------------------------------------------------------------------------------------

LOOKS.amulet = function(ctx)
	piece(ctx, "Torso", Vector3.new(1.0, 0.06, 0.06), CFrame.new(0, 0.85, -0.58), GOLD, Enum.Material.Metal)
	piece(ctx, "Torso", Vector3.new(0.06, 0.4, 0.06), CFrame.new(-0.3, 0.62, -0.6) * CFrame.Angles(0, 0, math.rad(-35)), GOLD, Enum.Material.Metal)
	piece(ctx, "Torso", Vector3.new(0.06, 0.4, 0.06), CFrame.new(0.3, 0.62, -0.6) * CFrame.Angles(0, 0, math.rad(35)), GOLD, Enum.Material.Metal)
	piece(ctx, "Torso", Vector3.new(0.3, 0.36, 0.1), CFrame.new(0, 0.38, -0.63), ctx.trim, Enum.Material.Neon)
end

LOOKS.token = function(ctx)
	piece(ctx, "Torso", Vector3.new(0.06, 0.28, 0.28), CFrame.new(0, 0.5, -0.62) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(176, 140, 96), Enum.Material.Metal, Enum.PartType.Cylinder)
	trim(ctx, "Torso", Vector3.new(0.1, 0.1, 0.06), CFrame.new(0, 0.5, -0.66))
end

LOOKS.ring = function(ctx)
	piece(ctx, "Right Arm", Vector3.new(0.12, 0.3, 0.3), CFrame.new(0.5, -0.85, -0.2), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece(ctx, "Right Arm", Vector3.new(0.1, 0.12, 0.12), CFrame.new(0.56, -0.85, -0.2), ctx.trim, Enum.Material.Neon)
end

-- Off-hands --------------------------------------------------------------------------------------------------------

-- A shield on the outside of the left forearm, facing out.
local function shield(ctx: Ctx, size: Vector3, color: Color3)
	local face = piece(ctx, "Left Arm", size, CFrame.new(-0.68, -0.25, 0), color, Enum.Material.Wood)
	if face then
		piece(ctx, "Left Arm", Vector3.new(0.08, size.Y + 0.12, 0.12), CFrame.new(-0.7, -0.25, size.Z / 2), ctx.trim, Enum.Material.Metal)
		piece(ctx, "Left Arm", Vector3.new(0.08, size.Y + 0.12, 0.12), CFrame.new(-0.7, -0.25, -size.Z / 2), ctx.trim, Enum.Material.Metal)
		piece(ctx, "Left Arm", Vector3.new(0.08, 0.12, size.Z), CFrame.new(-0.7, -0.25 + size.Y / 2, 0), ctx.trim, Enum.Material.Metal)
		piece(ctx, "Left Arm", Vector3.new(0.22, 0.5, 0.5), CFrame.new(-0.86, -0.15, 0), IRON, Enum.Material.Metal) -- boss
	end
end

LOOKS.heater = function(ctx)
	shield(ctx, Vector3.new(0.2, 2.2, 1.8), Color3.fromRGB(120, 40, 36))
	piece(ctx, "Left Arm", Vector3.new(0.2, 0.9, 0.9), CFrame.new(-0.68, -1.55, 0) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(120, 40, 36), Enum.Material.Wood) -- point
end

LOOKS.kite = function(ctx)
	shield(ctx, Vector3.new(0.2, 2.9, 1.6), Color3.fromRGB(36, 56, 110))
	piece(ctx, "Left Arm", Vector3.new(0.2, 0.8, 0.8), CFrame.new(-0.68, -1.85, 0) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(36, 56, 110), Enum.Material.Wood)
end

LOOKS.tower = function(ctx)
	shield(ctx, Vector3.new(0.24, 3.4, 2.2), DARK_IRON)
end

LOOKS.buckler = function(ctx)
	piece(ctx, "Left Arm", Vector3.new(0.2, 1.7, 1.7), CFrame.new(-0.66, -0.4, 0), WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	piece(ctx, "Left Arm", Vector3.new(0.22, 1.8, 1.8), CFrame.new(-0.64, -0.4, 0), ctx.trim, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece(ctx, "Left Arm", Vector3.new(0.3, 0.5, 0.5), CFrame.new(-0.82, -0.4, 0), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
end

LOOKS.parryDagger = function(ctx)
	piece(ctx, "Left Arm", Vector3.new(0.2, 0.45, 0.2), CFrame.new(0, -1.15, -0.15), DARK_LEATHER, Enum.Material.Leather)
	piece(ctx, "Left Arm", Vector3.new(0.7, 0.08, 0.12), CFrame.new(0, -1.4, -0.15), ctx.trim, Enum.Material.Metal) -- guard
	piece(ctx, "Left Arm", Vector3.new(0.06, 1.3, 0.22), CFrame.new(0, -2.1, -0.15), IRON, Enum.Material.Metal) -- blade
end

LOOKS.pouch = function(ctx)
	piece(ctx, "Torso", Vector3.new(0.5, 0.5, 0.4), CFrame.new(-0.75, -0.85, -0.45), DARK_LEATHER, Enum.Material.Leather)
	trim(ctx, "Torso", Vector3.new(0.52, 0.1, 0.42), CFrame.new(-0.75, -0.62, -0.45))
end

LOOKS.tome = function(ctx)
	piece(ctx, "Torso", Vector3.new(0.35, 0.95, 0.75), CFrame.new(-1.12, -0.65, 0), Color3.fromRGB(96, 34, 30), Enum.Material.Leather)
	piece(ctx, "Torso", Vector3.new(0.3, 0.9, 0.7), CFrame.new(-1.14, -0.65, 0), Color3.fromRGB(232, 222, 196), Enum.Material.SmoothPlastic) -- pages
	trim(ctx, "Torso", Vector3.new(0.37, 0.1, 0.77), CFrame.new(-1.12, -0.25, 0))
end

LOOKS.lantern = function(ctx)
	local cage = piece(ctx, "Torso", Vector3.new(0.45, 0.6, 0.45), CFrame.new(-1.2, -0.75, -0.2), DARK_IRON, Enum.Material.Glass)
	if cage then
		cage.Transparency = 0.5
	end
	local core = piece(ctx, "Torso", Vector3.new(0.22, 0.3, 0.22), CFrame.new(-1.2, -0.75, -0.2), GOLD, Enum.Material.Neon)
	if core then
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Brightness = 1.2
		light.Range = 8
		light.Parent = core
	end
	trim(ctx, "Torso", Vector3.new(0.5, 0.08, 0.5), CFrame.new(-1.2, -0.42, -0.2))
end

local function quiver(ctx: Ctx, length: number, width: number)
	local tilt = CFrame.Angles(0, 0, math.rad(-25))
	piece(ctx, "Torso", Vector3.new(width, length, width), CFrame.new(0.45, 0.2, 0.72) * tilt, LEATHER, Enum.Material.Leather)
	piece(ctx, "Torso", Vector3.new(width * 0.85, 0.35, width * 0.85), CFrame.new(0.45, 0.2, 0.72) * tilt * CFrame.new(0, length / 2 + 0.15, 0), Color3.fromRGB(236, 232, 224), Enum.Material.Fabric) -- fletching
	trim(ctx, "Torso", Vector3.new(width + 0.04, 0.1, width + 0.04), CFrame.new(0.45, 0.2, 0.72) * tilt * CFrame.new(0, length / 2 - 0.1, 0))
	piece(ctx, "Torso", Vector3.new(0.12, 2.6, 1.22), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(-35)), DARK_LEATHER, Enum.Material.Leather) -- strap
end

LOOKS.quiver = function(ctx)
	quiver(ctx, 1.8, 0.5)
end

LOOKS.quiverLarge = function(ctx)
	quiver(ctx, 2.2, 0.65)
end

----------------------------------------------------------------------------------------------------------------------

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

-- Rebuilds every gear look on `character` from `equipped` (slot id -> item). Main hands are left to server/Weapons.
function Gear.apply(character: Model, equipped: { [string]: any })
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = FOLDER
	local coveredHead = false
	for _, slot in Items.SLOTS do
		local item = equipped[slot.id]
		local build = item and item.look and LOOKS[item.look]
		if build then
			local rarity = Items.rarity(item.rarity)
			local model = Instance.new("Model")
			model.Name = slot.id
			build({
				model = model,
				character = character,
				trim = rarity.color,
				glow = rarity.rank >= Items.rarity("legendary").rank,
			})
			model.Parent = root
			if slot.id == "head" and item.look ~= "circlet" then
				coveredHead = true
			end
		end
	end
	setHeadwearHidden(character, coveredHead)
	root.Parent = character
end

return Gear
