-- language: Luau, file: cbae.lua, runtime: Roblox
-- target: Roblox client
-- *deep map scanner + player/NPC/interact/place browser + respawn teleport flow*
-- *hard dedup by unique name + separate NPC / Interact tabs*
-- *UI: glassy minimal, compact 320x420, sliding tab indicator, smooth via RenderStepped*

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local old = PlayerGui:FindFirstChild("cbae_gui")
if old then old:Destroy() end

--==================================================
-- CUSTOM PLACES
--==================================================

local CUSTOM_PLACES = {}

--==================================================
-- SETTINGS
--==================================================

local OFFSET = CFrame.new(3, 0, 0)
local PLACE_OFFSET = CFrame.new(0, 5, 0)
local REFRESH_INTERVAL = 2
local MAX_PLACE_RESULTS = 1000

--==================================================
-- THEME
--==================================================

local T = {
	bg          = Color3.fromRGB(12, 14, 18),
	surface     = Color3.fromRGB(20, 23, 30),
	surfaceGlass= Color3.fromRGB(26, 30, 38),
	row         = Color3.fromRGB(24, 27, 34),
	rowHover    = Color3.fromRGB(34, 38, 48),
	rowSelect   = Color3.fromRGB(28, 46, 46),
	stroke      = Color3.fromRGB(60, 72, 88),
	strokeSoft  = Color3.fromRGB(40, 48, 58),
	accent      = Color3.fromRGB(100, 220, 210),
	accentDim   = Color3.fromRGB(70, 160, 155),
	green       = Color3.fromRGB(100, 220, 160),
	blue        = Color3.fromRGB(120, 180, 240),
	red         = Color3.fromRGB(240, 110, 130),
	textMain    = Color3.fromRGB(235, 240, 245),
	textSub     = Color3.fromRGB(140, 150, 165),
	textMuted   = Color3.fromRGB(90, 100, 115),
}

--==================================================
-- SMOOTHING
--==================================================

local function smooth(current, target, speed, dt)
	return current + (target - current) * (1 - math.exp(-speed * dt))
end

local function smoothColor(current, target, speed, dt)
	return Color3.new(
		smooth(current.R, target.R, speed, dt),
		smooth(current.G, target.G, speed, dt),
		smooth(current.B, target.B, speed, dt)
	)
end

--==================================================
-- GUI ROOT
--==================================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "cbae_gui"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(320, 420)
Main.Position = UDim2.new(0.5, -160, 0.5, -210)
Main.BackgroundColor3 = T.bg
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = Gui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = T.stroke
MainStroke.Thickness = 1
MainStroke.Transparency = 0.7
MainStroke.Parent = Main

local MainGradient = Instance.new("UIGradient")
MainGradient.Rotation = 160
MainGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 21, 28)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 12, 16)),
})
MainGradient.Parent = Main

local Shadow = Instance.new("ImageLabel")
Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow.Position = UDim2.new(0.5, 0, 0.5, 6)
Shadow.Size = UDim2.new(1, 60, 1, 60)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://1316045217"
Shadow.ImageColor3 = Color3.new(0, 0, 0)
Shadow.ImageTransparency = 0.55
Shadow.ZIndex = -1
Shadow.Parent = Main

--==================================================
-- HEADER
--==================================================

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundTransparency = 1
Header.Parent = Main

local LogoDot = Instance.new("Frame")
LogoDot.Size = UDim2.fromOffset(7, 7)
LogoDot.Position = UDim2.fromOffset(16, 19)
LogoDot.BackgroundColor3 = T.accent
LogoDot.BorderSizePixel = 0
LogoDot.Parent = Header

Instance.new("UICorner", LogoDot).CornerRadius = UDim.new(1, 0)

