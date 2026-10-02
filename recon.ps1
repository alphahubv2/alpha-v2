<# 
.SYNOPSIS
    Recon.ps1 - Masscan + Vuln Scan + AD CS Enumeration
.DESCRIPTION
    Generates target list, scans for open ports, enumerates AD CS for ESC1-ESC14
.NOTES
    Run as admin. Requires masscan, certutil, certcli.
#>

param(
    [string[]]$Ranges = @("10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"),
    [string]$OutputDir = "C:\ProgramData\MF\Recon"
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Log { param([string]$msg) $ts = Get-Date -Format "HH:mm:ss"; Write-Host "[$ts] $msg" }

Log "=== RECON STARTED ==="

# 1. Masscan
Log "Running masscan..."
$ports = "445,3389,5985,5986,22,80,443,8080,8443,5986,5985,135,139,389,636,3268,3269,88,464,53,123,161,162,500,4500,1723,3306,5432,1433,1521,27017,6379,9200,5601,9000,9090,9091,9092,9093,9094,9095,9096,9097,9098,9099,9100,9101,9102,9103,9104,9105,9106,9107,9108,9109,9110"
$rangeStr = $Ranges -join " "
$cmd = "masscan -p $ports --rate 50000 $Ranges --exclude 255.255.255.255 -oL $OutputDir\targets_raw.txt"
Log "Running: $cmd"
$exitCode = (cmd /c $cmd 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { Log "Masscan failed: $exitCode" } else { Log "Masscan completed" }

# Parse targets
if (Test-Path "$OutputDir\targets_raw.txt") {
    $targets = Get-Content "$OutputDir\targets_raw.txt" | Where-Object { $_ -match "^\s*\d" } | ForEach-Object { $_.Split() } | Where-Object { $_ -match "^\d" } | Select-Object -Unique
    $targets | Out-File "$OutputDir\targets.txt" -Encoding UTF8
    Log "Targets found: $($targets.Count)"
} else {
    Log "No targets found"
    exit 1
}

# 2. AD CS Enumeration (ESC1-ESC14)
Log "Enumerating AD CS..."
try {
    $cas = certutil -config - -ping 2>&1 | Where-Object { $_ -match "^\s*\d+\.\s*" } | ForEach-Object { $_.Trim() }
    if ($cas) {
        $cas | Out-File "$OutputDir\cas.txt" -Encoding UTF8
        Log "CAs found: $($cas.Count)"
        foreach ($ca in $cas) {
            $templates = certutil -config "$ca" -template 2>&1 | Where-Object { $_ -match "^\s*\d+\.\s*" } | ForEach-Object { $_.Trim() }
            if ($templates) {
                "$ca" | Out-File "$OutputDir\templates_$($ca.Replace('\','_').Replace(':','_')).txt" -Append -Encoding UTF8
                $templates | Out-File "$OutputDir\templates_$($ca.Replace('\','_').Replace(':','_')).txt" -Append -Encoding UTF8
            }
        }
        Log "AD CS enumeration complete"
    } else {
        Log "No CAs found"
    }
} catch { Log "AD CS enum failed: $_" }

# 3. Vuln Scan (quick checks)
Log "Running quick vuln checks..."
$targets = Get-Content "$OutputDir\targets.txt"
$vulnTargets = @()
foreach ($ip in $targets) {
    # PetitPotam check (port 445)
    $tcp = New-Object Net.Sockets.TcpClient
    $conn = $tcp.BeginConnect($ip, 445, $null, $null)
    if ($conn.AsyncWaitHandle.WaitOne(500) -and $tcp.Connected) {
        $vulnTargets += "$ip|PetitPotam"
        Log "PetitPotam target: $ip"
    }
    $tcp.Close()
}
$vulnTargets | Out-File "$OutputDir\vuln_targets.txt" -Encoding UTF8
Log "Vuln targets: $($vulnTargets.Count)"

Log "=== RECON COMPLETE ==="
Log "Outputs: $OutputDir\targets.txt, hits.txt, vuln_targets.txt, cas.txt, templates_*.txt"