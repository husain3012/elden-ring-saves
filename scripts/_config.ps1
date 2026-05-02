# _config.ps1 — Shared helpers for Elden Ring Save Manager
# Dot-sourced by other scripts. Do NOT run this file directly.

$script:RepoRoot         = Split-Path $PSScriptRoot -Parent
$script:SavesDir         = Join-Path $script:RepoRoot "saves"
$script:BackupsDir       = Join-Path $script:RepoRoot "_backups"
$script:PlayerConfigFile = Join-Path $script:RepoRoot ".player"

# ---------------------------------------------------------------------------
# Save-path detection (standard + Seamless Co-op mod)
# ---------------------------------------------------------------------------
function Get-EldenRingSaveInfo {
    <#
    .SYNOPSIS
        Auto-detects the Elden Ring save folder for the current Windows user.
        Supports both the standard game (ER0000.sl2) and the Seamless Co-op
        mod (ER0000.co2).  Returns a PSCustomObject with:
            .SteamId  — numeric Steam ID string
            .Path     — full path to the Steam-ID sub-folder
            .Files[]  — array of { Name, FullPath, Label }
    #>
    $base = Join-Path $env:APPDATA "EldenRing"

    if (-not (Test-Path $base)) {
        throw (
            "Elden Ring data folder not found:`n" +
            "  $base`n`n" +
            "Launch Elden Ring at least once so the folder is created."
        )
    }

    # Steam stores saves under a purely-numeric sub-folder (the Steam ID).
    $steamDirs = @(
        Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{5,20}$' } |
            Sort-Object  LastWriteTime -Descending
    )

    if (-not $steamDirs) {
        throw "No Steam ID folder found inside: $base"
    }

    # If there is more than one Steam account on this PC, ask the user which
    # one to use rather than silently picking the most-recently-written one.
    if ($steamDirs.Count -gt 1) {
        Write-Host ""
        Write-Host "  Multiple Steam accounts detected. Choose which save to use:" -ForegroundColor Yellow
        Write-Host ""
        for ($idx = 0; $idx -lt $steamDirs.Count; $idx++) {
            $d   = $steamDirs[$idx]
            $sl2 = Join-Path $d.FullName "ER0000.sl2"
            $co2 = Join-Path $d.FullName "ER0000.co2"
            $has = @()
            if (Test-Path $sl2) { $has += "Standard" }
            if (Test-Path $co2) { $has += "Seamless Co-op" }
            $saveLabel = if ($has) { "[$($has -join ', ')]" } else { "[no save files]" }
            Write-Host ("  {0}. Steam ID {1}   last modified {2}   {3}" -f `
                ($idx + 1), $d.Name, $d.LastWriteTime.ToString("yyyy-MM-dd HH:mm"), $saveLabel) -ForegroundColor White
        }
        Write-Host ""
        $pick = 0
        while ($pick -lt 1 -or $pick -gt $steamDirs.Count) {
            $raw = (Read-Host "  Enter number (default 1 = most recent)").Trim()
            if (-not $raw) { $raw = "1" }
            if ($raw -match '^\d+$') {
                $pick = [int]$raw
                if ($pick -lt 1 -or $pick -gt $steamDirs.Count) {
                    Write-Host "  Please enter a number between 1 and $($steamDirs.Count)." -ForegroundColor Yellow
                    $pick = 0
                }
            } else {
                Write-Host "  Please enter a number." -ForegroundColor Yellow
            }
        }
        $dir = $steamDirs[$pick - 1]
    } else {
        $dir = $steamDirs[0]
    }
    $files = [System.Collections.Generic.List[object]]::new()

    foreach ($entry in @(
        [pscustomobject]@{ File = "ER0000.sl2"; Label = "Standard" }
        [pscustomobject]@{ File = "ER0000.co2"; Label = "Seamless Co-op" }
    )) {
        $fp = Join-Path $dir.FullName $entry.File
        if (Test-Path $fp) {
            $files.Add([pscustomobject]@{
                Name     = $entry.File
                FullPath = $fp
                Label    = $entry.Label
            })
        }
    }

    if ($files.Count -eq 0) {
        throw (
            "No save files found in:`n" +
            "  $($dir.FullName)`n`n" +
            "Expected ER0000.sl2 (standard game) or ER0000.co2 (Seamless Co-op mod)."
        )
    }

    return [pscustomobject]@{
        SteamId = $dir.Name
        Path    = $dir.FullName
        Files   = $files.ToArray()
    }
}

# ---------------------------------------------------------------------------
# Per-player identity helpers
# ---------------------------------------------------------------------------
function Get-PlayerName {
    if (Test-Path $script:PlayerConfigFile) {
        $name = (Get-Content $script:PlayerConfigFile -Raw -Encoding UTF8).Trim()
        if ($name) { return $name }
    }
    throw (
        "Player name not configured.`n`n" +
        "Run  1-Setup.bat  first to set your player name."
    )
}

function Get-MySavesDir {
    $playerName = Get-PlayerName
    $dir = Join-Path $script:SavesDir $playerName
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Get-AllPlayerNames {
    if (-not (Test-Path $script:SavesDir)) { return @() }
    return @(
        Get-ChildItem $script:SavesDir -Directory -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Name
    )
}

# ---------------------------------------------------------------------------
# Console UI helpers
# ---------------------------------------------------------------------------
function Write-Banner {
    param([string]$Subtitle = "")
    $sep = [string][char]0x2500 * 52   # ─ * 52
    Write-Host ""
    Write-Host "  $sep" -ForegroundColor DarkYellow
    if ($Subtitle) {
        Write-Host ("  Elden Ring Save Manager  |  " + $Subtitle) -ForegroundColor Yellow
    } else {
        Write-Host  "  Elden Ring Save Manager" -ForegroundColor Yellow
    }
    Write-Host "  $sep" -ForegroundColor DarkYellow
    Write-Host ""
}

function Write-OK   { param([string]$Msg); Write-Host "  [+] $Msg" -ForegroundColor Green  }
function Write-Info { param([string]$Msg); Write-Host "  [*] $Msg" -ForegroundColor Cyan   }
function Write-Warn { param([string]$Msg); Write-Host "  [!] $Msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$Msg); Write-Host "  [X] $Msg" -ForegroundColor Red    }
function Write-Sep  {                      Write-Host ("  " + ([string][char]0x2500 * 48)) -ForegroundColor DarkGray }

# ---------------------------------------------------------------------------
# Git helpers (all executed from the repo root)
# ---------------------------------------------------------------------------
function Invoke-Git {
    param([string[]]$GitArgs)
    Push-Location $script:RepoRoot
    try {
        # Coerce 2>&1 output to plain strings so git's stderr lines (e.g.
        # "To github.com:...") are never treated as red ErrorRecord objects.
        $local:ErrorActionPreference = "Continue"
        $out = @(& git @GitArgs 2>&1 | ForEach-Object { "$_" })
        if ($LASTEXITCODE -ne 0) {
            throw "git $($GitArgs -join ' ') failed (exit $LASTEXITCODE):`n$($out -join "`n")"
        }
        return $out
    } finally {
        Pop-Location
    }
}

function Get-RemoteUrl {
    # Returns the configured 'origin' remote URL, or empty string if not set.
    Push-Location $script:RepoRoot
    try {
        $local:ErrorActionPreference = "Continue"
        $out = ((& git remote get-url origin 2>&1) | ForEach-Object { "$_" }) -join ""
        if ($LASTEXITCODE -eq 0 -and $out -and -not ($out -match '^fatal')) {
            return $out.Trim()
        }
        return ""
    } finally {
        Pop-Location
    }
}

function Get-Checkpoints {
    param([string]$PathFilter = "")
    Push-Location $script:RepoRoot
    try {
        $gitArgs = @("log", "--pretty=format:%H|%ad|%s", "--date=format:%Y-%m-%d %H:%M")
        if ($PathFilter) { $gitArgs += "--"; $gitArgs += $PathFilter }
        $lines = & git @gitArgs 2>&1
        if ($LASTEXITCODE -ne 0 -or -not $lines) { return @() }
        return @(
            $lines | Where-Object { $_ -match '\|' } | ForEach-Object {
                $p = $_ -split '\|', 3
                [pscustomobject]@{
                    Hash    = $p[0].Trim()
                    Short   = $p[0].Trim().Substring(0, 7)
                    Date    = $p[1].Trim()
                    Message = $p[2].Trim()
                }
            }
        )
    } finally {
        Pop-Location
    }
}

function Get-CurrentBranch {
    Push-Location $script:RepoRoot
    try {
        $b = (& git branch --show-current 2>&1).Trim()
        if ($LASTEXITCODE -eq 0 -and $b) { return $b }
        return "main"
    } finally {
        Pop-Location
    }
}

function Get-AllBranches {
    Push-Location $script:RepoRoot
    try {
        $current = Get-CurrentBranch
        return @(
            & git branch 2>&1 |
                ForEach-Object { $_.TrimStart('*').Trim() } |
                Where-Object   { $_ } |
                ForEach-Object { [pscustomobject]@{ Name = $_; Current = ($_ -eq $current) } }
        )
    } finally {
        Pop-Location
    }
}

function Get-SaveFiles {
    # Returns all .sl2 / .co2 save files found in a directory.
    param([string]$Dir)
    return @(Get-ChildItem $Dir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '\.(sl2|co2)$' })
}

function New-BackupSnapshot {
    # Creates a timestamped _backups/<ts>/ folder, copies SaveInfo.Files into
    # it, writes meta.json with the supplied metadata, and returns the folder path.
    param(
        [object]   $SaveInfo,  # result of Get-EldenRingSaveInfo
        [hashtable]$Meta       # data to serialise into meta.json
    )
    $ts  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $dir = Join-Path $script:BackupsDir $ts
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    foreach ($f in $SaveInfo.Files) {
        Copy-Item -Path $f.FullPath -Destination (Join-Path $dir $f.Name) -Force
    }
    $Meta | ConvertTo-Json | Set-Content -Path (Join-Path $dir "meta.json") -Encoding UTF8
    return $dir
}

function Test-GameRunning {
    return [bool](Get-Process -Name "eldenring" -ErrorAction SilentlyContinue)
}

function Confirm-Prompt {
    param([string]$Message, [string]$Default = "N")
    $hint = if ($Default -eq "Y") { "[Y/n]" } else { "[y/N]" }
    $ans  = (Read-Host "  $Message $hint").Trim()
    if (-not $ans) { $ans = $Default }
    return $ans -match '^[Yy]'
}

function Read-MenuChoice {
    # Prompts for a number in [1..Max]. Returns 0 when AllowCancel and the user
    # enters "0". Accepts a Default that is used when the user presses Enter.
    param(
        [string]$Prompt,
        [int]   $Max,
        [int]   $Default     = 0,   # 0 = no default
        [switch]$AllowCancel         # treat "0" input as cancel → return 0
    )
    $val = 0
    while ($val -lt 1 -or $val -gt $Max) {
        $raw = (Read-Host "  $Prompt").Trim()
        if ($AllowCancel -and $raw -eq "0") { return 0 }
        if (-not $raw -and $Default -ge 1 -and $Default -le $Max) { return $Default }
        if ($raw -match '^\d+$') {
            $val = [int]$raw
            if ($val -lt 1 -or $val -gt $Max) {
                Write-Warn "Please enter a number between 1 and $Max."
                $val = 0
            }
        } else {
            Write-Warn "Please enter a number."
        }
    }
    return $val
}

function Wait-AnyKey {
    Write-Host ""
    Write-Host "  Press Enter to close..." -ForegroundColor DarkGray
    $null = Read-Host
}
