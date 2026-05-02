#Requires -Version 5.1
# Setup.ps1 — Run once to initialize the Elden Ring Save Manager.
# After this you can use Backup, Restore, and the other scripts freely.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    . (Join-Path $PSScriptRoot "_config.ps1")
    Write-Banner "First-Time Setup"

    # ── 1. Check git is installed ──────────────────────────────────────────
    Write-Info "Checking for Git..."
    $gitVersion = & git --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw (
            "Git is not installed or not on your PATH.`n`n" +
            "Download it from: https://git-scm.com/download/win`n" +
            "After installing, re-run this setup."
        )
    }
    Write-OK "Found: $gitVersion"

    # ── 2. Initialize repo if needed ──────────────────────────────────────
    $gitDir = Join-Path $script:RepoRoot ".git"
    if (Test-Path $gitDir) {
        Write-Info "Git repository already initialized — skipping init."
    } else {
        Write-Info "Initializing Git repository..."
        Invoke-Git @("init", "-b", "main")
        Write-OK "Repository initialized."
    }

    # ── 3. Configure local git identity (no global config touched) ────────
    $cfgName  = (& git -C $script:RepoRoot config --local user.name  2>&1).Trim()
    $cfgEmail = (& git -C $script:RepoRoot config --local user.email 2>&1).Trim()

    if (-not $cfgName -or -not $cfgEmail) {
        Write-Host ""
        Write-Host "  Git needs a name and e-mail to label your commits." -ForegroundColor DarkGray
        Write-Host "  These are stored locally in this repo only." -ForegroundColor DarkGray
        Write-Host ""
        $inputName  = (Read-Host "  Your name  (default: Elden Ring Player)").Trim()
        $inputEmail = (Read-Host "  Your email (default: player@localhost)  ").Trim()
        if (-not $inputName)  { $inputName  = "Elden Ring Player" }
        if (-not $inputEmail) { $inputEmail = "player@localhost"   }
        Invoke-Git @("config", "--local", "user.name",  $inputName)
        Invoke-Git @("config", "--local", "user.email", $inputEmail)
        Write-OK "Git identity set to: $inputName ($inputEmail)"
    } else {
        Write-OK "Git identity already configured: $cfgName ($cfgEmail)"
    }

    # ── 4. Configure player name ──────────────────────────────────────────
    $existingPlayer = ""
    if (Test-Path $script:PlayerConfigFile) {
        $existingPlayer = (Get-Content $script:PlayerConfigFile -Raw -Encoding UTF8).Trim()
    }

    if ($existingPlayer) {
        Write-OK "Player name: $existingPlayer  (saves/$existingPlayer/)"
    } else {
        Write-Host ""
        Write-Host "  Choose a short name to identify YOUR saves in the shared repository." -ForegroundColor DarkGray
        Write-Host "  This becomes your personal save folder: saves/<name>/"                -ForegroundColor DarkGray
        Write-Host "  Use letters, numbers, and hyphens only. Examples: husain  alice  p1" -ForegroundColor DarkGray
        Write-Host ""
        $playerName = ""
        while (-not $playerName) {
            $raw = (Read-Host "  Your player name").Trim() -replace '[^a-zA-Z0-9\-_]', ''
            if (-not $raw) {
                Write-Warn "Name cannot be empty."
            } else {
                $playerName = $raw
            }
        }
        [System.IO.File]::WriteAllText($script:PlayerConfigFile, $playerName)
        Write-OK "Player name set to: $playerName  (saves/$playerName/)"
        $existingPlayer = $playerName
    }

    # ── 5. Ensure saves/<player>/ folder exists ───────────────────────────
    $playerDir = Join-Path $script:SavesDir $existingPlayer
    if (-not (Test-Path $playerDir)) {
        New-Item -ItemType Directory -Path $playerDir -Force | Out-Null
        Write-OK "Created saves/$existingPlayer/ folder."
    } else {
        Write-Info "saves/$existingPlayer/ folder already exists."
    }

    # ── 6. Verify save files are detectable ───────────────────────────────
    Write-Info "Detecting Elden Ring save files..."
    $saveInfo = Get-EldenRingSaveInfo
    Write-OK "Steam ID : $($saveInfo.SteamId)"
    foreach ($f in $saveInfo.Files) {
        Write-OK "Save file : $($f.Name)  ($($f.Label))"
    }

    # ── 6. Create initial repo commit if nothing committed yet ────────────
    $hasCommits = & git -C $script:RepoRoot log --oneline 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $hasCommits) {
        Write-Info "Creating initial repository commit..."

        # Ensure .gitkeep exists so saves/<player>/ is tracked
        $gitkeep = Join-Path $playerDir ".gitkeep"
        if (-not (Test-Path $gitkeep)) {
            [System.IO.File]::WriteAllText($gitkeep, "")
        }

        Invoke-Git @("add", ".")
        Invoke-Git @("commit", "-m", "chore: initialize Elden Ring Save Manager")
        Write-OK "Initial commit created."
    }

    # ── 7. Configure remote origin (for syncing with friends) ────────────
    Push-Location $script:RepoRoot
    $existingOrigin = (& git remote get-url origin 2>&1).Trim()
    $hasOrigin = ($LASTEXITCODE -eq 0 -and $existingOrigin -and -not ($existingOrigin -match '^fatal'))
    Pop-Location

    if ($hasOrigin) {
        Write-OK "Remote origin: $existingOrigin"
    } else {
        Write-Host ""
        Write-Host "  OPTIONAL: Enter a remote Git URL so backups sync to a shared server." -ForegroundColor DarkGray
        Write-Host "  This lets friends pull your saves (e.g. a private GitHub repo)."      -ForegroundColor DarkGray
        Write-Host "  Examples:" -ForegroundColor DarkGray
        Write-Host "    https://github.com/yourname/elden-saves.git" -ForegroundColor DarkGray
        Write-Host "    git@github.com:yourname/elden-saves.git"     -ForegroundColor DarkGray
        Write-Host "  Leave blank to skip — run 1-Setup.bat again to set it later." -ForegroundColor DarkGray
        Write-Host ""
        $remoteUrl = (Read-Host "  Remote URL (blank to skip)").Trim()
        if ($remoteUrl) {
            Invoke-Git @("remote", "add", "origin", $remoteUrl)
            Write-OK "Remote origin set: $remoteUrl"
            Write-Info "Run  2-Backup.bat  — it will push to this remote after every checkpoint."
        } else {
            Write-Info "No remote set. Saves are stored locally only."
        }
    }

    # ── 8. Done ───────────────────────────────────────────────────────────
    Write-Host ""
    Write-Sep
    Write-Host "  Setup complete! Here is what to do next:" -ForegroundColor Green
    Write-Host ""
    Write-Host "    2-Backup.bat           Create your first checkpoint (do this now!)" -ForegroundColor White
    Write-Host "    3-Restore.bat          Roll back to any past checkpoint"            -ForegroundColor White
    Write-Host "    4-List-Checkpoints.bat See all saved checkpoints"                   -ForegroundColor White
    Write-Host "    5-New-Timeline.bat     Fork a new branch (alternate playthrough)"   -ForegroundColor White
    Write-Host "    6-Switch-Timeline.bat  Switch between branches"                     -ForegroundColor White
    Write-Host ""
    Write-Host "  TIP: Back up BEFORE doing anything risky in-game!" -ForegroundColor DarkYellow
    Write-Sep

} catch {
    Write-Host ""
    Write-Host "  [X] Setup failed: $_" -ForegroundColor Red
} finally {
    Wait-AnyKey
}
