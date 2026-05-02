#Requires -Version 5.1
# Backup-Save.ps1 — Create a named checkpoint of your current save files.
# Run this before any risky quests, boss fights, or major decisions.

param(
    [string]$Message,
    [switch]$ContinueIfGameRunning,
    [switch]$AllowNoChanges,
    [switch]$NoPush,
    [switch]$NoPause,
    [int]$SteamAccountIndex = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    . (Join-Path $PSScriptRoot "_config.ps1")
    $script:SkipPause = [bool]$NoPause
    Write-Banner "Backup / Create Checkpoint"

    # ── Detect save files ─────────────────────────────────────────────────
    Write-Info "Detecting save files..."
    $saveInfo     = Get-EldenRingSaveInfo -SteamAccountIndex $SteamAccountIndex
    $myPlayerName = Get-PlayerName
    $myDir        = Get-MySavesDir
    $myRelPath    = "saves/$myPlayerName"
    Write-OK "Player   : $myPlayerName  (saves/$myPlayerName/)"
    Write-OK "Steam ID : $($saveInfo.SteamId)"
    foreach ($f in $saveInfo.Files) {
        $modTime = (Get-Item $f.FullPath).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-OK "Found    : $($f.Name)  ($($f.Label))  — last saved $modTime"
    }
    Write-Host ""

    # ── Warn if game is running ────────────────────────────────────────────
    if (Test-GameRunning) {
        Write-Warn "Elden Ring appears to be running."
        Write-Warn "The save file may be incomplete while the game is open."
        Write-Host ""
        $shouldContinue = $ContinueIfGameRunning -or (Confirm-Prompt "Continue anyway?" -Default "N")
        if (-not $shouldContinue) {
            Write-Info "Backup cancelled. Close the game first for a clean save."
            Wait-AnyKey
            exit 0
        }
        Write-Host ""
    }

    # ── Ask for checkpoint message ─────────────────────────────────────────
    Write-Host "  Describe this checkpoint (what you are about to do, or what just happened)." -ForegroundColor DarkGray
    Write-Host "  Examples:  Before Malenia fight  |  Finished Ranni questline  |  About to try invasion" -ForegroundColor DarkGray
    Write-Host ""
    if ($Message) {
        $msg = $Message.Trim()
        if (-not $msg) { throw "Message cannot be empty." }
    } else {
        $msg = ""
        while (-not $msg) {
            $msg = (Read-Host "  Checkpoint message").Trim()
            if (-not $msg) { Write-Warn "Message cannot be empty. Please enter something." }
        }
    }

    # ── Copy save files into saves/<player>/ ──────────────────────────────
    Write-Host ""
    Write-Info "Copying save files to repository..."
    foreach ($f in $saveInfo.Files) {
        $dest = Join-Path $myDir $f.Name
        Copy-Item -Path $f.FullPath -Destination $dest -Force
        Write-OK "Copied: $($f.Name)"
    }

    # ── Check if anything actually changed ────────────────────────────────
    Push-Location $script:RepoRoot
    $statusLines = & git status --porcelain $myRelPath 2>&1
    Pop-Location

    if (-not $statusLines) {
        Write-Host ""
        Write-Warn "Save files have not changed since the last checkpoint."
        Write-Host ""
        $allowEmpty = $AllowNoChanges -or (Confirm-Prompt "Create a checkpoint anyway (no file changes will be recorded)?" -Default "N")
        if (-not $allowEmpty) {
            Write-Info "No checkpoint created."
            Wait-AnyKey
            exit 0
        }
        Write-Host ""
    }

    # ── Commit ────────────────────────────────────────────────────────────
    $timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitMsg  = "[$timestamp][$myPlayerName] $msg"
    $branch     = Get-CurrentBranch

    if ($statusLines) {
        Invoke-Git @("add", $myRelPath)
        Invoke-Git @("commit", "-m", $commitMsg)
    } else {
        Invoke-Git @("commit", "--allow-empty", "-m", $commitMsg)
    }

    # Get the short hash of the new commit
    Push-Location $script:RepoRoot
    $shortHash = (& git rev-parse --short HEAD 2>&1).Trim()
    Pop-Location
    $remotePushUrl = Get-RemoteUrl
    $hasRemote     = [bool]$remotePushUrl

    # ── Write a physical _backups/ snapshot with metadata ─────────────────
    New-BackupSnapshot -SaveInfo $saveInfo -Meta @{
        reason     = "backup"
        message    = $msg
        player     = $myPlayerName
        commitHash = $shortHash
        branch     = $branch
    }

    # ── Push to remote if configured ──────────────────────────────────────
    $pushStatus = ""
    if ($NoPush) {
        $pushStatus = "Skipped push (NoPush)"
    } elseif ($hasRemote) {
        Write-Host ""
        Write-Info "Pushing to remote ($remotePushUrl)..."
        try {
            Invoke-Git @("push", "origin", $branch)
            Write-OK "Pushed to remote."
            $pushStatus = "Pushed to $remotePushUrl"
        } catch {
            $errText = "$_"
            if ($errText -match 'fetch first|rejected|non-fast-forward') {
                Write-Warn "Push rejected — remote has commits this machine does not have."
                Write-Warn "If you just ran 0-Reset-for-New-User.bat, run once in a terminal:"
                Write-Host "    git push --force origin $branch" -ForegroundColor Yellow
                Write-Warn "Otherwise run  git pull origin $branch  to sync first."
            } else {
                Write-Warn "Push failed (checkpoint saved locally): $errText"
            }
            $pushStatus = "Push failed — saved locally only"
        }
    } else {
        $pushStatus = "No remote — local only  (run 1-Setup.bat to add one)"
    }

    Write-Host ""
    Write-Sep
    Write-OK "Checkpoint saved!"
    Write-Host ""
    Write-Host "  Message : $msg"           -ForegroundColor White
    Write-Host "  Player  : $myPlayerName"  -ForegroundColor White
    Write-Host "  Time    : $timestamp"     -ForegroundColor White
    Write-Host "  Commit  : $shortHash"     -ForegroundColor White
    Write-Host "  Branch  : $branch"        -ForegroundColor White
    Write-Host "  Remote  : $pushStatus"    -ForegroundColor White
    Write-Host ""
    Write-Host "  To restore this later, run  3-Restore.bat" -ForegroundColor DarkGray
    Write-Sep

} catch {
    Write-Host ""
    Write-Host "  [X] Backup failed: $_" -ForegroundColor Red
} finally {
    Wait-AnyKey
}
