-- Dasher Ascent: one movement skill, restrained presentation, authoritative rewards.
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
local package = ReplicatedStorage:WaitForChild("Dasher")
local Config = require(package:WaitForChild("Config"))
local RoundClock = require(package:WaitForChild("RoundClock"))
local ResetHold = require(package:WaitForChild("ResetHold"))
local remotes = package:WaitForChild("Remotes")
local Action, State, Feedback = remotes:WaitForChild("Action"), remotes:WaitForChild("State"), remotes:WaitForChild("Feedback")
local C = {ink=Color3.fromRGB(19,23,27), panel=Color3.fromRGB(29,35,40), card=Color3.fromRGB(40,47,52), border=Color3.fromRGB(91,107,115), text=Color3.fromRGB(238,242,241), muted=Color3.fromRGB(162,178,181), cyan=Color3.fromRGB(163,218,197), gold=Color3.fromRGB(255,214,143), red=Color3.fromRGB(255,139,154), green=Color3.fromRGB(163,218,197), lilac=Color3.fromRGB(162,191,211), paper=Color3.fromRGB(238,242,241)}
-- Restore the rounded typography used by the original Tower release.
local regularFont = Font.fromEnum(Enum.Font.Nunito)
local strongFont = Font.fromEnum(Enum.Font.FredokaOne)
local SkillFX = remotes:WaitForChild("SkillFX")
local skillRequests = {Updraft=-100}
local shuttleCarry = {approvedUntil=-100}
local lastSkillApplied = {Updraft=-math.huge}
local skillBlockedBefore = -math.huge
local spectatorExitPending = false
local spectatorExitRequestAt = -100
local altitudeDots = {}
local snapshot = {phase="Waiting",coins=0,owned={ice=true},equipped="ice",progress=0,finishers={},racers={}}
local reducedMotion, muted, menuOpen = false, false, false
local menuPage = "Home"
local lastRestartAt = -100
local resetHold, resetFocused, resetPointer = ResetHold.New(), true, nil
local resetKeyInputs = {}
local lastFinished, lastCamera = nil, nil
local cinematic, spectateTarget = nil, nil
local introPlayed = false
local lastLevel = nil
local cameraKick, cameraOffsetApplied, toastSerial, menuSerial = 0, 0, 0, 0
local effects, connections, characterConnections, shopButtons, questControls, voteButtons = {}, {}, {}, {}, {}, {}
local previewParticles, raceRows, stationBindings = {}, {}, {}
local particleStyles, particleStyleById
local rankButton, updateRaceBoard
local ui = {}
local openMenu, closeMenu, restoreCamera, setSpectate, renderVotes, openDialogue, closeDialogue
local dialogue = {active=nil,serial=0,rigs={},lastPoseAt=0}
local countdownPresentation = {text="",goUntil=0}
local function make(className,parent,props)
 local item=Instance.new(className)
 for key,value in pairs(props or {}) do item[key]=value end
 item.Parent=parent return item
end
local function round(parent,radius) return make("UICorner",parent,{CornerRadius=UDim.new(0,radius or 12)}) end
local function stroke(parent,color,transparency) return make("UIStroke",parent,{Color=color or C.border,Transparency=transparency or 0.55,Thickness=1}) end
local function panel(parent,name,size,position,color)
 local item=make("Frame",parent,{Name=name,Size=size,Position=position,BackgroundColor3=color or C.ink,BackgroundTransparency=0.06,BorderSizePixel=0})
 round(item,12) stroke(item) return item
