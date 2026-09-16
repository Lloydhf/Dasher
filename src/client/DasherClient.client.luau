-- Dasher client: presentation and prediction only. Rewards, runs and saves belong to the server.
-- Motor6D overlays are applied in PreSimulation, after the Animator, and removed before its next step.
-- Dash uses a planar LinearVelocity so gravity and jumping remain part of the parkour.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
-- The game owns its finish-order UI; the default player list otherwise overlaps the coin pill.
-- CoreGui can initialize after this script, so retry briefly without delaying the HUD.
task.spawn(function()
	for _ = 1, 8 do
		local ok = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
		if ok then return end
		task.wait(0.25)
	end
end)
local package = ReplicatedStorage:WaitForChild("Dasher")
local Config = require(package:WaitForChild("Config"))
local remotes = package:WaitForChild("Remotes")
local Action = remotes:WaitForChild("Action")
local State = remotes:WaitForChild("State")
local Feedback = remotes:WaitForChild("Feedback")
local DashFX = remotes:WaitForChild("DashFX")

local C = {
	ink = Color3.fromRGB(12, 18, 31), panel = Color3.fromRGB(20, 29, 46),
	card = Color3.fromRGB(30, 42, 61), border = Color3.fromRGB(68, 89, 111),
	text = Color3.fromRGB(246, 244, 233), muted = Color3.fromRGB(174, 190, 205),
	cyan = Color3.fromRGB(90, 230, 239), gold = Color3.fromRGB(255, 208, 105),
	red = Color3.fromRGB(255, 127, 136), green = Color3.fromRGB(147, 235, 184),
}
local snapshot = {phase = "Waiting", coins = 0, owned = {ice = true}, equipped = "ice", progress = 0, finishers = {}}
local receivedAt = os.clock()
local reducedMotion = false
local muted = false
local menuOpen = false
local menuPage = "Help"
local localDashAt = -100
local activeDash = nil
local lastRestartAt = -100
local effects = {}
local lastFinished = nil
local toastSerial = 0
local cameraKick = 0
local cameraOffsetApplied = 0
local lastCamera = nil
local shopButtons = {}
local connections = {}
local characterConnections = {}
local closedResultsRound = nil

local function make(className, parent, props)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do instance[key] = value end
	instance.Parent = parent
	return instance
end

local function round(parent, radius)
	return make("UICorner", parent, {CornerRadius = UDim.new(0, radius or 12)})
end

local function stroke(parent, color, transparency)
	return make("UIStroke", parent, {Color = color or C.border, Transparency = transparency or 0.55, Thickness = 1})
end

local function panel(parent, name, size, position, color)
	local item = make("Frame", parent, {Name = name, Size = size, Position = position, BackgroundColor3 = color or C.ink, BackgroundTransparency = 0.07, BorderSizePixel = 0})
	round(item, 14)
	stroke(item)
	return item
end

local function label(parent, text, size, position, textSize, color, bold)
	return make("TextLabel", parent, {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = size, Position = position,
		Text = text, TextSize = textSize or 14, TextColor3 = color or C.text,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function button(parent, text, size, position, color)
	local item = make("TextButton", parent, {
		Size = size, Position = position, Text = text, TextSize = 12, Font = Enum.Font.GothamBold,
		TextColor3 = color and C.ink or C.text, BackgroundColor3 = color or C.panel,
		BorderSizePixel = 0, AutoButtonColor = true, Selectable = true,
	})
	round(item, 10)
	stroke(item, color or C.border, color and 0.8 or 0.45)
	return item
end

local function center(item)
	item.TextXAlignment = Enum.TextXAlignment.Center
	return item
end

local function timeText(seconds, precise)
	seconds = math.max(0, tonumber(seconds) or 0)
	local minutes = math.floor(seconds / 60)
	if precise then return string.format("%02d:%05.2f", minutes, seconds % 60) end
	return string.format("%02d:%02d", minutes, math.floor(seconds % 60))
end

local function coinText(amount)
	local text = tostring(math.floor(tonumber(amount) or 0))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return formatted:gsub("^,", "")
end

local function trailColor(id)
	for _, cosmetic in ipairs(Config.Cosmetics) do
		if cosmetic.id == id then return cosmetic.color end
	end
	return C.cyan
end

local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
	Name = "DasherHUD", ResetOnSpawn = false, IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 20,
})
local root = make("Frame", gui, {Name = "SafeCanvas", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})

local identity = panel(root, "Identity", UDim2.fromOffset(224, 78), UDim2.fromOffset(20, 18))
local slash = make("Frame", identity, {Size = UDim2.fromOffset(5, 24), Position = UDim2.fromOffset(19, 16), BackgroundColor3 = C.cyan, BorderSizePixel = 0, Rotation = 20})
round(slash, 2)
label(identity, "DASHER", UDim2.new(1, -57, 0, 28), UDim2.fromOffset(37, 12), 23, C.text, true)
local mapLabel = label(identity, "ENTER THE RACE", UDim2.new(1, -34, 0, 18), UDim2.fromOffset(17, 49), 10, C.muted, true)

local timerPanel = panel(root, "RoundClock", UDim2.fromOffset(180, 86), UDim2.new(0.5, -90, 0, 18))
local phaseLabel = center(label(timerPanel, "GETTING READY", UDim2.new(1, -12, 0, 16), UDim2.fromOffset(6, 8), 10, C.muted, true))
local clockLabel = center(label(timerPanel, "--:--", UDim2.new(1, -12, 0, 35), UDim2.fromOffset(6, 25), 30, C.text, true))
local multiplierLabel = center(label(timerPanel, "ROUND TIME", UDim2.new(1, -12, 0, 15), UDim2.fromOffset(6, 64), 9, C.muted, true))

