-- Utility tools from the hotbar (server/Inventory): taking one out puts the weapon away and the tool in the right
-- hand; putting it away brings the weapon back. The "HeldTool" attribute on the character and its player says
-- which tool is out; CombatService reads it so attacks use the tool and skills draw the weapon first.
-- A tool's model comes from ServerStorage.OathTools.<tool id> when the place has one; until then nothing shows in
-- the hand (no block placeholders), except the torch's flame and light. R6 only.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Constants = require(Shared.Constants)
local Weapons = require(script.Parent.Weapons)

local Tools = {}

local FOLDER = "OathTool"
local ATTRIBUTE = "HeldTool"
-- The grip below the Right Arm, pointing forward the way Roblox tools are held. A model can override it with a
-- CFrame attribute named "Grip". [Proto]
local GRIP = CFrame.new(0, -1, -0.1) * CFrame.Angles(-math.pi / 2, 0, 0)
-- Roblox's own R6 "toolnone" pose: the arm held forward, as with any Roblox tool.
local HOLD_ANIMATION = "rbxassetid://182393478"

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
	local track = holdTracks[character]
	if track then
		track:Stop(Constants.ANIM_FADE)
		holdTracks[character] = nil
	end
end

local function playHold(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = HOLD_ANIMATION
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
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
			local grip = model:GetAttribute("Grip")
			local offset = if typeof(grip) == "CFrame" then grip else GRIP
			if model:IsA("Model") then
				model:PivotTo(arm.CFrame * offset)
			else
				main.CFrame = arm.CFrame * offset
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
				weld.Part0 = arm
				weld.Part1 = main
				weld.C0 = offset
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
	playHold(character)
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
