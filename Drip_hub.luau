-- ════════════════════════════════════════════════════════════════
-- Drip Hub  v1.3  |  DOORS - The Hotel
-- Executor: Any UNC-compatible (Synapse X, KRNL, Delta, Xeno, Fluxus)
-- Key provider: https://jnkie.com/get-key/driphubkeys
-- Discord:      https://discord.gg/Phy76Bg6B
--
-- VOLATILE: entity names, remote paths, room folder drift per patch
-- Entity path: workspace.CurrentRooms[RS.GameData.LatestRoom.Value]
-- ════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────
-- SERVICES
-- ────────────────────────────────────────────────
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local RS         = game:GetService("ReplicatedStorage")
local TweenSvc   = game:GetService("TweenService")
local VUser      = game:GetService("VirtualUser")

local LP  = Players.LocalPlayer
local Char, Root, Hum

local function refreshChar(c)
    Char = c or LP.Character
    Root = Char and Char:FindFirstChild("HumanoidRootPart")
    Hum  = Char and Char:FindFirstChild("Humanoid")
end
refreshChar()
LP.CharacterAdded:Connect(refreshChar)

local function alive()
    return Char and Root and Hum and Hum.Health > 0
end

-- ────────────────────────────────────────────────
-- DOORS PATHS  (VOLATILE — verify after patches)
-- ────────────────────────────────────────────────
local ROOMS_FOLD = workspace:FindFirstChild("CurrentRooms")

-- VOLATILE: entity model names — update from game decompile after patches
local ENTITY_NAMES = {
    "Rush","Ambush","Eyes","Screech","Figure","Halt",
    "Dupe","Snare","Seek","Giggle","Void","Timothy",
    "Grumble","Gloombat","Dread","Firedamp","Watcher",
}
local ENTITY_COLOR = {
    Rush    = Color3.fromRGB(255, 50,  50),
    Ambush  = Color3.fromRGB(255,120,   0),
    Seek    = Color3.fromRGB(255, 80,  20),
    Figure  = Color3.fromRGB(180,  0,   0),
    Eyes    = Color3.fromRGB(255,220,  50),
    Screech = Color3.fromRGB(255,100, 200),
    Halt    = Color3.fromRGB( 40,200, 255),
    Dupe    = Color3.fromRGB(180,130, 255),
    Snare   = Color3.fromRGB(100,200,  80),
    Giggle  = Color3.fromRGB(255,200,  80),
}
local function entityColor(n)
    return ENTITY_COLOR[n] or Color3.fromRGB(220,220,220)
end

local HIDE_NAMES = { "Closet","Wardrobe","Bed","BedUnder","Locker" }
local ITEM_NAMES = { "Key","Lockpick","Lighter","Candle","Flashlight","Vitamins","Crucifix","Lantern" }

-- VOLATILE: remote paths
local REMOTES = {
    hide    = RS:FindFirstChild("HideInSpot"),
    code    = RS:FindFirstChild("EnterCode"),
    breaker = RS:FindFirstChild("FlipBreaker"),
}
-- VOLATILE: entity warning event names
local ENTITY_EVENTS = {
    Screech="ScreechWarning", Eyes="EyesLookingAt",
    Ambush ="AmbushIncoming", Rush ="RushIncoming", Seek="SeekChase",
}

-- ────────────────────────────────────────────────
-- KEY SYSTEM
-- ────────────────────────────────────────────────
local JNKIE_API  = "1c4742c5-deb6-473a-9e62-d1670f39519e"
local KEY_URL    = "https://jnkie.com/get-key/driphubkeys"
local DISCORD    = "https://discord.gg/Phy76Bg6B"
local unlocked   = false
local menuOpen   = false

local function openURL(url)
    if syn and syn.open_url then
        syn.open_url(url)
    elseif setclipboard then
        setclipboard(url)
    end
end

local function httpGet(opts)
    local fn = (syn and syn.request)
            or (http and http.request)
            or http_request or request
    if not fn then return nil end
    local ok, res = pcall(fn, opts)
    return ok and res or nil
end

-- Validate against jnkie API
-- GET jnkie.com/api/v1/checkKey?key=X&apiKey=Y → {"success":true/false}
-- ────────────────────────────────────────────────
-- VALIDATE KEY  (fixed — case-sensitive, debug output)
-- ────────────────────────────────────────────────
local function validateKey(userKey)
    local res = httpGet({
        Url    = "https://jnkie.com/api/v1/checkKey"
                 .."?key="..userKey
                 .."&apiKey="..JNKIE_API,
        Method = "GET",
        Headers = { ["Content-Type"] = "application/json" },
    })
    if not res then return false, "no_http" end
    -- debug: print exact response so you can see what jnkie returns
    print("[DripHub] status:", res.StatusCode)
    print("[DripHub] body:", res.Body)
    if res.StatusCode ~= 200 then
        return false, "http_"..tostring(res.StatusCode)
    end
    local body = res.Body or ""
    -- match both casing variants jnkie might return
    if body:find('"success"%s*:%s*true')
    or body:find('"valid"%s*:%s*true')
    or body:find('"status"%s*:%s*"ok"')
    or body:find('"status"%s*:%s*"valid"') then
        return true
    end
    return false, body
end

