-- Hit, block, parry, heal and boss VFX and sounds, driven by the server's Fx events. Purely cosmetic: the server
-- has already decided every outcome. Particle effects come from shared/VfxLibrary (vania and hxh), sounds from
-- AssetIds.Sfx. Effects are built once per key and cloned, and live on Terrain attachments so no parts are needed.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared.AssetIds)
local VfxLibrary = require(Shared.VfxLibrary)

local Effects = {}

local SOUND_VOLUME = 0.6 -- [Proto]
local SOUND_LIFETIME = 4 -- seconds before a played sound is cleaned up

-- Which effect each class's hits use.
local HIT_EFFECT = {
	Warden = "slash",
	Assassin = "stab",
	Cleric = "blunt",
	Ranger = "stab",
}

----------------------------------------------------------------------------------------------------
-- Arrows: drawn on the same arc the server simulates (server/Projectiles), so they land where it says they hit.

local RunService = game:GetService("RunService")

local ARROW_LIFETIME = 3 -- seconds; the server ends every arrow well before this
local VOLLEY_ARROWS = 12 -- [Proto]

local arrows: { [number]: any } = {}

local function makeArrow(pierce: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Arrow"
	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.12, 0.12, 2.6)
	shaft.Color = Color3.fromRGB(120, 86, 52)
	shaft.Material = Enum.Material.Wood
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.22, 0.22, 0.4)
	tip.Color = if pierce then Color3.fromRGB(150, 210, 255) else Color3.fromRGB(190, 190, 195)
	tip.Material = if pierce then Enum.Material.Neon else Enum.Material.Metal
	for _, p in { shaft, tip } do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.08, 1.2)
	a0.Parent = shaft
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.08, 1.2)
	a1.Parent = shaft
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(if pierce then Color3.fromRGB(150, 210, 255) else Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Parent = shaft
	model.PrimaryPart = shaft
	return model
end

local function placeArrow(model: Model, pos: Vector3, vel: Vector3)
	if vel.Magnitude < 1e-3 then
		return
	end
	local cf = CFrame.lookAt(pos, pos + vel)
	local shaft = model.PrimaryPart :: BasePart
	shaft.CFrame = cf
	;(model:FindFirstChild("Tip") :: BasePart).CFrame = cf * CFrame.new(0, 0, -1.45)
end

-- Starts drawing an arrow from `pos` with `vel`, falling at `g`.
local function launch(id: any, pos: Vector3, vel: Vector3, g: number, pierce: boolean, predicted: boolean?)
	local model = makeArrow(pierce)
	placeArrow(model, pos, vel)
	model.Parent = workspace
	arrows[id] = { model = model, pos = pos, vel = vel, g = g, born = os.clock(), predicted = predicted }
end

local function land(id: number, pos: Vector3?)
	local a = arrows[id]
	if not a then
		return
	end
	arrows[id] = nil
	if pos then
		placeArrow(a.model, pos, a.vel)
	end
	-- Leave it stuck where it landed for a moment.
	Debris:AddItem(a.model, 2)
end

local localPlayer = game:GetService("Players").LocalPlayer
local predictedIds = 0

-- Your own Aimed Shot, drawn the moment you click instead of after the round trip to the server. The server
-- simulates the same arc and decides what it hits; this copy only has to stop where it meets something.
function Effects.predictArrow(pos: Vector3, vel: Vector3, g: number)
	predictedIds += 1
	launch("p" .. predictedIds, pos, vel, g, false, true)
	Effects.sfx("bowRelease", pos)
end

RunService.RenderStepped:Connect(function(dt)
	for id, a in arrows do
		local from = a.pos
		a.pos += a.vel * dt + Vector3.new(0, -0.5 * a.g * dt * dt, 0)
		a.vel += Vector3.new(0, -a.g * dt, 0)
		if a.predicted then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { localPlayer.Character :: Instance, a.model }
			params.RespectCanCollide = false
			local hit = workspace:Raycast(from, a.pos - from, params)
			if hit and (hit.Instance.CanCollide or hit.Instance:FindFirstAncestorOfClass("Model")) then
				land(id, hit.Position)
				continue
			end
		end
		placeArrow(a.model, a.pos, a.vel)
		if os.clock() - a.born > ARROW_LIFETIME then
			land(id, nil)
		end
	end
end)

-- A Volley: a gold circle on the ground, then arrows falling into it as the hit lands.
local volleyIds = -1
local function volley(point: Vector3, radius: number, delay: number)
	local ground = Effects.ground(point) or point
	local circle = Instance.new("Part")
	circle.Shape = Enum.PartType.Cylinder
	circle.Anchored = true
	circle.CanCollide = false
	circle.CanQuery = false
	circle.CanTouch = false
	circle.Material = Enum.Material.Neon
	circle.Color = Color3.fromRGB(255, 205, 90)
	circle.Transparency = 0.7
	circle.Size = Vector3.new(0.15, radius * 2, radius * 2)
	circle.CFrame = CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	circle.Parent = workspace
	Debris:AddItem(circle, delay + 0.3)
	local fall = 0.35 -- seconds each arrow falls
	local speed = 90
	for i = 1, VOLLEY_ARROWS do
		task.delay(math.max(0, delay - fall) + math.random() * 0.15, function()
			local angle = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * radius
			local target = ground + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			local start = target + Vector3.new(-4, speed * fall, 2)
			volleyIds -= 1
			launch(volleyIds, start, (target - start).Unit * speed, 0, false)
			local id = volleyIds
			task.delay(fall, function()
				land(id, target)
			end)
		end)
	end
	task.delay(delay, function()
		Effects.sfx("arrowHit", ground)
	end)
end

local RANGE_FIELDS = { "Lifetime", "Speed", "RotSpeed", "Rotation", "FlipbookFramerate" }
local SEQUENCE_FIELDS = { "Size", "Transparency", "Squash" }
local PLAIN_FIELDS = {
	"Texture",
	"Brightness",
	"Drag",
	"LightEmission",
	"LightInfluence",
	"Rate",
	"ShapePartial",
	"TimeScale",
	"VelocityInheritance",
	"ZOffset",
	"LockedToPart",
	"FlipbookStartRandom",
	"WindAffectsDrag",
}
local ENUM_FIELDS = {
	EmissionDirection = Enum.NormalId,
	Orientation = Enum.ParticleOrientation,
	Shape = Enum.ParticleEmitterShape,
	ShapeInOut = Enum.ParticleEmitterShapeInOut,
	ShapeStyle = Enum.ParticleEmitterShapeStyle,
	FlipbookLayout = Enum.ParticleFlipbookLayout,
	FlipbookMode = Enum.ParticleFlipbookMode,
}

local function enumItem(enumType: Enum, value: number): EnumItem?
	for _, item in enumType:GetEnumItems() do
		if item.Value == value then
			return item
		end
	end
	return nil
end

local function set(emitter: ParticleEmitter, field: string, value: any)
	-- A property Roblox renamed or removed should not break the whole effect.
	pcall(function()
		(emitter :: any)[field] = value
	end)
end

local function buildEmitter(def): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	for _, field in PLAIN_FIELDS do
		if def[field] ~= nil then
			set(emitter, field, def[field])
		end
	end
	for _, field in RANGE_FIELDS do
		local r = def[field]
		if r then
			set(emitter, field, NumberRange.new(math.min(r[1], r[2]), math.max(r[1], r[2])))
		end
	end
	for _, field in SEQUENCE_FIELDS do
		local points = def[field]
		if points then
			local keypoints = {}
			for _, p in points do
				table.insert(keypoints, NumberSequenceKeypoint.new(p[1], p[2], p[3]))
			end
			set(emitter, field, NumberSequence.new(keypoints))
		end
	end
	if def.Color then
		local keypoints = {}
		for _, p in def.Color do
			table.insert(keypoints, ColorSequenceKeypoint.new(p[1], Color3.new(p[2], p[3], p[4])))
		end
		set(emitter, "Color", ColorSequence.new(keypoints))
	end
	if def.Acceleration then
		set(emitter, "Acceleration", Vector3.new(def.Acceleration[1], def.Acceleration[2], def.Acceleration[3]))
	end
	if def.SpreadAngle then
		set(emitter, "SpreadAngle", Vector2.new(def.SpreadAngle[1], def.SpreadAngle[2]))
	end
	for field, enumType in ENUM_FIELDS do
		if def[field] then
			local item = enumItem(enumType, def[field])
			if item then
				set(emitter, field, item)
			end
		end
	end
	emitter:SetAttribute("EmitCount", def.emitCount)
	emitter:SetAttribute("EmitDelay", def.emitDelay or 0)
	return emitter
end

-- key -> list of { template: Attachment, offset: CFrame, lifetime: number }
local templates: { [string]: { any } } = {}

local function templatesFor(key: string)
	local cached = templates[key]
	if cached then
		return cached
	end
	local groups = VfxLibrary[key]
	if not groups then
		return nil
	end
	cached = {}
	for _, group in groups do
		local attachment = Instance.new("Attachment")
		local lifetime = 0
		for _, def in group.emitters do
			buildEmitter(def).Parent = attachment
			local maxLife = def.Lifetime and math.max(def.Lifetime[1], def.Lifetime[2]) or 1
			lifetime = math.max(lifetime, maxLife + (def.emitDelay or 0))
		end
		local c = group.cframe
		local offset = CFrame.identity
		if c then
			offset = CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		end
		table.insert(cached, { template = attachment, offset = offset, lifetime = lifetime })
	end
	templates[key] = cached
	return cached
end

local GROUND_PROBE = 12 -- studs below a character's root to look for the floor
local GROUND_LIFT = 0.15 -- keeps a circle from z-fighting with the floor

-- The floor under `position`, skipping characters and other effects. Spell circles sit here instead of at the
-- character's root, which is in the middle of the body.
function Effects.ground(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = {}
	params.FilterDescendantsInstances = skip
	local origin = position + Vector3.new(0, 1, 0)
	for _ = 1, 6 do
		local hit = workspace:Raycast(origin, Vector3.new(0, -GROUND_PROBE, 0), params)
		if not hit then
			break
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			table.insert(skip, model)
		elseif hit.Instance.CanCollide or hit.Instance:IsA("Terrain") then
			return hit.Position + Vector3.new(0, GROUND_LIFT, 0)
		else
			table.insert(skip, hit.Instance)
		end
		params.FilterDescendantsInstances = skip
	end
	return position - Vector3.new(0, 3, 0) -- an R6 root is 3 studs above the feet
end

local function scaleSize(emitter: ParticleEmitter, scale: number)
	local keypoints = {}
	for _, k in emitter.Size.Keypoints do
		table.insert(keypoints, NumberSequenceKeypoint.new(k.Time, k.Value * scale, k.Envelope * scale))
	end
	emitter.Size = NumberSequence.new(keypoints)
end

-- Plays a particle effect once at `position`. `scale` grows the particles (a wide circle for an area spell).
function Effects.vfx(key: string, position: Vector3?, scale: number?)
	if not position then
		return
	end
	local groups = templatesFor(key)
	if not groups then
		return
	end
	for _, group in groups do
		local attachment = group.template:Clone()
		attachment.CFrame = CFrame.new(position) * group.offset
		attachment.Parent = workspace.Terrain
		for _, emitter in attachment:GetChildren() do
			if emitter:IsA("ParticleEmitter") then
				if scale and scale ~= 1 then
					scaleSize(emitter, scale)
				end
				local count = emitter:GetAttribute("EmitCount") or 1
				local delay = emitter:GetAttribute("EmitDelay") or 0
				if delay > 0 then
					task.delay(delay, function()
						emitter:Emit(count)
					end)
				else
					emitter:Emit(count)
				end
			end
		end
		Debris:AddItem(attachment, group.lifetime + 0.5)
	end
end

-- Plays one of the key's sounds at `position`.
function Effects.sfx(key: string, position: Vector3?)
	local ids = AssetIds.Sfx[key]
	if not ids or not position then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = AssetIds.uri(ids[math.random(#ids)])
	sound.Volume = SOUND_VOLUME
	sound.PlaybackSpeed = 0.95 + math.random() * 0.1
	sound.Parent = attachment
	sound:Play()
	Debris:AddItem(attachment, SOUND_LIFETIME)
end

local function both(key: string, position: Vector3?)
	Effects.vfx(key, position)
	Effects.sfx(key, position)
end

-- Camera shake: a small decaying jitter on heavy hits you deal or take, applied after the camera scripts.
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local SHAKE_DEAL = 0.25 -- degrees [Proto]
local SHAKE_TAKE = 0.6 -- degrees [Proto]
local SHAKE_TIME = 0.18 -- seconds [Proto]
local shakeUntil, shakeStrength = 0, 0
function Effects.shake(degrees: number)
	shakeStrength = math.max(if os.clock() < shakeUntil then shakeStrength else 0, degrees)
	shakeUntil = os.clock() + SHAKE_TIME
end
RunService:BindToRenderStep("OathShake", Enum.RenderPriority.Camera.Value + 3, function()
	local left = shakeUntil - os.clock()
	if left <= 0 or localPlayer:GetAttribute("UiOpen") then
		return
	end
	local s = math.rad(shakeStrength * left / SHAKE_TIME)
	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.Angles((math.random() - 0.5) * 2 * s, (math.random() - 0.5) * 2 * s, 0)
end)

function Effects.onFx(event)
	local t = event.t
	local pos = event.pos
	if t == "swing" then
		Effects.sfx(if event.class == "Ranger" then "bowDraw" else "swing", pos)
		if event.ability == "mend" and pos then
			-- Casting circle under the Cleric while Mend winds up.
			Effects.vfx("heal", Effects.ground(pos), 1.3)
			Effects.sfx("bossCast", pos)
		end
	elseif t == "hit" then
		both(if event.blocked then "blockHit" else HIT_EFFECT[event.class] or "slash", pos)
		if event.heavy and event.uid == localPlayer.UserId then
			Effects.shake(SHAKE_DEAL)
		end
	elseif t == "heal" then
		-- Circles go on the floor under whoever was healed. Sanctuary draws its own big circle, so its heals only
		-- add a small one; Smite's side heal is smaller than Mend's.
		if pos then
			local size = if event.ability == "mend" then 1.6 elseif event.ability == "sanctuary" then 0.7 else 0.8
			Effects.vfx("heal", Effects.ground(pos), size)
		end
		Effects.sfx("heal", pos)
	elseif t == "sanctuary" then
		if pos then
			local ground = Effects.ground(pos)
			Effects.vfx("slam", ground)
			Effects.vfx("heal", ground, math.max(1, (event.radius or 21) / 2.6))
		end
		Effects.sfx("bossSlam", pos)
		Effects.sfx("heal", pos)
	elseif t == "avoid" then
		if event.text == "Parry!" then
			both("parry", pos)
		else
			Effects.sfx("dodge", pos)
		end
	elseif t == "hurt" then
		both(if event.blocked then "blockHit" else "hurt", pos)
		if event.heavy and event.uid == localPlayer.UserId then
			Effects.shake(SHAKE_TAKE)
		end
	elseif t == "bossAttack" then
		if event.key == "sweep" then
			Effects.vfx("slam", pos)
			Effects.sfx("bossSlam", pos)
		else
			Effects.sfx("bossSwing", pos)
		end
	elseif t == "broken" then
		both("guardBreak", pos)
	elseif t == "cast" then
		Effects.sfx("bossCast", pos)
	elseif t == "arrow" then
		if event.predicted and event.owner == localPlayer.UserId then
			return -- already drawn by Effects.predictArrow when you clicked
		end
		launch(event.id, event.pos, event.vel, event.g, event.pierce)
		Effects.sfx("bowRelease", pos)
	elseif t == "arrowEnd" then
		land(event.id, event.pos)
		if event.hit then
			Effects.sfx("arrowHit", pos)
		end
	elseif t == "volley" then
		volley(pos, event.radius, event.delay)
	elseif t == "leap" then
		Effects.sfx("dodge", pos)
	end
end

return Effects
