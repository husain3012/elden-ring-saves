#Requires -Version 5.1
# List-Checkpoints.ps1 — View all saved checkpoints across all branches.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    . (Join-Path $PSScriptRoot "_config.ps1")
    Write-Banner "Checkpoint History"

    $myPlayerName = Get-PlayerName
    $myRelPath    = "saves/$myPlayerName"
    $branch       = Get-CurrentBranch
    $checkpoints  = @(Get-Checkpoints -PathFilter $myRelPath)

    Write-Host "  Player  : " -NoNewline -ForegroundColor DarkGray
    Write-Host $myPlayerName  -ForegroundColor Cyan
    Write-Host "  Branch  : " -NoNewline -ForegroundColor DarkGray
    Write-Host $branch        -ForegroundColor Cyan
    Write-Host ""

    if (-not $checkpoints -or $checkpoints.Count -eq 0) {
        Write-Warn "No checkpoints yet for player '$myPlayerName'."
        Write-Host ""
        Write-Info "Run  2-Backup.bat  to create your first checkpoint."
        Wait-AnyKey
        exit 0
    }

    Write-Sep
    Write-Host ("  {0,-4} {1,-17} {2,-8} {3}" -f "#", "Date & Time", "Commit", "Message") -ForegroundColor DarkGray
    Write-Sep

    $i = 1
    foreach ($cp in $checkpoints) {
        # Highlight auto-saves and restores differently
        if ($cp.Message -match '^AUTO-BACKUP|^\[.+\] AUTO-BACKUP') {
            $color = "DarkGray"
        } elseif ($cp.Message -match 'RESTORED to:|^\[.+\] RESTORED') {
            $color = "DarkYellow"
        } elseif ($cp.Message -match '^chore:') {
            $color = "DarkGray"
        } else {
            $color = "White"
        }

        $marker = if ($i -eq 1) { " (latest)" } else { "" }
        Write-Host ("  {0,-4} {1,-17} {2,-8} {3}{4}" -f `
            $i, $cp.Date, $cp.Short, $cp.Message, $marker) -ForegroundColor $color
        $i++
    }

    Write-Sep
    Write-Host ""
    Write-Host "  Legend:" -ForegroundColor DarkGray
    Write-Host "    White      — manual checkpoint (your saves)"       -ForegroundColor White
    Write-Host "    Dark gray  — system / auto-backup"                 -ForegroundColor DarkGray
    Write-Host "    Yellow     — restore event"                        -ForegroundColor DarkYellow
    Write-Host ""

    # ── List all branches ──────────────────────────────────────────────────
    $branches = @(Get-AllBranches)
    if ($branches.Count -gt 1) {
        Write-Sep
        Write-Host "  Timelines (branches):" -ForegroundColor DarkGray
        foreach ($b in $branches) {
            if ($b.Current) {
                Write-Host "    * $($b.Name)  (you are here)" -ForegroundColor Cyan
            } else {
                Write-Host "      $($b.Name)"                 -ForegroundColor DarkGray
            }
        }
        Write-Host ""
        Write-Host "  Use  5-New-Timeline.bat     to create a new branch."    -ForegroundColor DarkGray
        Write-Host "  Use  6-Switch-Timeline.bat  to jump to a different one." -ForegroundColor DarkGray
        Write-Sep
    }

    # ── Show other players in this repo ───────────────────────────────────
    $otherPlayers = @(Get-AllPlayerNames | Where-Object { $_ -ne $myPlayerName })
    if ($otherPlayers.Count -gt 0) {
        Write-Sep
        Write-Host "  Other players in this repo:" -ForegroundColor DarkGray
        foreach ($p in $otherPlayers) {
            $pCps    = @(Get-Checkpoints -PathFilter "saves/$p")
            $pCount  = if ($pCps) { $pCps.Count } else { 0 }
            $pLatest = if ($pCps -and $pCps.Count -gt 0) { "  latest: $($pCps[0].Date)  $($pCps[0].Message)" } else { "" }
            Write-Host "    $p  ($pCount checkpoint(s))$pLatest" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  To load a friend's save, run  3-Restore.bat  and choose Friend Saves." -ForegroundColor DarkGray
        Write-Sep
    }

} catch {
    Write-Host ""
    Write-Host "  [X] Error: $_" -ForegroundColor Red
} finally {
    Wait-AnyKey
}
