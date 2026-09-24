-- Ascent: independent tower climbs, one verified Updraft, moving terrain and stage rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")

local shared = ReplicatedStorage:WaitForChild("Dasher")
local Config = require(shared:WaitForChild("Config"))
local ProfileStore = require(script.Parent:WaitForChild("ProfileStore"))
local WeeklyLeaderboard = require(script.Parent:WaitForChild("WeeklyLeaderboard"))
local RoundRules = require(script.Parent:WaitForChild("RoundRules"))
local TowerRules = require(script.Parent:WaitForChild("TowerRules"))
local CourseMotion = require(script.Parent:WaitForChild("CourseMotion"))
local profiles = ProfileStore.new(Config)
local weeklyLeaderboard = WeeklyLeaderboard.new()
profiles.OnSaved = function(player, weekly)
	weeklyLeaderboard:Queue(player, weekly)
end

local remotes = shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = shared
local function remote(name)
	local item = remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
	item.Name = name
	item.Parent = remotes
	return item
end
local Action = remote("Action")
local State = remote("State")
local Feedback = remote("Feedback")
local SkillFX = remote("SkillFX")

Players.RespawnTime = 0.45
pcall(function()
	PhysicsService:RegisterCollisionGroup("DasherRacers")
end)
PhysicsService:CollisionGroupSetCollidable("DasherRacers", "DasherRacers", false)

local phase = "Waiting"
local mapId = Config.MapOrder[1]
local roundId = 0
local timeLeft = 0
local multiplier = 1
local accelerated = false
local accelerateAt = nil
local accelerationOwner = nil
local finishers = {}
local finishClaims = {}
local lastPlayedRound = {}
local roundEndReason = nil
local finalSprint = false
local roster = {}
local connections = {}
local rateLimits = {}
local activeMap = nil
local startPart = nil
local finishPart = nil
local gates = {}
local courseStages = {}
local hazards = {}
local boundsPart = nil
local courseMotion = nil
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.RespectCanCollide = true
local stopping = false
local previousMap = nil
local voteOptions, votes = {}, {}
local spectating = {}
local random = Random.new()
local activeSince = 0
local TEST_MODE = RunService:IsStudio() and workspace:GetAttribute("DasherTestMode") == true
local function testDuration(attribute, fallback)
	local value = workspace:GetAttribute(attribute)
	return TEST_MODE and type(value) == "number" and value > 0 and value < 3600 and value or fallback
end
local timings = {
	intermission = testDuration("TowerQAIntermission", TEST_MODE and 2 or Config.Intermission),
	countdown = testDuration("TowerQACountdown", TEST_MODE and 1 or Config.Countdown),
	round = testDuration("TowerQARoundDuration", TEST_MODE and 12 or Config.RoundDuration),
	results = testDuration("TowerQAResultsDuration", TEST_MODE and 2 or Config.ResultsDuration),
}

local function now()
	return workspace:GetServerTimeNow()
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function finiteVector(value)
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function characterParts(player)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	return character, character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

local function tell(player, kind, message, extra)
	if player.Parent == Players then
		Feedback:FireClient(player, kind, message, extra)
	end
end

local function announce(message)
	for _, player in Players:GetPlayers() do
		tell(player, "Toast", message)
	end
end

local function rootToFeet(root, humanoid)
	local distance = root.Size.Y * 0.5 + humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = humanoid.Parent and humanoid.Parent:FindFirstChild("Left Leg")
		distance += leg and leg:IsA("BasePart") and leg.Size.Y or 2
	end
	return distance
end

local function lobbyCFrame(player)
	local lobby = workspace:FindFirstChild("Lobby")
	local spawn = lobby and lobby:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = spawn and spawn.CFrame + Vector3.new(0, 4, 0) or CFrame.new(0, 28, 85)
	local offset = (math.abs(player.UserId) % 5 - 2) * 2.2
	local _, root, humanoid = characterParts(player)
	local lift = root and humanoid and math.max(0, rootToFeet(root, humanoid) - 4.1) or 0
	return base * CFrame.new(offset, lift, 0)
end

local function startCFrame(player)
	if not startPart then
		return lobbyCFrame(player)
	end
	local slot = roster[player] and roster[player].spawnSlot or (math.abs(player.UserId) % 10 + 1)
	local marker = activeMap and activeMap:FindFirstChild(string.format("Start%02d", slot), true)
	local base = marker and marker:IsA("BasePart") and marker.CFrame
		or startPart.CFrame * CFrame.new(((slot - 1) % 5 - 2) * 4, 0, slot <= 5 and -4 or 4)
	local _, root, humanoid = characterParts(player)
	local lift = root and humanoid and math.max(0, rootToFeet(root, humanoid) - 3.6) or 0
	return base * CFrame.new(0, lift, 0)
end

local function setCharacterMotion(player, frozen)
	local _, root, humanoid = characterParts(player)
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.WalkSpeed = frozen and 0 or Config.WalkSpeed
		humanoid.JumpPower = frozen and 0 or Config.JumpPower
		humanoid.AutoRotate = not frozen
	end
	if root then
		root.Anchored = frozen
	end
