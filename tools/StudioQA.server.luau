-- Included ONLY by tools/build.py --qa. Never included in release places.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local Config = require(game.ReplicatedStorage.Dasher.Config)
local Profiles = require(game.ServerScriptService.ProfileStore)
local count = 0
local function check(condition, name)
	assert(condition, "[DASHER_QA] FAIL " .. name)
	count += 1
	print("[DASHER_QA] PASS " .. name)
end
local store = Profiles.new(Config)
local fake = {UserId = -887700}
local data,status = store:Load(fake)
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
check(store:SetBest(fake, "Skyline", 55), "first record accepted")
check(not store:SetBest(fake, "Skyline", 60) and data.best.Skyline == 55, "slower result preserves best")
check(store:SetBest(fake, "Skyline", 50) and data.best.Skyline == 50, "faster result replaces best")
check(not store:SetBest(fake, "Skyline", math.huge), "infinite record rejected")
store:Release(fake)
check(store:Get(fake) == nil, "session cleanup")
for _, id in Config.MapOrder do
	local model = game.ServerStorage.Maps:FindFirstChild(id)
	check(model and model:IsA("Model"), id .. " template exists")
	check(model.Start and model.Finish and #model.Gates:GetChildren() == 8, id .. " start/finish and eight validation gates")
	check(#model.Hazards:GetChildren() > 0, id .. " restart hazards exist")
end
print("[DASHER_QA] STRUCTURE_AND_ECONOMY_PASS " .. count)
task.spawn(function()
	local seen = {}
	local deadline = os.clock()+110
	while os.clock()<deadline do
		if workspace:GetAttribute("DasherPhase") == "Racing" then
			local id=workspace:GetAttribute("DasherMapId")
			if id and not seen[id] then
				seen[id]=true
				print("[DASHER_QA] RACING " .. id)
			end
		end
		if seen.Skyline and seen.Neon and seen.Grid then
			print("[DASHER_QA] THREE_MAP_ROTATION_PASS")
			return
		end
		task.wait(0.2)
	end
	warn("[DASHER_QA] Three map rotation timeout; inspect current phase/player state.")
end)
