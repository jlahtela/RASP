# RASP Cross-Platform Test Script for Windows
# This script verifies that RASP works correctly on Windows systems

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  RASP Windows Compatibility Test" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$TestsPassed = 0
$TestsFailed = 0

function Test-Result {
    param($Success, $Message)
    if ($Success) {
        Write-Host "✓ PASS: $Message" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "✗ FAIL: $Message" -ForegroundColor Red
        $script:TestsFailed++
    }
}

Write-Host "1. Checking Lua installation..."
$luaCmd = Get-Command lua -ErrorAction SilentlyContinue
if ($null -eq $luaCmd) {
    Write-Host "ERROR: Lua not found!" -ForegroundColor Red
    Write-Host "Please install Lua from: https://www.lua.org/download.html"
    Write-Host "Or use Chocolatey: choco install lua"
    exit 1
}
lua -v
Write-Host ""

Write-Host "2. Checking Lua syntax for all files..."
Get-ChildItem -Path . -Include *.lua -Recurse | ForEach-Object {
    try {
        $output = lua -e "return loadfile('$($_.FullName)')" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Test-Result $true "Syntax check: $($_.Name)"
        } else {
            Test-Result $false "Syntax check: $($_.Name)"
        }
    } catch {
        Test-Result $false "Syntax check: $($_.Name) - $_"
    }
}
Write-Host ""

Write-Host "3. Verifying line endings..."
Get-ChildItem -Path . -Include *.lua -Recurse | ForEach-Object {
    $content = Get-Content -Raw $_.FullName
    # Check for consistent line endings
    $crlfCount = ([regex]::Matches($content, "`r`n")).Count
    $lfOnlyCount = ([regex]::Matches($content, "(?<!\r)`n")).Count
    
    if ($lfOnlyCount -eq 0 -or $crlfCount -eq 0) {
        Test-Result $true "Line endings: $($_.Name)"
    } else {
        Test-Result $false "Line endings: $($_.Name) (mixed)"
    }
}
Write-Host ""

Write-Host "4. Testing file_operations module..."
$testScript = @'
-- Mock reaper functions for testing
reaper = {
    GetOS = function() return "Win64" end,
    file_exists = function(path) return true end,
    EnumerateFiles = function() return nil end,
    EnumerateSubdirectories = function() return nil end,
    RecursiveCreateDirectory = function() end,
}

-- Load the module
local file_ops = dofile('modules/file_operations.lua')

-- Test 1: OS detection
assert(file_ops.get_os() == "windows", "OS detection failed")
print("   ✓ OS detection: windows")

-- Test 2: Path separator
assert(file_ops.get_separator() == "\\", "Path separator wrong")
print("   ✓ Path separator: \\")

-- Test 3: Path parsing
local test_path = "C:\\Users\\test\\projects\\MyProject\\file.lua"
assert(file_ops.get_directory(test_path) == "C:\\Users\\test\\projects\\MyProject", "get_directory failed")
print("   ✓ Path parsing: get_directory")

assert(file_ops.get_filename(test_path) == "file.lua", "get_filename failed")
print("   ✓ Path parsing: get_filename")

assert(file_ops.get_basename(test_path) == "file", "get_basename failed")
print("   ✓ Path parsing: get_basename")

assert(file_ops.get_extension(test_path) == ".lua", "get_extension failed")
print("   ✓ Path parsing: get_extension")

-- Test 4: Path normalization (Linux to Windows)
local unix_path = "/home/user/file.txt"
local normalized = file_ops.normalize_path(unix_path)
assert(normalized == "\\home\\user\\file.txt", "Path normalization failed")
print("   ✓ Path normalization: Linux -> Windows")

-- Test 5: Path joining
local joined = file_ops.join_path("C:\\Users", "test", "file.lua")
assert(joined == "C:\\Users\\test\\file.lua", "Path join failed")
print("   ✓ Path joining")

print("\n   All file_operations tests passed!")
'@

try {
    $output = lua -e $testScript 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $output
        Test-Result $true "file_operations module"
    } else {
        Write-Host $output
        Test-Result $false "file_operations module"
    }
} catch {
    Test-Result $false "file_operations module - $_"
}
Write-Host ""

Write-Host "5. Testing config module..."
$testScript = @'
-- Mock reaper functions
reaper = {
    GetExtState = function() return "" end,
    SetExtState = function() end,
}

-- Load the module
local config = dofile('modules/config.lua')

-- Test version formatting
config.init()
local formatted = config.format_version(42)
assert(formatted == "_v042", "Version formatting failed")
print("   ✓ Version formatting: " .. formatted)

-- Test version parsing
local version = config.parse_version("MyProject_v001")
assert(version == 1, "Version parsing failed")
print("   ✓ Version parsing: v001 -> 1")

version = config.parse_version("Test_v042")
assert(version == 42, "Version parsing failed")
print("   ✓ Version parsing: v042 -> 42")

print("\n   All config tests passed!")
'@

try {
    $output = lua -e $testScript 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $output
        Test-Result $true "config module"
    } else {
        Write-Host $output
        Test-Result $false "config module"
    }
} catch {
    Test-Result $false "config module - $_"
}
Write-Host ""

Write-Host "6. Checking for Windows commands compatibility..."
if (Get-Command copy -ErrorAction SilentlyContinue) {
    Test-Result $true "copy command available"
} else {
    Test-Result $false "copy command NOT available"
}

if (Get-Command robocopy -ErrorAction SilentlyContinue) {
    Test-Result $true "robocopy command available"
} else {
    Test-Result $false "robocopy command NOT available"
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
if ($TestsFailed -gt 0) {
    Write-Host "  Failed: $TestsFailed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Some tests failed. Please review the output above." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "  All tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "RASP is compatible with this Windows system." -ForegroundColor Green
    exit 0
}
