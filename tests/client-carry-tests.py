"""Run the release client carry block against translated platforms and bounded ray hits.
No release source is rewritten. This is not a substitute for networked Studio physics.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
from test_paths import ROOT, QA, LUAU

CLIENT = ROOT / "src/client/DasherClient.client.luau"
source = CLIENT.read_text(encoding="utf-8")
start = source.index("do\n local support, previousFrame, supportedCharacter")
end = source.index("\nlocal function applyApprovedVelocity", start)
carry = source[start:end]
source_hash = hashlib.sha256(CLIENT.read_bytes()).hexdigest()

prelude = r"""
local vectorMethods={}
local vectorMeta={}
local Vector3={}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
Vector3.zero=Vector3.new(0,0,0)
vectorMeta.__index=function(v,k)
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 return vectorMethods[k]
end
vectorMeta.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__mul=function(a,b)
 if type(a)=="number" then return Vector3.new(a*b.X,a*b.Y,a*b.Z) end
 return Vector3.new(a.X*b,a.Y*b,a.Z*b)
end
local frameMethods={}
local frameMeta={__index=frameMethods}
local CFrame={}
function CFrame.new(x,y,z)
 local position=type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0)
 return setmetatable({Position=position},frameMeta)
end
function frameMethods:PointToObjectSpace(v) return v-self.Position end
function frameMethods:PointToWorldSpace(v) return v+self.Position end
function frameMethods:Inverse() return CFrame.new(Vector3.zero-self.Position) end
frameMeta.__mul=function(a,b) return CFrame.new(a.Position+b.Position) end
local Enum={RaycastFilterType={Include="Include"},HumanoidRigType={R6="R6",R15="R15"},HumanoidStateType={Jumping="Jumping"}}
local RaycastParams={new=function() return {} end}
local actualOs=os
local clock=100
local os={clock=function() return clock end}
local function instance(class,props)
 local object=props or {} object.ClassName=class object.children={}
 function object:IsA(name) return self.ClassName==name or (self.ClassName=="Part" and name=="BasePart") end
 function object:FindFirstChild(name) return self.children[name] end
 function object:FindFirstChildOfClass(name)
  for _,child in pairs(self.children) do if child:IsA(name) then return child end end
 end
 return object
end
local parts={}
local workspace={}
local player={}
local snapshot={phase="Racing",racing=true}
local skillRequests={Updraft=-100}
local shuttleCarry={approvedUntil=-100}
function workspace:FindFirstChild(name) return self[name] end
function workspace:Raycast(origin,direction,params)
 assert(params.RespectCanCollide==true,"carry probes must respect collision")
 assert(params.FilterType==Enum.RaycastFilterType.Include,"carry probes must include only course map")
 local nearest=nil
 for _,part in ipairs(parts) do
  if part.CanCollide and part.map==params.FilterDescendantsInstances[1] then
   local p=part.CFrame.Position
   local top=p.Y+part.Size.Y*.5
   local distance=origin.Y-top
   if distance>=0 and distance<=-direction.Y and math.abs(origin.X-p.X)<=part.Size.X*.5 and math.abs(origin.Z-p.Z)<=part.Size.Z*.5 then
    if not nearest or distance<nearest.Distance then nearest={Instance=part,Normal=Vector3.new(0,part.normalY or 1,0),Distance=distance} end
   end
  end
 end
 return nearest
end
"""
checks = r"""
local checks=0
local function expect(condition,name)
 assert(condition,name) checks+=1 print("PASS "..name)
end
local function near(a,b) return math.abs(a-b)<.00001 end
local function scene(x,z,rig)
 clock=100 snapshot={phase="Racing",racing=true}
 skillRequests.Updraft=-100 shuttleCarry.approvedUntil=-100 shuttleCarry.reset()
 parts={}
 local course=instance("Folder") local map=instance("Model") map.children.Course=course workspace.ActiveMap=map
 local model=instance("Model",{Parent=course})
 model.children.Motion=instance("StringValue",{Value="Shuttle"})
 model.children.Travel=instance("Vector3Value",{Value=Vector3.new(18,0,0)})
 local pad=instance("Part",{Parent=model,map=map,Anchored=true,CanCollide=true,CanQuery=true,Size=Vector3.new(6,1,6),CFrame=CFrame.new(0,0,0)})
 table.insert(parts,pad)
 local root=instance("Part",{Size=Vector3.new(2,2,1),Position=Vector3.new(x or 0,3.5,z or 0),AssemblyLinearVelocity=Vector3.zero,Anchored=false})
 local character=instance("Model",{pivotCount=0})
 local humanoid=instance("Humanoid",{HipHeight=rig=="R6" and 0 or 2,RigType=rig or "R15",Parent=character,Health=100,Jump=false,state="Running"})
 function humanoid:GetState() return self.state end
 character.children.HumanoidRootPart=root character.children.Humanoid=humanoid
 character.children["Left Leg"]=instance("Part",{Size=Vector3.new(1,2,1)})
 function character:GetPivot() return CFrame.new(root.Position) end
 function character:PivotTo(frame) self.pivotCount+=1 root.Position=frame.Position end
 player.Character=character
 return {pad=pad,root=root,humanoid=humanoid,character=character,map=map,model=model,course=course}
