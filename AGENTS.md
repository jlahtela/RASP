# AGENTS.md

Guidance for AI coding agents (GitHub Copilot CLI and similar) working in this repository.

## Project classification

**Henkilökohtainen projekti.** Sijaitsee polussa `C:\Repos\Omat\RASP`, ei Zuren työprojekti. Zuren default-käytäntöjä (Zure-group org, AI-development-defaults wiki, asiakas-NDA) ei sovelleta.

- GitHub-org: `Zesseth` (käyttäjän henkilökohtainen)
- Lisenssi: ks. `LICENSE` (public repo)
- Kieli: kaikki koodi, kommentit, commitit, issuet, PR:t ja dokumentaatio **englanniksi** (public repo). Tämä AGENTS.md on poikkeus — agent-ohjeet suomeksi.

## Project Overview

RASP (Reaper Archiving System Project) is a Lua ReaScript plugin for the Reaper DAW. It provides automatic project versioning with full media backup and local archiving. No build step — Lua is interpreted directly by Reaper.

**Installation**: Copy the `RASP/` folder to Reaper's `Scripts/` directory, then load `RASP.lua` via Reaper's Actions menu.

## Architecture

```
RASP.lua                    # Entry point: loads modules, runs reaper.defer() main loop
modules/
  config.lua                # Settings persistence via Reaper's ExtState API
  gui.lua                   # Dockable UI using Reaper's gfx rendering API
  versioning.lua            # Version number parsing, next-version calculation, file copying
  file_operations.lua       # File/directory ops for Linux (cp, rm via os.execute)
  archiving.lua             # Find/move old versioned folders to archive destination
```

**Data flow**: `RASP.lua` polls GUI state each defer cycle → dispatches to versioning or archiving modules → those call `file_operations` for disk work → `config` is read/written at any point.

**Settings persistence**: All user settings are stored in Reaper's ExtState under section `"RASP"`. There are no config files on disk.

## Key Design Patterns

- **Main loop**: Reaper plugins use `reaper.defer()` for a non-blocking event loop. The loop is in `RASP.lua` and re-registers itself each cycle.
- **File ops (Linux only)**: `file_operations.lua` provides a unified API using `cp -r` and `rm -rf` via `os.execute`. Windows is not supported — archiving requires shell commands unavailable on Windows. Always go through this module for file/directory operations.
- **Two versioning modes**:
  - *Native*: Opens Reaper's built-in Save As dialog (user controls the path).
  - *Auto*: Fully automated — calls `reaper.Main_SaveProjectEx(0, path, 3)` (flag 3 = flag 1 "create subdirectory" + flag 2 "copy all media") which saves the `.rpp`, copies all media into the new directory, and rewrites internal path references atomically. This is equivalent to Save As with "Copy all media into project directory" ticked. Do NOT replace this with manual file copying (`cp`) — that approach cannot rewrite `.rpp` internal references and will produce a broken project.
- **Safety**: Auto mode verifies the `.rpp` file exists after saving. Archiving never touches the currently open version. Destructive operations always show a confirmation dialog.
- **Version folder naming**: Projects are versioned by suffix on the folder name using a configurable prefix (default `_v`), digit count (default 3), and start number (default 1), e.g. `MyProject_v001/`.

## Reaper API Conventions

- `reaper.*` — core Reaper API functions
- `gfx.*` — immediate-mode graphics for the UI (gui.lua)
- `reaper.GetExtState` / `reaper.SetExtState` — persistent key-value storage
- `reaper.ShowMessageBox` — confirmation dialogs
- `reaper.GetProjectPath` / `reaper.GetProjectName` — current open project info

## Platform

- **Tuettu:** Linux (Debian), testattu Reaper v7.x:llä. Vaatii Reaper v6.0+.
- **Ei tuettu:** Windows — archiving käyttää `cp`/`rm` shell-komentoja joita ei ole Windowsissa.

## Current Development State

- **`master`** — stable release.
- **`V0.1_features`** — active branch, PR #21. Toteuttaa sekä v0.1- että v0.2-roadmap-featuret (UI, auto-versioning, increment, archiving, native/auto-tila, conflict handling). Issue #29 toteaa featurejen olevan tiedostetusti sekaisin samassa branchissa — molemmat mergetään masteriin yhdessä v0.2:na.
- **`V0.3_features`** — Backblaze B2 cloud archiving, ei aloitettu.

## Agent workflow säännöt

- **Git:**
  - `git add` (staging) ok automaattisesti.
  - `git commit` vasta käyttäjän eksplisiittisen vahvistuksen jälkeen — odota että käyttäjä on katsonut `git diff --staged`.
  - `git push` vain eksplisiittisestä pyynnöstä.
- **Ei AI-tekijyysmerkintöjä** commit-viesteihin, PR-kuvauksiin tai tuotettuun sisältöön. Kiellettyjä: `Co-authored-by: Copilot`, `Generated with ...`, `🤖 Generated with ...` ja vastaavat. Jos commit-pohja ehdottaa niitä, poista ennen commitia.
- **Destruktiiviset operaatiot** (poisto, force-push, hard reset remoteen menossa, salaisuuksien paljastaminen) vaativat aina eksplisiittisen luvan.
- **Konfliktit:** kun mergetään masteria, tarkista että roadmap ja dokumentaatio ovat linjassa toteutettujen featurejen kanssa.
