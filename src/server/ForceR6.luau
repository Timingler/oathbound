-- Makes every player spawn as R6, whatever the experience's avatar setting says. The combat and movement
-- animations are all R6. Works by putting an R6 StarterCharacter in StarterPlayer, then dressing each new
-- character in the player's own avatar so they still look like themselves.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local ForceR6 = {}

function ForceR6.start()
	-- Roblox's own Shift Lock would fight the game's camera lock toggle (client/Input), which also uses Shift.
	StarterPlayer.EnableMouseLockOption = false
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
			-- Gear may already have put its Shirt and Pants on; clear them so only the avatar's own are left to
			-- remember (an avatar without classic clothing would otherwise keep the gear's).
			for _, clothing in character:GetChildren() do
				if clothing:IsA("Shirt") or clothing:IsA("Pants") then
					clothing:Destroy()
				end
			end
			pcall(function()
				humanoid:ApplyDescription(description)
			end)
		end
		-- Dressing replaced the clothing; server/Gear re-reads the avatar's own and puts the gear back on top.
		character:SetAttribute("OathShirt", nil)
		character:SetAttribute("OathPants", nil)
		character:SetAttribute("Dressed", true)
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
