-- One record per player, serialized UpdateAsync writes, and an expiring session lock.
-- Studio always uses memory: enabling Studio API access must never alter live progress.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ProfileStore = {}
ProfileStore.__index = ProfileStore

local SCHEMA = 2
local COURSE_VERSION = 2
local LOCK_SECONDS = 180
local MAX_COINS = 100000000
local MAX_XP = 100000000
local XP_PER_LEVEL = 500
local DAILY_REWARD = 25
local WEEKLY_TARGET = 10
local WEEKLY_REWARD = 80

local function weekKey(timestamp)
	-- Monday 00:00 UTC; Jan 1 1970 was a Thursday.
	return tostring(math.floor((timestamp + 3 * 86400) / (7 * 86400)))
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function defaultData(courseVersion)
	return {
		version = SCHEMA, courseVersion = courseVersion or COURSE_VERSION,
		coins = 0, owned = {ice = true}, equipped = "ice", best = {}, legacyBest = {},
		xp = 0, dailyDay = -1,
		weekly = {key = weekKey(os.time()), finishes = 0, score = 0, claimed = false},
	}
end

function ProfileStore.new(config)
	local self = setmetatable({}, ProfileStore)
	self.records = {}
	self.cosmetics = {}
	self.mapIds = {}
	self.sessionId = (game.JobId ~= "" and game.JobId or "studio") .. ":" .. HttpService:GenerateGUID(false)
	self.sessionOnly = RunService:IsStudio() or game.GameId == 0
	self.closing = false
	self.courseVersion = config.CourseVersion or COURSE_VERSION
	self.xpPerLevel = config.XPPerLevel or XP_PER_LEVEL
	self.xpPerFinish = config.XPPerFinish or 100
	self.xpWinBonus = config.XPWinBonus or 50
	self.dailyReward = config.DailyReward or DAILY_REWARD
	self.weeklyTarget = config.WeeklyFinishTarget or WEEKLY_TARGET
	self.weeklyReward = config.WeeklyReward or WEEKLY_REWARD
	for _, cosmetic in config.Cosmetics do
		self.cosmetics[cosmetic.id] = cosmetic
	end
	for _, id in config.MapOrder do
		self.mapIds[id] = true
	end
	if not self.sessionOnly then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore("DasherProfiles_v1")
		end)
		if ok then
			self.store = store
		else
			warn("[Dasher] Persistent storage unavailable; existing data will not be overwritten.")
		end
	end
	return self
end

function ProfileStore:_sanitize(raw)
	local data = defaultData(self.courseVersion)
	if type(raw) ~= "table" then
		return data
	end
	if finite(raw.coins) then
		data.coins = math.clamp(math.floor(raw.coins), 0, MAX_COINS)
	end
	if type(raw.owned) == "table" then
		for id in self.cosmetics do
			if raw.owned[id] == true then
				data.owned[id] = true
			end
		end
	end
	if type(raw.equipped) == "string" and data.owned[raw.equipped] then
		data.equipped = raw.equipped
	end
	local oldCourses = raw.courseVersion ~= self.courseVersion
	if type(raw.best) == "table" then
		for id in self.mapIds do
			local time = raw.best[id]
			if finite(time) and time > 0 and time < 3600 then
				if oldCourses then
					data.legacyBest[id] = time
				else
					data.best[id] = time
				end
			end
		end
	end
	if type(raw.legacyBest) == "table" then
		for id in self.mapIds do
			local time = raw.legacyBest[id]
			if finite(time) and time > 0 and time < 3600 then
				data.legacyBest[id] = time
			end
		end
	end
	if finite(raw.xp) then
		data.xp = math.clamp(math.floor(raw.xp), 0, MAX_XP)
	end
	if finite(raw.dailyDay) then
		data.dailyDay = math.clamp(math.floor(raw.dailyDay), -1, math.floor(os.time() / 86400))
	end
	if type(raw.weekly) == "table" and raw.weekly.key == data.weekly.key then
		for _, field in {"finishes", "score"} do
			if finite(raw.weekly[field]) then
				data.weekly[field] = math.clamp(math.floor(raw.weekly[field]), 0, MAX_XP)
			end
		end
		data.weekly.claimed = raw.weekly.claimed == true
	end
	return data
end

