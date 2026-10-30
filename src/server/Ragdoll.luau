-- R6 ragdoll on death, after the R6 Ragdoll System kit (BestRobloxLib): instead of falling apart, the body goes
-- limp. Each limb joint becomes a ball socket with the kit's limits, and small collider parts keep limbs out of the
-- floor. The kit's "R to ragdoll yourself" remote is left out on purpose: clients do not get to ragdoll anyone.

local Ragdoll = {}

-- The kit's attachment frames for each R6 joint: on Part0, then on Part1.
local SOCKETS: { [string]: { CFrame } } = {
	["Neck"] = { CFrame.new(0, 1, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1), CFrame.new(0, -0.5, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1) },
	["Left Shoulder"] = { CFrame.new(-1.3, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1), CFrame.new(0.2, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1) },
	["Right Shoulder"] = { CFrame.new(1.3, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), CFrame.new(-0.2, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1) },
	["Left Hip"] = { CFrame.new(-0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1) },
	["Right Hip"] = { CFrame.new(0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1) },
}

local function collider(part: BasePart)
	local c = Instance.new("Part")
	c.Name = "RagdollCollider"
	c.Size = part.Size / 1.7
	c.Massless = true
	c.Transparency = 1
	c.CFrame = part.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = c
	weld.Part1 = part
	weld.Parent = c
	c.Parent = part
end

-- Turns `character`'s joints into ball sockets. R6 only; anything else is left alone.
function Ragdoll.apply(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("Torso") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 or not torso or not root then
		return
	end
	humanoid.AutoRotate = false
	for _, joint in character:GetDescendants() do
		if not joint:IsA("Motor6D") then
			continue
		end
		local frames = SOCKETS[joint.Name]
		if joint.Name == "RootJoint" then
			-- The root goes along with the torso, so the camera follows the body instead of a part falling away.
			joint.Enabled = false
			local weld = Instance.new("WeldConstraint")
			weld.Name = "RagdollRootWeld"
			weld.Part0 = root
			weld.Part1 = torso
			weld.Parent = torso
		elseif frames and joint.Part0 and joint.Part1 then
			joint.Enabled = false
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollAttachment"
			a0.CFrame = frames[1]
			a0.Parent = joint.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollAttachment"
			a1.CFrame = frames[2]
			a1.Parent = joint.Part1
			collider(joint.Part1)
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "RagdollSocket"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.Radius = 0.15
			socket.LimitsEnabled = true
			socket.UpperAngle = if joint.Name == "Neck" then 45 else 90
			socket.TwistLimitsEnabled = joint.Name == "Neck"
			socket.TwistLowerAngle = if joint.Name == "Neck" then -70 else -45
			socket.TwistUpperAngle = if joint.Name == "Neck" then 70 else 45
			socket.Parent = joint.Parent
		end
	end
end

-- Ragdolls `humanoid`'s character when it dies, instead of breaking its joints.
function Ragdoll.onDeath(humanoid: Humanoid)
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Once(function()
		local character = humanoid.Parent
		if character and character:IsA("Model") then
			Ragdoll.apply(character)
		end
	end)
end

return Ragdoll