-- ────────────────────────────────────────────────
-- TRY KEY  (fixed — no .upper(), only strip whitespace)
-- ────────────────────────────────────────────────
local function tryKey()
    -- strip whitespace only — DO NOT uppercase, jnkie keys are case-sensitive
    local input = ksBox.Text:gsub("%s","")
    if input == "" then
        ksStatus.TextColor3 = Color3.fromRGB(255,80,80)
        ksStatus.Text       = "✗  Paste your key first"
        return
    end
    ksUnlock.Text             = "Checking..."
    ksUnlock.BackgroundColor3 = Color3.fromRGB(60,35,140)
    ksStatus.Text             = ""
    task.spawn(function()
        local valid, err = validateKey(input)
        if valid then
            unlockSuccess()
        else
            ksUnlock.Text             = "UNLOCK"
            ksUnlock.BackgroundColor3 = Color3.fromRGB(88,48,210)
            if err == "no_http" then
                ksStatus.TextColor3 = Color3.fromRGB(255,180,50)
                ksStatus.Text       = "⚠  No HTTP — try Synapse X or Delta"
            else
                ksStatus.TextColor3 = Color3.fromRGB(255,80,80)
                ksStatus.Text       = "✗  Invalid key — tap GET KEY below"
                ksBox.BackgroundColor3 = Color3.fromRGB(38,12,12)
                shakeBox()
                task.delay(0.35, function()
                    ksBox.BackgroundColor3 = Color3.fromRGB(18,16,32)
                end)
            end
        end
    end)
end

-- ────────────────────────────────────────────────
-- FEATURE CONFIG
-- ────────────────────────────────────────────────
local cfg = {
    speedHack=false,  walkSpeed=30,
    jumpBoost=false,  jumpPower=50,
    flyEnabled=false, flySpeed=50,
    noclip=false,     noAccel=false,
    doorNoclip=true,  doorReach=false,
    fastClosetExit=false, antiAFK=true,
    autoInteract=false,   autoHide=false,
    autoBreaker=false,    autoLibCode=false,
    bruteforce=false,     bruteRate=0.004,
    antiScreech=false, antiEyes=false,
    antiAmbush=false,  antiRush=false,
    antiDupe=false,    antiSnare=false,
    antiFigure=false,  antiSeek=false,
    noDmgScreech=true, noDmgGlitch=true, noDmgHalt=true,
    espOn=false,
    espEntities=true, espEntityDist=true,
    espPlayers=true,  espDoors=true,
    espItems=true,    espGold=true,
    espChests=true,   espClosets=false,
    keyNoclip=Enum.KeyCode.N,
    keyFly   =Enum.KeyCode.F,
    keyHide  =Enum.KeyCode.Q,
    keyMenu  =Enum.KeyCode.RightShift,
}

-- ────────────────────────────────────────────────
-- ANTI-AFK
-- ────────────────────────────────────────────────
LP.Idled:Connect(function()
    if not cfg.antiAFK then return end
    VUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
    task.wait(0.1)
    VUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
end)

-- ────────────────────────────────────────────────
-- MOVEMENT
-- ────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not alive() then return end
    if cfg.speedHack then Hum.WalkSpeed = cfg.walkSpeed end
    if cfg.jumpBoost then Hum.JumpPower = cfg.jumpPower  end
    if cfg.noAccel then
        Root.AssemblyLinearVelocity =
            Vector3.new(0, Root.AssemblyLinearVelocity.Y, 0)
    end
end)

-- ────────────────────────────────────────────────
-- NOCLIP
-- ────────────────────────────────────────────────
RunService.Stepped:Connect(function()
    if not cfg.noclip or not Char then return end
    for _, p in ipairs(Char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)

-- ────────────────────────────────────────────────
-- FLY
-- ────────────────────────────────────────────────
local flyConn, flyBV, flyBG

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn=nil end
    if flyBV   then flyBV:Destroy();  flyBV=nil  end
    if flyBG   then flyBG:Destroy();  flyBG=nil  end
    if Hum     then Hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end

local function startFly()
    if not alive() then return end
    stopFly()
    flyBV = Instance.new("BodyVelocity", Root)
    flyBV.MaxForce = Vector3.new(1e9,1e9,1e9)
    flyBV.Velocity = Vector3.zero
    flyBG = Instance.new("BodyGyro", Root)
    flyBG.MaxTorque = Vector3.new(1e9,1e9,1e9)
    flyBG.D = 100
    local cam = workspace.CurrentCamera
    flyConn = RunService.RenderStepped:Connect(function()
        if not cfg.flyEnabled then stopFly(); return end
        local d = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W)         then d += cam.CFrame.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S)         then d -= cam.CFrame.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A)         then d -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D)         then d += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)     then d += Vector3.yAxis          end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then d -= Vector3.yAxis          end
        flyBV.Velocity = d.Magnitude>0 and d.Unit*cfg.flySpeed or Vector3.zero
        flyBG.CFrame   = cam.CFrame
    end)
end

-- ────────────────────────────────────────────────
-- DOOR NOCLIP  (VOLATILE: door model name pattern)
-- ────────────────────────────────────────────────
local function patchDoor(obj)
    if not cfg.doorNoclip then return end
    if obj.Name:lower():match("door") then
        for _, p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end
workspace.DescendantAdded:Connect(patchDoor)
for _, obj in ipairs(workspace:GetDescendants()) do patchDoor(obj) end

-- ────────────────────────────────────────────────
-- DOOR REACH
-- ────────────────────────────────────────────────
task.spawn(function()
    while task.wait(0.5) do
        if not cfg.doorReach then continue end
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.Parent
               and p.Parent.Name:lower():match("door") then
                p.MaxActivationDistance = 30
            end
        end
    end
end)

-- ────────────────────────────────────────────────
-- AUTO INTERACT
-- ────────────────────────────────────────────────
task.spawn(function()
    while task.wait(0.05) do
        if not cfg.autoInteract or not alive() then continue end
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and p.Enabled then
                local pp  = p.Parent
                local pos = pp and (
                    pp:IsA("BasePart") and pp.Position
                    or (pp:FindFirstChildWhichIsA("BasePart")
                        and pp:FindFirstChildWhichIsA("BasePart").Position))
                if pos and (Root.Position-pos).Magnitude
                   <= p.MaxActivationDistance+2 then
                    fireproximityprompt(p)
                end
            end
        end
    end
end)

