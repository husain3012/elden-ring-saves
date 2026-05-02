#Requires -Version 5.1
# Restore-Save.ps1 — Roll back your game to a prior checkpoint, friend save,
# or local backup. The flow is two-step: choose a source category first, then
# choose the specific entry to restore.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    . (Join-Path $PSScriptRoot "_config.ps1")
    Write-Banner "Restore Checkpoint"

    $myPlayerName = Get-PlayerName
    $myDir        = Get-MySavesDir
    $myRelPath    = "saves/$myPlayerName"
    $branch       = Get-CurrentBranch

    Write-Host "  Player : " -NoNewline -ForegroundColor DarkGray
    Write-Host $myPlayerName  -ForegroundColor Cyan
    Write-Host "  Branch : " -NoNewline -ForegroundColor DarkGray
    Write-Host $branch        -ForegroundColor Cyan
    Write-Host ""

    # ── Build restore entries from all supported sources ──────────────────
    Write-Info "Loading restore points..."
    $timeline = [System.Collections.Generic.List[hashtable]]::new()

    # 1) My own git checkpoints
    $myCheckpoints = @(Get-Checkpoints -PathFilter $myRelPath)
    foreach ($cp in $myCheckpoints) {
        $timeline.Add(@{
            Type        = "own"
            SortKey     = $cp.Date
            DisplayDate = $cp.Date
            Description = $cp.Message
            Cp          = $cp
        })
    }

    # 2) Friends' latest save (one entry per friend, their most recent checkpoint)
    $otherPlayers = @(Get-AllPlayerNames | Where-Object { $_ -ne $myPlayerName })
    foreach ($friend in $otherPlayers) {
        $fRelPath = "saves/$friend"
        $fCps     = @(Get-Checkpoints -PathFilter $fRelPath)
        $fDir     = Join-Path $script:SavesDir $friend
        $fFiles   = Get-SaveFiles $fDir
        if (-not $fFiles) { continue }
        $fDate  = if ($fCps -and $fCps.Count -gt 0) { $fCps[0].Date } else { "unknown" }
        $fMsg   = if ($fCps -and $fCps.Count -gt 0) { $fCps[0].Message } else { "(no message)" }
        $timeline.Add(@{
            Type        = "friend"
            SortKey     = $fDate
            DisplayDate = $fDate
            Description = $fMsg
            FriendName  = $friend
            FriendFiles = $fFiles
        })
    }

    # 3) Local _backups/ timestamped folders
    $backupDirs  = @(Get-ChildItem $script:BackupsDir -Directory -ErrorAction SilentlyContinue |
                     Sort-Object Name -Descending)
    foreach ($bd in $backupDirs) {
        # Folder name: yyyy-MM-dd_HH-mm-ss  →  parse to a sortable date string
        $bdDateStr = $bd.Name -replace '_', ' ' -replace '-(\d{2})-(\d{2})$', ':$1:$2'
        $bdFiles   = @(Get-SaveFiles $bd.FullName | Select-Object -ExpandProperty Name)
        # Read metadata if present
        $bdMetaFile = Join-Path $bd.FullName "meta.json"
        $bdDesc = if (Test-Path $bdMetaFile) {
            try {
                $m = Get-Content $bdMetaFile -Raw | ConvertFrom-Json
                if ($m.reason -eq "backup") {
                    "Checkpoint: $($m.message)  [$($m.commitHash)]"
                } else {
                    "Before $($m.linkedType) restore: $($m.linkedDesc)"
                }
            } catch { $bdFiles -join ", " }
        } else { $bdFiles -join ", " }
        $timeline.Add(@{
            Type        = "backup"
            SortKey     = $bdDateStr
            DisplayDate = $bd.Name
            Description = $bdDesc
            BackupDir   = $bd
        })
    }

    if ($timeline.Count -eq 0) {
        Write-Warn "No restore points found."
        Write-Info "Run  2-Backup.bat  first to create a checkpoint."
        Wait-AnyKey; exit 0
    }

    # ── Step 1: pick category ─────────────────────────────────────────────
    $categories = [System.Collections.Generic.List[hashtable]]::new()

    $ownEntries    = @($timeline | Where-Object { $_.Type -eq "own" }    | Sort-Object { $_.SortKey } -Descending)
    $backupEntries = @($timeline | Where-Object { $_.Type -eq "backup" } | Sort-Object { $_.SortKey } -Descending)
    $friendEntries = @($timeline | Where-Object { $_.Type -eq "friend" } | Sort-Object { $_.SortKey } -Descending)

    if ($ownEntries.Count -gt 0)    { $categories.Add(@{ Label = "My Checkpoints  ($($ownEntries.Count) entries)";    Entries = $ownEntries    }) }
    if ($backupEntries.Count -gt 0) { $categories.Add(@{ Label = "Local Backups   ($($backupEntries.Count) entries)"; Entries = $backupEntries }) }
    if ($friendEntries.Count -gt 0) { $categories.Add(@{ Label = "Friend Saves    ($($friendEntries.Count) entries)"; Entries = $friendEntries }) }

    $catChoice = 0
    if ($categories.Count -eq 1) {
        $catChoice = 1
    } else {
        Write-Host "  What would you like to restore from?" -ForegroundColor DarkGray
        Write-Host ""
        for ($ci = 0; $ci -lt $categories.Count; $ci++) {
            Write-Host "    $($ci + 1).  $($categories[$ci].Label)" -ForegroundColor White
        }
        Write-Host "    0.  Cancel" -ForegroundColor DarkGray
        Write-Host ""
        while ($catChoice -lt 1 -or $catChoice -gt $categories.Count) {
            $catChoice = Read-MenuChoice -Prompt "Enter 1-$($categories.Count)" -Max $categories.Count -AllowCancel
            if ($catChoice -eq 0) { Write-Info "Cancelled."; Wait-AnyKey; exit 0 }
        }
    }

    $activeEntries = @($categories[$catChoice - 1].Entries)

    # ── Step 2: pick entry within category ───────────────────────────────
    Write-Host ""
    Write-Sep
    Write-Host ("  {0,-4} {1,-22} {2}" -f "#", "Date", "Description") -ForegroundColor DarkGray
    Write-Sep

    for ($i = 0; $i -lt $activeEntries.Count; $i++) {
        $e = $activeEntries[$i]
        $color = switch ($e.Type) {
            "own"    { "White" }
            "friend" { "Cyan"  }
            "backup" { "DarkYellow" }
        }
        $marker = if ($e.Type -eq "own" -and $i -eq 0) { "  <- latest" } else { "" }
        Write-Host ("  {0,-4} {1,-22} {2}{3}" -f ($i + 1), $e.DisplayDate, $e.Description, $marker) -ForegroundColor $color
    }
    Write-Sep
    Write-Host ""

    $choice = Read-MenuChoice -Prompt "Enter # to restore (or 0 to go back)" -Max $activeEntries.Count -AllowCancel
    if ($choice -eq 0) { Write-Info "Cancelled."; Wait-AnyKey; exit 0 }

    $entry = $activeEntries[$choice - 1]
    $entryLabel = switch ($entry.Type) {
        "own"    { "My Checkpoint" }
        "friend" { "Friend: $($entry.FriendName)" }
        "backup" { "Local Backup" }
        default   { $entry.Type }
    }
    Write-Host ""
    Write-Host "  Selected : $entryLabel  —  $($entry.Description)" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Confirm-Prompt "Restore this? Your current save will be backed up first." -Default "N")) {
        Write-Info "Restore cancelled."; Wait-AnyKey; exit 0
    }

    if (Test-GameRunning) {
        Write-Fail "Elden Ring is currently running. Close the game completely before restoring."
        Wait-AnyKey; exit 1
    }

    Write-Host ""
    Write-Info "Detecting current save files..."
    $saveInfo = Get-EldenRingSaveInfo

    # ── Safety backup of current game files ──────────────────────────────
    $safeBackupDir = New-BackupSnapshot -SaveInfo $saveInfo -Meta @{
        reason     = "pre-restore"
        linkedType = $entry.Type
        linkedDesc = $entry.Description
        linkedDate = $entry.DisplayDate
        player     = $myPlayerName
    }
    Write-OK "Current save backed up to:"
    Write-Host "    $safeBackupDir" -ForegroundColor DarkGray
    Write-Host ""

    # ══════════════════════════════════════════════════════════════════════
    if ($entry.Type -eq "own") {
    # ══════════════════════════════════════════════════════════════════════

        $selected = $entry.Cp

        # Auto-commit current state if changed
        Write-Info "Checking for uncommitted changes before restoring..."
        foreach ($f in $saveInfo.Files) {
            Copy-Item -Path $f.FullPath -Destination (Join-Path $myDir $f.Name) -Force
        }
        Push-Location $script:RepoRoot
        $statusLines = & git status --porcelain $myRelPath 2>&1
        Pop-Location

        if ($statusLines) {
            $autoMsg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')][$myPlayerName] AUTO-BACKUP before restoring to: $($selected.Message)"
            Invoke-Git @("add", $myRelPath)
            Invoke-Git @("commit", "-m", $autoMsg)
            Write-OK "Current state committed as safety backup."
        } else {
            Write-Info "No uncommitted changes — skipping auto-commit."
        }

        Write-Host ""
        Write-Info "Extracting checkpoint $($selected.Short)..."
        Invoke-Git @("checkout", $selected.Hash, "--", $myRelPath)

        Write-Info "Writing to game save folder..."
        $restoredFiles = Get-SaveFiles $myDir
        foreach ($rf in $restoredFiles) {
            Copy-Item -Path $rf.FullName -Destination (Join-Path $saveInfo.Path $rf.Name) -Force
            Write-OK "Restored: $($rf.Name)  →  $($saveInfo.Path)"
        }

        # Record restore commit
        $restoreMsg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm')][$myPlayerName] RESTORED to: $($selected.Message)"
        Invoke-Git @("add", $myRelPath)
        Push-Location $script:RepoRoot
        $staged = & git status --porcelain $myRelPath 2>&1
        Pop-Location
        if ($staged) { Invoke-Git @("commit", "-m", $restoreMsg) }
        else          { Invoke-Git @("restore", "--staged", $myRelPath) }

        Write-Host ""
        Write-Sep
        Write-OK "Restore complete!"
        Write-Host ""
        Write-Host "  Restored to : $($selected.Message)" -ForegroundColor White
        Write-Host "  Checkpoint  : $($selected.Date)"    -ForegroundColor White
        Write-Host ""
        Write-Host "  You can now launch Elden Ring and continue from that checkpoint." -ForegroundColor DarkGray
        Write-Sep

    # ══════════════════════════════════════════════════════════════════════
    } elseif ($entry.Type -eq "friend") {
    # ══════════════════════════════════════════════════════════════════════

        $friendName  = $entry.FriendName
        $friendFiles = $entry.FriendFiles

        Write-Info "Writing $friendName's save to game folder..."
        foreach ($ff in $friendFiles) {
            Copy-Item -Path $ff.FullName -Destination (Join-Path $saveInfo.Path $ff.Name) -Force
            Write-OK "Loaded: $($ff.Name)  →  $($saveInfo.Path)"
        }

        Write-Host ""
        Write-Sep
        Write-OK "Loaded $friendName's save into your game!"
        Write-Host ""
        Write-Host "  Note: your OWN save was NOT changed in the repository." -ForegroundColor DarkYellow
        Write-Host "  Run  2-Backup.bat  when you want to save your own progress." -ForegroundColor DarkGray
        Write-Sep

    # ══════════════════════════════════════════════════════════════════════
    } elseif ($entry.Type -eq "backup") {
    # ══════════════════════════════════════════════════════════════════════

        $bd        = $entry.BackupDir
        $bdFiles   = Get-SaveFiles $bd.FullName

        if (-not $bdFiles) {
            Write-Fail "No .sl2 / .co2 files found in that backup folder."
            Wait-AnyKey; exit 1
        }

        Write-Info "Writing backup to game folder..."
        foreach ($bf in $bdFiles) {
            Copy-Item -Path $bf.FullName -Destination (Join-Path $saveInfo.Path $bf.Name) -Force
            Write-OK "Restored: $($bf.Name)  →  $($saveInfo.Path)"
        }

        Write-Host ""
        Write-Sep
        Write-OK "Restore complete!"
        Write-Host ""
        Write-Host "  Restored from backup : $($bd.Name)" -ForegroundColor White
        Write-Host ""
        Write-Host "  Run  2-Backup.bat  if you want to create a git checkpoint now." -ForegroundColor DarkGray
        Write-Sep
    }

} catch {
    Write-Host ""
    Write-Host "  [X] Restore failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "  [!] Your original save files have NOT been modified (the error occurred before any write)." -ForegroundColor Yellow
    Write-Host "  [!] If a partial write happened, your backed-up copy is in _backups/ and can be restored." -ForegroundColor Yellow
} finally {
    Wait-AnyKey
}
