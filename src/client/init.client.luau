-- Oathbound prototype client: input and HUD. The server decides every outcome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Input = require(script.Input)
local Hud = require(script.Hud)

Hud.start()
Input.start()

local remotes = ReplicatedStorage:WaitForChild(Net.FOLDER)
local stateRemote = remotes:WaitForChild(Net.STATE) :: RemoteEvent
local fxRemote = remotes:WaitForChild(Net.FX) :: RemoteEvent

stateRemote.OnClientEvent:Connect(Hud.onState)
fxRemote.OnClientEvent:Connect(Hud.onFx)