end
local function label(parent,text,size,position,textSize,color,bold)
 return make("TextLabel",parent,{BackgroundTransparency=1,BorderSizePixel=0,Size=size,Position=position,Text=text,TextSize=textSize or 16,TextColor3=color or C.text,FontFace=bold and strongFont or regularFont,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
end
local function center(item) item.TextXAlignment=Enum.TextXAlignment.Center return item end
local function button(parent,text,size,position,color)
 local item=make("TextButton",parent,{Size=size,Position=position,Text=text,TextSize=16,FontFace=regularFont,TextColor3=color and C.ink or C.text,BackgroundColor3=color or C.panel,BorderSizePixel=0,AutoButtonColor=false,Selectable=true})
 round(item,9) local outline=stroke(item,color or C.border,color and 0.8 or 0.45)
 local scale=make("UIScale",item,{Scale=1})
 local function hover(active)
  if not item.Parent then return end
  TweenService:Create(outline,TweenInfo.new(reducedMotion and 0 or 0.13),{Transparency=active and 0.08 or 0.6}):Play()
  TweenService:Create(scale,TweenInfo.new(reducedMotion and 0 or .16,Enum.EasingStyle.Quad),{Scale=active and not reducedMotion and 1.015 or 1}):Play()
 end
 item.MouseEnter:Connect(function() hover(true) end) item.MouseLeave:Connect(function() hover(false) end)
 item.SelectionGained:Connect(function() hover(true) end) item.SelectionLost:Connect(function() hover(false) end)
 return item
end
local function wrap(item) item.TextWrapped=true item.TextTruncate=Enum.TextTruncate.None return item end
local function timeText(seconds,precise)
 seconds=math.max(0,tonumber(seconds) or 0)
 return precise and string.format("%02d:%05.2f",math.floor(seconds/60),seconds%60) or string.format("%02d:%02d",math.floor(seconds/60),math.floor(seconds%60))
end
local function coinText(amount)
 local value=tostring(math.floor(tonumber(amount) or 0)):reverse():gsub("(%d%d%d)","%1,"):reverse()
 return (value:gsub("^,",""))
end
local function trailColor(id)
 for _,item in ipairs(Config.Cosmetics) do if item.id==id then return item.color end end return C.cyan
end
local gui=make("ScreenGui",player:WaitForChild("PlayerGui"),{Name="DasherHUD",ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=20})
local root=make("Frame",gui,{Name="SafeCanvas",Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
ui.launcher=button(root,"MENU / TAB",UDim2.fromOffset(104,32),UDim2.fromOffset(14,70)) ui.launcher.TextSize=14
ui.status=panel(root,"ClimbClock",UDim2.fromOffset(248,46),UDim2.new(.5,-124,0,12))
ui.accent=make("Frame",ui.status,{Size=UDim2.fromOffset(3,22),Position=UDim2.fromOffset(13,12),BackgroundColor3=C.cyan,BorderSizePixel=0}) round(ui.accent,2)
ui.map=label(ui.status,"ASCENT",UDim2.new(1,-111,0,23),UDim2.fromOffset(26,3),17,C.text,true)
ui.phase=label(ui.status,"GETTING READY",UDim2.new(1,-111,0,16),UDim2.fromOffset(26,26),11,C.muted)
ui.clock=label(ui.status,"--:--",UDim2.fromOffset(75,34),UDim2.new(1,-87,0,6),23,C.text,true) ui.clock.TextXAlignment=Enum.TextXAlignment.Right
ui.balance=panel(root,"PlayerProgress",UDim2.fromOffset(156,55),UDim2.new(1,-170,0,12))
ui.level=label(ui.balance,"LEVEL 1",UDim2.fromOffset(84,21),UDim2.fromOffset(11,5),14,C.text,true)
ui.coins=label(ui.balance,"0",UDim2.fromOffset(60,21),UDim2.new(1,-71,0,5),14,C.gold,true) ui.coins.TextXAlignment=Enum.TextXAlignment.Right
ui.xpText=label(ui.balance,"0 / 500 XP",UDim2.new(1,-22,0,15),UDim2.fromOffset(11,28),11,C.muted)
ui.xpTrack=make("Frame",ui.balance,{Size=UDim2.new(1,-22,0,2),Position=UDim2.new(0,11,1,-6),BackgroundColor3=C.card,BorderSizePixel=0})
ui.xpFill=make("Frame",ui.xpTrack,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.cyan,BorderSizePixel=0})
rankButton=button(root,"RACE",UDim2.fromOffset(156,30),UDim2.new(1,-170,0,77)) rankButton.Name="RaceStandings" rankButton.TextSize=14 rankButton.Visible=false
ui.rail=make("Frame",root,{Name="AltitudeRail",Size=UDim2.fromOffset(50,236),Position=UDim2.new(0,14,.5,-118),BackgroundTransparency=1})
ui.railTitle=center(label(ui.rail,"HEIGHT",UDim2.new(1,0,0,17),UDim2.fromOffset(0,3),10,C.muted,true))
ui.railTrack=make("Frame",ui.rail,{Name="HeightTrack",Size=UDim2.new(0,3,1,-58),Position=UDim2.fromOffset(26,27),BackgroundColor3=C.card,BorderSizePixel=0}) round(ui.railTrack,3)
ui.railFill=make("Frame",ui.railTrack,{Size=UDim2.fromScale(1,0),AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),BackgroundColor3=C.cyan,BorderSizePixel=0})
ui.stageMarks={}
ui.dotLayer=make("Frame",ui.railTrack,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=5})
ui.selfDot=make("Frame",ui.dotLayer,{Name="YourHeight",AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(10,10),Position=UDim2.fromScale(.5,1),BackgroundColor3=C.cyan,BorderSizePixel=0,ZIndex=7}) round(ui.selfDot,10) stroke(ui.selfDot,C.ink,0)
ui.height=center(label(ui.rail,"0",UDim2.new(1,0,0,21),UDim2.new(0,0,1,-26),13,C.text,true))
ui.abilities=make("Frame",root,{Name="UpdraftDock",Size=UDim2.fromOffset(196,54),Position=UDim2.new(.5,-98,1,-68),BackgroundTransparency=1})
ui.updraft={}
ui.updraft.button=button(ui.abilities,"",UDim2.fromScale(1,1),UDim2.fromOffset(0,0)) ui.updraft.button.Name="Updraft"
ui.updraft.key=center(label(ui.updraft.button,"Q",UDim2.fromOffset(27,28),UDim2.fromOffset(11,11),16,C.cyan,true))
ui.updraft.key.BackgroundColor3=C.card ui.updraft.key.BackgroundTransparency=0 round(ui.updraft.key,6)
ui.updraft.title=label(ui.updraft.button,"UPDRAFT",UDim2.fromOffset(135,21),UDim2.fromOffset(50,8),15,C.text,true)
ui.updraft.cooldown=label(ui.updraft.button,"READY",UDim2.fromOffset(135,16),UDim2.fromOffset(50,29),12,C.muted)
ui.updraft.bar=make("Frame",ui.updraft.button,{Size=UDim2.new(1,-20,0,2),Position=UDim2.new(0,10,1,-5),BackgroundColor3=C.cyan,BorderSizePixel=0}) ui.updraft.color=C.cyan
local restartButton=button(root,"",UDim2.fromOffset(140,38),UDim2.new(0,14,1,-52)) restartButton.Name="HoldToReset"
ui.resetKey=center(label(restartButton,"R",UDim2.fromOffset(23,23),UDim2.fromOffset(8,6),12,C.muted,true))
ui.resetKey.BackgroundColor3=C.card ui.resetKey.BackgroundTransparency=0 round(ui.resetKey,5)
ui.resetTitle=label(restartButton,"HOLD TO RESET",UDim2.new(1,-43,0,24),UDim2.fromOffset(37,5),11,C.muted)
ui.resetTrack=make("Frame",restartButton,{Name="HoldTrack",Size=UDim2.new(1,-16,0,3),Position=UDim2.new(0,8,1,-6),BackgroundColor3=C.card,BorderSizePixel=0}) round(ui.resetTrack,3)
ui.resetFill=make("Frame",ui.resetTrack,{Name="HoldProgress",Size=UDim2.fromScale(0,1),BackgroundColor3=C.gold,BorderSizePixel=0}) round(ui.resetFill,3)
ui.resetHint=label(root,"Release to cancel",UDim2.fromOffset(132,16),UDim2.new(0,14,1,-73),11,C.gold) ui.resetHint.Visible=false
ui.run=center(label(root,"",UDim2.fromOffset(200,18),UDim2.new(.5,-100,1,-92),12,C.muted))
ui.onboarding=make("Frame",root,{Name="ClimbHint",Size=UDim2.fromOffset(320,46),Position=UDim2.new(.5,-160,0,76),BackgroundTransparency=1})
ui.onboardTitle=center(label(ui.onboarding,"YOUR ROUTE. YOUR RACE.",UDim2.new(1,0,0,23),UDim2.fromOffset(0,0),16,C.text,true))
ui.onboardText=center(label(ui.onboarding,"Q to lift  /  choose your next landing",UDim2.new(1,0,0,20),UDim2.fromOffset(0,26),13,C.muted))
local accelerateButton=button(root,"BOOST CLOCK",UDim2.fromOffset(148,36),UDim2.new(0.5,7,0,78),C.gold) accelerateButton.Visible=false
ui.watch=button(root,"WATCH RACE",UDim2.fromOffset(148,36),UDim2.new(0.5,-155,0,78)) ui.watch.Visible=false
ui.countdown=center(label(root,"",UDim2.fromOffset(240,96),UDim2.new(0.5,-120,0.35,-48),64,C.text,true)) ui.countdown.Visible=false
ui.countdown.Name="StartCountdown" ui.countdownScale=make("UIScale",ui.countdown,{Scale=1})
ui.toast=panel(root,"Toast",UDim2.fromOffset(420,44),UDim2.new(0.5,-210,0,132)) ui.toast.Visible=false ui.toast.ZIndex=60
ui.toastText=wrap(center(label(ui.toast,"",UDim2.new(1,-24,1,-8),UDim2.fromOffset(12,4),15,C.text,true))) ui.toastText.ZIndex=61
ui.vote=panel(root,"MapVote",UDim2.fromOffset(486,138),UDim2.new(0.5,-243,1,-162)) ui.vote.Visible=false
ui.voteTitle=label(ui.vote,"CHOOSE YOUR TOWER",UDim2.new(1,-28,0,26),UDim2.fromOffset(14,7),15,C.text,true)
ui.voteChoices=make("Frame",ui.vote,{Size=UDim2.new(1,-20,0,88),Position=UDim2.fromOffset(10,40),BackgroundTransparency=1})
ui.spectator=panel(root,"Spectating",UDim2.fromOffset(340,48),UDim2.new(0.5,-170,1,-68)) ui.spectator.Visible=false
ui.previous=button(ui.spectator,"<",UDim2.fromOffset(35,32),UDim2.fromOffset(8,8))
ui.next=button(ui.spectator,">",UDim2.fromOffset(35,32),UDim2.new(1,-85,0,8))
ui.stopWatch=button(ui.spectator,"X",UDim2.fromOffset(32,32),UDim2.new(1,-40,0,8))
ui.watching=label(ui.spectator,"WATCHING",UDim2.new(1,-142,1,0),UDim2.fromOffset(51,0),15,C.text,true)
ui.result=panel(root,"RoundSummary",UDim2.fromOffset(388,108),UDim2.new(0.5,-194,0.5,-54)) ui.result.Visible=false
ui.resultTitle=label(ui.result,"ROUND COMPLETE",UDim2.new(1,-58,0,27),UDim2.fromOffset(13,8),19,C.text,true)
ui.resultText=label(ui.result,"",UDim2.new(1,-26,0,22),UDim2.fromOffset(13,39),15,C.muted)
ui.resultOpen=button(ui.result,"RESULTS",UDim2.fromOffset(115,28),UDim2.fromOffset(13,70)) ui.resultOpen.TextSize=14
ui.resultWatch=button(ui.result,"WATCH",UDim2.fromOffset(100,28),UDim2.fromOffset(140,70),C.cyan) ui.resultWatch.TextSize=14
ui.resultClose=button(ui.result,"X",UDim2.fromOffset(28,28),UDim2.new(1,-40,0,8))
ui.skip=button(root,"SKIP INTRO",UDim2.fromOffset(116,32),UDim2.new(0.5,-58,1,-58)) ui.skip.Visible=false ui.skip.ZIndex=25 ui.skip.TextSize=14
local scrim=make("TextButton",root,{Name="ModalScrim",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.35,BorderSizePixel=0,Text="",AutoButtonColor=false,Visible=false,ZIndex=30,Selectable=false})
local modal=make("CanvasGroup",root,{Name="Menu",Size=UDim2.fromOffset(608,486),Position=UDim2.new(0.5,-304,0.5,-243),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=31,Visible=false}) round(modal,16) stroke(modal)
ui.menuAccent=make("Frame",modal,{Name="PageAccent",Size=UDim2.new(1,-40,0,2),Position=UDim2.fromOffset(20,0),BackgroundColor3=C.cyan,BorderSizePixel=0,ZIndex=35})
make("UIGradient",ui.menuAccent,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.25,0),NumberSequenceKeypoint.new(.75,0),NumberSequenceKeypoint.new(1,1)})})
ui.modalTitle=label(modal,"DASHER",UDim2.new(1,-86,0,30),UDim2.fromOffset(22,16),24,C.text,true)
ui.modalSubtitle=label(modal,"",UDim2.new(1,-44,0,25),UDim2.fromOffset(22,48),15,C.muted)
ui.close=button(modal,"X",UDim2.fromOffset(34,34),UDim2.new(1,-52,0,17))
local navigation=make("ScrollingFrame",modal,{Name="Navigation",Size=UDim2.new(1,-36,0,39),Position=UDim2.fromOffset(18,80),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X})
make("UIListLayout",navigation,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
local scroll=make("ScrollingFrame",modal,{Name="Content",Size=UDim2.new(1,-32,1,-137),Position=UDim2.fromOffset(16,129),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.muted,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y})
make("UIListLayout",scroll,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
make("UIPadding",scroll,{PaddingLeft=UDim.new(0,3),PaddingRight=UDim.new(0,7),PaddingBottom=UDim.new(0,10)})
local audioGroup=make("SoundGroup",SoundService,{Name="DasherLocalAudio",Volume=1})
local liftSound=make("Sound",SoundService,{Name="AscentLift",SoundId="rbxasset://sounds/action_jump.mp3",Volume=0.18,PlaybackSpeed=1.75,SoundGroup=audioGroup})
local finishSound=make("Sound",SoundService,{Name="DasherFinish",SoundId="rbxasset://sounds/volume_slider.ogg",Volume=0.3,PlaybackSpeed=1.1,SoundGroup=audioGroup})
-- Conversations stay local: a choice can open a page, never award coins/items.
do
 ui.dialogue=make("CanvasGroup",root,{Name="NPCConversation",Size=UDim2.fromOffset(620,218),Position=UDim2.new(.5,-310,1,-242),BackgroundColor3=C.ink,BorderSizePixel=0,ZIndex=45,Visible=false})
 round(ui.dialogue,16) stroke(ui.dialogue,C.cyan,.4)
 ui.dialoguePortrait=make("ViewportFrame",ui.dialogue,{Name="MerchantPortrait",Size=UDim2.fromOffset(112,170),Position=UDim2.fromOffset(12,12),BackgroundColor3=C.card,BorderSizePixel=0,Ambient=Color3.fromRGB(196,212,222),LightColor=Color3.fromRGB(255,244,217),LightDirection=Vector3.new(-1,-1,-1)}) round(ui.dialoguePortrait,12)
 ui.dialogueSpeaker=label(ui.dialogue,"",UDim2.new(1,-190,0,28),UDim2.fromOffset(142,14),23,C.text,true) ui.dialogueSpeaker.Name="Speaker"
 ui.dialogueRole=label(ui.dialogue,"",UDim2.new(1,-190,0,18),UDim2.fromOffset(143,43),12,C.cyan)
 ui.dialogueText=make("TextButton",ui.dialogue,{Name="Speech",Size=UDim2.new(1,-165,0,77),Position=UDim2.fromOffset(142,70),Text="",TextSize=17,FontFace=regularFont,TextColor3=C.text,BackgroundTransparency=1,BorderSizePixel=0,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,AutoButtonColor=false,Selectable=true,MaxVisibleGraphemes=-1})
 ui.dialogueHint=label(ui.dialogue,"Tap the words to reveal",UDim2.new(1,-166,0,17),UDim2.fromOffset(142,144),11,C.muted)
 ui.dialogueClose=button(ui.dialogue,"X",UDim2.fromOffset(30,30),UDim2.new(1,-42,0,12)) ui.dialogueClose.Name="LeaveConversation"
 ui.dialogueChoices=make("Frame",ui.dialogue,{Name="Choices",Size=UDim2.new(1,-40,0,36),Position=UDim2.new(0,20,1,-49),BackgroundTransparency=1})
 ui.dialogueButtons={}
 for index=1,3 do
  local choice=button(ui.dialogueChoices,"",UDim2.new(1/3,-6,1,0),UDim2.new((index-1)/3,(index-1)*3,0,0),index==1 and C.cyan or nil)
  choice.Name="Choice"..index choice.TextSize=13 ui.dialogueButtons[index]=choice
 end
 for _,item in ipairs(ui.dialogue:GetDescendants()) do if item:IsA("GuiObject") then item.ZIndex=46 end end
end
local function showToast(message,color,duration)
 toastSerial+=1 local serial=toastSerial
 ui.toastText.Text=tostring(message or "") ui.toastText.TextColor3=color or C.text ui.toast.Visible=true
 task.delay(duration or 3,function() if serial==toastSerial then ui.toast.Visible=false end end)
end
local function setModalLayer(parent)
 for _,item in ipairs(parent:GetDescendants()) do if item:IsA("GuiObject") then item.ZIndex=34 end end
end
local function menuCard(height,order)
 local card=panel(scroll,"Card",UDim2.new(1,-5,0,height),UDim2.fromOffset(0,0),C.card) card.LayoutOrder=order card.ZIndex=33 return card
end
local function textCard(title,body,order,height)
 local card=menuCard(height or 98,order)
 label(card,title,UDim2.new(1,-28,0,25),UDim2.fromOffset(14,10),17,C.text,true)
 local desc=wrap(label(card,body,UDim2.new(1,-28,1,-45),UDim2.fromOffset(14,38),15,C.muted)) desc.TextYAlignment=Enum.TextYAlignment.Top
 setModalLayer(card) return card
end
local function updateShopButtons()
 for id,entry in pairs(shopButtons) do
  local owned=snapshot.owned and snapshot.owned[id]
  entry.button.Text=snapshot.equipped==id and "EQUIPPED" or (owned and "EQUIP" or coinText(entry.price).." COINS")
  entry.button.BackgroundColor3=snapshot.equipped==id and C.cyan or C.panel
  entry.button.TextColor3=snapshot.equipped==id and C.ink or (owned and C.text or C.gold)
 end
end
local function cosmeticTile(row,cosmetic,column)
 local card=panel(row,"Effect_"..cosmetic.id,UDim2.new(.5,-5,1,0),UDim2.new((column-1)*.5,column==1 and 0 or 5,0,0),C.card)
 local preview=make("Frame",card,{Name="AnimatedTrailPreview",Size=UDim2.new(1,-14,0,74),Position=UDim2.fromOffset(7,7),BackgroundColor3=cosmetic.color:Lerp(C.ink,.82),BorderSizePixel=0,ClipsDescendants=true}) round(preview,8)
 make("UIGradient",preview,{Rotation=35,Color=ColorSequence.new(cosmetic.color:Lerp(C.ink,.66),C.ink)})
 local style=particleStyles[cosmetic.particleStyle or ""] or particleStyles[particleStyleById[cosmetic.id] or "crystal"]
 -- A lightweight 2D trail sample uses the same bundled texture and colour as
 -- the actual avatar effect. It is decorative, never an inventory entitlement.
 local runner=make("Frame",preview,{Size=UDim2.fromOffset(30,48),Position=UDim2.new(.76,-15,.5,-24),BackgroundTransparency=1})
 local head=make("Frame",runner,{Size=UDim2.fromOffset(12,12),Position=UDim2.fromOffset(9,0),BackgroundColor3=C.paper,BackgroundTransparency=.08,BorderSizePixel=0}) round(head,4)
 local torso=make("Frame",runner,{Size=UDim2.fromOffset(16,20),Position=UDim2.fromOffset(7,15),BackgroundColor3=C.paper,BackgroundTransparency=.16,BorderSizePixel=0,Rotation=-8}) round(torso,3)
 for side=-1,1,2 do
  local leg=make("Frame",runner,{Size=UDim2.fromOffset(6,15),Position=UDim2.fromOffset(12+side*6,31),BackgroundColor3=C.paper,BackgroundTransparency=.24,BorderSizePixel=0,Rotation=side*24}) round(leg,2)
 end
 for index=1,8 do
  local dot=make("ImageLabel",preview,{Name="PreviewParticle",AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(style.mist and 28 or 8,style.mist and 28 or 8),BackgroundTransparency=1,Image="rbxasset://textures/particles/"..style.texture,ImageColor3=cosmetic.color,ImageTransparency=.2,Rotation=index*43})
  table.insert(previewParticles,{image=dot,holder=preview,phase=index/8,style=style,color=cosmetic.color})
 end
 label(card,cosmetic.name,UDim2.new(1,-20,0,24),UDim2.fromOffset(10,86),16,C.text,true)
 label(card,cosmetic.particleStyle or "Trail",UDim2.new(1,-20,0,18),UDim2.fromOffset(10,110),12,C.muted)
 local buy=button(card,"",UDim2.new(1,-20,0,32),UDim2.new(0,10,1,-43)) buy.TextSize=13
 shopButtons[cosmetic.id]={button=buy,price=cosmetic.price}
 buy.Activated:Connect(function()
  if snapshot.equipped==cosmetic.id then return end
  if snapshot.owned and snapshot.owned[cosmetic.id] then Action:FireServer("Equip",cosmetic.id)
  elseif (snapshot.coins or 0)>=cosmetic.price then Action:FireServer("Buy",cosmetic.id)
  else showToast("Clear stages to earn more coins.",C.gold) end
 end)
 setModalLayer(card)
end
local function rankedRacers()
 local entries,finishes={},{}
 for index,result in ipairs(snapshot.finishers or {}) do finishes[result.userId]={rank=index,time=result.time} end
 for _,racer in ipairs(snapshot.racers or {}) do table.insert(entries,racer) end
 table.sort(entries,function(a,b)
  local fa,fb=finishes[a.userId],finishes[b.userId]
  if fa or fb then return fa and (not fb or fa.rank<fb.rank) or false end
  if a.progress~=b.progress then return (a.progress or 0)>(b.progress or 0) end
  return a.userId<b.userId
 end)
 return entries,finishes
end
updateRaceBoard=function()
 local entries,finishes=rankedRacers()
 local myRank
 for index,racer in ipairs(entries) do if racer.userId==player.UserId then myRank=index break end end
 rankButton.Text=myRank and string.format("#%d  /  %d RUNNERS",myRank,#entries) or string.format("RACE  /  %d RUNNERS",#entries)
 for index,row in ipairs(raceRows) do
  local racer=entries[index] row.card.Visible=racer~=nil
  if racer then
   local finish=finishes[racer.userId]
   row.rank.Text=string.format("%02d",index) row.rank.TextColor3=index==1 and C.gold or C.muted
   row.name.Text=racer.displayName or racer.name or "Runner" row.name.TextColor3=racer.userId==player.UserId and C.cyan or C.text
   row.detail.Text=finish and ("FINISHED  /  "..timeText(finish.time,true)) or string.format("STAGE %d  /  %d%% HEIGHT",racer.stage or 0,math.floor(math.clamp(racer.progress or 0,0,1)*100))
   row.fill.Size=UDim2.fromScale(finish and 1 or math.clamp(racer.progress or 0,0,1),1) row.fill.BackgroundColor3=finish and C.gold or C.cyan
  end
 end
end
local function showFinishCard(result)
 if type(result)~="table" then return end
 ui.result.Visible=true
 ui.resultTitle.Text=result.rank and ("#"..tostring(result.rank).."  SUMMIT REACHED!") or "SUMMIT REACHED!"
 ui.resultTitle.TextColor3=C.gold
 ui.resultText.Text=timeText(result.time,true).."   /   +"..coinText(result.coins).." COINS"
 ui.resultWatch.Visible=snapshot.phase=="Racing"
end
local function updateQuestControls()
 local p=snapshot.progression or {}
 if questControls.daily then questControls.daily.Text=p.dailyAvailable and "CLAIM" or "CLAIMED" end
 if questControls.weekly then questControls.weekly.Text=p.weeklyClaimed and "CLAIMED" or ((p.weeklyProgress or 0)>=(p.weeklyTarget or 10) and "CLAIM" or "IN PROGRESS") end
 if questControls.progress then questControls.progress.Text=string.format("Finish %d courses  /  %d of %d",p.weeklyTarget or 10,p.weeklyProgress or 0,p.weeklyTarget or 10) end
end
-- Map reveals are planned from the actual opening route, inside the tower.
-- Visible geometry is queried separately from gameplay collision: decoration
-- must not swallow the lens, while transparent sensors must not block it.
local mapIntroCamera={radius=.85,axes={"X","Y","Z"}}
function mapIntroCamera.decorDistance(guard,origin,direction)
 local nearest=nil local distance=direction.Magnitude
 for _,part in ipairs(guard.decor) do
  if part.Parent then
   -- Camera-only broad phase, then a conservative sphere-expanded oriented
   -- box. Do not enable CanQuery on decoration: gameplay raycasts share it.
   local offset=part.Position-origin
   local along=distance>.001 and math.clamp(offset:Dot(direction)/(distance*distance),0,1) or 0
   local broadRadius=part.Size.Magnitude*.5+mapIntroCamera.radius
   if (offset-direction*along).Magnitude<=broadRadius then
    local a=part.CFrame:PointToObjectSpace(origin)
    local b=part.CFrame:VectorToObjectSpace(direction)
    local extent=part.Size*.5+Vector3.new(mapIntroCamera.radius,mapIntroCamera.radius,mapIntroCamera.radius)
    local near,far,intersects=0,1,true
    for _,axis in ipairs(mapIntroCamera.axes) do
     if math.abs(b[axis])<.00001 then
      if math.abs(a[axis])>extent[axis] then intersects=false break end
     else
      local low,high=(-extent[axis]-a[axis])/b[axis],(extent[axis]-a[axis])/b[axis]
      if low>high then low,high=high,low end
      near,far=math.max(near,low),math.min(far,high)
      if near>far then intersects=false break end
     end
    end
    if intersects then nearest=math.min(nearest or math.huge,near*distance) end
   end
  end
 end
 return nearest
end
function mapIntroCamera.blocked(guard,position)
 return #workspace:GetPartBoundsInRadius(position,mapIntroCamera.radius,guard.overlap)>0
  or mapIntroCamera.decorDistance(guard,position,Vector3.zero)~=nil
end
function mapIntroCamera.cast(guard,origin,direction)
 if direction.Magnitude<.001 then return nil end
 local hit=workspace:Spherecast(origin,mapIntroCamera.radius,direction,guard.rays)
 local decorDistance=mapIntroCamera.decorDistance(guard,origin,direction)
 if decorDistance and (not hit or decorDistance<hit.Distance) then return {Distance=decorDistance} end
 return hit
end
function mapIntroCamera.position(guard,position,focus,previous)
 if not guard.map.Parent then return nil end
 local horizontal=Vector3.new(position.X-guard.center.X,0,position.Z-guard.center.Z)
 if horizontal.Magnitude>guard.limit then
  horizontal=horizontal.Unit*guard.limit
  position=Vector3.new(guard.center.X+horizontal.X,position.Y,guard.center.Z+horizontal.Z)
 end
 if mapIntroCamera.blocked(guard,focus) then return nil end
 -- Shorten the focus-to-lens arm before an occluder, including a wall or an
 -- upper landing. Distance is the travelled sphere-centre distance.
 local arm=position-focus
 if arm.Magnitude<2 then return nil end
 local hit=mapIntroCamera.cast(guard,focus,arm)
 if hit then
  if hit.Distance<2.3 then return nil end
  position=focus+arm.Unit*(hit.Distance-.3)
 end
 -- The smooth handoff also sweeps the lens. A safe endpoint alone would not
 -- stop an interpolated camera from passing through a beam between frames.
 if previous then
  local travel=position-previous
  if travel.Magnitude>.001 then
   local obstruction=mapIntroCamera.cast(guard,previous,travel)
   if obstruction then position=previous+travel.Unit*math.max(0,obstruction.Distance-.3) end
  end
 end
 if mapIntroCamera.blocked(guard,position) then return nil end
 arm=position-focus
 if arm.Magnitude<2 or mapIntroCamera.cast(guard,focus,arm) then return nil end
 return position
end
function mapIntroCamera.plan(map,start)
 local course=map:FindFirstChild("Course")
 local firstModel=course and course:FindFirstChild("P001")
 local first=firstModel and firstModel:FindFirstChild("Walkable")
 if not first or not first:IsA("BasePart") then return nil end
 local forward=Vector3.new(first.Position.X-start.Position.X,0,first.Position.Z-start.Position.Z)
 if forward.Magnitude<1 then return nil end
 forward=forward.Unit local right=Vector3.new(-forward.Z,0,forward.X)
 local visible,decor={},{}
 for _,part in ipairs(map:GetDescendants()) do
  if part:IsA("BasePart") and part.Transparency<.95 then
   table.insert(visible,part)
   if not part.CanQuery then table.insert(decor,part) end
  end
 end
 local rays=RaycastParams.new() rays.FilterType=Enum.RaycastFilterType.Include rays.FilterDescendantsInstances=visible rays.RespectCanCollide=false
 local overlap=OverlapParams.new() overlap.FilterType=Enum.RaycastFilterType.Include overlap.FilterDescendantsInstances=visible overlap.RespectCanCollide=false overlap.MaxParts=1
 local bounds=map:FindFirstChild("Bounds")
 local limit=bounds and bounds:IsA("BasePart") and math.min(bounds.Size.X,bounds.Size.Z)*.5-10 or 60
 local guard={map=map,rays=rays,overlap=overlap,decor=decor,center=start.Position,limit=math.clamp(limit,24,66)}
 local routeFocus,routeCount=Vector3.zero,0
 for index=1,4 do
  local model=course:FindFirstChild(string.format("P%03d",index))
  local landing=model and model:FindFirstChild("Walkable")
  if landing and landing:IsA("BasePart") then routeFocus+=landing.Position+Vector3.new(0,landing.Size.Y*.5+3.5,0) routeCount+=1 end
 end
 local focus=routeFocus/math.max(1,routeCount)
 for _,side in ipairs({1,-1,0}) do
  local from=start.Position-forward*26+right*(side*20)+Vector3.new(0,18,0)
  local to=start.Position-forward*18+right*(side*12)+Vector3.new(0,11,0)
  local clear=true local previous=nil
  for step=0,12 do
   local desired=from:Lerp(to,step/12)
   local safe=mapIntroCamera.position(guard,desired,focus,previous)
   if not safe or (safe-desired).Magnitude>.1 then clear=false break end
   previous=safe
  end
  if clear then return {from=from,to=to,focus=focus,guard=guard} end
 end
 -- If a streamed/custom course cannot provide a clear reveal, keep Roblox's
 -- ordinary camera. A wall-facing flyover is never a required loading step.
 return nil
end
restoreCamera=function()
 local oldFrame=cinematic
 local leavingCinematic=cinematic~=nil
 cinematic=nil spectateTarget=nil cameraKick=0 ui.skip.Visible=false ui.spectator.Visible=false
 local camera=workspace.CurrentCamera
 if camera then
  if camera==lastCamera then camera.FieldOfView=math.clamp(camera.FieldOfView-cameraOffsetApplied,1,120) end
  cameraOffsetApplied=0
  -- Only flyovers need a new viewing angle. Leaving menus/spectate must preserve
  -- the player's ordinary orbit instead of snapping it behind them every time.
  local rootPart=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if leavingCinematic and rootPart then
   local forward=Vector3.new(rootPart.CFrame.LookVector.X,0,rootPart.CFrame.LookVector.Z)
   forward=forward.Magnitude>.01 and forward.Unit or Vector3.new(0,0,-1)
   local focus=rootPart.Position+Vector3.new(0,2,0)
   local position=rootPart.Position-forward*18+Vector3.new(0,9,0)
   if oldFrame and oldFrame.guard then position=mapIntroCamera.position(oldFrame.guard,position,focus,oldFrame.lastPosition) or camera.CFrame.Position end
   camera.CFrame=CFrame.lookAt(position,focus)
   camera.Focus=CFrame.new(focus)
  end
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if humanoid then camera.CameraSubject=humanoid end
  camera.CameraType=Enum.CameraType.Custom
 end
end
local function beginCinematic(from,to,lookAt,duration,guard)
 ResetHold.Cancel(resetHold)
 if reducedMotion or menuOpen or dialogue.active or snapshot.phase=="Racing" or not workspace.CurrentCamera then return end
 restoreCamera() cinematic={from=from,to=to,lookAt=lookAt,started=os.clock(),duration=duration,guard=guard,lastPosition=guard and from or nil}
 workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable ui.skip.Visible=true
end
local function playLobbyIntro()
 if introPlayed or snapshot.phase=="Racing" or snapshot.phase=="Countdown" then return end
 local lobby=workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("DasherLobby")
 local start=lobby and lobby:FindFirstChild("CameraStart",true)
 local finish=lobby and lobby:FindFirstChild("CameraEnd",true)
 local look=lobby and lobby:FindFirstChild("CameraLookAt",true)
 if start and finish and look and start:IsA("BasePart") and finish:IsA("BasePart") and look:IsA("BasePart") then introPlayed=true beginCinematic(start.Position,finish.Position,look.Position,6) end
end
local function playMapIntro(roundId)
 task.spawn(function()
  local map=workspace:FindFirstChild("ActiveMap") local start=map and map:FindFirstChild("Start",true)
  for _=1,12 do
   if start or snapshot.phase~="Countdown" or snapshot.roundId~=roundId then break end
   task.wait(0.1) map=workspace:FindFirstChild("ActiveMap") start=map and map:FindFirstChild("Start",true)
  end
  if snapshot.phase~="Countdown" or snapshot.roundId~=roundId or not start or not start:IsA("BasePart") then return end
  local shot=mapIntroCamera.plan(map,start)
  local duration=math.min(4,RoundClock.Remaining(snapshot,workspace:GetServerTimeNow())-3.15)
  if duration>=.8 and shot then beginCinematic(shot.from,shot.to,shot.focus,duration,shot.guard) end
 end)
end
local function spectatorCandidates()
 local result={}
 for _,racer in ipairs(snapshot.racers or {}) do
  local person=Players:GetPlayerByUserId(racer.userId)
  local humanoid=person and person.Character and person.Character:FindFirstChildOfClass("Humanoid")
  if person~=player and not racer.finished and humanoid and humanoid.Health>0 then table.insert(result,{person=person,humanoid=humanoid,name=racer.displayName or racer.name or person.DisplayName}) end
 end return result
end
setSpectate=function(step)
 local candidates=spectatorCandidates()
 if #candidates==0 then spectatorExitPending=true Action:FireServer("Spectate",false) restoreCamera() showToast("No runners to watch right now.",C.muted) return end
 local index=1
 for i,item in ipairs(candidates) do if item.person==spectateTarget then index=((i-1+(step or 0))%#candidates)+1 break end end
 local chosen=candidates[index] cinematic=nil ui.skip.Visible=false spectateTarget=chosen.person
 local camera=workspace.CurrentCamera if camera then camera.CameraType=Enum.CameraType.Custom camera.CameraSubject=chosen.humanoid end
 ui.spectator.Visible=true ui.watching.Text=chosen.name
end
closeMenu=function()
 menuSerial+=1 local serial=menuSerial menuOpen=false
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(modal) then GuiService.SelectedObject=nil end
 if reducedMotion then modal.Visible=false scrim.Visible=false else
  TweenService:Create(modal,TweenInfo.new(0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{GroupTransparency=1,Position=UDim2.new(1,20,modal.Position.Y.Scale,modal.Position.Y.Offset)}):Play()
  task.delay(0.17,function() if serial==menuSerial then modal.Visible=false scrim.Visible=false end end)
 end
end
openMenu=function(page)
 if snapshot.phase=="Countdown" then return end
 ResetHold.Cancel(resetHold)
 if dialogue.active then closeDialogue(true) end
 if cinematic then restoreCamera() end
 local wasOpen=menuOpen
 menuSerial+=1 menuOpen=true menuPage=page or "Home" shopButtons={} questControls={} previewParticles={} raceRows={} 
 for _,item in ipairs(scroll:GetChildren()) do if item:IsA("GuiObject") then item:Destroy() end end
 scroll.CanvasPosition=Vector2.zero modal.Visible=true scrim.Visible=true modal.GroupTransparency=reducedMotion and 0 or 1
 if not reducedMotion and not wasOpen then modal.Position=UDim2.new(1,20,(ui.drawerPosition or modal.Position).Y.Scale,(ui.drawerPosition or modal.Position).Y.Offset) end
 if wasOpen then modal.GroupTransparency=reducedMotion and 0 or .24 end
 TweenService:Create(modal,TweenInfo.new(reducedMotion and 0 or (wasOpen and .18 or .28),Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{GroupTransparency=0,Position=ui.drawerPosition or modal.Position}):Play()
 ui.modalTitle.Text=string.upper(menuPage) ui.modalSubtitle.Text="Choose your route. Race to the summit."
 if menuPage=="Shop" or menuPage=="Inventory" then
  ui.modalTitle.Text=menuPage=="Shop" and "TRAIL STUDIO" or "YOUR COLLECTION"
  ui.modalSubtitle.Text=coinText(snapshot.coins).." coins  /  "..(menuPage=="Shop" and "Effects for every climb" or "Choose your equipped trail")
  local count,row=0,nil
  for _,cosmetic in ipairs(Config.Cosmetics) do
   if menuPage=="Shop" or (snapshot.owned and snapshot.owned[cosmetic.id]) then
    count+=1
    if count%2==1 then
     row=make("Frame",scroll,{Name="TrailRow",Size=UDim2.new(1,-5,0,182),BackgroundTransparency=1,LayoutOrder=math.ceil(count/2)})
    end
    cosmeticTile(row,cosmetic,(count%2==1) and 1 or 2)
   end
  end updateShopButtons()
 elseif menuPage=="Race" then
  ui.modalTitle.Text="THE RACE" ui.modalSubtitle.Text="Live height / finish order locks at the summit"
  for index=1,10 do
   local card=menuCard(65,index)
   local rank=label(card,"",UDim2.fromOffset(34,40),UDim2.fromOffset(12,8),21,C.gold,true)
   local name=label(card,"",UDim2.new(1,-73,0,25),UDim2.fromOffset(54,5),17,C.text,true)
   local detail=label(card,"",UDim2.new(1,-73,0,19),UDim2.fromOffset(54,31),12,C.muted)
   local track=make("Frame",card,{Size=UDim2.new(1,-73,0,3),Position=UDim2.fromOffset(54,55),BackgroundColor3=C.panel,BorderSizePixel=0})
   local fill=make("Frame",track,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.cyan,BorderSizePixel=0})
   raceRows[index]={card=card,rank=rank,name=name,detail=detail,fill=fill}
  end
  updateRaceBoard()
 elseif menuPage=="Quests" then
  local p=snapshot.progression or {}
  ui.modalSubtitle.Text=string.format("Level %d  /  %s XP",p.level or 1,coinText(p.xp or 0))
  local daily=menuCard(100,1)
  label(daily,"DAILY CHECK-IN",UDim2.new(1,-148,0,26),UDim2.fromOffset(14,10),17,C.text,true)
  wrap(label(daily,"+"..coinText(p.dailyReward or 25).." coins. Refreshes at 00:00 UTC.",UDim2.new(1,-148,0,48),UDim2.fromOffset(14,40),15,C.muted))
  questControls.daily=button(daily,"",UDim2.fromOffset(110,38),UDim2.new(1,-123,0,31),C.cyan)
  questControls.daily.Activated:Connect(function() if (snapshot.progression or {}).dailyAvailable then Action:FireServer("ClaimDaily") end end) setModalLayer(daily)
  local weekly=menuCard(117,2)
  label(weekly,"WEEKLY RUNNER",UDim2.new(1,-150,0,26),UDim2.fromOffset(14,10),17,C.text,true)
  questControls.progress=wrap(label(weekly,"",UDim2.new(1,-150,0,42),UDim2.fromOffset(14,38),15,C.muted))
  label(weekly,"+"..coinText(p.weeklyReward or 80).." coins",UDim2.new(1,-28,0,23),UDim2.fromOffset(14,87),15,C.gold)
  questControls.weekly=button(weekly,"",UDim2.fromOffset(122,38),UDim2.new(1,-135,0,38)) questControls.weekly.TextSize=13
  questControls.weekly.Activated:Connect(function() local q=snapshot.progression or {} if not q.weeklyClaimed and (q.weeklyProgress or 0)>=(q.weeklyTarget or 10) then Action:FireServer("ClaimWeekly") end end) setModalLayer(weekly)
  textCard("PLAY AT YOUR PACE","Missing a day never removes your coins or progress. All gameplay abilities stay equal.",3,96)
  updateQuestControls()
 elseif menuPage=="Leaderboard" or menuPage=="Results" then
  local board=snapshot.leaderboard or {} local results=menuPage=="Results"
  ui.modalSubtitle.Text=results and "Finish order / real run times" or ((board.scope or "Weekly ranking").." / earned by finishing races")
  local entries=results and (snapshot.finishers or {}) or (board.entries or {})
  if #entries==0 then
   local title,body="REACH THE SUMMIT","Finish a course to put your name on the board. Rankings refresh periodically."
   if results then title="A NEW CHALLENGE" body="No finishers this round. Learn the route and make the next one count."
   elseif board.status=="unavailable" then title="RANKING UNAVAILABLE" body="We could not load the weekly board. Your saved progress remains separate. Try again shortly."
   elseif board.status=="loading" then title="LOADING THE BOARD" body="Fetching the latest weekly scores. Reopen this page in a moment." end
   textCard(title,body,1,110)
  end
  for index,result in ipairs(entries) do
   if index>20 then break end local card=menuCard(66,index)
   label(card,string.format("%02d",index),UDim2.fromOffset(32,42),UDim2.fromOffset(12,12),20,index==1 and C.gold or C.muted,true)
   label(card,result.name or "Runner",UDim2.new(1,-172,0,28),UDim2.fromOffset(52,8),17,result.userId==player.UserId and C.cyan or C.text,true)
   label(card,results and ("+"..coinText(result.coins).." coins") or "WEEKLY SCORE",UDim2.new(1,-172,0,20),UDim2.fromOffset(52,38),13,C.muted)
   local score=label(card,results and timeText(result.time,true) or coinText(result.score),UDim2.fromOffset(105,40),UDim2.new(1,-118,0,13),18,C.text,true) score.TextXAlignment=Enum.TextXAlignment.Right setModalLayer(card)
  end
 elseif menuPage=="Settings" then
  ui.modalSubtitle.Text="Comfort settings for this play session."
  local motion=textCard("REDUCED MOTION","Skips flyovers and camera lift. Hides trailing particles.",1,105)
  for _,item in ipairs(motion:GetChildren()) do if item:IsA("TextLabel") then item.Size=UDim2.new(1,-130,item.Size.Y.Scale,item.Size.Y.Offset) end end
  local toggle=button(motion,reducedMotion and "ON" or "OFF",UDim2.fromOffset(83,36),UDim2.new(1,-97,0,34))
  toggle.Activated:Connect(function() reducedMotion=not reducedMotion toggle.Text=reducedMotion and "ON" or "OFF" if reducedMotion then cameraKick=0 if cinematic then restoreCamera() end end end) setModalLayer(motion)
  local sound=textCard("SOUND EFFECTS","Soft feedback for lifts, progress and finishes.",2,105)
  for _,item in ipairs(sound:GetChildren()) do if item:IsA("TextLabel") then item.Size=UDim2.new(1,-130,item.Size.Y.Scale,item.Size.Y.Offset) end end
  local soundToggle=button(sound,muted and "OFF" or "ON",UDim2.fromOffset(83,36),UDim2.new(1,-97,0,34))
  soundToggle.Activated:Connect(function() muted=not muted audioGroup.Volume=muted and 0 or 1 soundToggle.Text=muted and "OFF" or "ON" end) setModalLayer(sound)
 elseif menuPage=="Watch" then
  ui.modalTitle.Text="WATCH THE RACE" ui.modalSubtitle.Text="Choose your next move."
  if snapshot.phase~="Racing" then textCard("THE NEXT RACE IS CLOSE","Spectating becomes available when runners are on the course.",1,105)
  elseif not snapshot.finished and snapshot.racing then
   textCard("LEAVE THIS RUN?","Watching now forfeits this round. You will earn no finish reward and can race again next round.",1,112)
   local card=menuCard(60,2)
   local yes=button(card,"FORFEIT & WATCH",UDim2.new(0.6,-20,0,38),UDim2.fromOffset(11,11)) yes.TextSize=14
   local no=button(card,"KEEP RACING",UDim2.new(0.4,-13,0,38),UDim2.new(0.6,0,0,11),C.cyan) no.TextSize=14
   yes.Activated:Connect(function() spectatorExitPending=false Action:FireServer("Spectate",true) closeMenu() end) no.Activated:Connect(closeMenu) setModalLayer(card)
  else
   if snapshot.forfeited then textCard("BACK NEXT ROUND","This round was forfeited. You can watch the remaining runners and race again next round.",1,100) end
   local card=menuCard(64,2) local watch=button(card,"WATCH RUNNERS",UDim2.new(1,-24,0,40),UDim2.fromOffset(12,12),C.cyan)
   watch.Activated:Connect(function() spectatorExitPending=false Action:FireServer("Spectate",true) closeMenu() end) setModalLayer(card)
  end
 elseif menuPage=="Help" then
  ui.modalSubtitle.Text="One ability. Keep your next landing in sight."
  textCard("MOVE & LIFT","WASD + Space to move and jump. Q lifts you upward. Controller: A jump, X lift. On touch, tap Updraft.",1,110)
  textCard("LAND TO RECHARGE","Updraft gives you height or rescues a fall. Recharge: "..tostring(Config.UpdraftCooldown or 3.25).." seconds. Touch down to rearm. Cyan landings mark lift routes.",2,118)
  textCard("EARN YOUR NEXT EFFECT","Each stage awards coins and XP once per round. Falling does not let you repeat a stage reward. Reach the summit for a finish bonus.",3,118)
 else
  local p=snapshot.progression or {} ui.modalTitle.Text="DASHER" ui.modalSubtitle.Text="Level "..tostring(p.level or 1).."  /  "..coinText(snapshot.coins).." coins"
  local hero=menuCard(132,1)
  make("UIGradient",hero,{Rotation=20,Color=ColorSequence.new(C.cyan:Lerp(C.card,.82),C.card)})
  label(hero,"YOUR NEXT ASCENT",UDim2.new(1,-32,0,20),UDim2.fromOffset(16,13),11,C.cyan,true)
  label(hero,snapshot.mapName or "FIND YOUR ROUTE",UDim2.new(1,-32,0,30),UDim2.fromOffset(16,36),24,C.text,true)
  wrap(label(hero,"One lift. Many ways up.\nMeet the crew between races.",UDim2.new(1,-32,0,43),UDim2.fromOffset(16,76),15,C.muted)) setModalLayer(hero)
  local shortcuts={{snapshot.phase=="Racing" and "LIVE RACE" or "LAST RESULTS",snapshot.phase=="Racing" and "Race" or "Results"},{"YOUR EFFECTS","Inventory"},{"TRAIL COLLECTION","Shop"},{"YOUR CHALLENGES","Quests"},{snapshot.phase=="Racing" and "WATCH THE RACE" or "WEEKLY LEADERS","Watch"},{"HOW TO PLAY","Help"}}
  for index,item in ipairs(shortcuts) do
   local card=menuCard(53,index+2) local key=(item[2]=="Watch" and snapshot.phase~="Racing") and "Leaderboard" or item[2]
   local shortcut=button(card,item[1].."  >",UDim2.new(1,-16,0,37),UDim2.fromOffset(8,8)) shortcut.TextXAlignment=Enum.TextXAlignment.Left
   make("UIPadding",shortcut,{PaddingLeft=UDim.new(0,12)}) shortcut.Activated:Connect(function() openMenu(key) end) setModalLayer(card)
  end
 end
 for _,tab in ipairs(navigation:GetChildren()) do
  if tab:IsA("TextButton") then
   TweenService:Create(tab,TweenInfo.new(reducedMotion and 0 or .16),{BackgroundColor3=tab.Name==menuPage and C.cyan or C.card,TextColor3=tab.Name==menuPage and C.ink or C.text}):Play()
   local marker=tab:FindFirstChild("ActivePage") if marker then marker.Visible=tab.Name==menuPage end
  end
 end
 setModalLayer(modal)
 if UserInputService.GamepadEnabled then GuiService.SelectedObject=ui.close end
end
local function dialogueAllowed(state)
 return state.phase=="Waiting" or state.phase=="Intermission" or state.phase=="Results"
end
local function readStationValue(part,name,fallback)
 local value=part:FindFirstChild(name)
 return value and value:IsA("StringValue") and value.Value or fallback
end
local function captureNPCRig(model,rootPart)
 local rig={model=model,root=rootPart,parts={},pivots={Head=Vector3.new(0,1.72,0),LeftArm=Vector3.new(-1.15,.9,0),RightArm=Vector3.new(1.15,.9,0)},phase=math.abs(rootPart.Position.X*.43+rootPart.Position.Z*.21)}
 for group,pivot in pairs(rig.pivots) do
  local marker=rootPart:FindFirstChild("NPC"..group.."Pivot")
  if marker and marker:IsA("Vector3Value") then rig.pivots[group]=marker.Value end
 end
 for _,part in ipairs(model:GetDescendants()) do
  local tag=part:IsA("BasePart") and part:FindFirstChild("NPCMotion")
  if tag and tag:IsA("StringValue") then table.insert(rig.parts,{part=part,group=tag.Value,base=rootPart.CFrame:ToObjectSpace(part.CFrame)}) end
 end
 return rig
end
local function poseNPCRig(rig,now,target,talking)
 if not rig.model.Parent or not rig.root.Parent then return end
 local yaw,pitch=0,0
 if target then
  local offset=rig.root.CFrame:PointToObjectSpace(target)-rig.pivots.Head
  yaw=math.clamp(math.atan2(offset.X,offset.Z),-.65,.65)
  pitch=-math.clamp(math.atan2(offset.Y,math.max(1,Vector2.new(offset.X,offset.Z).Magnitude)),-.22,.22)
 end
 local motion=reducedMotion and 0 or 1
 local breath=math.sin(now*1.65+rig.phase)*.028*motion
 local talk=dialogue.active and math.max(0,1-(now-dialogue.active.started)/1.8) or 0
 for _,entry in ipairs(rig.parts) do
  if entry.part.Parent then
   local group=entry.group local pivot=rig.pivots[group]
   local transform=CFrame.new(0,breath,0)
   if group=="Head" then
    transform*=CFrame.new(pivot)*CFrame.Angles(pitch,yaw,0)*CFrame.new(-pivot)
   elseif group=="LeftArm" or group=="RightArm" then
    local side=group=="LeftArm" and -1 or 1
    local gesture=talking and group=="RightArm" and talk*math.rad(32)*motion or 0
    local sway=math.sin(now*1.3+rig.phase)*.025*motion
    transform*=CFrame.new(pivot)*CFrame.Angles(-gesture+sway,0,side*(.02*motion+gesture*.45))*CFrame.new(-pivot)
   end
   entry.part.CFrame=rig.root.CFrame*transform*entry.base
  end
 end
end
local function dialogueNode(page,node)
 local first={
  Shop={"Milo","TRAIL ARTISAN","Hey, climber! Looking for a little colour? Every trail here is yours to keep, and none changes your speed.","Browse trails","Earn coins?"},
  Inventory={"Nova","STYLE CURATOR","Good to see you. Your collection is ready. Want to change the trail you leave behind?","My collection","About trails"},
  Quests={"Fern","GARDEN KEEPER","Take a breath before the next climb. I keep track of your daily gift and weekly challenge.","My challenges","A challenge?"},
  Leaderboard={"Ace","RACE STEWARD","The summit decides the finish order. Ready to see who has been climbing this week?","The board","Climbing tips"},
 }
 local details={
  Shop="Clear a stage for coins and XP, then reach the summit for a finish bonus. Each stage pays once per round. Pick a favourite trail and save toward it.",
  Inventory="Equip any trail you own whenever you like. They are visual effects only. For a calmer view, switch on Reduced Motion in Settings.",
  Quests="Check in for a daily gift, then work toward the weekly finish challenge. Missing a day never takes away your coins. Your next climb is a fresh chance.",
  Leaderboard="Watch the moving blocks before you jump. Save Updraft for a tall gap or a recovery. There is more than one route; a lower ledge can rescue a fall.",
 }
 local key=first[page] and page or "Shop" local data=first[key]
 return {speaker=data[1],role=data[2],text=node=="advice" and details[key] or data[3],primary=data[4],secondary=node=="advice" and "Back" or data[5]}
end
local function renderDialogueNode(node)
 local active=dialogue.active if not active then return end
 active.node=node local content=dialogueNode(active.page,node)
 ui.dialogueText.Text=content.text ui.dialogueText.MaxVisibleGraphemes=reducedMotion and -1 or 0
 active.revealAt=os.clock() active.graphemes=utf8.len(content.text) or #content.text
 ui.dialogueButtons[1].Text=content.primary ui.dialogueButtons[2].Text=content.secondary ui.dialogueButtons[3].Text="See you!"
 if UserInputService:GetLastInputType().Name:find("Gamepad") then GuiService.SelectedObject=ui.dialogueButtons[1] end
end
closeDialogue=function(immediate)
 local active=dialogue.active
 if not active then return end
 dialogue.active=nil dialogue.serial+=1 local serial=dialogue.serial
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(ui.dialogue) then GuiService.SelectedObject=nil end
 local camera=workspace.CurrentCamera
 if camera and camera==active.camera then
  camera.CameraType=active.cameraType
  if active.subject and active.subject.Parent then camera.CameraSubject=active.subject end
  camera.CFrame=active.cameraFrame camera.Focus=active.cameraFocus
 end
 if active.prompt and active.prompt.Parent then active.prompt.Enabled=true end
 if immediate or reducedMotion then ui.dialogue.Visible=false else
  TweenService:Create(ui.dialogue,TweenInfo.new(.15,Enum.EasingStyle.Quad),{GroupTransparency=1}):Play()
  task.delay(.16,function() if serial==dialogue.serial then ui.dialogue.Visible=false end end)
 end
 dialogue.portraitRig=nil
end
openDialogue=function(part)
 if not dialogueAllowed(snapshot) or not part or not part.Parent then return end
 local rootPart=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if not rootPart or not humanoid or humanoid.Health<=0 or (rootPart.Position-part.Position).Magnitude>14 then return end
 ResetHold.Cancel(resetHold)
 closeDialogue(true) closeMenu() restoreCamera()
 local camera=workspace.CurrentCamera if not camera then return end
 local page=readStationValue(part,"MenuPage","Shop") local content=dialogueNode(page,"greeting")
 dialogue.serial+=1
 local active={part=part,page=page,node="greeting",started=os.clock(),camera=camera,cameraType=camera.CameraType,subject=camera.CameraSubject,cameraFrame=camera.CFrame,cameraFocus=camera.Focus,prompt=part:FindFirstChildWhichIsA("ProximityPrompt")}
 dialogue.active=active
 if active.prompt then active.prompt.Enabled=false end
 ui.dialogueSpeaker.Text=readStationValue(part,"NPCName",content.speaker)
 ui.dialogueRole.Text=readStationValue(part,"NPCRole",content.role)
 ui.dialogue.Visible=true ui.dialogue.GroupTransparency=reducedMotion and 0 or 1
 TweenService:Create(ui.dialogue,TweenInfo.new(reducedMotion and 0 or .22,Enum.EasingStyle.Quad),{GroupTransparency=0}):Play()
 for _,item in ipairs(ui.dialoguePortrait:GetChildren()) do if item:IsA("WorldModel") or item:IsA("Camera") then item:Destroy() end end
 local model=part.Parent
 if model:IsA("Model") then
  local clone=model:Clone()
  for _,item in ipairs(clone:GetDescendants()) do
   if item:IsA("ProximityPrompt") or item:IsA("LuaSourceContainer") or item:IsA("BillboardGui") or item:IsA("SurfaceGui") then item:Destroy() end
  end
  local world=make("WorldModel",ui.dialoguePortrait,{Name="Merchant"}) clone.Parent=world
  local portraitRoot=clone:FindFirstChild("HumanoidRootPart")
  if portraitRoot and portraitRoot:IsA("BasePart") then
   -- Clone the authored pose, not the current world look-at pose, so talking
   -- animation is not baked into and then applied again to the portrait.
   local originalRig=dialogue.rigs[part]
   for _,entry in ipairs(originalRig and originalRig.parts or {}) do
    local clonedPart=clone:FindFirstChild(entry.part.Name,true)
    if clonedPart and clonedPart:IsA("BasePart") then clonedPart.CFrame=portraitRoot.CFrame*entry.base end
   end
   local portraitCamera=make("Camera",ui.dialoguePortrait,{FieldOfView=32})
   portraitCamera.CFrame=CFrame.lookAt(portraitRoot.CFrame:PointToWorldSpace(Vector3.new(0,1.6,10)),portraitRoot.Position+Vector3.new(0,1,0))
   ui.dialoguePortrait.CurrentCamera=portraitCamera dialogue.portraitRig=captureNPCRig(clone,portraitRoot)
  end
 end
 renderDialogueNode("greeting")
end
ui.dialogueText.Activated:Connect(function() if dialogue.active then ui.dialogueText.MaxVisibleGraphemes=-1 end end)
ui.dialogueClose.Activated:Connect(function() closeDialogue() end)
ui.dialogueButtons[1].Activated:Connect(function() local active=dialogue.active if active then local page=active.page closeDialogue(true) openMenu(page) end end)
ui.dialogueButtons[2].Activated:Connect(function() local active=dialogue.active if active then renderDialogueNode(active.node=="advice" and "greeting" or "advice") end end)
ui.dialogueButtons[3].Activated:Connect(function() closeDialogue() end)
for index,page in ipairs({"Home","Shop","Inventory","Quests","Leaderboard","Settings"}) do
 local tab=button(navigation,page,UDim2.fromOffset(page=="Leaderboard" and 113 or 85,33),UDim2.fromOffset(0,0)) tab.Name=page tab.TextSize=14 tab.LayoutOrder=index
 make("Frame",tab,{Name="ActivePage",Size=UDim2.new(1,-24,0,2),Position=UDim2.new(0,12,1,-3),BackgroundColor3=C.ink,BackgroundTransparency=.35,BorderSizePixel=0,Visible=false})
 tab.Activated:Connect(function() openMenu(page) end)
end
ui.launcher.Activated:Connect(function() if menuOpen then closeMenu() else openMenu("Home") end end)
ui.close.Activated:Connect(closeMenu) scrim.Activated:Connect(closeMenu) ui.skip.Activated:Connect(restoreCamera)
ui.watch.Activated:Connect(function() spectatorExitPending=false Action:FireServer("Spectate",true) end)
ui.previous.Activated:Connect(function() setSpectate(-1) end) ui.next.Activated:Connect(function() setSpectate(1) end)
ui.stopWatch.Activated:Connect(function() spectatorExitPending=true Action:FireServer("Spectate",false) restoreCamera() end)
ui.resultOpen.Activated:Connect(function() ui.result.Visible=false openMenu("Results") end)
ui.resultClose.Activated:Connect(function() ui.result.Visible=false end)
ui.resultWatch.Activated:Connect(function() ui.result.Visible=false spectatorExitPending=false Action:FireServer("Spectate",true) end)
rankButton.Activated:Connect(function() openMenu("Race") end)
renderVotes=function()
 local options=snapshot.voteOptions or {} local changed=#voteButtons~=#options
 if not changed then for i,option in ipairs(options) do if voteButtons[i].id~=option.id then changed=true break end end end
 if changed then
  for _,item in ipairs(ui.voteChoices:GetChildren()) do item:Destroy() end voteButtons={}
  for i,option in ipairs(options) do
   local map=Config.Maps[option.id] or {}
   local card=button(ui.voteChoices,"",UDim2.new(1/math.max(1,#options),-6,1,0),UDim2.new((i-1)/math.max(1,#options),3,0,0))
   local bar=make("Frame",card,{Size=UDim2.new(1,-22,0,3),Position=UDim2.fromOffset(11,11),BackgroundColor3=map.accent or C.cyan,BorderSizePixel=0}) round(bar,3)
   local name=wrap(label(card,option.name or option.id,UDim2.new(1,-20,0,38),UDim2.fromOffset(10,19),14,C.text,true))
   local count=label(card,"",UDim2.new(1,-20,0,18),UDim2.fromOffset(10,64),13,C.muted)
   card.Activated:Connect(function() Action:FireServer("Vote",option.id) end)
   voteButtons[i]={id=option.id,button=card,count=count,name=name}
  end
 end
 for i,option in ipairs(options) do
  local entry=voteButtons[i] local chosen=snapshot.myVote==option.id
  entry.button.BackgroundColor3=chosen and C.card or C.panel entry.name.TextColor3=chosen and C.cyan or C.text
  entry.count.Text=(chosen and "PICKED / " or "")..tostring(option.votes or 0).." votes"
 end
end

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

-- Every client presents the replicated equipped ID for every avatar. No local
-- purchase or inventory mutation is involved. All textures ship with Roblox.
local cosmeticBindings={}
particleStyles={
 crystal={texture="SquareParticle.png",rate=10,life=.65,size=.15,speed=.5,spin=0,squash=0,accel=Vector3.new(0,-.3,0)},
 glow={texture="forcefield_glow_main.dds",rate=7,life=.9,size=.55,speed=.3,spin=0,squash=0,accel=Vector3.new(0,.6,0)},
 petal={texture="SquareParticle.png",rate=8,life=1.1,size=.28,speed=.7,spin=90,squash=.7,accel=Vector3.new(0,-2,0)},
 leaf={texture="SquareParticle.png",rate=7,life=1.0,size=.30,speed=1,spin=-65,squash=1.6,accel=Vector3.new(0,-3,0)},
 ember={texture="fire_sparks_main.dds",rate=12,life=.8,size=.38,speed=1.2,spin=25,squash=.2,accel=Vector3.new(0,3,0)},
 comet={texture="sparkles_main.dds",rate=10,life=.7,size=.22,speed=3,spin=0,squash=2.2,accel=Vector3.new(0,-.8,0),aligned=true},
 snow={texture="sparkles_main.dds",rate=9,life=1.3,size=.24,speed=.4,spin=35,squash=0,accel=Vector3.new(0,-2,0)},
 prism={texture="SquareParticle.png",rate=8,life=.9,size=.22,speed=.7,spin=140,squash=.1,accel=Vector3.new(0,.3,0),rainbow=true},
 sparks={texture="fire_sparks_main.dds",rate=12,life=.55,size=.32,speed=2.4,spin=-25,squash=1,accel=Vector3.new(0,-5,0),aligned=true},
 mist={texture="smoke_main.dds",rate=5,life=1.0,size=1.0,speed=.2,spin=14,squash=.1,accel=Vector3.new(0,.9,0),mist=true},
}
particleStyleById={ice="crystal",solar="glow",orchid="petal",mint="leaf",ember="ember",cobalt="comet",pearl="snow",prism="prism",crimson="sparks",aurora="mist"}
local function clearCosmetic(binding)
 if binding.attachment then binding.attachment:Destroy() end
 binding.attachment=nil binding.emitter=nil
end
local function rebuildCosmetic(binding)
 clearCosmetic(binding)
 local character=binding.character local rootPart=character and character:FindFirstChild("HumanoidRootPart")
 if not binding.alive or not rootPart then return end
 local id=binding.player:GetAttribute("EquippedTrail") or "ice"
 local cosmetic
 for _,candidate in ipairs(Config.Cosmetics) do if candidate.id==id then cosmetic=candidate break end end
 if not cosmetic then return end
 local style=particleStyles[cosmetic.particleStyle or ""] or particleStyles[particleStyleById[id] or "crystal"]
 local attachment=make("Attachment",rootPart,{Name="AscentCosmetic",Position=Vector3.new(0,-.5,1.2)})
 local color=cosmetic.color or C.cyan
 local sequence=ColorSequence.new(color)
 if style.rainbow then sequence=ColorSequence.new({ColorSequenceKeypoint.new(0,color),ColorSequenceKeypoint.new(.35,Color3.fromRGB(132,200,242)),ColorSequenceKeypoint.new(.7,Color3.fromRGB(243,171,192)),ColorSequenceKeypoint.new(1,Color3.fromRGB(176,230,194))})
 elseif style.mist then sequence=ColorSequence.new(color,color:Lerp(C.lilac,.7)) end
 local emitter=make("ParticleEmitter",attachment,{
  Name="MovementParticles",Texture="rbxasset://textures/particles/"..style.texture,
  Enabled=false,Rate=0,Lifetime=NumberRange.new(style.life*.75,style.life),Color=sequence,
  Speed=NumberRange.new(style.speed*.7,style.speed),Acceleration=style.accel,Drag=1.5,
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,style.size*.65),NumberSequenceKeypoint.new(.2,style.size),NumberSequenceKeypoint.new(1,style.mist and style.size*1.5 or style.size*.25)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,style.mist and .85 or .25),NumberSequenceKeypoint.new(.3,style.mist and .76 or .10),NumberSequenceKeypoint.new(1,1)}),
  Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(math.min(style.spin*.65,style.spin),math.max(style.spin*.65,style.spin)),
  Squash=NumberSequence.new(style.squash),SpreadAngle=Vector2.new(18,18),
  LightEmission=style.mist and .15 or .55,LightInfluence=.15,Brightness=1,
  EmissionDirection=Enum.NormalId.Back,LockedToPart=false,VelocityInheritance=0,
  Orientation=style.aligned and Enum.ParticleOrientation.VelocityParallel or Enum.ParticleOrientation.FacingCamera,
 })
 -- NumberRange endpoints must be ordered for negative-spin styles too.
 emitter.RotSpeed=NumberRange.new(math.min(style.spin*.65,style.spin),math.max(style.spin*.65,style.spin))
 binding.attachment=attachment binding.emitter=emitter binding.style=style
end
local function bindCosmeticPlayer(person)
 if cosmeticBindings[person] then return end
 local binding={player=person,alive=true,connections={}}
 cosmeticBindings[person]=binding
 local function characterAdded(character)
  clearCosmetic(binding) binding.character=character
  task.spawn(function()
   local rootPart=character:WaitForChild("HumanoidRootPart",10)
   if rootPart and binding.alive and binding.character==character then rebuildCosmetic(binding) end
  end)
 end
 table.insert(binding.connections,person.CharacterAdded:Connect(characterAdded))
 table.insert(binding.connections,person.CharacterRemoving:Connect(function(character) if binding.character==character then clearCosmetic(binding) binding.character=nil end end))
 table.insert(binding.connections,person:GetAttributeChangedSignal("EquippedTrail"):Connect(function() rebuildCosmetic(binding) end))
 if person.Character then characterAdded(person.Character) end
end
local function unbindCosmeticPlayer(person)
 local binding=cosmeticBindings[person] if not binding then return end
 binding.alive=false clearCosmetic(binding)
 for _,connection in ipairs(binding.connections) do connection:Disconnect() end
 cosmeticBindings[person]=nil
end
for _,person in ipairs(Players:GetPlayers()) do bindCosmeticPlayer(person) end
table.insert(connections,Players.PlayerAdded:Connect(bindCosmeticPlayer))
table.insert(connections,Players.PlayerRemoving:Connect(unbindCosmeticPlayer))
local particleTick=0
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
 particleTick+=dt if particleTick<.10 then return end particleTick=0
 local camera=workspace.CurrentCamera
 for _,binding in pairs(cosmeticBindings) do
  local emitter=binding.emitter local character=binding.character
  local rootPart=character and character:FindFirstChild("HumanoidRootPart")
  local humanoid=character and character:FindFirstChildOfClass("Humanoid")
  if emitter and emitter.Parent and rootPart and humanoid then
   local velocity=rootPart.AssemblyLinearVelocity local horizontal=Vector3.new(velocity.X,0,velocity.Z)
   local moving=velocity.Magnitude>3 and humanoid.Health>0 and not rootPart.Anchored
   local nearby=camera and (camera.CFrame.Position-rootPart.Position).Magnitude<130
   local enabled=moving and nearby and not reducedMotion
   emitter.Enabled=enabled emitter.Rate=enabled and binding.style.rate*math.clamp(velocity.Magnitude/20,.35,1) or 0
   if horizontal.Magnitude>2 then
    local direction=horizontal.Unit local position=rootPart.Position-direction*1.1+Vector3.new(0,-.5,0)
    binding.attachment.CFrame=rootPart.CFrame:ToObjectSpace(CFrame.lookAt(position,position+direction))
   end
   if reducedMotion then emitter:Clear() end
  end
 end
end))

local skillFxFolder=make("Folder",workspace,{Name="DasherLocalSkillFX"})
local function windRing(position,radius,color,duration,expand)
 local count=reducedMotion and 12 or 18
 for index=1,count do
  local a=(index-1)*math.pi*2/count local b=index*math.pi*2/count
  local function frame(scale)
   local start=position+Vector3.new(math.cos(a)*radius*scale,0,math.sin(a)*radius*scale)
   local finish=position+Vector3.new(math.cos(b)*radius*scale,0,math.sin(b)*radius*scale)
   return CFrame.lookAt((start+finish)/2,finish),(finish-start).Magnitude
  end
  local cf,length=frame(1)
  local piece=make("Part",skillFxFolder,{Name="WindRing",Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,Material=Enum.Material.Neon,Color=color,Transparency=.24,Size=Vector3.new(.13,.10,length+.05),CFrame=cf})
  local target,targetLength=frame(reducedMotion and 1 or (expand or 1))
  TweenService:Create(piece,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=target,Size=Vector3.new(.05,.06,targetLength),Transparency=1}):Play()
  task.delay(duration+.08,function() piece:Destroy() end)
 end
end
local function updraftVisual(person,position)
 local character=person and person.Character local rootPart=character and character:FindFirstChild("HumanoidRootPart")
 local color=person and trailColor(person:GetAttribute("EquippedTrail") or "ice") or C.cyan
 windRing(position-Vector3.new(0,2.4,0),2.3,color,reducedMotion and .22 or .5,2.8)
 if not rootPart then return end
 if not reducedMotion then
  for index=1,6 do
   local angle=index*math.pi/3
   local offset=Vector3.new(math.cos(angle)*1.3,-1.2,math.sin(angle)*1.3)
   local streak=make("Part",skillFxFolder,{Name="LiftStreak",Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,Material=Enum.Material.Neon,Color=color,Transparency=.18,Size=Vector3.new(.08,1.7,.08),CFrame=CFrame.new(position+offset)})
   TweenService:Create(streak,TweenInfo.new(.38,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=CFrame.new(position+offset+Vector3.new(0,6,0)),Size=Vector3.new(.04,.4,.04),Transparency=1}):Play()
   task.delay(.45,function() streak:Destroy() end)
  end
 end
 endEffect(character)
 local effect={at=os.clock(),kind="updraft",bases={},motors={},instances={}}
 effects[character]=effect
 for _,motor in ipairs(character:GetDescendants()) do
  if motor:IsA("Motor6D") and (motor.Name=="Waist" or motor.Name=="Root" or motor.Name=="RootJoint" or string.find(motor.Name,"Shoulder") or string.find(motor.Name,"Hip")) then table.insert(effect.motors,motor) end
 end
end
local function validVelocity(value)
 if typeof(value)~="Vector3" then return false end
 return value.X==value.X and value.Y==value.Y and value.Z==value.Z and value.Magnitude<500
end
-- Only the network owner transports its character. The server moves terrain and
-- independently verifies rider contact; no movement delta is sent by this client.
do
 local support, previousFrame, supportedCharacter = nil, nil, nil
 local ground = RaycastParams.new()
 ground.FilterType=Enum.RaycastFilterType.Include
 ground.RespectCanCollide=true
 function shuttleCarry.reset()
  support,previousFrame,supportedCharacter=nil,nil,nil
 end
 local function feetDistance(rootPart,humanoid)
  local distance=rootPart.Size.Y*.5+humanoid.HipHeight
  if humanoid.RigType==Enum.HumanoidRigType.R6 then
   local leg=humanoid.Parent:FindFirstChild("Left Leg")
   distance+=leg and leg:IsA("BasePart") and leg.Size.Y or 2
  end
  return distance
 end
 local function isShuttle(part,map)
  local model=part and part.Parent
  local motion=model and model:FindFirstChild("Motion")
  local travel=model and model:FindFirstChild("Travel")
  return part and part:IsA("BasePart") and part.CanCollide and part.Anchored
   and model and model:IsA("Model") and model.Parent==map:FindFirstChild("Course")
   and motion and motion:IsA("StringValue") and motion.Value=="Shuttle"
   and travel and travel:IsA("Vector3Value") and travel.Value.Magnitude>0 and travel.Value.Magnitude<=64
 end
 local contactOffsets={Vector3.zero,Vector3.new(1,0,0),Vector3.new(-1,0,0),Vector3.new(0,0,1),Vector3.new(0,0,-1),
  Vector3.new(.707,0,.707),Vector3.new(-.707,0,-.707),Vector3.new(-.707,0,.707),Vector3.new(.707,0,-.707)}
 local function footprintRadius(rootPart)
  return math.min(.8,math.max(rootPart.Size.X,rootPart.Size.Z)*.4)
 end
 local function shuttleContact(position,rootPart,feet,map,wanted)
  local radius=footprintRadius(rootPart)
  for _,offset in contactOffsets do
   local hit=workspace:Raycast(position+offset*radius,Vector3.new(0,-feet-.45,0),ground)
   if hit and (not wanted or hit.Instance==wanted) and hit.Normal.Y>.7 and hit.Distance>=feet-.55
    and isShuttle(hit.Instance,map) then return hit end
  end
  return nil
 end
 function shuttleCarry.step()
  local character=player.Character
  local humanoid=character and character:FindFirstChildOfClass("Humanoid")
  local rootPart=character and character:FindFirstChild("HumanoidRootPart")
  local map=workspace:FindFirstChild("ActiveMap")
  if not map or not rootPart or not humanoid or humanoid.Health<=0 or rootPart.Anchored
   or snapshot.phase~="Racing" or not snapshot.racing or snapshot.finished or snapshot.forfeited
   or humanoid.Jump or humanoid:GetState()==Enum.HumanoidStateType.Jumping
   or math.abs(rootPart.AssemblyLinearVelocity.Y)>12 or os.clock()<shuttleCarry.approvedUntil
   -- This timeout covers only an unanswered request. Approval/denial clears it.
   or os.clock()-skillRequests.Updraft<1.5 then
   shuttleCarry.reset() return
  end
  ground.FilterDescendantsInstances={map}
  local feet=feetDistance(rootPart,humanoid)
  if support and previousFrame and supportedCharacter==character and isShuttle(support,map) then
   local oldContact=false
   for _,offset in contactOffsets do
    local oldPoint=previousFrame:PointToObjectSpace(rootPart.Position+offset*footprintRadius(rootPart))
    local oldGap=oldPoint.Y-support.Size.Y*.5-feet
    if math.abs(oldPoint.X)<=support.Size.X*.5 and math.abs(oldPoint.Z)<=support.Size.Z*.5 and math.abs(oldGap)<=.55 then
     oldContact=true break
    end
   end
   -- Test old contact before transporting, then test the proposed contact against
   -- replicated geometry. Walking off an edge, jumping and teleports detach now.
   if oldContact then
    local delta=support.CFrame*previousFrame:Inverse()
    local proposed=delta:PointToWorldSpace(rootPart.Position)
    local displacement=(proposed-rootPart.Position).Magnitude
    local travel=support.Parent:FindFirstChild("Travel")
    if displacement>0.00001 and displacement<=math.min(8,travel.Value.Magnitude) then
     local hit=shuttleContact(proposed,rootPart,feet,map,support)
     if hit then
      character:PivotTo(delta*character:GetPivot())
     end
    end
   end
  end
  local hit=shuttleContact(rootPart.Position,rootPart,feet,map)
  if hit then
   support,previousFrame,supportedCharacter=hit.Instance,hit.Instance.CFrame,character
  else shuttleCarry.reset() end
 end
end
local function applyApprovedVelocity(kind,extra)
 if type(extra)~="table" or type(extra.at)~="number" or extra.at~=extra.at or not validVelocity(extra.velocity) then return false end
 if extra.at<=(lastSkillApplied[kind] or -math.huge) or extra.at<=skillBlockedBefore then return false end
 if snapshot.phase~="Racing" or not snapshot.racing or snapshot.finished then return false end
 local character=player.Character local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local rootPart=character and character:FindFirstChild("HumanoidRootPart")
 if not rootPart or not humanoid or humanoid.Health<=0 or rootPart.Anchored then return false end
 lastSkillApplied[kind]=extra.at
 shuttleCarry.reset()
 -- The impulse can arrive between physics steps. Do not reacquire the old floor
 -- before its new upward velocity is observable by the next simulation step.
 shuttleCarry.approvedUntil=os.clock()+.2
 -- The lift is applied once, only after the server approval arrives.
 
 humanoid.Jump=false humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
 rootPart:ApplyImpulse((extra.velocity-rootPart.AssemblyLinearVelocity)*rootPart.AssemblyMass)
 if kind=="Updraft" then
  skillRequests.Updraft=-100
  if not reducedMotion then cameraKick=2.2 end
  if not muted then local sound=liftSound:Clone() sound.Name="LiftSound" sound.PlaybackSpeed=1.24 sound.Volume=.20 sound.Parent=SoundService sound:Play() task.delay(1.5,function() sound:Destroy() end) end
 end
 return true
end
local function skillInputAllowed()
 return not cinematic and not dialogue.active and not spectateTarget and not menuOpen and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox() and snapshot.phase=="Racing" and snapshot.racing and not snapshot.finished
end
local function abilityReadiness(ability,serverNow,lastApproved,cooldown)
 -- Rendering and input share one server-time deadline. A stale periodic
 -- `updraftReady=false` cannot add another network interval to the cooldown.
 local approvedAt=math.max(tonumber(ability.updraftAt) or 0,lastApproved or -math.huge)
 local readyAt=math.max(tonumber(ability.updraftReadyAt) or 0,approvedAt+cooldown)
 local remaining=math.max(0,readyAt-serverNow)
 local armed=ability.updraftArmed
 if armed==nil then armed=ability.updraftReady==true end
 return armed==true and remaining<=0,math.clamp(1-remaining/cooldown,0,1),remaining
end
local function tryUpdraft()
 if not skillInputAllowed() or os.clock()-skillRequests.Updraft<.5 then return end
 local ability=snapshot.abilities or {}
 local ready=abilityReadiness(ability,workspace:GetServerTimeNow(),lastSkillApplied.Updraft,Config.UpdraftCooldown or 3.25)
 if not ready then return end
 skillRequests.Updraft=os.clock()
 shuttleCarry.reset()
 Action:FireServer("Updraft")
end
local function resetEligible(confirmedCoreReset)
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local rootPart=character and character:FindFirstChild("HumanoidRootPart")
 return resetFocused and not cinematic and not dialogue.active and not menuOpen and not spectateTarget
  and (confirmedCoreReset or not GuiService.MenuIsOpen) and not UserInputService:GetFocusedTextBox()
  and snapshot.phase=="Racing" and snapshot.racing==true and not snapshot.finished and not snapshot.spectating and not snapshot.forfeited
  and humanoid~=nil and humanoid.Health>0 and rootPart~=nil and not rootPart.Anchored
end
local function requestRestart(confirmedCoreReset)
 if not resetEligible(confirmedCoreReset) or os.clock()-lastRestartAt<.8 then return false end
 lastRestartAt=os.clock() shuttleCarry.reset()
 Action:FireServer("Restart")
 return true
end
local function resetKeyToken(input)
 return input.UserInputType.Name..":"..input.KeyCode.Name
end
local function beginResetHold(token)
 ResetHold.Begin(resetHold,token,os.clock(),resetEligible(false),player.Character)
end
local function cancelResetHold()
 ResetHold.Cancel(resetHold) resetPointer=nil
end
local function resetPointerInside(input)
 -- InputObject.Position and AbsolutePosition use the same inset-aware origin.
 -- Subtracting the top bar again would falsely cancel normal touch holds.
 local point=Vector2.new(input.Position.X,input.Position.Y)
 local pos,size=restartButton.AbsolutePosition,restartButton.AbsoluteSize
 return point.X>=pos.X and point.X<=pos.X+size.X and point.Y>=pos.Y and point.Y<=pos.Y+size.Y
end

ui.updraft.button.Activated:Connect(tryUpdraft)
-- Activated fires on release, so it must never be a reset shortcut. Pointer,
-- keyboard and gamepad all feed the same cancellable, once-per-press hold.
restartButton.InputBegan:Connect(function(input)
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 beginResetHold(input)
 if resetHold.active==input then resetPointer=input end
end)
restartButton.MouseLeave:Connect(function()
 if resetPointer and resetPointer.UserInputType==Enum.UserInputType.MouseButton1 then cancelResetHold() end
end)
restartButton.SelectionLost:Connect(function()
 local input=resetHold.active and resetKeyInputs[resetHold.active]
 if input and input.KeyCode==Enum.KeyCode.ButtonA then cancelResetHold() end
end)
table.insert(connections,UserInputService.InputBegan:Connect(function(input)
 if input.KeyCode==Enum.KeyCode.ButtonA and GuiService.SelectedObject==restartButton then
  local token=resetKeyToken(input) resetKeyInputs[token]=input beginResetHold(token)
 end
end))
table.insert(connections,UserInputService.InputEnded:Connect(function(input)
 ResetHold.Release(resetHold,input)
 ResetHold.Release(resetHold,resetKeyToken(input))
 if resetPointer==input then resetPointer=nil end
end))
table.insert(connections,UserInputService.InputChanged:Connect(function(input)
 if input==resetPointer and input.UserInputType==Enum.UserInputType.Touch and not resetPointerInside(input) then cancelResetHold() end
end))
table.insert(connections,UserInputService.TextBoxFocused:Connect(cancelResetHold))
table.insert(connections,GuiService.MenuOpened:Connect(cancelResetHold))
table.insert(connections,UserInputService.WindowFocusReleased:Connect(function() resetFocused=false cancelResetHold() end))
table.insert(connections,UserInputService.WindowFocused:Connect(function()
 resetFocused=true
 -- A key may have been released while the window was unfocused. Clear only
 -- genuinely released keys; still-held inputs must not restart a cancelled hold.
 for token,input in pairs(resetKeyInputs) do
  local down=false
  if input.UserInputType==Enum.UserInputType.Keyboard then down=UserInputService:IsKeyDown(input.KeyCode)
  elseif input.UserInputType.Name:find("Gamepad") then down=UserInputService:IsGamepadButtonDown(input.UserInputType,input.KeyCode) end
  if not down then ResetHold.Release(resetHold,token) end
 end
end))
local coreReset=make("BindableEvent",gui,{Name="ConfirmedReset"})
table.insert(connections,coreReset.Event:Connect(function()
 -- Roblox emits this only after the built-in reset confirmation is accepted.
 cancelResetHold() requestRestart(true)
end))
task.spawn(function()
 for _=1,20 do
  if not gui.Parent then return end
  if pcall(function() StarterGui:SetCore("ResetButtonCallback",coreReset) end) then return end
  task.wait(.25)
 end
end)
accelerateButton.Activated:Connect(function() if snapshot.canAccelerate then Action:FireServer("Accelerate") accelerateButton.Visible=false end end)
ContextActionService:BindAction("DasherUpdraft",function(_,state)
 if not skillInputAllowed() then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then tryUpdraft() end
 return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.Q,Enum.KeyCode.ButtonX)
ContextActionService:BindAction("DasherRestart",function(_,state,input)
 local token=resetKeyToken(input) resetKeyInputs[token]=input
 if state==Enum.UserInputState.End then
  ResetHold.Release(resetHold,token)
 elseif state==Enum.UserInputState.Cancel then
  if resetHold.active==token then cancelResetHold() end
 elseif state==Enum.UserInputState.Begin then beginResetHold(token) end
 return resetEligible(false) and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
end,false,Enum.KeyCode.R,Enum.KeyCode.ButtonY)
ContextActionService:BindAction("DasherMenu",function(_,state)
 if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then if dialogue.active then closeDialogue() elseif menuOpen then closeMenu() else openMenu("Home") end end
 return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.Tab,Enum.KeyCode.H,Enum.KeyCode.ButtonSelect)
ContextActionService:BindAction("DasherSpectate",function(_,state,input)
 if state~=Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
 if input.KeyCode==Enum.KeyCode.ButtonB and dialogue.active then closeDialogue() return Enum.ContextActionResult.Sink end
 if input.KeyCode==Enum.KeyCode.ButtonB and menuOpen then closeMenu() return Enum.ContextActionResult.Sink end
 if not spectateTarget then return Enum.ContextActionResult.Pass end
 if input.KeyCode==Enum.KeyCode.ButtonB then spectatorExitPending=true Action:FireServer("Spectate",false) restoreCamera()
 else setSpectate(input.KeyCode==Enum.KeyCode.ButtonL1 and -1 or 1) end
 return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,Enum.KeyCode.ButtonB)
local function onCharacter(character)
 cancelResetHold()
 closeDialogue(true)
 shuttleCarry.reset()
 skillBlockedBefore=workspace:GetServerTimeNow()
 skillRequests.Updraft=-100 
 if snapshot.spectating then spectatorExitPending=true Action:FireServer("Spectate",false) end
  restoreCamera()
 for _,connection in ipairs(characterConnections) do connection:Disconnect() end characterConnections={}
 
 task.spawn(function()
  local humanoid=character:WaitForChild("Humanoid",10)
  if not humanoid or character~=player.Character then return end
  restoreCamera()
  table.insert(characterConnections,humanoid.Died:Connect(function() cancelResetHold() endEffect(character) restoreCamera() end))
 end)
end
table.insert(connections,player.CharacterAdded:Connect(onCharacter))
table.insert(connections,player.CharacterRemoving:Connect(function(character) cancelResetHold() closeDialogue(true) endEffect(character) restoreCamera() end))
if player.Character then onCharacter(player.Character) end
table.insert(connections,Players.PlayerRemoving:Connect(function(person) if person==spectateTarget then setSpectate(1) end end))
table.insert(connections,SkillFX.OnClientEvent:Connect(function(kind,data)
 if kind=="Updraft" and type(data)=="table" and typeof(data.position)=="Vector3" then updraftVisual(Players:GetPlayerByUserId(data.userId),data.position) end
end))
table.insert(connections,Feedback.OnClientEvent:Connect(function(kind,message,extra)
 if kind=="Updraft" then applyApprovedVelocity("Updraft",extra)
 elseif kind=="SkillDenied" then
  skillRequests.Updraft=-100
  if message and message~="" then showToast(message,C.muted,1.7) end
 elseif kind=="Reset" or kind=="MovementCorrected" then
  cancelResetHold()
  shuttleCarry.reset()
  skillBlockedBefore=workspace:GetServerTimeNow() skillRequests.Updraft=-100
  if player.Character then endEffect(player.Character) end
  showToast(message~="" and message or "Back at the base. Try another climb.",C.muted,1.5)
 elseif kind=="StageCompleted" then
  if type(extra)=="table" then showToast(string.format("STAGE %d   +%d COINS   +%d XP",extra.stage or 0,extra.coins or 0,extra.xp or 0),C.cyan,2.2) end
 elseif kind=="Finish" then
  cancelResetHold()
  lastFinished=type(extra)=="table" and extra or nil
  if not muted then finishSound:Play() end
  showFinishCard(lastFinished)
  showToast(lastFinished and string.format("SUMMIT  %s  /  +%s COINS",timeText(lastFinished.time,true),coinText(lastFinished.coins)) or message,C.gold,4)
 elseif kind=="Error" then showToast(message,C.red)
 elseif kind=="Purchase" then showToast(message,C.gold)
 else showToast(message,C.text) end
end))
local function updateStageMarkers(count)
 count=math.clamp(math.floor(tonumber(count) or 8),1,16)
 if #ui.stageMarks==count then return end
 for _,entry in ipairs(ui.stageMarks) do entry.number:Destroy() entry.line:Destroy() end
 ui.stageMarks={}
 for stage=1,count do
  local y=1-stage/count
  local line=make("Frame",ui.railTrack,{Size=UDim2.fromOffset(9,1),Position=UDim2.new(0,-3,y,0),BackgroundColor3=C.border,BorderSizePixel=0})
  local number=label(ui.railTrack,tostring(stage),UDim2.fromOffset(15,15),UDim2.new(0,-21,y,-7),10,C.muted)
  table.insert(ui.stageMarks,{line=line,number=number})
 end
end
local function updateAltitudeDots()
 local live={}
 for index,racer in ipairs(snapshot.racers or {}) do
  if racer.userId~=player.UserId then
   live[racer.userId]=true
   local dot=altitudeDots[racer.userId]
   if not dot then
    dot=make("Frame",ui.dotLayer,{Name="Runner_"..tostring(racer.userId),AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(8,8),BackgroundColor3=C.lilac,BorderSizePixel=0,ZIndex=6}) round(dot,8) stroke(dot,C.ink,.05) altitudeDots[racer.userId]=dot
   end
   dot.Position=UDim2.new(.5,((index%3)-1)*8,1-math.clamp(tonumber(racer.progress) or 0,0,1),0)
   dot.BackgroundColor3=racer.finished and C.gold or C.lilac
  end
 end
 for id,dot in pairs(altitudeDots) do if not live[id] then dot:Destroy() altitudeDots[id]=nil end end
end
local lobbyThemeId=nil
local function applyLobbyTheme()
 if lobbyThemeId==snapshot.mapId then return end
 local lobby=workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("DasherLobby")
 local theme=Config.Maps[snapshot.mapId]
 if not lobby or not theme or not theme.accent then return end
 lobbyThemeId=snapshot.mapId
 for _,part in ipairs(lobby:GetDescendants()) do
  local tint=part:IsA("BasePart") and part:FindFirstChild("LobbyTint")
  if tint and tint:IsA("StringValue") then
   local color=tint.Value=="soft" and theme.accent:Lerp(Color3.fromRGB(240,246,240),.65) or theme.accent
   TweenService:Create(part,TweenInfo.new(reducedMotion and 0 or .8),{Color=color}):Play()
   for _,effect in ipairs(part:GetDescendants()) do
    if effect:IsA("Light") then effect.Color=color
    elseif effect:IsA("ParticleEmitter") then effect.Color=ColorSequence.new(color) end
   end
  end
 end
end
local function updateSnapshot(nextSnapshot)
 if not RoundClock.Accept(snapshot,nextSnapshot) then return end
 local previousPhase,previousRound,previousSpectating,previousFinished=snapshot.phase,snapshot.roundId,snapshot.spectating,snapshot.finished
 local previousFinalSprint=snapshot.finalSprint
 snapshot=nextSnapshot
 if previousPhase~=snapshot.phase or previousRound~=snapshot.roundId or not resetEligible(false) then cancelResetHold() end
 if dialogue.active and not dialogueAllowed(snapshot) then closeDialogue(true) end
 if previousPhase=="Countdown" and snapshot.phase=="Racing" then countdownPresentation.goUntil=(snapshot.phaseStartedAt or 0)+.75
 elseif snapshot.phase~="Racing" then countdownPresentation.goUntil=0 end
 if previousRound~=snapshot.roundId then spectatorExitPending=false skillBlockedBefore=workspace:GetServerTimeNow() lastFinished=nil lastSkillApplied.Updraft=-math.huge restoreCamera() ui.result.Visible=false end
 if previousPhase~=snapshot.phase then
  restoreCamera()
  if snapshot.phase=="Countdown" then closeMenu() playMapIntro(snapshot.roundId)
  elseif snapshot.phase=="Results" then
   ui.result.Visible=true ui.resultTitle.Text=snapshot.finished and "SUMMIT REACHED" or "ROUND COMPLETE"
   ui.resultTitle.TextColor3=snapshot.finished and C.gold or C.text ui.resultWatch.Visible=false
   local first=(snapshot.finishers or {})[1]
   ui.resultText.Text=first and ((first.name or "Runner").."  /  "..timeText(first.time,true)) or "Fresh course. Fresh start."
   if snapshot.finished and lastFinished then showFinishCard(lastFinished) end
   local resultRound=snapshot.roundId task.delay(5,function() if snapshot.roundId==resultRound then ui.result.Visible=false end end)
  else ui.result.Visible=false if menuOpen and menuPage=="Results" then closeMenu() end end
 end
 if snapshot.finished and not previousFinished and snapshot.phase=="Racing" then
  for index,result in ipairs(snapshot.finishers or {}) do
   if result.userId==player.UserId then
    lastFinished=lastFinished or {rank=index,time=result.time,coins=result.coins}
    showFinishCard(lastFinished) break
   end
  end
 end
 if snapshot.finalSprint and not previousFinalSprint and snapshot.phase=="Racing" and not snapshot.finished then showToast("FIRST FINISH!  "..timeText(snapshot.timeLeft).." LEFT",C.gold,3) end
 if snapshot.phase=="Racing" and snapshot.spectating and not spectateTarget and not spectatorExitPending then setSpectate(0)
 elseif not snapshot.spectating then spectatorExitPending=false if previousSpectating then restoreCamera() end end
 local map=Config.Maps[snapshot.mapId]
 ui.map.Text=snapshot.mapName or (map and map.name) or "DASHER" ui.accent.BackgroundColor3=map and map.accent or C.cyan
 ui.phase.Text=({Waiting="WELCOME",Intermission="PICK A TOWER",Countdown="ON YOUR MARK",Racing="CLIMB IN PROGRESS",Results="ROUND COMPLETE"})[snapshot.phase] or "DASHER"
 ui.coins.Text=coinText(snapshot.coins).." C"
 local p=snapshot.progression or {}
 ui.level.Text=snapshot.saveStatus=="error" and "SAVE ERROR" or (snapshot.saveStatus=="loading" and "LOADING" or ((ui.compact and "LV. " or "LEVEL ")..tostring(p.level or 1)))
 local xpPerLevel=math.max(1,p.xpPerLevel or Config.XPPerLevel or 500)
 local xpInto=math.clamp(p.xpIntoLevel or (p.xp or 0)%xpPerLevel,0,xpPerLevel)
 ui.xpText.Text=string.format("%d / %d XP",xpInto,xpPerLevel)
 TweenService:Create(ui.xpFill,TweenInfo.new(reducedMotion and 0 or .3),{Size=UDim2.fromScale(xpInto/xpPerLevel,1)}):Play()
 if lastLevel and (p.level or 1)>lastLevel then showToast("LEVEL "..tostring(p.level).." REACHED",C.cyan,3) end
 lastLevel=p.level or 1
 updateStageMarkers((snapshot.altitude or {}).totalStages or 8)
 ui.level.TextColor3=snapshot.saveStatus=="error" and C.red or C.muted
 accelerateButton.Visible=snapshot.canAccelerate==true and snapshot.phase=="Racing"
 ui.watch.Visible=snapshot.finished==true and snapshot.phase=="Racing" and not snapshot.spectating
 restartButton.Visible=snapshot.phase=="Racing" and snapshot.racing==true and not snapshot.finished
 updateAltitudeDots()
 updateRaceBoard() applyLobbyTheme()
 if menuOpen and (menuPage=="Shop" or menuPage=="Inventory") then ui.modalSubtitle.Text=coinText(snapshot.coins).." coins  /  "..(menuPage=="Shop" and "Effects for every climb" or "Choose your equipped trail") end
 updateShopButtons() updateQuestControls() renderVotes()
 if snapshot.phase=="Intermission" then playLobbyIntro() end
end
table.insert(connections,State.OnClientEvent:Connect(updateSnapshot))
-- Remove the prior overlay before animation evaluation to prevent accumulating rotations.
table.insert(connections, RunService.PreAnimation:Connect(function()
	for _, effect in pairs(effects) do restoreEffect(effect) end
end))
table.insert(connections,RunService.PreSimulation:Connect(function()
 shuttleCarry.step()
 local now=os.clock()
 for character,effect in pairs(effects) do
  local age=now-effect.at
  if not character.Parent or age>.60 then endEffect(character)
  else
   local weight=math.min(1,age/.06)*math.clamp(1-(age-.32)/.18,0,1)
   for _,motor in ipairs(effect.motors) do
    if motor.Parent then
     local base=motor.Transform effect.bases[motor]=base
     local name=motor.Name local angle=CFrame.identity
     if string.find(name,"Shoulder") then local side=string.find(name,"Right") and 1 or -1 angle=CFrame.Angles(math.rad(-24),0,math.rad(side*22))
     elseif string.find(name,"Hip") then angle=CFrame.Angles(math.rad(12),0,0)
     else local rotation=motor.C0.Rotation angle=rotation:Inverse()*CFrame.Angles(math.rad(5),0,0)*rotation end
     motor.Transform=base:Lerp(base*angle,weight)
    end
   end
  end
 end
end))
local function updateInputHints()
 local input=UserInputService:GetLastInputType()
 local gamepad=string.find(input.Name,"Gamepad")~=nil
 local touch=input==Enum.UserInputType.Touch or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
 ui.updraft.key.Text=gamepad and "X" or (touch and "^" or "Q")
 ui.launcher.Text=ui.compact and "MENU" or (gamepad and "MENU / VIEW" or (touch and "MENU" or "MENU / TAB"))
 ui.resetKey.Text=gamepad and "Y" or (touch and "↺" or "R")
 ui.onboardText.Text=gamepad and "X to lift / choose your landing" or (touch and "Tap Updraft / choose your landing" or "Q to lift / choose your landing")
end
table.insert(connections,UserInputService.LastInputTypeChanged:Connect(updateInputHints)) updateInputHints()
local function layout()
 local width,height=root.AbsoluteSize.X,root.AbsoluteSize.Y local narrow=width<600 local short=height<440
 local compact=height<390 and width<800 ui.compact=compact
 local statusWidth=compact and 208 or (narrow and 232 or 248)
 ui.status.Size=UDim2.fromOffset(statusWidth,compact and 36 or 44) ui.status.Position=UDim2.new(.5,-statusWidth/2,0,narrow and (compact and 64 or 74) or 12)
 ui.map.TextSize=compact and 16 or 17 ui.clock.TextSize=compact and 22 or 23
 ui.map.Position=UDim2.fromOffset(26,compact and 0 or 3) ui.phase.Position=UDim2.fromOffset(26,compact and 21 or 26)
 ui.clock.Position=UDim2.new(1,-87,0,compact and 1 or 6) ui.accent.Position=UDim2.fromOffset(13,compact and 7 or 12)
 ui.launcher.Size=UDim2.fromOffset(compact and 68 or (narrow and 88 or 104),compact and 28 or 32) ui.launcher.Position=UDim2.fromOffset(14,narrow and 12 or 70)
 local balanceWidth=compact and 132 or (narrow and 142 or 156)
 ui.balance.Size=UDim2.fromOffset(balanceWidth,compact and 44 or 55) ui.balance.Position=UDim2.new(1,-balanceWidth-14,0,12)
 rankButton.Size=UDim2.fromOffset(balanceWidth,30) rankButton.Position=UDim2.new(1,-balanceWidth-14,0,compact and 64 or 77)
 ui.level.Position=UDim2.fromOffset(11,compact and 2 or 5) ui.coins.Position=UDim2.new(1,-71,0,compact and 2 or 5)
 ui.xpText.Position=UDim2.fromOffset(11,compact and 22 or 28) ui.xpText.TextSize=compact and 10 or 11
 local railHeight=math.clamp(height*.35,130,252)
 ui.rail.Size=UDim2.fromOffset(46,railHeight) ui.rail.Position=UDim2.new(0,narrow and 8 or 14,.5,-railHeight/2)
 local bottom=(UserInputService.TouchEnabled and narrow) and 161 or 68
 local abilityWidth=compact and 156 or 196
 ui.abilities.Size=UDim2.fromOffset(abilityWidth,compact and 48 or 54) ui.abilities.Position=UDim2.new(.5,-abilityWidth/2,1,-bottom)
 ui.updraft.key.Position=UDim2.fromOffset(11,compact and 8 or 11)
 ui.updraft.title.Position=UDim2.fromOffset(compact and 44 or 50,compact and 4 or 8) ui.updraft.title.Size=UDim2.fromOffset(compact and 104 or 135,21)
 ui.updraft.cooldown.Position=UDim2.fromOffset(compact and 44 or 50,compact and 25 or 29) ui.updraft.cooldown.Size=UDim2.fromOffset(compact and 104 or 135,16)
 ui.run.Size=UDim2.fromOffset(compact and 120 or 200,compact and 16 or 18) ui.run.Position=UDim2.new(.5,compact and -60 or -100,1,-bottom-24)
 restartButton.Size=UDim2.fromOffset(compact and 130 or 140,UserInputService.TouchEnabled and 44 or 38)
 local resetBottom=UserInputService.TouchEnabled and 219 or 52
 restartButton.Position=UDim2.new(0,14,1,-resetBottom)
 ui.resetHint.Position=UDim2.new(0,14,1,-resetBottom-21)
 local drawerWidth,drawerHeight=math.min(440,width-24),math.min(570,height-24)
 modal.Size=UDim2.fromOffset(drawerWidth,drawerHeight) ui.drawerPosition=UDim2.new(1,-drawerWidth-12,.5,-drawerHeight/2) modal.Position=ui.drawerPosition
 local dialogueWidth=math.min(620,width-24) local showPortrait=dialogueWidth>=520
 local dialogueHeight=showPortrait and 218 or (short and 224 or 258)
 ui.dialogue.Size=UDim2.fromOffset(dialogueWidth,dialogueHeight) ui.dialogue.Position=UDim2.new(.5,-dialogueWidth/2,1,-dialogueHeight-18)
 ui.dialoguePortrait.Visible=showPortrait ui.dialoguePortrait.Size=UDim2.fromOffset(112,142)
 local dialogueLeft=showPortrait and 142 or 20
 ui.dialogueSpeaker.Position=UDim2.fromOffset(dialogueLeft,14) ui.dialogueSpeaker.Size=UDim2.new(1,-dialogueLeft-50,0,28)
 ui.dialogueRole.Position=UDim2.fromOffset(dialogueLeft,43) ui.dialogueRole.Size=UDim2.new(1,-dialogueLeft-28,0,18)
 ui.dialogueText.Position=UDim2.fromOffset(dialogueLeft,70) ui.dialogueText.Size=UDim2.new(1,-dialogueLeft-22,0,dialogueHeight-145)
 ui.dialogueText.TextSize=short and 14 or (showPortrait and 17 or 16)
 ui.dialogueHint.Position=UDim2.new(0,dialogueLeft,1,-72) ui.dialogueHint.Size=UDim2.new(1,-dialogueLeft-22,0,17)
 for _,choice in ipairs(ui.dialogueButtons) do choice.TextSize=dialogueWidth<420 and 11 or 13 end
 ui.modalTitle.TextSize=22 ui.modalSubtitle.TextSize=13
 local toastWidth=math.min(410,width-24) ui.toast.Size=UDim2.fromOffset(toastWidth,40) ui.toast.Position=UDim2.new(.5,-toastWidth/2,0,narrow and 126 or 114)
 local voteWidth=math.min(468,width-24) ui.vote.Size=UDim2.fromOffset(voteWidth,128) ui.vote.Position=UDim2.new(.5,-voteWidth/2,1,-145)
 ui.voteChoices.Size=UDim2.new(1,-20,0,80) ui.voteChoices.Position=UDim2.fromOffset(10,39)
 local resultWidth=math.min(376,width-24) ui.result.Size=UDim2.fromOffset(resultWidth,108) ui.result.Position=UDim2.new(.5,-resultWidth/2,.5,-54)
 local specWidth=math.min(324,width-24) ui.spectator.Size=UDim2.fromOffset(specWidth,48) ui.spectator.Position=UDim2.new(.5,-specWidth/2,1,-66)
 accelerateButton.Position=UDim2.new(.5,7,0,narrow and 129 or 72) ui.watch.Position=UDim2.new(.5,-155,0,narrow and 129 or 72)
 local hintWidth=math.min(320,width-24) ui.onboarding.Size=UDim2.fromOffset(hintWidth,46) ui.onboarding.Position=UDim2.new(.5,-hintWidth/2,0,narrow and 132 or 76)
 ui.onboardTitle.TextSize=narrow and 14 or 16 ui.onboardText.TextSize=12
 updateInputHints()
 if short then ui.rail.Visible=false end
end
table.insert(connections,root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)) layout()
local cameraCheckAt,previewPaintAt=0,0
RunService:BindToRenderStep("DasherPresentation",Enum.RenderPriority.Camera.Value+1,function(dt)
 local now=os.clock() local serverNow=workspace:GetServerTimeNow() local phase=snapshot.phase
 if spectatorExitPending and snapshot.spectating and now-spectatorExitRequestAt>.75 then spectatorExitRequestAt=now Action:FireServer("Spectate",false) end
 local multiplier=phase=="Racing" and (snapshot.multiplier or 1) or 1
 local timeLeft=RoundClock.Remaining(snapshot,serverNow)
 ui.clock.Text=phase=="Waiting" and "--:--" or timeText(math.ceil(timeLeft),false)
 ui.clock.TextColor3=phase=="Racing" and timeLeft<=20 and C.gold or C.text
 local altitude=snapshot.altitude or {} local total=math.max(1,altitude.totalStages or 8)
 if phase=="Racing" then
  ui.phase.Text=snapshot.finished and "FINISHED!" or (snapshot.finalSprint and "FINAL SPRINT" or string.format("STAGE %d / %d%s",math.clamp((altitude.stage or 0)+1,1,total),total,multiplier>1 and " / 1.5x" or ""))
 end
 local countdownText=RoundClock.Countdown(snapshot,serverNow)
 if phase=="Racing" and serverNow<countdownPresentation.goUntil then countdownText="GO" end
 if phase=="Countdown" and timeLeft<=3.05 and cinematic then restoreCamera() end
 ui.countdown.Visible=countdownText~="" and not menuOpen
 if countdownText~=countdownPresentation.text then
  countdownPresentation.text=countdownText ui.countdown.Text=countdownText
  ui.countdown.TextColor3=countdownText=="GO" and C.cyan or C.text
  ui.countdownScale.Scale=reducedMotion and 1 or 1.18
  TweenService:Create(ui.countdownScale,TweenInfo.new(reducedMotion and 0 or .22,Enum.EasingStyle.Quad),{Scale=1}):Play()
 end
 local enabled=phase=="Racing" and snapshot.racing and not snapshot.finished and not snapshot.spectating
 ui.abilities.Visible=enabled and not menuOpen and not cinematic ui.run.Visible=ui.abilities.Visible
 ui.rail.Visible=phase=="Racing" and not menuOpen and not cinematic and root.AbsoluteSize.Y>=390
 restartButton.Visible=enabled and not menuOpen and not cinematic and not dialogue.active
 local resetTriggered,resetProgress=ResetHold.Step(resetHold,now,resetEligible(false),player.Character)
 if resetTriggered then requestRestart(false) end
 ui.resetFill.Size=UDim2.fromScale(resetProgress,1)
 ui.resetTitle.Text=resetHold.triggered and "RESETTING" or (resetHold.active and "HOLD..." or "HOLD TO RESET")
 ui.resetTitle.TextColor3=resetHold.active and C.gold or C.muted
 ui.resetKey.TextColor3=resetHold.active and C.gold or C.muted
 ui.resetHint.Visible=restartButton.Visible and resetHold.active~=nil and not resetHold.triggered
 ui.vote.Visible=phase=="Intermission" and #(snapshot.voteOptions or {})>0 and not menuOpen and not cinematic and not dialogue.active
 ui.spectator.Visible=spectateTarget~=nil and not menuOpen
 rankButton.Visible=phase=="Racing" and not menuOpen and not cinematic and root.AbsoluteSize.X>=600
 ui.onboarding.Visible=(phase=="Waiting" or phase=="Intermission") and not menuOpen and not cinematic and not dialogue.active
 if dialogue.active then
  local active=dialogue.active
  local rootPart=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if not dialogueAllowed(snapshot) or not active.part.Parent or not rootPart or not humanoid or humanoid.Health<=0 or (rootPart.Position-active.part.Position).Magnitude>15 then closeDialogue()
  else
   if ui.dialogueText.MaxVisibleGraphemes>=0 then
    local count=math.floor((now-active.revealAt)*45)
    ui.dialogueText.MaxVisibleGraphemes=count>=active.graphemes and -1 or count
   end
   ui.dialogueHint.Text=ui.dialogueText.MaxVisibleGraphemes<0 and "Choose a reply below" or "Tap the words to reveal"
  end
 end
 if now-dialogue.lastPoseAt>=.05 then
  dialogue.lastPoseAt=now
  local rootPart=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  for part,rig in pairs(dialogue.rigs) do
   if not part.Parent then dialogue.rigs[part]=nil
   elseif rootPart and (rootPart.Position-part.Position).Magnitude<45 then
    local talking=dialogue.active and dialogue.active.part==part
    local target=(talking or (rootPart.Position-part.Position).Magnitude<12) and (rootPart.Position+Vector3.new(0,1.5,0)) or nil
    poseNPCRig(rig,now,target,talking)
   end
  end
  if dialogue.portraitRig and dialogue.active then poseNPCRig(dialogue.portraitRig,now,nil,true) end
 end
 local ability=snapshot.abilities or {}
 local cooldown=Config.UpdraftCooldown or 3.25
 local ready,charge,remaining=abilityReadiness(ability,serverNow,lastSkillApplied.Updraft,cooldown)
 local caption=ready and "READY" or (remaining>0 and string.format("%.1f s",remaining) or "TOUCH DOWN TO REARM")
 if now-skillRequests.Updraft<.5 then caption="Lifting..." end
 ui.updraft.cooldown.Text=caption ui.updraft.title.TextColor3=ready and C.text or C.muted
 ui.updraft.cooldown.TextSize=remaining<=0 and not ready and 10 or 12
 ui.updraft.key.BackgroundColor3=ready and C.cyan or C.card ui.updraft.key.TextColor3=ready and C.ink or C.muted
 ui.updraft.bar.Size=UDim2.new(charge,-20*charge,0,2) ui.updraft.bar.BackgroundColor3=ready and C.cyan or C.border
 if menuOpen and now-previewPaintAt>.04 then
  previewPaintAt=now
  local scrollTop,scrollBottom=scroll.AbsolutePosition.Y,scroll.AbsolutePosition.Y+scroll.AbsoluteSize.Y
  for _,entry in ipairs(previewParticles) do
   local holder=entry.holder
   if holder.Parent and holder.AbsolutePosition.Y+holder.AbsoluteSize.Y>scrollTop and holder.AbsolutePosition.Y<scrollBottom then
    local style=entry.style local age=reducedMotion and entry.phase or (entry.phase+now/(style.life*2.8))%1
    local drift=style.accel.Y*.006*age*age
    entry.image.Position=UDim2.fromScale(.72-age*.67,.52+math.sin(entry.phase*15+age*4)*.18-drift)
    entry.image.ImageTransparency=style.mist and (.7+age*.29) or (.12+age^1.7*.85)
    entry.image.Rotation=entry.phase*360+age*style.spin
    local size=math.clamp(style.size*28,5,28)*(style.mist and (1+age*.6) or (1-age*.55))
    entry.image.Size=UDim2.fromOffset(size/(1+style.squash*.35),size)
    if style.rainbow then entry.image.ImageColor3=Color3.fromHSV((entry.phase+age*.25)%1,.38,1) end
   end
  end
 end
 local progress=math.clamp(tonumber(snapshot.progress) or 0,0,1) local displayHeight=tonumber(altitude.current) or 0
 if enabled then
  local character=player.Character local rootPart=character and character:FindFirstChild("HumanoidRootPart")
  local map=workspace:FindFirstChild("ActiveMap") local start=map and map:FindFirstChild("Start",true) local height=tonumber(altitude.height) or 0
  if rootPart and start and start:IsA("BasePart") and height>0 then displayHeight=math.clamp(rootPart.Position.Y-start.Position.Y,0,height) progress=displayHeight/height end
 end
 ui.selfDot.Position=UDim2.new(.5,0,1-progress,0) ui.railFill.Size=UDim2.fromScale(1,progress) ui.height.Text=tostring(math.floor(displayHeight))
 for index,mark in ipairs(ui.stageMarks) do mark.number.TextColor3=(altitude.stage or 0)>=index and C.cyan or C.muted end
 if enabled and type(snapshot.runStartedAt)=="number" then
  ui.run.Text=timeText(serverNow-snapshot.runStartedAt,true)..(root.AbsoluteSize.Y<390 and string.format(" / %d%%",math.floor(progress*100)) or "")
 end
 local camera=workspace.CurrentCamera
 if camera~=lastCamera then
  if lastCamera and lastCamera.Parent then lastCamera.FieldOfView=math.clamp(lastCamera.FieldOfView-cameraOffsetApplied,1,120) end
  cameraOffsetApplied=0 lastCamera=camera
 end
 if camera then
  if dialogue.active and not reducedMotion then
   local active=dialogue.active local part=active.part
   local focus=part.CFrame:PointToWorldSpace(Vector3.new(0,1.5,0))
   local shot=CFrame.lookAt(part.CFrame:PointToWorldSpace(Vector3.new(2.1,2,8)),focus)
   local alpha=math.clamp((now-active.started)/.6,0,1) alpha=alpha*alpha*(3-2*alpha)
   camera.CameraType=Enum.CameraType.Scriptable camera.CFrame=active.cameraFrame:Lerp(shot,alpha) camera.Focus=CFrame.new(focus)
  elseif cinematic then
   local frame=cinematic local alpha=math.clamp((now-frame.started)/frame.duration,0,1) local eased=alpha*alpha*(3-2*alpha)
   camera.CameraType=Enum.CameraType.Scriptable
   local shot=CFrame.lookAt(frame.from:Lerp(frame.to,eased),frame.lookAt)
   local focus=frame.lookAt
   local rootPart=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   if rootPart and alpha>.72 then
    local forward=Vector3.new(rootPart.CFrame.LookVector.X,0,rootPart.CFrame.LookVector.Z)
    forward=forward.Magnitude>.01 and forward.Unit or Vector3.new(0,0,-1)
    local targetFocus=rootPart.Position+Vector3.new(0,2,0)
    local target=CFrame.lookAt(rootPart.Position-forward*18+Vector3.new(0,9,0),targetFocus)
    local handoff=math.clamp((alpha-.72)/.28,0,1) handoff=handoff*handoff*(3-2*handoff)
    shot=shot:Lerp(target,handoff) focus=focus:Lerp(targetFocus,handoff)
   end
   local position=shot.Position
   if frame.guard then position=mapIntroCamera.position(frame.guard,position,focus,frame.lastPosition) end
   if frame.guard and not position then restoreCamera()
   else
    if frame.guard then frame.lastPosition=position shot=CFrame.lookAt(position,focus) end
    camera.CFrame=shot camera.Focus=CFrame.new(focus)
    if alpha>=1 then restoreCamera() end
   end
  elseif spectateTarget and now-cameraCheckAt>.25 then
   cameraCheckAt=now local character=spectateTarget.Character local humanoid=character and character:FindFirstChildOfClass("Humanoid")
   local eligible=false for _,racer in ipairs(snapshot.racers or {}) do if racer.userId==spectateTarget.UserId and not racer.finished then eligible=true break end end
   if not humanoid or humanoid.Health<=0 or not eligible then setSpectate(1) else camera.CameraType=Enum.CameraType.Custom camera.CameraSubject=humanoid end
  end
  local baseFov=camera.FieldOfView-cameraOffsetApplied cameraKick*=math.exp(-dt*12)
  cameraOffsetApplied=(reducedMotion or cinematic or dialogue.active or spectateTarget) and 0 or cameraKick camera.FieldOfView=math.clamp(baseFov+cameraOffsetApplied,1,120)
 end
end)
-- Authored NPCs expose contextual pages without a permanent row of shop GUIs.
-- Existing StationPrompt objects are reused, so a merchant never has two prompts.
local function bindStation(part)
 if not part or not part:IsA("BasePart") or stationBindings[part] then return end
 local station=part:FindFirstChild("MenuPage")
 local page=(station and station:IsA("StringValue")) and station.Value or part.Name
 if not ({Shop=true,Inventory=true,Quests=true,Leaderboard=true})[page] then return end
 stationBindings[part]=true
 if part.Parent:IsA("Model") then dialogue.rigs[part]=captureNPCRig(part.Parent,part) end
 local name=part:FindFirstChild("NPCName")
 local prompt=part:FindFirstChildWhichIsA("ProximityPrompt")
 if not prompt then
  prompt=make("ProximityPrompt",part,{Name="DasherMenuPrompt",ActionText="Talk",ObjectText=name and name.Value or page,KeyboardKeyCode=Enum.KeyCode.E,GamepadKeyCode=Enum.KeyCode.ButtonX,HoldDuration=0,MaxActivationDistance=10,RequiresLineOfSight=false})
 end
 prompt.ActionText="Talk"
 table.insert(connections,prompt.Triggered:Connect(function(person)
  if not person or person==player then openDialogue(part) end
 end))
