-- Server-authored anchored terrain. Owners carry their avatars; the server validates matching ride deltas.
local Rules = require(script.Parent:WaitForChild("TowerRules"))
local CourseMotion = {}
CourseMotion.__index = CourseMotion
local CONTACT_HISTORY_SECONDS = 0.2

local function numberValue(model, name, fallback, minimum, maximum)
	local value = model:FindFirstChild(name)
	local number = value and value:IsA("NumberValue") and value.Value or fallback
	if number ~= number or math.abs(number) == math.huge then number = fallback end
	return math.clamp(number, minimum, maximum)
end

function CourseMotion.new(map)
	local self = setmetatable({movers = {}, blinks = {}, spinners = {}, movingParts = {}}, CourseMotion)
	local course = map:FindFirstChild("Course")
	if course then
		for _, model in course:GetChildren() do
			local motion = model:FindFirstChild("Motion")
			if not model:IsA("Model") or not motion or not motion:IsA("StringValue") then continue end
			local period = numberValue(model, "Period", 10, 2, 60)
			local phase = numberValue(model, "Phase", 0, -3600, 3600)
			if motion.Value == "Shuttle" then
				local travel = model:FindFirstChild("Travel")
				if travel and travel:IsA("Vector3Value") and travel.Value.Magnitude > 0 and travel.Value.Magnitude <= 64 then
					local entry = {model = model, origin = model:GetPivot(), travel = travel.Value,
						period = period, dwell = numberValue(model, "Dwell", 1.5, 0, period * 0.45), phase = phase,
						contactParts = {}, contactHistory = {}}
					table.insert(self.movers, entry)
					for _, part in model:GetDescendants() do
						if part:IsA("BasePart") and part.CanCollide then
							self.movingParts[part] = entry
							table.insert(entry.contactParts, {part = part, offset = entry.origin:ToObjectSpace(part.CFrame)})
						end
					end
				end
			elseif motion.Value == "Blink" then
				local entry = {model = model, parts = {}, period = period, phase = phase,
					onDuration = numberValue(model, "OnDuration", 5, 0.25, period - 0.25),
					warningDuration = numberValue(model, "WarningDuration", 1, 0, period)}
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						table.insert(entry.parts, {part = part, solid = part.CanCollide, color = part.Color,
							transparency = part.Transparency, material = part.Material})
					end
				end
				table.insert(self.blinks, entry)
			end
		end
	end
	local hazards = map:FindFirstChild("Hazards")
	if hazards then
		for _, model in hazards:GetChildren() do
			local motion = model:FindFirstChild("Motion")
			if model:IsA("Model") and motion and motion:IsA("StringValue") and motion.Value == "Spinner" then
				local center, bar = model:FindFirstChild("Center"), model:FindFirstChild("Bar")
				if center and center:IsA("BasePart") and bar and bar:IsA("BasePart") then
					table.insert(self.spinners, {center = center, bar = bar, offset = center.CFrame:ToObjectSpace(bar.CFrame),
						speed = numberValue(model, "AngularSpeed", 0.7, -3, 3), phase = numberValue(model, "Phase", 0, -3600, 3600)})
				end
			end
		end
	end
	return self
end

function CourseMotion:RecentSupport(position, feetDistance, radius, offsets, verticalSpeed, elapsed)
	-- Client-owned character physics and server-owned terrain replicate separately.
	-- Test the exact recent authored surface, never a widened support region or a
	-- client-reported platform. A stationary avatar left behind loses this contact
	-- as soon as the matching pose is older than this short, fixed history window.
	if math.abs(verticalSpeed) >= 12 or verticalSpeed > 2 then return nil end
	for _, mover in self.movers do
		if not mover.model.Parent then continue end
		for _, contact in mover.contactParts do
			local part = contact.part
			if not part.Parent or not part.CanCollide or self.movingParts[part] ~= mover then continue end
			for index = #mover.contactHistory, 1, -1 do
				local frame = mover.contactHistory[index]
				local age = elapsed - frame.at
				if age <= 0 or age > CONTACT_HISTORY_SECONDS then continue end
				local surface = frame.pose * contact.offset
				if (surface.Position - part.Position).Magnitude < 0.01 or surface.UpVector.Y < 0.7 then continue end
				local direction = surface:VectorToObjectSpace(Vector3.new(0, -1, 0))
				if direction.Y >= -0.7 then continue end
				local half = part.Size * 0.5
				for _, offset in offsets do
					local probe = position + offset * radius
					local origin = surface:PointToObjectSpace(probe)
					local distance = (half.Y - origin.Y) / direction.Y
					local point = origin + direction * distance
					if math.abs(point.X) <= half.X and math.abs(point.Z) <= half.Z
						and Rules.GroundContact(distance, feetDistance, surface.UpVector.Y, verticalSpeed) then
						return {Instance = part, Distance = distance, Normal = surface.UpVector,
							Position = probe + Vector3.new(0, -distance, 0), Historical = true}
					end
				end
			end
		end
	end
	return nil
end

function CourseMotion:Step(elapsed)
	local deltas = {}
	for _, entry in self.movers do
		if entry.model.Parent then
			local alpha = Rules.ShuttleAlpha(elapsed + entry.phase, entry.period, entry.dwell)
			local previous = entry.model:GetPivot()
			local target = CFrame.new(entry.travel * alpha) * entry.origin
			entry.model:PivotTo(target)
			deltas[entry] = target * previous:Inverse()
			table.insert(entry.contactHistory, {at = elapsed, pose = target})
			while entry.contactHistory[1] and elapsed - entry.contactHistory[1].at > CONTACT_HISTORY_SECONDS do
				table.remove(entry.contactHistory, 1)
			end
		end
	end
	for _, entry in self.blinks do
		local solid, warning = Rules.BlinkState(elapsed + entry.phase, entry.period, entry.onDuration, entry.warningDuration)
		if solid ~= entry.solid or warning ~= entry.warning then
			entry.solid, entry.warning = solid, warning
			entry.model:SetAttribute("StepActive", solid)
			entry.model:SetAttribute("StepWarning", warning)
			for _, original in entry.parts do
				local part = original.part
				if part.Parent then
					part.CanCollide = solid and original.solid
					part.Transparency = solid and original.transparency or math.max(original.transparency, 0.85)
					part.Color = warning and original.color:Lerp(Color3.fromRGB(255, 185, 72), 0.7) or original.color
					part.Material = warning and Enum.Material.Neon or original.material
				end
			end
		end
	end
	for _, entry in self.spinners do
		if entry.bar.Parent then
			entry.bar.CFrame = entry.center.CFrame * CFrame.Angles(0, elapsed * entry.speed + entry.phase, 0) * entry.offset
		end
	end
	return deltas
end

return CourseMotion