-- ────────────────────────────────────────────────
-- NEAREST HIDE SPOT
-- ────────────────────────────────────────────────
local function nearestHide()
    if not Root then return nil end
    local best, bestD = nil, math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if table.find(HIDE_NAMES, obj.Name) then
            local part = obj:IsA("BasePart") and obj
                         or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local d = (Root.Position-part.Position).Magnitude
                if d < bestD then best, bestD = obj, d end
            end
        end
    end
    return best, bestD
end

-- ────────────────────────────────────────────────
-- AUTO HIDE
-- ────────────────────────────────────────────────
task.spawn(function()
    while task.wait(0.1) do
        if not cfg.autoHide or not alive() then continue end
        local spot, d = nearestHide()
        if spot and d < 20 and REMOTES.hide then
            REMOTES.hide:FireServer(spot)
        end
    end
end)

-- ────────────────────────────────────────────────
-- FAST CLOSET EXIT
-- ────────────────────────────────────────────────
task.spawn(function()
    while task.wait(0.1) do
        if not cfg.fastClosetExit or not alive() then continue end
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt")
               and p.ObjectText:lower():match("exit") then
                fireproximityprompt(p)
            end
        end
    end
end)

-- ────────────────────────────────────────────────
-- NO DAMAGE
-- ────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not alive() then return end
    if cfg.noDmgScreech or cfg.noDmgGlitch or cfg.noDmgHalt then
        if Hum.Health < Hum.MaxHealth then Hum.Health = Hum.MaxHealth end
    end
end)

-- ────────────────────────────────────────────────
-- ANTI ENTITY  (VOLATILE: event names)
-- ────────────────────────────────────────────────
for entityName, evName in pairs(ENTITY_EVENTS) do
    local cfgKey = "anti"..entityName
    local ev = RS:FindFirstChild(evName)
    if ev and ev:IsA("RemoteEvent") then
        ev.OnClientEvent:Connect(function()
            if not cfg[cfgKey] then return end
            local spot = nearestHide()
            if spot and REMOTES.hide then REMOTES.hide:FireServer(spot) end
        end)
    end
end

