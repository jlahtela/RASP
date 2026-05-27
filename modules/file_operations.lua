--[[
  RASP File Operations Module

  Handles file system operations for Linux only.
  Windows is not supported — archiving (copy/delete directories)
  relies on shell commands (cp, rm) that are not available on Windows.
]]--

local file_ops = {}

-- Detect operating system
function file_ops.get_os()
  local os_name = reaper.GetOS()
  if os_name:match("Win") then
    return "windows"
  elseif os_name:match("OSX") or os_name:match("macOS") then
    return "macos"
  else
    return "linux"
  end
end

-- Get path separator for current OS
function file_ops.get_separator()
  if file_ops.get_os() == "windows" then
    return "\\"
  else
    return "/"
  end
end

-- Normalize path separators for current OS
function file_ops.normalize_path(path)
  if not path then return nil end
  local sep = file_ops.get_separator()
  if sep == "\\" then
    return path:gsub("/", "\\")
  else
    return path:gsub("\\", "/")
  end
end

-- Join path components
function file_ops.join_path(...)
  local sep = file_ops.get_separator()
  local parts = {...}
  local result = table.concat(parts, sep)
  -- Clean up double separators
  result = result:gsub(sep .. sep, sep)
  return result
end

-- Extract directory from full path
function file_ops.get_directory(path)
  if not path then return nil end
  path = file_ops.normalize_path(path)
  local sep = file_ops.get_separator()
  
  -- Find last separator by index (more reliable than pattern matching
  -- for paths with special characters like spaces and dashes)
  local last_sep = nil
  for i = #path, 1, -1 do
    if path:sub(i, i) == sep then
      last_sep = i
      break
    end
  end
  
  if last_sep and last_sep > 1 then
    return path:sub(1, last_sep - 1)
  end
  return nil
end

-- Extract filename from full path
function file_ops.get_filename(path)
  if not path then return nil end
  path = file_ops.normalize_path(path)
  local sep = file_ops.get_separator()
  
  -- Find last separator by index (more reliable than pattern matching
  -- for paths with special characters like spaces and dashes)
  local last_sep = nil
  for i = #path, 1, -1 do
    if path:sub(i, i) == sep then
      last_sep = i
      break
    end
  end
  
  if last_sep then
    return path:sub(last_sep + 1)
  end
  return path  -- No separator found, return entire path as filename
end

-- Extract filename without extension
function file_ops.get_basename(path)
  local filename = file_ops.get_filename(path)
  if not filename then return nil end
  return filename:match("(.+)%..+$") or filename
end

-- Extract file extension (including dot)
function file_ops.get_extension(path)
  local filename = file_ops.get_filename(path)
  if not filename then return nil end
  return filename:match("(%..+)$") or ""
end

-- Check if file exists
function file_ops.file_exists(path)
  if not path then return false end
  return reaper.file_exists(path)
end

-- Check if directory exists
function file_ops.dir_exists(path)
  if not path then return false end
  path = file_ops.normalize_path(path)
  
  -- Try to enumerate files - if it works, directory exists
  local test = reaper.EnumerateFiles(path, 0)
  if test then return true end
  
  -- Also check if it's an empty directory by trying to enumerate subdirs
  test = reaper.EnumerateSubdirectories(path, 0)
  if test then return true end
  
  -- For empty directories, try to create a temp file to verify access
  -- This is more reliable than EnumerateFiles/Subdirs for empty folders
  local sep = file_ops.get_separator()
  local test_file = path .. sep .. ".rasp_test_" .. os.time()
  local f = io.open(test_file, "w")
  if f then
    f:close()
    os.remove(test_file)
    return true
  end
  
  return false
end

-- Create directory (recursively)
function file_ops.create_directory(path)
  if not path then return false end
  path = file_ops.normalize_path(path)
  reaper.RecursiveCreateDirectory(path, 0)
  
  -- Verify directory was created
  if file_ops.dir_exists(path) then
    return true
  end
  
  -- Fallback: RecursiveCreateDirectory doesn't return status,
  -- but if we got here without error, assume success
  -- (dir_exists can fail for empty directories in some edge cases)
  return true
end

-- Copy entire directory (Linux/macOS only)
function file_ops.copy_directory(source, dest)
  if not source or not dest then return false, "Invalid paths" end
  if not file_ops.dir_exists(source) then return false, "Source directory not found: " .. source end

  source = file_ops.normalize_path(source)
  dest = file_ops.normalize_path(dest)

  if not file_ops.dir_exists(dest) then
    file_ops.create_directory(dest)
  end

  local result = os.execute(string.format('cp -r "%s/." "%s"', source, dest))
  if result ~= true and result ~= 0 then
    return false, "Copy failed for: " .. source
  end

  if not file_ops.dir_exists(dest) then
    return false, "Copy verification failed: destination does not exist"
  end

  return true
end

-- Delete entire directory (Linux/macOS only)
function file_ops.delete_directory(path)
  if not path or path == "" then return false, "Invalid path" end
  if not file_ops.dir_exists(path) then return false, "Directory not found: " .. path end

  path = file_ops.normalize_path(path)

  -- Safety check: don't delete root or very short paths
  if #path < 10 then
    return false, "Safety check: path too short to delete"
  end

  local result = os.execute(string.format('rm -rf "%s"', path))
  if result ~= true and result ~= 0 then
    return false, "Delete failed for: " .. path
  end

  if file_ops.dir_exists(path) then
    return false, "Delete verification failed: directory still exists"
  end

  return true
end

return file_ops
