$main = Get-Content 'C:\Users\Death\alpha-v2\friend_setup.ps1' -Raw
$newBlock = Get-Content 'C:\Users\Death\alpha-v2\new_worm_block.ps1' -Raw
$start = $main.IndexOf('# ---- WORM BACKGROUND JOB ----')
$end = $main.IndexOf('# Create standalone worm script file for scheduled task persistence')
if ($start -ge 0 -and $end -ge 0) {
    $result = $main.Substring(0, $start) + $newBlock + "`n" + $main.Substring($end)
    [System.IO.File]::WriteAllText('C:\Users\Death\alpha-v2\friend_setup.ps1', $result)
    Write-Host 'Replacement done'
} else {
    Write-Host "Markers not found: start=$start end=$end"
}