-- ────────────────────────────────────────────────
-- AUTO BREAKER  (VOLATILE: model name)
-- ────────────────────────────────────────────────
task.spawn(function()
    while task.wait(0.5) do
        if not cfg.autoBreaker or not alive() then continue end
        local box = workspace:FindFirstChild("BreakerBox", true)
        if not box then continue end
        for _, p in ipairs(box:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                fireproximityprompt(p); task.wait(0.1)
            end
        end
    end
end)

-- ────────────────────────────────────────────────
-- BRUTEFORCE CODE  (VOLATILE: remote, digit count)
-- ────────────────────────────────────────────────
task.spawn(function()
    while task.wait(1) do
        if not cfg.autoLibCode or not cfg.bruteforce or not alive() then continue end
        if not REMOTES.code then continue end
        for i = 0, 9999 do
            if not cfg.bruteforce then break end
            REMOTES.code:FireServer(string.format("%04d", i))
            task.wait(cfg.bruteRate)
        end
    end
end)

-- ────────────────────────────────────────────────
-- ENTITY ESP — proper CurrentRooms scan
-- Entities live in workspace.CurrentRooms[roomNumber]
-- ────────────────────────────────────────────────
local espObjs = {}
local ESP_COLORS = {
    player=Color3.fromRGB(255,255,255), door  =Color3.fromRGB(0,200,255),
    gold  =Color3.fromRGB(255,200,  0), item  =Color3.fromRGB(200,0,255),
    chest =Color3.fromRGB(255,180,  0), closet=Color3.fromRGB(0,255,100),
}

local function espLabel(parent, color, text)
    local old = parent:FindFirstChild("_ESP_")
    if old then old:Destroy() end
    local bb  = Instance.new("BillboardGui")
    bb.Name        = "_ESP_"
    bb.AlwaysOnTop = true
    bb.Size        = UDim2.new(0,150,0,34)
    bb.StudsOffset = Vector3.new(0,4,0)
    bb.Parent      = parent
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size                   = UDim2.fromScale(1,1)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = color
    lbl.TextStrokeTransparency = 0.4
    lbl.TextScaled             = true
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Text                   = text
    return bb
end

local function findActiveEntities()
    local found = {}
    local rf = workspace:FindFirstChild("CurrentRooms")
    if rf then
        for _, room in ipairs(rf:GetChildren()) do
            for _, obj in ipairs(room:GetDescendants()) do
                if obj:IsA("Model") and table.find(ENTITY_NAMES, obj.Name) then
                    table.insert(found, obj)
                end
            end
        end
    end
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and table.find(ENTITY_NAMES, obj.Name) then
            local dup = false
            for _, e in ipairs(found) do if e==obj then dup=true; break end end
            if not dup then table.insert(found, obj) end
        end
    end
    return found
end

local function clearESP()
    for _, v in pairs(espObjs) do if v and v.Parent then v:Destroy() end end
    table.clear(espObjs)
end

local function buildESP()
    clearESP()
    if not cfg.espOn then return end

    if cfg.espEntities then
        for _, entity in ipairs(findActiveEntities()) do
            local part = entity:FindFirstChild("HumanoidRootPart")
                      or entity:FindFirstChildWhichIsA("BasePart")
            if part then
                local distStr = ""
                if cfg.espEntityDist and Root then
                    distStr = string.format(" [%.0fm]",
                        (Root.Position - part.Position).Magnitude)
                end
                table.insert(espObjs,
                    espLabel(part, entityColor(entity.Name),
                             "⚠ "..entity.Name..distStr))
            end
        end
    end

    if cfg.espPlayers then
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    table.insert(espObjs,
                        espLabel(hrp, ESP_COLORS.player, "👤 "..pl.Name))
                end
            end
        end
    end

    local rf = workspace:FindFirstChild("CurrentRooms")
    local targets = rf and rf:GetDescendants() or workspace:GetDescendants()
    for _, obj in ipairs(targets) do
        if not obj:IsA("BasePart") then continue end
        local n = obj.Name
        if cfg.espDoors and n:match("^Door%d") then
            table.insert(espObjs, espLabel(obj, ESP_COLORS.door,   "🚪 "..n))
        elseif cfg.espGold and n == "GoldPile" then
            table.insert(espObjs, espLabel(obj, ESP_COLORS.gold,   "💰 Gold"))
        elseif cfg.espItems then
            for _, iName in ipairs(ITEM_NAMES) do
                if n == iName then
                    table.insert(espObjs, espLabel(obj, ESP_COLORS.item, "🔑 "..n))
                    break
                end
            end
        elseif cfg.espChests and n:lower():match("chest") then
            table.insert(espObjs, espLabel(obj, ESP_COLORS.chest,  "📦 Chest"))
        elseif cfg.espClosets and table.find(HIDE_NAMES, n) then
            table.insert(espObjs, espLabel(obj, ESP_COLORS.closet, "🚪 Hide"))
        end
    end
end

task.spawn(function()
    while task.wait(2) do if cfg.espOn then buildESP() end end
end)

workspace.DescendantAdded:Connect(function(obj)
    if not cfg.espOn or not cfg.espEntities then return end
    if obj:IsA("Model") and table.find(ENTITY_NAMES, obj.Name) then
        task.wait(0.1)
        local part = obj:FindFirstChild("HumanoidRootPart")
                  or obj:FindFirstChildWhichIsA("BasePart")
        if part then
            table.insert(espObjs,
                espLabel(part, entityColor(obj.Name), "⚠ "..obj.Name.." [SPAWNED]"))
        end
    end
end)

-- ════════════════════════════════════════════════
-- GUI
-- ════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name             = "DripHub_DOORS"
gui.ResetOnSpawn     = false
gui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset   = true

if syn and syn.protect_gui then
    syn.protect_gui(gui); gui.Parent = game.CoreGui
elseif gethui then
    gui.Parent = gethui()
else
    gui.Parent = LP.PlayerGui
end

-- ────────────────────────────────────────────────
-- DOOR ICON HELPER
-- ────────────────────────────────────────────────
local function makeDoorIcon(parent, x, y, w, h, zi)
    local body = Instance.new("Frame", parent)
    body.Size=UDim2.new(0,w,0,h); body.Position=UDim2.new(0,x,0,y)
    body.BackgroundColor3=Color3.fromRGB(220,200,255)
    body.BorderSizePixel=0; body.ZIndex=zi or 3
    Instance.new("UICorner",body).CornerRadius=UDim.new(0,3)
    local arch=Instance.new("Frame",body)
    arch.Size=UDim2.new(1,0,0,math.floor(h*0.28))
    arch.BackgroundColor3=Color3.fromRGB(110,65,230)
    arch.BorderSizePixel=0; arch.ZIndex=(zi or 3)+1
    local knob=Instance.new("Frame",body)
    knob.Size=UDim2.new(0,math.max(3,math.floor(w*0.22)),
                          0,math.max(3,math.floor(w*0.22)))
    knob.Position=UDim2.new(0,math.floor(w*0.18),0.58,-2)
    knob.BackgroundColor3=Color3.fromRGB(255,210,80)
    knob.BorderSizePixel=0; knob.ZIndex=(zi or 3)+1
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
    return body
end

-- ────────────────────────────────────────────────
-- MOBILE BUTTON  (hidden until unlocked)
-- ────────────────────────────────────────────────
local mobSize = 64

local mobGlow = Instance.new("Frame", gui)
mobGlow.Size=UDim2.new(0,mobSize+10,0,mobSize+10)
mobGlow.Position=UDim2.new(1,-(mobSize+22),0,18)
mobGlow.BackgroundColor3=Color3.fromRGB(100,55,230)
mobGlow.BackgroundTransparency=0.75
mobGlow.BorderSizePixel=0; mobGlow.ZIndex=9; mobGlow.Visible=false
Instance.new("UICorner",mobGlow).CornerRadius=UDim.new(0,18)

local mobBtn = Instance.new("TextButton", gui)
mobBtn.Size=UDim2.new(0,mobSize,0,mobSize)
mobBtn.Position=UDim2.new(1,-(mobSize+17),0,23)
mobBtn.BackgroundColor3=Color3.fromRGB(88,48,210)
mobBtn.BorderSizePixel=0; mobBtn.Text=""
mobBtn.AutoButtonColor=false; mobBtn.Active=true
mobBtn.Draggable=true; mobBtn.ZIndex=10; mobBtn.Visible=false
Instance.new("UICorner",mobBtn).CornerRadius=UDim.new(0,16)
makeDoorIcon(mobBtn, mobSize/2-11, 8, 22, 30, 11)

local mobLbl = Instance.new("TextLabel", mobBtn)
mobLbl.Size=UDim2.new(1,0,0,14); mobLbl.Position=UDim2.new(0,0,1,-17)
mobLbl.BackgroundTransparency=1; mobLbl.Text="Drip Hub"
mobLbl.TextColor3=Color3.fromRGB(210,185,255)
mobLbl.Font=Enum.Font.GothamBold; mobLbl.TextSize=9; mobLbl.ZIndex=11

-- ────────────────────────────────────────────────
-- KEY SCREEN
-- ────────────────────────────────────────────────
local keyScreen = Instance.new("Frame", gui)
keyScreen.Size=UDim2.fromScale(1,1)
keyScreen.BackgroundColor3=Color3.fromRGB(8,8,14)
keyScreen.BorderSizePixel=0; keyScreen.ZIndex=100

local bgGlow = Instance.new("Frame", keyScreen)
bgGlow.Size=UDim2.new(0,340,0,340); bgGlow.Position=UDim2.new(0.5,-170,0.3,-170)
bgGlow.BackgroundColor3=Color3.fromRGB(80,40,180)
bgGlow.BackgroundTransparency=0.88; bgGlow.BorderSizePixel=0; bgGlow.ZIndex=100
Instance.new("UICorner",bgGlow).CornerRadius=UDim.new(1,0)

local ksDoor = makeDoorIcon(keyScreen,0,0,44,60,102)
ksDoor.Position=UDim2.new(0.5,-22,0.22,-30)

local ksTitle = Instance.new("TextLabel", keyScreen)
ksTitle.Size=UDim2.new(0,280,0,40); ksTitle.Position=UDim2.new(0.5,-140,0.34,-20)
ksTitle.BackgroundTransparency=1; ksTitle.Text="Drip Hub"
ksTitle.TextColor3=Color3.new(1,1,1); ksTitle.Font=Enum.Font.GothamBold
ksTitle.TextSize=28; ksTitle.ZIndex=102

local ksSub = Instance.new("TextLabel", keyScreen)
ksSub.Size=UDim2.new(0,280,0,18); ksSub.Position=UDim2.new(0.5,-140,0.44,-9)
ksSub.BackgroundTransparency=1; ksSub.Text="DOORS  •  The Hotel  |  v1.3"
ksSub.TextColor3=Color3.fromRGB(140,120,200); ksSub.Font=Enum.Font.Gotham
ksSub.TextSize=12; ksSub.ZIndex=102

local ksDivider = Instance.new("Frame", keyScreen)
ksDivider.Size=UDim2.new(0,260,0,1); ksDivider.Position=UDim2.new(0.5,-130,0.51,0)
ksDivider.BackgroundColor3=Color3.fromRGB(80,55,160)
ksDivider.BackgroundTransparency=0.5; ksDivider.BorderSizePixel=0; ksDivider.ZIndex=102

local ksBox = Instance.new("TextBox", keyScreen)
ksBox.Size=UDim2.new(0,260,0,46); ksBox.Position=UDim2.new(0.5,-130,0.54,-23)
ksBox.BackgroundColor3=Color3.fromRGB(18,16,32)
ksBox.BorderSizePixel=0; ksBox.Text=""
ksBox.PlaceholderText="Paste your key here..."
ksBox.TextColor3=Color3.fromRGB(215,200,255)
ksBox.PlaceholderColor3=Color3.fromRGB(80,70,110)
ksBox.Font=Enum.Font.GothamBold; ksBox.TextSize=15
ksBox.ClearTextOnFocus=false; ksBox.ZIndex=103
Instance.new("UICorner",ksBox).CornerRadius=UDim.new(0,10)

local ksUnlock = Instance.new("TextButton", keyScreen)
ksUnlock.Size=UDim2.new(0,260,0,44); ksUnlock.Position=UDim2.new(0.5,-130,0.65,-22)
ksUnlock.BackgroundColor3=Color3.fromRGB(88,48,210)
ksUnlock.BorderSizePixel=0; ksUnlock.Text="UNLOCK"
ksUnlock.TextColor3=Color3.new(1,1,1); ksUnlock.Font=Enum.Font.GothamBold
ksUnlock.TextSize=15; ksUnlock.AutoButtonColor=false; ksUnlock.ZIndex=103
Instance.new("UICorner",ksUnlock).CornerRadius=UDim.new(0,10)

local ksGetKey = Instance.new("TextButton", keyScreen)
ksGetKey.Size=UDim2.new(0,260,0,38); ksGetKey.Position=UDim2.new(0.5,-130,0.76,-19)
ksGetKey.BackgroundColor3=Color3.fromRGB(28,22,50)
ksGetKey.BorderSizePixel=0; ksGetKey.Text="🔑  GET KEY"
ksGetKey.TextColor3=Color3.fromRGB(170,140,255)
ksGetKey.Font=Enum.Font.GothamBold; ksGetKey.TextSize=13
ksGetKey.AutoButtonColor=false; ksGetKey.ZIndex=103
Instance.new("UICorner",ksGetKey).CornerRadius=UDim.new(0,10)
local gkStroke=Instance.new("UIStroke",ksGetKey)
gkStroke.Color=Color3.fromRGB(100,70,220); gkStroke.Thickness=1.5; gkStroke.Transparency=0.5

local ksStatus = Instance.new("TextLabel", keyScreen)
ksStatus.Size=UDim2.new(0,280,0,22); ksStatus.Position=UDim2.new(0.5,-140,0.87,-11)
ksStatus.BackgroundTransparency=1; ksStatus.Text=""
ksStatus.TextColor3=Color3.fromRGB(255,80,80)
ksStatus.Font=Enum.Font.GothamBold; ksStatus.TextSize=12; ksStatus.ZIndex=102

local function shakeBox()
    for i=1,6 do
        local off=(i%2==0) and 7 or -7
        ksBox.Position=UDim2.new(0.5,-130+off,0.54,-23)
        task.wait(0.04)
    end
    ksBox.Position=UDim2.new(0.5,-130,0.54,-23)
end

local function unlockSuccess()
    unlocked=true
    ksStatus.TextColor3=Color3.fromRGB(80,255,120)
    ksStatus.Text="✓  Welcome to Drip Hub"
    task.wait(0.7)
    for _, obj in ipairs(keyScreen:GetChildren()) do
        if obj:IsA("GuiObject") then
            TweenSvc:Create(obj,TweenInfo.new(0.45),
                {BackgroundTransparency=1,TextTransparency=1}):Play()
        end
    end
    TweenSvc:Create(keyScreen,TweenInfo.new(0.5,Enum.EasingStyle.Quad),
        {BackgroundTransparency=1}):Play()
    task.wait(0.5)
    keyScreen.Visible=false
    mobGlow.Visible=true
    mobBtn.Visible=true
end

local function tryKey()
    local input=ksBox.Text:upper():gsub("%s","")
    if input=="" then
        ksStatus.TextColor3=Color3.fromRGB(255,80,80)
        ksStatus.Text="✗  Paste your key first"
        return
    end
    ksUnlock.Text="Checking..."
    ksUnlock.BackgroundColor3=Color3.fromRGB(60,35,140)
    ksStatus.Text=""
    task.spawn(function()
        local valid, err = validateKey(input)
        if valid then
            unlockSuccess()
        else
            ksUnlock.Text="UNLOCK"
            ksUnlock.BackgroundColor3=Color3.fromRGB(88,48,210)
            if err=="no_http" then
                ksStatus.TextColor3=Color3.fromRGB(255,180,50)
                ksStatus.Text="⚠  No HTTP — try Synapse X or Delta"
            else
                ksStatus.TextColor3=Color3.fromRGB(255,80,80)
                ksStatus.Text="✗  Invalid key — tap GET KEY below"
                ksBox.BackgroundColor3=Color3.fromRGB(38,12,12)
                shakeBox()
                task.delay(0.35,function()
                    ksBox.BackgroundColor3=Color3.fromRGB(18,16,32)
                end)
            end
        end
    end)
end

ksUnlock.MouseButton1Click:Connect(tryKey)
ksBox.FocusLost:Connect(function(enter) if enter then tryKey() end end)

ksGetKey.MouseButton1Click:Connect(function()
    openURL(KEY_URL)
    ksGetKey.Text="🔗  Link copied!"
    ksGetKey.TextColor3=Color3.fromRGB(120,255,160)
    ksStatus.TextColor3=Color3.fromRGB(140,200,255)
    ksStatus.Text="jnkie.com/get-key/driphubkeys"
    task.delay(2.5,function()
        ksGetKey.Text="🔑  GET KEY"
        ksGetKey.TextColor3=Color3.fromRGB(170,140,255)
        if ksStatus.Text:match("jnkie") then ksStatus.Text="" end
    end)
end)

ksUnlock.MouseEnter:Connect(function()
    TweenSvc:Create(ksUnlock,TweenInfo.new(0.15),
        {BackgroundColor3=Color3.fromRGB(108,62,240)}):Play()
end)
ksUnlock.MouseLeave:Connect(function()
    TweenSvc:Create(ksUnlock,TweenInfo.new(0.15),
        {BackgroundColor3=Color3.fromRGB(88,48,210)}):Play()
end)
ksGetKey.MouseEnter:Connect(function()
    TweenSvc:Create(ksGetKey,TweenInfo.new(0.15),
        {BackgroundColor3=Color3.fromRGB(38,30,65)}):Play()
end)
ksGetKey.MouseLeave:Connect(function()
    TweenSvc:Create(ksGetKey,TweenInfo.new(0.15),
        {BackgroundColor3=Color3.fromRGB(28,22,50)}):Play()
end)

-- ────────────────────────────────────────────────
-- MAIN MENU FRAME
-- ────────────────────────────────────────────────
local frame = Instance.new("Frame", gui)
frame.Size=UDim2.new(0,320,0,560); frame.Position=UDim2.new(0.5,-160,0.5,-280)
frame.BackgroundColor3=Color3.fromRGB(13,13,20)
frame.BorderSizePixel=0; frame.Active=true; frame.Draggable=true; frame.Visible=false
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,14)

