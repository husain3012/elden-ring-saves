#Requires -Version 5.1
# Switch-Timeline.ps1 — Jump between branches (alternate playthroughs).
# Switching timelines changes saves/ to match that branch's latest checkpoint
# and optionally loads that save into the game folder.

param(
    [string]$TargetBranch,
    [switch]$ConfirmSwitch,
    [switch]$LoadToGameFolder,
    [switch]$NoLoadToGameFolder,
    [switch]$NoPause,
    [int]$SteamAccountIndex = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    . (Join-Path $PSScriptRoot "_config.ps1")
    $script:SkipPause = [bool]$NoPause
    Write-Banner "Switch Timeline (Branch)"

    if ($LoadToGameFolder -and $NoLoadToGameFolder) {
        throw "LoadToGameFolder and NoLoadToGameFolder cannot both be specified."
    }

    $currentBranch = Get-CurrentBranch
    $branches      = @(Get-AllBranches)

    if ($branches.Count -le 1) {
        Write-Info "Only one timeline exists: '$currentBranch'."
        Write-Host ""
        Write-Info "Use  5-New-Timeline.bat  to create a new branch / alternate playthrough."
        Wait-AnyKey
        exit 0
    }

    # ── Display branches ───────────────────────────────────────────────────
    Write-Host "  You are on: " -NoNewline -ForegroundColor DarkGray
    Write-Host $currentBranch  -ForegroundColor Cyan
    Write-Host ""
    Write-Sep
    Write-Host ("  {0,-4} {1}" -f "#", "Timeline name") -ForegroundColor DarkGray
    Write-Sep

    $i = 1
    foreach ($b in $branches) {
        if ($b.Current) {
            Write-Host ("  {0,-4} {1}  (current)" -f $i, $b.Name) -ForegroundColor Cyan
        } else {
            Write-Host ("  {0,-4} {1}"             -f $i, $b.Name) -ForegroundColor White
        }
        $i++
    }

    Write-Sep
    Write-Host ""

    if ($TargetBranch) {
        $target = @($branches | Where-Object { $_.Name -eq $TargetBranch })[0]
        if (-not $target) { throw "Timeline '$TargetBranch' was not found." }
    } else {
        $choice = Read-MenuChoice -Prompt "Enter the # of the timeline to switch to" -Max $branches.Count
        $target = $branches[$choice - 1]
    }

    if ($target.Current) {
        Write-Host ""
        Write-Info "You are already on '$($target.Name)'. Nothing to do."
        Wait-AnyKey
        exit 0
    }

    Write-Host ""
    Write-Host "  Switching to: " -NoNewline -ForegroundColor DarkGray
    Write-Host $target.Name       -ForegroundColor Yellow
    Write-Host ""

    if (-not ($ConfirmSwitch -or (Confirm-Prompt "Switch to timeline '$($target.Name)'?" -Default "Y"))) {
        Write-Info "Cancelled."
        Wait-AnyKey
        exit 0
    }

    # ── Stash any uncommitted changes so the checkout is clean ────────────
    Push-Location $script:RepoRoot
    $dirty = & git status --porcelain 2>&1
    Pop-Location

    if ($dirty) {
        Write-Info "Stashing uncommitted changes before switching..."
        Invoke-Git @("stash", "push", "-m", "auto-stash before switching to $($target.Name)")
        Write-OK "Changes stashed."
    }

    # ── Switch branch ─────────────────────────────────────────────────────
    Write-Info "Switching branch..."
    Invoke-Git @("checkout", $target.Name)
    Write-OK "Now on timeline: $($target.Name)"

    # ── Show latest checkpoint on this branch ─────────────────────────────
    $myPlayerName = Get-PlayerName
    $myRelPath    = "saves/$myPlayerName"
    $checkpoints  = @(Get-Checkpoints -PathFilter $myRelPath)
    if ($checkpoints -and $checkpoints.Count -gt 0) {
        $latest = $checkpoints[0]
        Write-Host ""
        Write-Host "  Latest checkpoint on this branch:" -ForegroundColor DarkGray
        Write-Host "    $($latest.Date)  $($latest.Message)" -ForegroundColor White
    }

    # ── Offer to load the branch's save into the game folder ──────────────
    $myDir     = Get-MySavesDir
    $saveFiles = Get-SaveFiles $myDir

    if ($saveFiles) {
        Write-Host ""
        if (Test-GameRunning) {
            Write-Warn "Elden Ring is running — can't copy save files while it's open."
            Write-Info "Close the game, then run  3-Restore.bat  and pick the top entry to load this branch's save."
        } else {
            Write-Host ""
            $shouldLoad = if ($LoadToGameFolder) { $true } elseif ($NoLoadToGameFolder) { $false } else { Confirm-Prompt "Load this timeline's save into your game folder now?" -Default "Y" }
            if ($shouldLoad) {
                $saveInfo = Get-EldenRingSaveInfo -SteamAccountIndex $SteamAccountIndex
                foreach ($sf in $saveFiles) {
                    $dest = Join-Path $saveInfo.Path $sf.Name
                    Copy-Item -Path $sf.FullName -Destination $dest -Force
                    Write-OK "Loaded: $($sf.Name)  →  $($saveInfo.Path)"
                }
                Write-OK "Game save now matches timeline '$($target.Name)'."
            }
        }
    } else {
        Write-Warn "No save files found in this branch's saves/ folder."
        Write-Info "This branch may not have any backups yet. Run  2-Backup.bat  to create the first one."
    }

    Write-Host ""
    Write-Sep
    Write-OK "Timeline switched to: $($target.Name)"
    Write-Host ""
    Write-Host "  Backups with  2-Backup.bat  will now go to '$($target.Name)'." -ForegroundColor DarkGray
    Write-Sep

} catch {
    Write-Host ""
    Write-Host "  [X] Error: $_" -ForegroundColor Red
} finally {
    Wait-AnyKey
}
