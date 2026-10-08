local RoundClock = require("../src/shared/RoundClock")
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function near(actual, expected, message)
	check(math.abs(actual - expected) < 0.000001, message .. ": " .. tostring(actual))
end
local function copy(source)
	local result = {}
	for key, value in source do result[key] = value end
	return result
end

local clock = RoundClock.New()
near(RoundClock.Remaining(clock, 1), 0, "new clock empty")
RoundClock.Start(clock, 100, 8)
clock.phase = "Countdown"
near(clock.phaseEndsAt, 108, "absolute deadline")
near(clock.phaseStartedAt, 100, "phase start")
near(clock.clockRevision, 1, "start revision")
check(RoundClock.Countdown(clock, 104.999) == "", "intro does not flash four")
for _, case in {{105,"3"},{105.999,"3"},{106,"2"},{106.999,"2"},{107,"1"},{107.999,"1"},{108,""},{109,""}} do
	check(RoundClock.Countdown(clock, case[1]) == case[2], "exact countdown boundary " .. case[1])
end

-- The same absolute deadline is sampled at different rendering rates. Each
-- numeral occupies a complete second, independent of the 4Hz remote cadence.
for _, fps in {15, 30, 60, 144} do
	local displayed = {['1']=0,['2']=0,['3']=0}
	for frame = 0, fps * 8 - 1 do
		local numeral = RoundClock.Countdown(clock, 100 + (frame + 0.5) / fps)
		if numeral ~= "" then displayed[numeral] += 1 end
	end
	for _, numeral in {"3", "2", "1"} do
		check(displayed[numeral] == fps, string.format("%s occupies one second at %dfps", numeral, fps))
	end
end

-- Delivery delay must never restart a relative countdown. Deliberately feed
-- stale compatibility timeLeft values: display still follows the server end.
local previous
for index, sample in {{101,101.7},{103.25,104},{104.25,105.3},{105.25,106.2},{106.5,107.4}} do
	local incoming = copy(clock)
	incoming.serverNow, incoming.timeLeft = sample[1], 108 - sample[1]
	incoming.stateSequence = index * 2
	check(RoundClock.Accept(previous, incoming), "new snapshot accepted")
	previous = incoming
	near(RoundClock.Remaining(incoming, sample[2]), 108 - sample[2], "network delay already accounted for")
	local old = copy(incoming)
	old.stateSequence -= 1
	old.phaseEndsAt = 999
	check(not RoundClock.Accept(previous, old), "out-of-order packet rejected")
	check(not RoundClock.Accept(previous, incoming), "duplicate packet rejected")
end
check(not RoundClock.Accept(previous, {stateSequence=0/0}), "nan packet rejected")
check(not RoundClock.Accept(previous, {}), "unversioned packet rejected")
check(not RoundClock.Accept(previous, false), "invalid packet rejected")

-- A delayed Racing packet must not be replaced by a Countdown packet, even
-- if the old countdown claims more time. GO remains the client's phase event.
local racing = copy(clock)
racing.phase, racing.stateSequence = "Racing", 100
check(RoundClock.Accept(previous, racing), "race accepted")
check(RoundClock.Countdown(racing, 107) == "", "helper never labels racing 1")
local stale = copy(clock)
stale.stateSequence = 99
check(not RoundClock.Accept(racing, stale), "cannot regress to Countdown")

RoundClock.Start(clock, 200, 420)
clock.phase = "Racing"
near(RoundClock.Remaining(clock, 210), 410, "race counts down normally")
local raceStart, beforeCap = clock.phaseStartedAt, clock.clockRevision
near(RoundClock.Cap(clock, 220, 90), 90, "first finisher caps game seconds")
near(clock.phaseEndsAt, 310, "cap publishes new deadline")
check(clock.clockRevision == beforeCap + 1, "cap revises clock")
check(clock.phaseStartedAt == raceStart, "cap retains race start")
local revision = clock.clockRevision
near(RoundClock.Cap(clock, 225, 90), 85, "later finish cannot extend clock")
check(clock.clockRevision == revision, "unchanged cap has no revision")

near(RoundClock.SetRate(clock, 230, 1.5), 80, "boost preserves remaining game seconds")
near(RoundClock.Remaining(clock, 232), 77, "boost rate applied once")
near(clock.phaseEndsAt, 230 + 80 / 1.5, "physical deadline reflects boost")
check(clock.phaseStartedAt == raceStart, "boost retains race start")
near(RoundClock.Cap(clock, 232, 30), 30, "cap during boost uses game seconds")
near(clock.phaseEndsAt, 252, "boosted cap converts duration to wall seconds")
near(RoundClock.Remaining(clock, 252.5), 0, "negative race duration clamped")

-- A late server frame applies acceleration at the scheduled instant, rather
-- than charging the entire frame at the newly requested rate.
RoundClock.Start(clock, 300, 100)
RoundClock.SetRate(clock, 310, 1.5)
near(RoundClock.Remaining(clock, 310.25), 89.625, "late-frame acceleration boundary")
RoundClock.Start(clock, 400, 10)
clock.phase = "Results"
near(clock.multiplier, 1, "results resets acceleration")
near(RoundClock.Remaining(clock, 401), 9, "results has ten real seconds")
RoundClock.Start(clock, 500, 0)
near(RoundClock.Remaining(clock, 500), 0, "waiting clock clears race time")
check(not pcall(RoundClock.Start, clock, 1, -1), "negative duration rejected")
check(not pcall(RoundClock.SetRate, clock, 1, 0), "zero rate rejected")
print(string.format("ROUND_CLOCK_REGRESSIONS_PASS checks=%d", checks))
