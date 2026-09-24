-- Pure round-selection helpers. All selection and tallying happen on the server.
local RoundRules = {}

function RoundRules.ChooseOptions(mapOrder, previousMap, random)
	local pool = {}
	for _, id in mapOrder do
		if id ~= previousMap then
			table.insert(pool, id)
		end
	end
	if #pool < 3 and previousMap then
		table.insert(pool, previousMap)
	end
	for index = #pool, 2, -1 do
		local other = random:NextInteger(1, index)
		pool[index], pool[other] = pool[other], pool[index]
	end
	while #pool > 3 do
		table.remove(pool)
	end
	return pool
end

function RoundRules.Tally(options, votes)
	local counts = {}
	for _, id in options do
		counts[id] = 0
	end
	for _, id in votes do
		if counts[id] ~= nil then
			counts[id] += 1
		end
	end
	return counts
end

function RoundRules.Resolve(options, votes, random)
	local counts = RoundRules.Tally(options, votes)
	local tied, highest = {}, -1
	for _, id in options do
		if counts[id] > highest then
			tied, highest = {id}, counts[id]
		elseif counts[id] == highest then
			table.insert(tied, id)
		end
	end
	return #tied > 0 and tied[random:NextInteger(1, #tied)] or nil
end

function RoundRules.SelectEntrants(players, lastPlayed, capacity)
	local ordered = table.clone(players)
	table.sort(ordered, function(a, b)
		local lastA, lastB = lastPlayed[a.UserId] or -1, lastPlayed[b.UserId] or -1
		return lastA < lastB or (lastA == lastB and a.UserId < b.UserId)
	end)
	while #ordered > capacity do table.remove(ordered) end
	return ordered
end

function RoundRules.RaceStatus(roster, connected, remaining, elapsed)
	local entrants, unfinished = 0, 0
	for player, record in roster do
		if connected(player) then
			entrants += 1
			if not record.finished and not record.forfeited then unfinished += 1 end
		end
	end
	if remaining <= 0 then return true, "TimeUp", entrants, unfinished end
	if elapsed >= 2 and unfinished == 0 then
		return true, entrants > 0 and "AllFinished" or "NoRacers", entrants, unfinished
	end
	return false, nil, entrants, unfinished
end

return RoundRules
