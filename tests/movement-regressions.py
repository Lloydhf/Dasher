"""Source-bound complete server validator regressions with controlled replicated poses.

Runs genuine production validateRacer, support, teleport and correction functions.
The physics/contact world is a deterministic mock, not a native Roblox claim.
"""
from pathlib import Path
from test_paths import ROOT, QA, LUAU, LUAU_COMPILE, TESTS
import hashlib, json, re, subprocess
source=(ROOT/'src/server/DasherServer.server.luau').read_text(encoding='utf-8-sig')
rules=(ROOT/'src/server/TowerRules.luau').read_text(encoding='utf-8-sig')
def between(a,b): return source[source.index(a):source.index(b,source.index(a))]
code=r'''
local checks=0
local function check(value,label) assert(value,label); checks+=1; print('PASS '..label) end
local mt={}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__mul=function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
mt.__index=function(a,key) if key=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
local Vector3={new=vec,zero=vec(0,0,0)}
local cf={}
local function frame(position) return setmetatable({Position=position},{__index=cf,__mul=function(a,b) return frame(a.Position+b.Position) end}) end
function cf:PointToObjectSpace(position) return position-self.Position end
function cf:ToObjectSpace(other) return frame(other.Position-self.Position) end
local function typeof(value) return getmetatable(value)==mt and 'Vector3' or type(value) end
local Enum={HumanoidRigType={R6='R6',R15='R15'},HumanoidStateType={Jumping='Jumping'}}
local Config={JumpPower=52,WalkSpeed=20,UpdraftGroundTime=.12,UpdraftCooldown=3.25,UpdraftSpeed=88}
local groundParams={}
local phase='Racing'
local Players={}
local timestamp=0
local function now() return timestamp end
local root,humanoid,character,player,record
local roster={}
local floorParts={}
local hazards={}
local boundsPart=nil
local courseMotion=nil
local activeSince=0
local startPart={Position=vec(0,3,0)}
local finishPart={Position=vec(40,43.5,0),Size=vec(11,7,4),CFrame=frame(vec(40,43.5,0))}
local finishPad=nil
local courseStages={}
local awarded,finished,resets,corrections=0,0,{},{}
local function horizontal(v) return vec(v.X,0,v.Z) end
local function finiteVector(v) return v.X==v.X and v.Y==v.Y and v.Z==v.Z and math.abs(v.X)<math.huge and math.abs(v.Y)<math.huge and math.abs(v.Z)<math.huge end
local function characterParts() return character,root,humanoid end
local function setCharacterMotion() end
local function startCFrame() return frame(startPart.Position) end
local function lobbyCFrame() return startCFrame() end
local function tell(_,kind,text,extra) if extra and extra.reasonCode then table.insert(corrections,extra.reasonCode) end end
local function sendState() end
local function creditStages(_,r,stage) awarded=math.max(awarded,stage); r.gate=math.max(r.gate,stage) end
local function finishRun() finished+=1 end
local function resetRun(_,reason,reasonCode) table.insert(resets,reasonCode or reason) end
local worldParent={FindFirstChild=function() return nil end}
local function floor(x,y,z,sx,sz,stage)
 local part={Position=vec(x,y-.5,z),Size=vec(sx,1,sz),CFrame=frame(vec(x,y-.5,z)),CanCollide=true,Parent=worldParent}
 table.insert(floorParts,part)
 if stage~=nil then courseStages[part]=stage end
 return part
end
local workspace={Gravity=196.2}
function workspace:Raycast(origin,direction)
 local best=nil
 for _,part in floorParts do
  local p=part.Position
  local top=p.Y+part.Size.Y*.5
  local distance=origin.Y-top
  if part.CanCollide and distance>=0 and distance<=-direction.Y
   and math.abs(origin.X-p.X)<=part.Size.X*.5 and math.abs(origin.Z-p.Z)<=part.Size.Z*.5 then
   if not best or distance<best.Distance then best={Instance=part,Distance=distance,Normal=vec(0,1,0),Position=vec(origin.X,top,origin.Z)} end
  end
 end
 return best
end
'''
code+='\nlocal TowerRules=(function()\n'+rules+'\nend)()\n'
code+=between('local function rootToFeet(', 'local function lobbyCFrame(')
code+=between('local function teleport(', 'local function refreshLeaderstats(')
code+=between('local function intersectsBox(', 'local function creditStages(')
code+=between('local supportOffsets =', 'local function updateCourseMotion(')
code+=between('local function isActive(', 'local function snapshot(')
code+=between('local function updateCourseMotion(', 'local function correctMovement(')
code+=between('local function correctMovement(', 'local function applyLighting(')
code+=between('local function handleCharacter(', 'local function playerAdded(')
code+=between('local function resetRun(', '-- Swept boxes').replace('local function resetRun(', 'local function actualResetRun(')
code+=r'''
local function setup(y)
 timestamp=0 floorParts={} courseStages={} hazards={} awarded=0 finished=0 resets={} corrections={}
 boundsPart={CFrame=frame(vec(0,0,0)),Size=vec(2000,2000,2000)} courseMotion=nil
 root={Position=vec(0,y or 3,0),Size=vec(2,2,1),AssemblyLinearVelocity=vec(0,0,0),CFrame=frame(vec(0,y or 3,0))}
 humanoid={Health=100,HipHeight=2,RigType='R15',GetState=function() return 'Running' end}
 character={PivotTo=function(_,target) root.Position=target.Position; root.CFrame=target end}
 player={attributes={},SetAttribute=function(self,key,value) self.attributes[key]=value end}
 record={lastUpdraft=-100,lastReset=-100,gate=0,updraftAirUsed=false}
 roster={[player]=record}
 teleport(player,frame(root.Position),false)
 record.graceUntil=0 record.airStartedAt=0
 return record
end
local function sample(dt,x,y,z,vy)
 timestamp+=dt
 root.Position=vec(x,y,z or 0) root.CFrame=frame(root.Position)
 root.AssemblyLinearVelocity=vec(0,vy or 0,0)
 validateRacer(player,record,timestamp)
end
local function step(dt,x,y,vy) sample(dt,x,y,0,vy) end
local function healthy(label) check(#resets==0 and #corrections==0,label) end

-- Human movement: pause, walk backwards, edge stand, jump with network bursts.
setup() local base=floor(0,0,0,300,40,0)
for i=1,180 do step(1/60,0,3,0) end
healthy('Three seconds standing still never expires flight')
check(record.safeSupport==base,'Only verified static landing becomes recovery anchor')
for i=1,120 do step(1/60,20-i/6,3,0) end
healthy('Walking backwards is valid')
setup() floor(0,0,0,4,4,0)
for i=1,100 do step(1/60,2.6,3,0) end
healthy('Avatar footprint may stand partly beyond a ledge')

for _,period in {.05,.1,.2,.35} do
 setup() floor(0,0,0,500,40,0)
 local captured=0 local x,y,vy=0,3,0
 for i=1,720 do
  local t=i/60
  if t-captured>=period then
   captured=t
   local flight=t%(104/196.2)
   x=math.sin(t*.35)*20
   y=3+52*flight-.5*196.2*flight*flight
   vy=52-196.2*flight
  end
  step(1/60,x,y,vy)
 end
 healthy('Repeated buffered jumps with '..period..' second replicated poses')
end

-- An approved Updraft followed by a long fall onto an earlier platform.
setup(103) floor(0,100,0,40,40,3) floor(0,0,0,200,40,0)
for i=1,30 do step(1/60,0,103,0) end
record.airOriginY=103 record.airStartedAt=timestamp record.airLaunchSpeed=88
record.ascentCredit=88^2/(2*196.2)+8 record.impulsePendingUntil=timestamp+.5
record.updraftAirUsed=true record.lastUpdraft=timestamp
for i=1,102 do
 local t=i/60 local y=103+88*t-.5*196.2*t*t
 if y<3 then y=3 end
 step(1/60,math.min(30,t*20),y,y==3 and 0 or 88-196.2*t)
end
healthy('Approved Updraft and long fall can return to an earlier course platform')
check(record.gate==3,'Falling to an earlier platform preserves earned milestone')

-- Replication correction / one inconsistent sample never hard resets.
setup() floor(0,0,0,200,40,0)
for i=1,30 do step(1/60,0,3,0) end
step(1/60,35,3,0)
for i=1,40 do step(1/60,35,3,0) end
healthy('A single bounded 35-stud correction is absorbed without a reset')
setup() floor(0,0,0,200,40,0)
for i=1,30 do step(1/60,0,3,0) end
step(1/60,0,25,0)
check(awarded==0 and finished==0,'An unsupported airborne packet cannot grant grounded progress')
step(1/60,0,3,0)
for i=1,60 do step(1/60,0,3,0) end
healthy('A transient vertical packet followed by genuine landing recovers')

-- Automatic speed/flight policing is intentionally removed at user request.
setup() base=floor(0,0,0,20,20,0) local high=floor(0,100,0,20,20,7)
for i=1,30 do step(1/60,0,3,0) end
for i=1,100 do step(1/60,0,103,0) end
healthy('Finite displacement onto a real landing never triggers an automatic flight correction')
check(awarded==7,'Real grounded progress cannot be starved by old movement evidence')
setup() floor(0,0,0,800,40,0)
for i=1,240 do step(1/60,i,3,0) end
healthy('Fast finite movement does not trigger automatic speed correction')
setup() floor(0,0,0,20,20,0)
for i=1,30 do step(1/60,0,3,0) end
for i=1,240 do step(1/60,0,10,0) end
healthy('Unsupported finite pose no longer causes a flight-based teleport')
check(awarded==0 and finished==0,'Unsupported hovering still cannot grant grounded stage or finish credit')
for i=1,240 do step(1/60,0,10+i*.2,12) end
healthy('Rising finite pose no longer causes an automatic flight correction')
check(awarded==0 and finished==0,'Airborne ascent still grants no landing rewards')
setup() base=floor(0,0,0,20,20,2)
for i=1,30 do step(1/60,0,3,0) end
step(1/60,0/0,3,0)
check(#corrections==1 and corrections[1]=='NonFinitePosition','NaN physics still invokes bounded safety recovery')
check(root.Position.Y==3 and root.Position.X==root.Position.X and record.gate==2,'Nonfinite recovery returns to verified landing and preserves earned progress')
check(#resets==0,'Finite safety recovery is distinct from a manual/course reset')

-- Precise visible finish: no pad arrival, below/above pass, or inflated radius.
local function finishScenario(x,y,z,onPad)
 setup(y) finishPad=floor(40,40,0,12,5,8)
 if not onPad then floorParts={} end
 root.Position=vec(x,y,z) record.lastPosition=root.Position record.lastWorldPosition=root.Position
 record.airOriginY=y record.airStartedAt=0
 step(.02,x,y,0)
 return finished
end
check(finishScenario(40,43,0,true)==1,'Landing inside visible finish pad ends the run')
check(finishScenario(34,43,0,true)==0,'Reaching crown apron outside exact gate does not finish')
check(finishScenario(40,34,0,false)==0,'Passing below crown cannot finish')
check(finishScenario(40,48,0,false)==0,'Flying above the finish pad cannot finish')
check(finishScenario(33.5,43,0,true)==0,'Old 2.2-stud inflated edge is no longer a finish')
setup(43) finishPad=floor(40,40,0,12,5,8)
record.lastPosition=vec(30,43,0) record.lastWorldPosition=record.lastPosition
step(.05,50,43,0)
check(finished==0,'Swept path through gate without supported arrival does not finish')

-- Hazards use real contacts, not an imagined chord across a network jump arc.
setup(10)
hazards={{Parent=true,CFrame=frame(vec(5,5,0)),Size=vec(2,1,5)}}
record.lastPosition=vec(0,8,0) record.lastWorldPosition=record.lastPosition
step(.3,10,8,0)
check(#resets==0,'Long replicated jump chord cannot invent a hazard contact')
step(.02,5,7,0)
check(#resets==1 and resets[1]=='HazardContact','Actual lower-body hazard overlap still resets with stable reason')

-- Avatar scaling uses actual feet distance for contact.
setup(5) humanoid.HipHeight=4 floor(0,0,0,20,20,0)
for i=1,90 do step(1/60,0,5,0) end
healthy('Tall R15 avatar standing contact uses HipHeight')
setup(3) humanoid.RigType='R6' humanoid.HipHeight=0
humanoid.Parent={FindFirstChild=function() return {Size=vec(1,2,1),IsA=function() return true end} end}
floor(0,0,0,20,20,0)
for i=1,90 do step(1/60,0,3,0) end
healthy('Classic R6 support includes its leg height')

-- Actual server moving-platform carry allowance and respawn-race nil guards.
setup() local shuttle=floor(0,0,0,10,10,1)
local mover={}
root.Parent=character
courseMotion={movingParts={[shuttle]=mover},RecentSupport=function() return nil end}
function courseMotion:Step()
 local delta=vec(.12,0,0)
 shuttle.Position+=delta shuttle.CFrame=frame(shuttle.Position)
 return {[mover]=frame(delta)}
end
for i=1,240 do
 timestamp+=1/60
 updateCourseMotion(timestamp)
 root.Position=vec(shuttle.Position.X,3,0) root.CFrame=frame(root.Position)
 validateRacer(player,record,timestamp)
end
healthy('Actual authored shuttle displacement is credited independently of walking')
check(#corrections==0,'Verified platform ride cannot trigger removed movement heuristics')
local before=shuttle.Position
root.AssemblyLinearVelocity=vec(0,52,0)
updateCourseMotion(timestamp+1/60)
check(shuttle.Position.X>before.X,'Server authored shuttle continues moving while an avatar jumps')
local savedRoot=root root=nil
check(pcall(updateCourseMotion,timestamp+1/60),'Missing root during respawn does not crash moving-platform heartbeat')
root=savedRoot

-- Actual lifecycle entry points must invalidate a pre-death recovery anchor.
setup() local oldSafe=floor(0,100,0,20,20,6)
record.safeSupport=oldSafe record.safeOffset=frame(vec(0,3.5,0)) record.gate=6
player.Parent=Players player.Character=character
local signal={Once=function() end,Connect=function() return {Disconnect=function() end} end}
character.WaitForChild=function(_,name) return name=='Humanoid' and humanoid or root end
character.GetDescendants=function() return {} end
character.DescendantAdded=signal character.Destroying=signal humanoid.Died=signal
handleCharacter(player,character)
check(record.safeSupport==nil and record.safeOffset==nil and record.gate==0,'Actual respawn clears old high recovery anchor and progress')
check(root.Position.Y==3,'Actual respawn returns to course start')
record.safeSupport=oldSafe record.safeOffset=frame(vec(0,3.5,0)) record.gate=6
record.groundedSince=1 record.impulsePendingUntil=100
record.resetCount=0 timestamp=10
actualResetRun(player,'Fresh attempt.','ManualRestart')
check(record.safeSupport==nil and record.safeOffset==nil and record.resetCount==1,'Actual manual restart clears old anchor exactly once')
check(record.groundedSince==nil and record.impulsePendingUntil==nil,'Actual restart clears stale ground and pending impulse state')

print('[DASHER07_MOVEMENT] PASS '..checks)
'''
target=QA/'movement-regressions.luau'
target.write_text(code,encoding='utf-8')
result=subprocess.run([str(LUAU),str(target)],capture_output=True,text=True)
print(result.stdout,end=''); print(result.stderr,end='')
if result.returncode: raise SystemExit(result.returncode)
count=int(re.search(r'\[DASHER07_MOVEMENT\] PASS (\d+)',result.stdout).group(1))
(QA/'movement-regression-results.json').write_text(json.dumps({'passed':count,'failed':0,
 'scope':'Actual complete validator, support, teleport and correction under deterministic replicated-pose/raycast mocks; not live multiplayer latency testing.',
 'sourceHashes':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['src/server/DasherServer.server.luau','src/server/TowerRules.luau']},
 'harnessSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},indent=2),encoding='utf-8')




