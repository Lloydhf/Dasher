-- One record per player, serialized UpdateAsync writes, and an expiring session lock.
-- Studio always uses memory: enabling Studio API access must never alter live progress.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ProfileStore = {}
ProfileStore.__index = ProfileStore

local SCHEMA = 1
local LOCK_SECONDS = 180
local MAX_COINS = 100000000

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function defaultData()
	return {version = SCHEMA, coins = 0, owned = {ice = true}, equipped = "ice", best = {}}
end

function ProfileStore.new(config)
	local self = setmetatable({}, ProfileStore)
	self.records = {}
	self.cosmetics = {}
	self.mapIds = {}
	self.sessionId = (game.JobId ~= "" and game.JobId or "studio") .. ":" .. HttpService:GenerateGUID(false)
	self.sessionOnly = RunService:IsStudio() or game.GameId == 0
	self.closing = false
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
	local data = defaultData()
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
	if type(raw.best) == "table" then
		for id in self.mapIds do
			local time = raw.best[id]
			if finite(time) and time > 0 and time < 3600 then
				data.best[id] = time
			end
		end
	end
	return data
end

function ProfileStore:Load(player)
	local record = {
		data = defaultData(), status = "loading", writable = false,
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
				if old ~= nil and (type(old) ~= "table" or old.version ~= SCHEMA) then
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
