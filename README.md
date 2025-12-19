# RASP
Reaper Archiving System Project

A Lua plugin for Reaper DAW that provides automatic project versioning with full media backup.

## Features (v0.1)

- **Dockable UI** - Native Reaper interface
- **Auto-versioning** - Create versioned copies with one click
- **Full project copy** - All media files copied to new version folder
- **Cross-platform** - Works on Linux (Debian), Windows, and macOS

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

Version 0.2 goals
- make archiving action of projects to local drive
- UI for archiving 

Version 0.3 goals

- find all repaer projects (from REPER media folder)
    - Able to choose what projects will be archived 
    - Configuration option for singe "Reaper media" folder
    
Version 0.4 goals
- Make archiving action of projects to ?
- Able to pull back project from archive 

Archive options:
- Backblaze
- Amazon S3
- Azure file
- Storj
