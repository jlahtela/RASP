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

-- Log message to REAPER console
local function log_message(msg)
  reaper.ShowConsoleMsg(msg .. "\n")
end

-- Handle version folder conflict
-- Returns: resolved_path, resolved_folder_name, or nil if user cancelled
local function handle_version_conflict(target_path, version_name, info, next_version)
  local msg = string.format(
    "Folder '%s' already exists!\n\nChoose action:\n" ..
    "YES = Increment version number (use next available)\n" ..
    "NO = Overwrite existing folder\n" ..
    "CANCEL = Do nothing",
    version_name
  )

  local result = reaper.ShowMessageBox(msg, "RASP - Version Conflict", 3)

  if result == 6 then  -- Yes = Increment version
    local try_version = next_version + 1
    while try_version <= 999 do
      local try_suffix = config.format_version(try_version)
      local try_name = info.base_name .. try_suffix
      local try_path = file_ops.join_path(info.parent_directory, try_name)
      if not file_ops.dir_exists(try_path) then
        return try_path, try_name
      end
      try_version = try_version + 1
    end
    log_message("❌ RASP Error: No available version number found (tried up to v999)")
    return nil
  elseif result == 7 then  -- No = Overwrite
    return target_path, version_name
  else  -- Cancel = Do nothing
    return nil
  end
end

-- Create new version (auto mode)
-- Uses Main_SaveProjectEx flag 3 = flag 1 (create subdirectory) + flag 2 (copy all media)
-- Reaper creates the folder, copies media, saves .rpp, and rewrites internal path references atomically.
-- Do NOT pre-create the directory — flag 1 expects to create it itself.
function versioning.create_new_version_safe()
  local info, err = versioning.get_project_info()
  if not info then
    log_message("❌ RASP Error: " .. (err or "No project loaded"))
    return false, err or "No project loaded"
  end

  local next_version = versioning.get_next_version(info)
  local version_suffix = config.format_version(next_version)
  local new_folder_name = info.base_name .. version_suffix
  local new_folder_path = file_ops.join_path(info.parent_directory, new_folder_name)

  log_message("RASP: Creating version " .. version_suffix .. "...")
  log_message("   📁 Target: " .. new_folder_path)

  -- Handle existing folder conflict
  if file_ops.dir_exists(new_folder_path) then
    local resolved_path, resolved_name = handle_version_conflict(new_folder_path, new_folder_name, info, next_version)
    if not resolved_path then
      log_message("   ⚠️ Operation cancelled by user")
      return true, "Operation cancelled"
    end
    new_folder_path = resolved_path
    new_folder_name = resolved_name
    log_message("   📁 Using: " .. new_folder_path)
  end

  -- Build project file path
  local new_rpp_name = new_folder_name .. ".rpp"
  local new_rpp_path = file_ops.join_path(new_folder_path, new_rpp_name)
  new_rpp_path = file_ops.normalize_path(new_rpp_path)

  -- Save using flag 3 = flag 1 (create subdirectory) + flag 2 (copy all media into project dir)
  -- Reaper creates the folder, copies all media, saves .rpp, and rewrites internal references.
  -- Do NOT pre-create the directory — flag 1 requires Reaper to create it itself.
  -- Main_SaveProjectEx returns void; verify success by checking file existence.
  reaper.Main_SaveProjectEx(info.project, new_rpp_path, 3)

  if not file_ops.file_exists(new_rpp_path) then
    local err_msg = "Save failed: project file not found at " .. new_rpp_path
    log_message("❌ RASP Error: " .. err_msg)
    return false, err_msg
  end

  log_message("✅ RASP: Version created successfully!")
  log_message("   📄 Project: " .. new_rpp_name)
  log_message("   📂 Location: " .. new_folder_path)

  return true, string.format("Version %s created", new_folder_name)
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
