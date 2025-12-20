# RASP
Reaper Archiving System Project

A Lua plugin for Reaper DAW that provides automatic project versioning with full media backup.

## Features (v0.1)

- **Dockable UI** - Native Reaper interface
- **Auto-versioning** - Open save as dialog
- **Cross-platform** - Tested and verified on Debian Linux (Debian 12 Bookworm) and Windows 10/11
- **Zero dependencies** - Uses standard Lua and OS utilities

## Requirements

### Required
- **Reaper DAW** v6.0 or newer (tested with v7.x)
- **Operating System**: 
  - **Debian 12 (Bookworm)** or newer - Primary target platform
  - Ubuntu 22.04+ (Debian-based, fully compatible)
  - Windows 10 or Windows 11
  - macOS (should work but not extensively tested)

### Recommended
No extensions or additional packages needed. RASP uses standard Lua and OS utilities (`cp` on Linux, `copy`/`robocopy` on Windows).

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
4. Click "Create New Version" to version your project

See [installation guide](docs/installation.md) for detailed instructions.

## Testing & Verification

To verify RASP works correctly on your platform:

**Linux/Debian:**
```bash
cd /path/to/REAPER/Scripts/RASP
./test-linux.sh
```

**Windows:**
```powershell
cd C:\path\to\REAPER\Scripts\RASP
.\test-windows.ps1
```

These scripts will verify:
- Lua syntax for all files
- Cross-platform path operations
- Line ending consistency
- Required system commands availability

## Version Format

```
MyProject/MyProject.rpp          → Original
MyProject_v001/MyProject_v001.rpp  → Version 1
MyProject_v002/MyProject_v002.rpp  → Version 2
```

---

## Roadmap

### Version 0.1 goals
- RASP UI / plugin to Reaper
- ability to "auto version" from RASP UI
- increase version number when versioning

### Version 0.2 goals
- make archiving action of projects to local drive
- UI for archiving 
- Select how many versions are kept and rest are achived

### Version 0.3 goals
- Make archiving action of projects to Backblaze B2
- Able to pull back project from archive from Backblaze B2

### Version 0.3 goals

- find all repaer projects (from REPER media folder)
    - Able to choose what projects will be archived and how many versions are kept
    - Configuration option for singe "Reaper media" folder
    
