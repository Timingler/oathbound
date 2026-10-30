-- Lock-on: middle mouse locks onto the enemy nearest the centre of the screen (models the server tags "OathEnemy":
-- the boss, the Duelist and the training dummy). While locked the camera keeps it centred, your character faces
-- it, and attacks and arrows aim at it (client/Input asks LockOn.point). Middle mouse again, the target dying or
-- getting too far away lets go.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Inventory.Theme)

local LockOn = {}

local TAG = "OathEnemy"
local RANGE = 70 -- studs to lock on [Proto]
local KEEP_RANGE = 90 -- studs before the lock lets go [Proto]
local MAX_ANGLE = 45 -- degrees from the screen centre a target may be [Proto]

local player = Players.LocalPlayer
local target: Model? = nil
local marker: BillboardGui? = nil

local function rootOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function alive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return model.Parent ~= nil and rootOf(model) ~= nil and (not humanoid or humanoid.Health > 0)
end

-- Where to aim: the middle of the target's body.
function LockOn.point(): Vector3?
	local root = target and rootOf(target)
	return root and root.Position
end

local function release()
	target = nil
	if marker then
		marker:Destroy()
		marker = nil
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
	end
end

local function pick(): Model?
	local camera = workspace.CurrentCamera
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not me then
		return nil
	end
	local best, bestScore = nil, math.huge
	for _, model in CollectionService:GetTagged(TAG) do
		local root = model:IsA("Model") and alive(model) and rootOf(model)
		if root then
			local distance = (root.Position - me.Position).Magnitude
			local toTarget = (root.Position - camera.CFrame.Position).Unit
			local angle = math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(toTarget), -1, 1)))
			if distance <= RANGE and angle <= MAX_ANGLE then
				local score = angle + distance * 0.3
				if score < bestScore then
					best, bestScore = model, score
				end
			end
		end
	end
	return best
end

local function lock(model: Model)
	release()
	target = model
	local root = rootOf(model) :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Name = "OathLockOn"
	gui.Size = UDim2.fromOffset(18, 18)
	gui.AlwaysOnTop = true
	gui.Adornee = root
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromOffset(11, 11)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Theme.gold
	diamond.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.4
	stroke.Parent = diamond
	diamond.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	marker = gui
end

-- Locks on, or lets go if already locked. Returns the target's name, if any.
function LockOn.toggle(): string?
	if player:GetAttribute("UiOpen") or player:GetAttribute("Talking") then
		return nil
	end
	if target then
		release()
		return nil
	end
	local model = pick()
	if model then
		lock(model)
	end
	return model and model.Name
end

function LockOn.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton3 then
			LockOn.toggle()
		end
	end)

	-- After the camera scripts: swing the camera to the target and turn the character to face it.
	RunService:BindToRenderStep("OathLockOn", Enum.RenderPriority.Camera.Value + 2, function()
		if not target then
			return
		end
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = rootOf(target)
		if not me or not humanoid or humanoid.Health <= 0 or not alive(target) or not root
			or (root.Position - me.Position).Magnitude > KEEP_RANGE then
			release()
			return
		end
		if player:GetAttribute("UiOpen") or player:GetAttribute("Talking") or player:GetAttribute("Traversal") then
			return -- a menu, a talk or a climb owns the camera and the facing for now
		end
		-- The camera scripts rebuild the view from the mouse every frame, so this re-aims it every frame.
		local camera = workspace.CurrentCamera
		camera.CFrame = CFrame.lookAt(camera.CFrame.Position, root.Position)
		humanoid.AutoRotate = false
		local flat = Vector3.new(root.Position.X, me.Position.Y, root.Position.Z)
		if (flat - me.Position).Magnitude > 0.1 then
			me.CFrame = CFrame.lookAt(me.Position, flat)
		end
	end)
	player.CharacterAdded:Connect(release)
end

return LockOn
