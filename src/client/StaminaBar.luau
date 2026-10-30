-- A slim vertical stamina bar floating beside your character, after the Sprint System With Stamina Bar kit
-- (BestRobloxLib): blue, turning red when low. It shows while stamina is being spent or refilling and fades out
-- once it is full again. Fed by the server snapshot (about 10 a second) and eased between snapshots.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared.Constants)

local StaminaBar = {}

local LOW = 0.3 -- of the pool: below this the bar turns red [Proto]
local HIDE_AFTER = 0.8 -- seconds full before it fades out
local EASE = 12 -- how quickly the shown value follows the server's (per second)
local BLUE = Color3.fromRGB(86, 168, 255)
local RED = Color3.fromRGB(230, 62, 50)

local player = Players.LocalPlayer
local gui: BillboardGui
local back: Frame
local fill: Frame
local target = Constants.STAMINA_POOL
local shown = Constants.STAMINA_POOL
local fullSince = 0
local visible = false

local function setVisible(on: boolean)
	if visible == on then
		return
	end
	visible = on
	local info = TweenInfo.new(if on then 0.15 else 0.4)
	TweenService:Create(back, info, { BackgroundTransparency = if on then 0.35 else 1 }):Play()
	TweenService:Create(fill, info, { BackgroundTransparency = if on then 0 else 1 }):Play()
	TweenService:Create(back.UIStroke, info, { Transparency = if on then 0.2 else 1 }):Play()
end

local function attach(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		gui.Adornee = root
	end
end

function StaminaBar.onState(snap)
	local me = snap and snap.self
	if me and me.stamina then
		target = me.stamina
	end
end

function StaminaBar.start()
	gui = Instance.new("BillboardGui")
	gui.Name = "OathStamina"
	gui.Size = UDim2.fromScale(0.22, 2.8) -- studs
	gui.StudsOffset = Vector3.new(2.3, 0.4, 0) -- to the right of the character, as the camera sees it
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	back.BackgroundTransparency = 1
	back.BorderSizePixel = 0
	back.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Transparency = 1
	stroke.Parent = back
	fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = BLUE
	fill.BackgroundTransparency = 1
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = player:WaitForChild("PlayerGui")

	player.CharacterAdded:Connect(attach)
	if player.Character then
		task.spawn(attach, player.Character)
	end

	RunService.RenderStepped:Connect(function(dt)
		shown += (target - shown) * math.min(1, EASE * dt)
		local fraction = math.clamp(shown / Constants.STAMINA_POOL, 0, 1)
		fill.Size = UDim2.fromScale(1, fraction)
		fill.BackgroundColor3 = if fraction < LOW then RED else BLUE
		local now = os.clock()
		if target < Constants.STAMINA_POOL - 0.5 then
			fullSince = now
			setVisible(not player:GetAttribute("UiOpen"))
		elseif now - fullSince > HIDE_AFTER then
			setVisible(false)
		end
	end)
end

return StaminaBar