local coinPanel = panel(root, "CoinBalance", UDim2.fromOffset(164, 56), UDim2.new(1, -184, 0, 18))
local coinCircle = make("Frame", coinPanel, {Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(13, 14), BackgroundColor3 = C.gold, BorderSizePixel = 0})
round(coinCircle, 50)
local coinInset = make("Frame", coinCircle, {Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.gold, BorderSizePixel = 0})
round(coinInset, 50)
stroke(coinInset, C.ink, 0.45)
make("Frame", coinInset, {Size = UDim2.fromOffset(3, 12), Position = UDim2.fromOffset(9, 4), BackgroundColor3 = C.ink, BackgroundTransparency = 0.22, BorderSizePixel = 0, Rotation = 22})
local balanceLabel = label(coinPanel, "0", UDim2.new(1, -58, 0, 24), UDim2.fromOffset(51, 8), 20, C.text, true)
local saveLabel = label(coinPanel, "COINS", UDim2.new(1, -58, 0, 15), UDim2.fromOffset(51, 32), 9, C.muted, true)

local topActions = make("Frame", root, {Size = UDim2.fromOffset(220, 34), Position = UDim2.new(1, -240, 0, 84), BackgroundTransparency = 1})
local trailsButton = button(topActions, "TRAILS", UDim2.fromOffset(78, 34), UDim2.fromOffset(0, 0))
local helpButton = button(topActions, "HELP", UDim2.fromOffset(62, 34), UDim2.fromOffset(85, 0))
local setupButton = button(topActions, "SETUP", UDim2.fromOffset(66, 34), UDim2.fromOffset(154, 0))
local restartButton = button(root, "RESTART  [R]", UDim2.fromOffset(132, 34), UDim2.fromOffset(20, 108))

local progressPanel = panel(root, "Progress", UDim2.fromOffset(330, 48), UDim2.new(0.5, -165, 1, -145))
local runLabel = label(progressPanel, "YOUR RUN  --:--", UDim2.fromOffset(197, 18), UDim2.fromOffset(14, 7), 10, C.muted, true)
local progressLabel = label(progressPanel, "0%", UDim2.fromOffset(62, 18), UDim2.new(1, -76, 0, 7), 10, C.cyan, true)
progressLabel.TextXAlignment = Enum.TextXAlignment.Right
local progressTrack = make("Frame", progressPanel, {Size = UDim2.new(1, -28, 0, 4), Position = UDim2.fromOffset(14, 31), BackgroundColor3 = C.card, BorderSizePixel = 0})
round(progressTrack, 4)
local progressFill = make("Frame", progressTrack, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.cyan, BorderSizePixel = 0})
round(progressFill, 4)

local dashPanel = panel(root, "DashReadiness", UDim2.fromOffset(280, 70), UDim2.new(0.5, -140, 1, -85))
local dashTitle = label(dashPanel, "DASH", UDim2.fromOffset(116, 24), UDim2.fromOffset(16, 9), 17, C.text, true)
local dashKey = label(dashPanel, "Q / SHIFT", UDim2.fromOffset(110, 22), UDim2.new(1, -126, 0, 10), 10, C.muted, true)
dashKey.TextXAlignment = Enum.TextXAlignment.Right
local dashTrack = make("Frame", dashPanel, {Size = UDim2.new(1, -32, 0, 5), Position = UDim2.fromOffset(16, 41), BackgroundColor3 = C.card, BorderSizePixel = 0})
round(dashTrack, 5)
local dashFill = make("Frame", dashTrack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.cyan, BorderSizePixel = 0})
round(dashFill, 5)
local dashCaption = center(label(dashPanel, "READY", UDim2.new(1, -20, 0, 14), UDim2.fromOffset(10, 49), 9, C.muted, true))

local touchDash = button(root, "DASH", UDim2.fromOffset(88, 70), UDim2.new(1, -108, 1, -206), C.cyan)
touchDash.TextSize = 16
touchDash.Visible = UserInputService.TouchEnabled
local tip = center(label(root, "JUMP + DASH ACROSS GAPS  /  EVERY FALL RESTARTS THE COURSE", UDim2.fromOffset(580, 24), UDim2.new(0.5, -290, 1, -177), 10, C.text, true))
tip.BackgroundColor3 = C.ink
tip.BackgroundTransparency = 0.14
round(tip, 8)

local accelerateButton = button(root, "SPEED UP ROUND  1.5x", UDim2.fromOffset(236, 42), UDim2.new(0.5, -118, 0, 126), C.gold)
accelerateButton.Visible = false

local countdown = center(label(root, "", UDim2.fromOffset(420, 100), UDim2.new(0.5, -210, 0.32, -50), 68, C.text, true))
countdown.Visible = false
stroke(countdown, C.ink, 0.3)
local toast = panel(root, "Toast", UDim2.fromOffset(470, 48), UDim2.new(0.5, -235, 0, 184))
toast.Visible = false
local toastText = center(label(toast, "", UDim2.new(1, -28, 1, -8), UDim2.fromOffset(14, 4), 13, C.text, true))
toastText.TextWrapped = true
toastText.TextTruncate = Enum.TextTruncate.None

