# RASP Development Guide

## Cross-Platform Compatibility

RASP is designed to work seamlessly on **Linux (Debian/Ubuntu)** and **Windows 10/11**. This guide explains how to maintain cross-platform compatibility.

### Key Principles

1. **Path Separators**: Always use the `file_operations` module for path handling
2. **Line Endings**: Git will automatically handle line endings via `.gitattributes`
3. **Shell Commands**: Use platform detection before executing OS-specific commands
4. **Case Sensitivity**: Linux filesystems are case-sensitive; always match exact filenames

### Testing Your Changes

Before submitting a PR, test on both platforms:

#### Linux/Debian Testing
```bash
# Install Lua if needed
sudo apt-get install lua5.4

# Run tests
./test-linux.sh
```

#### Windows Testing
```powershell
# Install Lua if needed (using Chocolatey)
choco install lua

# Run tests
.\test-windows.ps1
```

### CI/CD Pipeline

Every push triggers automated tests on both platforms via GitHub Actions:
- Ubuntu Latest (representing Debian/Linux)
- Windows Latest

See `.github/workflows/test.yml` for details.

## Code Guidelines

### Path Operations

**✓ DO:**
```lua
local file_ops = require("file_operations")

-- Use cross-platform functions
local dir = file_ops.get_directory(path)
local filename = file_ops.get_filename(path)
local joined = file_ops.join_path(dir, filename)
local sep = file_ops.get_separator()
```

**✗ DON'T:**
```lua
-- Hardcoded separators
local path = "C:\\Users\\test\\file.txt"  -- Windows-only
local path = "/home/user/file.txt"       -- Linux-only

-- String concatenation with separators
local path = dir .. "/" .. file  -- Wrong separator on Windows
```

### Shell Commands

**✓ DO:**
```lua
local os_type = file_ops.get_os()

if os_type == "windows" then
  -- Windows command
  cmd = 'copy "source" "dest"'
else
  -- Linux/macOS command
  cmd = 'cp "source" "dest"'
end
```

**✗ DON'T:**
```lua
-- Assuming one OS
os.execute('cp file1 file2')  -- Fails on Windows
os.execute('copy file1 file2')  -- Fails on Linux
```

### Module Loading

Lua's `require()` and `package.path` use forward slashes on all platforms:

**✓ DO:**
```lua
package.path = script_path .. "/modules/?.lua;" .. package.path
local config = require("config")
```

**✗ DON'T:**
```lua
-- OS-specific separators in package.path
package.path = script_path .. "\\" .. "modules\\?.lua"  -- Wrong
```

### Line Endings

The `.gitattributes` file ensures correct line endings:
- `.lua` files → LF (Unix-style)
- `.sh` files → LF
- `.bat`, `.cmd`, `.ps1` files → CRLF (Windows-style)

Git handles this automatically; you don't need to worry about it.

## Reaper API

All Reaper API calls work identically on all platforms, with one exception:

```lua
-- Returns "Win64", "Linux", or "OSX"/"macOS"
local os_name = reaper.GetOS()
```

Use this to detect the OS when needed for platform-specific operations.

## Common Pitfalls

### 1. Case Sensitivity

Linux filenames are case-sensitive:
```lua
-- On Linux, these are DIFFERENT files:
require("config")  -- modules/config.lua
require("Config")  -- modules/Config.lua (won't be found if file is lowercase)
```

### 2. Hidden Files

Linux uses dot-prefix for hidden files (`.hidden`), while Windows uses file attributes.

Our `cp -a` command on Linux preserves hidden files:
```lua
-- Copies all files including .hidden ones
-- The "/." syntax copies directory contents, not the directory itself
cmd = string.format('cp -a "%s"/. "%s"', source, dest)
```

### 3. Permissions

On Linux, ensure directories are writable:
```bash
chmod 755 /path/to/project
```

Windows typically doesn't require manual permission management for user directories.

### 4. Path Lengths

Windows has a 260-character path limit (can be disabled in Windows 10+), while Linux supports much longer paths (typically 4096 characters).

Keep project names and paths reasonable for Windows compatibility.

## Adding New Features

When adding features that interact with the filesystem or shell:

1. **Design for both platforms** from the start
2. **Use `file_operations` module** for all path operations
3. **Test on both Linux and Windows** before submitting PR
4. **Update test scripts** if you add new modules or functionality
5. **Document platform-specific behavior** in code comments

## Debugging

### On Linux
```bash
# Check Lua syntax
luac5.4 -p file.lua

# Test module loading
lua5.4 -e "dofile('modules/file_operations.lua')"

# Check file types and line endings
file *.lua modules/*.lua
```

### On Windows
```powershell
# Check Lua syntax
lua -e "return loadfile('file.lua')"

# Test module loading
lua -e "dofile('modules/file_operations.lua')"

# Check line endings
Get-Content file.lua -Raw | ForEach-Object { $_ -match "`r`n" }
```

## Resources

- [Reaper API Documentation](https://www.reaper.fm/sdk/reascript/reascripthelp.html)
- [Lua 5.4 Reference](https://www.lua.org/manual/5.4/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## Questions?

If you encounter cross-platform issues or have questions, please open an issue on GitHub with:
- Your OS and version (e.g., "Debian 12", "Windows 11")
- Reaper version
- Error message or unexpected behavior
- Steps to reproduce
