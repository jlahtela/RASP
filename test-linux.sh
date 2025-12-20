#!/usr/bin/env bash
# RASP Cross-Platform Test Script for Linux/Debian
# This script verifies that RASP works correctly on Debian-based Linux systems

echo "================================================"
echo "  RASP Linux Compatibility Test"
echo "================================================"
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Testing on: $PRETTY_NAME"
    if [[ "$ID" == "debian" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
        echo "✓ Debian-based system detected"
    else
        echo "⚠ Warning: Not a Debian-based system"
    fi
    echo ""
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

echo "1. Checking Lua installation..."
if command -v lua5.4 &> /dev/null; then
    LUA_CMD="lua5.4"
    LUAC_CMD="luac5.4"
    echo "   Found: lua5.4"
elif command -v lua5.3 &> /dev/null; then
    LUA_CMD="lua5.3"
    LUAC_CMD="luac5.3"
    echo "   Found: lua5.3"
elif command -v lua &> /dev/null; then
    LUA_CMD="lua"
    LUAC_CMD="luac"
    echo "   Found: lua"
else
    echo -e "${RED}ERROR: Lua not found!${NC}"
    echo "Please install Lua: sudo apt-get install lua5.4"
    exit 1
fi

$LUA_CMD -v
echo ""

echo "2. Checking Lua syntax for all files..."
for file in RASP.lua modules/*.lua; do
    if [ -f "$file" ]; then
        $LUAC_CMD -p "$file" 2>&1
        test_result $? "Syntax check: $file"
    fi
done
echo ""

echo "3. Verifying line endings (should be LF, not CRLF)..."
for file in RASP.lua modules/*.lua; do
    if [ -f "$file" ]; then
        if file "$file" | grep -q "CRLF"; then
            test_result 1 "Line endings: $file (has CRLF)"
        else
            test_result 0 "Line endings: $file (LF)"
        fi
    fi
done
echo ""

echo "4. Testing file_operations module..."
$LUA_CMD << 'EOF'
-- Mock reaper functions for testing
reaper = {
    GetOS = function() return "Linux" end,
    file_exists = function(path) return true end,
    EnumerateFiles = function() return nil end,
    EnumerateSubdirectories = function() return nil end,
    RecursiveCreateDirectory = function() end,
}

-- Load the module
local file_ops = dofile('modules/file_operations.lua')

-- Test 1: OS detection
assert(file_ops.get_os() == "linux", "OS detection failed")
print("   ✓ OS detection: linux")

-- Test 2: Path separator
assert(file_ops.get_separator() == "/", "Path separator wrong")
print("   ✓ Path separator: /")

-- Test 3: Path parsing
local test_path = "/home/user/projects/MyProject/file.lua"
assert(file_ops.get_directory(test_path) == "/home/user/projects/MyProject", "get_directory failed")
print("   ✓ Path parsing: get_directory")

assert(file_ops.get_filename(test_path) == "file.lua", "get_filename failed")
print("   ✓ Path parsing: get_filename")

assert(file_ops.get_basename(test_path) == "file", "get_basename failed")
print("   ✓ Path parsing: get_basename")

assert(file_ops.get_extension(test_path) == ".lua", "get_extension failed")
print("   ✓ Path parsing: get_extension")

-- Test 4: Path normalization (Windows to Linux)
local win_path = "C:\\Users\\test\\file.txt"
local normalized = file_ops.normalize_path(win_path)
assert(normalized == "C:/Users/test/file.txt", "Path normalization failed")
print("   ✓ Path normalization: Windows -> Linux")

-- Test 5: Path joining
local joined = file_ops.join_path("/home", "user", "test.lua")
assert(joined == "/home/user/test.lua", "Path join failed")
print("   ✓ Path joining")

-- Test 6: count_files_in_dir function (new in V0.2)
local count = file_ops.count_files_in_dir("/nonexistent")
assert(count == 0, "count_files_in_dir should return 0 for nonexistent dir")
print("   ✓ count_files_in_dir returns 0 for nonexistent directory")

print("\n   All file_operations tests passed!")
EOF
test_result $? "file_operations module"
echo ""

echo "5. Testing config module..."
$LUA_CMD << 'EOF'
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
assert(formatted == "_v042", "Version formatting failed, got: " .. formatted)
print("   ✓ Version formatting: " .. formatted)

-- Test version parsing
local version = config.parse_version("MyProject_v001")
assert(version == 1, "Version parsing failed")
print("   ✓ Version parsing: v001 -> 1")

version = config.parse_version("Test_v042")
assert(version == 42, "Version parsing failed")
print("   ✓ Version parsing: v042 -> 42")

print("\n   All config tests passed!")
EOF
test_result $? "config module"
echo ""

echo "6. Checking for shell commands compatibility..."
if command -v cp &> /dev/null; then
    test_result 0 "cp command available"
else
    test_result 1 "cp command NOT available"
fi

echo ""
echo "================================================"
echo "  Test Summary"
echo "================================================"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo "Some tests failed. Please review the output above."
    exit 1
else
    echo -e "  ${GREEN}All tests passed!${NC}"
    echo ""
    echo "RASP is compatible with this Linux system."
    exit 0
fi