-- Modals use a scroll area so their controls remain reachable on small displays.
local scrim = make("TextButton", root, {Name = "ModalScrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 30, Selectable = false})
local modal = panel(root, "Menu", UDim2.fromOffset(540, 486), UDim2.new(0.5, -270, 0.5, -243), C.panel)
modal.ZIndex = 31
modal.Visible = false
local modalTitle = label(modal, "HOW TO DASH", UDim2.new(1, -90, 0, 30), UDim2.fromOffset(24, 22), 24, C.text, true)
modalTitle.ZIndex = 32
local closeButton = button(modal, "X", UDim2.fromOffset(34, 34), UDim2.new(1, -54, 0, 20))
closeButton.ZIndex = 33
local modalSubtitle = label(modal, "", UDim2.new(1, -48, 0, 34), UDim2.fromOffset(24, 57), 12, C.muted)
modalSubtitle.TextWrapped = true
modalSubtitle.TextTruncate = Enum.TextTruncate.None
modalSubtitle.ZIndex = 32
local scroll = make("ScrollingFrame", modal, {Size = UDim2.new(1, -36, 1, -115), Position = UDim2.fromOffset(18, 98), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.muted, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 32})
make("UIListLayout", scroll, {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
make("UIPadding", scroll, {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8)})
local footer = center(label(root, "DASHER  /  FIRST EDITION", UDim2.fromOffset(210, 20), UDim2.new(1, -228, 1, -29), 9, C.muted, true))

local audioGroup = make("SoundGroup", SoundService, {Name = "DasherLocalAudio", Volume = 1})
-- Bundled assets verified in the installed Roblox content/sounds directory. No external IDs.
local dashSound = make("Sound", SoundService, {Name = "DasherDash", SoundId = "rbxasset://sounds/action_jump.mp3", Volume = 0.22, PlaybackSpeed = 1.75, SoundGroup = audioGroup})
local finishSound = make("Sound", SoundService, {Name = "DasherFinish", SoundId = "rbxasset://sounds/volume_slider.ogg", Volume = 0.35, PlaybackSpeed = 1.1, SoundGroup = audioGroup})

local function showToast(message, color, duration)
	toastSerial += 1
	local serial = toastSerial
	toastText.Text = tostring(message or "")
	toastText.TextColor3 = color or C.text
	toast.Visible = true
	task.delay(duration or 3, function()
		if serial == toastSerial then toast.Visible = false end
	end)
end

local function setModalLayer(parent)
	for _, child in ipairs(parent:GetDescendants()) do
		if child:IsA("GuiObject") then child.ZIndex = 34 end
	end
end

local function clearMenu()
	shopButtons = {}
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	scroll.CanvasPosition = Vector2.zero
end

local function menuCard(height, order)
	local card = panel(scroll, "Card", UDim2.new(1, -6, 0, height), UDim2.fromOffset(0, 0), C.card)
	card.LayoutOrder = order
	card.ZIndex = 33
	return card
end

local function closeMenu()
	menuOpen = false
	modal.Visible = false
	scrim.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(modal) then GuiService.SelectedObject = nil end
end

local function updateShopButtons()
	for id, entry in pairs(shopButtons) do
		local owned = snapshot.owned and snapshot.owned[id]
		entry.button.Text = snapshot.equipped == id and "EQUIPPED" or (owned and "EQUIP" or (coinText(entry.price) .. " COINS"))
		entry.button.BackgroundColor3 = snapshot.equipped == id and C.cyan or C.panel
		entry.button.TextColor3 = snapshot.equipped == id and C.ink or (owned and C.text or C.gold)
	end
end

local function openMenu(page)
	menuPage = page
	clearMenu()
	menuOpen = true
	modal.Visible = true
	scrim.Visible = true
	if page == "Trails" then
		modalTitle.Text = "LEAVE YOUR MARK"
		modalSubtitle.Text = "Cosmetic trails. Same speed. Same chance to win."
		for index, cosmetic in ipairs(Config.Cosmetics) do
			local card = menuCard(70, index)
			local swatch = make("Frame", card, {Size = UDim2.fromOffset(6, 34), Position = UDim2.fromOffset(17, 18), BackgroundColor3 = cosmetic.color, BorderSizePixel = 0, Rotation = 18})
			round(swatch, 3)
			label(card, string.upper(cosmetic.name), UDim2.new(1, -176, 0, 23), UDim2.fromOffset(36, 12), 13, C.text, true)
			label(card, "DASH TRAIL", UDim2.new(1, -176, 0, 18), UDim2.fromOffset(36, 36), 9, C.muted, true)
			local buy = button(card, "", UDim2.fromOffset(120, 36), UDim2.new(1, -133, 0, 17))
			shopButtons[cosmetic.id] = {button = buy, price = cosmetic.price}
			buy.Activated:Connect(function()
				if snapshot.equipped == cosmetic.id then return end
				if snapshot.owned and snapshot.owned[cosmetic.id] then
					Action:FireServer("Equip", cosmetic.id)
				elseif (snapshot.coins or 0) >= cosmetic.price then
					Action:FireServer("Buy", cosmetic.id)
				else
					showToast("Finish races to earn more coins.", C.gold)
				end
			end)
			setModalLayer(card)
		end
		updateShopButtons()
	elseif page == "Setup" then
		modalTitle.Text = "MAKE IT YOURS"
		modalSubtitle.Text = "Comfort settings apply to this play session."
		local motionCard = menuCard(82, 1)
		label(motionCard, "REDUCED MOTION", UDim2.new(1, -144, 0, 24), UDim2.fromOffset(16, 12), 13, C.text, true)
		local motionDesc = label(motionCard, "No dash zoom. Shorter trails.", UDim2.new(1, -144, 0, 31), UDim2.fromOffset(16, 37), 11, C.muted)
		motionDesc.TextWrapped = true
		local motion = button(motionCard, reducedMotion and "ON" or "OFF", UDim2.fromOffset(80, 34), UDim2.new(1, -96, 0, 24), reducedMotion and C.cyan or nil)
		motion.Activated:Connect(function()
			reducedMotion = not reducedMotion
			motion.Text = reducedMotion and "ON" or "OFF"
			motion.BackgroundColor3 = reducedMotion and C.cyan or C.panel
			motion.TextColor3 = reducedMotion and C.ink or C.text
			if reducedMotion then cameraKick = 0 end
		end)
		setModalLayer(motionCard)
		local soundCard = menuCard(82, 2)
		label(soundCard, "DASH & UI SOUNDS", UDim2.new(1, -144, 0, 24), UDim2.fromOffset(16, 12), 13, C.text, true)
		local soundDesc = label(soundCard, "Soft feedback for dashes and finishes.", UDim2.new(1, -144, 0, 31), UDim2.fromOffset(16, 37), 11, C.muted)
		soundDesc.TextWrapped = true
		local soundButton = button(soundCard, muted and "OFF" or "ON", UDim2.fromOffset(80, 34), UDim2.new(1, -96, 0, 24), not muted and C.cyan or nil)
		soundButton.Activated:Connect(function()
			muted = not muted
			audioGroup.Volume = muted and 0 or 1
			soundButton.Text = muted and "OFF" or "ON"
			soundButton.BackgroundColor3 = muted and C.panel or C.cyan
			soundButton.TextColor3 = muted and C.text or C.ink
		end)
		setModalLayer(soundCard)
		local note = menuCard(65, 3)
		local noteText = label(note, "Every fall returns you to the start. Your personal timer keeps running. Your avatar stays your own.", UDim2.new(1, -32, 1, -18), UDim2.fromOffset(16, 9), 12, C.muted)
		noteText.TextWrapped = true
		noteText.TextTruncate = Enum.TextTruncate.None
		setModalLayer(note)
	elseif page == "Results" then
		modalTitle.Text = "ROUND COMPLETE"
		modalSubtitle.Text = "Real finish times. A fresh course is up next."
		if #(snapshot.finishers or {}) == 0 then
			local empty = menuCard(86, 1)
			local emptyText = center(label(empty, "No finishers this round.\nLearn the route. Take another run.", UDim2.new(1, -30, 1, -18), UDim2.fromOffset(15, 9), 14, C.muted))
			emptyText.TextWrapped = true
			setModalLayer(empty)
		else
			for index, result in ipairs(snapshot.finishers) do
				if index > 10 then break end
				local card = menuCard(64, index)
				label(card, string.format("%02d", index), UDim2.fromOffset(34, 40), UDim2.fromOffset(13, 11), 20, index == 1 and C.gold or C.muted, true)
				label(card, result.name or "Runner", UDim2.new(1, -174, 0, 24), UDim2.fromOffset(56, 10), 13, result.userId == player.UserId and C.cyan or C.text, true)
				label(card, "+" .. coinText(result.coins) .. " coins", UDim2.new(1, -174, 0, 19), UDim2.fromOffset(56, 34), 10, C.gold)
				local finishTime = label(card, timeText(result.time, true), UDim2.fromOffset(103, 35), UDim2.new(1, -119, 0, 15), 15, C.text, true)
				finishTime.TextXAlignment = Enum.TextXAlignment.Right
				setModalLayer(card)
			end
		end
	else
		modalTitle.Text = "ONE DASH. ALL SKILL."
		modalSubtitle.Text = "Three worlds. One finish line. No checkpoints."
		local steps = {
			{"01", "MOVE. JUMP. DASH.", "WASD + Space. Q or Shift to dash. On controller: A to jump, X to dash. On touch: use the on-screen controls."},
			{"02", "COMMIT TO YOUR LINE", "Dash in your movement direction. With no movement input, dash where the camera faces. Jump before long gaps."},
			{"03", "FALL. LEARN. REPEAT.", "Falls and red hazards return you to the start. R / controller Y restarts your run. Your timer never rewinds."},
			{"04", "FINISH. SET THE PACE.", "The first finisher can speed up the shared round clock once. Your personal time is always measured in real seconds."},
		}
		for index, item in ipairs(steps) do
			local cardHeight = root.AbsoluteSize.X < 520 and 123 or 99
			local card = menuCard(cardHeight, index)
			label(card, item[1], UDim2.fromOffset(31, 32), UDim2.fromOffset(12, 10), 18, C.cyan, true)
			label(card, item[2], UDim2.new(1, -69, 0, 24), UDim2.fromOffset(51, 9), 12, C.text, true)
			local body = label(card, item[3], UDim2.new(1, -69, 0, cardHeight - 45), UDim2.fromOffset(51, 34), 11, C.muted)
			body.TextWrapped = true
			body.TextTruncate = Enum.TextTruncate.None
			body.TextYAlignment = Enum.TextYAlignment.Top
			setModalLayer(card)
		end
	end
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = closeButton end
end

trailsButton.Activated:Connect(function() openMenu("Trails") end)
helpButton.Activated:Connect(function() openMenu("Help") end)
setupButton.Activated:Connect(function() openMenu("Setup") end)
closeButton.Activated:Connect(function()
	if menuPage == "Results" then closedResultsRound = snapshot.roundId end
	closeMenu()
end)
scrim.Activated:Connect(function()
	if menuPage == "Results" then closedResultsRound = snapshot.roundId end
	closeMenu()
end)

local function restoreEffect(effect)
	for motor, base in pairs(effect.bases or {}) do
		if motor.Parent then motor.Transform = base end
	end
	effect.bases = {}
end

local function endEffect(character)
	local effect = effects[character]
	if not effect then return end
	restoreEffect(effect)
	for _, item in ipairs(effect.instances) do if item.Parent then item:Destroy() end end
	effects[character] = nil
end

local function dashEffect(character, direction, id)
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	endEffect(character)
	local color = trailColor(id)
	local effect = {at = os.clock(), bases = {}, motors = {}, instances = {}, direction = direction}
	effects[character] = effect
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("Motor6D") then
			local name = item.Name
			if name == "Waist" or name == "Root" or name == "RootJoint" or name == "RightShoulder" or name == "LeftShoulder" or name == "Right Shoulder" or name == "Left Shoulder" or name == "RightHip" or name == "LeftHip" then
				table.insert(effect.motors, item)
			end
		end
	end
	for side = -1, 1, 2 do
		local a = make("Attachment", rootPart, {Name = "DasherTrailTop", Position = Vector3.new(side * 0.75, 0.25, 0.45)})
		local b = make("Attachment", rootPart, {Name = "DasherTrailBottom", Position = Vector3.new(side * 0.75, -0.25, 0.45)})
		local trail = make("Trail", rootPart, {
			Name = "DasherTrail", Attachment0 = a, Attachment1 = b, Color = ColorSequence.new(color),
			Lifetime = reducedMotion and 0.09 or 0.23, MinLength = 0.08, FaceCamera = true,
			LightEmission = 0.75, WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(0.65, 0.48), NumberSequenceKeypoint.new(1, 1)}),
		})
		table.insert(effect.instances, a)
		table.insert(effect.instances, b)
		table.insert(effect.instances, trail)
	end
	if character == player.Character then
		if not reducedMotion then cameraKick = 5 end
		if not muted then dashSound:Play() end
	end
end

local function stopDash(cancelled)
	local dash = activeDash
	if not dash then return end
	activeDash = nil
	if dash.velocity then dash.velocity:Destroy() end
	if dash.attachment then dash.attachment:Destroy() end
	if dash.humanoid and dash.humanoid.Parent then dash.humanoid.AutoRotate = dash.autoRotate end
	if dash.root and dash.root.Parent then
		local v = dash.root.AssemblyLinearVelocity
		local speed = cancelled and 0 or math.min(Config.WalkSpeed, Vector3.new(v.X, 0, v.Z).Magnitude)
		dash.root.AssemblyLinearVelocity = dash.direction * speed + Vector3.new(0, v.Y, 0)
	end
end

local function dashCast(rootPart, direction, distance)
	local filter = {}
	for _, person in ipairs(Players:GetPlayers()) do
		if person.Character then table.insert(filter, person.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	params.RespectCanCollide = true
	-- Torso-sized cast excludes floors but detects a thin wall before physics crosses it.
	return workspace:Blockcast(CFrame.lookAt(rootPart.Position, rootPart.Position + direction), Vector3.new(1.6, 1.8, 1.1), direction * distance, params)
end

local function tryDash()
	if menuOpen or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
	if snapshot.phase ~= "Racing" or not snapshot.racing or snapshot.finished then return end
	local accepted = player:GetAttribute("DashAt")
	local serverCooldown = typeof(accepted) == "number" and workspace:GetServerTimeNow() - accepted < Config.DashCooldown
	if activeDash or serverCooldown or os.clock() - localDashAt < Config.DashCooldown then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or humanoid.Health <= 0 or rootPart.Anchored then return end
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		local camera = workspace.CurrentCamera
		direction = camera and camera.CFrame.LookVector or rootPart.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, -1) end
	direction = direction.Unit
	if dashCast(rootPart, direction, 1.2) then return end
	localDashAt = os.clock()
	local attachment = make("Attachment", rootPart, {Name = "DasherDashAttachment"})
	local velocity = make("LinearVelocity", rootPart, {
		Name = "DasherDashVelocity", Attachment0 = attachment,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		VelocityConstraintMode = Enum.VelocityConstraintMode.Plane,
		PrimaryTangentAxis = Vector3.new(1, 0, 0), SecondaryTangentAxis = Vector3.new(0, 0, 1),
		PlaneVelocity = Vector2.new(direction.X * Config.DashSpeed, direction.Z * Config.DashSpeed),
		ForceLimitsEnabled = true, ForceLimitMode = Enum.ForceLimitMode.PerAxis,
		MaxPlanarAxesForce = Vector2.new(rootPart.AssemblyMass * 12000, rootPart.AssemblyMass * 12000),
	})
	activeDash = {root = rootPart, humanoid = humanoid, attachment = attachment, velocity = velocity, direction = direction, started = os.clock(), autoRotate = humanoid.AutoRotate}
	humanoid.AutoRotate = false
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
	dashEffect(character, direction, snapshot.equipped)
	Action:FireServer("Dash", direction)
end

local function tryRestart()
	if menuOpen or UserInputService:GetFocusedTextBox() or os.clock() - lastRestartAt < 0.8 then return end
	if snapshot.phase ~= "Racing" or not snapshot.racing or snapshot.finished then return end
	lastRestartAt = os.clock()
	stopDash(true)
	Action:FireServer("Restart")
end

touchDash.Activated:Connect(tryDash)
restartButton.Activated:Connect(tryRestart)
accelerateButton.Activated:Connect(function()
	if snapshot.canAccelerate then
		Action:FireServer("Accelerate")
		accelerateButton.Visible = false
	end
end)

ContextActionService:BindAction("DasherDash", function(_, state)
	if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then tryDash() end
	return menuOpen and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Q, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonX)
ContextActionService:BindAction("DasherRestart", function(_, state)
	if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then tryRestart() end
	return menuOpen and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
ContextActionService:BindAction("DasherHelp", function(_, state)
	if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		if menuOpen then closeMenu() else openMenu("Help") end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.H, Enum.KeyCode.ButtonSelect)
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.ButtonB and menuOpen then closeMenu() end
end))

