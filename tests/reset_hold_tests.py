"""Execute shipped ResetHold and extracted client input wiring with Roblox mocks."""
from pathlib import Path
from test_paths import ROOT, QA, LUAU, LUAU_COMPILE, TESTS
import hashlib
import json
import re
import subprocess

CLIENT = ROOT / 'src/client/DasherClient.client.luau'
MODULE = ROOT / 'src/shared/ResetHold.luau'
source = CLIENT.read_text(encoding='utf-8')

def extract(start, end):
    at = source.index(start)
    return source[at:source.index(end, at)]

prefix = r'''
local checks=0
local function expect(value,why) assert(value,why) checks+=1 end
local now=10
local os={clock=function() return now end}
local function signal()
 local callbacks={}
 return {Connect=function(_,f) table.insert(callbacks,f) return {Disconnect=function() end} end,
 Fire=function(_,...) for _,f in ipairs(callbacks) do f(...) end end}
end
local function enum(names)
 local result={} for _,name in ipairs(names) do result[name]={Name=name} end return result
end
local Enum={UserInputType=enum({'Keyboard','MouseButton1','Touch','Gamepad1'}),KeyCode=enum({'R','ButtonY','ButtonA','Unknown'}),
 UserInputState=enum({'Begin','End','Cancel','Change'}),ContextActionResult={Pass='Pass',Sink='Sink'}}
local vecmt={__sub=function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y},getmetatable(a)) end}
local Vector2={new=function(x,y) return setmetatable({X=x,Y=y},vecmt) end}
local UDim2={fromScale=function(x,y) return {X=x,Y=y} end}
local C={gold='gold',muted='muted'}
local liveHumanoid={Health=100}
local liveRoot={Anchored=false}
local character={FindFirstChildOfClass=function() return liveHumanoid end,FindFirstChild=function() return liveRoot end}
local player={Character=character}
local snapshot={phase='Racing',racing=true,roundId=1}
local cinematic,menuOpen,spectateTarget=nil,false,nil
local dialogue={active=nil}
local resetHold,resetFocused,resetPointer=ResetHold.New(),true,nil
local resetKeyInputs={}
local lastRestartAt=-100
local GuiService={MenuIsOpen=false,SelectedObject=nil,MenuOpened=signal(),GetGuiInset=function() return Vector2.new(0,36) end}
local keys={}
local UserInputService={
 GetFocusedTextBox=function(self) return self.focused end,
 IsKeyDown=function(_,key) return keys['Keyboard:'..key.Name]==true end,
 IsGamepadButtonDown=function(_,kind,key) return keys[kind.Name..':'..key.Name]==true end,
 InputBegan=signal(),InputEnded=signal(),InputChanged=signal(),TextBoxFocused=signal(),WindowFocusReleased=signal(),WindowFocused=signal()}
local remoteCalls=0
local Action={FireServer=function(_,action) expect(action=='Restart','Only Restart is dispatched') remoteCalls+=1 end}
local carryClears=0
local shuttleCarry={reset=function() carryClears+=1 end}
local skillRequests={Updraft=-100}
local skillBlockedBefore=-math.huge
local lastSkillApplied={Updraft=-math.huge}
local workspace={GetServerTimeNow=function() return now end}
local endedEffects=0
local function endEffect() endedEffects+=1 end
local toastMessage
local function showToast(message) toastMessage=message end
local function typeof(value) return type(value)=='table' and value.kind or type(value) end
local connections={}
local gui={Parent=true}
local restartButton={InputBegan=signal(),MouseLeave=signal(),SelectionLost=signal(),AbsolutePosition=Vector2.new(14,500),AbsoluteSize=Vector2.new(140,38)}
local ui={resetFill={},resetTitle={},resetKey={},resetHint={}}
local coreRegistered
local StarterGui={SetCore=function(_,key,value) coreRegistered={key,value} end}
local task={spawn=function(f) f() end,wait=function() end}
local function make(class) expect(class=='BindableEvent','Core reset is event-backed') return {Event=signal()} end
local ContextActionService={handlers={},BindAction=function(self,name,handler) self.handlers[name]=handler end}
'''

