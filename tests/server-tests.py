from pathlib import Path
from test_paths import ROOT, QA, LUAU, LUAU_COMPILE, TESTS
import subprocess
import hashlib
import json
import re
SERVER = ROOT / 'src/server'
preamble = r'''
local checks=0
local function check(value,name) assert(value,name); checks+=1; print('PASS '..name) end
local timestamp=1790110800
local failedStorage=false
local stored,writes={},0
local sequence=0
local studio=true
local storage={UpdateAsync=function(_,key,callback)
 if failedStorage then error('injected unavailable storage') end
 local nextValue=callback(stored[key])
 if nextValue~=nil then stored[key]=nextValue; writes+=1 end
 return nextValue
end}
local services={
 DataStoreService={GetDataStore=function() return storage end},
 HttpService={GenerateGUID=function() sequence+=1; return tostring(sequence) end},
 RunService={IsStudio=function() return studio end},
}
local game={JobId='qa',GameId=100,GetService=function(_,name) return services[name] end}
local os={time=function() return timestamp end,clock=function() return 0 end}
local task={wait=function() end,spawn=function(fn) fn() end}
local warn=function() end
'''
source=preamble
for module in ('ProfileStore','TowerRules'):
 source+='\nlocal '+module+'=(function()\n'+(SERVER/(module+'.luau')).read_text(encoding='utf-8-sig')+'\nend)()\n'