function ProfileStore:Load(player)
	local record = {
		data = defaultData(self.courseVersion), status = "loading", writable = false,
		busy = true, ready = false, closing = false, revision = 0,
		lockId = self.sessionId .. ":" .. HttpService:GenerateGUID(false),
	}
	self.records[player] = record
	if self.sessionOnly or not self.store then
		record.status = self.sessionOnly and "session" or "error"
		record.busy = false
		record.ready = true
		return record.data, record.status
	end
	local key = "player_" .. tostring(player.UserId)
	for attempt = 1, 3 do
		local conflict = false
		local unsupported = false
		local ok, result = pcall(function()
			return self.store:UpdateAsync(key, function(old)
				-- An unknown schema is left untouched rather than replaced by defaults.
				if old ~= nil and (type(old) ~= "table" or (old.version ~= 1 and old.version ~= SCHEMA)) then
					unsupported = true
					return nil
				end
				local lock = old and old.session
				if type(lock) == "table" and lock.id ~= record.lockId
					and finite(lock.updatedAt) and os.time() - lock.updatedAt < LOCK_SECONDS then
					conflict = true
					return nil
				end
				local data = self:_sanitize(old)
				data.session = {id = record.lockId, updatedAt = os.time()}
				return data
			end)
		end)
		if ok and result and result.session and result.session.id == record.lockId then
			record.data = self:_sanitize(result)
			record.status = "saved"
			record.writable = true
			break
		end
		if unsupported then
			warn("[Dasher] Unsupported profile schema for " .. player.UserId .. "; leaving saved data untouched.")
			break
		end
		if attempt < 3 and not self.closing then
			task.wait((conflict and 2 or 0.6) * attempt + math.random() * 0.3)
		end
	end
	if not record.writable then
		record.status = "error"
		warn("[Dasher] Profile load failed/locked for " .. player.UserId .. "; session data cannot overwrite storage.")
	end
	-- Never swap these defaults into persistent storage after a failed read.
	record.ready = true
	record.busy = false
	return record.data, record.status
end

function ProfileStore:Get(player)
	local record = self.records[player]
	return record and record.data or nil
end

function ProfileStore:IsReady(player)
	local record = self.records[player]
	return record ~= nil and record.ready and not record.closing
end

function ProfileStore:GetStatus(player)
	local record = self.records[player]
	return record and record.status or "loading"
end

function ProfileStore:AddCoins(player, amount)
	local record = self.records[player]
	if not self:IsReady(player) or not finite(amount) or amount < 0 then
		return false
	end
	record.data.coins = math.clamp(record.data.coins + math.floor(amount), 0, MAX_COINS)
	record.revision += 1
	return true
end

function ProfileStore:Buy(player, id)
	local record = self.records[player]
	local item = self.cosmetics[id]
	if not self:IsReady(player) or not item then
		return false, "That trail is unavailable."
	end
	if record.data.owned[id] then
		return false, "You already own this trail."
	end
	if record.data.coins < item.price then
		return false, "Not enough coins yet. Finish a race to earn more."
	end
	-- No yields between debit and grant: this is one in-memory transaction.
	record.data.coins -= item.price
	record.data.owned[id] = true
	record.data.equipped = id
	record.revision += 1
	return true, item.name .. " unlocked."
end

function ProfileStore:Equip(player, id)
	local record = self.records[player]
	if not self:IsReady(player) or not self.cosmetics[id] or not record.data.owned[id] then
		return false, "Unlock this trail before equipping it."
	end
	record.data.equipped = id
	record.revision += 1
	return true, self.cosmetics[id].name .. " equipped."
end

function ProfileStore:SetBest(player, mapId, seconds)
	local record = self.records[player]
	if not self:IsReady(player) or not self.mapIds[mapId] or not finite(seconds) or seconds <= 0 then
		return false
	end
	local previous = record.data.best[mapId]
	if not previous or seconds < previous then
		record.data.best[mapId] = seconds
		record.revision += 1
		return true
	end
	return false
end

function ProfileStore:_currentWeek(record)
	local key = weekKey(os.time())
	if record.data.weekly.key ~= key then
		record.data.weekly = {key = key, finishes = 0, score = 0, claimed = false}
		record.revision += 1
	end
	return record.data.weekly
end

function ProfileStore:GetProgression(player)
	local record = self.records[player]
	if not record or not record.ready then
		return nil
	end
	local weekly = self:_currentWeek(record)
	local xp = record.data.xp
	local perLevel = self.xpPerLevel
	return {
		xp = xp, level = 1 + math.floor(xp / perLevel), xpIntoLevel = xp % perLevel,
		xpPerLevel = perLevel, xpToNext = perLevel - xp % perLevel,
		dailyAvailable = record.data.dailyDay < math.floor(os.time() / 86400), dailyReward = self.dailyReward,
		weeklyProgress = weekly.finishes, weeklyTarget = self.weeklyTarget, weeklyClaimed = weekly.claimed,
		weeklyReward = self.weeklyReward, weeklyKey = weekly.key, weeklyScore = weekly.score,
	}
