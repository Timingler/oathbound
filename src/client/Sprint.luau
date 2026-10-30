-- Sprint, as in the Sprint System With Stamina Bar kit (BestRobloxLib): double-tap W and keep holding it to run.
-- Letting go of W, opening a menu or running out of stamina stops it. The server drains the shared stamina pool
-- and ends the sprint when you attack, block, dodge or aim (server/CombatService); the snapshot tells this module.
-- client/Locomotion already switches to the run cycles above 20 studs per second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Constants = require(Shared.Constants)

local R = Net.Request
local DOUBLE_TAP = 0.3 -- seconds between W presses [Proto]
local SERVER_GRACE = 0.4 -- seconds to trust the local sprint before the server's snapshot has caught up

local Sprint = {}

local player = Players.LocalPlayer
local actionRemote: RemoteEvent
local sprinting = false
local startedAt = 0
local lastW = -math.huge

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function stop(tellServer: boolean)
	if not sprinting then
		return
	end
	sprinting = false
	local h = humanoid()
	if h and h.WalkSpeed == Constants.SPRINT_SPEED then
		h.WalkSpeed = Constants.WALK_SPEED
	end
	if tellServer then
		actionRemote:FireServer({ kind = R.EXERT_END })
	end
end

local function start()
	local h = humanoid()
	-- Something else owns the walk speed (the Ranger's aim, a frozen menu): no sprint.
	if
		sprinting
		or not h
		or h.Health <= 0
		or h.WalkSpeed ~= Constants.WALK_SPEED
		or player:GetAttribute("UiOpen")
		or player:GetAttribute("Traversal")
	then
		return
	end
	sprinting = true
	startedAt = os.clock()
	h.WalkSpeed = Constants.SPRINT_SPEED
	actionRemote:FireServer({ kind = R.EXERT_START, mode = "sprint" })
end

function Sprint.isSprinting(): boolean
	return sprinting
end

-- From the server's snapshot: it ended the sprint (an attack, a block, out of stamina).
function Sprint.onState(snap)
	local me = snap and snap.self
	if sprinting and me and me.exertion ~= "sprint" and os.clock() - startedAt > SERVER_GRACE then
		stop(false)
	end
end

function Sprint.start()
	actionRemote = ReplicatedStorage:WaitForChild(Net.FOLDER):WaitForChild(Net.ACTION) :: RemoteEvent
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.W then
			return
		end
		local now = os.clock()
		if now - lastW <= DOUBLE_TAP then
			start()
		end
		lastW = now
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.W then
			stop(true)
		end
	end)
	player:GetAttributeChangedSignal("UiOpen"):Connect(function()
		if player:GetAttribute("UiOpen") then
			stop(true)
		end
	end)
	player.CharacterAdded:Connect(function()
		sprinting = false
	end)
end

return Sprint
