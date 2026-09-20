-- Shared presentation and tuning. Rewards and eligibility are enforced on the server.
local Config = {}
Config.Version = "0.2.0"
Config.CourseVersion = 2 -- Expanded courses have separate records; coins and unlocks survive.
Config.WalkSpeed = 22
Config.JumpPower = 52
Config.DashSpeed = 82
Config.DashDuration = 0.20
Config.DashCooldown = 3.8
Config.RoundDuration = 360
Config.Intermission = 20
Config.Countdown = 5
Config.ResultsDuration = 10
Config.SpeedMultiplier = 1.5
Config.FinishReward = 14
Config.RankBonuses = {6, 3, 1}
Config.XPPerFinish = 100
Config.XPWinBonus = 50
Config.XPPerLevel = 500
Config.DailyReward = 25
Config.WeeklyFinishTarget = 10
Config.WeeklyReward = 80
Config.MapOrder = {"Skyline", "Neon", "Grid", "Foundry", "Zenith"}
Config.Lobby = {clockTime = 0.8, ambient = Color3.fromRGB(69, 82, 111),
    outdoorAmbient = Color3.fromRGB(86, 97, 127), fogColor = Color3.fromRGB(20, 28, 46), fogStart = 250, fogEnd = 1600}
Config.Maps = {
	Skyline = {name = "CLOUDLINE", subtitle = "Above the noise.", accent = Color3.fromRGB(99, 222, 231), clockTime = 14.4,
		ambient = Color3.fromRGB(123, 143, 164), outdoorAmbient = Color3.fromRGB(155, 175, 196), fogColor = Color3.fromRGB(200, 225, 244), fogStart = 190, fogEnd = 1100},
	Neon = {name = "AFTERHOURS", subtitle = "Own the night.", accent = Color3.fromRGB(183, 137, 250), clockTime = 0.3,
		ambient = Color3.fromRGB(63, 61, 92), outdoorAmbient = Color3.fromRGB(79, 84, 118), fogColor = Color3.fromRGB(20, 22, 44), fogStart = 120, fogEnd = 600},
	Grid = {name = "THE GRID", subtitle = "Nothing to hide behind.", accent = Color3.fromRGB(104, 223, 207), clockTime = 12,
		ambient = Color3.fromRGB(114, 118, 137), outdoorAmbient = Color3.fromRGB(139, 147, 170), fogColor = Color3.fromRGB(39, 44, 61), fogStart = 200, fogEnd = 850},
	Foundry = {name = "FOUNDRY", subtitle = "Precision under pressure.", accent = Color3.fromRGB(255, 186, 92), clockTime = 17.8,
		ambient = Color3.fromRGB(110, 91, 87), outdoorAmbient = Color3.fromRGB(132, 113, 107), fogColor = Color3.fromRGB(61, 45, 43), fogStart = 220, fogEnd = 1000},
	Zenith = {name = "ZENITH", subtitle = "Chase the horizon.", accent = Color3.fromRGB(167, 186, 255), clockTime = 1.4,
		ambient = Color3.fromRGB(91, 98, 136), outdoorAmbient = Color3.fromRGB(117, 125, 163), fogColor = Color3.fromRGB(36, 43, 70), fogStart = 240, fogEnd = 1500},
}
Config.Cosmetics = {
	{id = "ice", name = "ION", price = 0, color = Color3.fromRGB(98, 224, 234)},
	{id = "solar", name = "SOLAR", price = 120, color = Color3.fromRGB(255, 193, 91)},
	{id = "orchid", name = "ORCHID", price = 240, color = Color3.fromRGB(234, 128, 224)},
	{id = "mint", name = "MINT", price = 360, color = Color3.fromRGB(142, 242, 180)},
	{id = "ember", name = "EMBER", price = 180, color = Color3.fromRGB(255, 126, 79)},
	{id = "cobalt", name = "COBALT", price = 300, color = Color3.fromRGB(111, 157, 255)},
	{id = "pearl", name = "PEARL", price = 450, color = Color3.fromRGB(240, 245, 255)},
	{id = "prism", name = "PRISM", price = 600, color = Color3.fromRGB(177, 145, 255)},
	{id = "crimson", name = "CRIMSON", price = 750, color = Color3.fromRGB(255, 88, 131)},
	{id = "aurora", name = "AURORA", price = 900, color = Color3.fromRGB(85, 244, 225)},
}
-- Reserved integration points. No real-money purchase is offered in this playtest build.
-- Enable only with durable receipt handling, real product IDs and live purchase tests.
Config.Monetization = {Enabled = false, VIPPassId = 0, DoubleCoinsPassId = 0, CoinPackProductId = 0, CoinPackAmount = 500}
return table.freeze(Config)