local LogoDotGlow = Instance.new("ImageLabel")
LogoDotGlow.Size = UDim2.fromOffset(22, 22)
LogoDotGlow.Position = UDim2.fromOffset(-7, -7)
LogoDotGlow.BackgroundTransparency = 1
LogoDotGlow.Image = "rbxassetid://5028857084"
LogoDotGlow.ImageColor3 = T.accent
LogoDotGlow.ImageTransparency = 0.5
LogoDotGlow.Parent = LogoDot

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.fromOffset(30, 0)
Title.BackgroundTransparency = 1
Title.Text = "cbae"
Title.TextColor3 = T.textMain
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local function makeIconButton(parent, glyph, xOffset, hoverColor)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(24, 24)
	btn.Position = UDim2.new(1, xOffset, 0, 10)
	btn.BackgroundColor3 = T.surfaceGlass
	btn.BackgroundTransparency = 0.3
	btn.BorderSizePixel = 0
	btn.Text = glyph
	btn.TextColor3 = T.textSub
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = false
	btn.Parent = parent

	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.Color = T.strokeSoft
	stroke.Transparency = 0.5
	stroke.Parent = btn

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = hoverColor or T.surfaceGlass,
			BackgroundTransparency = 0.1,
			TextColor3 = T.textMain,
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = T.surfaceGlass,
			BackgroundTransparency = 0.3,
			TextColor3 = T.textSub,
		}):Play()
	end)

	return btn
end

local Minimize = makeIconButton(Header, "—", -58)
local Unload   = makeIconButton(Header, "✕", -30, T.red)

--==================================================
-- STATUS
--==================================================

local StatusRow = Instance.new("Frame")
StatusRow.Size = UDim2.new(1, -28, 0, 18)
StatusRow.Position = UDim2.fromOffset(14, 44)
StatusRow.BackgroundTransparency = 1
StatusRow.Parent = Main

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(5, 5)
StatusDot.Position = UDim2.fromOffset(2, 6)
StatusDot.BackgroundColor3 = T.accent
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusRow

Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -14, 1, 0)
Status.Position = UDim2.fromOffset(14, 0)
Status.BackgroundTransparency = 1
Status.Text = "ready"
Status.TextColor3 = T.textSub
Status.TextSize = 11
Status.Font = Enum.Font.GothamMedium
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = StatusRow

local statusDotTarget = T.accent

local function setStatus(text, color)
	Status.Text = text
	if color then statusDotTarget = color end
end

--==================================================
-- TABS
--==================================================

local activeTab = "NPCs"
local tabOrder = { "NPCs", "Interacts", "Places", "Players" }
local tabButtons = {}

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -28, 0, 30)
TabContainer.Position = UDim2.fromOffset(14, 66)
TabContainer.BackgroundColor3 = T.surfaceGlass
TabContainer.BackgroundTransparency = 0.45
TabContainer.BorderSizePixel = 0
TabContainer.Parent = Main

Instance.new("UICorner", TabContainer).CornerRadius = UDim.new(1, 0)

local TabStroke = Instance.new("UIStroke")
TabStroke.Color = T.strokeSoft
TabStroke.Transparency = 0.6
TabStroke.Parent = TabContainer

local TabPad = Instance.new("UIPadding")
TabPad.PaddingTop = UDim.new(0, 3)
TabPad.PaddingBottom = UDim.new(0, 3)
TabPad.PaddingLeft = UDim.new(0, 3)
TabPad.PaddingRight = UDim.new(0, 3)
TabPad.Parent = TabContainer

local TabHighlight = Instance.new("Frame")
TabHighlight.Name = "Highlight"
TabHighlight.BackgroundColor3 = T.accent
TabHighlight.BackgroundTransparency = 0.15
TabHighlight.BorderSizePixel = 0
TabHighlight.ZIndex = 1
TabHighlight.Parent = TabContainer

Instance.new("UICorner", TabHighlight).CornerRadius = UDim.new(1, 0)

for i, name in ipairs(tabOrder) do
	local btn = Instance.new("TextButton")
	btn.Name = "Tab_" .. name
	btn.Size = UDim2.new(0.25, -3, 1, 0)
	btn.Position = UDim2.new((i - 1) * 0.25, (i - 1) * 3 + 1.5, 0, 0)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Text = name
	btn.TextColor3 = T.textSub
	btn.TextSize = 10
	btn.Font = Enum.Font.GothamBold
	btn.ZIndex = 2
	btn.AutoButtonColor = false
	btn.Parent = TabContainer

	btn.MouseEnter:Connect(function()
		if activeTab ~= name then
			TweenService:Create(btn, TweenInfo.new(0.12), { TextColor3 = T.textMain }):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		if activeTab ~= name then
			TweenService:Create(btn, TweenInfo.new(0.12), { TextColor3 = T.textSub }):Play()
		end
	end)

	tabButtons[name] = btn