end
local function move(s,dx,dy,dz)
 s.pad.CFrame=CFrame.new(s.pad.CFrame.Position+Vector3.new(dx or 0,dy or 0,dz or 0))
 clock+=.05 shuttleCarry.step()
end
local s=scene() shuttleCarry.step() move(s,3)
expect(near(s.root.Position.X,3) and s.character.pivotCount==1,"center contact carries actual platform delta")
s=scene(3.5) shuttleCarry.step() move(s,3)
expect(near(s.root.Position.X,6.5),"legitimate root-over-edge footprint still rides")
s=scene(3.55,3.55) shuttleCarry.step() move(s,0,0,2)
expect(near(s.root.Position.Z,5.55),"diagonal footprint probe preserves real corner contact")
s=scene(3.81) shuttleCarry.step() move(s,-2)
expect(near(s.root.Position.X,3.81) and s.character.pivotCount==0,"outside0.8footprint cannot attach")
s=scene(3.7,3.7) shuttleCarry.step() move(s,-1,0,-1)
expect(s.character.pivotCount==0,"diagonal outsidefootprint cannot attach")
s=scene() shuttleCarry.step() s.root.Position=Vector3.new(4,3.5,0) move(s,-1)
expect(s.character.pivotCount==0 and near(s.root.Position.X,4),"walking beyond previous edge releases carrier")
s=scene() shuttleCarry.step() s.humanoid.Jump=true move(s,2)
expect(s.character.pivotCount==0,"Jump flag detaches before transport")
s=scene() shuttleCarry.step() s.humanoid.state="Jumping" move(s,2)
expect(s.character.pivotCount==0,"Jumping state detaches before transport")
s=scene() shuttleCarry.step() s.root.AssemblyLinearVelocity=Vector3.new(0,13,0) move(s,2)
expect(s.character.pivotCount==0,"upward airborne velocity detaches")
s=scene() shuttleCarry.step() s.root.AssemblyLinearVelocity=Vector3.new(0,-13,0) move(s,2)
expect(s.character.pivotCount==0,"downward airborne velocity detaches")
s=scene() shuttleCarry.step() skillRequests.Updraft=clock move(s,2)
expect(s.character.pivotCount==0,"pending Updraft request prevents stale-floor carry")
s=scene() shuttleCarry.step() shuttleCarry.approvedUntil=clock+.2 move(s,2)
expect(s.character.pivotCount==0,"approved impulse guard prevents stale-floor carry")
s=scene() shuttleCarry.step() snapshot.finished=true move(s,2)
expect(s.character.pivotCount==0,"finished racer cannot be transported")
s=scene() shuttleCarry.step() snapshot.forfeited=true move(s,2)
expect(s.character.pivotCount==0,"forfeited racer cannot be transported")
s=scene() shuttleCarry.step() snapshot.phase="Intermission" move(s,2)
expect(s.character.pivotCount==0,"lobby phase cannot be transported")
s=scene() shuttleCarry.step() s.humanoid.Health=0 move(s,2)
expect(s.character.pivotCount==0,"dead racer cannot be transported")
s=scene() shuttleCarry.step() s.root.Anchored=true move(s,2)
expect(s.character.pivotCount==0,"anchored countdown avatar cannot be transported")
s=scene() shuttleCarry.step() s.pad.CanCollide=false move(s,2)
expect(s.character.pivotCount==0,"disappeared noncollidable floor cannot carry")
s=scene() shuttleCarry.step() s.pad.Anchored=false move(s,2)
expect(s.character.pivotCount==0,"unanchored objects cannot grant course carry")
s=scene() s.model.children.Travel.Value=Vector3.new(65,0,0) shuttleCarry.step() move(s,2)
expect(s.character.pivotCount==0,"oversized authored travel is rejected")
s=scene() shuttleCarry.step() move(s,9)
expect(s.character.pivotCount==0,"replicated single-step delta over8studs is rejected")
s=scene() s.model.children.Travel.Value=Vector3.new(2,0,0) shuttleCarry.step() move(s,3)
expect(s.character.pivotCount==0,"step cannot exceed configured total travel")
s=scene() shuttleCarry.step() move(s,0)
expect(s.character.pivotCount==0,"stationary dwell creates no artificial avatar movement")
s=scene() shuttleCarry.step()
for _=1,6 do move(s,3) end
expect(near(s.root.Position.X,18) and s.character.pivotCount==6,"6x6shuttle carries whole18studjourney without doubledelta")
s=scene() shuttleCarry.step()
for _=1,6 do s.root.Position+=Vector3.new(.1,0,0) move(s,3) end
expect(near(s.root.Position.X,18.6),"carrier preserves player-controlled movement across journey")
s=scene(4) s.root.Size=Vector3.new(8,2,8) shuttleCarry.step() move(s,-1)
expect(s.character.pivotCount==0,"oversized avatar retains0.8radiuscap")
s=scene() shuttleCarry.step() s.root.Position=Vector3.new(30,3.5,0) move(s,2)
expect(s.character.pivotCount==0 and near(s.root.Position.X,30),"teleport detaches instead of dragging avatar back")
s=scene() s.pad.normalY=.65 shuttleCarry.step() move(s,2)
expect(s.character.pivotCount==0,"non-floor ray normal cannot grant carry")
s=scene() s.root.Position=Vector3.new(0,2.9,0) shuttleCarry.step() move(s,2)
expect(s.character.pivotCount==0,"buried feet below0.55tolerance cannot grant carry")
s=scene() shuttleCarry.step() s.root.Position+=Vector3.new(0,.6,0) move(s,2)
expect(s.character.pivotCount==0,"loss of previous vertical contact detaches")
s=scene(0,0,"R6") shuttleCarry.step() move(s,2)
expect(near(s.root.Position.X,2),"R6 leg height participates in actual feet distance")
s=scene(0,0,"R6") s.character.children["Left Leg"].Size=Vector3.new(1,3,1) s.root.Position=Vector3.new(0,4.5,0) shuttleCarry.step() move(s,2)
expect(near(s.root.Position.X,2),"R6 actual longer leg determines support height")
s=scene() shuttleCarry.step()
local otherModel=instance("Model",{Parent=s.course})
otherModel.children.Motion=instance("StringValue",{Value="Shuttle"})
otherModel.children.Travel=instance("Vector3Value",{Value=Vector3.new(18,0,0)})
local other=instance("Part",{Parent=otherModel,map=s.map,Anchored=true,CanCollide=true,CanQuery=true,Size=Vector3.new(6,1,6),CFrame=CFrame.new(3,.1,0)})
table.insert(parts,other) move(s,3)
expect(s.character.pivotCount==0,"a different shuttle at proposed landing cannot authorize original delta")
s=scene() shuttleCarry.step()
local blocker=instance("Part",{map=s.map,Anchored=true,CanCollide=true,CanQuery=true,Size=Vector3.new(7,1,7),CFrame=CFrame.new(3,.1,0)})
table.insert(parts,blocker) move(s,3)
expect(s.character.pivotCount==0,"static blocker on proposed contact cannot authorize carry")
s=scene() shuttleCarry.step() local old=s.character
local replacement=instance("Model") replacement.children.HumanoidRootPart=s.root replacement.children.Humanoid=s.humanoid
function replacement:GetPivot() return CFrame.new(s.root.Position) end
function replacement:PivotTo() error("replacement must not inherit carrier") end
player.Character=replacement move(s,2)
expect(old.pivotCount==0,"replacement avatar cannot inherit old character support")
print("TOTAL "..checks)
"""

harness = QA / "client-carry-extracted.luau"
harness.write_text(prelude + "\n" + carry + "\n" + checks, encoding="utf-8")
completed = subprocess.run([str(LUAU), str(harness)], capture_output=True, text=True)
print(completed.stdout + completed.stderr)
match = re.search(r"TOTAL (\d+)", completed.stdout)
result = {
    "passed": completed.returncode == 0 and match is not None,
    "checks": int(match.group(1)) if match else 0,
    "clientSha256": source_hash,
    "carryBlockSha256": hashlib.sha256(carry.encode()).hexdigest(),
    "harnessSha256": hashlib.sha256(harness.read_bytes()).hexdigest(),
    "sourceFunctionsVerified": True,
    "nativePhysicsTested": False,
    "limitations": "Translation-only CFrames and deterministic downward AABB raycasts; no rotated movers, replication latency or full Roblox physics.",
    "stdout": completed.stdout,
    "stderr": completed.stderr,
}
(QA / "client-carry-results.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
if not result["passed"]:
    raise SystemExit(completed.returncode or 1)

readiness = Path(__file__).parent / "client-readiness-tests.luau"
readiness_source = readiness.read_text(encoding="utf-8")
for first, last in [("local function abilityReadiness(", "\nlocal function tryUpdraft()"), ("local function rankedRacers()", "\nupdateRaceBoard=function()")]:
    assert source[source.index(first):source.index(last)] in readiness_source
run = subprocess.run([str(LUAU), str(readiness)], capture_output=True, text=True)
print(run.stdout + run.stderr)
assert run.returncode == 0
(QA / "client-checks.json").write_text(json.dumps({
    "checks": 18, "passed": True, "clientSha256": source_hash,
    "harnessSha256": hashlib.sha256(readiness.read_bytes()).hexdigest(),
    "sourceFunctionsVerified": True, "details": run.stdout.strip(), "nativeUiTested": False
}, indent=2), encoding="utf-8")
