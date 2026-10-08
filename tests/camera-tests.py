"""Execute the shipped intro planner/guard with deterministic geometry mocks."""
from pathlib import Path
from test_paths import ROOT, QA, LUAU, LUAU_COMPILE, TESTS
import hashlib, json, re, subprocess

CLIENT=ROOT / 'src/client/DasherClient.client.luau'
source=CLIENT.read_text(encoding='utf-8')
camera=source[source.index('local mapIntroCamera='):source.index('restoreCamera=function()')]
prelude=r'''
local vm,methods={},{}
local Vector3={}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
Vector3.zero=Vector3.new(0,0,0)
vm.__index=function(v,k)
 if k=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=='Unit' then return v/v.Magnitude end
 return methods[k]
end
vm.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vm.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__mul=function(a,b) if type(a)=='number' then a,b=b,a end return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vm.__div=function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
function methods:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function methods:Lerp(b,t) return self+(b-self)*t end
local function frame(pos,yaw)
 local c,s=math.cos(yaw or 0),math.sin(yaw or 0)
 local cf={Position=pos}
 function cf:VectorToObjectSpace(v) return Vector3.new(c*v.X-s*v.Z,v.Y,s*v.X+c*v.Z) end
 function cf:PointToObjectSpace(v) return self:VectorToObjectSpace(v-self.Position) end
 return cf
end
local function object(class,props)
 local v=props or {} v.class=class v.children={} v.Parent=true
 function v:IsA(name) return name==class or (class=='Part' and name=='BasePart') end
 function v:FindFirstChild(name) return self.children[name] end
 function v:GetDescendants() return self.parts or {} end
 return v
end
local function part(pos,size,query,transparency,yaw)
 return object('Part',{Position=pos,Size=size or Vector3.new(4,1,4),CFrame=frame(pos,yaw),CanQuery=query~=false,Transparency=transparency or 0})
end
local Enum={RaycastFilterType={Include='Include'}}
local RaycastParams={new=function() return {} end}
local OverlapParams={new=function() return {} end}
local workspace={}
local axes={'X','Y','Z'}
local function boxHit(p,origin,direction,radius)
 local a,b=p.CFrame:PointToObjectSpace(origin),p.CFrame:VectorToObjectSpace(direction)
 local size=p.Size*.5+Vector3.new(radius,radius,radius)
 local enter,exit=0,1
 for _,axis in ipairs(axes) do
  if math.abs(b[axis])<.00001 then if math.abs(a[axis])>size[axis] then return nil end
  else
   local u,v=(-size[axis]-a[axis])/b[axis],(size[axis]-a[axis])/b[axis]
   if u>v then u,v=v,u end enter,exit=math.max(enter,u),math.min(exit,v)
   if enter>exit then return nil end
  end
 end
 return enter*direction.Magnitude
end
function workspace:Spherecast(origin,radius,direction,params)
 local result=nil
 for _,p in ipairs(params.FilterDescendantsInstances) do
  if p.CanQuery then
   local d=boxHit(p,origin,direction,radius)
   if d and (not result or d<result.Distance) then result={Distance=d} end
  end
 end
 return result
end
function workspace:GetPartBoundsInRadius(position,radius,params)
 for _,p in ipairs(params.FilterDescendantsInstances) do
  if p.CanQuery and boxHit(p,position,Vector3.zero,radius) then return {p} end
 end
 return {}
end
'''
tests=r'''
local checks=0
local function expect(value,why) assert(value,why) checks+=1 end
local function close(a,b) return (a-b).Magnitude<.00001 end
local function scene()
 local map=object('Model',{parts={}}) local course=object('Folder') map.children.Course=course
 local start=part(Vector3.new(0,26,0),Vector3.new(4,1,4),false,1)
 local points={Vector3.new(0,23,16),Vector3.new(12,25,24),Vector3.new(24,26,16),Vector3.new(40,40,16)}
 for index,pos in ipairs(points) do
  local model=object('Model') local p=part(pos) model.children.Walkable=p
  course.children[string.format('P%03d',index)]=model table.insert(map.parts,p)
 end
 map.children.Bounds=part(Vector3.new(0,131,0),Vector3.new(152,286,152),false,1)
 table.insert(map.parts,map.children.Bounds)
 return map,start
end
local map,start=scene()
local plan=mapIntroCamera.plan(map,start)
expect(plan~=nil,'Open route has a real cinematic plan, not just fallback')
expect(plan.guard.limit==66 and #plan.guard.rays.FilterDescendantsInstances==4,'Visible course only; transparent bounds excluded')
expect(close(plan.from,Vector3.new(-20,44,-26)) and close(plan.to,Vector3.new(-12,37,-18)),'Route-facing endpoints remain inside the tower')
expect(close(plan.focus,Vector3.new(19,32.5,18)),'Focus comes from actual first four landings')
for step=0,30 do
 local desired=plan.from:Lerp(plan.to,step/30)
 local eye=mapIntroCamera.position(plan.guard,desired,plan.focus,nil)
 expect(eye~=nil and close(eye,desired),'Clear reveal sample '..step)
end
local guard=plan.guard
local eye=mapIntroCamera.position(guard,Vector3.new(72,50,92),Vector3.new(0,50,0),nil)
expect(eye~=nil and Vector3.new(eye.X,0,eye.Z).Magnitude<=66.0001,'Even an exterior request is clamped inside the tower')
expect(mapIntroCamera.position(guard,plan.focus,plan.focus,nil)==nil,'Degenerate look direction is rejected')
map.Parent=nil expect(mapIntroCamera.position(guard,plan.from,plan.focus,nil)==nil,'Unloaded map exits the cinematic') map.Parent=true

local function isolated(obstacles)
 return {map=object('Model'),center=Vector3.zero,limit=66,
 rays={FilterDescendantsInstances=obstacles},overlap={FilterDescendantsInstances=obstacles},decor=obstacles}
end
local decoration=part(Vector3.new(0,10,0),Vector3.new(2,2,2),false)
guard=isolated({decoration})
expect(mapIntroCamera.blocked(guard,Vector3.new(0,10,0)),'Nonquery decoration still blocks the lens')
expect(not mapIntroCamera.blocked(guard,Vector3.new(4,10,0)),'Distant decoration does not block empty space')
local hit=mapIntroCamera.cast(guard,Vector3.new(-10,10,0),Vector3.new(20,0,0))
expect(hit and math.abs(hit.Distance-8.15)<.00001,'Camera-only OBB catches nonquery decoration')
eye=mapIntroCamera.position(guard,Vector3.new(10,10,0),Vector3.new(-10,10,0),nil)
expect(eye and eye.X<-1.85 and eye.X>-3,'Occluded arm shortens before decoration')
expect(not mapIntroCamera.blocked(guard,eye),'Shortened eye remains clear')
expect(not mapIntroCamera.cast(guard,Vector3.new(-10,10,0),eye-Vector3.new(-10,10,0)),'Shortened eye keeps unobstructed focus')
expect(mapIntroCamera.position(guard,Vector3.new(10,10,0),Vector3.new(0,10,0),nil)==nil,'Focus inside decoration fails safely')
decoration.CFrame=frame(Vector3.new(30,10,0)) decoration.Position=decoration.CFrame.Position
expect(not mapIntroCamera.blocked(guard,Vector3.new(0,10,0)),'Moving nonquery decoration uses current transform')
decoration.Parent=nil expect(mapIntroCamera.decorDistance(guard,Vector3.new(30,10,0),Vector3.zero)==nil,'Removed decoration cannot keep blocking')

local rotated=part(Vector3.new(0,10,0),Vector3.new(12,2,1),false,0,math.pi*.5)
guard=isolated({rotated})
expect(mapIntroCamera.blocked(guard,Vector3.new(0,10,5)),'Rotated long decor uses its local box axes')
expect(not mapIntroCamera.blocked(guard,Vector3.new(5,10,0)),'Rotated short axis does not become a broad false wall')
local visibleQuery=part(Vector3.new(0,10,0),Vector3.new(2,2,2),true)
guard={map=object('Model'),center=Vector3.zero,limit=66,rays={FilterDescendantsInstances={visibleQuery}},overlap={FilterDescendantsInstances={visibleQuery}},decor={}}
expect(mapIntroCamera.blocked(guard,Vector3.new(0,10,0)),'Queryable visible geometry uses engine overlap')
expect(mapIntroCamera.cast(guard,Vector3.new(-10,10,0),Vector3.new(20,0,0))~=nil,'Queryable visible geometry uses engine shapecast')
eye=mapIntroCamera.position(guard,Vector3.new(10,10,5),Vector3.new(10,10,15),Vector3.new(-10,10,-5))
expect(eye==nil or eye.X<-1 or eye.Z<4,'Camera handoff cannot sweep through an obstacle')

map,start=scene() map.children.Course.children.P001=nil
expect(mapIntroCamera.plan(map,start)==nil,'Missing streamed first landing keeps ordinary camera')
map,start=scene() table.insert(map.parts,part(Vector3.new(0,40,0),Vector3.new(160,100,160),false))
expect(mapIntroCamera.plan(map,start)==nil,'Fully blocked map does not launch a wall-facing reveal')
print('CAMERA_CHECKS='..checks)
'''
code=prelude+camera+tests
path=QA/'camera-tests.luau';path.write_text(code,encoding='utf-8')
run=subprocess.run([str(LUAU),str(path)],capture_output=True,text=True)
print(run.stdout,end='');print(run.stderr,end='')
if run.returncode:raise SystemExit(run.returncode)
count=int(re.search(r'CAMERA_CHECKS=(\d+)',run.stdout)[1])
(QA/'camera-results.json').write_text(json.dumps(dict(passed=True,checks=count,
 clientSha256=hashlib.sha256(CLIENT.read_bytes()).hexdigest(),harnessSha256=hashlib.sha256(path.read_bytes()).hexdigest(),
 scope='Actual shipped planner and guard with deterministic queryable/nonquery rotated-box mocks. Real three-map geometry and native presentation are separate.'),indent=2)+'\n',encoding='utf-8')
