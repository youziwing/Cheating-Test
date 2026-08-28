local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local teacherBox = Drawing.new("Square")
teacherBox.Thickness = 2
teacherBox.Filled = false
teacherBox.Color = Color3.fromRGB(255, 80, 80)
teacherBox.Visible = false

local teacherName = Drawing.new("Text")
teacherName.Size = 14
teacherName.Center = true
teacherName.Outline = true
teacherName.Color = Color3.fromRGB(255, 120, 120)
teacherName.Visible = false

local teacherDist = Drawing.new("Text")
teacherDist.Size = 13
teacherDist.Center = true
teacherDist.Outline = true
teacherDist.Color = Color3.fromRGB(255, 200, 200)
teacherDist.Visible = false

local dangLine = Drawing.new("Line")
dangLine.Thickness = 2
dangLine.Color = Color3.fromRGB(255, 40, 40)
dangLine.Visible = false

local hudBg = Drawing.new("Square")
hudBg.Filled = true
hudBg.Color = Color3.fromRGB(0, 0, 0)
hudBg.Transparency = 0.55
hudBg.Visible = false

local hudTitle = Drawing.new("Text")
hudTitle.Size = 15
hudTitle.Center = false
hudTitle.Outline = true
hudTitle.Color = Color3.fromRGB(255, 255, 255)
hudTitle.Visible = false

local hudLines = {}
for i = 1, 2 do
	local t = Drawing.new("Text")
	t.Size = 13
	t.Center = false
	t.Outline = true
	t.Color = Color3.fromRGB(220, 220, 220)
	t.Visible = false
	hudLines[i] = t
end

local tris = {}
for i = 1, 60 do
	local t = Drawing.new("Triangle")
	t.Filled = true
	t.Visible = false
	t.Transparency = 0.35
	t.Color = Color3.fromRGB(255, 50, 50)
	tris[i] = t
end

local state = {
	exists = false,
	dist = 0,
	angle = 0,
	los = false,
	inCone = false,
	phoneOut = false,
	photo = false,
}

local function readCheatStatus()
	local char = lp.Character
	if not char then return false, false end
	local phoneOut, photo = false, false
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") and string.find(string.lower(c.Name), "phone") then
			phoneOut = true
			local flash = c:FindFirstChild("Phone") and c.Phone:FindFirstChild("Flash")
			if flash and (flash.Transparency < 1 or (flash:FindFirstChildOfClass("PointLight") and flash:FindFirstChildOfClass("PointLight").Enabled)) then
				photo = true
			end
			local cam = c:FindFirstChild("Phone") and c.Phone:FindFirstChild("Screen")
			local sg = cam and cam:FindFirstChild("SurfaceGui")
			local ct = sg and sg:FindFirstChild("Frame") and sg.Frame:FindFirstChild("CameraText")
			if ct and ct.Text and string.find(string.upper(ct.Text), "REC") then
				photo = true
			end
		end
	end
	return phoneOut, photo
end

task.spawn(function()
	while true do
		local teacher = Workspace:FindFirstChild("Teacher")
		local tHRP = teacher and teacher:FindFirstChild("HumanoidRootPart")
		local char = lp.Character
		local hr = char and char:FindFirstChild("HumanoidRootPart")
		if tHRP and hr then
			local tpos = tHRP.Position
			local ppos = hr.Position
			local toMe = ppos - tpos
			local dist = toMe.Magnitude
			local dot = tHRP.CFrame.LookVector:Dot(toMe.Unit)
			local ang = math.deg(math.acos(math.clamp(dot, -1, 1)))
			local inCone = (dist <= 55) and (ang <= 60)
			local los = false
			if inCone then
				local origin = tpos + Vector3.new(0, 1.6, 0)
				local target = ppos + Vector3.new(0, 1.6, 0)
				local rp = RaycastParams.new()
				rp.FilterDescendantsInstances = { teacher, char }
				rp.FilterType = Enum.RaycastFilterType.Blacklist
				los = (Workspace:Raycast(origin, target - origin, rp) == nil)
			end
			local po, ph = readCheatStatus()
			state.exists = true
			state.dist = dist
			state.angle = ang
			state.inCone = inCone
			state.los = los
			state.phoneOut = po
			state.photo = ph
		else
			state.exists = false
		end
		task.wait(0.1)
	end
end)

