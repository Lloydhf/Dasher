-- Absolute server-clock deadlines keep presentation independent of packet arrival.
-- This module is intentionally pure so boundary, delay and acceleration behavior
-- can be exercised outside Studio using exactly the shipped implementation.
local RoundClock = {}

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function RoundClock.New()
	return {phaseStartedAt = 0, phaseEndsAt = 0, multiplier = 1, clockRevision = 0}
end

function RoundClock.Remaining(state, timestamp)
	if not state or not finite(timestamp) or not finite(state.phaseEndsAt) then return 0 end
	local rate = finite(state.multiplier) and math.max(0, state.multiplier) or 1
	return math.max(0, (state.phaseEndsAt - timestamp) * rate)
end

function RoundClock.Start(clock, timestamp, duration, rate)
	assert(finite(timestamp) and finite(duration) and duration >= 0, "Invalid phase clock")
	rate = rate or 1
	assert(finite(rate) and rate > 0, "Invalid clock rate")
	clock.phaseStartedAt = timestamp
	clock.phaseEndsAt = timestamp + duration / rate
	clock.multiplier = rate
	clock.clockRevision += 1
	return duration
end

function RoundClock.Cap(clock, timestamp, maximum)
	assert(finite(maximum) and maximum >= 0, "Invalid clock cap")
	local remaining = RoundClock.Remaining(clock, timestamp)
	if remaining > maximum then
		remaining = maximum
		clock.phaseEndsAt = timestamp + remaining / clock.multiplier
		clock.clockRevision += 1
	end
	return remaining
end

function RoundClock.SetRate(clock, timestamp, rate)
	assert(finite(rate) and rate > 0, "Invalid clock rate")
	local remaining = RoundClock.Remaining(clock, timestamp)
	if rate ~= clock.multiplier then
		clock.phaseEndsAt = timestamp + remaining / rate
		clock.multiplier = rate
		clock.clockRevision += 1
	end
	return remaining
end

function RoundClock.Countdown(state, timestamp)
	if not state or state.phase ~= "Countdown" then return "" end
	local remaining = RoundClock.Remaining(state, timestamp)
	if remaining <= 0 or remaining > 3 then return "" end
	return tostring(math.ceil(remaining))
end

function RoundClock.Accept(previous, incoming)
	if type(incoming) ~= "table" or not finite(incoming.stateSequence) then return false end
	return not previous or not finite(previous.stateSequence) or incoming.stateSequence > previous.stateSequence
end

return RoundClock
