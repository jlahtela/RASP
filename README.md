# RASP
Reaper Archiving System Project

A Lua plugin for Reaper DAW that provides automatic project versioning with full media backup.

## Features (v0.2)

- **Dockable UI** - Native Reaper interface
- **Safe Auto-versioning** - Copies entire project with all media files
- **Dual Saving Mode** - Choose between Native (Reaper dialog) or Auto (fully automated)
- **Conflict Handling** - Smart handling when version folder already exists
- **Cross-platform** - Works on Linux (Debian) and Windows

## Requirements

### Required
- **Reaper DAW** v6.0 or newer (tested with v7.x)
- **Operating System**: Linux (Debian) or Windows 11 (tested)

### Recommended
No extensions or additional software needed.

## Project Structure

```
RASP/
├── RASP.lua              # Main entry point
├── modules/
│   ├── config.lua        # Settings & ExtState
│   ├── file_operations.lua   # File copying
│   ├── gui.lua           # User interface
│   └── versioning.lua    # Version logic
└── docs/
    └── installation.md   # Setup guide
```

## Quick Start

1. Copy `RASP/` folder to Reaper's `Scripts/` directory
2. In Reaper: Actions → Load ReaScript → Select `RASP.lua`
3. Run the script to open RASP window
4. Select saving method (Native/Auto)
5. Click "Create New Version" to version your project

See [installation guide](docs/installation.md) for detailed instructions.

## Version Format

```
MyProject/MyProject.rpp            → Original
MyProject_v001/MyProject_v001.rpp  → Version 1
MyProject_v002/MyProject_v002.rpp  → Version 2
MyProject_v002_a/MyProject_v002_a.rpp  → Version 2 (alongside)
```

---

## Versioning Guide

### Saving Method Selection

RASP provides two methods for creating new versions. You can switch between them using the **Native / Auto** toggle in the Versioning section.

<!-- TODO: Add screenshot of versioning section with switch -->

### Native Mode

Opens Reaper's built-in "Save As" dialog.

**When to use:**
- You want full control over save location
- You need to manually select which media to copy
- You're familiar with Reaper's "Copy all media" options

**How it works:**
1. Click "Create New Version"
2. Reaper's Save As dialog opens
3. Choose location and enable "Copy all media into project directory"
4. Save

**Console output:**
```
RASP: Opening Save As dialog...
   💡 Tip: Enable 'Copy all media into project directory' for safe versioning
```

### Auto Mode (Recommended)

Fully automated versioning that guarantees all media files are copied.

**When to use:**
- You want fast, reliable versioning
- You want to ensure no media references break
- You want the new version to open automatically

**How it works:**
1. Click "Create New Version"
2. RASP automatically:
   - Calculates next version number (v001 → v002)
   - Creates new folder `ProjectName_v002/`
   - Copies ALL project files (audio, MIDI, peaks, etc.)
   - Saves project file with new name
   - Opens the new version in Reaper

**Console output (success):**
```
RASP: Creating version _v002...
   📁 Target: /home/user/Projects/MySong_v002
✅ RASP: Version created successfully!
   📄 Project: MySong_v002.rpp
   🎵 Files: 47 copied
   📂 Location: /home/user/Projects/MySong_v002
```

**Console output (error):**
```
❌ RASP Error: Copy failed
   Reason: Source directory not found: /path/to/project
```

### Conflict Handling

If the target version folder already exists, RASP shows a dialog with three options:

<!-- TODO: Add screenshot of conflict dialog -->

| Option | Result |
|--------|--------|
| **Yes** (Create alongside) | Creates `MySong_v002_a/` (or `_b`, `_c`, etc.) |
| **No** (Overwrite) | Copies files over existing ones (no deletion) |
| **Cancel** | Aborts versioning, no changes made |

### Why Auto Mode is Safer

Reaper projects can have media references that are:
- **Absolute paths** - Point to specific locations on disk
- **Relative paths** - Point relative to project file location

When you manually copy/move a project without its media, these references break. RASP's Auto mode:

1. ✅ Copies the **entire project folder** (all files)
2. ✅ Creates a new `.rpp` file with the version name
3. ✅ Preserves relative path structure
4. ✅ Automatically opens the new version

This ensures your versioned projects are **100% self-contained** and portable.

---

## Roadmap

### Version 0.1 ✅
- RASP UI / plugin to Reaper
- ability to "auto version" from RASP UI
- increase version number when versioning

### Version 0.2 ✅
- Safe versioning with full media copy
- Native/Auto mode selection
- Conflict handling (alongside/overwrite/cancel)
- Console logging with detailed feedback

### Version 0.3 (planned)
- Archiving action of projects to local drive
- UI for archiving 
- Select how many versions are kept and rest are archived

### Version 0.4 (planned)
- Make archiving action of projects to Backblaze B2
- Able to pull back project from archive from Backblaze B2

### Future
- Find all Reaper projects (from Reaper media folder)
- Choose what projects will be archived and how many versions are kept
- Configuration option for single "Reaper media" folder
    
