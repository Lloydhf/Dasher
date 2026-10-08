"""Run the shipped dialogue guard, content, renderer and close lifecycle in Luau."""
from pathlib import Path
from test_paths import ROOT, QA, LUAU, LUAU_COMPILE, TESTS
import json
import hashlib
import re
import subprocess

source = (ROOT / "src/client/DasherClient.client.luau").read_text(encoding="utf-8")

def extract(start, end):
    return source[source.index(start):source.index(end, source.index(start))]

functions = [
    extract("local function dialogueAllowed(state)", "local function readStationValue"),
    extract("local function dialogueNode(page,node)", "local function renderDialogueNode"),
    extract("local function renderDialogueNode(node)", "closeDialogue=function"),
    extract("closeDialogue=function", "openDialogue=function"),
]
prefix = r'''
local checks=0
local function expect(value,message) assert(value,message) checks+=1 end
local reducedMotion=false
local dialogue={active=nil,serial=0}
local ui={dialogue={},dialogueText={},dialogueButtons={{},{},{}}}
local GuiService={SelectedObject=nil}
local input="Keyboard"
local UserInputService={GetLastInputType=function() return {Name=input} end}
local workspace={CurrentCamera=nil}
local pending={}
local task={delay=function(_,f) table.insert(pending,f) end}
local TweenInfo={new=function() return {} end}
local Enum={EasingStyle={Quad="Quad"}}
local TweenService={Create=function(_,item,_,props) return {Play=function() for k,v in pairs(props) do item[k]=v end end} end}
local closeDialogue
'''
tests = r'''
for _,phase in ipairs({"Waiting","Intermission","Results"}) do expect(dialogueAllowed({phase=phase}),"Lobby phase allows conversation: "..phase) end
for _,phase in ipairs({"Racing","Countdown","Unknown",""}) do expect(not dialogueAllowed({phase=phase}),"No conversation during "..phase) end
expect(not dialogueAllowed({}),"Missing phase cannot open merchant")
for _,page in ipairs({"Shop","Inventory","Quests","Leaderboard","Unknown"}) do
 local hello,advice=dialogueNode(page,"greeting"),dialogueNode(page,"advice")
 expect(type(hello.text)=="string" and #hello.text>30,"Greeting body for "..page)
 expect(type(advice.text)=="string" and #advice.text>30,"Advice body for "..page)
 expect(hello.text~=advice.text,"Advice is a real branch for "..page)
 expect(hello.speaker==advice.speaker and hello.role==advice.role,"Speaker identity stays stable for "..page)
 expect(advice.secondary=="Back" and hello.secondary~="Back","Advice has a return choice for "..page)
 expect(hello.primary==advice.primary,"The page stays available from both branches for "..page)
 expect(#hello.primary<=14 and #hello.secondary<=14,"Choice labels fit narrow layouts for "..page)
 expect(#advice.text<=210,"Advice fits accessible speech area for "..page)
end
dialogue.active={page="Shop"}
renderDialogueNode("greeting")
expect(dialogue.active.node=="greeting" and ui.dialogueText.MaxVisibleGraphemes==0,"New greeting starts typewriter")
expect(dialogue.active.graphemes==utf8.len(ui.dialogueText.Text),"Typewriter uses text character count")
expect(ui.dialogueButtons[1].Text=="Browse trails" and ui.dialogueButtons[3].Text=="See you!","Primary and exit choices rendered")
renderDialogueNode("advice")
expect(dialogue.active.node=="advice" and ui.dialogueButtons[2].Text=="Back","Advice branch updates choices")
expect(ui.dialogueText.Text:find("once per round",1,true)~=nil,"Merchant explains real coin policy")
renderDialogueNode("greeting")
expect(ui.dialogueButtons[2].Text=="Earn coins?","Back returns to original prompt")
reducedMotion=true
renderDialogueNode("advice")
expect(ui.dialogueText.MaxVisibleGraphemes==-1,"Reduced motion reveals all speech immediately")
input="Gamepad1" renderDialogueNode("greeting")
expect(GuiService.SelectedObject==ui.dialogueButtons[1],"Gamepad selects a real choice")
input="Keyboard" reducedMotion=false
dialogue.active=nil
local old=ui.dialogueText.Text renderDialogueNode("advice")
expect(ui.dialogueText.Text==old,"Inactive renderer is harmless")

local subject={Parent=true}
local camera={CameraType="Scriptable",CameraSubject={},CFrame="closeup",Focus="merchant"}
local prompt={Parent=true,Enabled=false}
workspace.CurrentCamera=camera
local selected={IsDescendantOf=function(_,item) return item==ui.dialogue end}
local function active()
 return {camera=camera,cameraType="Custom",subject=subject,cameraFrame="original",cameraFocus="original-focus",prompt=prompt}
end
dialogue.active=active() dialogue.portraitRig={} ui.dialogue.Visible=true GuiService.SelectedObject=selected
closeDialogue(true)
expect(dialogue.active==nil and dialogue.portraitRig==nil,"Closing clears conversation and portrait state")
expect(camera.CameraType=="Custom" and camera.CameraSubject==subject,"Closing restores normal camera subject")
expect(camera.CFrame=="original" and camera.Focus=="original-focus","Closing restores the original orbit")
expect(prompt.Enabled==true and ui.dialogue.Visible==false,"Prompt re-enables and dialogue hides")
expect(GuiService.SelectedObject==nil,"Closed dialogue loses controller selection")
local serial=dialogue.serial closeDialogue(true)
expect(serial==dialogue.serial,"Closing twice is safe")

dialogue.active=active() ui.dialogue.Visible=true closeDialogue(false)
expect(ui.dialogue.Visible and ui.dialogue.GroupTransparency==1 and #pending==1,"Animated exit waits before removing view")
dialogue.serial+=1 ui.dialogue.Visible=true pending[1]()
expect(ui.dialogue.Visible,"A stale exit cannot hide a new conversation")
pending={} dialogue.active=active() ui.dialogue.Visible=true closeDialogue(false) pending[1]()
expect(not ui.dialogue.Visible,"Completed exit hides its own view")

local otherCamera={CameraType="Custom",CFrame="new-camera"}
workspace.CurrentCamera=otherCamera dialogue.active=active() closeDialogue(true)
expect(otherCamera.CFrame=="new-camera","Closing does not overwrite a replacement camera")
subject.Parent=nil workspace.CurrentCamera=camera camera.CameraSubject="replacement-subject"
dialogue.active=active() closeDialogue(true)
expect(camera.CameraSubject=="replacement-subject","Removed character is never restored as camera subject")
print("PASS "..checks.." client dialogue and lifecycle checks")
'''
test_file = QA / "client_dialogue_tests.luau"
test_file.write_text(prefix + "\n".join(functions) + tests, encoding="utf-8")
result = subprocess.run([str(LUAU), str(test_file)], capture_output=True, text=True)
check_match = re.search(r"PASS (\d+) client dialogue and lifecycle checks", result.stdout)
checks = int(check_match.group(1)) if check_match else 0
record = {
    "exit_code": result.returncode,
    "passed": result.returncode == 0 and checks > 0,
    "checks": checks,
    "stdout": result.stdout,
    "stderr": result.stderr,
    "source": "src/client/DasherClient.client.luau",
    "sourceSHA256": hashlib.sha256((ROOT / "src/client/DasherClient.client.luau").read_bytes()).hexdigest(),
    "harnessSHA256": hashlib.sha256(test_file.read_bytes()).hexdigest(),
}
(QA / "client-dialogue-results.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
print(result.stdout, end="")
print(result.stderr, end="")
raise SystemExit(result.returncode)