end

--==================================================
-- SEARCH
--==================================================

local SearchFrame = Instance.new("Frame")
SearchFrame.Size = UDim2.new(1, -28, 0, 28)
SearchFrame.Position = UDim2.fromOffset(14, 104)
SearchFrame.BackgroundColor3 = T.surfaceGlass
SearchFrame.BackgroundTransparency = 0.45
SearchFrame.BorderSizePixel = 0
SearchFrame.Parent = Main

Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(1, 0)

local SearchStroke = Instance.new("UIStroke")
SearchStroke.Color = T.strokeSoft
SearchStroke.Transparency = 0.6
SearchStroke.Parent = SearchFrame

local SearchIcon = Instance.new("TextLabel")
SearchIcon.Size = UDim2.fromOffset(24, 28)
SearchIcon.Position = UDim2.fromOffset(6, 0)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Text = "⌕"
SearchIcon.TextColor3 = T.textMuted
SearchIcon.TextSize = 14
SearchIcon.Font = Enum.Font.GothamBold
SearchIcon.Parent = SearchFrame

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -46, 1, 0)
SearchBox.Position = UDim2.fromOffset(26, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.Text = ""
SearchBox.PlaceholderText = "search…"
SearchBox.PlaceholderColor3 = T.textMuted
SearchBox.TextColor3 = T.textMain
SearchBox.TextSize = 11
SearchBox.Font = Enum.Font.GothamMedium
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = SearchFrame

local searchQuery = ""

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchQuery = string.lower(SearchBox.Text)
	refreshList()
end)

SearchBox.Focused:Connect(function()
	TweenService:Create(SearchStroke, TweenInfo.new(0.2), { Color = T.accent, Transparency = 0.2 }):Play()
end)
SearchBox.FocusLost:Connect(function()
	TweenService:Create(SearchStroke, TweenInfo.new(0.2), { Color = T.strokeSoft, Transparency = 0.6 }):Play()
end)

--==================================================
-- LIST
--==================================================

local ListFrame = Instance.new("Frame")
ListFrame.Size = UDim2.new(1, -28, 1, -202)
ListFrame.Position = UDim2.fromOffset(14, 138)
ListFrame.BackgroundColor3 = T.surface
ListFrame.BackgroundTransparency = 0.3
ListFrame.BorderSizePixel = 0
ListFrame.Parent = Main

Instance.new("UICorner", ListFrame).CornerRadius = UDim.new(0, 12)

local ListStroke = Instance.new("UIStroke")
ListStroke.Color = T.strokeSoft
ListStroke.Transparency = 0.7
ListStroke.Parent = ListFrame

local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(1, 0, 1, 0)
List.BackgroundTransparency = 1
List.BorderSizePixel = 0
List.ScrollBarThickness = 2
List.ScrollBarImageColor3 = T.stroke
List.ScrollBarImageTransparency = 0.4
List.CanvasSize = UDim2.new()
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.ScrollingDirection = Enum.ScrollingDirection.Y
List.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
List.Parent = ListFrame

local ListPad = Instance.new("UIPadding")
ListPad.PaddingTop = UDim.new(0, 6)
ListPad.PaddingBottom = UDim.new(0, 6)
ListPad.PaddingLeft = UDim.new(0, 6)
ListPad.PaddingRight = UDim.new(0, 6)
ListPad.Parent = List

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 3)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = List

local EmptyLabel = Instance.new("TextLabel")
EmptyLabel.Size = UDim2.new(1, -20, 0, 20)
EmptyLabel.Position = UDim2.new(0.5, 0, 0.5, -10)
EmptyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.Text = "no results"
EmptyLabel.TextColor3 = T.textMuted
EmptyLabel.TextSize = 11
EmptyLabel.Font = Enum.Font.GothamMedium
EmptyLabel.Visible = false
EmptyLabel.ZIndex = 5
EmptyLabel.Parent = ListFrame

--==================================================
-- TELEPORT BUTTON
--==================================================

