# Elden Ring Save Manager

A Git-powered save checkpoint system for Elden Ring on PC. Back up your save
before risky fights or decisions, restore to any past checkpoint, and manage
multiple alternate playthroughs — all without knowing any Git commands.

---

## Quick Start

**Do this once:**

1. Double-click **`1-Setup.bat`**  
   Initialises the repo, detects your save files, and confirms everything works.

**Every session:**

| File | What it does |
| --- | --- |
| `2-Backup.bat` | Save a named checkpoint right now |
| `3-Restore.bat` | Roll back to any past checkpoint |
| `4-List-Checkpoints.bat` | See all your checkpoints |
| `5-New-Timeline.bat` | Fork a new alternate playthrough branch |
| `6-Switch-Timeline.bat` | Jump between alternate playthroughs |
| `7-Open-UI.bat` | Open a lightweight launcher window for all actions |

> **Tip:** Double-click any `.bat` file. No terminal or Git knowledge required.
> Optional: Double-click `7-Open-UI.bat` for a simple button-based launcher.

---

## How it Works

```text
Game save folder  (read — never written to except during an explicit restore)
  C:\Users\YOU\AppData\Roaming\EldenRing\<SteamID>\ER0000.sl2

Repository saves folder  (the version-controlled copy)
  elden-ring-saves\saves\<player-name>\ER0000.sl2
```

- **Backing up** copies your game save → `saves/<player-name>/`, then commits with your message.  
- **Restoring** auto-backs up your current state first (safety net), then copies
  the chosen checkpoint, friend save, or local backup → game folder.  
- **Timelines** are Git branches — each branch is a separate playthrough that
  shares history up to the fork point.

---

## Supported Save Types

| File | Mode |
| --- | --- |
| `ER0000.sl2` | Standard game |
| `ER0000.co2` | [Seamless Co-op mod](https://www.nexusmods.com/eldenring/mods/510) |

Both are detected and backed up automatically when present.

---

## Sharing a Save With a Friend

1. Make sure your friend has this same repository (share the folder, or push to
   a private GitHub repo and have them clone it).
2. Your friend runs **`3-Restore.bat`**, chooses **Friend Saves**, and then
  picks the save they want to load from your history.
3. That's it — the save is copied to their game folder.

If you push to GitHub, your friend just needs to `git pull` (or you can add a
`7-Sync-Remote.bat` that wraps `git pull`).

---

## Alternate Timelines (Branches)

Branches let you explore "what if" playthroughs without losing your main
progress.  Think of it as the *Back to the Future* alternate timeline model.

```text
main
  ●── Level 1 ── Stormveil ── Liurnia ──●── (keeps going)
                                        │
                               try-malenia (new branch)
                                        ●── (backups here don't affect main)
```

- **`5-New-Timeline.bat`** — pick a fork point and name the new branch.  
- **`6-Switch-Timeline.bat`** — jump back to `main` or any other branch.  
- Backups always go to whichever branch you are currently on.

---

## Directory Structure

```text
elden-ring-saves/
├── 0-Reset-for-New-User.bat   ← wipe repo history for a clean handoff
├── 1-Setup.bat                ← run once
├── 2-Backup.bat               ← create checkpoint
├── 3-Restore.bat              ← restore checkpoint
├── 4-List-Checkpoints.bat     ← view history
├── 5-New-Timeline.bat         ← fork a branch
├── 6-Switch-Timeline.bat      ← switch branch
├── 7-Open-UI.bat              ← open lightweight launcher UI
│
├── saves/
│   └── <player-name>/
│       ├── ER0000.sl2         ← backed-up standard save (git-tracked)
│       └── ER0000.co2         ← backed-up co-op save   (git-tracked, if present)
│
├── _backups/                  ← timestamped local safety copies with metadata
│   └── yyyy-MM-dd_HH-mm-ss/
│       ├── ER0000.sl2
│       ├── ER0000.co2
│       └── meta.json
│
├── scripts/                   ← PowerShell scripts (don't need to edit these)
│   ├── _config.ps1
│   ├── _fix-encoding.ps1
│   ├── Setup.ps1
│   ├── Backup-Save.ps1
│   ├── Restore-Save.ps1
│   ├── List-Checkpoints.ps1
│   ├── New-Timeline.ps1
│   ├── Reset-Project.ps1
│   ├── Switch-Timeline.ps1
│   └── UI-Launcher.ps1
│
├── .gitignore
└── README.md
```

---

## Notes & Caveats

- **Close the game before restoring.** Writing save files while the game is
  running can corrupt them. The restore script enforces this.
- **Backups before risky actions** — run `2-Backup.bat` before anything you
  might regret (invading, attacking NPCs, major story choices).
- **Auto-safety backup** — `3-Restore.bat` always writes a timestamped local
  backup before overwriting anything, and restoring your own checkpoint also
  records a git auto-backup when there are uncommitted changes.
- **`.bak` files are ignored** — the game creates its own `ER0000.sl2.bak`
  automatically; this tool manages its own versioning and ignores those files.
