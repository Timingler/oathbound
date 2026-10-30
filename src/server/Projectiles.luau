-- Arrows and other delayed hits, stepped on the combat tick.
--
-- An arrow is simulated here, not as a part: each tick it moves along a ballistic arc and checks the segment it
-- covered against every enemy, so fast arrows cannot pass through anyone between ticks. Clients draw it from the
-- "arrow" Fx event with the same arc (client/Effects), and remove it on "arrowEnd".
-- Arrows fly exactly where the player points (the crosshair, or the mouse with the camera free): no homing and no
-- leading, so the drop and the travel time are the player's to judge. The Ranger is a skill class.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)

local Projectiles = {}

Projectiles.GRAVITY = Constants.ARROW_GRAVITY
local MUZZLE = Constants.ARROW_MUZZLE
local HIT_PADDING = 1.0 -- studs added to an enemy's radius, roughly a character's half-width [Proto]
local DEFAULT_RADIUS = 1.5

local arrows = {}
local delayed = {}
local nextId = 0

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Distance from point `p` to the segment a-b.
local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local len2 = ab:Dot(ab)
	local t = if len2 > 1e-9 then math.clamp((p - a):Dot(ab) / len2, 0, 1) else 0
	return (p - (a + ab * t)).Magnitude
end

-- Speed and damage coefficient of `def` at `draw` (0..1). Shots without a draw use their full values.
function Projectiles.drawn(def, draw: number?): (number, number)
	if draw == nil or not def.minSpeed then
		return def.speed, def.coeff
	end
	local t = math.clamp(draw, 0, 1)
	return def.minSpeed + (def.speed - def.minSpeed) * t, (def.minCoeff or def.coeff) + (def.coeff - (def.minCoeff or def.coeff)) * t
end

-- Fires `def` (a "shot": coeff, speed, range, pierce?) from `actor`. Players' arrows go to their aim point; an
-- NPC's (no aim point) go at `target`, or straight ahead.
function Projectiles.fireArrow(service, actor, def, target, draw: number?)
	local root = actor:root()
	if not root then
		return
	end
	local speed, coeff = Projectiles.drawn(def, draw)
	local origin = (root.CFrame * MUZZLE).Position
	local aimPoint
	local aimed = actor.aimPoint -- under the player's crosshair or mouse (CombatService)
	if aimed and (aimed - origin).Magnitude > 3 then
		aimPoint = aimed
	elseif actor.kind ~= "player" and target and target:isAlive() then
		aimPoint = target:position() :: Vector3
	else
		aimPoint = origin + flat(actor:lookVector()).Unit * def.range
	end
	local velocity = (aimPoint - origin).Unit * speed

	nextId += 1
	local arrow = {
		id = nextId,
		actor = actor,
		def = def,
		coeff = coeff,
		pos = origin,
		vel = velocity,
		traveled = 0,
		maxRange = def.range * 1.3,
		hit = {},
	}
	table.insert(arrows, arrow)
	service.fx({
		t = "arrow",
		id = arrow.id,
		src = actor.id,
		pos = origin,
		vel = velocity,
		g = Projectiles.GRAVITY,
		pierce = def.pierce == true,
		-- The shooter's client already drew this arrow when the click happened (client/Effects predicts it).
		owner = actor.player and actor.player.UserId or nil,
		predicted = def.needsAim == true,
	})
end

-- Lands `def` (coeff, radius) on every enemy within its radius of `point` after `delay` seconds.
function Projectiles.area(service, actor, def, point: Vector3, landsAt: number)
	table.insert(delayed, { actor = actor, def = def, point = point, landsAt = landsAt })
end

local function endArrow(service, arrow, hitSomething: boolean)
	service.fx({ t = "arrowEnd", id = arrow.id, pos = arrow.pos, hit = hitSomething })
end

function Projectiles.step(service, now: number)
	local dt = Constants.TICK
	local g = Vector3.new(0, -Projectiles.GRAVITY, 0)

	for i = #arrows, 1, -1 do
		local arrow = arrows[i]
		local from = arrow.pos
		local to = from + arrow.vel * dt + 0.5 * g * dt * dt
		arrow.vel += g * dt
		arrow.pos = to
		arrow.traveled += (to - from).Magnitude

		local actor = arrow.actor
		local stopped = false
		local hitAny = false
		-- Walls and the ground stop an arrow: shorten this tick's segment to where it strikes them.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = {}
		for _, other in service.living() do
			if other.model then
				table.insert(skip, other.model)
			end
		end
		params.FilterDescendantsInstances = skip
		params.RespectCanCollide = true
		local wall = workspace:Raycast(from, to - from, params)
		if wall then
			to = wall.Position
			arrow.pos = to
		end
		-- The nearest enemy along this tick's segment is hit first.
		local candidates = {}
		for _, other in service.living() do
			if other.team ~= actor.team and not arrow.hit[other] then
				local p = other:position()
				if p and segmentDistance(p, from, to) <= (other.radius or DEFAULT_RADIUS) + HIT_PADDING then
					table.insert(candidates, { other, (p - from).Magnitude })
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a[2] < b[2]
		end)
		for _, c in candidates do
			local enemy = c[1]
			arrow.hit[enemy] = true
			hitAny = true
			service.strike(actor, enemy, arrow.coeff * actor.wd, arrow.def)
			if not arrow.def.pierce then
				arrow.pos = enemy:position() :: Vector3
				stopped = true
				break
			end
		end
		if not stopped and (wall or to.Y < -50 or arrow.traveled >= arrow.maxRange) then
			stopped = true
		end
		if stopped then
			endArrow(service, arrow, hitAny)
			table.remove(arrows, i)
		end
	end

	for i = #delayed, 1, -1 do
		local d = delayed[i]
		if now >= d.landsAt - 1e-6 then
			table.remove(delayed, i)
			local hit = 0
			for _, other in service.living() do
				if other.team ~= d.actor.team then
					local p = other:position()
					if p and flat(p - d.point).Magnitude <= d.def.radius + (other.radius or DEFAULT_RADIUS) then
						service.strike(d.actor, other, d.def.coeff * d.actor.wd, d.def)
						hit += 1
					end
				end
			end
			if hit == 0 then
				service.log(d.actor, d.def.name .. " hit nothing")
			end
		end
	end
end

return Projectiles
