--[[
  RASP Versioning Module
  
  Handles project versioning logic:
  - Parse current version from project name/path
  - Generate new version number
  - Create versioned copy of project with all media
]]--

local versioning = {}

-- Load dependencies (will be available after require in main script)
local config = require("config")
local file_ops = require("file_operations")

-- Get current project information
function versioning.get_project_info()
  -- Get current project
  local proj, proj_path = reaper.EnumProjects(-1)
  
  if not proj_path or proj_path == "" then
    return nil, "No project loaded"
  end
  
  proj_path = file_ops.normalize_path(proj_path)
  
  local proj_dir = file_ops.get_directory(proj_path)
  local proj_filename = file_ops.get_filename(proj_path)
  local proj_basename = file_ops.get_basename(proj_path)
  local proj_ext = file_ops.get_extension(proj_path)
  
  -- Parse version from project name
  local current_version = config.parse_version(proj_basename)
  
  -- Get base name without version suffix
  local base_name = proj_basename
  if current_version then
    local version_suffix = config.format_version(current_version)
    base_name = proj_basename:sub(1, -(#version_suffix + 1))
  end
  
  -- Get parent directory (where versioned folders are created)
  local parent_dir = file_ops.get_directory(proj_dir)
  
  -- If parent_dir is nil (project at root level or no parent available),
  -- use proj_dir itself to create versions in the same directory as the project file
  if not parent_dir or parent_dir == "" then
    parent_dir = proj_dir
  end
  
  return {
    project = proj,
    full_path = proj_path,
    directory = proj_dir,
    parent_directory = parent_dir,
    filename = proj_filename,
    basename = proj_basename,
    base_name = base_name,
    extension = proj_ext,
    current_version = current_version,
  }
end

-- Find highest existing version in parent directory
function versioning.find_highest_version(parent_dir, base_name)
  -- Return 0 if parent_dir is invalid (no existing versions can be found)
  if not parent_dir then return 0 end
  
  local highest = 0
  local prefix = config.get("version_prefix")
  
  local i = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(parent_dir, i)
    if not subdir then break end
    
    -- Check if this directory matches our naming pattern
    if subdir:sub(1, #base_name) == base_name then
      local version = config.parse_version(subdir)
      if version and version > highest then
        highest = version
      end
    end
    
    i = i + 1
  end
  
  return highest
end

-- Generate next version number
function versioning.get_next_version(info)
  if info.current_version then
    -- Project already has version, increment it
    return info.current_version + 1
  else
    -- New project, find highest existing version or start fresh
    local highest = versioning.find_highest_version(info.parent_directory, info.base_name)
    if highest > 0 then
      return highest + 1
    else
      return config.get("start_version")
    end
  end
end

-- Find available suffix when folder exists (a, b, c, ... z)
local function find_available_suffix(base_path)
  for i = 1, 26 do
    local suffix = "_" .. string.char(96 + i)  -- 'a', 'b', 'c', ...
    local new_path = base_path .. suffix
    if not file_ops.dir_exists(new_path) then
      return suffix
    end
  end
  return nil  -- All suffixes used (unlikely)
end

-- Log message to REAPER console
local function log_message(msg)
  reaper.ShowConsoleMsg(msg .. "\n")
end

-- Handle version folder conflict
-- Returns: new_path (modified if needed), or nil if user cancelled
local function handle_version_conflict(target_path, version_name)
  local msg = string.format(
    "Folder '%s' already exists!\n\nChoose action:\n" ..
    "YES = Create alongside (add suffix _a, _b, etc.)\n" ..
    "NO = Overwrite (merge files)\n" ..
    "CANCEL = Abort operation",
    version_name
  )
  
  local result = reaper.ShowMessageBox(msg, "RASP - Version Conflict", 3)
  
  if result == 6 then  -- Yes = Create alongside
    local suffix = find_available_suffix(target_path)
    if suffix then
      return target_path .. suffix
    else
      log_message("❌ RASP Error: All suffixes (a-z) are used for this version")
      return nil
    end
  elseif result == 7 then  -- No = Overwrite
    return target_path  -- Keep original path, will overwrite
  else  -- Cancel
    return nil
  end
end

-- Verify version copy was successful
local function verify_version_copy(new_dir, new_rpp_path, original_file_count)
  local errors = {}
  
  -- Check directory exists
  if not file_ops.dir_exists(new_dir) then
    table.insert(errors, "Target directory was not created: " .. new_dir)
  end
  
  -- Check RPP file exists
  if not file_ops.file_exists(new_rpp_path) then
    table.insert(errors, "Project file was not created: " .. new_rpp_path)
  end
  
  -- Check file count
  local new_count = file_ops.count_files_in_dir(new_dir)
  if new_count == 0 and original_file_count > 0 then
    table.insert(errors, string.format("No files copied (expected at least %d)", original_file_count))
  end
  
  if #errors > 0 then
    return false, table.concat(errors, "\n   ")
  end
  
  return true, new_count
end

-- Create new version with full automated copy (safe mode)
function versioning.create_new_version_safe()
  -- Get current project info
  local info, err = versioning.get_project_info()
  if not info then
    log_message("❌ RASP Error: " .. (err or "No project loaded"))
    return false, err or "No project loaded"
  end
  
  -- Calculate next version
  local next_version = versioning.get_next_version(info)
  local version_suffix = config.format_version(next_version)
  local new_folder_name = info.base_name .. version_suffix
  local new_folder_path = file_ops.join_path(info.parent_directory, new_folder_name)
  
  log_message("RASP: Creating version " .. version_suffix .. "...")
  log_message("   📁 Target: " .. new_folder_path)
  
  -- Check if target folder already exists
  if file_ops.dir_exists(new_folder_path) then
    new_folder_path = handle_version_conflict(new_folder_path, new_folder_name)
    if not new_folder_path then
      log_message("   ⚠️ Operation cancelled by user")
      return false, "Operation cancelled"
    end
    -- Update folder name from potentially modified path
    new_folder_name = file_ops.get_filename(new_folder_path)
    log_message("   📁 Using: " .. new_folder_path)
  end
  
  -- Count original files for verification
  local original_count = file_ops.count_files_in_dir(info.directory)
  
  -- Create target directory
  if not file_ops.create_directory(new_folder_path) then
    local err_msg = "Failed to create directory: " .. new_folder_path
    log_message("❌ RASP Error: " .. err_msg)
    return false, err_msg
  end
  
  -- Copy all project files (excluding .rpp files - we'll save a new one)
  local copy_success, copy_msg = file_ops.copy_project_files(info.directory, new_folder_path, true)
  if not copy_success then
    log_message("❌ RASP Error: Copy failed")
    log_message("   Reason: " .. (copy_msg or "Unknown error"))
    return false, copy_msg
  end
  
  -- Construct new RPP filename and path
  local new_rpp_name = new_folder_name .. ".rpp"
  local new_rpp_path = file_ops.join_path(new_folder_path, new_rpp_name)
  
  -- Save project to new location
  -- Use Main_SaveProjectEx with option 0 (normal save)
  reaper.Main_SaveProjectEx(0, new_rpp_path, 0)
  
  -- Verify the copy was successful
  local verify_success, verify_result = verify_version_copy(new_folder_path, new_rpp_path, original_count)
  
  if not verify_success then
    log_message("❌ RASP Error: Verification failed")
    log_message("   " .. verify_result)
    return false, "Verification failed: " .. verify_result
  end
  
  -- Open the new project in REAPER
  reaper.Main_openProject(new_rpp_path)
  
  -- Success logging
  log_message("✅ RASP: Version created successfully!")
  log_message("   📄 Project: " .. new_rpp_name)
  log_message("   🎵 Files: " .. verify_result .. " copied")
  log_message("   📂 Location: " .. new_folder_path)
  
  return true, string.format("Version %s created with %d files", version_suffix, verify_result)
end

-- Create a new versioned copy of the project
-- Mode is determined by config setting (native or auto)
function versioning.create_new_version(mode)
  -- Get mode from parameter or config
  if not mode then
    mode = config.get("versioning_mode") or "auto"
  end
  
  if mode == "native" then
    -- Open Reaper's native Save As dialog
    log_message("RASP: Opening Save As dialog...")
    log_message("   💡 Tip: Enable 'Copy all media into project directory' for safe versioning")
    reaper.Main_OnCommand(40022, 0)
    return true, "Save As dialog opened"
  else
    -- Use automated safe copy
    return versioning.create_new_version_safe()
  end
end

-- Get display string for current version
function versioning.get_version_display()
  local info, err = versioning.get_project_info()
  if not info then
    return "No project loaded"
  end
  
  if info.current_version then
    return string.format("v%d", info.current_version)
  else
    return "Not versioned"
  end
end

-- Get display string for project name
function versioning.get_project_display()
  local info, err = versioning.get_project_info()
  if not info then
    return "No project loaded"
  end
  
  return info.base_name
end

return versioning
