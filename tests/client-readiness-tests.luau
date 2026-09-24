local function abilityReadiness(ability,serverNow,lastApproved,cooldown)
 -- Rendering and input share one server-time deadline. A stale periodic
 -- `updraftReady=false` cannot add another network interval to the cooldown.
 local approvedAt=math.max(tonumber(ability.updraftAt) or 0,lastApproved or -math.huge)
 local readyAt=math.max(tonumber(ability.updraftReadyAt) or 0,approvedAt+cooldown)
 local remaining=math.max(0,readyAt-serverNow)
 local armed=ability.updraftArmed
 if armed==nil then armed=ability.updraftReady==true end
 return armed==true and remaining<=0,math.clamp(1-remaining/cooldown,0,1),remaining
end
local snapshot={}
local function rankedRacers()
 local entries,finishes={},{}
 for index,result in ipairs(snapshot.finishers or {}) do finishes[result.userId]={rank=index,time=result.time} end
 for _,racer in ipairs(snapshot.racers or {}) do table.insert(entries,racer) end
 table.sort(entries,function(a,b)
  local fa,fb=finishes[a.userId],finishes[b.userId]
  if fa or fb then return fa and (not fb or fa.rank<fb.rank) or false end
  if a.progress~=b.progress then return (a.progress or 0)>(b.progress or 0) end
  return a.userId<b.userId
 end)
 return entries,finishes
end
local checks=0
local function expect(value,message) assert(value,message) checks+=1 end
local function ready(t,at,last) return abilityReadiness(t,at,last or -math.huge,3.25) end
expect(ready({updraftArmed=true,updraftAt=100,updraftReady=false},103.25),"Cooldown completion cannot wait for a new snapshot")
expect(not ready({updraftArmed=true,updraftAt=100,updraftReady=true},103.249),"Early ready bit cannot shorten cooldown")
expect(not ready({updraftArmed=false,updraftAt=100,updraftReady=true},110),"Air-used skill requires server arming")
expect(ready({updraftArmed=true,updraftAt=0,updraftReadyAt=0},100),"Fresh race ready")
expect(not ready({updraftArmed=true,updraftAt=20},102,100),"Approved impulse masks stale snapshot")
expect(ready({updraftArmed=true,updraftAt=20},103.25,100),"Approval cooldown ends exactly")
expect(not ready({updraftArmed=true,updraftAt=20,updraftReadyAt=111},110),"Server ground rearm deadline respected")
expect(ready({updraftArmed=true,updraftAt=20,updraftReadyAt=111},111),"Ground deadline ends exactly")
expect(ready({updraftReady=true,updraftAt=20},30),"Legacy snapshot fallback supported")
expect(not ready({updraftReady=false,updraftAt=20},30),"Missing arming never grants ability")
local _,charge,left=ready({updraftArmed=true,updraftAt=100},101)
expect(math.abs(left-2.25)<.0001 and math.abs(charge-1/3.25)<.0001,"HUD and input share precise deadline")
local _,charged,remaining=ready({updraftArmed=false,updraftAt=100},110)
expect(charged==1 and remaining==0,"Full cooldown can still show land-to-rearm")
snapshot={racers={{userId=7,progress=.9},{userId=3,progress=1,finished=true},{userId=2,progress=.9},{userId=9,progress=1,finished=true}},finishers={{userId=9,time=80},{userId=3,time=81}}}
local ranked,finished=rankedRacers()
expect(ranked[1].userId==9 and ranked[2].userId==3,"Completed runners preserve finish order")
expect(ranked[3].userId==2 and ranked[4].userId==7,"Equal heights have stable ordering")
expect(finished[9].rank==1 and finished[3].time==81,"Results retain actual server times")
expect(snapshot.racers[1].userId==7,"Ranking never mutates server snapshot")
snapshot={racers={},finishers={}}
expect(#rankedRacers()==0,"Empty race safe")
snapshot={racers={},finishers={}}
for n=1,10 do table.insert(snapshot.racers,{userId=n,progress=n/10}) end
expect(#rankedRacers()==10 and rankedRacers()[1].userId==10,"Ten racer list retains all participants")
print("PASS "..checks.." client readiness and ranking checks")