local CX = { .5, -.5, .5, -.5, .5, -.5, .5, -.5 }
local CY = { .5, .5, -.5, -.5, .5, .5, -.5, -.5 }
local CZ = { .5, .5, .5, .5, -.5, -.5, -.5, -.5 }

local pp, sb, hb = {}, {}, {}
for i = 1, 24 do pp[i] = {0,0}; hb[i] = {0,0} end

local cX, cY, cZ, c00, c01, c02, c10, c11, c12, c20, c21, c22
local fL, hW, hH
local pFOV, fD = -1, 1
local lastTeacher, cachedGroups

local function getGroups(c)
	if c:FindFirstChild("UpperTorso") then
		return {
			{"Head"}, {"UpperTorso","LowerTorso"},
			{"LeftUpperArm","LeftLowerArm","LeftHand"},
			{"RightUpperArm","RightLowerArm","RightHand"},
			{"LeftUpperLeg","LeftLowerLeg","LeftFoot"},
			{"RightUpperLeg","RightLowerLeg","RightFoot"},
		}
	end
	return {
		{"Head"}, {"Torso"},
		{"Left Arm"}, {"Right Arm"},
		{"Left Leg"}, {"Right Leg"},
	}
end

local function updCam(cam)
	local cf, vp, fov = cam.CFrame, cam.ViewportSize, cam.FieldOfView
	hW, hH = vp.X * .5, vp.Y * .5
	if fov ~= pFOV then pFOV = fov; fD = math.tan(math.rad(fov) * .5) end
	fL = hH / fD
	cX, cY, cZ, c00, c01, c02, c10, c11, c12, c20, c21, c22 = cf:GetComponents()
end

local function proj(x, y, z)
	local dx, dy, dz = x - cX, y - cY, z - cZ
	local lx = c00*dx + c10*dy + c20*dz
	local ly = c01*dx + c11*dy + c21*dz
	local lz = c02*dx + c12*dy + c22*dz
	local d = -lz
	if d < .01 then return 0, 0, false end
	local s = fL / d
	return hW + lx*s, hH - ly*s, true
end

local function ptLt(a, b)
	return a[1] == b[1] and a[2] < b[2] or a[1] < b[1]
end

local function cross(ax, ay, bx, by, px, py)
	return (bx - ax) * (py - ay) - (by - ay) * (px - ax)
end

local function hull(n)
	local sz = 0
	for i = 1, n do
		local x, y = sb[i][1], sb[i][2]
		while sz >= 2 and cross(hb[sz-1][1], hb[sz-1][2], hb[sz][1], hb[sz][2], x, y) <= 0 do sz -= 1 end
		sz += 1; hb[sz][1], hb[sz][2] = x, y
	end
	local le = sz + 1
	for i = n - 1, 1, -1 do
		local x, y = sb[i][1], sb[i][2]
		while sz >= le and cross(hb[sz-1][1], hb[sz-1][2], hb[sz][1], hb[sz][2], x, y) <= 0 do sz -= 1 end
		sz += 1; hb[sz][1], hb[sz][2] = x, y
	end
	return sz - 1
end

local function hideGroup(gi)
	local a = (gi - 1) * 10 + 1
	for i = a, a + 9 do tris[i].Visible = false end
end

local function procGroup(char, g, gi, isHead, isR6)
	local tb = (gi - 1) * 10 + 1
	local te = tb + 9
	local pc = 0
	for _, nm in ipairs(g) do
		local p = char:FindFirstChild(nm)
		if p and p:IsA("BasePart") then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
			local s = p.Size
			local scaleX = (isHead and isR6) and 1.2 or 1.9
			local hx = s.X * .5 * scaleX
			local hy = s.Y * .5 * 1.9
			local hz = s.Z * .5 * 1.9
			for c = 1, 8 do
				local lx, ly, lz = CX[c]*hx, CY[c]*hy, CZ[c]*hz
				local sx, sy, o = proj(
					x + r00*lx + r01*ly + r02*lz,
					y + r10*lx + r11*ly + r12*lz,
					z + r20*lx + r21*ly + r22*lz
				)
				if o then
					pc += 1
					pp[pc][1], pp[pc][2] = sx, sy
					sb[pc] = pp[pc]
				end
			end
		end
	end
	if pc < 3 then hideGroup(gi) return end
	table.sort(sb, ptLt)
	local hs = hull(pc)
	if hs < 3 then hideGroup(gi) return end
	local cx, cy = 0, 0
	for i = 1, hs do cx += hb[i][1]; cy += hb[i][2] end
	cx, cy = cx / hs, cy / hs
	local w = 0
	for i = 1, hs do
		local ni = i % hs + 1
		local idx = tb + w
		if idx > te then break end
		local t = tris[idx]
		t.PointA = Vector2.new(cx, cy)
		t.PointB = Vector2.new(hb[i][1], hb[i][2])
		t.PointC = Vector2.new(hb[ni][1], hb[ni][2])
		t.Visible = true
		w += 1
	end
	for i = tb + w, te do tris[i].Visible = false end
