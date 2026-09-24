-- Shared presentation and tuning. Rewards and eligibility are enforced on the server.
local Config = {}
Config.Version = "0.5.0"
Config.CourseVersion = 5 -- New routes archive previous times; coins and unlocks survive.
Config.WalkSpeed = 20
Config.JumpPower = 52
Config.UpdraftSpeed = 88
Config.UpdraftCooldown = 3.25
Config.UpdraftGroundTime = 0.12
Config.RoundDuration = 420
Config.FirstFinishGrace = 90
Config.MaxRacers = 10
Config.Intermission = 18
Config.Countdown = 8
Config.ResultsDuration = 10
Config.SpeedMultiplier = 1.5
Config.FinishReward = 14
Config.RankBonuses = {6, 3, 1}
Config.StageReward = 3
Config.StageXP = 25
Config.XPPerFinish = 100
Config.XPWinBonus = 50
Config.XPPerLevel = 500
Config.DailyReward = 25
Config.WeeklyFinishTarget = 10
Config.WeeklyReward = 80
Config.MapOrder = {"Helix", "Canopy", "Reactor"}
Config.Lobby = {clockTime = 14.2, ambient = Color3.fromRGB(127, 139, 151),
    outdoorAmbient = Color3.fromRGB(157, 173, 185), fogColor = Color3.fromRGB(207, 224, 233), fogStart = 400, fogEnd = 1800}
-- Each tower has a distinct traversal layout, not a palette swap of a straight route.
Config.Maps = {
    Helix = {name = "HELIX", subtitle = "Thread the sky.", accent = Color3.fromRGB(194, 243, 94), clockTime = 14.2,
        ambient = Color3.fromRGB(130, 146, 158), outdoorAmbient = Color3.fromRGB(171, 188, 201), fogColor = Color3.fromRGB(208, 230, 241), fogStart = 400, fogEnd = 1800},
    Canopy = {name = "CANOPY", subtitle = "Find your foothold.", accent = Color3.fromRGB(102, 223, 169), clockTime = 15.3,
        ambient = Color3.fromRGB(125, 147, 136), outdoorAmbient = Color3.fromRGB(171, 193, 165), fogColor = Color3.fromRGB(208, 234, 208), fogStart = 400, fogEnd = 1800},
    Reactor = {name = "REACTOR", subtitle = "Rise above the noise.", accent = Color3.fromRGB(192, 159, 255), clockTime = 19.2,
        ambient = Color3.fromRGB(117, 120, 151), outdoorAmbient = Color3.fromRGB(147, 157, 183), fogColor = Color3.fromRGB(139, 152, 193), fogStart = 400, fogEnd = 1800},
}
Config.Cosmetics = {
	{id = "ice", particleStyle = "crystal", name = "ION", price = 0, color = Color3.fromRGB(98, 224, 234)},
	{id = "solar", particleStyle = "glow", name = "SOLAR", price = 120, color = Color3.fromRGB(255, 193, 91)},
	{id = "orchid", particleStyle = "petal", name = "ORCHID", price = 240, color = Color3.fromRGB(234, 128, 224)},
	{id = "mint", particleStyle = "leaf", name = "MINT", price = 360, color = Color3.fromRGB(142, 242, 180)},
	{id = "ember", particleStyle = "ember", name = "EMBER", price = 180, color = Color3.fromRGB(255, 126, 79)},
	{id = "cobalt", particleStyle = "comet", name = "COBALT", price = 300, color = Color3.fromRGB(111, 157, 255)},
	{id = "pearl", particleStyle = "snow", name = "PEARL", price = 450, color = Color3.fromRGB(240, 245, 255)},
	{id = "prism", particleStyle = "prism", name = "PRISM", price = 600, color = Color3.fromRGB(177, 145, 255)},
	{id = "crimson", particleStyle = "sparks", name = "CRIMSON", price = 750, color = Color3.fromRGB(255, 88, 131)},
	{id = "aurora", particleStyle = "mist", name = "AURORA", price = 900, color = Color3.fromRGB(85, 244, 225)},
}
-- Reserved integration points. No real-money purchase is offered in this playtest build.
-- Enable only with durable receipt handling, real product IDs and live purchase tests.
Config.Monetization = {Enabled = false, VIPPassId = 0, DoubleCoinsPassId = 0, CoinPackProductId = 0, CoinPackAmount = 500}
return table.freeze(Config)
