--[[
  RASP File Operations Module
  
  Handles file system operations including:
  - Directory creation
  - File copying (cross-platform)
  - Media file collection from Reaper project
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

-- Copy a single file (cross-platform)
function file_ops.copy_file(source, dest)
  if not source or not dest then return false, "Invalid paths" end
  if not file_ops.file_exists(source) then return false, "Source not found: " .. source end
  
  source = file_ops.normalize_path(source)
  dest = file_ops.normalize_path(dest)
  
  local os_type = file_ops.get_os()
  local cmd
  
  if os_type == "windows" then
    -- Use copy command on Windows
    cmd = string.format('copy /Y "%s" "%s"', source, dest)
  else
    -- Use cp on Linux/macOS
    cmd = string.format('cp "%s" "%s"', source, dest)
  end
  
  local result = os.execute(cmd)
  
  if result == 0 or result == true then
    return true
  else
    return false, "Copy failed: " .. cmd
  end
end

-- Copy entire directory (cross-platform)
function file_ops.copy_directory(source, dest)
  if not source or not dest then return false, "Invalid paths" end
  
  source = file_ops.normalize_path(source)
  dest = file_ops.normalize_path(dest)
  
  local os_type = file_ops.get_os()
  local cmd
  
  if os_type == "windows" then
    -- Use robocopy on Windows (returns 0-7 for success)
    cmd = string.format('robocopy "%s" "%s" /E /NFL /NDL /NJH /NJS', source, dest)
    local result = os.execute(cmd)
    -- Robocopy returns 0-7 for various success states
    if type(result) == "number" then
      return result <= 7
    end
    return result == true
  else
    -- Use cp -r on Linux/macOS
    cmd = string.format('cp -r "%s"/* "%s"/', source, dest)
    local result = os.execute(cmd)
    return result == 0 or result == true
  end
end

-- Get all media files used in current project
function file_ops.get_project_media_files()
  local media_files = {}
  local seen = {} -- Avoid duplicates
  
  -- Iterate through all media items
  local item_count = reaper.CountMediaItems(0)
  for i = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take_count = reaper.CountTakes(item)
    
    for t = 0, take_count - 1 do
      local take = reaper.GetTake(item, t)
      if take then
        local source = reaper.GetMediaItemTake_Source(take)
        if source then
          local filename = reaper.GetMediaSourceFileName(source)
          if filename and filename ~= "" and not seen[filename] then
            seen[filename] = true
            table.insert(media_files, filename)
          end
        end
      end
    end
  end
  
  return media_files
end

-- Get all files in project directory (recursive)
function file_ops.get_all_project_files(project_dir)
  local files = {}
  
  local function scan_dir(dir, relative_path)
    -- Scan files
    local i = 0
    while true do
      local filename = reaper.EnumerateFiles(dir, i)
      if not filename then break end
      
      local full_path = file_ops.join_path(dir, filename)
      local rel_path = relative_path ~= "" and file_ops.join_path(relative_path, filename) or filename
      
      table.insert(files, {
        full_path = full_path,
        relative_path = rel_path,
        filename = filename
      })
      
      i = i + 1
    end
    
    -- Scan subdirectories
    i = 0
    while true do
      local subdir = reaper.EnumerateSubdirectories(dir, i)
      if not subdir then break end
      
      local full_subdir = file_ops.join_path(dir, subdir)
      local rel_subdir = relative_path ~= "" and file_ops.join_path(relative_path, subdir) or subdir
      
      scan_dir(full_subdir, rel_subdir)
      
      i = i + 1
    end
  end
  
  scan_dir(project_dir, "")
  return files
end

-- Copy all project files to new directory
function file_ops.copy_project_files(source_dir, dest_dir, exclude_rpp)
  if not file_ops.create_directory(dest_dir) then
    return false, "Could not create destination directory"
  end
  
  local files = file_ops.get_all_project_files(source_dir)
  local copied = 0
  local errors = {}
  
  for _, file_info in ipairs(files) do
    -- Skip .rpp files if requested (we'll save a new one)
    local skip = exclude_rpp and file_info.filename:match("%.rpp$")
    
    if not skip then
      -- Create subdirectory if needed
      local rel_dir = file_ops.get_directory(file_info.relative_path)
      if rel_dir and rel_dir ~= "" then
        local sub_dest = file_ops.join_path(dest_dir, rel_dir)
        file_ops.create_directory(sub_dest)
      end
      
      -- Copy file
      local dest_path = file_ops.join_path(dest_dir, file_info.relative_path)
      local success, err = file_ops.copy_file(file_info.full_path, dest_path)
      
      if success then
        copied = copied + 1
      else
        table.insert(errors, err or ("Failed: " .. file_info.relative_path))
      end
    end
  end
  
  if #errors > 0 then
    return false, string.format("Copied %d files, %d errors", copied, #errors)
  end
  
  return true, string.format("Copied %d files", copied)
end

return file_ops