local Teleport = Instance.new("TextButton")
Teleport.Size = UDim2.new(1, -28, 0, 38)
Teleport.Position = UDim2.new(0, 14, 1, -50)
Teleport.BackgroundColor3 = T.accent
Teleport.BackgroundTransparency = 0.1
Teleport.BorderSizePixel = 0
Teleport.Text = "Intercept Spawn"
Teleport.TextColor3 = Color3.fromRGB(8, 24, 20)
Teleport.TextSize = 12
Teleport.Font = Enum.Font.GothamBold
Teleport.AutoButtonColor = false
Teleport.Parent = Main

Instance.new("UICorner", Teleport).CornerRadius = UDim.new(1, 0)

local TeleportGradient = Instance.new("UIGradient")
TeleportGradient.Rotation = 90
TeleportGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 240, 220)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 200, 190)),
})
TeleportGradient.Parent = Teleport

Teleport.MouseEnter:Connect(function()
	TweenService:Create(Teleport, TweenInfo.new(0.15), { BackgroundTransparency = 0 }):Play()
end)
Teleport.MouseLeave:Connect(function()
	TweenService:Create(Teleport, TweenInfo.new(0.15), { BackgroundTransparency = 0.1 }):Play()
end)

--==================================================
-- TOASTS
--==================================================

local ToastHolder = Instance.new("Frame")
ToastHolder.AnchorPoint = Vector2.new(0.5, 1)
ToastHolder.Position = UDim2.new(0.5, 0, 1, -12)
ToastHolder.Size = UDim2.new(1, -40, 0, 80)
ToastHolder.BackgroundTransparency = 1
ToastHolder.Parent = Gui

local ToastLayout = Instance.new("UIListLayout")
ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ToastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
ToastLayout.SortOrder = Enum.SortOrder.LayoutOrder
ToastLayout.Padding = UDim.new(0, 5)
ToastLayout.Parent = ToastHolder

