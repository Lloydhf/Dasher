"""Focused regression of the actual server validation prefix, with scalar physics mocks.
No production edits. Before the landing-order fix, the first assertion fails.
"""
from pathlib import Path
import subprocess
from test_paths import ROOT, QA, LUAU
import hashlib,json,re
server=(ROOT/'src/server/DasherServer.server.luau').read_text(encoding='utf-8')
rules=(ROOT/'src/server/TowerRules.luau').read_text(encoding='utf-8')
start=server.index('local supportOffsets =')
end=server.index('local function updateCourseMotion(',start)
support=server[start:end]
start=server.index('local function teleport(')
end=server.index('local function refreshLeaderstats(',start)
teleport_source=server[start:end]
start=server.index('local function validateRacer(')
end=server.index('\tlocal current, peak = TowerRules.Altitude(',start)
validation=server[start:end]+'\treturn "accepted"\nend\n'
harness=r"""
local checks=0
local function check(ok,label) assert(ok,label); checks+=1; print('PASS '..label) end
local mt={}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__mul=function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
mt.__index=function(a,key) if key=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
local Vector3={new=vec,zero=vec(0,0,0)}
local root,humanoid,hit,reason
local testNow=0
local roster={}
local character={PivotTo=function(_,target) root.Position=target.Position end}
local function now() return testNow end
local function setCharacterMotion() end
local Config={JumpPower=52,WalkSpeed=20,UpdraftGroundTime=.12,UpdraftCooldown=3.25}
local groundParams={}
local boundsPart=nil
local workspace={Gravity=196.2,Raycast=function() return hit end}
local function characterParts() return character,root,humanoid end
local function rootToFeet() return 3.087 end
local function horizontal(v) return vec(v.X,0,v.Z) end
local function finiteVector(v)
 return v.X==v.X and v.Y==v.Y and v.Z==v.Z and math.abs(v.X)<math.huge and math.abs(v.Y)<math.huge and math.abs(v.Z)<math.huge
end
local function resetRun(_,text) reason=text end
"""
harness+='\nlocal TowerRules=(function()\n'+rules+'\nend)()\n'+support+'\n'+teleport_source+'\n'+validation
harness+=r"""
local function scenario(options)
 options=options or {}
 local timestamp=options.time or 1.03
 local position=vec(options.x or 0,options.y or 51.09,0)
 root={Position=position,Size=vec(2,2,1),AssemblyLinearVelocity=vec(0,options.vy or 0,0)}
 humanoid={Health=100}
 hit=options.ground and {Distance=options.distance or 3.087,Normal=vec(0,options.normalY or 1,0),Instance={Name='Walkable'}} or nil
 reason=nil
 local record={lastPosition=vec(0,options.previousY or position.Y,0),lastWorldPosition=position,lastSample=timestamp-.03,
  travelCredit=32,airOriginY=options.origin or 50.12,airStartedAt=0,airLaunchSpeed=options.launch or 52,
  ascentCredit=options.credit or 10,lastUpdraft=-100,graceUntil=.55,teleportAt=0}
 local result=validateRacer({},record,timestamp)
 return result,reason,record
end
local result,why,record=scenario({ground=true})
check(result=='accepted' and why==nil,'Actual supported P008 landing survives stale post-teleport ballistic origin')
check(record.airOriginY==51.09 and record.airStartedAt==1.03,'Accepted landing refreshes the next flight origin')
result,why=scenario({ground=false})
check(result~='accepted' and string.find(why,'Vertical',1,true),'Identical expired pose without support remains rejected')
result,why,record=scenario({ground=true,previousY=30})
check(result~='accepted' and string.find(why,'Vertical',1,true),'Verified floor cannot excuse excessive ascent credit')
check(record.airOriginY==50.12,'Rejected ascent cannot refresh airborne allowance')
result,why=scenario({ground=false,y=50,time=2})
check(result~='accepted' and string.find(why,'Vertical',1,true),'Unsupported hovering still expires')
result,why=scenario({ground=false,y=57,time=.6})
check(result=='accepted' and why==nil,'Ordinary unsupported jump remains within the existing ballistic envelope')
result,why=scenario({ground=false,y=-100,vy=-70})
check(result=='accepted' and why==nil,'Legitimate long fall remains accepted')
result,why=scenario({ground=true,x=50})
check(result~='accepted' and string.find(why,'Movement could',1,true),'Floor contact cannot bypass horizontal distance validation')
result,why=scenario({ground=true,distance=1})
check(result~='accepted' and string.find(why,'Vertical',1,true),'Surface above the feet is not accepted as landing support')
result,why=scenario({ground=true,normalY=0})
check(result~='accepted' and string.find(why,'Vertical',1,true),'Nearby wall cannot end an expired flight')
result,why=scenario({ground=true,y=90,origin=90,time=1.5,launch=88})
check(result=='accepted' and why==nil,'Supported Updraft landing ends its previous flight without extending air time')
local function teleportScenario(options)
 options=options or {}
 testNow=0 reason=nil hit=nil
 root={Position=vec(0,25.087,0),Size=vec(2,2,1),AssemblyLinearVelocity=vec(0,0,0)}
 humanoid={Health=100}
 local player={} local data={lastUpdraft=-100}
 roster[player]=data
 assert(teleport(player,{Position=vec(0,50.207,0)},false))
 local initialClock=data.airStartedAt
 if options.initialOnly then return data,initialClock end
 testNow=options.time or 1.016
 data.lastPosition=vec(0,options.previousY or 52.8,0)
 data.lastWorldPosition=data.lastPosition data.lastSample=testNow-.03
 data.ascentCredit=6.941
 root.Position=vec(options.x or 0,options.y or 52.108,0)
 root.AssemblyLinearVelocity=vec(0,options.vy or -35.693,0)
 hit=options.ground and {Distance=3.087,Normal=vec(0,1,0),Instance={Name='Walkable'}} or nil
 local accepted=validateRacer(player,data,testNow)
 return accepted,reason,data,initialClock
end
local initialized,clock=teleportScenario({initialOnly=true})
check(clock==.55 and clock==initialized.graceUntil,'Actual server teleport sets the initial flight clock once at its fixed grace boundary')
check(52.108>TowerRules.BallisticCeiling(50.207,52,1.016,196.2,.4),'Captured descending jump reproduces expiration under the former teleport clock')
result,why,record,clock=teleportScenario()
check(result=='accepted' and why==nil and record.airStartedAt==clock,'Captured unsupported descending pose is accepted after bounded teleport grace without resetting its clock')
result,why=teleportScenario({y=50.207,previousY=50.207,time=2,vy=0})
check(result~='accepted' and string.find(why,'Vertical',1,true),'Unsupported hover still expires after the fixed teleport grace')
result,why=teleportScenario({y=80,previousY=50.207,time=.6})
check(result~='accepted' and string.find(why,'Vertical',1,true),'Teleport grace clock does not excuse excessive ascent after grace')
result,why=teleportScenario({x=50})
check(result~='accepted' and string.find(why,'Movement could',1,true),'Teleport grace clock does not excuse excessive horizontal motion after grace')
result,why,record=teleportScenario({ground=true,y=51.087,previousY=52.108,time=1.1,vy=0})
check(result=='accepted' and record.airStartedAt==1.1,'Subsequent verified landing replaces the teleport clock with its actual contact time')
local landed={lastUpdraft=10,updraftAirUsed=true,groundedSince=10.5}
refreshGround(landed,root,humanoid,10.63,hit)
check(not landed.updraftAirUsed,'Actual grounded recharge arms after0.12seconds without waiting for the whole cooldown')
check(not TowerRules.UpdraftReady(11,landed.lastUpdraft,landed.updraftAirUsed,nil,Config.UpdraftCooldown,Config.UpdraftGroundTime),'Armed landing does not bypass remaining cooldown')
check(TowerRules.UpdraftReady(13.25,landed.lastUpdraft,landed.updraftAirUsed,nil,Config.UpdraftCooldown,Config.UpdraftGroundTime),'After a real recharge the next jump can use Updraft when its exact cooldown expires')
local pending={lastUpdraft=11,updraftAirUsed=true,groundedSince=10.5,impulsePendingUntil=11.5,airOriginY=root.Position.Y}
refreshGround(pending,root,humanoid,11.1,hit)
check(pending.updraftAirUsed,'Impulse replication delay is not mistaken for a fresh recharge')
print('[DASHER_ASCENT_QA] MOVEMENT_LANDING_PASS '..checks)
"""
output=QA/'movement-landing-tests.luau'
output.write_text(harness,encoding='utf-8')
result=subprocess.run([str(LUAU),str(output)],check=True,capture_output=True,text=True)
print(result.stdout,end='')
match=re.search(r'MOVEMENT_LANDING_PASS (\d+)',result.stdout)
assert match, 'Missing actual-validator regression completion marker'
source_paths=['src/server/DasherServer.server.luau','src/server/TowerRules.luau']
report={'passed':int(match.group(1)),
 'scope':'Actual teleport initialization, validateRacer validation prefix, groundSupport, refreshGround and TowerRules; controlled vector/raycast/clock inputs.',
 'sourceHashes':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in source_paths},
 'harnessSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
(QA/'movement-landing-results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