local function onCharacter(character)
	stopDash(true)
	for _, connection in ipairs(characterConnections) do connection:Disconnect() end
	characterConnections = {}
	localDashAt = -100
	cameraKick = 0
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or character ~= player.Character then return end
		table.insert(characterConnections, humanoid.Died:Connect(function()
			stopDash(true)
			endEffect(character)
		end))
	end)
end
table.insert(connections, player.CharacterAdded:Connect(onCharacter))
table.insert(connections, player.CharacterRemoving:Connect(function(character)
	stopDash(true)
	endEffect(character)
end))
if player.Character then onCharacter(player.Character) end

table.insert(connections, DashFX.OnClientEvent:Connect(function(person, direction)
	-- Our own movement and FX were predicted immediately. Never replay either on confirmation.
	if person == player or typeof(person) ~= "Instance" or not person:IsA("Player") then return end
	if typeof(direction) ~= "Vector3" then return end
	if person.Character then dashEffect(person.Character, direction, person:GetAttribute("EquippedTrail") or "ice") end
end))

table.insert(connections, Feedback.OnClientEvent:Connect(function(kind, message, extra)
	if kind == "DashDenied" then
		stopDash(true)
		if player.Character then endEffect(player.Character) end
		cameraKick = 0
	elseif kind == "Reset" then
		stopDash(true)
		localDashAt = -100
		if player.Character then endEffect(player.Character) end
		showToast(message ~= "" and message or "Back to the start. Find your line.", C.muted, 1.8)
	elseif kind == "Finish" then
		stopDash(true)
		lastFinished = type(extra) == "table" and extra or nil
		if not muted then finishSound:Play() end
		showToast(lastFinished and string.format("FINISHED  %s  /  +%s COINS", timeText(lastFinished.time, true), coinText(lastFinished.coins)) or message, C.gold, 5)
	elseif kind == "Error" then
		showToast(message, C.red)
	elseif kind == "Purchase" then
		showToast(message, C.gold)
	else
		showToast(message, C.text)
	end
end))

