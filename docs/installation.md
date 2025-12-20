# RASP Installation Guide

## Requirements

### Required
- **Reaper DAW** v6.0 or newer (tested with v7.x)
- **Operating System**: Linux (Debian), Windows, or macOS

### Recommended: SWS Extension

The **SWS Extension** adds powerful features to Reaper and enables RASP to automatically configure settings.

**Benefits with SWS installed:**
- RASP can automatically enable "Copy imported media to project media directory" setting
- Better integration with Reaper's internal configuration

**Installation:**
1. Go to https://www.sws-extension.org/
2. Download the installer for your operating system
3. Run the installer (Reaper should be closed)
4. Restart Reaper - SWS will be automatically loaded

**Without SWS:**
- RASP will still work, but you'll need to configure Reaper settings manually
- RASP will show instructions if a setting needs to be changed

## Installation Steps

### 1. Locate Reaper Scripts Folder

In Reaper, go to:
- **Options** → **Show REAPER resource path in explorer/finder**

This opens your Reaper resource folder. Navigate to the `Scripts` subfolder (create it if it doesn't exist).

### 2. Copy RASP Files

Copy the entire `RASP` folder into the `Scripts` directory:

```
REAPER/
└── Scripts/
    └── RASP/
        ├── RASP.lua
        └── modules/
            ├── config.lua
            ├── file_operations.lua
            ├── gui.lua
            └── versioning.lua
```

### 3. Load Script in Reaper

1. Open Reaper
2. Open the **Actions** menu (shortcut: `?` or `Shift+/`)
3. Click **"Load..."** or **"New action" → "Load ReaScript..."**
4. Navigate to `Scripts/RASP/RASP.lua`
5. Select it and click **Open**

### 4. Add Keyboard Shortcut (Optional)

1. In the Actions window, find "Script: RASP.lua"
2. Select it and click **"Add..."** to assign a keyboard shortcut
3. Recommended: `Ctrl+Alt+V` for quick version creation

### 5. Add to Toolbar (Optional)

1. Right-click any toolbar
2. Choose **Customize toolbar...**
3. Find "Script: RASP.lua" in the actions list
4. Drag it to your toolbar

## Usage

### Creating a New Version

1. Open a project in Reaper
2. Launch RASP (via Actions menu, shortcut, or toolbar)
3. Click **"Create New Version"**

RASP will:
- Create a new folder with incremented version number
- Copy ALL project files to the new folder
- Save the project with the new version name
- Switch to the new version automatically

### Version Naming

Projects are versioned as:
```
ProjectName_v001/ProjectName_v001.rpp
ProjectName_v002/ProjectName_v002.rpp
ProjectName_v003/ProjectName_v003.rpp
```

### First Version

If your project isn't versioned yet, RASP will:
- Detect the project name (e.g., `MySong.rpp`)
- Create `MySong_v001/MySong_v001.rpp`
- Copy all media to the new folder

## Configuration

Settings are stored in Reaper's ExtState and persist across sessions:

| Setting | Default | Description |
|---------|---------|-------------|
| `version_prefix` | `_v` | Text before version number |
| `version_digits` | `3` | Number of digits (e.g., 001) |
| `start_version` | `1` | First version number |

To modify (advanced):
```lua
-- In Reaper's ReaScript console
reaper.SetExtState("RASP", "version_prefix", "_ver", true)
reaper.SetExtState("RASP", "version_digits", "4", true)
```

## Platform-Specific Notes

### Debian Linux (Primary Target)

RASP is developed and tested primarily on **Debian 12 (Bookworm)**. It is fully compatible with Debian-based distributions including Ubuntu.

**Requirements:**
- Reaper DAW installed (see https://www.reaper.fm/download.php)
- Standard GNU utilities (`cp`, `mkdir`) - pre-installed on Debian
- Lua (for testing): `sudo apt-get install lua5.4`

**Testing your installation:**
```bash
cd /path/to/REAPER/Scripts/RASP
./test-linux.sh
```

The test script will detect your OS and confirm Debian compatibility.

**File paths:**
- RASP automatically uses Unix-style forward slashes (`/`) on Linux
- All file operations are cross-platform compatible

**Permissions:**
- Make sure Reaper has write permissions to your project directories
- If using external drives, ensure they're mounted with proper permissions

### Ubuntu and other Debian-based distributions

Ubuntu and other Debian-based distributions are fully supported as they share the same core utilities and package management with Debian.

### Windows

RASP fully supports Windows 10 and Windows 11.

**Requirements:**
- Standard Windows commands (`copy`, `robocopy`) - pre-installed

**Testing your installation:**
```powershell
cd C:\path\to\REAPER\Scripts\RASP
.\test-windows.ps1
```

**File paths:**
- RASP automatically uses Windows-style backslashes (`\`) on Windows
- Works with network drives and UNC paths

## Troubleshooting

### "No project loaded"
- Make sure you have a project open in Reaper
- Save your project at least once before using RASP

### Files not copying
- Check write permissions on the destination folder
- Ensure enough disk space is available
- **On Linux/Debian:** verify `cp` command is available (run `which cp`)
- **On Windows:** verify `copy` and `robocopy` commands are available
- **On Linux:** Check file permissions with `ls -la`

### Permission denied errors (Linux)
- Ensure the destination directory is writable: `chmod 755 /path/to/projects`
- Check if the filesystem is mounted read-only: `mount | grep /path/to/drive`
- For external drives, remount with write permissions

### Window doesn't dock
- The RASP window can be docked by dragging it to a dock area
- Window position and dock state are saved automatically

## Uninstallation

1. Remove `Scripts/RASP/` folder
2. In Reaper Actions, right-click the RASP action and remove it
3. (Optional) Clear settings:
   ```lua
   reaper.DeleteExtState("RASP", "version_prefix", true)
   reaper.DeleteExtState("RASP", "version_digits", true)
   -- etc.
   ```

## Future Versions

- **v0.2**: Local archiving with configurable destinations
- **v0.3**: Project discovery and batch operations
- **v0.4**: Cloud archiving (Backblaze, S3, Azure, Storj)