end

function ProfileStore:RecordFinish(player, rank)
	local record = self.records[player]
	if not self:IsReady(player) then
		return 0
	end
	local gained = self.xpPerFinish + (rank == 1 and self.xpWinBonus or 0)
	local weekly = self:_currentWeek(record)
	weekly.finishes = math.min(MAX_XP, weekly.finishes + 1)
	weekly.score = math.min(MAX_XP, weekly.score + gained)
	record.data.xp = math.min(MAX_XP, record.data.xp + gained)
	record.revision += 1
	return gained
end

function ProfileStore:ClaimDaily(player)
	local record = self.records[player]
	if not self:IsReady(player) then
		return false, "Progress is still loading."
	end
	local day = math.floor(os.time() / 86400)
	if record.data.dailyDay >= day then
		return false, "Today's reward has already been claimed."
	end
	-- Mark and credit without a yield so simultaneous requests cannot double claim.
	record.data.dailyDay = day
	self:AddCoins(player, self.dailyReward)
	return true, "+" .. self.dailyReward .. " coins. Come back tomorrow UTC!"
end

function ProfileStore:ClaimWeekly(player)
	local record = self.records[player]
	if not self:IsReady(player) then
		return false, "Progress is still loading."
	end
	local weekly = self:_currentWeek(record)
	if weekly.claimed then
		return false, "This week's reward has already been claimed."
	end
	if weekly.finishes < self.weeklyTarget then
		return false, "Finish " .. self.weeklyTarget .. " races this week to claim this reward."
	end
	weekly.claimed = true
	self:AddCoins(player, self.weeklyReward)
	return true, "+" .. self.weeklyReward .. " coins. Weekly challenge complete!"
end

function ProfileStore:Save(player, release)
	local record = self.records[player]
	if not record or not record.ready or not record.writable or record.busy then
		return false
	end
	record.busy = true
	local snapshot = self:_sanitize(record.data)
	local key = "player_" .. tostring(player.UserId)
	local succeeded = false
	local lostLock = false
	for attempt = 1, 3 do
		local wrote = false
		local ok = pcall(function()
			self.store:UpdateAsync(key, function(old)
				if type(old) ~= "table" or old.version ~= SCHEMA
					or type(old.session) ~= "table" or old.session.id ~= record.lockId then
					lostLock = true
					return nil
				end
				local output = self:_sanitize(snapshot)
				if not release then
					output.session = {id = record.lockId, updatedAt = os.time()}
				end
				wrote = true
				return output
			end)
		end)
		if ok and wrote and not lostLock then
			succeeded = true
			break
		end
		if lostLock then
			record.writable = false
			break
		end
		if attempt < 3 then
			task.wait(0.5 * attempt + math.random() * 0.2)
		end
	end
	record.status = succeeded and "saved" or "error"
	if succeeded and release then
		record.writable = false
	end
	record.busy = false
	if succeeded and self.OnSaved then
		-- Consumers get the exact committed weekly total, never a newer unsaved value.
		self.OnSaved(player, table.clone(snapshot.weekly))
	end
	if not succeeded then
		warn("[Dasher] Could not save " .. player.UserId .. (lostLock and " (session ownership changed)." or ". Will retry on the next save."))
	end
	return succeeded
end

function ProfileStore:Release(player)
	local record = self.records[player]
	if not record or record.releasing then
		return
	end
	record.releasing = true
	record.closing = true
	local deadline = os.clock() + 23
	while record.busy and os.clock() < deadline do
		task.wait(0.05)
	end
	if not record.busy then
		self:Save(player, true)
		self.records[player] = nil
	else
		-- A load may complete after disconnect; still release its lock when it settles.
		task.spawn(function()
			while record.busy do
				task.wait(0.1)
			end
			self:Save(player, true)
			self.records[player] = nil
		end)
	end
end

function ProfileStore:Close()
	self.closing = true
	for player in self.records do
		task.spawn(function()
			self:Release(player)
		end)
	end
	local deadline = os.clock() + 27
	while next(self.records) ~= nil and os.clock() < deadline do
		task.wait(0.05)
	end
end

return ProfileStore