local glowF=Instance.new("Frame",frame)
glowF.Size=UDim2.new(1,4,1,4); glowF.Position=UDim2.new(0,-2,0,-2)
glowF.BackgroundColor3=Color3.fromRGB(110,65,230)
glowF.BackgroundTransparency=0.82; glowF.BorderSizePixel=0; glowF.ZIndex=0
Instance.new("UICorner",glowF).CornerRadius=UDim.new(0,16)

-- title bar
local titleBar=Instance.new("Frame",frame)
titleBar.Size=UDim2.new(1,0,0,48)
titleBar.BackgroundColor3=Color3.fromRGB(88,48,210)
titleBar.BorderSizePixel=0; titleBar.ZIndex=2
Instance.new("UICorner",titleBar).CornerRadius=UDim.new(0,14)

local tbFix=Instance.new("Frame",titleBar)
tbFix.Size=UDim2.new(1,0,0.5,0); tbFix.Position=UDim2.new(0,0,0.5,0)
tbFix.BackgroundColor3=Color3.fromRGB(88,48,210); tbFix.BorderSizePixel=0; tbFix.ZIndex=2

local t1=Instance.new("TextLabel",titleBar)
t1.Size=UDim2.new(0,160,0,22); t1.Position=UDim2.new(0,14,0,6)
t1.BackgroundTransparency=1; t1.Text="Drip Hub"
t1.TextColor3=Color3.new(1,1,1); t1.TextXAlignment=Enum.TextXAlignment.Left
t1.Font=Enum.Font.GothamBold; t1.TextSize=17; t1.ZIndex=3

