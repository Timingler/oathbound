-- Utility tools from the hotbar (server/Inventory): taking one out puts the weapon away and the tool in the right
-- hand; putting it away brings the weapon back. The "HeldTool" attribute on the character and its player says
-- which tool is out; CombatService reads it so attacks use the tool and skills draw the weapon first.
-- A tool's model comes from ServerStorage.OathTools.<tool id> when the place has one; until then nothing shows in
-- the hand (no block placeholders), except the torch's flame and light. R6 only.
-- Tools are not weapons: no block or parry while one is out (CombatService), and left click swings it
-- (client/Input). The pickaxe and hatchet are rigged on a "Hilt" like the weapons (server/Weapons), so vania's
-- hammer clips move them: they rest on the shoulder (the Cleric's hold) and swing like the Cleric's first hammer
-- swing. The torch and fishing rod are held forward the way Roblox tools are.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Constants = require(Shared.Constants)
local AssetIds = require(Shared.AssetIds)
local Weapons = require(script.Parent.Weapons)

local Tools = {}

local FOLDER = "OathTool"
local ATTRIBUTE = "HeldTool"
-- The grip below the Right Arm, pointing forward the way Roblox tools are held. A model can override it with a
-- CFrame attribute named "Grip". [Proto]
local GRIP = CFrame.new(0, -1, -0.1) * CFrame.Angles(-math.pi / 2, 0, 0)
-- Roblox's own R6 "toolnone" pose: the arm held forward, as with any Roblox tool.
local HOLD_ANIMATION = "rbxassetid://182393478"
-- Hilted tools: where vania's rig holds the Hilt below the Right Arm, and each tool's weld C0 from its main part
-- (the handle) to the Hilt: the Great Hammer's grip (shared/WeaponLibrary), moved for the shorter handles. [Proto]
local HILT_C0 = CFrame.new(0, -0.65, 0)
local HAMMER_TURN = CFrame.new(0, 0, 0, -0.9998, -0.0174, 0, -0.0001, 0.0074, -1, 0.0174, -0.9998, -0.0074)
local HILTED = {
	pickaxe = { hold = AssetIds.Hold.Cleric, grip = CFrame.new(0.03, -0.85, 0) * HAMMER_TURN },
	hatchet = { hold = AssetIds.Hold.Cleric, grip = CFrame.new(0.03, -0.9, 0) * HAMMER_TURN },
}

local holdTracks: { [Model]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any

function Tools.held(character: Model?): string?
	return character and character:GetAttribute(ATTRIBUTE)
end

local function clear(character: Model)
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local arm = character:FindFirstChild("Right Arm")
	local grip = arm and arm:FindFirstChild("OathToolGrip")
	if grip then
		grip:Destroy()
	end
	local hilt = arm and arm:FindFirstChild("WToolHilt")
	if hilt then
		hilt:Destroy()
	end
	if character:GetAttribute("ToolHold") then
		character:SetAttribute("ToolHold", nil)
		character:SetAttribute("WeaponHold", nil)
	end
	local track = holdTracks[character]
	if track then
		track:Stop(Constants.ANIM_FADE)
		holdTracks[character] = nil
	end
end

-- `id` is a vania hold (Idle priority, like the weapon holds) or nil for Roblox's tool pose.
local function playHold(character: Model, id: number?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = if id then AssetIds.uri(id) else HOLD_ANIMATION
	local track = animator:LoadAnimation(animation)
	track.Priority = if id then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Action
	if id then
		-- Like a weapon hold: client/Locomotion leaves the standing pose to it.
		character:SetAttribute("ToolHold", true)
		character:SetAttribute("WeaponHold", true)
	end
	track.Looped = true
	track:Play(Constants.ANIM_FADE)
	holdTracks[character] = track
end

local function build(character: Model, def)
	local arm = character:FindFirstChild("Right Arm") :: BasePart?
	if not arm then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = FOLDER

	local library = ServerStorage:FindFirstChild("OathTools")
	local source = library and library:FindFirstChild(def.id)
	if source then
		local model = source:Clone()
		local main = if model:IsA("BasePart") then model else model:FindFirstChildWhichIsA("BasePart", true)
		if main then
			local hilted = HILTED[def.id]
			local grip = model:GetAttribute("Grip")
			local offset = if typeof(grip) == "CFrame" then grip else GRIP
			local hilt: BasePart? = nil
			if hilted then
				-- A Hilt joined to the Right Arm, which vania's clips move; the handle hangs off it by the grip.
				hilt = Instance.new("Part")
				hilt.Name = "Hilt" -- the clips' Pose name; must match
				hilt.Size = Vector3.new(0.2, 0.2, 0.2)
				hilt.Transparency = 1
				hilt.CanCollide = false
				hilt.CanQuery = false
				hilt.CanTouch = false
				hilt.Massless = true
				hilt.CFrame = arm.CFrame * HILT_C0
				hilt.Parent = folder
				local joint = Instance.new("Motor6D")
				joint.Name = "WToolHilt"
				joint.Part0 = arm
				joint.Part1 = hilt
				joint.C0 = HILT_C0
				joint.Parent = arm
				offset = HILT_C0 * hilted.grip:Inverse() -- so the handle ends where the grip puts it
			end
			-- Move the whole model so its main part sits at arm * offset.
			local goal = arm.CFrame * offset
			if model:IsA("Model") then
				model:PivotTo(goal * main.CFrame:ToObjectSpace(model:GetPivot()))
			else
				main.CFrame = goal
			end
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Massless = true
				end
			end
			if main:IsA("BasePart") then
				main.Anchored = false
				main.CanCollide = false
				main.Massless = true
				-- Everything else is welded to `main` where it already sits, then `main` to the arm.
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") and part ~= main then
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = main
						weld.Part1 = part
						weld.Parent = part
					end
				end
				local weld = Instance.new("Weld")
				if hilt and hilted then
					weld.Part0 = main
					weld.Part1 = hilt
					weld.C0 = hilted.grip
				else
					weld.Part0 = arm
					weld.Part1 = main
					weld.C0 = offset
				end
				weld.Parent = main
			end
			model.Parent = folder
		end
	end

	if def.light then
		-- The flame sits at the end of the torch, about two studs past the hand.
		local grip = Instance.new("Attachment")
		grip.Name = "OathToolGrip"
		grip.CFrame = GRIP * CFrame.new(0, 2, 0)
		grip.Parent = arm
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 6
		fire.Color = Color3.fromRGB(255, 150, 60)
		fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
		fire.Parent = grip
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 176, 96)
		light.Shadows = true
		light.Parent = grip
	end

	folder.Parent = character
	local hilted = HILTED[def.id]
	playHold(character, hilted and hilted.hold)
end

-- Takes out `toolId` (an Items.TOOLS id), or with nil puts the tool away and draws `className`'s weapon.
function Tools.hold(player: Player, character: Model, toolId: string?, className: string?)
	clear(character)
	local def = toolId and Items.TOOL_BY_ID[toolId]
	character:SetAttribute(ATTRIBUTE, def and def.id or nil)
	player:SetAttribute(ATTRIBUTE, def and def.id or nil)
	if def then
		Weapons.stow(character)
		build(character, def)
	elseif className then
		task.spawn(Weapons.equip, character, className)
	end
end

return Tools
