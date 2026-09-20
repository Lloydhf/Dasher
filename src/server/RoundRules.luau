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

return RoundRules