local toastOrder = 0
local function toast(text, color)
	toastOrder += 1
	local t = Instance.new("Frame")
	t.Size = UDim2.fromOffset(220, 32)
	t.BackgroundColor3 = T.surfaceGlass
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.LayoutOrder = toastOrder
	t.Parent = ToastHolder

	Instance.new("UICorner", t).CornerRadius = UDim.new(1, 0)

	local s = Instance.new("UIStroke")
	s.Color = color or T.accent
	s.Transparency = 1
	s.Parent = t

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -18, 1, 0)
	lbl.Position = UDim2.fromOffset(10, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = T.textMain
	lbl.TextSize = 11
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextTransparency = 1
	lbl.Parent = t

	local ti = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(t, ti, { BackgroundTransparency = 0.2 }):Play()
	TweenService:Create(s, ti, { Transparency = 0.4 }):Play()
	TweenService:Create(lbl, ti, { TextTransparency = 0 }):Play()

	task.delay(2.0, function()
		local to = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(t, to, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(s, to, { Transparency = 1 }):Play()
		TweenService:Create(lbl, to, { TextTransparency = 1 }):Play()
		task.wait(0.25)
		t:Destroy()
	end)
end

--==================================================
-- STATE
--==================================================

local selectedTarget = nil
local traveling = false
local cancelTravel = false
local dead = false
local minimized = false
local connections = {}
local cachedPlaces = nil
local scanInProgress = false

--==================================================
-- DRAG
--==================================================

local dragging = false
local dragStartMouse = nil
local dragStartPos = nil
local dragTargetPos = nil
local currentPos = nil

Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStartMouse = input.Position
		dragStartPos = Main.Position
		dragTargetPos = Main.Position
		currentPos = Main.Position
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartMouse
		dragTargetPos = UDim2.new(
			dragStartPos.X.Scale,
			dragStartPos.X.Offset + delta.X,
			dragStartPos.Y.Scale,
			dragStartPos.Y.Offset + delta.Y
		)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

--==================================================
-- CHARACTER HELPERS
--==================================================

local function getMyCharacter()
	local c = LocalPlayer.Character
	if c and c.Parent then return c end
	return nil
end

local function getMyRoot()
	local c = getMyCharacter()
	if not c then return nil end
	return c:FindFirstChild("HumanoidRootPart")
end

local function getMyHumanoid()
	local c = getMyCharacter()
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid")
end

local function cleanName(name)
	name = tostring(name)
	name = name:gsub("_", " ")
	name = name:gsub("%-", " ")
	name = name:gsub("%s+", " ")
	return name:match("^%s*(.-)%s*$")
end

local function getObjectCFrame(obj)
	if not obj or not obj.Parent then return nil end
	if obj:IsA("BasePart") then return obj.CFrame end
	if obj:IsA("Model") then
		local ok, pivot = pcall(function() return obj:GetPivot() end)
		if ok and typeof(pivot) == "CFrame" then return pivot end
		if obj.PrimaryPart then return obj.PrimaryPart.CFrame end
		local part = obj:FindFirstChildWhichIsA("BasePart", true)
		if part then return part.CFrame end
	end
	return nil
end

--==================================================
-- NPC SCANNER
--==================================================

local function getNPCs()
	local results, seenModels, seenNames = {}, {}, {}

	local function addEntry(name, obj, cf)
		local key = string.lower(name)
		if seenNames[key] then return end
		seenNames[key] = true
		table.insert(results, { name = name, obj = obj, cf = cf })
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Humanoid") then
			local model = obj.Parent
			if model and model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
				local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
				if root and not seenModels[model] then
					seenModels[model] = true
					addEntry(cleanName(model.Name), model, root.CFrame)
				end
			end
		end
	end

	table.sort(results, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
	return results
end

--==================================================
-- INTERACT SCANNER
--==================================================

local function getInteracts()
	local results, seenModels, seenNames = {}, {}, {}

	local function addEntry(name, obj, cf)
		local key = string.lower(name)
		if seenNames[key] then return end
		seenNames[key] = true
		table.insert(results, { name = name, obj = obj, cf = cf })
	end

	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") or prompt:IsA("ClickDetector") then
			local holder = prompt.Parent
			if holder then
				local model = holder:FindFirstAncestorOfClass("Model") or holder
				if not seenModels[model] and not Players:GetPlayerFromCharacter(model) then
					local cf = getObjectCFrame(model)
					if cf then
						local name = cleanName(model.Name)
						if prompt:IsA("ProximityPrompt") then
							if prompt.ObjectText ~= "" and prompt.ActionText ~= "" then
								name = cleanName(prompt.ObjectText .. " - " .. prompt.ActionText)
							elseif prompt.ObjectText ~= "" then
								name = cleanName(prompt.ObjectText)
							elseif prompt.ActionText ~= "" then
								name = cleanName(prompt.ActionText)
							end
						end
						addEntry(name, model, cf)
						seenModels[model] = true
					end
				end
			end
		end
	end

	table.sort(results, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
	return results
end

--==================================================
-- PLACE SCANNER
--==================================================

local ALLOWED_PLACE_KEYWORDS = { "village", "shrine" }
local EXCLUDED_KEYWORDS = { "wall", "fence", "barrier", "gate", "door", "border", "partition" }

local function isExcluded(name)
	local lower = string.lower(name)
	for _, w in ipairs(EXCLUDED_KEYWORDS) do
		if string.find(lower, w, 1, true) then return true end
	end
	return false
end

local function containsPlaceKeyword(name)
	local lower = string.lower(cleanName(name))
	if isExcluded(lower) then return false end
	for _, kw in ipairs(ALLOWED_PLACE_KEYWORDS) do
		if string.find(lower, kw, 1, true) then return true end
	end
	return false
end

local function performDeepScan()
	if scanInProgress then return cachedPlaces or {} end
	scanInProgress = true

	local places, seenNames = {}, {}

	local function addPlace(obj, name, isCustom)
		if #places >= MAX_PLACE_RESULTS then return end
		local cf = typeof(obj) == "CFrame" and obj or getObjectCFrame(obj)
		if not cf then return end
		local cleaned = cleanName(name)
		local key = string.lower(cleaned)
		if seenNames[key] then return end
		seenNames[key] = true
		table.insert(places, {
			name = cleaned, cf = cf, isCustom = isCustom == true,
			instance = obj,
		})
	end

	for name, cf in pairs(CUSTOM_PLACES) do
		addPlace(cf, name, true)
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if containsPlaceKeyword(obj.Name) then
			if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
				addPlace(obj, obj.Name, false)
			end
		end
	end

	table.sort(places, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)

	cachedPlaces = places
	scanInProgress = false
	return places
end

local function getPlaces()
	if cachedPlaces then return cachedPlaces end
	return performDeepScan()
end

--==================================================
-- TELEPORT ENGINE
--==================================================

local function resolveTargetCFrame(targetInfo)
	if not targetInfo then return nil end

	if targetInfo.type == "Player" then
		local p = targetInfo.obj
		if p and p.Character then
			local root = p.Character:FindFirstChild("HumanoidRootPart")
			if root then return root.CFrame * OFFSET end
		end
	elseif targetInfo.type == "NPC" or targetInfo.type == "Interact" then
		local model = targetInfo.obj
		if model and model.Parent then
			local cf = getObjectCFrame(model)
			if cf then return cf * OFFSET end
		end
	elseif targetInfo.type == "Place" then
		if typeof(targetInfo.obj) == "CFrame" then
			return targetInfo.obj * PLACE_OFFSET
		end
	end
	return nil
end

local function executeTeleport(targetInfo)
	local char, hum = getMyCharacter(), getMyHumanoid()
	if not char or not hum then return false, "Character unavailable" end

	local destCF = resolveTargetCFrame(targetInfo)
	if not destCF then return false, "Target location missing or invalid" end

	setStatus("intercepting respawn…", T.red)

	local newChar = nil
	local startTime = os.clock()
	local conn

	conn = LocalPlayer.CharacterAdded:Connect(function(c) newChar = c end)
	hum.Health = 0

	while not newChar do
		if dead or cancelTravel then
			if conn then conn:Disconnect() end
			return false, cancelTravel and "Cancelled" or "Unloaded"
		end
		if os.clock() - startTime > 12 then
			if conn then conn:Disconnect() end
			return false, "Respawn timeout"
		end
		task.wait(0.05)
	end

	if conn then conn:Disconnect() end
	if dead or cancelTravel then
		return false, cancelTravel and "Cancelled" or "Unloaded"
	end

	local root = newChar:WaitForChild("HumanoidRootPart", 5)
	if not root then return false, "Root part failed to load" end

	RunService.Stepped:Wait()
	if dead or cancelTravel then
		return false, cancelTravel and "Cancelled" or "Unloaded"
	end

	if targetInfo.type == "Player" or targetInfo.type == "NPC" or targetInfo.type == "Interact" then
		local refreshed = resolveTargetCFrame(targetInfo)
		if refreshed then destCF = refreshed end
	end

	if not destCF then return false, "Destination disappeared" end

	newChar:PivotTo(destCF)
	return true
end

--==================================================
-- LIST RENDERING
--==================================================

local orderCounter = 10
local refreshList
local rowAnimators = {}

local function matchesSearch(name)
	if searchQuery == "" then return true end
	return string.find(string.lower(name), searchQuery, 1, true) ~= nil
end

local function createActionButton(text, color, action)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = color
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(8, 24, 20)
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamBold
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.AutoButtonColor = false
	btn.LayoutOrder = (action == "SavePos") and 1 or 2
	btn.Parent = List

	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

	local bp = Instance.new("UIPadding")
	bp.PaddingLeft = UDim.new(0, 14)
	bp.Parent = btn

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.15 }):Play()
	end)

	btn.Activated:Connect(function()
		if dead or traveling then return end

		if action == "SavePos" then
			local root = getMyRoot()
			if root then
				local count = 1
				for savedName in pairs(CUSTOM_PLACES) do
					if string.match(savedName, "^Saved Place %d+$") then count += 1 end
				end
				local saveName = "Saved Place " .. count
				CUSTOM_PLACES[saveName] = root.CFrame
				cachedPlaces = nil
				setStatus("saved " .. saveName, T.green)
				toast("saved " .. saveName, T.green)
				refreshList()
			else
				setStatus("failed to save", T.red)
			end
		elseif action == "Rescan" then
			setStatus("scanning…", T.blue)
			cachedPlaces = nil
			task.spawn(function()
				performDeepScan()
				if not dead then
					setStatus("scan complete", T.green)
					toast("scan complete", T.green)
					refreshList()
				end
			end)
		end
	end)
end

local function createListButton(name, targetData)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 34)
	button.BackgroundColor3 = T.row
	button.BackgroundTransparency = 0.2
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = List

	orderCounter += 1
	button.LayoutOrder = orderCounter

	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke")
	stroke.Color = T.strokeSoft
	stroke.Transparency = 0.7
	stroke.Parent = button

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(0, 2, 1, -14)
	accentBar.Position = UDim2.fromOffset(0, 7)
	accentBar.BackgroundColor3 = T.accent
	accentBar.BorderSizePixel = 0
	accentBar.BackgroundTransparency = 1
	accentBar.Parent = button

	Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -20, 1, 0)
	nameLabel.Position = UDim2.fromOffset(14, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = T.textMain
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = button

	local state = {
		btn = button, stroke = stroke, accentBar = accentBar, nameLabel = nameLabel,
		hovered = false, targetData = targetData,
	}

	button.MouseEnter:Connect(function() state.hovered = true end)
	button.MouseLeave:Connect(function() state.hovered = false end)

	table.insert(rowAnimators, state)

	button.Activated:Connect(function()
		if dead or traveling then return end
		selectedTarget = targetData
		setStatus("locked: " .. name)
		refreshList()
	end)
end

--==================================================
-- REFRESH LIST
--==================================================

refreshList = function()
	if dead then return end

	orderCounter = 10
	rowAnimators = {}

	for _, child in ipairs(List:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local total = 0

	if activeTab == "Players" then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local dn, un = player.DisplayName, player.Name
				if matchesSearch(dn) or matchesSearch(un) then
					createListButton(dn, {
						type = "Player", obj = player, name = dn,
					})
					total += 1
				end
			end
		end
	elseif activeTab == "NPCs" then
		for _, entry in ipairs(getNPCs()) do
			if matchesSearch(entry.name) then
				createListButton(entry.name, {
					type = "NPC", obj = entry.obj, name = entry.name,
				})
				total += 1
			end
		end
	elseif activeTab == "Interacts" then
		for _, entry in ipairs(getInteracts()) do
			if matchesSearch(entry.name) then
				createListButton(entry.name, {
					type = "Interact", obj = entry.obj, name = entry.name,
				})
				total += 1
			end
		end
	elseif activeTab == "Places" then
		if searchQuery == "" then
			createActionButton("+ save position", T.green, "SavePos")
			createActionButton("↻ rescan", T.blue, "Rescan")
			total += 2
		end
		for index, place in ipairs(getPlaces()) do
			if index > MAX_PLACE_RESULTS then break end
			if matchesSearch(place.name) then
				createListButton(place.name, {
					type = "Place", obj = place.cf,
					instance = place.instance, name = place.name,
				})
				total += 1
			end
		end
	end

	EmptyLabel.Visible = (total == 0)
end

--==================================================
-- TAB LOGIC
--==================================================

local function updateTabHighlight()
	local btn = tabButtons[activeTab]
	if not btn then return end
	TweenService:Create(TabHighlight, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = btn.Position,
		Size = btn.Size,
	}):Play()
end

local function switchTab(tabName)
	if activeTab == tabName or traveling then return end
	activeTab = tabName

	for name, btn in pairs(tabButtons) do
		local ti = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if name == activeTab then
			TweenService:Create(btn, ti, { TextColor3 = Color3.fromRGB(8, 24, 20) }):Play()
		else
			TweenService:Create(btn, ti, { TextColor3 = T.textSub }):Play()
		end
	end

	updateTabHighlight()
	selectedTarget = nil
	setStatus("ready", T.accent)
	refreshList()
end

for name, btn in pairs(tabButtons) do
	btn.Activated:Connect(function() switchTab(name) end)
end

task.defer(function()
	local btn = tabButtons[activeTab]
	if btn then
		TabHighlight.Position = btn.Position
		TabHighlight.Size = btn.Size
		btn.TextColor3 = Color3.fromRGB(8, 24, 20)
	end
end)

--==================================================
-- MINIMIZE / UNLOAD
--==================================================

local fullSize = Main.Size
local minTweenInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

Minimize.Activated:Connect(function()
	if dead then return end
	minimized = not minimized
	if minimized then
		TweenService:Create(Main, minTweenInfo, { Size = UDim2.fromOffset(320, 44) }):Play()
	else
		TweenService:Create(Main, minTweenInfo, { Size = fullSize }):Play()
	end
	SearchFrame.Visible = not minimized
	TabContainer.Visible = not minimized
	StatusRow.Visible = not minimized
	ListFrame.Visible = not minimized
	Teleport.Visible = not minimized
end)

Unload.Activated:Connect(function()
	dead = true
	for _, conn in ipairs(connections) do
		if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
	end
	if Gui then Gui:Destroy() end
end)

--==================================================
-- TELEPORT BUTTON
--==================================================

Teleport.Activated:Connect(function()
	if dead then return end

	if traveling then
		cancelTravel = true
		Teleport.Text = "cancelling…"
		return
	end

	if not selectedTarget then
		setStatus("select a target", T.red)
		toast("select a target", T.red)
		return
	end

	traveling = true
	cancelTravel = false
	Teleport.Text = "Cancel Teleport"
	TweenService:Create(Teleport, TweenInfo.new(0.2), { BackgroundColor3 = T.red }):Play()

	task.spawn(function()
		local success, err = executeTeleport(selectedTarget)
		if dead then return end
		traveling = false
		cancelTravel = false
		Teleport.Text = "Intercept Spawn"
		TweenService:Create(Teleport, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
			BackgroundColor3 = T.accent,
		}):Play()

		if success then
			setStatus("arrived", T.green)
			toast("arrived at destination", T.green)
		else
			setStatus("failed: " .. tostring(err), T.red)
			toast("failed: " .. tostring(err), T.red)
		end
	end)
end)

