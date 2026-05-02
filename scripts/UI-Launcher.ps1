#Requires -Version 5.1
# UI-Launcher.ps1 — Minimal built-in launcher UI for Elden Ring Save Manager.
# Uses WinForms (already available on Windows PowerShell 5.1), no extra packages.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path $PSScriptRoot -Parent

function Start-BatAction {
    param(
        [string]$BatName,
        [System.Windows.Forms.Label]$StatusLabel,
        [switch]$IsDanger
    )

    $batPath = Join-Path $repoRoot $BatName
    if (-not (Test-Path $batPath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not find: $BatName`n`nExpected at:`n$batPath",
            "Missing File",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    if ($IsDanger) {
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "This opens the reset workflow, which permanently wipes save history.`n`nContinue?",
            "Confirm Reset",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            $StatusLabel.Text = "Ready"
            return
        }
    }

    try {
        $StatusLabel.Text = "Launching: $BatName"
        [System.Diagnostics.Process]::Start($batPath) | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to launch: $BatName`n`n$_",
            "Launch Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        $StatusLabel.Text = "Ready"
        return
    }

    $StatusLabel.Text = "Ready"
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Elden Ring Save Manager"
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.ClientSize = New-Object System.Drawing.Size(560, 430)
$form.BackColor = [System.Drawing.Color]::FromArgb(26, 26, 26)
$form.ForeColor = [System.Drawing.Color]::Gainsboro

$title = New-Object System.Windows.Forms.Label
$title.Text = "Elden Ring Save Manager"
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 18)
$title.Location = New-Object System.Drawing.Point(20, 16)
$title.Size = New-Object System.Drawing.Size(520, 38)
$title.ForeColor = [System.Drawing.Color]::FromArgb(255, 204, 120)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Minimal launcher UI. Each button opens the existing script workflow in its own window."
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.Location = New-Object System.Drawing.Point(22, 52)
$subtitle.Size = New-Object System.Drawing.Size(520, 20)
$subtitle.ForeColor = [System.Drawing.Color]::Silver
$form.Controls.Add($subtitle)

$panel = New-Object System.Windows.Forms.FlowLayoutPanel
$panel.Location = New-Object System.Drawing.Point(20, 86)
$panel.Size = New-Object System.Drawing.Size(520, 280)
$panel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$panel.WrapContents = $false
$panel.AutoScroll = $true
$panel.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 36)
$panel.Padding = New-Object System.Windows.Forms.Padding(12)
$form.Controls.Add($panel)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Ready"
$status.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$status.Location = New-Object System.Drawing.Point(20, 378)
$status.Size = New-Object System.Drawing.Size(520, 20)
$status.ForeColor = [System.Drawing.Color]::LightGray
$form.Controls.Add($status)

$actions = @(
    @{ Label = "1) Setup";                  Bat = "1-Setup.bat" },
    @{ Label = "2) Backup";                 Bat = "2-Backup.bat" },
    @{ Label = "3) Restore";                Bat = "3-Restore.bat" },
    @{ Label = "4) List Checkpoints";       Bat = "4-List-Checkpoints.bat" },
    @{ Label = "5) New Timeline";           Bat = "5-New-Timeline.bat" },
    @{ Label = "6) Switch Timeline";        Bat = "6-Switch-Timeline.bat" },
    @{ Label = "0) Reset for New User";     Bat = "0-Reset-for-New-User.bat"; Danger = $true }
)

foreach ($action in $actions) {
    $isDanger = $action.ContainsKey("Danger") -and [bool]$action["Danger"]

    $button = New-Object System.Windows.Forms.Button
    $button.Text = "$($action.Label)   ->   $($action.Bat)"
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $button.Size = New-Object System.Drawing.Size(485, 34)
    $button.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(75, 75, 75)
    $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(64, 64, 64)

    if ($isDanger) {
        $button.BackColor = [System.Drawing.Color]::FromArgb(72, 28, 28)
        $button.ForeColor = [System.Drawing.Color]::MistyRose
    } else {
        $button.BackColor = [System.Drawing.Color]::FromArgb(48, 48, 48)
        $button.ForeColor = [System.Drawing.Color]::WhiteSmoke
    }

    $button.Tag = [pscustomobject]@{
        BatName  = [string]$action.Bat
        IsDanger = $isDanger
    }
    $button.Add_Click({
        param($sender, $eventArgs)
        $meta = $sender.Tag
        Start-BatAction -BatName $meta.BatName -StatusLabel $status -IsDanger:$meta.IsDanger
    })

    $panel.Controls.Add($button)
}

$footer = New-Object System.Windows.Forms.Label
$footer.Text = "Tip: Start with Setup once, then use Backup before risky in-game actions."
$footer.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$footer.Location = New-Object System.Drawing.Point(20, 402)
$footer.Size = New-Object System.Drawing.Size(520, 18)
$footer.ForeColor = [System.Drawing.Color]::DarkGray
$form.Controls.Add($footer)

[void]$form.ShowDialog()