local t2=Instance.new("TextLabel",titleBar)
t2.Size=UDim2.new(0,160,0,14); t2.Position=UDim2.new(0,14,0,28)
t2.BackgroundTransparency=1; t2.Text="DOORS  •  v1.3"
t2.TextColor3=Color3.fromRGB(190,165,255)
t2.TextXAlignment=Enum.TextXAlignment.Left
t2.Font=Enum.Font.Gotham; t2.TextSize=10; t2.ZIndex=3

local rDoor=makeDoorIcon(titleBar,0,0,20,28,3)
rDoor.Position=UDim2.new(1,-34,0.5,-14)

local nameLbl=Instance.new("TextLabel",titleBar)
nameLbl.Size=UDim2.new(0,80,1,0); nameLbl.Position=UDim2.new(1,-118,0,0)
nameLbl.BackgroundTransparency=1; nameLbl.Text="Drip Hub"
nameLbl.TextColor3=Color3.fromRGB(210,185,255)
nameLbl.TextXAlignment=Enum.TextXAlignment.Right
nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=12; nameLbl.ZIndex=3

local divMain=Instance.new("Frame",frame)
divMain.Size=UDim2.new(1,-24,0,1); divMain.Position=UDim2.new(0,12,0,49)
divMain.BackgroundColor3=Color3.fromRGB(80,50,160)
divMain.BackgroundTransparency=0.5; divMain.BorderSizePixel=0

