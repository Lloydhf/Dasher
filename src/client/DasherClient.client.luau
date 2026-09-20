-- Dasher 0.2: compact presentation; rewards and eligibility are server authoritative.
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
local remotes = package:WaitForChild("Remotes")
local Action, State, Feedback, DashFX = remotes:WaitForChild("Action"), remotes:WaitForChild("State"), remotes:WaitForChild("Feedback"), remotes:WaitForChild("DashFX")
local C = {ink=Color3.fromRGB(13,16,22), panel=Color3.fromRGB(23,28,36), card=Color3.fromRGB(33,40,49), border=Color3.fromRGB(70,86,99), text=Color3.fromRGB(242,242,233), muted=Color3.fromRGB(168,184,195), cyan=Color3.fromRGB(96,230,221), gold=Color3.fromRGB(247,202,113), red=Color3.fromRGB(250,129,138), green=Color3.fromRGB(147,235,184)}
local regularFont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local strongFont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local snapshot = {phase="Waiting",coins=0,owned={ice=true},equipped="ice",progress=0,finishers={},racers={}}
local receivedAt = os.clock()
local reducedMotion, muted, menuOpen = false, false, false
local menuPage = "Home"
local localDashAt, lastRestartAt = -100, -100
local activeDash, lastFinished, lastCamera = nil, nil, nil
local cinematic, spectateTarget = nil, nil
local introPlayed = false
local cameraKick, cameraOffsetApplied, toastSerial, menuSerial = 0, 0, 0, 0
local effects, connections, characterConnections, shopButtons, questControls, voteButtons = {}, {}, {}, {}, {}, {}
local ui = {}
local openMenu, closeMenu, restoreCamera, setSpectate, renderVotes
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
 local item=make("TextButton",parent,{Size=size,Position=position,Text=text,TextSize=16,FontFace=strongFont,TextColor3=color and C.ink or C.text,BackgroundColor3=color or C.panel,BorderSizePixel=0,AutoButtonColor=false,Selectable=true})
 round(item,9) local outline=stroke(item,color or C.border,color and 0.8 or 0.45)
 local function hover(active)
  if not item.Parent then return end
  TweenService:Create(outline,TweenInfo.new(reducedMotion and 0 or 0.13),{Transparency=active and 0.08 or 0.6}):Play()
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
ui.launcher=button(root,"MENU / TAB",UDim2.fromOffset(116,38),UDim2.fromOffset(14,12))
ui.status=panel(root,"RoundStatus",UDim2.fromOffset(328,52),UDim2.new(0.5,-164,0,12))
ui.accent=make("Frame",ui.status,{Size=UDim2.fromOffset(3,26),Position=UDim2.fromOffset(13,13),BackgroundColor3=C.cyan,BorderSizePixel=0}) round(ui.accent,2)
ui.map=label(ui.status,"DASHER",UDim2.new(1,-111,0,23),UDim2.fromOffset(26,5),17,C.text,true)
ui.phase=label(ui.status,"WELCOME",UDim2.new(1,-111,0,18),UDim2.fromOffset(26,29),13,C.muted)
ui.clock=label(ui.status,"--:--",UDim2.fromOffset(73,34),UDim2.new(1,-88,0,9),23,C.text,true) ui.clock.TextXAlignment=Enum.TextXAlignment.Right
ui.balance=panel(root,"Balance",UDim2.fromOffset(126,42),UDim2.new(1,-140,0,12))
ui.coins=label(ui.balance,"0",UDim2.new(1,-24,0,23),UDim2.fromOffset(12,2),18,C.gold,true)
ui.level=label(ui.balance,"LEVEL 1",UDim2.new(1,-24,0,15),UDim2.fromOffset(12,25),12,C.muted)
ui.energy=panel(root,"DashEnergy",UDim2.fromOffset(258,62),UDim2.new(0.5,-129,1,-76))
ui.run=label(ui.energy,"FIND YOUR LINE",UDim2.new(1,-82,0,19),UDim2.fromOffset(12,5),14,C.muted)
ui.progress=label(ui.energy,"0%",UDim2.fromOffset(52,19),UDim2.new(1,-64,0,5),14,C.cyan,true) ui.progress.TextXAlignment=Enum.TextXAlignment.Right
ui.dash=label(ui.energy,"DASH READY",UDim2.new(1,-90,0,20),UDim2.fromOffset(12,26),15,C.text,true)
ui.key=label(ui.energy,"Q / SHIFT",UDim2.fromOffset(78,20),UDim2.new(1,-90,0,26),12,C.muted) ui.key.TextXAlignment=Enum.TextXAlignment.Right
local track=make("Frame",ui.energy,{Size=UDim2.new(1,-24,0,3),Position=UDim2.new(0,12,1,-8),BackgroundColor3=C.card,BorderSizePixel=0}) round(track,3)
ui.charge=make("Frame",track,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.cyan,BorderSizePixel=0}) round(ui.charge,3)
local restartButton=button(root,"RESET R",UDim2.fromOffset(90,32),UDim2.new(0,14,1,-46)) restartButton.TextSize=14
local touchDash=button(root,"DASH",UDim2.fromOffset(70,58),UDim2.new(1,-90,1,-202),C.cyan) touchDash.Visible=UserInputService.TouchEnabled
local accelerateButton=button(root,"BOOST CLOCK",UDim2.fromOffset(148,36),UDim2.new(0.5,7,0,78),C.gold) accelerateButton.Visible=false
ui.watch=button(root,"WATCH RACE",UDim2.fromOffset(148,36),UDim2.new(0.5,-155,0,78)) ui.watch.Visible=false
ui.countdown=center(label(root,"",UDim2.fromOffset(240,96),UDim2.new(0.5,-120,0.35,-48),64,C.text,true)) ui.countdown.Visible=false
ui.toast=panel(root,"Toast",UDim2.fromOffset(420,44),UDim2.new(0.5,-210,0,132)) ui.toast.Visible=false ui.toast.ZIndex=60
ui.toastText=wrap(center(label(ui.toast,"",UDim2.new(1,-24,1,-8),UDim2.fromOffset(12,4),15,C.text,true))) ui.toastText.ZIndex=61
ui.vote=panel(root,"MapVote",UDim2.fromOffset(486,138),UDim2.new(0.5,-243,1,-162)) ui.vote.Visible=false
ui.voteTitle=label(ui.vote,"PICK THE NEXT COURSE",UDim2.new(1,-28,0,26),UDim2.fromOffset(14,7),15,C.text,true)
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
ui.resultClose=button(ui.result,"X",UDim2.fromOffset(28,28),UDim2.new(1,-40,0,8))
ui.skip=button(root,"SKIP INTRO",UDim2.fromOffset(116,32),UDim2.new(0.5,-58,1,-58)) ui.skip.Visible=false ui.skip.ZIndex=25 ui.skip.TextSize=14
local scrim=make("TextButton",root,{Name="ModalScrim",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.35,BorderSizePixel=0,Text="",AutoButtonColor=false,Visible=false,ZIndex=30,Selectable=false})
local modal=make("CanvasGroup",root,{Name="Menu",Size=UDim2.fromOffset(608,486),Position=UDim2.new(0.5,-304,0.5,-243),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=31,Visible=false}) round(modal,16) stroke(modal)
ui.modalTitle=label(modal,"DASHER",UDim2.new(1,-86,0,30),UDim2.fromOffset(22,16),24,C.text,true)
ui.modalSubtitle=label(modal,"",UDim2.new(1,-44,0,25),UDim2.fromOffset(22,48),15,C.muted)
ui.close=button(modal,"X",UDim2.fromOffset(34,34),UDim2.new(1,-52,0,17))
local navigation=make("ScrollingFrame",modal,{Name="Navigation",Size=UDim2.new(1,-36,0,39),Position=UDim2.fromOffset(18,80),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X})
make("UIListLayout",navigation,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
local scroll=make("ScrollingFrame",modal,{Name="Content",Size=UDim2.new(1,-32,1,-137),Position=UDim2.fromOffset(16,129),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.muted,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y})
make("UIListLayout",scroll,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
make("UIPadding",scroll,{PaddingLeft=UDim.new(0,3),PaddingRight=UDim.new(0,7),PaddingBottom=UDim.new(0,10)})
local audioGroup=make("SoundGroup",SoundService,{Name="DasherLocalAudio",Volume=1})
local dashSound=make("Sound",SoundService,{Name="DasherDash",SoundId="rbxasset://sounds/action_jump.mp3",Volume=0.18,PlaybackSpeed=1.75,SoundGroup=audioGroup})
local finishSound=make("Sound",SoundService,{Name="DasherFinish",SoundId="rbxasset://sounds/volume_slider.ogg",Volume=0.3,PlaybackSpeed=1.1,SoundGroup=audioGroup})
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
local function updateQuestControls()
 local p=snapshot.progression or {}
 if questControls.daily then questControls.daily.Text=p.dailyAvailable and "CLAIM" or "CLAIMED" end
 if questControls.weekly then questControls.weekly.Text=p.weeklyClaimed and "CLAIMED" or ((p.weeklyProgress or 0)>=(p.weeklyTarget or 10) and "CLAIM" or "IN PROGRESS") end
 if questControls.progress then questControls.progress.Text=string.format("Finish %d courses  /  %d of %d",p.weeklyTarget or 10,p.weeklyProgress or 0,p.weeklyTarget or 10) end
end
restoreCamera=function()
 cinematic=nil spectateTarget=nil cameraKick=0 ui.skip.Visible=false ui.spectator.Visible=false
 local camera=workspace.CurrentCamera
 if camera then
  if camera==lastCamera then camera.FieldOfView=math.clamp(camera.FieldOfView-cameraOffsetApplied,1,120) end
  cameraOffsetApplied=0 camera.CameraType=Enum.CameraType.Custom
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if humanoid then camera.CameraSubject=humanoid end
 end
end
local function beginCinematic(from,to,lookAt,duration)
 if reducedMotion or menuOpen or snapshot.phase=="Racing" or not workspace.CurrentCamera then return end
 restoreCamera() cinematic={from=from,to=to,lookAt=lookAt,started=os.clock(),duration=duration}
 workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable ui.skip.Visible=true
end
local function playLobbyIntro()
 if introPlayed or snapshot.phase=="Racing" or snapshot.phase=="Countdown" then return end
 local lobby=workspace:FindFirstChild("Lobby")
 local start=lobby and lobby:FindFirstChild("CameraStart",true)
 local finish=lobby and lobby:FindFirstChild("CameraEnd",true)
 local look=lobby and lobby:FindFirstChild("CameraLookAt",true)
 if start and finish and look and start:IsA("BasePart") and finish:IsA("BasePart") and look:IsA("BasePart") then introPlayed=true beginCinematic(start.Position,finish.Position,look.Position,2.8) end
end
local function playMapIntro(roundId)
 task.spawn(function()
  local map=workspace:FindFirstChild("ActiveMap") local start=map and map:FindFirstChild("Start",true)
  for _=1,12 do
   if start or snapshot.phase~="Countdown" or snapshot.roundId~=roundId then break end
   task.wait(0.1) map=workspace:FindFirstChild("ActiveMap") start=map and map:FindFirstChild("Start",true)
  end
  if snapshot.phase~="Countdown" or snapshot.roundId~=roundId or not start or not start:IsA("BasePart") then return end
  local forward=start.CFrame.LookVector local finish=map:FindFirstChild("Finish",true)
  if finish and finish:IsA("BasePart") then local delta=finish.Position-start.Position if delta.Magnitude>1 then forward=delta.Unit end end
  beginCinematic(start.Position-forward*24+Vector3.new(0,22,0),start.Position-forward*12+Vector3.new(0,9,0),start.Position+forward*40,math.min(2.3,math.max(0.8,(snapshot.timeLeft or 4)-0.7)))
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
 if #candidates==0 then Action:FireServer("Spectate",false) restoreCamera() showToast("No runners to watch right now.",C.muted) return end
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
  TweenService:Create(modal,TweenInfo.new(0.12),{GroupTransparency=1}):Play()
  task.delay(0.13,function() if serial==menuSerial then modal.Visible=false scrim.Visible=false end end)
 end
end
openMenu=function(page)
 if cinematic then restoreCamera() end
 menuSerial+=1 menuOpen=true menuPage=page or "Home" shopButtons={} questControls={}
 for _,item in ipairs(scroll:GetChildren()) do if item:IsA("GuiObject") then item:Destroy() end end
 scroll.CanvasPosition=Vector2.zero modal.Visible=true scrim.Visible=true modal.GroupTransparency=reducedMotion and 0 or 1
 TweenService:Create(modal,TweenInfo.new(reducedMotion and 0 or 0.18),{GroupTransparency=0}):Play()
 ui.modalTitle.Text=string.upper(menuPage) ui.modalSubtitle.Text="Find your line. Make it count."
 if menuPage=="Shop" or menuPage=="Inventory" then
  ui.modalTitle.Text=menuPage=="Shop" and "THE TRAIL COLLECTION" or "YOUR LOCKER"
  ui.modalSubtitle.Text=menuPage=="Shop" and "All style. Every runner has the same movement." or "Choose the signature you leave behind."
  local count=0
  for _,cosmetic in ipairs(Config.Cosmetics) do
   if menuPage=="Shop" or (snapshot.owned and snapshot.owned[cosmetic.id]) then
    count+=1 local card=menuCard(77,count)
    local swatch=make("Frame",card,{Size=UDim2.fromOffset(7,37),Position=UDim2.fromOffset(17,20),BackgroundColor3=cosmetic.color,BorderSizePixel=0,Rotation=18}) round(swatch,4)
    label(card,cosmetic.name,UDim2.new(1,-182,0,25),UDim2.fromOffset(39,13),18,C.text,true)
    label(card,cosmetic.rarity or "Dash trail",UDim2.new(1,-182,0,20),UDim2.fromOffset(39,41),14,C.muted)
    local buy=button(card,"",UDim2.fromOffset(127,37),UDim2.new(1,-140,0,20)) buy.TextSize=14
    shopButtons[cosmetic.id]={button=buy,price=cosmetic.price}
    buy.Activated:Connect(function()
     if snapshot.equipped==cosmetic.id then return end
     if snapshot.owned and snapshot.owned[cosmetic.id] then Action:FireServer("Equip",cosmetic.id)
     elseif (snapshot.coins or 0)>=cosmetic.price then Action:FireServer("Buy",cosmetic.id)
     else showToast("Race and complete quests to earn more coins.",C.gold) end
    end) setModalLayer(card)
   end
  end updateShopButtons()
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
   local title,body="SET THE FIRST SCORE","Finish a course to put your name on the board. Rankings refresh periodically."
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
  local motion=textCard("REDUCED MOTION","Skips flyovers and dash zoom. Shortens trails.",1,105)
  for _,item in ipairs(motion:GetChildren()) do if item:IsA("TextLabel") then item.Size=UDim2.new(1,-130,item.Size.Y.Scale,item.Size.Y.Offset) end end
  local toggle=button(motion,reducedMotion and "ON" or "OFF",UDim2.fromOffset(83,36),UDim2.new(1,-97,0,34))
  toggle.Activated:Connect(function() reducedMotion=not reducedMotion toggle.Text=reducedMotion and "ON" or "OFF" if reducedMotion then cameraKick=0 if cinematic then restoreCamera() end end end) setModalLayer(motion)
  local sound=textCard("SOUND EFFECTS","Soft feedback for dashes and finishes.",2,105)
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
   yes.Activated:Connect(function() Action:FireServer("Spectate",true) closeMenu() end) no.Activated:Connect(closeMenu) setModalLayer(card)
  else
   if snapshot.forfeited then textCard("BACK NEXT ROUND","This round was forfeited. You can watch the remaining runners and race again next round.",1,100) end
   local card=menuCard(64,2) local watch=button(card,"WATCH RUNNERS",UDim2.new(1,-24,0,40),UDim2.fromOffset(12,12),C.cyan)
   watch.Activated:Connect(function() Action:FireServer("Spectate",true) closeMenu() end) setModalLayer(card)
  end
 elseif menuPage=="Help" then
  ui.modalSubtitle.Text="Precision first. One dash charge. No checkpoints."
  textCard("01 / MOVE, JUMP, DASH","WASD + Space. Q / Shift to dash. Controller: A to jump, X to dash. Touch: use the dash button.",1,110)
  textCard("02 / PLAN YOUR NEXT LANDING","Your dash refills in "..tostring(Config.DashCooldown).." seconds. Rest on safe landings; follow the marked route to the finish.",2,110)
  textCard("03 / FALL, LEARN, REPEAT","Every fall sends you to the course start. R / controller Y resets. Your run timer keeps going.",3,105)
  textCard("04 / RACE TOGETHER","Vote between rounds. Finish for coins and weekly score. The first finisher can boost the clock; watch the others through the menu.",4,122)
 else
  local p=snapshot.progression or {} ui.modalTitle.Text="DASHER" ui.modalSubtitle.Text="Level "..tostring(p.level or 1).."  /  "..coinText(snapshot.coins).." coins"
  textCard("FIND YOUR LINE","Five longer courses. One charge. No checkpoints. Finish clean, refine your route, and climb the weekly board.",1,110)
  local shortcuts={{"YOUR LOCKER","Inventory"},{"TRAIL COLLECTION","Shop"},{"DAILY & WEEKLY","Quests"},{snapshot.phase=="Racing" and "WATCH THE RACE" or "WEEKLY LEADERS","Watch"}}
  for index,item in ipairs(shortcuts) do
   local card=menuCard(53,index+1) local key=(item[2]=="Watch" and snapshot.phase~="Racing") and "Leaderboard" or item[2]
   local shortcut=button(card,item[1].."  >",UDim2.new(1,-16,0,37),UDim2.fromOffset(8,8)) shortcut.TextXAlignment=Enum.TextXAlignment.Left
   make("UIPadding",shortcut,{PaddingLeft=UDim.new(0,12)}) shortcut.Activated:Connect(function() openMenu(key) end) setModalLayer(card)
  end
 end
 for _,tab in ipairs(navigation:GetChildren()) do if tab:IsA("TextButton") then tab.BackgroundColor3=tab.Name==menuPage and C.cyan or C.card tab.TextColor3=tab.Name==menuPage and C.ink or C.text end end
 setModalLayer(modal)
 if UserInputService.GamepadEnabled then GuiService.SelectedObject=ui.close end
end
for index,page in ipairs({"Home","Shop","Inventory","Quests","Leaderboard","Settings","Help"}) do
 local tab=button(navigation,page,UDim2.fromOffset(page=="Leaderboard" and 113 or 85,33),UDim2.fromOffset(0,0)) tab.Name=page tab.TextSize=14 tab.LayoutOrder=index
 tab.Activated:Connect(function() openMenu(page) end)
end
ui.launcher.Activated:Connect(function() if menuOpen then closeMenu() else openMenu("Home") end end)
ui.close.Activated:Connect(closeMenu) scrim.Activated:Connect(closeMenu) ui.skip.Activated:Connect(restoreCamera)
ui.watch.Activated:Connect(function() Action:FireServer("Spectate",true) end)
ui.previous.Activated:Connect(function() setSpectate(-1) end) ui.next.Activated:Connect(function() setSpectate(1) end)
ui.stopWatch.Activated:Connect(function() Action:FireServer("Spectate",false) restoreCamera() end)
ui.resultOpen.Activated:Connect(function() ui.result.Visible=false openMenu("Results") end)
ui.resultClose.Activated:Connect(function() ui.result.Visible=false end)
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
	if cinematic or spectateTarget or menuOpen or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
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
accelerateButton.Activated:Connect(function() if snapshot.canAccelerate then Action:FireServer("Accelerate") accelerateButton.Visible=false end end)
ContextActionService:BindAction("DasherDash",function(_,state)
 if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
 if menuOpen or snapshot.phase~="Racing" or not snapshot.racing or snapshot.finished or snapshot.spectating then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then tryDash() end
 return menuOpen and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.Q,Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonX)
ContextActionService:BindAction("DasherRestart",function(_,state)
 if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
 if menuOpen or snapshot.phase~="Racing" or not snapshot.racing or snapshot.finished or snapshot.spectating then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then tryRestart() end
 return menuOpen and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.R,Enum.KeyCode.ButtonY)
ContextActionService:BindAction("DasherMenu",function(_,state)
 if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then if menuOpen then closeMenu() else openMenu("Home") end end
 return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.Tab,Enum.KeyCode.H,Enum.KeyCode.ButtonSelect)
ContextActionService:BindAction("DasherSpectate",function(_,state,input)
 if state~=Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
 if input.KeyCode==Enum.KeyCode.ButtonB and menuOpen then closeMenu() return Enum.ContextActionResult.Sink end
 if not spectateTarget then return Enum.ContextActionResult.Pass end
 if input.KeyCode==Enum.KeyCode.ButtonB then Action:FireServer("Spectate",false) restoreCamera()
 else setSpectate(input.KeyCode==Enum.KeyCode.ButtonL1 and -1 or 1) end
 return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,Enum.KeyCode.ButtonB)
local function onCharacter(character)
 if snapshot.spectating then Action:FireServer("Spectate",false) end
 stopDash(true) restoreCamera()
 for _,connection in ipairs(characterConnections) do connection:Disconnect() end characterConnections={}
 localDashAt=-100
 task.spawn(function()
  local humanoid=character:WaitForChild("Humanoid",10)
  if not humanoid or character~=player.Character then return end
  restoreCamera()
  table.insert(characterConnections,humanoid.Died:Connect(function() stopDash(true) endEffect(character) restoreCamera() end))
 end)
end
table.insert(connections,player.CharacterAdded:Connect(onCharacter))
table.insert(connections,player.CharacterRemoving:Connect(function(character) stopDash(true) endEffect(character) restoreCamera() end))
if player.Character then onCharacter(player.Character) end
table.insert(connections,Players.PlayerRemoving:Connect(function(person) if person==spectateTarget then setSpectate(1) end end))
table.insert(connections,DashFX.OnClientEvent:Connect(function(person,direction)
 if person==player or typeof(person)~="Instance" or not person:IsA("Player") or typeof(direction)~="Vector3" then return end
 if person.Character then dashEffect(person.Character,direction,person:GetAttribute("EquippedTrail") or "ice") end
end))
table.insert(connections,Feedback.OnClientEvent:Connect(function(kind,message,extra)
 if kind=="DashDenied" then stopDash(true) if player.Character then endEffect(player.Character) end cameraKick=0
 elseif kind=="Reset" then stopDash(true) localDashAt=-100 if player.Character then endEffect(player.Character) end showToast(message~="" and message or "Back to the start. Find your line.",C.muted,1.5)
 elseif kind=="Finish" then
  stopDash(true) lastFinished=type(extra)=="table" and extra or nil
  if not muted then finishSound:Play() end
  showToast(lastFinished and string.format("FINISHED  %s  /  +%s COINS",timeText(lastFinished.time,true),coinText(lastFinished.coins)) or message,C.gold,4)
 elseif kind=="Error" then showToast(message,C.red)
 elseif kind=="Purchase" then showToast(message,C.gold)
 else showToast(message,C.text) end
end))
local function updateSnapshot(nextSnapshot)
 if type(nextSnapshot)~="table" then return end
 local previousPhase,previousRound,previousSpectating=snapshot.phase,snapshot.roundId,snapshot.spectating
 snapshot=nextSnapshot receivedAt=os.clock()
 if previousRound~=snapshot.roundId then lastFinished=nil localDashAt=-100 stopDash(true) restoreCamera() ui.result.Visible=false end
 if snapshot.phase~="Racing" or not snapshot.racing or snapshot.finished then stopDash(true) end
 if previousPhase~=snapshot.phase then
  restoreCamera()
  if snapshot.phase=="Countdown" then closeMenu() playMapIntro(snapshot.roundId)
  elseif snapshot.phase=="Results" then
   ui.result.Visible=true ui.resultTitle.Text=snapshot.finished and "COURSE COMPLETE" or "ROUND COMPLETE"
   local first=(snapshot.finishers or {})[1]
   ui.resultText.Text=first and ((first.name or "Runner").."  /  "..timeText(first.time,true)) or "Fresh course. Fresh start."
   local resultRound=snapshot.roundId task.delay(5,function() if snapshot.roundId==resultRound then ui.result.Visible=false end end)
  else ui.result.Visible=false if menuOpen and menuPage=="Results" then closeMenu() end end
 end
 if snapshot.phase=="Racing" and snapshot.spectating and not previousSpectating then setSpectate(0)
 elseif not snapshot.spectating and previousSpectating then restoreCamera() end
 local map=Config.Maps[snapshot.mapId]
 ui.map.Text=snapshot.mapName or (map and map.name) or "DASHER" ui.accent.BackgroundColor3=map and map.accent or C.cyan
 ui.phase.Text=({Waiting="WELCOME",Intermission="VOTE FOR A COURSE",Countdown="ON YOUR MARK",Racing="RACE IN PROGRESS",Results="ROUND COMPLETE"})[snapshot.phase] or "DASHER"
 ui.coins.Text=coinText(snapshot.coins).."  COINS"
 local p=snapshot.progression or {}
 ui.level.Text=snapshot.saveStatus=="error" and "SAVE UNAVAILABLE" or (snapshot.saveStatus=="loading" and "LOADING" or ("LEVEL "..tostring(p.level or 1)..(snapshot.saveStatus=="session" and " / STUDIO" or "")))
 ui.level.TextColor3=snapshot.saveStatus=="error" and C.red or C.muted
 accelerateButton.Visible=snapshot.canAccelerate==true and snapshot.phase=="Racing"
 ui.watch.Visible=snapshot.finished==true and snapshot.phase=="Racing" and not snapshot.spectating
 restartButton.Visible=snapshot.phase=="Racing" and snapshot.racing==true and not snapshot.finished
 ui.progress.Text=snapshot.finished and "DONE" or string.format("%d%%",math.floor(math.clamp(tonumber(snapshot.progress) or 0,0,1)*100))
 updateShopButtons() updateQuestControls() renderVotes()
 if snapshot.phase=="Intermission" then playLobbyIntro() end
end
table.insert(connections,State.OnClientEvent:Connect(updateSnapshot))
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
 local input=UserInputService:GetLastInputType()
 local gamepad=string.find(input.Name,"Gamepad")~=nil
 local touch=input==Enum.UserInputType.Touch or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
 ui.key.Text=gamepad and "X" or (touch and "TAP DASH" or "Q / SHIFT")
 ui.launcher.Text=gamepad and "MENU / VIEW" or (touch and "MENU" or "MENU / TAB")
 restartButton.Text=gamepad and "RESET Y" or (touch and "RESET" or "RESET R")
end
table.insert(connections,UserInputService.LastInputTypeChanged:Connect(updateInputHints)) updateInputHints()
local function layout()
 local width,height=root.AbsoluteSize.X,root.AbsoluteSize.Y local narrow=width<540
 local short=height<440
 ui.launcher.Size=UDim2.fromOffset(narrow and 96 or 116,38)
 ui.status.Size=UDim2.fromOffset(narrow and 256 or 328,52) ui.status.Position=UDim2.new(0.5,narrow and -128 or -164,0,narrow and 60 or 12)
 ui.map.TextSize=narrow and 15 or 17 ui.phase.TextSize=narrow and 12 or 13
 ui.energy.Size=UDim2.fromOffset(narrow and 222 or 258,62) ui.energy.Position=UDim2.new(0.5,narrow and -111 or -129,1,-76)
 ui.balance.Position=UDim2.new(1,-140,0,12)
 local mw,mh=math.min(608,width-20),math.min(510,height-24)
 modal.Size=UDim2.fromOffset(mw,mh) modal.Position=UDim2.new(0.5,-mw/2,0.5,-mh/2)
 ui.modalTitle.TextSize=narrow and 21 or 24
 local tw=math.min(420,width-24) ui.toast.Size=UDim2.fromOffset(tw,44) ui.toast.Position=UDim2.new(0.5,-tw/2,0,126)
 local vw=math.min(486,width-20) ui.vote.Size=UDim2.fromOffset(vw,138) ui.vote.Position=UDim2.new(0.5,-vw/2,1,-154)
 local rw=math.min(388,width-24) ui.result.Size=UDim2.fromOffset(rw,108) ui.result.Position=UDim2.new(0.5,-rw/2,0.5,-54)
 local sw=math.min(340,width-24) ui.spectator.Size=UDim2.fromOffset(sw,48) ui.spectator.Position=UDim2.new(0.5,-sw/2,1,-70)
 accelerateButton.Position=UDim2.new(0.5,7,0,narrow and 122 or 78) ui.watch.Position=UDim2.new(0.5,-155,0,narrow and 122 or 78)
 touchDash.Position=UDim2.new(1,-88,1,narrow and -235 or -194)
 restartButton.Position=UDim2.new(0,14,1,UserInputService.TouchEnabled and -188 or -46)
 ui.phase.Visible=not short
 ui.map.Position=UDim2.fromOffset(26,5)
 ui.clock.Position=UDim2.new(1,-88,0,9)
 ui.run.Position=UDim2.fromOffset(12,5) ui.progress.Position=UDim2.new(1,-64,0,5)
 ui.dash.Position=UDim2.fromOffset(12,26) ui.key.Position=UDim2.new(1,-90,0,26)
 ui.balance.Size=UDim2.fromOffset(126,42)
 restartButton.Size=UDim2.fromOffset(90,32) touchDash.Size=UDim2.fromOffset(70,58)
 if short then
  -- Short landscape keeps readable type by removing a secondary row, not scaling all text.
  ui.launcher.Size=UDim2.fromOffset(92,32)
  ui.status.Size=UDim2.fromOffset(220,38) ui.status.Position=UDim2.new(0.5,-110,0,narrow and 54 or 12)
  ui.map.Size=UDim2.new(1,-99,0,25) ui.map.Position=UDim2.fromOffset(20,6) ui.map.TextSize=15
  ui.accent.Size=UDim2.fromOffset(3,22) ui.accent.Position=UDim2.fromOffset(10,8)
  ui.clock.Position=UDim2.new(1,-79,0,2) ui.clock.Size=UDim2.fromOffset(69,34) ui.clock.TextSize=21
  ui.balance.Size=UDim2.fromOffset(110,38) ui.balance.Position=UDim2.new(1,-124,0,12) ui.coins.TextSize=16
  ui.level.Position=UDim2.fromOffset(12,22)
  ui.energy.Size=UDim2.fromOffset(190,46) ui.energy.Position=UDim2.new(0.5,-95,1,-58)
  ui.run.Position=UDim2.fromOffset(10,1) ui.progress.Position=UDim2.new(1,-62,0,1)
  ui.dash.Position=UDim2.fromOffset(10,20) ui.key.Position=UDim2.new(1,-78,0,20) ui.key.Size=UDim2.fromOffset(68,18)
  ui.dash.Size=UDim2.new(1,-83,0,18) ui.dash.TextSize=14
  restartButton.Size=UDim2.fromOffset(76,30) touchDash.Size=UDim2.fromOffset(60,50)
 else
  ui.map.Size=UDim2.new(1,-111,0,23) ui.accent.Size=UDim2.fromOffset(3,26) ui.accent.Position=UDim2.fromOffset(13,13)
  ui.clock.Size=UDim2.fromOffset(73,34) ui.clock.TextSize=23 ui.coins.TextSize=18 ui.level.Position=UDim2.fromOffset(12,25)
  ui.dash.Size=UDim2.new(1,-90,0,20) ui.dash.TextSize=15 ui.key.Size=UDim2.fromOffset(78,20)
 end
end
table.insert(connections,root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)) layout()
local cameraCheckAt=0
RunService:BindToRenderStep("DasherPresentation",Enum.RenderPriority.Camera.Value+1,function(dt)
 local now=os.clock() local phase=snapshot.phase
 local multiplier=phase=="Racing" and (snapshot.multiplier or 1) or 1
 local timeLeft=math.max(0,(snapshot.timeLeft or 0)-(now-receivedAt)*multiplier)
 ui.clock.Text=phase=="Waiting" and "--:--" or timeText(math.ceil(timeLeft),false)
 ui.clock.TextColor3=phase=="Racing" and timeLeft<=20 and C.gold or C.text
 if phase=="Racing" then ui.phase.Text=multiplier>1 and string.format("%.1fx CLOCK / RACE",multiplier) or "RACE IN PROGRESS" end
 ui.countdown.Visible=phase=="Countdown" and not menuOpen ui.countdown.Text=timeLeft>0.7 and tostring(math.ceil(timeLeft)) or "GO"
 local charge=math.clamp((now-localDashAt)/Config.DashCooldown,0,1) local accepted=player:GetAttribute("DashAt")
 if typeof(accepted)=="number" then charge=math.min(charge,math.clamp((workspace:GetServerTimeNow()-accepted)/Config.DashCooldown,0,1)) end
 local enabled=phase=="Racing" and snapshot.racing and not snapshot.finished and not snapshot.spectating
 ui.energy.Visible=enabled and not menuOpen and not cinematic
 ui.charge.Size=UDim2.fromScale(enabled and charge or 0,1) ui.charge.BackgroundColor3=charge>=0.999 and C.cyan or C.muted
 ui.dash.Text=charge>=0.999 and "DASH READY" or string.format("REFILL %.1fs",(1-charge)*Config.DashCooldown)
 touchDash.Visible=UserInputService.TouchEnabled and enabled and not menuOpen and not cinematic
 touchDash.BackgroundColor3=enabled and charge>=0.999 and C.cyan or C.card touchDash.TextColor3=enabled and charge>=0.999 and C.ink or C.muted
 restartButton.Visible=enabled and not menuOpen
 ui.vote.Visible=phase=="Intermission" and #(snapshot.voteOptions or {})>0 and not menuOpen and not cinematic
 ui.spectator.Visible=spectateTarget~=nil and not menuOpen
 if enabled and type(snapshot.runStartedAt)=="number" then ui.run.Text=timeText(workspace:GetServerTimeNow()-snapshot.runStartedAt,true)
 else ui.run.Text=snapshot.best and ("BEST "..timeText(snapshot.best,true)) or "FIND YOUR LINE" end
 local camera=workspace.CurrentCamera
 if camera~=lastCamera then
  if lastCamera and lastCamera.Parent then lastCamera.FieldOfView=math.clamp(lastCamera.FieldOfView-cameraOffsetApplied,1,120) end
  cameraOffsetApplied=0 lastCamera=camera
 end
 if camera then
  if cinematic then
   local frame=cinematic local alpha=math.clamp((now-frame.started)/frame.duration,0,1) local eased=alpha*alpha*(3-2*alpha)
   camera.CameraType=Enum.CameraType.Scriptable camera.CFrame=CFrame.lookAt(frame.from:Lerp(frame.to,eased),frame.lookAt) camera.Focus=CFrame.new(frame.lookAt)
   if alpha>=1 then restoreCamera() end
  elseif spectateTarget and now-cameraCheckAt>0.25 then
   cameraCheckAt=now local character=spectateTarget.Character local humanoid=character and character:FindFirstChildOfClass("Humanoid")
   local eligible=false for _,racer in ipairs(snapshot.racers or {}) do if racer.userId==spectateTarget.UserId and not racer.finished then eligible=true break end end
   if not humanoid or humanoid.Health<=0 or not eligible then setSpectate(1)
   else camera.CameraType=Enum.CameraType.Custom camera.CameraSubject=humanoid end
  end
  local baseFov=camera.FieldOfView-cameraOffsetApplied cameraKick*=math.exp(-dt*12)
  cameraOffsetApplied=(reducedMotion or cinematic or spectateTarget) and 0 or cameraKick
  camera.FieldOfView=math.clamp(baseFov+cameraOffsetApplied,1,120)
 end
end)
-- Kiosks expose the same pages without permanent screen clutter.
task.spawn(function()
 local lobby=workspace:WaitForChild("Lobby",15) if not lobby then return end
 local kiosks=lobby:WaitForChild("Kiosks",10) if not kiosks then return end
 for _,part in ipairs(kiosks:GetDescendants()) do
  if part:IsA("BasePart") and ({Shop=true,Inventory=true,Quests=true,Leaderboard=true})[part.Name] then
   local prompt=make("ProximityPrompt",part,{Name="DasherMenuPrompt",ActionText="Open",ObjectText=part.Name,KeyboardKeyCode=Enum.KeyCode.E,GamepadKeyCode=Enum.KeyCode.ButtonX,HoldDuration=0,MaxActivationDistance=11,RequiresLineOfSight=false})
   table.insert(connections,prompt.Triggered:Connect(function(person) if not person or person==player then openMenu(part.Name) end end))
  end
 end
end)
task.spawn(function()
 for _=1,8 do local ok=pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false) end) if ok then break end task.wait(0.25) end
end)
player:SetAttribute("DasherClientReady",true) Action:FireServer("Ready")
task.delay(1.2,function() if gui.Parent and snapshot.phase=="Waiting" then Action:FireServer("Ready") end end)
task.delay(3,function() if gui.Parent and not introPlayed then playLobbyIntro() end end)
script.Destroying:Connect(function()
 stopDash(true) restoreCamera()
 for character in pairs(effects) do endEffect(character) end
 for _,connection in ipairs(connections) do connection:Disconnect() end
 for _,connection in ipairs(characterConnections) do connection:Disconnect() end
 RunService:UnbindFromRenderStep("DasherPresentation")
 for _,name in ipairs({"DasherDash","DasherRestart","DasherMenu","DasherSpectate"}) do ContextActionService:UnbindAction(name) end
 dashSound:Destroy() finishSound:Destroy() audioGroup:Destroy() gui:Destroy()
end)
