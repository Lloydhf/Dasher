"""Execute actual v0.5 finish/reward/round functions with deterministic service mocks.

This verifies lifecycle and reward logic, not Roblox physics or a native10-player run.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
from test_paths import ROOT, QA, LUAU

SERVER = ROOT / 'src/server'
source = (SERVER / 'DasherServer.server.luau').read_text(encoding='utf-8-sig')

def between(start, end):
    return source[source.index(start):source.index(end, source.index(start))]

code = r'''
local checks=0
local function check(value,name) assert(value,name); checks+=1; print('PASS '..name) end
local sequence=0
local task={wait=function() end,spawn=function(fn) fn() end}
local game={JobId='qa',GameId=100,GetService=function(_,name)
 if name=='RunService' then return {IsStudio=function() return true end} end
 if name=='HttpService' then return {GenerateGUID=function() sequence+=1; return tostring(sequence) end} end
 return {}
end}
local warn=function() end
'''
for module in ('ProfileStore', 'TowerRules', 'RoundRules'):
    code += '\nlocal ' + module + '=(function()\n' + (SERVER / (module+'.luau')).read_text(encoding='utf-8-sig') + '\nend)()\n'
code += r'''
local Config={CourseVersion=5,StageReward=3,StageXP=25,XPPerLevel=500,
 Cosmetics={{id='ice',name='ION',price=0},{id='solar',name='SOLAR',price=120}},
 MapOrder={'Helix','Canopy','Reactor'},MaxRacers=10,WalkSpeed=20,UpdraftSpeed=88,
 UpdraftCooldown=3.25,UpdraftGroundTime=.12,FinishReward=14,RankBonuses={6,3,1},FirstFinishGrace=90,SpeedMultiplier=1.5}
local profiles=ProfileStore.new(Config)
local Players={}
local people={}
function Players:GetPlayers() return people end
local clock=100
local function now() return clock end
local phase='Racing'
local roundId=1
local mapId='Helix'
local timeLeft=420
local finalSprint=false
local roundEndReason=nil
local finishers,finishClaims,roster,lastPlayedRound={},{},{},{}
local spectating,votes,voteOptions={},{},{}
local previousMap=nil
local stopping=false
local multiplier=1
local accelerated,accelerateAt,accelerationOwner=false,nil,nil
local activeSince=0
local random={NextInteger=function(_,a) return a end}
local gates={1,2,3,4,5,6,7,8}
local mt={__sub=function() return {Magnitude=208} end}
local startPart={Position=setmetatable({},mt)}
local finishPart={Position=setmetatable({},mt)}
local weeklyLeaderboard={sessionOnly=true,Queue=function() end}
local messages,teleports={},{}
local broadcasts=0
local function refreshLeaderstats() end
local function sendState() broadcasts+=1 end
local function broadcastState() broadcasts+=1 end
local function announce(message) table.insert(messages,{kind='Announcement',message=message}) end
local function tell(player,kind,message,extra) table.insert(messages,{player=player,kind=kind,message=message,extra=extra}) end
local function lobbyCFrame() return 'Lobby' end
local function startCFrame() return 'Start' end
local function teleport(player,target) teleports[player]=target; return true end
local function resetRun(player,reason) roster[player].resetReason=reason end
local function applyLobbyLighting() end
local function loadMap() return true end
local timings={intermission=1,countdown=1,round=420,results=1}
local phases={}
local function waitPhase(duration)
 table.insert(phases,phase)
 clock+=duration
 if phase=='Results' then stopping=true end
 return true
end
local function player(id)
 local item={UserId=id,Name='Player'..id,DisplayName='Player'..id,Parent=Players,attributes={}}
 function item:SetAttribute(name,value) self.attributes[name]=value end
 return item
end
'''
code += between('local function addEntrant(', 'local function resetRun(')
code += between('local function creditStages(', 'local supportOffsets =')
code += between('local function runRounds()', '-- The first lobby visit')
contact = between('\t-- Only a real landing on an authored course surface', '\trecord.lastPosition = position\n\trecord.lastWorldPosition = position\n\trecord.lastSample = timestamp\nend\n\nlocal function applyLighting')
code += '\nlocal courseStages={}\nlocal insideCrown=false\nlocal function intersectsBox() return insideCrown end\n'
code += '\nlocal function validatedContact(player,record,grounded,groundPart)\n local routePrevious,position=nil,nil\n' + contact + '\nend\n'
code += r'''
local function resetScenario(count)
 people={}
 profiles=ProfileStore.new(Config)
 roster,finishClaims,finishers,lastPlayedRound={},{},{},{}
 messages,teleports,phases={},{},{}
 stopping=false
 clock=100
 phase='Racing' roundId=1 timeLeft=420
 finalSprint=false
 profiles:BeginStageRound(roundId)
 for i=1,count do
  local p=player(i) table.insert(people,p) profiles:Load(p) addEntrant(p)
 end
 clock=110
end
resetScenario(1)
local p=people[1]
local record=roster[p]
creditStages(p,record,3,false)
check(record.gate==3 and profiles:GetStageProgress(p,1)==3,'Landing on a higher authored route fills missed milestones')
check(profiles:Get(p).coins==9 and profiles:Get(p).xp==75,'Skipped milestone reward sum is exact')
record.gate=0
creditStages(p,record,2,false)
check(record.gate==2 and profiles:Get(p).coins==9,'Restart and lower re-climb cannot farm already claimed rewards')
creditStages(p,record,5,false)
check(profiles:Get(p).coins==15 and profiles:GetStageProgress(p,1)==5,'Later alternate route rewards only new milestones')
local before=profiles:Get(p).coins
for _,bad in {-1,2.5,9,math.huge,0/0,'8'} do creditStages(p,record,bad,false) end
check(profiles:Get(p).coins==before and record.gate==5,'Invalid authored stage values grant nothing')
record.gate=0
finishRun(p)
check(record.finished and #finishers==1 and finishClaims[p.UserId]~=nil,'Crown finishes after legitimate skipped rests without exact gate history')
check(record.gate==8 and profiles:GetStageProgress(p,1)==8,'Crown settles remaining milestones')
check(profiles:Get(p).coins==44 and profiles:Get(p).xp==350,'First finish gets exactly eight milestones plus first-place rewards')
check(teleports[p]=='Lobby' and p.attributes.IsRacing==false,'Finisher returns to lobby and leaves active racing')
check(finalSprint and timeLeft==90,'First finish caps remaining race at90seconds')
local finishMessages=0
for _,m in messages do if m.kind=='Finish' then finishMessages+=1; check(m.extra.rank==1 and m.extra.time==10,'Finish feedback supplies rank and time') end end
finishRun(p)
check(#finishers==1 and profiles:Get(p).coins==44 and finishMessages==1,'Duplicate finish contact cannot double reward')
roster[p]=nil p.Parent=nil profiles:Release(p)
local rejoined=player(1) profiles:Load(rejoined) people={rejoined} addEntrant(rejoined)
check(roster[rejoined].finished and teleports[rejoined]=='Lobby','Same-round reconnect restores finished status without racing again')
finishRun(rejoined)
check(#finishers==1 and profiles:Get(rejoined).weekly.finishes==0,'Reconnect cannot farm another finish award')

resetScenario(1) p=people[1] record=roster[p]
record.forfeited=true
finishRun(p)
check(not record.finished and #finishers==0,'Forfeited racer cannot finish')
record.forfeited=false phase='Results' finishRun(p)
check(not record.finished,'Finish outside Racing is inert')
phase='Racing' clock=record.runStartedAt+.1 finishRun(p)
check(not record.finished and record.resetReason~=nil,'Implausibly fast crown contact fails timing guard')

resetScenario(1) p=people[1] record=roster[p]
local authoredBranch={} courseStages={[authoredBranch]=3}
validatedContact(p,record,false,authoredBranch)
check(record.gate==0,'Actual movement tail grants no reward for merely flying above a branch')
validatedContact(p,record,true,{})
check(record.gate==0,'Actual movement tail grants no progress for non-route scenery support')
validatedContact(p,record,true,authoredBranch)
check(record.gate==3 and profiles:GetStageProgress(p,1)==3,'Actual movement tail accepts alternate authored contact')
record.gate=0 insideCrown=true
validatedContact(p,record,false,nil)
check(record.finished,'Actual validated crown contact reaches finish even without exact rest history')
insideCrown=false

resetScenario(10)
local slots={}
for _,entrant in people do slots[roster[entrant].spawnSlot]=true end
local slotCount=0 for _ in slots do slotCount+=1 end
check(slotCount==10,'Ten racers get distinct starting slots')
local eleventh=player(11) profiles:Load(eleventh) addEntrant(eleventh)
check(roster[eleventh]==nil,'Eleventh connected racer waits for capacity')
for i=1,9 do finishRun(people[i]) end
local ended,reason,entrants,unfinished=RoundRules.RaceStatus(roster,function(q) return q.Parent==Players end,timeLeft,10)
check(not ended and entrants==10 and unfinished==1,'Nine finishes do not end a10-racer race early')
finishRun(people[10])
ended,reason=RoundRules.RaceStatus(roster,function(q) return q.Parent==Players end,timeLeft,10)
check(ended and reason=='AllFinished' and #finishers==10,'Tenth finish ends the10-racer race')
local ranks=true
for i,item in finishers do if item.rank~=i or item.userId~=i then ranks=false end end
check(ranks,'Ten independent finish ranks are unique and ordered')
check(profiles:Get(people[2]).coins==41 and profiles:Get(people[3]).coins==39 and profiles:Get(people[10]).coins==38,'Rank bonus applies only to the correct finishers')

resetScenario(10)
for i=1,8 do roster[people[i]].finished=true end
roster[people[9]].forfeited=true people[10].Parent=nil
ended,reason=RoundRules.RaceStatus(roster,function(q) return q.Parent==Players end,60,10)
check(ended and reason=='AllFinished','Forfeit and departing last racer cannot keep a race open')
for _,q in people do q.Parent=nil end
ended,reason=RoundRules.RaceStatus(roster,function(q) return q.Parent==Players end,60,10)
check(ended and reason=='NoRacers','No connected racers ends instead of waiting for420seconds')
ended,reason=RoundRules.RaceStatus({},function() return true end,60,2)
check(ended and reason=='NoRacers','Empty roster with lobby spectators also ends')
ended=RoundRules.RaceStatus({},function() return true end,60,.5)
check(not ended,'Initial minimum grace prevents an immediate empty-round flash')
resetScenario(10)
ended,reason=RoundRules.RaceStatus(roster,function() return true end,0,420)
check(ended and reason=='TimeUp','Timeout ends with all ten racers still unfinished')
local many,played={},{}
for i=1,12 do many[i]=player(i); if i<=10 then played[i]=1 end end
local selected=RoundRules.SelectEntrants(many,played,10)
check(#selected==10 and selected[1].UserId==11 and selected[2].UserId==12,'Waiting players receive priority in the next capped race')
check(#many==12 and many[1].UserId==1,'Fair selection does not mutate the connected-player array')

local function lifecycle(mode)
 resetScenario(10)
 local fired=false
 task.wait=function(dt)
  clock+=dt
  if phase=='Racing' and clock-activeSince>=4 and not fired then
   fired=true
   if mode=='finish' then for _,q in people do finishRun(q) end
   elseif mode=='depart' then for _,q in people do q.Parent=nil end
   elseif mode=='sprint' then finishRun(people[1]) end
  end
 end
 runRounds()
 check(table.concat(phases,',')=='Intermission,Countdown,Results','Actual round loop reaches Results after '..mode)
 check(phase=='Results' and stopping,'Actual round loop exits test cleanly after '..mode)
 local expected=mode=='finish' and 'AllFinished' or mode=='depart' and 'NoRacers' or 'TimeUp'
 check(roundEndReason==expected,'Actual round loop reports '..expected..' after '..mode)
 if mode=='finish' then check(#finishers==10,'Actual loop records all ten independent winners') end
 if mode=='sprint' then check(clock-activeSince<96,'Actual loop applies first-finish90second cap') end
 for _,q in people do check(q.attributes.IsRacing==false and teleports[q]=='Lobby','Results releases racer'..q.UserId..' after '..mode) end
end
lifecycle('finish') lifecycle('timeout') lifecycle('depart') lifecycle('sprint')

resetScenario(10)
local roundResults=0
waitPhase=function(duration)
 table.insert(phases,phase) clock+=duration
 if phase=='Results' then roundResults+=1; if roundResults==2 then stopping=true end end
 return true
end
task.wait=function(dt)
 clock+=dt
 if phase=='Racing' and clock-activeSince>=4 then
  for _,q in people do if not roster[q].finished then finishRun(q) end end
 end
end
runRounds()
check(table.concat(phases,',')=='Intermission,Countdown,Results,Intermission,Countdown,Results','Actual loop starts a new voted round after Results')
check(roundId==3 and #finishers==10,'New round resets finish claims and records ten new completions')
check(profiles:Get(people[1]).weekly.finishes==2 and profiles:Get(people[1]).coins==88,'New-round rewards remain available exactly once per round')

check(not TowerRules.UpdraftReady(3.24,0,false,nil,3.25,.12),'Updraft cannot fire before3.25second cooldown')
check(TowerRules.UpdraftReady(3.25,0,false,nil,3.25,.12),'Armed Updraft becomes ready exactly at3.25seconds')
check(not TowerRules.UpdraftReady(5,0,true,nil,3.25,.12),'Repeated airborne Updraft remains prohibited')
check(TowerRules.UpdraftReady(5,0,true,4.8,3.25,.12),'Verified landing rearms Updraft')
print('[DASHER05_SERVER] PASS '..checks)
'''
target = QA / 'finish-regressions.luau'
target.write_text(code, encoding='utf-8')
exe = LUAU
result = subprocess.run([str(exe), str(target)], capture_output=True, text=True)
print(result.stdout, end='')
print(result.stderr, end='')
if result.returncode:
    raise SystemExit(result.returncode)
count = int(re.search(r'\[DASHER05_SERVER\] PASS (\d+)', result.stdout).group(1))
hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in SERVER.glob('*.luau')}
(QA / 'finish-regression-results.json').write_text(json.dumps({
    'version': '0.5.0', 'passed': count, 'failed': 0,
    'scope': 'Actual server finish/entrant/round-loop functions and profile/rule modules under deterministic service mocks; not native10-client performance.',
    'sourceSha256': hashes, 'harnessSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
}, indent=2), encoding='utf-8')
