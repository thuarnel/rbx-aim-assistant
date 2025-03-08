--[=[
	Script created by thuarnel

	Features:
		- Root ESP
		- Team Check
		- Wall Check

	Contact:
		- Discord: thuarnel
		- Discord Server: https://discord.gg/wat
]=]

local env = type(getgenv) == "function" and getgenv()

if type(env.stop_root_esp) == "function" then
	env.stop_root_esp()
end

local connections = {}
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local instances = {}

local coregui = game:GetService("CoreGui")
local runtime = game:GetService("RunService")
local roots = workspace.Roots
local stop_loops = false
local camera = workspace.CurrentCamera
local spawn = task.spawn
local wait = task.wait

connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
	camera = workspace.CurrentCamera
end)

local color_scheme = {
	valid = Color3.fromRGB(38, 255, 99),
	invalid = Color3.fromRGB(255, 37, 40)
}

local beams = {}
local casting = {}
local highlights = {}
local characters = setmetatable({}, { __mode = "v" })
env.pf_chars = characters

local ui = Instance.new("ScreenGui")
ui.Name = "highlighterz"
ui.ResetOnSpawn = false
ui.Parent = coregui
table.insert(instances, ui)

local cameraPart = Instance.new("Part")
cameraPart.Anchored = true
cameraPart.CanCollide = false
cameraPart.Transparency = 1
cameraPart.Parent = workspace
table.insert(instances, cameraPart)

local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = {
	roots,
	camera
}
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function isRootVisible(root)
	local _, onScreen = camera:WorldToViewportPoint(root.Position)
	return onScreen
end

local function isRootBlocked(root)
	if not isRootVisible(root) then
		return false
	end

	local direction = (root.Position - camera.CFrame.Position).Unit * (root.Position - camera.CFrame.Position).Magnitude
	local rayResult = workspace:Raycast(camera.CFrame.Position, direction, rayParams)
	return rayResult ~= nil
end


local ghosts = Color3.fromRGB(231, 183, 88)
local phantoms = Color3.fromRGB(155, 182, 255)

local suit_ghosts = {
	["rbxassetid://5558971297"] = true,
	["rbxassetid://5614184140"] = true
}

local suit_phantoms = {
	["rbxassetid://5614184106"] = true,
	["rbxassetid://5558971356"] = true
}

local sleeves
local highlightPool = {}

local function getHighlight()
	local highlight
	if #highlightPool > 0 then
		highlight = table.remove(highlightPool)
	else
		highlight = Instance.new("Highlight")
		table.insert(instances, highlight)
	end
	highlight.Enabled = true
	return highlight
end

local function releaseHighlight(highlight)
	highlight.Enabled = false
	highlight.Adornee = nil
	highlight.Parent = nil
	table.insert(highlightPool, highlight)
end

connect(runtime.Stepped, function()
	cameraPart.CFrame = camera.CFrame - Vector3.new(0, 1, 0)
	if typeof(sleeves) ~= 'Instance' or not sleeves:IsDescendantOf(camera) then
		sleeves = camera:FindFirstChild("Sleeves", true)
	end

	local myTeam
	if sleeves then
		local texture = sleeves:FindFirstChildWhichIsA("Texture", true)
		if texture and texture:IsA("Texture") then
			if texture.Color3 == ghosts then
				myTeam = "ghosts"
			elseif texture.Color3 == phantoms then
				myTeam = "phantoms"
			end
		end
	end

	for _, root in pairs(roots:GetChildren()) do
		if typeof(root) == "Instance" and root:IsA("BasePart") then
			root.Transparency = 0

			local highlight = highlights[root]
			if not highlight then
				highlight = getHighlight()
				highlights[root] = highlight
			end

			highlight.Adornee = characters[root] or root
			highlight.Parent = ui

			for r, model in pairs(characters) do
				if not model or (not model:IsDescendantOf(workspace)) then
					highlight.Adornee = r
					characters[r] = nil
				end
			end

			if not characters[root] and (not casting[root]) then
				local rayOrigin = root.Position + Vector3.new(0, 3, 0)
				local rayDirection = Vector3.new(0, -6, 0)
				local raycastParams = RaycastParams.new()
				raycastParams.FilterDescendantsInstances = {
					workspace.Map,
					workspace.Map.MapParts
				}
				raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
				local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
				if result then
					local hitPart = result.Instance
					local hitModel = hitPart:FindFirstAncestorWhichIsA("Model")
					local hitFolder = hitPart:FindFirstAncestorWhichIsA("Folder")
					if hitFolder and hitModel then
						characters[root] = hitModel
						highlight.Adornee = hitModel
					end
				end
			end

			local character = characters[root]
			local theirTeam
			if character then
				local texture = character:FindFirstChildWhichIsA("Texture", true)
				if texture then
					if suit_ghosts[texture.Texture] then
						theirTeam = "ghosts"
					elseif suit_phantoms[texture.Texture] then
						theirTeam = "phantoms"
					end
				end
				if myTeam and theirTeam then
					highlight.Enabled = (myTeam ~= theirTeam)
				end
			end

			if isRootBlocked(root) then
				highlight.FillColor = color_scheme.invalid
				highlight.OutlineColor = color_scheme.invalid
			else
				highlight.FillColor = color_scheme.valid
				highlight.OutlineColor = color_scheme.valid
			end

			-- Handle Beam creation/updating (unchanged)
			local beam = beams[root]
			if not beam then
				local attachment0 = Instance.new("Attachment")
				attachment0.Position = Vector3.new(0, 0, 0)
				attachment0.Parent = cameraPart
				table.insert(instances, attachment0)
				local attachment1 = Instance.new("Attachment")
				attachment1.Position = Vector3.new(0, 0, 0)
				attachment1.Parent = root
				table.insert(instances, attachment1)
				beam = Instance.new("Beam")
				beam.Attachment0 = attachment0
				beam.Attachment1 = attachment1
				beam.Width0 = 0.1
				beam.Width1 = 0.1
				beam.FaceCamera = true
				beam.Color = ColorSequence.new(color_scheme.valid)
				beam.Parent = attachment0
				table.insert(instances, beam)
				beams[root] = beam
			end
			beam.Enabled = (not isRootBlocked(root)) and (myTeam and theirTeam and (myTeam ~= theirTeam))
		end
	end
end)

spawn(function()
	while not stop_loops do
		local highlightCount = 0
		for _, v in pairs(ui:GetChildren()) do
			if v:IsA("Highlight") then
				highlightCount = highlightCount + 1
				if not v.Adornee then
					releaseHighlight(v)
				elseif not highlights[v.Adornee] then
					highlights[v.Adornee] = v
				end
			end
		end

		if highlightCount > 31 then
			highlights = {}
			for _, v in pairs(ui:GetChildren()) do
				if v:IsA("Highlight") then
					releaseHighlight(v)
				end
			end
		end

		wait(.1)
	end
end)

function env.stop_root_esp()
	stop_loops = true
	for _, connection in pairs(connections) do
		if typeof(connection) == "RBXScriptConnection" and connection.Connected then
			connection:Disconnect()
		end
	end
	for _, instance in pairs(instances) do
		if typeof(instance) == "Instance" then
			instance:Destroy()
		end
	end
end