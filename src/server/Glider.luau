-- The cloth glider from the Glider System kit (BestRobloxLib): its own fabric wing mesh, seated above and behind the
-- head the way the kit welds it, shown while a player glides (client/Traversal starts the glide; CombatService
-- calls this when the "glide" exertion starts and ends). Built on the server so everyone sees it.

local AssetService = game:GetService("AssetService")

local Glider = {}

local NAME = "OathGlider"
local MESH = "rbxassetid://8697333444" -- the kit's "Glider" model
local SIZE = Vector3.new(10.62, 4.94, 6.76)
local COLOR = Color3.fromRGB(86, 66, 54) -- the kit's brown fabric
local SEAT = CFrame.new(0, -4.5, -0.9) -- the kit's weld: glider * SEAT = root, so it sits 4.5 up and 0.9 back

local template: MeshPart? = nil
local loading = false

local function getTemplate(): MeshPart?
	if template or loading then
		return template
	end
	loading = true
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(MESH)
	end)
	loading = false
	if not ok or not part then
		warn("[Glider] could not load the glider mesh: " .. tostring(part))
		return nil
	end
	part.Name = NAME
	part.Size = SIZE
	part.Color = COLOR
	part.Material = Enum.Material.Fabric
	part.DoubleSided = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	template = part
	return part
end

-- Shows or removes the glider on `character`. Yields the first time while the mesh loads.
function Glider.set(character: Model, on: boolean)
	local old = character:FindFirstChild(NAME)
	if not on then
		if old then
			old:Destroy()
		end
		return
	end
	if old then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local source = getTemplate()
	if not root or not source then
		return
	end
	local glider = source:Clone()
	glider.CFrame = root.CFrame * SEAT:Inverse()
	local weld = Instance.new("Weld")
	weld.Part0 = glider
	weld.Part1 = root
	weld.C0 = SEAT
	weld.Parent = glider
	glider.Parent = character
end

-- Load the mesh before anyone glides, so the first glide shows it at once.
task.spawn(getTemplate)

return Glider