local function updateSnapshot(nextSnapshot)
	if type(nextSnapshot) ~= "table" then return end
	local previousPhase = snapshot.phase
	local previousRound = snapshot.roundId
	snapshot = nextSnapshot
	receivedAt = os.clock()
	if previousRound ~= snapshot.roundId then
		lastFinished = nil
		closedResultsRound = nil
		localDashAt = -100
		stopDash(true)
	end
	if snapshot.phase ~= "Racing" or not snapshot.racing or snapshot.finished then stopDash(true) end
	local mapConfig = Config.Maps[snapshot.mapId]
	mapLabel.Text = string.upper(snapshot.mapName or (mapConfig and mapConfig.name) or "ENTER THE RACE")
	slash.BackgroundColor3 = mapConfig and mapConfig.accent or C.cyan
	phaseLabel.Text = ({Waiting = "GETTING READY", Intermission = "NEXT COURSE", Countdown = "ON YOUR MARK", Racing = "RACE IN PROGRESS", Results = "ROUND COMPLETE"})[snapshot.phase] or "DASHER"
	balanceLabel.Text = coinText(snapshot.coins)
	local status = snapshot.saveStatus
	saveLabel.Text = status == "session" and "SESSION COINS" or (status == "error" and "SAVE UNAVAILABLE" or (status == "loading" and "LOADING" or "COINS"))
	saveLabel.TextColor3 = status == "error" and C.red or C.muted
	accelerateButton.Visible = snapshot.canAccelerate == true and snapshot.phase == "Racing"
	restartButton.Visible = snapshot.phase == "Racing" and snapshot.racing == true and not snapshot.finished
	local progress = math.clamp(tonumber(snapshot.progress) or 0, 0, 1)
	progressLabel.Text = snapshot.finished and "FINISHED" or string.format("%d%%", math.floor(progress * 100))
	if reducedMotion then
		progressFill.Size = UDim2.fromScale(progress, 1)
	else
		TweenService:Create(progressFill, TweenInfo.new(0.18), {Size = UDim2.fromScale(progress, 1)}):Play()
	end
	updateShopButtons()
	if snapshot.phase == "Results" and previousPhase ~= "Results" and closedResultsRound ~= snapshot.roundId then
		openMenu("Results")
	elseif previousPhase == "Results" and snapshot.phase ~= "Results" and menuOpen and menuPage == "Results" then
		closeMenu()
	end
	if snapshot.phase == "Countdown" and previousPhase ~= "Countdown" then closeMenu() end
