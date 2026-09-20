-- Included ONLY by tools/build.py --qa. Never included in release places.
-- All profile tests run in isolated Studio memory and cannot touch player saves.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local Config = require(game.ReplicatedStorage.Dasher.Config)
local Profiles = require(game.ServerScriptService.ProfileStore)
local RoundRules = require(game.ServerScriptService.RoundRules)
local WeeklyLeaderboard = require(game.ServerScriptService.WeeklyLeaderboard)
local count = 0
local function check(condition, name)
	assert(condition, "[DASHER_NEXT_QA] FAIL " .. name)
	count += 1
	print("[DASHER_NEXT_QA] PASS " .. name)
end
local store = Profiles.new(Config)
local fake = {UserId = -887700, Name = "IsolatedQA"}
local data, status = store:Load(fake)
check(status == "session", "Studio isolates persistent data")
check(data.coins == 0 and data.owned.ice, "new profile defaults")
check(not store:Buy(fake, "solar"), "insufficient funds cannot buy")
check(not store:Buy(fake, "unknown"), "unknown item rejected")
check(not store:Equip(fake, "mint"), "unowned item cannot equip")
check(not store:AddCoins(fake, 0/0), "NaN reward rejected")
check(not store:AddCoins(fake, -1), "negative reward rejected")
check(store:AddCoins(fake, 180), "server reward accepted")
check(store:Buy(fake, "solar") and data.coins == 60 and data.owned.solar, "atomic debit and cosmetic grant")
check(not store:Buy(fake, "solar") and data.coins == 60, "duplicate buy never debits twice")
check(store:Equip(fake, "ice") and data.equipped == "ice", "owned cosmetic equip")
check(store:SetBest(fake, "Skyline", 155), "first expanded-course record accepted")
check(not store:SetBest(fake, "Skyline", 160) and data.best.Skyline == 155, "slower result preserves best")
check(store:SetBest(fake, "Skyline", 150) and data.best.Skyline == 150, "faster result replaces best")
check(not store:SetBest(fake, "Skyline", math.huge), "infinite record rejected")
local migrated = store:_sanitize({version = 1, coins = 777, owned = {ice = true, solar = true}, equipped = "solar", best = {Skyline = 29.5}})
check(migrated.version == 2 and migrated.coins == 777 and migrated.owned.solar and migrated.equipped == "solar", "v1 migration preserves currency and unlocks")
check(migrated.courseVersion == 2 and migrated.best.Skyline == nil and migrated.legacyBest.Skyline == 29.5, "short-course record archived outside v2 personal best")
check(store:ClaimDaily(fake) and data.coins == 60 + Config.DailyReward, "explicit daily reward")
local afterDaily = data.coins
check(not store:ClaimDaily(fake) and data.coins == afterDaily, "duplicate daily claim rejected")
check(not store:ClaimWeekly(fake), "weekly challenge cannot be claimed early")
for rank = 1, Config.WeeklyFinishTarget do store:RecordFinish(fake, rank) end
local p = store:GetProgression(fake)
local expectedXP = Config.XPPerFinish * Config.WeeklyFinishTarget + Config.XPWinBonus
check(p.xp == expectedXP and p.level == 1 + math.floor(expectedXP / Config.XPPerLevel), "finish XP, win bonus and level use server config")
check(p.weeklyProgress == Config.WeeklyFinishTarget and p.weeklyScore == expectedXP, "weekly progress tracks verified finish calls")
check(store:ClaimWeekly(fake) and data.coins == afterDaily + Config.WeeklyReward, "weekly challenge claim")
local afterWeekly = data.coins
check(not store:ClaimWeekly(fake) and data.coins == afterWeekly, "duplicate weekly claim rejected")
local board = WeeklyLeaderboard.new()
board:Queue(fake, data.weekly)
board:Queue(fake, {key = data.weekly.key, score = 1})
local standing = board:Snapshot()
check(standing.scope == "Studio session" and standing.entries[1].score == expectedXP, "Studio weekly board accurately labels scope and does not regress")
local oldXP = data.xp
data.weekly = {key = "expired", finishes = 99, score = 999, claimed = true}
p = store:GetProgression(fake)
check(p.weeklyProgress == 0 and not p.weeklyClaimed and p.xp == oldXP, "week rollover resets quest while retaining XP")
check(not store:Save(fake, false), "Studio save cannot write live data")
store:Release(fake)
check(store:Get(fake) == nil, "session cleanup")

local rng = Random.new(9172026)
local options = RoundRules.ChooseOptions(Config.MapOrder, "Skyline", rng)
check(#options == 3 and not table.find(options, "Skyline"), "three vote options exclude previous map")
check(options[1] ~= options[2] and options[2] ~= options[3] and options[1] ~= options[3], "vote options unique")
local votes = {[1] = options[1], [2] = options[2]}
votes[1] = options[2]
local tally = RoundRules.Tally(options, votes)
check(tally[options[1]] == 0 and tally[options[2]] == 2, "changing vote replaces old vote")
check(RoundRules.Resolve(options, votes, rng) == options[2], "majority wins map selection")
local tied = {}
for _ = 1, 300 do
	local picked = RoundRules.Resolve(options, {}, rng)
	tied[picked] = true
end
check(tied[options[1]] and tied[options[2]] and tied[options[3]], "all tied candidates can win")
check(RoundRules.Resolve(options, {}, Random.new(12)) == RoundRules.Resolve(options, {}, Random.new(12)), "tie choice reproducible with same seed")

check(#Config.MapOrder == 5, "five selectable map themes")
check(Config.DashCooldown >= 3 and Config.FinishReward + Config.RankBonuses[1] <= 24, "strategic dash cooldown and reduced economy")
for _, id in Config.MapOrder do
	local model = game.ServerStorage.Maps:FindFirstChild(id)
	check(model and model:IsA("Model"), id .. " template exists")
	check(model.Start and model.Finish and #model.Gates:GetChildren() == 24, id .. " start/finish and 24 ordered validation gates")
	check(#model.Hazards:GetChildren() > 0, id .. " restart hazards exist")
	check(model.Start.Position.Z - model.Finish.Position.Z > 1000, id .. " expanded route exceeds 1000 studs")
	local primaryCount = 0
	for _, deck in model.Course:GetChildren() do
		if deck:IsA("Model") and not string.match(deck.Name, "^RiskShortcut") then
			primaryCount += 1
			check(deck:FindFirstChild("Walkable") ~= nil and deck.Walkable.CanCollide, id .. " " .. deck.Name .. " has a solid landing")
		end
	end
	check(primaryCount == 74, id .. " has 74 primary platforms")
	local lastZ = math.huge
	for index = 1, 24 do
		local gate = model.Gates:FindFirstChild(string.format("Gate%02d", index))
		check(gate and gate:IsA("BasePart") and gate.Position.Z < lastZ, id .. " gate " .. index .. " has ordered route position")
		lastZ = gate.Position.Z
	end
end
print("[DASHER_NEXT_QA] STRUCTURE_PROGRESSION_VOTING_PASS " .. count)
