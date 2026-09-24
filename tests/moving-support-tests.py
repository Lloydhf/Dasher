"""Actual bounded shuttle history/contact code with rigid-transform service mocks."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
from test_paths import ROOT, QA, LUAU

server = (ROOT / 'src/server/DasherServer.server.luau').read_text(encoding='utf-8-sig')
motion = (ROOT / 'src/server/CourseMotion.luau').read_text(encoding='utf-8-sig')
rules = (ROOT / 'src/server/TowerRules.luau').read_text(encoding='utf-8-sig')
code = r'''
local checks=0
local function check(value,name) assert(value,name); checks+=1; print('PASS '..name) end
local vm={}
local function v(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
vm.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vm.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__mul=function(a,b) return v(a.X*b,a.Y*b,a.Z*b) end
vm.__index=function(a,key) if key=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local fm={}
local function frame(position,right,up,back)
 return setmetatable({Position=position,RightVector=right or v(1,0,0),UpVector=up or v(0,1,0),BackVector=back or v(0,0,1)},fm)
end
local methods={}
function methods:VectorToObjectSpace(a) return v(dot(a,self.RightVector),dot(a,self.UpVector),dot(a,self.BackVector)) end
function methods:PointToObjectSpace(a) return self:VectorToObjectSpace(a-self.Position) end
function methods:VectorToWorldSpace(a) return self.RightVector*a.X+self.UpVector*a.Y+self.BackVector*a.Z end
function methods:PointToWorldSpace(a) return self.Position+self:VectorToWorldSpace(a) end
function methods:Inverse()
 local right=v(self.RightVector.X,self.UpVector.X,self.BackVector.X)
 local up=v(self.RightVector.Y,self.UpVector.Y,self.BackVector.Y)
 local back=v(self.RightVector.Z,self.UpVector.Z,self.BackVector.Z)
 local inverse=frame(v(0,0,0),right,up,back)
 inverse.Position=inverse:VectorToWorldSpace(self.Position*-1)
 return inverse
end
function methods:ToObjectSpace(other) return self:Inverse()*other end
fm.__index=methods
fm.__mul=function(a,b)
 return frame(a:PointToWorldSpace(b.Position),a:VectorToWorldSpace(b.RightVector),a:VectorToWorldSpace(b.UpVector),a:VectorToWorldSpace(b.BackVector))
end
local Vector3={new=v,zero=v(0,0,0)}
local CFrame={new=function(x,y,z) return frame(type(x)=='table' and x or v(x or 0,y or 0,z or 0)) end}
local Enum={HumanoidStateType={Jumping='Jumping'}}
'''
code += '\nlocal Rules=(function()\n' + rules + '\nend)()\nlocal TowerRules=Rules\n'
motion = motion.replace('local Rules = require(script.Parent:WaitForChild("TowerRules"))', '')
code += '\nlocal CourseMotion=(function()\n' + motion + '\nend)()\n'
code += r'''
local part,entry,courseMotion
local currentRay=nil
local activeSince=0
local groundParams={}
local workspace={Raycast=function() return currentRay end}
local function rootToFeet() return 3.08694 end
local root,humanoid
local function fixture()
 part={Parent=true,CanCollide=true,Size=v(6,1.25,6),Position=v(14.142,76.875,29),CFrame=CFrame.new(14.142,76.875,29)}
 entry={contactParts={{part=part,offset=CFrame.new()}},contactHistory={
  {at=1.85,pose=CFrame.new(12.95,76.875,29)}, {at=2,pose=part.CFrame}},
  origin=CFrame.new(0,76.875,29),travel=v(18,0,0),period=8,dwell=1.2,phase=0}
 entry.model={Parent=true,pose=part.CFrame}
 function entry.model:GetPivot() return self.pose end
 function entry.model:PivotTo(pose) self.pose=pose; part.CFrame=pose; part.Position=pose.Position end
 courseMotion=setmetatable({movers={entry},blinks={},spinners={},movingParts={[part]=entry}},CourseMotion)
 root={Position=v(10.0269,80.5872,26.516),Size=v(2,2,1),AssemblyLinearVelocity=v(0,0,0)}
 humanoid={Jump=false,state='Running',GetState=function(self) return self.state end}
 currentRay=nil
end
'''
code += server[server.index('local supportOffsets ='):server.index('local function refreshGround(')]
code += r'''
fixture()
local hit=groundSupport(root,humanoid,{},2)
check(hit and hit.Historical and hit.Instance==part,'Captured trailing six-stud shuttle pose has exact recent authored support')
check(math.abs(hit.Distance-3.0872)<.001,'Historical support uses the actual feet-to-top plane distance')
check(hit.Normal.Y==1,'Historical support retains the actual upward surface normal')
local other={}
currentRay={Distance=3.08694,Normal=v(0,1,0),Instance=other}
check(groundSupport(root,humanoid,{},2).Instance==other,'Current physical raycast support always wins over history')
fixture()
check(groundSupport(root,humanoid,{},2.049)~=nil,'Valid support remains accepted inside the fixed0.2second history')
check(groundSupport(root,humanoid,{},2.051)==nil,'Identical pose is rejected immediately after the matching frame expires')
entry.contactHistory[#entry.contactHistory+1]={at=2.21,pose=part.CFrame}
check(groundSupport(root,humanoid,{},2.21)==nil,'New clock samples cannot renew an old stationary hovering pose')
fixture() root.Position=v(6,80.5872,26.516)
check(groundSupport(root,humanoid,{},2)==nil,'Merely being near a past shuttle without footprint overlap gives no support')
fixture() root.Position=v(10.0269,80.5872,23)
check(groundSupport(root,humanoid,{},2)==nil,'A past surface outside the other footprint axis is rejected')
fixture() root.Position=v(10.0269,81.5872,26.516)
check(groundSupport(root,humanoid,{},2)==nil,'A floor too far beneath the feet cannot grant historical support')
fixture() root.Position=v(10.0269,79.5872,26.516)
check(groundSupport(root,humanoid,{},2)==nil,'A surface above the feet cannot grant historical support')
fixture() root.AssemblyLinearVelocity=v(0,3,0)
check(groundSupport(root,humanoid,{},2)==nil,'Rising character cannot borrow a past platform contact')
fixture() root.AssemblyLinearVelocity=v(0,52,0)
check(groundSupport(root,humanoid,{},2)==nil,'Ordinary airborne jump cannot borrow historical contact')
fixture() root.AssemblyLinearVelocity=v(0,-30,0)
check(groundSupport(root,humanoid,{},2)==nil,'Fast falling character does not count as a historical landing')
fixture() humanoid.Jump=true
check(groundSupport(root,humanoid,{},2)==nil,'Queued jump detaches from historical support')
fixture() humanoid.state='Jumping'
check(groundSupport(root,humanoid,{},2)==nil,'Jumping state detaches from historical support')
fixture()
check(groundSupport(root,humanoid,{impulsePendingUntil=2.1},2)==nil,'Pending Updraft cannot recharge against a delayed surface')
check(groundSupport(root,humanoid,{impulsePendingUntil=1.9},2)~=nil,'Expired impulse protection permits a later real grounded pose')
fixture() part.CanCollide=false
check(groundSupport(root,humanoid,{},2)==nil,'Noncollidable authored parts never grant history contact')
fixture() part.Parent=nil
check(groundSupport(root,humanoid,{},2)==nil,'Destroyed surface never grants history contact')
fixture() courseMotion.movingParts[part]=nil
check(groundSupport(root,humanoid,{},2)==nil,'Unregistered or foreign surface never grants history contact')
fixture() entry.model.Parent=nil
check(groundSupport(root,humanoid,{},2)==nil,'Removed mover never grants history contact')
fixture() entry.contactHistory={}
check(groundSupport(root,humanoid,{},2)==nil,'No authored pose history means no fallback support')
fixture() entry.contactHistory={{at=2.1,pose=CFrame.new(12.95,76.875,29)}}
check(groundSupport(root,humanoid,{},2)==nil,'Future pose cannot act as historical support')
fixture() entry.contactHistory={{at=1.85,pose=frame(v(12.95,76.875,29),v(0,1,0),v(1,0,0),v(0,0,-1))}}
check(groundSupport(root,humanoid,{},2)==nil,'Vertical wall geometry cannot masquerade as an upward floor')
fixture() root.Position=v(0/0,80.5872,26.516)
check(groundSupport(root,humanoid,{},2)==nil,'Nonfinite footprint coordinates cannot pass support comparisons')
fixture() entry.contactHistory={}
for frameIndex=1,600 do courseMotion:Step(frameIndex/60) end
check(#entry.contactHistory<=13,'Actual terrain Step bounds history storage to the0.2second window')
local newest=entry.contactHistory[#entry.contactHistory]
check(newest.at==10 and (newest.pose.Position-part.Position).Magnitude<1e-6,'Actual Step records exact server-authored pose and elapsed time')
local oldest=entry.contactHistory[1]
check(10-oldest.at<=.2,'Actual Step prunes stale poses by elapsed time')
courseMotion:Step(100)
check(#entry.contactHistory==1,'A long heartbeat pause does not retain stale contact history')
print('[DASHER05_MOVING_SUPPORT] PASS '..checks)
'''
target = QA / 'moving-support-tests.luau'
target.write_text(code, encoding='utf-8')
run = subprocess.run([str(LUAU), str(target)], capture_output=True, text=True)
print(run.stdout, end='')
print(run.stderr, end='')
if run.returncode:
    raise SystemExit(run.returncode)
count = int(re.search(r'\[DASHER05_MOVING_SUPPORT\] PASS (\d+)', run.stdout).group(1))
paths = ['src/server/DasherServer.server.luau', 'src/server/CourseMotion.luau', 'src/server/TowerRules.luau']
(QA / 'moving-support-results.json').write_text(json.dumps({
    'passed': count, 'failed': 0,
    'scope': 'Actual CourseMotion history and server groundSupport with deterministic rigid-transform/raycast mocks; native replication still requires Studio validation.',
    'sourceHashes': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths},
    'harnessSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
}, indent=2), encoding='utf-8')