events = extract('restartButton.InputBegan:Connect', 'accelerateButton.Activated:Connect')
binding = extract('ContextActionService:BindAction("DasherRestart"', 'ContextActionService:BindAction("DasherMenu"')
render = extract(' local resetTriggered,resetProgress=', ' ui.vote.Visible=phase==')
snapshot_guard = extract(' snapshot=nextSnapshot\n', ' if dialogue.active and not dialogueAllowed(snapshot)')
feedback_reset = extract(' elseif kind=="Reset" or kind=="MovementCorrected" then', ' elseif kind=="StageCompleted" then')

tests = r'''
expect(coreRegistered[1]=='ResetButtonCallback','Core menu reset uses native confirmed callback')
local function input(kind,key,x,y)
 return {UserInputType=Enum.UserInputType[kind],KeyCode=Enum.KeyCode[key or 'Unknown'],Position={X=x or 20,Y=y or 512}}
end
local r,y,a=input('Keyboard','R'),input('Gamepad1','ButtonY'),input('Gamepad1','ButtonA')
local function keyEvent(obj,state)
 local token=resetKeyToken(obj)
 if state=='Begin' then keys[token]=true elseif state=='End' then keys[token]=false end
 return ContextActionService.handlers.DasherRestart(nil,Enum.UserInputState[state],obj)
end
local function endInput(obj)
 keys[resetKeyToken(obj)]=false UserInputService.InputEnded:Fire(obj)
end
local function fresh()
 now+=5 resetHold=ResetHold.New() resetFocused=true resetPointer=nil lastRestartAt=-100
 snapshot={phase='Racing',racing=true,roundId=1} player.Character=character
 cinematic=nil menuOpen=false spectateTarget=nil dialogue.active=nil
 GuiService.MenuIsOpen=false GuiService.SelectedObject=nil UserInputService.focused=nil
 liveHumanoid.Health=100 liveRoot.Anchored=false remoteCalls=0 keys={}
end
fresh()
expect(keyEvent(r,'Begin')=='Sink','R is consumed during a race')
local started=now now+=.3 renderReset(now)
expect(remoteCalls==0 and ui.resetFill.Size.X>0 and ui.resetFill.Size.X<1,'Tap begins progress without resetting')
expect(ui.resetHint.Visible and ui.resetTitle.Text=='HOLD...','Clear cancellable hold presentation')
keyEvent(r,'End') now+=2 renderReset(now)
expect(remoteCalls==0 and ui.resetFill.Size.X==0 and not ui.resetHint.Visible,'Release cancels both request and progress')
keyEvent(r,'Begin') started=now now+=.55 keyEvent(r,'Begin')
now=started+1.09 renderReset(now) expect(remoteCalls==0,'No reset before threshold; repeated keydown cannot shortcut')
now=started+1.101 renderReset(now) expect(remoteCalls==1 and ui.resetTitle.Text=='RESETTING','Held R resets at threshold')
for _=1,50 do now+=.1 renderReset(now) end
expect(remoteCalls==1,'A continuous hold sends exactly one reset')
cancelResetHold() keyEvent(r,'Begin') now+=2 renderReset(now)
expect(remoteCalls==1,'Reset feedback cannot re-arm a still-held key')
endInput(r) keyEvent(r,'Begin') now+=1.2 renderReset(now)
expect(remoteCalls==2,'Release and a new full hold may reset again')

for _,block in ipairs({'menu','dialogue','spectate','cinematic','coreMenu','chat','finished','forfeit','notRacing','spectating','countdown','dead','anchored','missingCharacter'}) do
 fresh() keyEvent(r,'Begin') now+=.7
 if block=='menu' then menuOpen=true elseif block=='dialogue' then dialogue.active={}
 elseif block=='spectate' then spectateTarget={} elseif block=='cinematic' then cinematic={}
 elseif block=='coreMenu' then GuiService.MenuIsOpen=true elseif block=='chat' then UserInputService.focused={}
 elseif block=='finished' then snapshot.finished=true elseif block=='forfeit' then snapshot.forfeited=true
 elseif block=='notRacing' then snapshot.racing=false elseif block=='spectating' then snapshot.spectating=true
 elseif block=='countdown' then snapshot.phase='Countdown' elseif block=='dead' then liveHumanoid.Health=0
 elseif block=='anchored' then liveRoot.Anchored=true elseif block=='missingCharacter' then player.Character=nil end
 now+=1 renderReset(now)
 expect(remoteCalls==0 and resetHold.active==nil,'Lifecycle blocks and cancels: '..block)
end

fresh() keyEvent(r,'Begin') now+=.8 UserInputService.TextBoxFocused:Fire({})
now+=1 renderReset(now) expect(remoteCalls==0 and resetHold.active==nil,'Chat focus cancels immediately')
keyEvent(r,'Begin') now+=2 renderReset(now) expect(remoteCalls==0,'Closing chat cannot resume held R')
endInput(r) keyEvent(r,'Begin') now+=1.2 renderReset(now) expect(remoteCalls==1,'New post-chat press works')

fresh() keyEvent(r,'Begin') now+=.8 UserInputService.WindowFocusReleased:Fire()
now+=1 renderReset(now) expect(remoteCalls==0 and not resetFocused,'Alt-tab cancels')
UserInputService.WindowFocused:Fire() keyEvent(r,'Begin') now+=2 renderReset(now)
expect(remoteCalls==0,'Still-held key cannot resume on focus return')
UserInputService.WindowFocusReleased:Fire() keys[resetKeyToken(r)]=false UserInputService.WindowFocused:Fire()
keyEvent(r,'Begin') now+=1.2 renderReset(now) expect(remoteCalls==1,'Release outside window is reconciled on focus return')

fresh() keyEvent(r,'Begin') GuiService.MenuOpened:Fire() now+=2 renderReset(now)
expect(remoteCalls==0,'ESC opening cancels hold immediately')
fresh() keyEvent(r,'Begin') keyEvent(r,'Cancel') now+=2 renderReset(now)
expect(remoteCalls==0,'ContextAction Cancel cannot trigger reset')
keyEvent(r,'Begin') now+=2 renderReset(now) expect(remoteCalls==0,'ContextAction Cancel still requires physical release')

fresh() keyEvent(y,'Begin') now+=1.2 renderReset(now) expect(remoteCalls==1,'Y holds use the same timing')
fresh() GuiService.SelectedObject=restartButton keys[resetKeyToken(a)]=true UserInputService.InputBegan:Fire(a)
now+=1.2 renderReset(now) expect(remoteCalls==1,'Selected reset button supports held gamepad A')
fresh() GuiService.SelectedObject=restartButton UserInputService.InputBegan:Fire(a) now+=.5
restartButton.SelectionLost:Fire() now+=1 renderReset(now) expect(remoteCalls==0,'Moving gamepad selection cancels hold')

fresh() local mouse=input('MouseButton1') restartButton.InputBegan:Fire(mouse)
now+=.5 restartButton.MouseLeave:Fire() now+=2 renderReset(now) expect(remoteCalls==0,'Dragging mouse out cancels')
endInput(mouse) restartButton.InputBegan:Fire(mouse) now+=1.2 renderReset(now) expect(remoteCalls==1,'Mouse hold confirms only at full progress')
fresh() local touch=input('Touch') restartButton.InputBegan:Fire(touch)
expect(resetPointerInside(touch),'Touch shares AbsolutePosition origin; top inset is not subtracted twice')
now+=.4 endInput(touch) now+=1 renderReset(now) expect(remoteCalls==0,'Touch tap does not reset')
restartButton.InputBegan:Fire(touch) now+=.5 touch.Position={X=600,Y=800} UserInputService.InputChanged:Fire(touch)
now+=1 renderReset(now) expect(remoteCalls==0,'Touch drag outside cancels')
endInput(touch) touch.Position={X=24,Y=515} restartButton.InputBegan:Fire(touch)
UserInputService.InputChanged:Fire(touch) expect(resetHold.active==touch,'Moving inside the touch button preserves hold')
now+=1.2 renderReset(now) expect(remoteCalls==1,'Touch hold inside confirms')

fresh() keyEvent(r,'Begin') now+=.5 keyEvent(y,'Begin') keyEvent(r,'End') now+=2 renderReset(now)
expect(remoteCalls==0,'Second held input cannot inherit progress')
keyEvent(y,'Begin') now+=2 renderReset(now) expect(remoteCalls==0,'Second input must release before its own hold')
keyEvent(y,'End') keyEvent(y,'Begin') now+=1.2 renderReset(now) expect(remoteCalls==1,'Second input can start a fresh hold after release')

fresh() keyEvent(r,'Begin') now+=.8 player.Character={}
now+=.5 local fired=ResetHold.Step(resetHold,now,true,player.Character)
expect(not fired and resetHold.active==nil,'A new character cannot inherit a pending hold')
fresh() keyEvent(r,'Begin') now+=.8 applySnapshot({phase='Racing',racing=true,roundId=2})
now+=1 renderReset(now) expect(remoteCalls==0 and resetHold.active==nil,'New racing round cancels previous round input')
keyEvent(r,'Begin') now+=2 renderReset(now) expect(remoteCalls==0,'Round transition does not re-arm a held key')
endInput(r) keyEvent(r,'Begin') now+=1.2 renderReset(now) expect(remoteCalls==1,'New round accepts a fresh complete hold')
fresh() keyEvent(r,'Begin') now+=.8 applySnapshot({phase='Countdown',racing=true,roundId=1})
expect(resetHold.active==nil,'Phase snapshot cancels before the next frame')
fresh() keyEvent(r,'Begin') now-=2
local fired=ResetHold.Step(resetHold,now,true,character)
expect(not fired and resetHold.active==nil,'A clock rollback cancels rather than firing')

fresh() GuiService.MenuIsOpen=true coreReset.Event:Fire()
expect(remoteCalls==1,'Native confirmed menu reset reaches same request path')
coreReset.Event:Fire() expect(remoteCalls==1,'Duplicate native confirmation is debounced')
fresh() snapshot.phase='Countdown' coreReset.Event:Fire()
expect(remoteCalls==0,'Native confirmation cannot reset countdown')
fresh() snapshot.finished=true coreReset.Event:Fire()
expect(remoteCalls==0,'Native confirmation cannot reset a finisher')

for _,kind in ipairs({'Reset','MovementCorrected'}) do
 fresh() keyEvent(r,'Begin') now+=.7
 local pendingAt=now-.04 skillRequests.Updraft=pendingAt
 local oldCarry,oldEffects=carryClears,endedEffects
 feedbackReset(kind,'Returned to your last landing.')
 expect(resetHold.active==nil and skillRequests.Updraft==-100,'Feedback clears hold and pending skill: '..kind)
 expect(carryClears==oldCarry+1 and endedEffects==oldEffects+1,'Feedback clears carry and active skill animation: '..kind)
 expect(skillBlockedBefore==now and toastMessage=='Returned to your last landing.','Feedback records correction boundary and keeps server message: '..kind)
 local velocity={kind='Vector3',X=0,Y=84,Z=0,Magnitude=84}
 expect(not applyApprovedVelocity('Updraft',{at=pendingAt,velocity=velocity}),'An old approved impulse cannot apply after '..kind)
 now+=1 renderReset(now) expect(remoteCalls==0,'Feedback cannot complete a cancelled hold: '..kind)
end

print('RESET_HOLD_CHECKS='..checks)
'''

