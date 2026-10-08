-- Input-independent hold state. A cancelled or completed physical press must
-- be released before it can start again, including after focus/phase changes.
local ResetHold = {}
ResetHold.Duration = 1.1

function ResetHold.New()
 return {down={},active=nil,startedAt=0,context=nil,triggered=false}
end

function ResetHold.Cancel(state)
 state.active=nil state.context=nil state.startedAt=0 state.triggered=false
end

function ResetHold.Begin(state,token,now,allowed,context)
 if token==nil or state.down[token] then return false end
 state.down[token]=true
 if not allowed or state.active~=nil then return false end
 state.active=token state.startedAt=now state.context=context state.triggered=false
 return true
end

function ResetHold.Release(state,token)
 state.down[token]=nil
 if state.active==token then ResetHold.Cancel(state) end
end

function ResetHold.Step(state,now,allowed,context)
 if state.active==nil then return false,0 end
 if not allowed or state.context~=context or now<state.startedAt then
  ResetHold.Cancel(state) return false,0
 end
 local progress=math.clamp((now-state.startedAt)/ResetHold.Duration,0,1)
 if progress>=1 and not state.triggered then
  state.triggered=true return true,progress
 end
 return false,progress
end

return ResetHold
