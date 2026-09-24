-- Scalar tower rules are independent of Roblox services and deterministic in tests.
local TowerRules = {}

function TowerRules.Altitude(y, baseY, finishY, previousPeak)
	local height = math.max(1, finishY - baseY)
	local current = math.clamp(y - baseY, 0, height)
	return current, math.max(previousPeak or 0, current), height, current / height
end

function TowerRules.BallisticCeiling(originY, launchSpeed, elapsed, gravity, latency)
	-- Replicated physics can arrive late or in bursts. Take the highest legitimate
	-- point in a bounded time window, rather than granting infinite airtime credit.
	local g = math.max(1, gravity)
	local early = math.max(0, elapsed - latency)
	local late = math.max(early, elapsed + latency)
	local apex = math.clamp(launchSpeed / g, early, late)
	return originY + launchSpeed * apex - 0.5 * g * apex * apex + 7
end

function TowerRules.UpdraftReady(timestamp, lastUse, airborneUsed, groundedSince, cooldown, groundTime)
	if timestamp - lastUse < cooldown then
		return false
	end
	return not airborneUsed or (groundedSince ~= nil and timestamp - groundedSince >= groundTime)
end

function TowerRules.ReachedStage(current, completed, total)
	-- CompletedStage is authored by the server, never supplied by a remote.
	-- A legitimate branch can bypass a particular rest without losing progress.
	if type(completed) ~= "number" or completed ~= completed or completed % 1 ~= 0
		or completed < 0 or completed > total then
		return current
	end
	return math.max(current, completed)
end

function TowerRules.CanFinish(phase, record, profileReady, elapsed, minimumTime)
	return phase == "Racing" and record ~= nil and not record.finished and not record.forfeited
		and profileReady and record.runStartedAt > 0 and elapsed >= minimumTime
end

function TowerRules.GroundContact(distance, feetDistance, normalY, verticalSpeed)
	-- A nearby wall, a surface above the feet, or an airborne crossing is not
	-- support. All inputs come from server raycasts and observed root physics.
	return math.abs(verticalSpeed) < 12 and normalY >= 0.7
		and distance >= feetDistance - 0.55 and distance <= feetDistance + 0.55
end

function TowerRules.HorizontalBudget(credit, dt, speed)
	-- Only walking refills this bucket; verified platform displacement is excluded.
	local walkingCap = 32 + speed * math.max(0, dt - 0.4)
	return math.min(walkingCap, credit + speed * 1.28 * dt)
end

function TowerRules.ShuttleAlpha(elapsed, period, dwell)
	period = math.max(1, period)
	dwell = math.clamp(dwell, 0, period * 0.45)
	local travel = (period - 2 * dwell) * 0.5
	local t = elapsed % period
	local function ease(value) return value * value * (3 - 2 * value) end
	if t < dwell then return 0 end
	if t < dwell + travel then return ease((t - dwell) / travel) end
	if t < 2 * dwell + travel then return 1 end
	return 1 - ease((t - 2 * dwell - travel) / travel)
end

function TowerRules.BlinkState(elapsed, period, onDuration, warningDuration)
	period = math.max(1, period)
	onDuration = math.clamp(onDuration, 0.25, period - 0.25)
	warningDuration = math.clamp(warningDuration, 0, onDuration)
	local t = elapsed % period
	local solid = t < onDuration
	return solid, solid and t >= onDuration - warningDuration
end

return TowerRules
