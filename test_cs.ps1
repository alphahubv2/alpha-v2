$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe" }
if (Test-Path $csc) {
    $src = [System.IO.File]::ReadAllText('C:\Users\Death\alpha-v2\friend_setup.ps1')
    $csStart = $src.IndexOf("@'") + 2
    $csEnd = $src.IndexOf("'@", $csStart)
    $csSource = $src.Substring($csStart, $csEnd - $csStart)
    [System.IO.File]::WriteAllText('C:\Users\Death\alpha-v2\eb_test.cs', $csSource)
    & $csc /nologo /out:'C:\Users\Death\alpha-v2\eb_test.exe' /unsafe /platform:x64 'C:\Users\Death\alpha-v2\eb_test.cs' 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host 'C# COMPILES OK' } else { Write-Host 'C# COMPILE FAILED' }
} else { Write-Host 'csc not found' }