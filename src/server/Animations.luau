-- Plays class combat animations on player characters. The server decides when an action starts, so it plays the
-- animation too; tracks played through the character's Animator replicate to every client.
-- Each animation is timed so its strike (AssetIds `hit`) lands as the wind-up ends, when the server applies the
-- hit, and plays close to its authored speed. Stretching whole animations over wind-up plus recovery made fast
-- actions look rushed and put the strike at the wrong moment.
-- R6 only (the animations are R6). Also plays for the Duelist NPCs; the boss is a part model and is not animated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared.AssetIds)
local Formulas = require(Shared.Formulas)

local Animations = {}

local FADE = 0.12 -- seconds [Proto]
local COMBO_RESET = 1.5 -- seconds without a basic attack before the combo starts again at hit 1 [Proto]
-- Playback rate limits [Proto]. Below MIN_RATE an animation looks slow-motion. Never faster than authored: sped-up
-- swings read as twitchy (playtest feedback). When the strike is too late for the wind-up even at MAX_RATE, the
-- start of the animation (its anticipation) is skipped instead.
local MIN_RATE = 0.75
local MAX_RATE = 1

type Entry = { id: number, length: number, hit: number? }

-- Per character: loaded tracks, and what is playing now.
local states: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any
-- Per actor: position in the basic-attack combo.
local combos: { [any]: { index: number, last: number } } = setmetatable({}, { __mode = "k" }) :: any

local function stateFor(actor)
	if (actor.kind ~= "player" and actor.kind ~= "npc") or not actor.model then
		return nil
	end
	local state = states[actor.model]
	if state then
		return state
	end
	local humanoid = actor:humanoid()
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	state = { animator = animator, tracks = {}, action = nil, block = nil }
	states[actor.model] = state
	return state
end

local function track(state, entry: Entry, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack
	local cached = state.tracks[entry.id]
	if cached then
		return cached
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = AssetIds.uri(entry.id)
	local t = state.animator:LoadAnimation(animation)
	t.Priority = priority
	t.Looped = looped
	state.tracks[entry.id] = t
	return t
end

local function entryFor(actor, def, now: number): Entry?
	local set = AssetIds.Combat[actor.kit and actor.kit.id]
	if not set then
		return nil
	end
	local entry = set[def.id]
	if def.id == "basic" and entry then
		local combo = combos[actor]
		if not combo or now - combo.last > COMBO_RESET then
			combo = { index = 0, last = now }
			combos[actor] = combo
		end
		combo.index = combo.index % #entry + 1
		combo.last = now
		return entry[combo.index]
	end
	return entry
end

-- An action went on the timeline: play its animation over wind-up plus recovery.
function Animations.action(actor, def, now: number)
	local state = stateFor(actor)
	if not state then
		return
	end
	local entry = entryFor(actor, def, now)
	if not entry then
		return
	end
	if state.action then
		state.action:Stop(FADE)
	end
	-- Strike on the fire tick: rate * windup of animation time passes during the wind-up, ending at `hit`.
	local windup = Formulas.actionTime(def.windup or 0, actor.stats.actionSpeed)
	local rate, start = 1, 0
	if entry.hit and windup > 0 then
		rate = math.clamp(entry.hit / windup, MIN_RATE, MAX_RATE)
		start = math.max(0, entry.hit - windup * rate)
	end
	local t = track(state, entry, Enum.AnimationPriority.Action, false)
	t:Play(FADE)
	t.TimePosition = start
	t:AdjustSpeed(rate)
	state.action = t
end

-- Block raised or lowered. Classes without their own block pose use the Warden's.
function Animations.block(actor, raised: boolean)
	local state = stateFor(actor)
	if not state then
		return
	end
	if raised then
		-- Raising the block cancels a wind-up, so its swing stops too.
		if state.action then
			state.action:Stop(FADE)
			state.action = nil
		end
		local set = AssetIds.Combat[actor.kit and actor.kit.id]
		local entry = (set and set.block) or AssetIds.Combat.Warden.block
		state.block = track(state, entry, Enum.AnimationPriority.Action, true)
		state.block:Play(FADE)
	elseif state.block then
		state.block:Stop(FADE)
		state.block = nil
	end
end

local parryFlip = false

-- A parry landed: play one of the two parry swings over the held block.
function Animations.parry(actor)
	local state = stateFor(actor)
	if not state then
		return
	end
	parryFlip = not parryFlip
	local entry = if parryFlip then AssetIds.Combat.Common.parry1 else AssetIds.Combat.Common.parry2
	track(state, entry, Enum.AnimationPriority.Action2, false):Play(FADE)
end

-- Dodge, death or a cancelled wind-up: stop the action and lower the block.
function Animations.cancel(actor)
	local state = stateFor(actor)
	if not state then
		return
	end
	if state.action then
		state.action:Stop(FADE)
		state.action = nil
	end
	if state.block then
		state.block:Stop(FADE)
		state.block = nil
	end
end

return Animations