end
table.insert(connections, State.OnClientEvent:Connect(updateSnapshot))

-- Remove the prior overlay before animation evaluation to prevent accumulating rotations.
table.insert(connections, RunService.PreAnimation:Connect(function()
	for _, effect in pairs(effects) do restoreEffect(effect) end
end))
table.insert(connections, RunService.PreSimulation:Connect(function(dt)
	local now = os.clock()
	if activeDash then
		local dash = activeDash
		if player:GetAttribute("IsRacing") == false then
			stopDash(true)
		elseif not dash.root.Parent or dash.humanoid.Health <= 0 or now - dash.started >= Config.DashDuration then
			stopDash(false)
		elseif dashCast(dash.root, dash.direction, Config.DashSpeed * math.min(dt, 0.1) + 0.55) then
			stopDash(true)
		end
	end
	for character, effect in pairs(effects) do
		local age = now - effect.at
		if not character.Parent or age > 0.48 then
			endEffect(character)
		else
			local weight = math.min(1, age / 0.035) * math.clamp(1 - (age - Config.DashDuration) / 0.18, 0, 1)
			for _, item in ipairs(effect.instances) do
				if item:IsA("Trail") then item.Enabled = age < Config.DashDuration end
			end
			for _, motor in ipairs(effect.motors) do
				if motor.Parent then
					local base = motor.Transform
					effect.bases[motor] = base
					local name = motor.Name
					local angle = CFrame.identity
					if name == "Waist" then
						angle = CFrame.Angles(math.rad(-12), 0, 0)
					elseif name == "Root" or name == "RootJoint" then
						-- Convert a torso-forward lean into each rig's joint frame (R6 and R15 differ).
						local rotation = motor.C0.Rotation
						angle = rotation:Inverse() * CFrame.Angles(math.rad(-14), 0, 0) * rotation
					elseif string.find(name, "Shoulder") then
						local side = string.find(name, "Right") and 1 or -1
						angle = CFrame.Angles(math.rad(24), 0, math.rad(side * 9))
					elseif string.find(name, "Hip") then
						angle = CFrame.Angles(math.rad(-9), 0, 0)
					end
					motor.Transform = base:Lerp(base * angle, weight)
				end
			end
		end
	end
end))