end

local function hideAllTris()
	for i = 1, 60 do tris[i].Visible = false end
end

local function runChams(teacher)
	if teacher ~= lastTeacher then
		cachedGroups = getGroups(teacher)
		lastTeacher = teacher
	end
	local isR6 = not teacher:FindFirstChild("UpperTorso")
	updCam(Workspace.CurrentCamera)
	for gi, g in ipairs(cachedGroups) do
		local isHead = g[1] == "Head"
		procGroup(teacher, g, gi, isHead, isR6)
	end
end

RunService.RenderStepped:Connect(function()
	local teacher = Workspace:FindFirstChild("Teacher")
	local tHRP = teacher and teacher:FindFirstChild("HumanoidRootPart")

	if not state.exists or not tHRP then
		teacherBox.Visible = false
		teacherName.Visible = false
		teacherDist.Visible = false
		dangLine.Visible = false
		hudBg.Visible = false
		hudTitle.Visible = false
		for i = 1, #hudLines do hudLines[i].Visible = false end
		hideAllTris()
		return
	end

	runChams(teacher)

	local p = tHRP.Position
	local topS, v1 = WorldToScreen(p + Vector3.new(0, 3, 0))
	local botS, v2 = WorldToScreen(p - Vector3.new(0, 3, 0))
	if v1 and v2 then
		local h = botS.Y - topS.Y
		local w = math.max(8, h * 0.5)
		teacherBox.Position = Vector2.new(topS.X - w * 0.5, topS.Y)
		teacherBox.Size = Vector2.new(w, h)
		teacherBox.Visible = true
		teacherName.Position = Vector2.new(topS.X, topS.Y - 18)
		teacherName.Text = "TEACHER"
		teacherName.Visible = true
		teacherDist.Position = Vector2.new(topS.X, botS.Y + 4)
		teacherDist.Text = string.format("%.0f studs", state.dist)
		teacherDist.Visible = true
	else
		teacherBox.Visible = false
		teacherName.Visible = false
		teacherDist.Visible = false
	end

	if state.inCone and state.los and (state.phoneOut or state.photo) then
		local char = lp.Character
		local hr = char and char:FindFirstChild("HumanoidRootPart")
		if hr then
			local a, va = WorldToScreen(tHRP.Position + Vector3.new(0, 1.6, 0))
			local b, vb = WorldToScreen(hr.Position + Vector3.new(0, 1.6, 0))
			if va and vb then
				dangLine.From = a
				dangLine.To = b
				dangLine.Visible = true
			end
		end
	else
		dangLine.Visible = false
	end

	local seenCheat = state.inCone and state.los and (state.phoneOut or state.photo)
	local watched = state.inCone and state.los
	local verdict, col
	if seenCheat then
		verdict = "DANGER: teacher SEES you cheating!"
		col = Color3.fromRGB(255, 60, 60)
	elseif watched then
		verdict = "WARNING: teacher is watching you"
		col = Color3.fromRGB(255, 200, 60)
	else
		verdict = "SAFE"
		col = Color3.fromRGB(80, 255, 120)
	end

	local x0, y0 = 16, 16
	hudBg.Position = Vector2.new(x0 - 8, y0 - 8)
	hudBg.Size = Vector2.new(300, 72)
	hudBg.Visible = true
	hudTitle.Position = Vector2.new(x0, y0)
	hudTitle.Text = "Cheat Detector"
	hudTitle.Color = col
	hudTitle.Visible = true

	local lines = {
		string.format("Verdict: %s", verdict),
		string.format("Teacher dist: %.0f  (range %d)", state.dist, 55),
	}
	for i = 1, #hudLines do
		hudLines[i].Position = Vector2.new(x0, y0 + 22 + (i - 1) * 20)
		hudLines[i].Text = lines[i]
		hudLines[i].Color = (i == 1) and col or Color3.fromRGB(220, 220, 220)
		hudLines[i].Visible = true
	end
end)
