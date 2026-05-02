$utf8bom = New-Object System.Text.UTF8Encoding $true
Get-ChildItem (Join-Path $PSScriptRoot "*.ps1") | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($_.FullName, $content, $utf8bom)
    Write-Host "Re-saved with BOM: $($_.Name)"
}
Write-Host "Done. All scripts saved as UTF-8 with BOM."