local function updateInputHints()
	local input = UserInputService:GetLastInputType()
	local gamepad = string.find(input.Name, "Gamepad") ~= nil
	local touch = input == Enum.UserInputType.Touch or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	dashKey.Text = gamepad and "[X]" or (touch and "TAP DASH" or "Q / SHIFT")
	restartButton.Text = gamepad and "RESTART  [Y]" or (touch and "RESTART" or "RESTART  [R]")
	touchDash.Visible = UserInputService.TouchEnabled
end
table.insert(connections, UserInputService.LastInputTypeChanged:Connect(updateInputHints))
updateInputHints()

local function layout()
	local size = root.AbsoluteSize
	local width, height = size.X, size.Y
	local compact = width < 760
	local portrait = width < 520
	identity.Size = UDim2.fromOffset(compact and 158 or 224, compact and 68 or 78)
	identity.Position = UDim2.fromOffset(compact and 12 or 20, 12)
	mapLabel.Position = UDim2.fromOffset(17, compact and 43 or 49)
	mapLabel.TextSize = compact and 8 or 10
	coinPanel.Size = UDim2.fromOffset(compact and 138 or 164, 56)
	coinPanel.Position = UDim2.new(1, compact and -150 or -184, 0, 12)
	timerPanel.Position = portrait and UDim2.new(0.5, -78, 0, 88) or UDim2.new(0.5, -90, 0, 12)
	timerPanel.Size = UDim2.fromOffset(portrait and 156 or 180, portrait and 78 or 86)
	clockLabel.TextSize = portrait and 26 or 30
	clockLabel.Position = UDim2.fromOffset(6, portrait and 23 or 25)
	multiplierLabel.Position = UDim2.fromOffset(6, portrait and 58 or 64)
	topActions.Position = portrait and UDim2.new(1, -150, 0, 76) or UDim2.new(1, -240, 0, 80)
	topActions.Size = UDim2.fromOffset(portrait and 138 or 220, portrait and 92 or 34)
	trailsButton.Size = UDim2.fromOffset(portrait and 66 or 78, 30)
	helpButton.Size = UDim2.fromOffset(portrait and 64 or 62, 30)
	setupButton.Size = UDim2.fromOffset(portrait and 138 or 66, 30)
	helpButton.Position = UDim2.fromOffset(portrait and 74 or 85, 0)
	setupButton.Position = UDim2.fromOffset(portrait and 0 or 154, portrait and 38 or 0)
	-- Portrait puts controls below the top status row, clear of the central round clock.
	if portrait then
		topActions.Position = UDim2.new(1, -150, 0, 184)
		restartButton.Position = UDim2.fromOffset(12, 184)
	else
		restartButton.Position = UDim2.fromOffset(compact and 12 or 20, compact and 89 or 102)
	end
	local bottom = UserInputService.TouchEnabled and 18 or 15
	dashPanel.Size = UDim2.fromOffset(portrait and 214 or 280, 70)
	dashPanel.Position = UDim2.new(0.5, portrait and -107 or -140, 1, -bottom - 70)
	progressPanel.Size = UDim2.fromOffset(portrait and 240 or 330, 48)
	progressPanel.Position = UDim2.new(0.5, portrait and -120 or -165, 1, -bottom - 130)
	runLabel.Size = UDim2.fromOffset(portrait and 157 or 197, 18)
	tip.Visible = width >= 760 and height >= 540
	tip.Position = UDim2.new(0.5, -290, 1, -bottom - 164)
	footer.Visible = width >= 1000
	touchDash.Position = UDim2.new(1, -106, 1, portrait and -244 or -192)
	accelerateButton.Position = UDim2.new(0.5, -118, 0, portrait and 270 or 124)
	local modalWidth = math.min(540, width - 24)
	local modalHeight = math.min(486, height - 24)
	modal.Size = UDim2.fromOffset(modalWidth, modalHeight)
	modal.Position = UDim2.new(0.5, -modalWidth / 2, 0.5, -modalHeight / 2)
	modalTitle.TextSize = portrait and 19 or 24
	local toastWidth = math.min(470, width - 24)
	toast.Size = UDim2.fromOffset(toastWidth, 48)
	toast.Position = UDim2.new(0.5, -toastWidth / 2, 0, portrait and 270 or 184)
	countdown.Size = UDim2.fromOffset(math.min(420, width - 24), 100)
	countdown.Position = UDim2.new(0.5, -math.min(420, width - 24) / 2, portrait and 0.43 or 0.32, -50)
