-- Oathbound prototype client: input, HUD and movement animations. The server decides every outcome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Input = require(script.Input)
local Hud = require(script.Hud)
local Locomotion = require(script.Locomotion)

Hud.start()
Input.start()
Locomotion.start()

local remotes = ReplicatedStorage:WaitForChild(Net.FOLDER)
local stateRemote = remotes:WaitForChild(Net.STATE) :: RemoteEvent
local fxRemote = remotes:WaitForChild(Net.FX) :: RemoteEvent

stateRemote.OnClientEvent:Connect(Hud.onState)
fxRemote.OnClientEvent:Connect(Hud.onFx)
