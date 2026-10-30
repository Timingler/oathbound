-- Makes every player spawn as R6, whatever the experience's avatar setting says. The combat and movement
-- animations are all R6. Works by putting an R6 StarterCharacter in StarterPlayer, then dressing each new
-- character in the player's own avatar so they still look like themselves.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local ForceR6 = {}

function ForceR6.start()
	if not StarterPlayer:FindFirstChild("StarterCharacter") then
		local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
		rig.Name = "StarterCharacter"
		rig.Parent = StarterPlayer
	end

	local function dress(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(math.max(player.UserId, 1))
		end)
		if ok and description then
			pcall(function()
				humanoid:ApplyDescription(description)
			end)
		end
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(dress, player, character)
		end)
		if player.Character then
			task.spawn(dress, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return ForceR6