end

local function teleport(player, target, frozen)
	local character, root, humanoid = characterParts(player)
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(target)
	setCharacterMotion(player, frozen)
	local data = roster[player]
	if data then
		data.lastPosition = target.Position
		data.lastWorldPosition = target.Position
		data.lastSample = now()
		data.teleportAt = now()
		data.teleportPosition = target.Position
		data.graceUntil = now() + 0.55
		data.travelCredit = 32
		data.airOriginY = target.Position.Y
		-- Validation deliberately skips this fixed server-teleport grace. Start
		-- its initial flight clock at that boundary, so a normal jump during
		-- grace is not charged for unobserved ground time before takeoff.
		-- Subsequent landings and approved Updrafts replace this clock normally.
		data.airStartedAt = data.graceUntil
		data.airLaunchSpeed = Config.JumpPower
		data.ascentCredit = Config.JumpPower ^ 2 / (2 * workspace.Gravity) + 8
		data.groundedSince = nil
		data.impulsePendingUntil = nil
	end
	return true
end

local function refreshLeaderstats(player)
	local data = profiles:Get(player)
	local stats = player:FindFirstChild("leaderstats")
	if stats and data then
		stats.Coins.Value = data.coins
	end
end

local function altitudeFor(player, record)
	local height = startPart and finishPart and math.max(1, finishPart.Position.Y - startPart.Position.Y) or 1
	if not record then
		return {current = 0, peak = 0, height = height, stage = 0, totalStages = #gates}, 0
	end
	local current = record.finished and height or (record.currentAltitude or 0)
	return {
		current = current, peak = record.peakAltitude or 0, height = height,
		stage = record.gate, totalStages = #gates,
		rewardedStages = profiles:GetStageProgress(player, roundId),
	}, current / height
end

local function isActive(player, record)
	local _, root, humanoid = characterParts(player)
	return phase == "Racing" and record ~= nil and not record.finished and not record.forfeited
		and root ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function snapshot(player)
	local record = roster[player]
	local data = profiles:Get(player)
	local description = Config.Maps[mapId]
	local altitude, progress = altitudeFor(player, record)
	local counts = RoundRules.Tally(voteOptions, votes)
	local choices, racers = {}, {}
	for _, id in voteOptions do
		table.insert(choices, {id = id, name = Config.Maps[id].name, votes = counts[id]})
	end
	for racer, race in roster do
		if racer.Parent == Players and not race.forfeited then
			table.insert(racers, {
				userId = racer.UserId, name = racer.Name, displayName = racer.DisplayName,
				progress = select(2, altitudeFor(racer, race)), stage = race.gate,
				finished = race.finished,
			})
		end
	end
	table.sort(racers, function(a, b)
		return a.progress > b.progress or (a.progress == b.progress and a.userId < b.userId)
	end)
	return {
		phase = phase,
		mapId = mapId,
		mapName = description and description.name or mapId,
		roundId = roundId,
		roundEndReason = roundEndReason,
		finalSprint = finalSprint,
		raceCapacity = Config.MaxRacers or 10,
		timeLeft = math.max(0, timeLeft),
		multiplier = multiplier,
		finishers = finishers,
		racing = phase == "Racing" and record ~= nil and not record.finished and not record.forfeited,
		finished = record ~= nil and record.finished or false,
		forfeited = record ~= nil and record.forfeited or false,
		spectating = spectating[player] == true,
		racers = racers,
		voteOptions = phase == "Intermission" and choices or {},
		myVote = votes[player],
		canAccelerate = phase == "Racing" and accelerationOwner == player and not accelerated and timeLeft > 12,
		runStartedAt = record and record.runStartedAt or 0,
		coins = data and data.coins or 0,
		owned = data and data.owned or {ice = true},
		equipped = data and data.equipped or "ice",
		progress = progress, altitude = altitude,
		stageRewarded = profiles:GetStageProgress(player, roundId),
		abilities = {
			updraftAt = record and record.lastUpdraft > 0 and record.lastUpdraft or 0,
			updraftArmed = isActive(player, record) and (not record.updraftAirUsed
				or (record.groundedSince ~= nil and now() - record.groundedSince >= Config.UpdraftGroundTime)),
			updraftReadyAt = record and math.max(0, record.lastUpdraft + Config.UpdraftCooldown,
				(record.updraftAirUsed and record.groundedSince) and record.groundedSince + Config.UpdraftGroundTime or 0) or 0,
			updraftReady = isActive(player, record) and TowerRules.UpdraftReady(now(), record.lastUpdraft,
				record.updraftAirUsed, record.groundedSince, Config.UpdraftCooldown, Config.UpdraftGroundTime),
			updraftAirUsed = record and record.updraftAirUsed or false,
		},
		best = data and data.best[mapId] or nil,
		saveStatus = profiles:GetStatus(player),
		progression = profiles:GetProgression(player),
		leaderboard = weeklyLeaderboard:Snapshot(),
	}
end

local function sendState(player)
	if player.Parent == Players then
		local record = roster[player]
		local altitude, progress = altitudeFor(player, record)
		player:SetAttribute("DasherProgress", progress)
		player:SetAttribute("DasherAltitude", altitude.current)
		player:SetAttribute("DasherStage", altitude.stage)
		player:SetAttribute("DasherFinished", record ~= nil and record.finished or false)
		player:SetAttribute("DasherSpectating", spectating[player] == true)
		State:FireClient(player, snapshot(player))
	end
end

local function broadcastState()
	workspace:SetAttribute("DasherPhase", phase)
	workspace:SetAttribute("DasherMapId", mapId)
	workspace:SetAttribute("DasherRoundId", roundId)
	for _, player in Players:GetPlayers() do
		sendState(player)
	end
end

local function addEntrant(player)
	if not profiles:IsReady(player) or roster[player] then
		return
	end
	local connected, occupied = 0, {}
	for entrant, race in roster do
		if entrant.Parent == Players then
			connected += 1
			occupied[race.spawnSlot] = true
		end
	end
	if connected >= (Config.MaxRacers or 10) then return end
	local slot = 1
	while occupied[slot] do slot += 1 end
	local timestamp = now()
	local priorFinish = finishClaims[player.UserId]
	roster[player] = {
		roundId = roundId, gate = priorFinish and #gates or 0, finished = priorFinish ~= nil, forfeited = false,
		spawnSlot = slot,
		finishTime = priorFinish and priorFinish.time or nil,
		runStartedAt = phase == "Racing" and timestamp or 0,
		lastGateAt = timestamp,
		lastReset = -math.huge, resetCount = 0,
		lastSample = timestamp, travelCredit = 32,
		currentAltitude = 0, peakAltitude = 0,
		lastUpdraft = -math.huge, updraftAirUsed = false,
	}
	lastPlayedRound[player.UserId] = roundId
	player:SetAttribute("IsRacing", phase == "Racing" and not priorFinish)
	player:SetAttribute("UpdraftAt", 0)
	teleport(player, priorFinish and lobbyCFrame(player) or startCFrame(player), phase == "Countdown" and not priorFinish)
	sendState(player)
end

local function resetRun(player, reason)
	local record = roster[player]
	if phase ~= "Racing" or not record or record.finished or record.forfeited or now() - record.lastReset < 0.45 then
		return
	end
	record.lastReset = now()
	record.gate = 0
	record.lastGateAt = now()
	record.updraftAirUsed = false
	record.currentAltitude = 0
	record.resetCount += 1
	teleport(player, startCFrame(player), false)
	tell(player, "Reset", reason or "Back to the start. You have this.", {reason = reason, count = record.resetCount})
	sendState(player)
end

-- Swept boxes preserve gate and hazard detection between physics samples.
local function intersectsBox(part, from, to, padding)
	local a = part.CFrame:PointToObjectSpace(from)
	local b = part.CFrame:PointToObjectSpace(to)
	local direction = b - a
	local extent = part.Size * 0.5 + (typeof(padding) == "Vector3" and padding or Vector3.new(padding, padding, padding))
	local minT, maxT = 0, 1
	for _, axis in {"X", "Y", "Z"} do
		local origin, delta, limit = a[axis], direction[axis], extent[axis]
		if math.abs(delta) < 0.0001 then
			if math.abs(origin) > limit then
				return false
			end
		else
			local entry, leave = (-limit - origin) / delta, (limit - origin) / delta
			if entry > leave then
				entry, leave = leave, entry
			end
			minT = math.max(minT, entry)
			maxT = math.min(maxT, leave)
			if minT > maxT then
				return false
			end
		end
	end
	return true
end

local function creditStages(player, record, completed, quiet)
	local reached = TowerRules.ReachedStage(record.gate, completed, #gates)
	if reached <= record.gate then return end
	record.gate = reached
	record.lastGateAt = now()
	local coins, xp = 0, 0
	-- Claims are stored by UserId outside the attempt record. Filling skipped
	-- milestones is safe across falls, restarts and same-server reconnects.
	for stage = profiles:GetStageProgress(player, roundId) + 1, reached do
		local awarded, stageCoins, stageXP = profiles:RecordStage(player, roundId, stage, #gates)
		if awarded then coins += stageCoins; xp += stageXP end
	end
	if coins > 0 or xp > 0 then
		refreshLeaderstats(player)
		if not quiet then
			tell(player, "StageCompleted", "Sector " .. reached .. " cleared!", {stage = reached, coins = coins, xp = xp})
		end
	end
	sendState(player)
end

local function finishRun(player)
	local record = roster[player]
	if phase ~= "Racing" or not record or record.finished or record.forfeited or finishClaims[player.UserId]
		or not profiles:IsReady(player) or record.runStartedAt <= 0 then
		return
	end
	local elapsed = now() - record.runStartedAt
	local routeLength = (finishPart.Position - startPart.Position).Magnitude
	-- Validated crown contact ends the run. Exact rest history must not reject a
	-- legitimate Updraft shortcut; continuous movement validation still applies.
	if not TowerRules.CanFinish(phase, record, profiles:IsReady(player), elapsed,
		routeLength / math.max(Config.WalkSpeed, Config.UpdraftSpeed)) then
		resetRun(player, "Route timing could not be verified. Try again.")
		return
	end
	record.finished = true -- Commit first, before any reward path or remote response.
	record.finishTime = elapsed
	player:SetAttribute("IsRacing", false)
	local rank = #finishers + 1
	local reward = Config.FinishReward + (Config.RankBonuses[rank] or 0)
	local result = {userId = player.UserId, name = player.DisplayName, time = elapsed, coins = reward, rank = rank}
	finishClaims[player.UserId] = result
	table.insert(finishers, result)
	creditStages(player, record, #gates, true)
	profiles:AddCoins(player, reward)
	local xp = profiles:RecordFinish(player, rank)
	if weeklyLeaderboard.sessionOnly then
		weeklyLeaderboard:Queue(player, profiles:Get(player).weekly)
	end
	local personalBest = profiles:SetBest(player, mapId, elapsed)
	if rank == 1 then
		accelerationOwner = player
		finalSprint = true
		timeLeft = math.min(timeLeft, Config.FirstFinishGrace or 90)
		announce(player.DisplayName .. " reached the crown! Final sprint: " .. math.ceil(timeLeft) .. " seconds.")
	end
	refreshLeaderstats(player)
	tell(player, "Finish", personalBest and "New personal best!" or "Run complete!", {
		time = elapsed, rank = rank, coins = reward, xp = xp, personalBest = personalBest,
	})
	teleport(player, lobbyCFrame(player), false)
	broadcastState()
end

local supportOffsets = {
	Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
	Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
	Vector3.new(0.707, 0, 0.707), Vector3.new(-0.707, 0, 0.707),
	Vector3.new(0.707, 0, -0.707), Vector3.new(-0.707, 0, -0.707),
}

local function groundSupport(root, humanoid, record, timestamp)
	local verticalSpeed = root.AssemblyLinearVelocity.Y
	if math.abs(verticalSpeed) >= 12 then return nil end
	local feetDistance = rootToFeet(root, humanoid)
	local radius = math.min(0.8, math.max(root.Size.X, root.Size.Z) * 0.4)
	for _, offset in supportOffsets do
		local result = workspace:Raycast(root.Position + offset * radius,
			Vector3.new(0, -feetDistance - 0.55, 0), groundParams)
		if result and TowerRules.GroundContact(result.Distance, feetDistance, result.Normal.Y, verticalSpeed) then
			return result
		end
	end
	if courseMotion and record and timestamp and not humanoid.Jump
		and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
		and (not record.impulsePendingUntil or timestamp >= record.impulsePendingUntil) then
		return courseMotion:RecentSupport(root.Position, feetDistance, radius, supportOffsets,
			verticalSpeed, math.max(0, timestamp - activeSince))
	end
	return nil
end

local function refreshGround(record, root, humanoid, timestamp, result)
	-- Humanoids can stand with part of their footprint beyond a platform edge.
	-- Center-only rays miss that genuine support and incorrectly expire flight.
	local grounded = result ~= nil
	if record.impulsePendingUntil and timestamp < record.impulsePendingUntil then
		-- Do not mistake the approval's network round-trip for a fresh landing.
		if root.AssemblyLinearVelocity.Y > 15 or root.Position.Y > record.airOriginY + 1.5 then
			record.impulsePendingUntil = nil
		elseif grounded then
			return true, result.Instance
		end
	end
	if grounded then
		record.groundedSince = record.groundedSince or timestamp
		if timestamp - record.groundedSince >= Config.UpdraftGroundTime then
			record.updraftAirUsed = false
		end
		record.airOriginY = root.Position.Y
		record.airStartedAt = timestamp
		record.airLaunchSpeed = Config.JumpPower
		record.ascentCredit = Config.JumpPower ^ 2 / (2 * workspace.Gravity) + 8
	else
		record.groundedSince = nil
	end
	return grounded, result and result.Instance or nil
end

local function updateCourseMotion(timestamp)
	if not courseMotion then return end
	local riders = {}
	-- Check contact against the platform's old position before moving it. Merely
	-- being near a shuttle never grants motion credit. The owner applies the
	-- visual/physical carry locally so server CFrame writes cannot suppress jumping.
	for player, record in roster do
		if isActive(player, record) then
			local character, root, humanoid = characterParts(player)
			if finiteVector(root.Position) and finiteVector(root.AssemblyLinearVelocity)
				and math.abs(root.AssemblyLinearVelocity.Y) < 12
				and (not record.impulsePendingUntil or timestamp >= record.impulsePendingUntil) then
				local hit = groundSupport(root, humanoid, record, timestamp)
				local mover = hit and courseMotion.movingParts[hit.Instance]
				if mover then
					table.insert(riders, {root = root, record = record, mover = mover})
				end
			end
		end
	end
	local deltas = courseMotion:Step(math.max(0, timestamp - activeSince))
	for _, rider in riders do
		local delta = deltas[rider.mover]
		if delta and rider.root.Parent then
			local displacement = delta.Position
			local record = rider.record
			-- Account only for independently verified server-authored translation.
			-- No client delta is accepted, and no server character teleport occurs.
			-- World-route samples remain untouched for gates and hazards.
			if record.lastPosition then record.lastPosition += displacement end
			if record.airOriginY then record.airOriginY += displacement.Y end
		end
	end
end

local function validateRacer(player, record, timestamp)
	local _, root, humanoid = characterParts(player)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local position = root.Position
	if not finiteVector(position) or not finiteVector(root.AssemblyLinearVelocity) then
		resetRun(player, "Movement reset.")
		return
	end
	local boundPosition = boundsPart and boundsPart.CFrame:PointToObjectSpace(position) or position
	local extent = boundsPart and boundsPart.Size * 0.5 or Vector3.new(70, 300, 70)
	if math.abs(boundPosition.X) > extent.X or math.abs(boundPosition.Z) > extent.Z
		or math.abs(boundPosition.Y) > extent.Y then
		resetRun(player, "Back to the base. Find your next landing.")
		return
	end
	if record.graceUntil and timestamp < record.graceUntil then
		return
	end
	local previous = record.lastPosition or position
	local routePrevious = record.lastWorldPosition or previous
	local dt = math.max(0.01, timestamp - record.lastSample)
	local distance = horizontal(position - previous).Magnitude
	-- The leaky walking budget absorbs bounded replication bursts. Verified
	-- platform travel was removed from the sample before reaching this point.
	record.travelCredit = TowerRules.HorizontalBudget(record.travelCredit, dt, Config.WalkSpeed)
	if distance > record.travelCredit + 2 then
		resetRun(player, "Movement could not be verified. Starting fresh.")
		return
	end
	record.travelCredit = math.max(0, record.travelCredit - distance)
	local rise = math.max(0, position.Y - previous.Y)
	record.ascentCredit = record.ascentCredit or Config.JumpPower ^ 2 / (2 * workspace.Gravity) + 8
	local support = groundSupport(root, humanoid, record, timestamp)
	local ceiling = TowerRules.BallisticCeiling(record.airOriginY or previous.Y,
		record.airLaunchSpeed or Config.JumpPower, timestamp - (record.airStartedAt or timestamp), workspace.Gravity, 0.4)
	-- A verified landing ends the previous flight, even when its replicated
	-- arrival outlives that flight's clock. Contact never excuses excessive rise;
	-- walking, bounds and ascent credit are still checked before ground refresh.
	if rise > record.ascentCredit + 2 or (not support and position.Y > ceiling) then
		resetRun(player, "Vertical movement could not be verified. Try again.")
		return
	end
	record.ascentCredit = math.max(0, record.ascentCredit - rise)
	local grounded, groundPart = refreshGround(record, root, humanoid, timestamp, support)
	local current, peak = TowerRules.Altitude(position.Y, startPart.Position.Y, finishPart.Position.Y, record.peakAltitude)
	record.currentAltitude, record.peakAltitude = current, peak
	-- The lower-body volume catches ankle-height killbrick borders as well as
	-- torso-height rotating bars; sampling only root/feet points misses the legs.
	local feet = rootToFeet(root, humanoid)
	local rootHalf = root.Size.Y * 0.5
	local bodyOffset = Vector3.new(0, (feet - rootHalf) * 0.5, 0)
	local bodyRadius = math.max(root.Size.X, root.Size.Z) * 0.45
	local bodyPadding = Vector3.new(bodyRadius, (feet + rootHalf) * 0.5, bodyRadius)
	for _, hazard in hazards do
		if hazard.Parent and intersectsBox(hazard, routePrevious - bodyOffset, position - bodyOffset, bodyPadding) then
			resetRun(player, "Back to the start. Watch the hazards.")
			return
		end
	end
	-- Only a real landing on an authored course surface grants progress. A
	-- jump apex, scenery contact or arbitrary reported altitude grants nothing.
	-- Branches and intentional Updraft shortcuts can reach a higher milestone
	-- without touching one particular rest in every earlier sector.
	if grounded and courseStages[groundPart] ~= nil then
		creditStages(player, record, courseStages[groundPart], false)
	end
	if finishPart and intersectsBox(finishPart, routePrevious, position, 2.2) then
		finishRun(player)
		return
	end
	record.lastPosition = position
	record.lastWorldPosition = position
	record.lastSample = timestamp
end

local function applyLighting(id)
	local theme = Config.Maps[id]
	if not theme then
		return
	end
	Lighting.ClockTime = theme.clockTime
	Lighting.Ambient = theme.ambient
	Lighting.OutdoorAmbient = theme.outdoorAmbient
	Lighting.FogColor = theme.fogColor
	Lighting.FogStart = theme.fogStart
	Lighting.FogEnd = theme.fogEnd
end

local function applyLobbyLighting()
	local theme = Config.Lobby
	if type(theme) ~= "table" then
		return
	end
	for key, property in {
		clockTime = "ClockTime", ambient = "Ambient", outdoorAmbient = "OutdoorAmbient",
		fogColor = "FogColor", fogStart = "FogStart", fogEnd = "FogEnd",
	} do
		if theme[key] ~= nil then
			Lighting[property] = theme[key]
		end
	end
end

local function loadMap(id)
	local templates = ServerStorage:WaitForChild("Maps")
	local template = templates:FindFirstChild(id)
	if not template then
		warn("[Dasher] Missing map " .. id)
		return false
	end
	local clone = template:Clone()
	local mapStart = clone:FindFirstChild("Start")
	local mapFinish = clone:FindFirstChild("Finish")
	local folder = clone:FindFirstChild("Gates")
	local bounds = clone:FindFirstChild("Bounds")
	if not mapStart or not mapStart:IsA("BasePart") or not mapFinish or not mapFinish:IsA("BasePart")
		or not folder or not bounds or not bounds:IsA("BasePart") then
		clone:Destroy()
		warn("[Dasher] Map contract incomplete for " .. id)
		return false
	end
	if activeMap then
		activeMap:Destroy()
	end
	clone.Name = "ActiveMap"
	clone.Parent = workspace
	activeMap, startPart, finishPart = clone, mapStart, mapFinish
	boundsPart = bounds
	groundParams.FilterDescendantsInstances = {clone}
	gates = {}
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(gates, part)
		end
	end
	table.sort(gates, function(a, b)
		return a.Name < b.Name
	end)
	courseStages = {}
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			local marker = part:FindFirstChild("CompletedStage")
			if marker and marker:IsA("IntValue") and marker.Value >= 0 and marker.Value <= #gates then
				courseStages[part] = marker.Value
			end
		end
	end
	hazards = {}
	local hazardFolder = clone:FindFirstChild("Hazards")
	if hazardFolder then
		for _, item in hazardFolder:GetChildren() do
			if item:IsA("BasePart") then
				table.insert(hazards, item)
			elseif item:IsA("Model") then
				local motion, bar = item:FindFirstChild("Motion"), item:FindFirstChild("Bar")
				if motion and motion:IsA("StringValue") and motion.Value == "Spinner"
					and bar and bar:IsA("BasePart") then
					table.insert(hazards, bar)
				end
			end
		end
	end
	courseMotion = CourseMotion.new(clone)
	mapId = id
	applyLighting(id)
	return true
end

local function handleCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or player.Parent ~= Players or player.Character ~= character then
		return
	end
	local function groupPart(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = "DasherRacers"
		end
	end
	for _, item in character:GetDescendants() do
		groupPart(item)
	end
	local descendantConnection = character.DescendantAdded:Connect(groupPart)
	character.Destroying:Once(function()
		descendantConnection:Disconnect()
	end)
	setCharacterMotion(player, false)
	humanoid.Died:Once(function()
		local record = roster[player]
		if record and not record.finished and not record.forfeited then
			record.gate = 0
			record.currentAltitude = 0
			record.updraftAirUsed = false
			record.lastGateAt = now()
		end
	end)
	local record = roster[player]
	if (phase == "Racing" or phase == "Countdown") and record and not record.finished and not record.forfeited then
		record.gate = 0
		record.lastGateAt = now()
		teleport(player, startCFrame(player), phase == "Countdown")
		tell(player, "Reset", "Back to the start.")
	else
		teleport(player, lobbyCFrame(player), false)
	end
end

local function playerAdded(player)
	if connections[player] then
		return
	end
	player:SetAttribute("IsRacing", false)
	player:SetAttribute("EquippedTrail", "ice")
	player:SetAttribute("UpdraftAt", 0)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	connections[player] = player.CharacterAdded:Connect(function(character)
		handleCharacter(player, character)
	end)
	if player.Character then
		task.spawn(handleCharacter, player, player.Character)
	end
	task.spawn(function()
		local data, status = profiles:Load(player)
		if player.Parent ~= Players then
			profiles:Release(player)
			return
		end
		player:SetAttribute("EquippedTrail", data.equipped)
		refreshLeaderstats(player)
		if status == "saved" or status == "session" then
			weeklyLeaderboard:Queue(player, data.weekly)
		end
		if status == "error" then
			tell(player, "Error", "Saved progress is unavailable. You can play, but this session will not be saved.")
		end
		if phase == "Racing" or phase == "Countdown" then
			addEntrant(player)
		end
		sendState(player)
	end)
end

local function allowAction(player, action)
	local timestamp = now()
	local limit = rateLimits[player]
	if not limit then
		limit = {tokens = 20, updatedAt = timestamp, actions = {}}
		rateLimits[player] = limit
	end
	limit.tokens = math.min(20, limit.tokens + (timestamp - limit.updatedAt) * 12)
	limit.updatedAt = timestamp
	if limit.tokens < 1 then
		return false
	end
	limit.tokens -= 1
	local interval = 0.25
	if timestamp - (limit.actions[action] or -math.huge) < interval then
		return false
	end
	limit.actions[action] = timestamp
	return true
end

local knownActions = {
	Ready = true, Restart = true, Accelerate = true, Buy = true, Equip = true,
	Vote = true, Spectate = true, ClaimDaily = true, ClaimWeekly = true,
	Updraft = true,
}
Action.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" or not knownActions[action] then
		return
	end
	-- Stopping a camera mode must work even immediately after entering it or when
	-- the client discovers there are no valid targets. It grants no eligibility,
	-- and an already stopped state performs no work, so repeated exits are inert.
	if action == "Spectate" and payload == false then
		if spectating[player] then
			spectating[player] = false
			sendState(player)
		end
		return
	end
	if not allowAction(player, action) then
		return
	end
	if action == "Ready" then
		sendState(player)
	elseif action == "Updraft" then
		local record = roster[player]
		local _, root = characterParts(player)
		local timestamp = now()
		if not isActive(player, record) or not finiteVector(root.Position) or not finiteVector(root.AssemblyLinearVelocity)
			or not TowerRules.UpdraftReady(timestamp, record.lastUpdraft,
			record.updraftAirUsed, record.groundedSince, Config.UpdraftCooldown, Config.UpdraftGroundTime) then
			tell(player, "SkillDenied", "Updraft needs a landing and its cooldown.", {skill = "Updraft"})
			return
		end
		record.lastUpdraft = timestamp
		record.updraftAirUsed = true
		record.groundedSince = nil
		record.airOriginY = root.Position.Y
		record.airStartedAt = timestamp
		record.airLaunchSpeed = Config.UpdraftSpeed
		record.impulsePendingUntil = timestamp + 0.5
		record.ascentCredit = math.min(60, (record.ascentCredit or 0) + Config.UpdraftSpeed ^ 2 / (2 * workspace.Gravity) + 8)
		local horizontalSpeed = horizontal(root.AssemblyLinearVelocity)
		if horizontalSpeed.Magnitude > (Config.WalkSpeed * 1.35) then
			horizontalSpeed = horizontalSpeed.Unit * (Config.WalkSpeed * 1.35)
		end
		local velocity = horizontalSpeed + Vector3.new(0, Config.UpdraftSpeed, 0)
		player:SetAttribute("UpdraftAt", timestamp)
		tell(player, "Updraft", "", {at = timestamp, velocity = velocity})
		SkillFX:FireAllClients("Updraft", {userId = player.UserId, position = root.Position, at = timestamp})
		sendState(player)
	elseif action == "Vote" then
		if phase ~= "Intermission" or not profiles:IsReady(player) or type(payload) ~= "string"
			or #payload > 32 or not table.find(voteOptions, payload) then
			return
		end
		votes[player] = payload
		broadcastState()
	elseif action == "Spectate" then
		if type(payload) ~= "boolean" then
			return
		end
		if payload and (phase ~= "Racing" or not profiles:IsReady(player)) then
			return
		end
		local record = roster[player]
		if payload and record and not record.finished and not record.forfeited then
			record.forfeited = true
			record.gate = 0
			player:SetAttribute("IsRacing", false)
			teleport(player, lobbyCFrame(player), false)
			tell(player, "Toast", "Spectating until the next race. This run was forfeited.")
		end
		spectating[player] = payload
		sendState(player)
	elseif action == "ClaimDaily" or action == "ClaimWeekly" then
		local ok, message
		if action == "ClaimDaily" then
			ok, message = profiles:ClaimDaily(player)
		else
			ok, message = profiles:ClaimWeekly(player)
		end
		if ok then
			refreshLeaderstats(player)
			task.spawn(function()
				profiles:Save(player, false)
			end)
		end
		tell(player, ok and "Reward" or "Error", message)
		sendState(player)
	elseif action == "Restart" then
		resetRun(player, "Fresh attempt. The clock keeps running.")
	elseif action == "Accelerate" then
		if phase == "Racing" and accelerationOwner == player and not accelerated and timeLeft > 12 then
			accelerated = true
			accelerateAt = now() + 3
			announce("Clock boost in 3 seconds. Keep moving!")
			broadcastState()
		end
	elseif action == "Buy" or action == "Equip" then
		if type(payload) ~= "string" or #payload > 24 then
			return
		end
		local ok, message
		if action == "Buy" then
			ok, message = profiles:Buy(player, payload)
		else
			ok, message = profiles:Equip(player, payload)
		end
		if ok then
			player:SetAttribute("EquippedTrail", payload)
			refreshLeaderstats(player)
			tell(player, "Purchase", message, {id = payload, coins = profiles:Get(player).coins})
		else
			tell(player, "Error", message)
		end
		sendState(player)
	end
end)

Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(function(player)
	roster[player] = nil
	votes[player] = nil
	spectating[player] = nil
	rateLimits[player] = nil
	if connections[player] then
		connections[player]:Disconnect()
		connections[player] = nil
	end
	if accelerationOwner == player and not accelerated then
		accelerationOwner = nil
	end
	task.spawn(function()
		profiles:Release(player)
	end)
end)
for _, player in Players:GetPlayers() do
	playerAdded(player)
end

local stateAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	stateAccumulator += dt
	if phase == "Racing" then
		local timestamp = now()
		updateCourseMotion(timestamp)
		-- A queued jump can leave a narrow landing in less than 0.08 seconds.
		-- Observe it at the physics cadence using the complete validation path,
		-- rather than granting unverified ground credit or extra airborne time.
		for player, record in roster do
			if player.Parent == Players and not record.finished and not record.forfeited then
				validateRacer(player, record, timestamp)
			end
		end
	end
	if stateAccumulator >= 0.25 then
		stateAccumulator = 0
		broadcastState()
	end
end)

task.spawn(function()
	while not stopping do
		task.wait(45)
		for _, player in Players:GetPlayers() do
			task.spawn(function()
				profiles:Save(player, false)
			end)
		end
	end
end)

task.spawn(function()
	while not stopping do
		weeklyLeaderboard:Flush()
		weeklyLeaderboard:Refresh()
		task.wait(45)
	end
end)

local function waitPhase(duration)
	timeLeft = duration
	broadcastState()
	local previous = now()
	while timeLeft > 0 and not stopping do
		task.wait(0.1)
		local timestamp = now()
		timeLeft = math.max(0, timeLeft - (timestamp - previous))
		previous = timestamp
		if #Players:GetPlayers() == 0 then
			return false
		end
	end
	return not stopping
end

local function runRounds()
	while not stopping do
		phase = "Waiting"
		timeLeft = 0
		while #Players:GetPlayers() == 0 and not stopping do
			task.wait(0.3)
		end
		if stopping then
			break
		end
		phase = "Intermission"
		applyLobbyLighting()
		multiplier = 1
		accelerated, accelerateAt, accelerationOwner = false, nil, nil
		finishers, roster, spectating, votes = {}, {}, {}, {}
		finishClaims = {}
		roundEndReason, finalSprint = nil, false
		for _, player in Players:GetPlayers() do
			player:SetAttribute("IsRacing", false)
			teleport(player, lobbyCFrame(player), false)
		end
		voteOptions = RoundRules.ChooseOptions(Config.MapOrder, previousMap, random)
		if not waitPhase(timings.intermission) then
			continue
		end
		mapId = RoundRules.Resolve(voteOptions, votes, random) or Config.MapOrder[1]
		if not loadMap(mapId) then
			announce("The course is being prepared. Retrying shortly.")
			task.wait(3)
			continue
		end
		previousMap = mapId
		roundId += 1
		profiles:BeginStageRound(roundId)
		phase = "Countdown"
		for _, player in RoundRules.SelectEntrants(Players:GetPlayers(), lastPlayedRound, Config.MaxRacers or 10) do
			addEntrant(player)
		end
		if not waitPhase(timings.countdown) then
			continue
		end
		phase = "Racing"
		timeLeft = timings.round
		activeSince = now()
		for player, record in roster do
			record.runStartedAt = activeSince
			record.lastGateAt = activeSince
			player:SetAttribute("IsRacing", true)
			teleport(player, startCFrame(player), false)
		end
		broadcastState()
		local previous = now()
		while timeLeft > 0 and not stopping and #Players:GetPlayers() > 0 do
			task.wait(0.05)
			local timestamp = now()
			if accelerateAt and timestamp >= accelerateAt then
				multiplier = Config.SpeedMultiplier
				accelerateAt = nil
			end
			timeLeft = math.max(0, timeLeft - (timestamp - previous) * multiplier)
			previous = timestamp
			local ended, reason = RoundRules.RaceStatus(roster, function(player)
				return player.Parent == Players
			end, timeLeft, timestamp - activeSince)
			if ended then
				roundEndReason = reason
				break
			end
		end
		phase = "Results"
		roundEndReason = roundEndReason or (timeLeft <= 0 and "TimeUp" or "NoRacers")
		spectating = {}
		applyLobbyLighting()
		for _, player in Players:GetPlayers() do
			player:SetAttribute("IsRacing", false)
			teleport(player, lobbyCFrame(player), false)
		end
		waitPhase(timings.results)
	end
end

-- The first lobby visit should already show what players will climb.
-- This uses the same active-map slot; the voted tower replaces it at countdown.
loadMap(Config.MapOrder[1])
applyLobbyLighting()
task.spawn(runRounds)
game:BindToClose(function()
	stopping = true
	profiles:Close()
	weeklyLeaderboard:Close()
end)