source+=r'''
local config={CourseVersion=6,StageReward=3,StageXP=25,XPPerLevel=500,
 Cosmetics={{id='ice',name='ION',price=0},{id='solar',name='SOLAR',price=120}},
 MapOrder={'Helix','Canopy','Reactor'}}
local player={UserId=101,Name='StageQA'}
local p=ProfileStore.new(config)
local data,status=p:Load(player)
check(status=='session' and not p:Save(player,false) and writes==0,'Studio cannot write live data')
check(p:BeginStageRound(10),'Server establishes round reward ledger')
local ok,coins,xp=p:RecordStage(player,10,1,8)
check(ok and coins==3 and xp==25 and data.coins==3 and data.xp==25,'First verified sector atomically credits coins andXP')
check(not p:RecordStage(player,10,1,8) and data.coins==3 and data.xp==25,'Duplicate sector cannot award twice')
check(not p:RecordStage(player,10,3,8),'Future sector cannot skip unclaimed sector')
for _,value in {0,-1,2.5,9,math.huge,0/0,'2'} do
 check(not p:RecordStage(player,10,value,8),'Malformed/out-of-range stage rejected '..tostring(value))
end
check(not p:RecordStage(player,11,2,8),'Unestablished round token rejected')
check(not p:RecordStage(player,10,2,101),'Unbounded total-stage count rejected')
check(p:RecordStage(player,10,2,8) and p:GetStageProgress(player,10)==2,'Next sequential sector rewarded')
check(not p:BeginStageRound(10) and not p:BeginStageRound(9),'Repeated or stale begin cannot clear reward ledger')
check(not p:RecordStage(player,10,1,8) and not p:RecordStage(player,10,2,8) and data.coins==6,'Restarting and reclimbing same sectors cannot farm')
check(data.weekly.finishes==0 and data.weekly.score==0,'StageXP does not inflate weekly finish leaderboard')
p:RecordFinish(player,1)
check(data.xp==200 and data.weekly.score==150 and data.weekly.finishes==1,'Finish adds ordinaryXP and distinct weekly finish score')
p:Release(player)
local rejoined={UserId=101,Name='StageQA'}
p:Load(rejoined)
check(p:GetStageProgress(rejoined,10)==2 and not p:RecordStage(rejoined,10,1,8),'Same-server disconnect/rejoin retains claims byUserId')
check(p:RecordStage(rejoined,10,3,8),'Rejoined player may earn only a later sequential sector')
check(p:BeginStageRound(11) and p:RecordStage(rejoined,11,1,8),'New round permits new verified sector reward')
check(not p:RecordStage(rejoined,10,2,8),'Old round token remains invalid after round transition')
local migrated=p:_sanitize({version=2,courseVersion=4,coins=777,xp=1250,owned={ice=true,solar=true},equipped='solar',best={Helix=95.2},legacyBest={Skyline=29.1}})
check(migrated.courseVersion==6 and migrated.coins==777 and migrated.xp==1250 and migrated.owned.solar and migrated.equipped=='solar','CourseVersion6 preserves balances,XP,cosmetics')
check(migrated.best.Helix==nil and migrated.legacyBest.Helix==95.2 and migrated.legacyBest.Skyline==29.1,'CourseVersion6 archives old tower and horizontal records')
studio=false
stored.player_101={version=2,courseVersion=4,coins=700,owned={ice=true},equipped='ice',best={Helix=99}}
local live=ProfileStore.new(config)
local liveData,liveStatus=live:Load(player)
check(liveStatus=='saved' and stored.player_101.courseVersion==6,'Live load performs version6 migration under session lock')
live:BeginStageRound(1)
check(live:RecordStage(player,1,1,8) and live:Save(player,false) and stored.player_101.coins==703,'Atomic stage balance persists through normal profile save')
live:Release(player)
live:Load(rejoined)
check(not live:RecordStage(rejoined,1,1,8) and live:Get(rejoined).coins==703,'Saved rejoin cannot reclaim same-server round reward')
local writesBefore=writes
failedStorage=true
local unavailable=ProfileStore.new(config)
local unavailablePlayer={UserId=202}
local _,unavailableStatus=unavailable:Load(unavailablePlayer)
unavailable:AddCoins(unavailablePlayer,99)
check(unavailableStatus=='error' and not unavailable:Save(unavailablePlayer,false) and writes==writesBefore,'Failed load never overwrites saved data with defaults')
failedStorage=false
stored.player_303={version=999,coins=900}
local future=ProfileStore.new(config)
local _,futureStatus=future:Load({UserId=303})
check(futureStatus=='error' and stored.player_303.coins==900,'Future profile schemas remain untouched')
local c,peak,h,progress=TowerRules.Altitude(126,26,234,130)
check(c==100 and peak==130 and h==208 and progress<.5,'Falling reduces current altitude while retaining peak')
check(TowerRules.FinishContact(0,0,0,11,7,4,true),'Supported root inside exact finish prism qualifies')
check(not TowerRules.FinishContact(0,0,0,11,7,4,false),'Airborne root inside finish prism cannot qualify')
check(not TowerRules.UpdraftReady(15,1,true,nil,6,.2),'Cooldown alone does not reload Updraft in air')
check(TowerRules.UpdraftReady(15,1,true,14.7,6,.2),'Landing and elapsed cooldown reload Updraft')
check(TowerRules.GroundContact(3.085,3.087,1,0),'Native edge-supported standing contact remains grounded')
check(not TowerRules.GroundContact(3.085,3.087,0,0),'Nearby vertical wall cannot grant ground support')
check(not TowerRules.GroundContact(1,3.087,1,0),'Surface above the feet cannot masquerade as a landing')
check(not TowerRules.GroundContact(5,3.087,1,0),'Floor too far below cannot recharge an airborne skill')
check(not TowerRules.GroundContact(3.087,3.087,1,52),'Ascending jump through the support region is not a landing')
check(not TowerRules.GroundContact(3.087,3.087,1,-40),'Falling past a nearby ledge is not stable support')
check(not TowerRules.GroundContact(0/0,3.087,1,0),'Nonfinite ground distance cannot validate support')
check(TowerRules.ShuttleAlpha(0,10,1.5)==0 and TowerRules.ShuttleAlpha(1.49,10,1.5)==0,'Shuttle dwells at authored dockA')
check(math.abs(TowerRules.ShuttleAlpha(3.25,10,1.5)-.5)<1e-8,'Shuttle outward travel reaches midpoint')
check(TowerRules.ShuttleAlpha(5,10,1.5)==1 and TowerRules.ShuttleAlpha(6.49,10,1.5)==1,'Shuttle dwells at dockB')
check(math.abs(TowerRules.ShuttleAlpha(8.25,10,1.5)-.5)<1e-8,'Shuttle return travel reaches midpoint')
check(TowerRules.ShuttleAlpha(10,10,1.5)==0 and TowerRules.ShuttleAlpha(20,10,1.5)==0,'Shuttle cycles are deterministic and continuous')
local bounded=true
for i=-200,1000 do local alpha=TowerRules.ShuttleAlpha(i*.03,10,1.5); if alpha<0 or alpha>1 then bounded=false end end
check(bounded,'Shuttle never exceeds authored endpoints')
local solid,warning=TowerRules.BlinkState(3.99,7,5,1)
check(solid and not warning,'Timed step remains solid before warning interval')
solid,warning=TowerRules.BlinkState(4,7,5,1)
check(solid and warning,'Warning starts while timed step remains solid')
solid,warning=TowerRules.BlinkState(5,7,5,1)
check(not solid and not warning,'Timed step disappears exactly at off boundary')
solid,warning=TowerRules.BlinkState(7,7,5,1)
check(solid and not warning,'Timed step returns at next cycle')
print('[DASHER_ASCENT_QA] SERVER_RULES_PASS '..checks)
'''
output=QA/'server-tests.luau'
output.write_text(source,encoding='utf-8')
exe=LUAU
result=subprocess.run([str(exe),str(output)],capture_output=True,text=True,check=True)
print(result.stdout,end='')
if result.stderr:
 print(result.stderr,end='')
match=re.search(r'SERVER_RULES_PASS (\d+)',result.stdout)
assert match and int(match.group(1))>=52, 'Missing profile/rule completion marker'
compiler=LUAU_COMPILE
for file in SERVER.glob('*.luau'):
 subprocess.run([str(compiler),str(file)],stdout=subprocess.DEVNULL,check=True)
 print('Compiled:',file.name)
module_paths=[SERVER/(name+'.luau') for name in ('ProfileStore','TowerRules')]
assert all(path.read_text(encoding='utf-8-sig') in source for path in module_paths), 'Harness does not embed current modules'
record={
 'version':'0.7.0',
 'passed':int(match.group(1)),
 'failed':0,
 'exit_code':result.returncode,
 'scope':'Actual ProfileStore and TowerRules modules under deterministic datastore, time and terrain mocks; no live persistence or multi-client network claim.',
 'sourceSha256':{str(path.relative_to(SERVER.parent.parent)).replace('\\','/'):hashlib.sha256(path.read_bytes()).hexdigest() for path in module_paths},
 'harness':'server-tests.luau',
 'harnessSha256':hashlib.sha256(output.read_bytes()).hexdigest(),
 'sourceFunctionsVerified':True,
 'details':match.group(0),
}
(QA/'profile-rules-results.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
