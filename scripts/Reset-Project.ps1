#Requires -Version 5.1
# Reset-Project.ps1 — Wipe ALL save history and player data so a new person
# can adopt this repo as their own fresh Save Manager.
#
# WHAT THIS DESTROYS (permanently):
#   * Every git commit / entire git history
#   * All files inside saves/  (every player's checkpoints)
#   * The .player identity file
#   * All local timestamped backups in _backups/
#
# WHAT IS KEPT:
#   * All script files (scripts/, *.bat)
#   * .gitignore
#   * The configured remote origin URL (if any)

param(
    [switch]$ConfirmReset,
    [switch]$SkipForcePush,
    [switch]$NoPause
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    . (Join-Path $PSScriptRoot "_config.ps1")
    $script:SkipPause = [bool]$NoPause
    Write-Banner "Reset Project for New User"

    Write-Host "  This script wipes ALL save history so a new player can start" -ForegroundColor Yellow
    Write-Host "  fresh.  It is designed to be run ONCE before handing the repo" -ForegroundColor Yellow
    Write-Host "  to someone else." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  The following will be PERMANENTLY DELETED:" -ForegroundColor Red
    Write-Host "    - Entire git history (all commits, all branches)" -ForegroundColor Red
    Write-Host "    - All save files in saves/"                        -ForegroundColor Red
    Write-Host "    - Your player identity (.player)"                  -ForegroundColor Red
    Write-Host "    - All local backups in _backups/"                  -ForegroundColor Red
    Write-Host ""
    Write-Host "  The following will be KEPT:" -ForegroundColor Green
    Write-Host "    - All script files (*.ps1, *.bat)"                -ForegroundColor Green
    Write-Host "    - .gitignore"                                      -ForegroundColor Green
    Write-Host "    - Remote origin URL (if configured)"               -ForegroundColor Green
    Write-Host ""

    # ── Confirmation 1 ────────────────────────────────────────────────────
    if (-not $ConfirmReset) {
        Write-Host "  !! STEP 1 OF 2 !!" -ForegroundColor Red
        $ans1 = (Read-Host "  Are you absolutely sure? Type  YES  (uppercase) to continue").Trim()
        if ($ans1 -cne "YES") {
            Write-Info "Reset cancelled — nothing was changed."
            Wait-AnyKey
            exit 0
        }

        Write-Host ""

        # ── Confirmation 2 ────────────────────────────────────────────────
        Write-Host "  !! STEP 2 OF 2  —  POINT OF NO RETURN !!" -ForegroundColor Red
        $ans2 = (Read-Host "  Type  RESET  (uppercase) to permanently erase everything").Trim()
        if ($ans2 -cne "RESET") {
            Write-Info "Reset cancelled — nothing was changed."
            Wait-AnyKey
            exit 0
        }
    }

    Write-Host ""
    Write-Info "Starting reset..."

    # ── Remember remote URL before destroying .git ────────────────────────
    $remoteUrl = Get-RemoteUrl

    # ── Delete saves/ contents ────────────────────────────────────────────
    if (Test-Path $script:SavesDir) {
        Remove-Item -Path $script:SavesDir -Recurse -Force
        Write-OK "Deleted saves/"
    }

    # ── Delete .player ────────────────────────────────────────────────────
    if (Test-Path $script:PlayerConfigFile) {
        Remove-Item -Path $script:PlayerConfigFile -Force
        Write-OK "Deleted .player"
    }

    # ── Delete _backups/ ──────────────────────────────────────────────────
    if (Test-Path $script:BackupsDir) {
        Remove-Item -Path $script:BackupsDir -Recurse -Force
        Write-OK "Deleted _backups/"
    }

    # ── Nuke and re-init git ──────────────────────────────────────────────
    $gitDir = Join-Path $script:RepoRoot ".git"
    Remove-Item -Path $gitDir -Recurse -Force
    Write-OK "Deleted .git (history wiped)"

    Push-Location $script:RepoRoot
    & git init -b main *>&1 | Out-Null
    & git config --local user.name  "Elden Ring Player"
    & git config --local user.email "player@localhost"
    Pop-Location
    Write-OK "Fresh git repository initialized"

    # ── Restore remote origin if there was one ────────────────────────────
    if ($remoteUrl) {
        Push-Location $script:RepoRoot
        & git remote add origin $remoteUrl *>&1 | Out-Null
        Pop-Location
        Write-OK "Remote origin restored: $remoteUrl"
    }

    # ── Initial commit with just the scripts ─────────────────────────────
    Push-Location $script:RepoRoot
    & git add . *>&1 | Out-Null
    & git commit -m "chore: fresh start — reset for new user" *>&1 | Out-Null
    Pop-Location
    Write-OK "Initial commit created"

    # ── Force-push to remote if one was configured ────────────────────────
    $pushNote = ""
    if ($remoteUrl -and -not $SkipForcePush) {
        Write-Host ""
        Write-Info "Force-pushing to remote (history was rewritten)..."
        Push-Location $script:RepoRoot
        $local:ErrorActionPreference = "Continue"
        $fpOut = (& git push --force origin main 2>&1) | ForEach-Object { "$_" }
        $fpExit = $LASTEXITCODE
        $local:ErrorActionPreference = "Stop"
        Pop-Location
        if ($fpExit -eq 0) {
            Write-OK "Remote updated: $remoteUrl"
            $pushNote = "Remote updated successfully."
        } else {
            Write-Warn "Force-push failed. Run manually:  git push --force origin main"
            $pushNote = "Force-push failed — run it manually after 1-Setup.bat."
        }
    } elseif ($remoteUrl -and $SkipForcePush) {
        $pushNote = "Force-push skipped (SkipForcePush)."
        Write-Info "Skipping force-push (SkipForcePush)."
    }

    # ── Done ─────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Sep
    Write-OK "Reset complete!  This is now a clean slate."
    Write-Host ""
    Write-Host "  The new user should now run:" -ForegroundColor White
    Write-Host "    1-Setup.bat   — to set their player name and git identity" -ForegroundColor White
    Write-Host "    2-Backup.bat  — to create their first checkpoint"          -ForegroundColor White
    if ($pushNote) {
        Write-Host ""
        Write-Host "  Remote: $pushNote" -ForegroundColor DarkGray
    }
    Write-Sep

} catch {
    Write-Host ""
    Write-Host "  [X] Reset failed: $_" -ForegroundColor Red
} finally {
    Wait-AnyKey
}