end
table.insert(connections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
layout()

RunService:BindToRenderStep("DasherPresentation", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local now = os.clock()
	local elapsed = now - receivedAt
	local phase = snapshot.phase
	local multiplier = phase == "Racing" and (snapshot.multiplier or 1) or 1
	local timeLeft = math.max(0, (snapshot.timeLeft or 0) - elapsed * multiplier)
	clockLabel.Text = phase == "Waiting" and "--:--" or timeText(math.ceil(timeLeft), false)
	clockLabel.TextColor3 = phase == "Racing" and timeLeft <= 20 and C.gold or C.text
	multiplierLabel.Text = multiplier > 1 and string.format("%.1fx  ROUND PACE", multiplier) or "ROUND TIME"
	multiplierLabel.TextColor3 = multiplier > 1 and C.gold or C.muted
	countdown.Visible = phase == "Countdown"
	countdown.Text = timeLeft > 0.7 and tostring(math.ceil(timeLeft)) or "GO"
	local charge = math.clamp((now - localDashAt) / Config.DashCooldown, 0, 1)
	local accepted = player:GetAttribute("DashAt")
	if typeof(accepted) == "number" then charge = math.min(charge, math.clamp((workspace:GetServerTimeNow() - accepted) / Config.DashCooldown, 0, 1)) end
	local enabled = phase == "Racing" and snapshot.racing and not snapshot.finished
	dashFill.Size = UDim2.fromScale(enabled and charge or 0, 1)
	dashTitle.TextColor3 = enabled and C.text or C.muted
	dashCaption.Text = not enabled and (snapshot.finished and "COURSE COMPLETE" or "RACE STARTS SOON") or (charge >= 0.999 and "READY" or "RECHARGING")
	dashFill.BackgroundColor3 = charge >= 0.999 and C.cyan or C.muted
	touchDash.BackgroundColor3 = enabled and charge >= 0.999 and C.cyan or C.card
	touchDash.TextColor3 = enabled and charge >= 0.999 and C.ink or C.muted
	if snapshot.finished then
		local resultTime = lastFinished and lastFinished.time
		if not resultTime then
			for _, result in ipairs(snapshot.finishers or {}) do if result.userId == player.UserId then resultTime = result.time break end end
		end
		runLabel.Text = "FINISHED  " .. timeText(resultTime or 0, true)
	elseif enabled and type(snapshot.runStartedAt) == "number" then
		runLabel.Text = "YOUR RUN  " .. timeText(workspace:GetServerTimeNow() - snapshot.runStartedAt, true)
	else
		runLabel.Text = snapshot.best and ("BEST  " .. timeText(snapshot.best, true)) or "FIND YOUR LINE"
	end
	local camera = workspace.CurrentCamera
	if camera ~= lastCamera then
		if lastCamera and lastCamera.Parent then lastCamera.FieldOfView = math.clamp(lastCamera.FieldOfView - cameraOffsetApplied, 1, 120) end
		cameraOffsetApplied = 0
		lastCamera = camera
	end
	if camera then
		local baseFov = camera.FieldOfView - cameraOffsetApplied
		cameraKick *= math.exp(-dt * 12)
		cameraOffsetApplied = reducedMotion and 0 or cameraKick
		camera.FieldOfView = math.clamp(baseFov + cameraOffsetApplied, 1, 120)
	end
end)

player:SetAttribute("DasherClientReady", true)
Action:FireServer("Ready")
task.delay(1.2, function()
	if gui.Parent and snapshot.phase == "Waiting" then Action:FireServer("Ready") end
end)
task.delay(2, function()
	if gui.Parent and not menuOpen then showToast("Jump + dash. Every fall sends you back. Open HELP for controls.", C.text, 7) end
end)

script.Destroying:Connect(function()
	stopDash(true)
	for character in pairs(effects) do endEffect(character) end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for _, connection in ipairs(characterConnections) do connection:Disconnect() end
	RunService:UnbindFromRenderStep("DasherPresentation")
	ContextActionService:UnbindAction("DasherDash")
	ContextActionService:UnbindAction("DasherRestart")
	ContextActionService:UnbindAction("DasherHelp")
	if lastCamera and lastCamera.Parent then lastCamera.FieldOfView = math.clamp(lastCamera.FieldOfView - cameraOffsetApplied, 1, 120) end
	dashSound:Destroy()
	finishSound:Destroy()
	audioGroup:Destroy()
	gui:Destroy()
end)
