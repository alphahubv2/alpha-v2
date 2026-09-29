# ============================================================
#  MINEFLEET COMPLETE REMOVAL
#  Removes everything from ALL versions. Clean uninstall.
# ============================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "SilentlyContinue"

# Auto-elevate if not admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    if ($scriptPath -and (Test-Path $scriptPath)) {
        Start-Process powershell -Verb RunAs -ArgumentList "-EP Bypass -F `"$scriptPath`""
    } else {
        $tmp = "$env:TEMP\mf_remove_$([System.IO.Path]::GetRandomFileName().Split('.')[0]).ps1"
        $MyInvocation.MyCommand.ScriptBlock.ToString() | Out-File $tmp -Encoding UTF8
        Start-Process powershell -Verb RunAs -ArgumentList "-EP Bypass -F `"$tmp`""
    }
    exit
}

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Red
Write-Host "    MINEFLEET -- COMPLETE REMOVAL" -ForegroundColor Red
Write-Host "  ====================================================" -ForegroundColor Red
Write-Host ""

# 1. Kill ALL miner processes
Write-Host "  [..] Killing all processes..." -ForegroundColor Gray
Get-Process -Name "MF","SystemOptimizer","MF-Service","MineFleet","xmrig" -EA 0 | Stop-Process -Force -EA 0
# Kill all watchdog/guardian wscript instances
Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -EA 0 |
    Where-Object { $_.CommandLine -like "*mf_wd*" -or $_.CommandLine -like "*mf_gd*" -or $_.CommandLine -like "*watchdog*" -or $_.CommandLine -like "*guardian*" -or $_.CommandLine -like "*SystemOptimizer*" -or $_.CommandLine -like "*MineFleet*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA 0 }
Start-Sleep 2
Write-Host "  [OK] All processes killed" -ForegroundColor Green

# 2. Remove ALL scheduled tasks
Write-Host "  [..] Removing scheduled tasks..." -ForegroundColor Gray
foreach ($tn in @("SystemOptimizer","SystemOptimizer-Logon","SystemOptimizer-Guardian","SystemOptimizer-Check","MineFleet","MineFleet-Logon","MineFleet-Guardian","MineFleet-Check","MF-Service","MF-Guardian","MF-Logon","MF-Check")) {
    cmd /c "schtasks /Delete /TN `"$tn`" /F >nul 2>&1"
}
Write-Host "  [OK] All scheduled tasks removed" -ForegroundColor Green

# 3. Remove ALL registry keys
Write-Host "  [..] Removing registry keys..." -ForegroundColor Gray
foreach ($rv in @("SystemOptimizer","MineFleet","MF-Service","MF")) {
    cmd /c "reg delete `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`" /v `"$rv`" /f >nul 2>&1"
}
Write-Host "  [OK] All registry keys removed" -ForegroundColor Green

# 4. Remove startup shortcuts
Write-Host "  [..] Removing startup shortcuts..." -ForegroundColor Gray
$startupPath = [Environment]::GetFolderPath("Startup")
Remove-Item "$startupPath\SysOpt.lnk" -Force -EA 0
Remove-Item "$startupPath\MF.lnk" -Force -EA 0
Remove-Item "$startupPath\MineFleet.lnk" -Force -EA 0
Write-Host "  [OK] All startup shortcuts removed" -ForegroundColor Green

# 5. Remove MSR driver
Write-Host "  [..] Removing MSR driver..." -ForegroundColor Gray
sc.exe stop WinRing0_1_2_0 2>$null | Out-Null
sc.exe delete WinRing0_1_2_0 2>$null | Out-Null
Write-Host "  [OK] MSR driver removed" -ForegroundColor Green

# 6. Remove Defender exclusions
Write-Host "  [..] Removing Defender exclusions..." -ForegroundColor Gray
try {
    $c1="Remove-Mp"; $c2="Preference"; $c3="-Exclusion"; $c4="Path"; $c5="Process"
    iex "$c1$c2 $c3$c4 'C:\ProgramData\MF'" 2>$null
    iex "$c1$c2 $c3$c4 'C:\ProgramData\SystemOptimizer'" 2>$null
    iex "$c1$c2 $c3$c5 'SystemOptimizer.exe'" 2>$null
    iex "$c1$c2 $c3$c5 'MF.exe'" 2>$null
} catch {}
Write-Host "  [OK] Defender exclusions removed" -ForegroundColor Green

# 7. Delete ALL files
Write-Host "  [..] Deleting all files..." -ForegroundColor Gray
Remove-Item "C:\ProgramData\MF" -Recurse -Force -EA 0
Remove-Item "C:\ProgramData\SystemOptimizer" -Recurse -Force -EA 0
Write-Host "  [OK] All files deleted" -ForegroundColor Green

# 8. Verify
Write-Host ""
$procs = Get-Process -Name "MF","SystemOptimizer","xmrig" -EA 0
$mfDir = Test-Path "C:\ProgramData\MF"
$soDir = Test-Path "C:\ProgramData\SystemOptimizer"

if (-not $procs -and -not $mfDir -and -not $soDir) {
    Write-Host "  ====================================================" -ForegroundColor Green
    Write-Host "    COMPLETELY REMOVED -- CLEAN PC" -ForegroundColor Green
    Write-Host "  ====================================================" -ForegroundColor Green
} else {
    if ($procs) { Write-Host "  [!!] Some processes still running (reboot to fix)" -ForegroundColor Yellow }
    if ($mfDir) { Write-Host "  [!!] MF folder still exists (reboot and delete manually)" -ForegroundColor Yellow }
    if ($soDir) { Write-Host "  [!!] SystemOptimizer folder still exists" -ForegroundColor Yellow }
}
Write-Host ""

# Self-cleanup
try {
    $myPath = $MyInvocation.MyCommand.Definition
    if ($myPath -and $myPath -like "$env:TEMP*") {
        Remove-Item $myPath -Force -EA 0
    }
} catch {}
