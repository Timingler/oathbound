-- Oathbound prototype client: input, HUD, movement animations and combat effects. The server decides every outcome.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local AssetIds = require(Shared.AssetIds)

local Input = require(script.Input)
local Hud = require(script.Hud)
local Locomotion = require(script.Locomotion)
local Effects = require(script.Effects)

Hud.start()
Input.start()
Locomotion.start()

-- The server plays the combat animations, but each client fetches an animation the first time it sees it, and a
-- swing is over before the fetch is. Fetch them all now so the first swing of each one shows.
task.spawn(function()
	local animations = {}
	local function add(id: number)
		if id ~= 0 then
			local animation = Instance.new("Animation")
			animation.AnimationId = AssetIds.uri(id)
			table.insert(animations, animation)
		end
	end
	for _, set in AssetIds.Combat do
		for _, entry in set do
			if entry.id then
				add(entry.id)
			else
				for _, hit in entry do -- a basic-attack combo
					add(hit.id)
				end
			end
		end
	end
	for _, id in AssetIds.Hold do
		add(id)
	end
	ContentProvider:PreloadAsync(animations)
end)

local remotes = ReplicatedStorage:WaitForChild(Net.FOLDER)
local stateRemote = remotes:WaitForChild(Net.STATE) :: RemoteEvent
local fxRemote = remotes:WaitForChild(Net.FX) :: RemoteEvent

stateRemote.OnClientEvent:Connect(Hud.onState)
fxRemote.OnClientEvent:Connect(Hud.onFx)
fxRemote.OnClientEvent:Connect(Effects.onFx)