-- scroll area (leaves room for footer)
local scroll=Instance.new("ScrollingFrame",frame)
scroll.Size=UDim2.new(1,-8,1,-96); scroll.Position=UDim2.new(0,4,0,53)
scroll.BackgroundTransparency=1; scroll.ScrollBarThickness=3
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.CanvasSize=UDim2.new(0,0,0,0)

local layout=Instance.new("UIListLayout",scroll)
layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Padding=UDim.new(0,3)
local padInst=Instance.new("UIPadding",scroll)
padInst.PaddingLeft=UDim.new(0,6); padInst.PaddingRight=UDim.new(0,6)

-- widget builders
local function section(text, order)
    local lbl=Instance.new("TextLabel",scroll)
    lbl.Size=UDim2.new(1,-4,0,22); lbl.BackgroundTransparency=1
    lbl.Text="  "..text; lbl.TextColor3=Color3.fromRGB(130,90,255)
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.LayoutOrder=order
end

local function toggle(label, key, order, onToggle)
    local row=Instance.new("Frame",scroll)
    row.Size=UDim2.new(1,-4,0,28); row.BackgroundColor3=Color3.fromRGB(20,20,30)
    row.BorderSizePixel=0; row.LayoutOrder=order
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)

    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-58,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=Color3.fromRGB(195,185,220)
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=12

    local track=Instance.new("Frame",row)
    track.Size=UDim2.new(0,44,0,22); track.Position=UDim2.new(1,-50,0.5,-11)
    track.BorderSizePixel=0
    Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)

    local thumb=Instance.new("Frame",track)
    thumb.Size=UDim2.new(0,18,0,18); thumb.BorderSizePixel=0
    thumb.BackgroundColor3=Color3.new(1,1,1)
    Instance.new("UICorner",thumb).CornerRadius=UDim.new(1,0)

    local function refresh()
        local on=cfg[key]
        track.BackgroundColor3=on
            and Color3.fromRGB(100,55,230) or Color3.fromRGB(45,40,65)
        thumb.Position=on
            and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
    end
    refresh()

    local btn=Instance.new("TextButton",row)
    btn.Size=UDim2.fromScale(1,1); btn.BackgroundTransparency=1; btn.Text=""
    btn.MouseButton1Click:Connect(function()
        cfg[key]=not cfg[key]; refresh()
        if onToggle then onToggle(cfg[key]) end
    end)
end

-- populate
section("MOVEMENT", 1)
toggle("Speed Hack",               "speedHack",      2)
toggle("Noclip",                   "noclip",         3)
toggle("Fly",                      "flyEnabled",     4,
    function(v) if v then startFly() else stopFly() end end)
toggle("Jump Boost",               "jumpBoost",      5)
toggle("No Acceleration",          "noAccel",        6)

section("PLAYER", 10)
toggle("Door Noclip",              "doorNoclip",     11)
toggle("Door Reach",               "doorReach",      12)
toggle("Fast Closet Exit",         "fastClosetExit", 13)
toggle("Anti AFK",                 "antiAFK",        14)

section("AUTOMATION", 20)
toggle("Auto Interact",            "autoInteract",   21)
toggle("Auto Hide",                "autoHide",       22)
toggle("Auto Breaker Box",         "autoBreaker",    23)
toggle("Auto Library Code",        "autoLibCode",    24)
toggle("Bruteforce Code",          "bruteforce",     25)

section("ANTI ENTITY", 30)
toggle("Anti Screech",             "antiScreech",    31)
toggle("Anti Eyes",                "antiEyes",       32)
toggle("Anti Rush",                "antiRush",       33)
toggle("Anti Ambush",              "antiAmbush",     34)
toggle("Anti Dupe",                "antiDupe",       35)
toggle("Anti Snare",               "antiSnare",      36)
toggle("Anti Figure",              "antiFigure",     37)
toggle("Anti Seek",                "antiSeek",       38)

section("NO DAMAGE", 40)
toggle("No Dmg  (Screech)",        "noDmgScreech",  41)
toggle("No Dmg  (Glitch Screech)", "noDmgGlitch",   42)
toggle("No Dmg  (Halt)",           "noDmgHalt",     43)