code = 'local ResetHold=(function()\n' + MODULE.read_text(encoding='utf-8') + '\nend)()\n'
code += prefix
code += extract('local function resetEligible(confirmedCoreReset)', 'ui.updraft.button.Activated:Connect')
code += extract('local function validVelocity(value)', '-- Only the network owner transports')
code += extract('local function applyApprovedVelocity(kind,extra)', 'local function skillInputAllowed()')
code += '\nlocal function feedbackReset(kind,message)\n if false then\n' + feedback_reset + '\n end\nend\n'
code += events + '\n' + binding
code += '\nlocal function renderReset(now)\n restartButton.Visible=true\n' + render + '\nend\n'
code += '\nlocal function applySnapshot(nextSnapshot)\n local previousPhase,previousRound=snapshot.phase,snapshot.roundId\n' + snapshot_guard + '\nend\n'
code += tests
harness = QA / 'reset_hold_tests.luau'
harness.write_text(code, encoding='utf-8')
run = subprocess.run([str(LUAU),str(harness)],capture_output=True,text=True)
print(run.stdout, end='')
print(run.stderr, end='')
if run.returncode:
    raise SystemExit(run.returncode)
checks = int(re.search(r'RESET_HOLD_CHECKS=(\d+)',run.stdout)[1])
report = {'passed':True,'checks':checks,'kind':'actual shipped hold state machine and extracted client event wiring',
          'files':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (CLIENT,MODULE)},
          'scope':['R/Y/button-A/mouse/touch','short tap and repeated keydown','one request per hold',
                   'release and focus recovery','chat/menu/dialogue/phase/character cancellation',
                   'pointer drag and controller selection','native reset confirmation','progress HUD state']}
(QA/'reset-hold-results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
