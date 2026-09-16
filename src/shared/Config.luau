-- Shared presentation and tuning. Rewards and eligibility are enforced on the server.
local Config = {}
Config.Version = "0.1.0"
Config.WalkSpeed = 22
Config.JumpPower = 52
Config.DashSpeed = 82
Config.DashDuration = 0.20
Config.DashCooldown = 1.15
Config.RoundDuration = 240
Config.Intermission = 12
Config.Countdown = 4
Config.ResultsDuration = 10
Config.SpeedMultiplier = 1.5
Config.FinishReward = 40
Config.RankBonuses = {20, 10, 5}
Config.MapOrder = {"Skyline", "Neon", "Grid"}
Config.Maps = {
	Skyline = {name = "CLOUDLINE", subtitle = "Above the noise.", accent = Color3.fromRGB(98, 224, 234), clockTime = 14.4,
		ambient = Color3.fromRGB(123, 143, 164), outdoorAmbient = Color3.fromRGB(155, 175, 196), fogColor = Color3.fromRGB(200, 225, 244), fogStart = 190, fogEnd = 1100},
	Neon = {name = "AFTERHOURS", subtitle = "Own the night.", accent = Color3.fromRGB(239, 111, 199), clockTime = 0.3,
		ambient = Color3.fromRGB(63, 61, 92), outdoorAmbient = Color3.fromRGB(79, 84, 118), fogColor = Color3.fromRGB(20, 22, 44), fogStart = 120, fogEnd = 600},
	Grid = {name = "THE GRID", subtitle = "Nothing to hide behind.", accent = Color3.fromRGB(255, 192, 91), clockTime = 12,
		ambient = Color3.fromRGB(114, 118, 137), outdoorAmbient = Color3.fromRGB(139, 147, 170), fogColor = Color3.fromRGB(39, 44, 61), fogStart = 200, fogEnd = 850},
}
Config.Cosmetics = {
	{id = "ice", name = "ION", price = 0, color = Color3.fromRGB(98, 224, 234)},
	{id = "solar", name = "SOLAR", price = 120, color = Color3.fromRGB(255, 193, 91)},
	{id = "orchid", name = "ORCHID", price = 240, color = Color3.fromRGB(234, 128, 224)},
	{id = "mint", name = "MINT", price = 360, color = Color3.fromRGB(142, 242, 180)},
}
return table.freeze(Config)
