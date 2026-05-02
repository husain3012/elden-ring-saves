#Requires -Version 5.1
# New-Timeline.ps1 — Fork the current checkpoint into a new branch (alternate
# playthrough). Think of it as creating a "Back to the Future" alternate timeline:
# both the original and the new branch share the same history up to the fork
# point, but from here they evolve independently.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    . (Join-Path $PSScriptRoot "_config.ps1")
    Write-Banner "New Timeline (Branch)"

    $myPlayerName  = Get-PlayerName
    $myRelPath     = "saves/$myPlayerName"
    $currentBranch = Get-CurrentBranch
    $checkpoints   = @(Get-Checkpoints -PathFilter $myRelPath)

    if (-not $checkpoints -or $checkpoints.Count -eq 0) {
        Write-Warn "No checkpoints found. Run  2-Backup.bat  first to create at least one checkpoint."
        Wait-AnyKey
        exit 0
    }

    Write-Host "  You are currently on branch: " -NoNewline -ForegroundColor DarkGray
    Write-Host $currentBranch                    -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  A new timeline forks from a checkpoint you choose." -ForegroundColor DarkGray
    Write-Host "  Backups on the new branch are independent from $currentBranch." -ForegroundColor DarkGray
    Write-Host ""

    # ── Choose fork point ─────────────────────────────────────────────────
    Write-Sep
    Write-Host ("  {0,-4} {1,-17} {2}" -f "#", "Date & Time", "Message") -ForegroundColor DarkGray
    Write-Sep

    $i = 1
    foreach ($cp in $checkpoints) {
        $marker = if ($i -eq 1) { " (latest)" } else { "" }
        Write-Host ("  {0,-4} {1,-17} {2}{3}" -f $i, $cp.Date, $cp.Message, $marker) -ForegroundColor White
        $i++
    }
    Write-Sep
    Write-Host ""

    $choice = Read-MenuChoice -Prompt "Fork from checkpoint # (Enter for latest)" -Max $checkpoints.Count -Default 1

    $forkPoint = $checkpoints[$choice - 1]
    Write-Host ""
    Write-Host "  Forking from: $($forkPoint.Date)  $($forkPoint.Message)" -ForegroundColor Yellow
    Write-Host ""

    # ── Ask for new branch / timeline name ────────────────────────────────
    Write-Host "  Name your new timeline. Use letters, numbers, and hyphens." -ForegroundColor DarkGray
    Write-Host "  Examples:  try-malenia-fight   ranni-questline   pvp-build" -ForegroundColor DarkGray
    Write-Host ""

    $existingBranches = (Get-AllBranches).Name
    $branchName = ""
    while (-not $branchName) {
        $raw = (Read-Host "  New timeline name").Trim() -replace '\s+', '-' -replace '[^a-zA-Z0-9\-_]', ''
        if (-not $raw) {
            Write-Warn "Name cannot be empty."
        } elseif ($existingBranches -contains $raw) {
            Write-Warn "A timeline named '$raw' already exists. Choose a different name."
        } else {
            $branchName = $raw
        }
    }

    Write-Host ""
    if (-not (Confirm-Prompt "Create timeline '$branchName' from: $($forkPoint.Message)?" -Default "Y")) {
        Write-Info "Cancelled."
        Wait-AnyKey
        exit 0
    }

    # ── Create and switch to the new branch ───────────────────────────────
    Write-Host ""
    Write-Info "Creating branch '$branchName' from commit $($forkPoint.Short)..."
    Invoke-Git @("checkout", "-b", $branchName, $forkPoint.Hash)
    Write-OK "Switched to new timeline: $branchName"

    # ── Offer to copy fork-point save to game folder ──────────────────────
    Write-Host ""
    Write-Host "  The saves/ folder now contains the files from checkpoint:" -ForegroundColor DarkGray
    Write-Host "    $($forkPoint.Message)" -ForegroundColor White
    Write-Host ""

    if (Confirm-Prompt "Copy the fork-point save to your game folder now?" -Default "Y") {
        if (Test-GameRunning) {
            Write-Fail "Elden Ring is running. Close the game first, then use  3-Restore.bat  to apply the save."
        } else {
            $saveInfo      = Get-EldenRingSaveInfo
            $myDir         = Get-MySavesDir
            $restoredFiles = Get-SaveFiles $myDir
            foreach ($rf in $restoredFiles) {
                $dest = Join-Path $saveInfo.Path $rf.Name
                Copy-Item -Path $rf.FullName -Destination $dest -Force
                Write-OK "Copied: $($rf.Name)  →  $($saveInfo.Path)"
            }
            Write-OK "Game save now matches the fork point."
        }
    }

    Write-Host ""
    Write-Sep
    Write-OK "New timeline '$branchName' is ready!"
    Write-Host ""
    Write-Host "  You are now on branch: " -NoNewline -ForegroundColor DarkGray
    Write-Host $branchName                 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  From now on, backups with  2-Backup.bat  will go to THIS branch." -ForegroundColor DarkGray
    Write-Host "  Use  6-Switch-Timeline.bat  to jump back to '$currentBranch' any time." -ForegroundColor DarkGray
    Write-Sep

} catch {
    Write-Host ""
    Write-Host "  [X] Error: $_" -ForegroundColor Red
} finally {
    Wait-AnyKey
}