end
task.spawn(function()
 local lobby=workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("DasherLobby") or workspace:WaitForChild("Lobby",15)
 if not lobby then return end
 for _,item in ipairs(lobby:GetDescendants()) do if item:IsA("BasePart") then bindStation(item) end end
 table.insert(connections,lobby.DescendantAdded:Connect(function(item)
  if item:IsA("BasePart") then task.defer(bindStation,item)
  elseif item.Name=="MenuPage" then task.defer(bindStation,item.Parent) end
  if item.Name=="LobbyTint" then lobbyThemeId=nil task.defer(applyLobbyTheme) end
 end))
 applyLobbyTheme()
end)

task.spawn(function()
 for _=1,8 do local ok=pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end) if ok then break end task.wait(0.25) end
end)
player:SetAttribute("DasherClientReady",true) Action:FireServer("Ready")
task.delay(1.2,function() if gui.Parent and snapshot.phase=="Waiting" then Action:FireServer("Ready") end end)
task.delay(3,function() if gui.Parent and not introPlayed then playLobbyIntro() end end)
script.Destroying:Connect(function()
 cancelResetHold()
 pcall(function() StarterGui:SetCore("ResetButtonCallback",true) end)
 closeDialogue(true)
 for _,rig in pairs(dialogue.rigs) do for _,entry in ipairs(rig.parts) do if entry.part.Parent and rig.root.Parent then entry.part.CFrame=rig.root.CFrame*entry.base end end end
  restoreCamera()
 for character in pairs(effects) do endEffect(character) end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 for _,connection in ipairs(characterConnections) do connection:Disconnect() end
 RunService:UnbindFromRenderStep("DasherPresentation")
 for _,name in ipairs({"DasherUpdraft","DasherRestart","DasherMenu","DasherSpectate"}) do ContextActionService:UnbindAction(name) end
 for person in pairs(cosmeticBindings) do unbindCosmeticPlayer(person) end
 skillFxFolder:Destroy() liftSound:Destroy() finishSound:Destroy() audioGroup:Destroy() gui:Destroy()
end)