--==================================================
-- MASTER RENDER LOOP
--==================================================

local statusPulseT = 0

RunService.RenderStepped:Connect(function(dt)
	if dead then return end

	if dragTargetPos and currentPos then
		local nx = smooth(currentPos.X.Offset, dragTargetPos.X.Offset, dragging and 30 or 20, dt)
		local ny = smooth(currentPos.Y.Offset, dragTargetPos.Y.Offset, dragging and 30 or 20, dt)
		currentPos = UDim2.new(dragTargetPos.X.Scale, nx, dragTargetPos.Y.Scale, ny)
		Main.Position = currentPos
	end

	for i = #rowAnimators, 1, -1 do
		local s = rowAnimators[i]
		if not s.btn.Parent then
			table.remove(rowAnimators, i)
		else
			local hovered = s.hovered
			local isSelected = false
			if selectedTarget and selectedTarget.type == s.targetData.type then
				if s.targetData.type == "Place" then
					isSelected = selectedTarget.instance == s.targetData.instance
						and selectedTarget.name == s.targetData.name
				else
					isSelected = selectedTarget.obj == s.targetData.obj
				end
			end

			local wantBg = isSelected and T.rowSelect or (hovered and T.rowHover or T.row)
			local wantText = isSelected and T.accent or T.textMain
			local wantStroke = isSelected and T.accent or T.strokeSoft
			local wantStrokeTrans = isSelected and 0.4 or (hovered and 0.3 or 0.7)
			local wantBarTrans = isSelected and 0 or 1

			s.btn.BackgroundColor3 = smoothColor(s.btn.BackgroundColor3, wantBg, 14, dt)
			s.nameLabel.TextColor3 = smoothColor(s.nameLabel.TextColor3, wantText, 14, dt)
			s.stroke.Color = smoothColor(s.stroke.Color, wantStroke, 14, dt)
			s.stroke.Transparency = smooth(s.stroke.Transparency, wantStrokeTrans, 14, dt)
			s.accentBar.BackgroundTransparency = smooth(s.accentBar.BackgroundTransparency, wantBarTrans, 14, dt)
		end
	end

	statusPulseT += dt
	StatusDot.BackgroundColor3 = smoothColor(StatusDot.BackgroundColor3, statusDotTarget, 10, dt)
	LogoDotGlow.ImageTransparency = 0.5 + math.sin(statusPulseT * 2) * 0.1
end)

--==================================================
-- AUTO REFRESH & INIT
--==================================================

task.spawn(function()
	while not dead do
		task.wait(REFRESH_INTERVAL)
		if not traveling and not scanInProgress and not minimized
			and (activeTab == "Players" or activeTab == "NPCs" or activeTab == "Interacts") then
			refreshList()
		end
	end
end)

refreshList()
task.spawn(performDeepScan)
