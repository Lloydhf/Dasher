-- Dasher: server-owned rounds, ordered route validation, rewards and profile state.
-- Movement is predicted by the owning client. This script validates it; it never
-- applies a second dash impulse, which would double the local movement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")

local shared = ReplicatedStorage:WaitForChild("Dasher")
local Config = require(shared:WaitForChild("Config"))
local ProfileStore = require(script.Parent:WaitForChild("ProfileStore"))
local profiles = ProfileStore.new(Config)

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
local DashFX = remote("DashFX")

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
local roster = {}
local connections = {}
local rateLimits = {}
local activeMap = nil
local startPart = nil
local finishPart = nil
local gates = {}
local hazards = {}
local stopping = false
local mapIndex = 0
local activeSince = 0
local TEST_MODE = RunService:IsStudio() and workspace:GetAttribute("DasherTestMode") == true
local timings = {
	intermission = TEST_MODE and 2 or Config.Intermission,
	countdown = TEST_MODE and 1 or Config.Countdown,
	round = TEST_MODE and 12 or Config.RoundDuration,
	results = TEST_MODE and 2 or Config.ResultsDuration,
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

local function lobbyCFrame(player)
	local lobby = workspace:FindFirstChild("Lobby")
	local spawn = lobby and lobby:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = spawn and spawn.CFrame + Vector3.new(0, 4, 0) or CFrame.new(0, 28, 85)
	local offset = (math.abs(player.UserId) % 5 - 2) * 2.2
	return base * CFrame.new(offset, 0, 0)
end

local function startCFrame(player)
	if not startPart then
		return lobbyCFrame(player)
	end
	local offset = (math.abs(player.UserId) % 5 - 2) * 1.6
	return startPart.CFrame * CFrame.new(offset, 0, 0)
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
		data.lastSample = now()
		data.teleportAt = now()
		data.teleportPosition = target.Position
		data.graceUntil = now() + 0.55
		data.travelCredit = 32
		data.airSince = nil
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

local function snapshot(player)
	local record = roster[player]
	local data = profiles:Get(player)
	local description = Config.Maps[mapId]
	return {
		phase = phase,
		mapId = mapId,
		mapName = description and description.name or mapId,
		roundId = roundId,
		timeLeft = math.max(0, timeLeft),
		multiplier = multiplier,
		finishers = finishers,
		racing = phase == "Racing" and record ~= nil and not record.finished,
		finished = record ~= nil and record.finished or false,
		canAccelerate = phase == "Racing" and accelerationOwner == player and not accelerated and timeLeft > 12,
		runStartedAt = record and record.runStartedAt or 0,
		coins = data and data.coins or 0,
		owned = data and data.owned or {ice = true},
		equipped = data and data.equipped or "ice",
		progress = record and (record.finished and 1 or record.gate / math.max(1, #gates + 1)) or 0,
		best = data and data.best[mapId] or nil,
		saveStatus = profiles:GetStatus(player),
	}
end

local function sendState(player)
	if player.Parent == Players then
		local record = roster[player]
		player:SetAttribute("DasherProgress", record and (record.finished and 1 or record.gate / math.max(1, #gates + 1)) or 0)
		player:SetAttribute("DasherFinished", record ~= nil and record.finished or false)
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
	local timestamp = now()
	roster[player] = {
		roundId = roundId, gate = 0, finished = false,
		runStartedAt = phase == "Racing" and timestamp or 0,
		lastGateAt = timestamp, lastDash = -math.huge,
		lastReset = -math.huge, resetCount = 0,
		lastSample = timestamp, travelCredit = 32,
	}
	player:SetAttribute("IsRacing", phase == "Racing")
	player:SetAttribute("DashAt", 0)
	teleport(player, startCFrame(player), phase == "Countdown")
	sendState(player)
end

local function resetRun(player, reason)
	local record = roster[player]
	if phase ~= "Racing" or not record or record.finished or now() - record.lastReset < 0.45 then
		return
	end
	record.lastReset = now()
	record.gate = 0
	record.lastGateAt = now()
	record.lastDash = -math.huge
	record.resetCount += 1
	player:SetAttribute("DashAt", 0)
	teleport(player, startCFrame(player), false)
	tell(player, "Reset", reason or "Back to the start. You have this.", {reason = reason, count = record.resetCount})
	sendState(player)
end

-- Server-side swept box test catches fast dashes that cross a gate between samples.
local function intersectsBox(part, from, to, padding)
	local a = part.CFrame:PointToObjectSpace(from)
	local b = part.CFrame:PointToObjectSpace(to)
	local direction = b - a
	local extent = part.Size * 0.5 + Vector3.new(padding, padding, padding)
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

local function finishRun(player)
	local record = roster[player]
	if phase ~= "Racing" or not record or record.finished or record.gate ~= #gates
		or not profiles:IsReady(player) or record.runStartedAt <= 0 then
		return
	end
	local elapsed = now() - record.runStartedAt
	local routeLength = horizontal(finishPart.Position - startPart.Position).Magnitude
	-- Generous speed bound: a honest dash + run route is considerably slower.
	if elapsed < routeLength / (Config.WalkSpeed + Config.DashSpeed * 0.48) then
		resetRun(player, "Route timing could not be verified. Try again.")
		return
	end
	record.finished = true -- Commit first, before any reward path or remote response.
	record.finishTime = elapsed
	player:SetAttribute("IsRacing", false)
	local rank = #finishers + 1
	local reward = Config.FinishReward + (Config.RankBonuses[rank] or 0)
	profiles:AddCoins(player, reward)
	local personalBest = profiles:SetBest(player, mapId, elapsed)
	table.insert(finishers, {userId = player.UserId, name = player.DisplayName, time = elapsed, coins = reward})
	if rank == 1 then
		accelerationOwner = player
		announce(player.DisplayName .. " finished first. The clock can be accelerated!")
	end
	refreshLeaderstats(player)
	tell(player, "Finish", personalBest and "New personal best!" or "Run complete!", {
		time = elapsed, rank = rank, coins = reward, personalBest = personalBest,
	})
	teleport(player, lobbyCFrame(player), false)
	broadcastState()
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
	if position.Y < 3 or math.abs(position.X) > 110 or position.Y > 130
		or position.Z > 50 or (finishPart and position.Z < finishPart.Position.Z - 65) then
		resetRun(player, "Back to the start. Keep your momentum.")
		return
	end
	if record.graceUntil and timestamp < record.graceUntil then
		return
	end
	local previous = record.lastPosition or position
	local dt = math.max(0.01, timestamp - record.lastSample)
	local distance = horizontal(position - previous).Magnitude
	-- Leaky movement budget absorbs replication bursts; accepted dashes add a
	-- finite distance allowance rather than allowing arbitrary dash-speed movement.
	record.travelCredit = math.min(40 + Config.WalkSpeed * math.max(0, dt - 0.4), record.travelCredit + Config.WalkSpeed * 1.28 * dt)
	if distance > record.travelCredit + 2 then
		resetRun(player, "Movement could not be verified. Starting fresh.")
		return
	end
	record.travelCredit = math.max(0, record.travelCredit - distance)
	if humanoid.FloorMaterial == Enum.Material.Air then
		record.airSince = record.airSince or timestamp
		if timestamp - record.airSince > 3.0 then
			resetRun(player, "Back to the start.")
			return
		end
	else
		record.airSince = nil
	end
	for _, hazard in hazards do
		local footOffset = Vector3.new(0, root.Size.Y * 0.5 + humanoid.HipHeight - 0.1, 0)
		if hazard.Parent and (intersectsBox(hazard, previous, position, 1.05)
			or intersectsBox(hazard, previous - footOffset, position - footOffset, 0.4)) then
			resetRun(player, "Back to the start. Watch the hazards.")
			return
		end
	end
	local nextGate = gates[record.gate + 1]
	if nextGate and intersectsBox(nextGate, previous, position, 2.4) then
		local gateOrigin = record.gate > 0 and gates[record.gate].Position or startPart.Position
		local minTime = horizontal(nextGate.Position - gateOrigin).Magnitude / (Config.DashSpeed * 1.8)
		if timestamp - record.lastGateAt < minTime then
			resetRun(player, "Route timing could not be verified. Try again.")
			return
		end
		record.gate += 1
		record.lastGateAt = timestamp
	end
	if finishPart and intersectsBox(finishPart, previous, position, 2.2) then
		if record.gate == #gates then
			finishRun(player)
		else
			resetRun(player, "Stay on the course to finish the race.")
		end
		return
	end
	record.lastPosition = position
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
	if not mapStart or not mapStart:IsA("BasePart") or not mapFinish or not mapFinish:IsA("BasePart") or not folder then
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
	gates = {}
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(gates, part)
		end
	end
	table.sort(gates, function(a, b)
		return a.Name < b.Name
	end)
	hazards = {}
	local hazardFolder = clone:FindFirstChild("Hazards")
	if hazardFolder then
		for _, part in hazardFolder:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(hazards, part)
			end
		end
	end
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
		if record and not record.finished then
			record.gate = 0
			record.lastDash = -math.huge
			record.lastGateAt = now()
			player:SetAttribute("DashAt", 0)
		end
	end)
	local record = roster[player]
	if (phase == "Racing" or phase == "Countdown") and record and not record.finished then
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
	player:SetAttribute("DashAt", 0)
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
	local interval = action == "Ready" and 0.25 or (action == "Dash" and 0.08 or 0.25)
	if timestamp - (limit.actions[action] or -math.huge) < interval then
		return false
	end
	limit.actions[action] = timestamp
	return true
end

local knownActions = {Ready = true, Dash = true, Restart = true, Accelerate = true, Buy = true, Equip = true}
Action.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" or not knownActions[action] or not allowAction(player, action) then
		return
	end
	if action == "Ready" then
		sendState(player)
	elseif action == "Dash" then
		local record = roster[player]
		local _, root, humanoid = characterParts(player)
		local timestamp = now()
		if phase ~= "Racing" or not record or record.finished or not root or not humanoid or humanoid.Health <= 0
			or not finiteVector(payload) or math.abs(payload.Y) > 0.05 or payload.Magnitude < 0.5 or payload.Magnitude > 1.5
			or timestamp - record.lastDash < Config.DashCooldown - 0.06 then
			tell(player, "DashDenied", "Dash is not ready.")
			return
		end
		local direction = horizontal(payload).Unit
		record.lastDash = timestamp
		record.travelCredit = math.min(58, record.travelCredit + (Config.DashSpeed - Config.WalkSpeed) * Config.DashDuration * 1.35)
		player:SetAttribute("DashAt", timestamp)
		DashFX:FireAllClients(player, direction)
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

local stateAccumulator, validationAccumulator = 0, 0
RunService.Heartbeat:Connect(function(dt)
	stateAccumulator += dt
	validationAccumulator += dt
	if phase == "Racing" and validationAccumulator >= 0.08 then
		validationAccumulator = 0
		local timestamp = now()
		for player, record in roster do
			if player.Parent == Players and not record.finished then
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
		multiplier = 1
		accelerated, accelerateAt, accelerationOwner = false, nil, nil
		finishers, roster = {}, {}
		for _, player in Players:GetPlayers() do
			player:SetAttribute("IsRacing", false)
			teleport(player, lobbyCFrame(player), false)
		end
		mapIndex = mapIndex % #Config.MapOrder + 1
		mapId = Config.MapOrder[mapIndex]
		if not waitPhase(timings.intermission) then
			continue
		end
		if not loadMap(mapId) then
			announce("The course is being prepared. Retrying shortly.")
			task.wait(3)
			continue
		end
		roundId += 1
		phase = "Countdown"
		for _, player in Players:GetPlayers() do
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
			local entrants, unfinished = 0, 0
			for player, record in roster do
				if player.Parent == Players then
					entrants += 1
					if not record.finished then
						unfinished += 1
					end
				end
			end
			if entrants > 0 and unfinished == 0 and timestamp - activeSince > 2 then
				break
			end
		end
		phase = "Results"
		for _, player in Players:GetPlayers() do
			player:SetAttribute("IsRacing", false)
			teleport(player, lobbyCFrame(player), false)
		end
		waitPhase(timings.results)
	end
end

task.spawn(runRounds)
game:BindToClose(function()
	stopping = true
	profiles:Close()
end)
