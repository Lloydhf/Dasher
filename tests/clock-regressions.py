"""Exercise the shipped shared clock and actual server phase wait functions."""
from pathlib import Path
from test_paths import ROOT, QA, LUAU, LUAU_COMPILE, TESTS
import hashlib
import json
import re
import subprocess

EXE = LUAU
SERVER = ROOT / 'src/server/DasherServer.server.luau'
SHARED = ROOT / 'src/shared/RoundClock.luau'
source = SERVER.read_text(encoding='utf-8-sig')
start = source.index('local function beginPhaseClock(')
end = source.index('local function runRounds()', start)
functions = source[start:end]
code = '''
local RoundClock = require("../src/shared/RoundClock")
local checks=0
local function check(value, message) assert(value, message); checks+=1 end
local timestamp=100
local function now() return timestamp end
local phaseClock=RoundClock.New()
local timeLeft, multiplier=0, 1
local stopping=false
local players={1}
local Players={GetPlayers=function() return players end}
local ticks, step=0, .25
local RunService={Heartbeat={Wait=function()
 timestamp+=step
 ticks+=1
end}}
local sent={}
local function broadcastState()
 table.insert(sent,{deadline=phaseClock.phaseEndsAt,remaining=RoundClock.Remaining(phaseClock,now()),rate=multiplier})
end
'''+functions+'''
-- The phase starts before enrollment. Its .5s setup delay must not move the
-- visible endpoint after the first entrant already received that endpoint.
beginPhaseClock(8)
local deadline=phaseClock.phaseEndsAt
check(deadline==108 and timeLeft==8, "clock initialized before enrollment")
timestamp+=.5
check(waitPhase(8,true), "countdown completes")
check(timestamp==108, "server unlock instant equals advertised endpoint")
check(sent[1].deadline==deadline and sent[1].remaining==7.5, "snapshot includes elapsed setup delay")
check(ticks==30 and timeLeft==0, "heartbeat wait terminates once deadline reached")
check(phaseClock.clockRevision==1, "waiting never restarts initialized phase")

timestamp=200
multiplier=1.5
RoundClock.Start(phaseClock,timestamp,90,1.5)
sent={}
check(waitPhase(2), "results wait completes")
check(timestamp==202, "results are real seconds after boosted race")
check(multiplier==1 and phaseClock.multiplier==1, "non-race server and snapshot rates reset together")
check(sent[1].rate==1 and sent[1].remaining==2, "results first snapshot correct")

timestamp=300
players={}
check(not waitPhase(8), "empty server abandons countdown")
check(timestamp==300.25, "empty server exits on first heartbeat")
players={1}
stopping=true
check(not waitPhase(8), "shutdown prevents phase completion")
stopping=false
timestamp=400
step=9
check(waitPhase(8), "long server stall still exits")
check(timeLeft==0 and timestamp==409, "late server tick never creates negative time or extra countdown")
print('SERVER_PHASE_CLOCK_PASS checks='..checks)
'''
target = QA / 'server-phase-clock-extracted.luau'
target.write_text(code, encoding='utf-8')
outputs=[]
for test in (TESTS/'clock-regressions.luau', target):
    result = subprocess.run([str(EXE),str(test)],capture_output=True,text=True)
    print(result.stdout,end='')
    print(result.stderr,end='')
    if result.returncode:
        raise SystemExit(result.returncode)
    outputs.append(result.stdout)
counts=[int(re.search(r'checks=(\d+)',text).group(1)) for text in outputs]
result = {
    'version':'0.7.0','passed':sum(counts),'failed':0,
    'sharedChecks':counts[0],'serverPhaseChecks':counts[1],
    'scope':'Shipped RoundClock module, plus extracted production beginPhaseClock/waitPhase functions under deterministic heartbeat mocks. Real packet latency and engine timing still require Studio.',
    'sourceSha256':{path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in (SERVER,SHARED)},
    'harnessSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
}
(QA/'clock-regression-results.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