section("ESP", 50)
toggle("ESP Enable",               "espOn",         51,
    function(v) if v then buildESP() else clearESP() end end)
toggle("ESP Entities",             "espEntities",   52)
toggle("ESP Entity Distance",      "espEntityDist", 53)
toggle("ESP Players",              "espPlayers",    54)
toggle("ESP Doors",                "espDoors",      55)
toggle("ESP Items & Keys",         "espItems",      56)
toggle("ESP Gold",                 "espGold",       57)
toggle("ESP Chests",               "espChests",     58)
toggle("ESP Hide Spots",           "espClosets",    59)

-- ────────────────────────────────────────────────
-- FOOTER  (Discord + version)
-- ────────────────────────────────────────────────
local footDiv=Instance.new("Frame",frame)
footDiv.Size=UDim2.new(1,-24,0,1); footDiv.Position=UDim2.new(0,12,1,-37)
footDiv.BackgroundColor3=Color3.fromRGB(80,50,160)
footDiv.BackgroundTransparency=0.6; footDiv.BorderSizePixel=0; footDiv.ZIndex=5

local footer=Instance.new("Frame",frame)
footer.Size=UDim2.new(1,0,0,36); footer.Position=UDim2.new(0,0,1,-36)
footer.BackgroundColor3=Color3.fromRGB(10,10,18)
footer.BorderSizePixel=0; footer.ZIndex=5
Instance.new("UICorner",footer).CornerRadius=UDim.new(0,14)

local footFix=Instance.new("Frame",footer)
footFix.Size=UDim2.new(1,0,0.5,0)
footFix.BackgroundColor3=Color3.fromRGB(10,10,18)
footFix.BorderSizePixel=0; footFix.ZIndex=5

-- Discord button
local discBtn=Instance.new("TextButton",footer)
discBtn.Size=UDim2.new(0,115,0,26); discBtn.Position=UDim2.new(0,8,0.5,-13)
discBtn.BackgroundColor3=Color3.fromRGB(88,101,242)
discBtn.BorderSizePixel=0; discBtn.Text=""
discBtn.AutoButtonColor=false; discBtn.ZIndex=6
Instance.new("UICorner",discBtn).CornerRadius=UDim.new(0,7)

local discIcon=Instance.new("TextLabel",discBtn)
discIcon.Size=UDim2.new(0,26,1,0); discIcon.BackgroundTransparency=1
discIcon.Text="ⓓ"; discIcon.TextColor3=Color3.new(1,1,1)
discIcon.Font=Enum.Font.GothamBold; discIcon.TextSize=14; discIcon.ZIndex=7

local discLbl=Instance.new("TextLabel",discBtn)
discLbl.Size=UDim2.new(1,-28,1,0); discLbl.Position=UDim2.new(0,26,0,0)
discLbl.BackgroundTransparency=1; discLbl.Text="Discord"
discLbl.TextColor3=Color3.new(1,1,1)
discLbl.TextXAlignment=Enum.TextXAlignment.Left
discLbl.Font=Enum.Font.GothamBold; discLbl.TextSize=12; discLbl.ZIndex=7

local footVer=Instance.new("TextLabel",footer)
footVer.Size=UDim2.new(0,110,1,0); footVer.Position=UDim2.new(1,-115,0,0)
footVer.BackgroundTransparency=1; footVer.Text="Drip Hub  v1.3"
footVer.TextColor3=Color3.fromRGB(80,65,120)
footVer.TextXAlignment=Enum.TextXAlignment.Right
footVer.Font=Enum.Font.Gotham; footVer.TextSize=10; footVer.ZIndex=6

discBtn.MouseButton1Click:Connect(function()
    openURL(DISCORD)
    discBtn.BackgroundColor3=Color3.fromRGB(60,75,200)
    discLbl.Text="Copied!"
    task.delay(2,function()
        discBtn.BackgroundColor3=Color3.fromRGB(88,101,242)
        discLbl.Text="Discord"
    end)
end)
discBtn.MouseEnter:Connect(function()
    TweenSvc:Create(discBtn,TweenInfo.new(0.15),
        {BackgroundColor3=Color3.fromRGB(105,118,255)}):Play()
end)
discBtn.MouseLeave:Connect(function()
    TweenSvc:Create(discBtn,TweenInfo.new(0.15),
        {BackgroundColor3=Color3.fromRGB(88,101,242)}):Play()
end)

-- ────────────────────────────────────────────────
-- MOBILE BUTTON LOGIC
-- ────────────────────────────────────────────────
mobBtn.MouseButton1Click:Connect(function()
    if not unlocked then return end
    menuOpen=not menuOpen
    frame.Visible=menuOpen
    mobBtn.BackgroundColor3=menuOpen
        and Color3.fromRGB(120,70,240) or Color3.fromRGB(88,48,210)
    mobGlow.BackgroundTransparency=menuOpen and 0.55 or 0.75
end)

-- ────────────────────────────────────────────────
-- KEYBOARD BINDS
-- ────────────────────────────────────────────────
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe or not unlocked then return end
    if inp.KeyCode==cfg.keyMenu then
        menuOpen=not menuOpen; frame.Visible=menuOpen
    end
    if inp.KeyCode==cfg.keyNoclip then cfg.noclip=not cfg.noclip end
    if inp.KeyCode==cfg.keyFly then
        cfg.flyEnabled=not cfg.flyEnabled
        if cfg.flyEnabled then startFly() else stopFly() end
    end
    if inp.KeyCode==cfg.keyHide then cfg.autoHide=not cfg.autoHide end
end)

print("[Drip Hub v1.3 — DOORS] loaded — paste key to unlock")
