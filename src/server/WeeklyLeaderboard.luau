-- Ordered weekly scores are published only after the profile carrying them saves.
-- Studio uses memory exclusively, including when Studio API access is enabled.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WeeklyLeaderboard = {}
WeeklyLeaderboard.__index = WeeklyLeaderboard

local function currentWeek()
	return tostring(math.floor((os.time() + 3 * 86400) / (7 * 86400)))
end

function WeeklyLeaderboard.new()
	return setmetatable({
		sessionOnly = RunService:IsStudio() or game.GameId == 0,
		weekKey = currentWeek(), pending = {}, memory = {}, entries = {}, names = {},
		status = "loading", lastRefresh = -math.huge, flushing = false, refreshing = false,
	}, WeeklyLeaderboard)
end

function WeeklyLeaderboard:_rollWeek()
	local key = currentWeek()
	if self.weekKey ~= key then
		self.weekKey = key
		self.entries, self.memory = {}, {}
		self.lastRefresh = -math.huge
		self.status = "loading"
	end
	return key
end

function WeeklyLeaderboard:Queue(player, weekly)
	if type(weekly) ~= "table" or type(weekly.key) ~= "string" or type(weekly.score) ~= "number"
		or weekly.score ~= weekly.score or weekly.score <= 0 or weekly.score > 100000000 then
		return
	end
	self:_rollWeek()
	local id = tostring(player.UserId)
	self.names[id] = player.Name
	if self.sessionOnly then
		if weekly.key == self.weekKey then
			self.memory[id] = math.max(self.memory[id] or 0, math.floor(weekly.score))
			self:_sessionEntries()
		end
		return
	end
	local key = weekly.key .. ":" .. id
	local existing = self.pending[key]
	self.pending[key] = {
		week = weekly.key, id = id,
		score = math.max(existing and existing.score or 0, math.floor(weekly.score)),
	}
end

function WeeklyLeaderboard:_sessionEntries()
	local entries = {}
	for id, score in self.memory do
		table.insert(entries, {userId = tonumber(id), name = self.names[id] or "Player", score = score})
	end
	table.sort(entries, function(a, b)
		return a.score > b.score or (a.score == b.score and a.userId < b.userId)
	end)
	while #entries > 10 do
		table.remove(entries)
	end
	self.entries, self.status = entries, "ready"
end

function WeeklyLeaderboard:Flush()
	if self.sessionOnly or self.flushing then
		return
	end
	self.flushing = true
	for key, entry in table.clone(self.pending) do
		local ok = pcall(function()
			local store = DataStoreService:GetOrderedDataStore("DasherWeekly_v2", entry.week)
			store:UpdateAsync(entry.id, function(old)
				return math.max(type(old) == "number" and old or 0, entry.score)
			end)
		end)
		if ok and self.pending[key] == entry then
			self.pending[key] = nil
		end
	end
	self.flushing = false
end

function WeeklyLeaderboard:Refresh()
	local key = self:_rollWeek()
	if self.sessionOnly then
		self:_sessionEntries()
		return
	end
	if self.refreshing or os.clock() - self.lastRefresh < 60 then
		return
	end
	self.refreshing = true
	self.lastRefresh = os.clock()
	local ok, entries = pcall(function()
		local store = DataStoreService:GetOrderedDataStore("DasherWeekly_v2", key)
		local page = store:GetSortedAsync(false, 10, 1):GetCurrentPage()
		local result = {}
		for _, row in page do
			local id = tonumber(row.key)
			if id then
				local name = self.names[row.key]
				if not name then
					local named, resolved = pcall(Players.GetNameFromUserIdAsync, Players, id)
					name = named and resolved or ("Player " .. row.key)
					self.names[row.key] = name
				end
				table.insert(result, {userId = id, name = name, score = row.value})
			end
		end
		return result
	end)
	if self.weekKey == key then
		if ok then
			self.entries, self.status = entries, "ready"
		else
			self.status = "unavailable"
		end
	end
	self.refreshing = false
end

function WeeklyLeaderboard:Snapshot()
	self:_rollWeek()
	return {
		scope = self.sessionOnly and "Studio session" or "Global weekly",
		entries = self.entries, weekKey = self.weekKey, status = self.status,
	}
end

function WeeklyLeaderboard:Close()
	-- Profiles:Close runs first so its final durable totals are already queued.
	self:Flush()
end

return WeeklyLeaderboard
