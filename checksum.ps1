#Variables to set before use
$DebugMode = $false
$saveLocation = "C:\"
$steamUserId = ''



#Start script
$destPath = "C:\Program Files (x86)\Steam\userdata\$($steamUserId)\1794680\remote\SaveData"
$jsonPath = $saveLocation
$jsonText = Get-Content -Raw -Path $jsonPath
$jsonContent = $jsonText | ConvertFrom-Json

if ($null -eq $jsonContent.checksum) {
    Write-Host "No .checksum property found. Exiting."
    Exit 1
}

$old = $jsonContent.checksum
if ($DebugMode) {
    Write-Host "`n=== BEFORE CHANGES ==="
    $beforeMeta = Get-Item $jsonPath | Select-Object Name, Length, LastWriteTime
    $beforeHash = Get-FileHash $jsonPath -Algorithm SHA256
    $beforeLines = Get-Content $jsonPath
    $beforeBytes = Get-Content $jsonPath -Encoding Byte

    $beforeMeta | Format-List
    $beforeHash
}

$jsonContent.checksum = ""
$compactJson = $jsonContent | ConvertTo-Json -Depth 100 -Compress
$bytes = [System.Text.Encoding]::UTF8.GetBytes($compactJson)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha256.ComputeHash($bytes)
$hashHex = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })

$updatedText = $jsonText -replace '(?<="checksum"\s*:\s*")[^"]*', $hashHex

if (-not (Test-Path (Split-Path $destPath))) {
    New-Item -ItemType Directory -Path (Split-Path $destPath) -Force | Out-Null
}
[System.IO.File]::WriteAllText($destPath, $updatedText, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Checksum updated from          $old        to          $hashHex"
Write-Host "File duplicated to: $destPath"

if ($DebugMode) {
    Write-Host "`n=== AFTER CHANGES ==="
    $afterMeta = Get-Item $destPath | Select-Object Name, Length, LastWriteTime
    $afterHash = Get-FileHash $destPath -Algorithm SHA256
    $afterLines = Get-Content $destPath
    $afterBytes = Get-Content $destPath -Encoding Byte

    $afterMeta | Format-List
    $afterHash

    Write-Host "`n=== LINE-BY-LINE DIFF ==="
    Compare-Object $beforeLines $afterLines | Format-Table -AutoSize

    Write-Host "`n=== BYTE-BY-BYTE DIFF ==="
    $byteDiff = Compare-Object $beforeBytes $afterBytes
    if ($byteDiff) {
        Write-Host "Byte-level differences detected (likely in checksum value)."
    } else {
        Write-Host "No byte-level differences detected."
    }
}
