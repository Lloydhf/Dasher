"""Diagnostic replay of exact authored shuttle geometry with delayed rider poses."""
from pathlib import Path
from test_paths import ROOT, QA, LUAU, LUAU_COMPILE, TESTS
import subprocess,hashlib,json,re
suite=(TESTS/'moving-support-tests.py').read_text(encoding='utf-8')
prefix=suite[:suite.index("target = QA / 'moving-support-tests.luau'")]
scope={'__file__':str(TESTS/'moving-support-tests.py')}
exec(compile(prefix,str(TESTS/'moving-support-tests.py'),'exec'),scope)
code=scope['code']+r'''
-- Reproduce the observed P042 left/back-corner pose on the actual 8s shuttle.
workspace.Raycast=function(_,origin,direction)
 local localPoint=part.CFrame:PointToObjectSpace(origin)
 local distance=localPoint.Y-part.Size.Y*.5
 if distance>=0 and distance<=-direction.Y and math.abs(localPoint.X)<=part.Size.X*.5 and math.abs(localPoint.Z)<=part.Size.Z*.5 then
  return {Instance=part,Distance=distance,Normal=v(0,1,0),Position=origin+v(0,-distance,0)}
 end
 return nil
end
for _,delay in {.1,.2,.3,.35,.4,.45,.5} do
 fixture()
 workspace.Raycast=function(_,origin,direction)
  local localPoint=part.CFrame:PointToObjectSpace(origin)
  local distance=localPoint.Y-part.Size.Y*.5
  if distance>=0 and distance<=-direction.Y and math.abs(localPoint.X)<=part.Size.X*.5 and math.abs(localPoint.Z)<=part.Size.Z*.5 then
   return {Instance=part,Distance=distance,Normal=v(0,1,0),Position=origin+v(0,-distance,0)}
  end
  return nil
 end
 local missing,longest=0,0
 for i=1,600 do
  local t=i/60
  courseMotion:Step(t)
  local lagged=entry.origin.Position+entry.travel*Rules.ShuttleAlpha(t-delay,entry.period,entry.dwell)
  root.Position=lagged+v(-2.15,part.Size.Y*.5+3.08694,-2.24)
  local hit=groundSupport(root,humanoid,{},t)
  if hit then missing=0 else missing+=1/60;longest=math.max(longest,missing) end
 end
 assert(longest==0,'Legitimate delayed shuttle corner lost support at '..delay)
 print('SHUTTLE_DELAY',delay,'LONGEST_MISSING_SUPPORT',longest)
end
'''
target=QA/'shuttle-latency-replay.luau'
target.write_text(code,encoding='utf-8')
run=subprocess.run([str(LUAU),str(target)],capture_output=True,text=True)
print(run.stdout,end='');print(run.stderr,end='')
if run.returncode==0:
    rows=[{'poseDelaySeconds':float(delay),'longestMissingSupportSeconds':float(missing)}
        for delay,missing in re.findall(r'SHUTTLE_DELAY\s+([\d.]+)\s+LONGEST_MISSING_SUPPORT\s+([\d.]+)',run.stdout)]
    assert len(rows)==7
    root=scope['ROOT']
    report={'passed':7,'failed':0,'cases':rows,
        'scope':'Exact production CourseMotion/groundSupport replay with authored P042 shuttle and corner offset; delayed poses simulated, not native network proof.',
        'limits':'Zero missing support asserted for the sampled0.1–0.5second delays on this corner/trajectory; no promise for arbitrary latency or avatars. Separate history suite rejects expired/foreign/airborne contacts.',
        'sourceHashes':{name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in
            ['src/server/DasherServer.server.luau','src/server/CourseMotion.luau','src/server/TowerRules.luau']},
        'harnessSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (QA/'shuttle-latency-results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
raise SystemExit(run.returncode)
