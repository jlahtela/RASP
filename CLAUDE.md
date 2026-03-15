# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## Language

All code comments, commit messages, issue comments, PR descriptions, and documentation must be written in **English**. This is a public repository.

## Current Development State

**Active branch:** `V0.1_features` — implements roadmap v0.2 features (untested as of 2026-03-13):
- Local archiving: move old version folders to a configurable archive destination
- Configurable "versions to keep" setting (default 3)
- Dual save mode toggle: Native (Reaper's Save As dialog) vs Auto (fully automated via `Main_SaveProjectEx`)

`master` contains the stable v0.1 release (basic versioning only).

**Branch history note:** `V0.1_features` was built on top of the archiving code — the two feature sets (archiving + save mode toggle) are tightly coupled in gui.lua and cannot be separated cleanly. Both will merge to master together as v0.2.

**Next:** `V0.3_features` — cloud archiving via Backblaze B2 (not started).
