-- One action at a time: wind-up, fire, recovery (Oathbound GDD v2, section 4, "Combat timeline").
-- Pure state machine. The caller passes the current time, so it runs the same on the server and in tests.
--
--   idle --start--> windup --(time)--> fire event --> recovery --(time)--> idle
--                     |
--                   cancel (forced movement, boss interrupt, own dodge): costs nothing, no cooldown

local Formulas = require(script.Parent.Formulas)

local Timeline = {}
Timeline.__index = Timeline

export type Action = {
	id: string,
	windup: number,
	recovery: number,
	[string]: any,
}

export type Timeline = typeof(setmetatable(
	{} :: {
		state: string,
		action: Action?,
		fireAt: number,
		recoveryEnd: number,
		payload: any,
		_actionSpeed: number,
	},
	Timeline
))

function Timeline.new(): Timeline
	return setmetatable({
		state = "idle",
		action = nil,
		fireAt = 0,
		recoveryEnd = 0,
		payload = nil,
		_actionSpeed = 0,
	}, Timeline)
end

function Timeline.isIdle(self: Timeline): boolean
	return self.state == "idle"
end

function Timeline.isWindingUp(self: Timeline): boolean
	return self.state == "windup"
end

-- Starts an action. Returns false if another action is in progress.
-- `payload` is anything the caller needs back when the action fires (target, slot...).
function Timeline.start(self: Timeline, action: Action, now: number, actionSpeed: number, payload: any?): boolean
	if self.state ~= "idle" then
		return false
	end
	self.state = "windup"
	self.action = action
	self.payload = payload
	self.fireAt = now + Formulas.actionTime(action.windup, actionSpeed)
	self.recoveryEnd = 0
	self._actionSpeed = actionSpeed
	return true
end

-- Cancels during wind-up only. Returns the cancelled action, or nil.
function Timeline.cancel(self: Timeline): Action?
	if self.state ~= "windup" then
		return nil
	end
	local action = self.action
	self.state = "idle"
	self.action = nil
	self.payload = nil
	return action
end

-- Advances to `now`. Returns (action, payload) on the tick its wind-up ends; the caller applies the effect.
function Timeline.step(self: Timeline, now: number): (Action?, any)
	if self.state == "windup" and now >= self.fireAt - 1e-9 then
		local action = self.action :: Action
		local payload = self.payload
		self.state = "recovery"
		self.recoveryEnd = self.fireAt + Formulas.actionTime(action.recovery, self._actionSpeed)
		self.payload = nil
		return action, payload
	end
	if self.state == "recovery" and now >= self.recoveryEnd - 1e-9 then
		self.state = "idle"
		self.action = nil
	end
	return nil, nil
end

-- Seconds until the timeline is free, for the HUD.
function Timeline.busyFor(self: Timeline, now: number): number
	if self.state == "windup" then
		return math.max(0, self.fireAt - now)
	elseif self.state == "recovery" then
		return math.max(0, self.recoveryEnd - now)
	end
	return 0
end

return Timeline
