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

-- Create a new versioned copy of the project
function versioning.create_new_version()
  -- Get current project info
  local info, err = versioning.get_project_info()
  if not info then
    return false, err
  end
  
  -- Calculate next version
  local next_version = versioning.get_next_version(info)
  local version_suffix = config.format_version(next_version)
  
  -- Generate new folder and file names
  local new_folder_name = info.base_name .. version_suffix
  local new_project_name = info.base_name .. version_suffix .. info.extension
  
  -- Create new paths
  local new_folder_path = file_ops.join_path(info.parent_directory, new_folder_name)
  local new_project_path = file_ops.join_path(new_folder_path, new_project_name)
  
  -- Check if destination already exists
  if file_ops.dir_exists(new_folder_path) then
    return false, "Version folder already exists: " .. new_folder_name
  end
  
  -- Create destination directory
  if not file_ops.create_directory(new_folder_path) then
    return false, "Could not create folder: " .. new_folder_name
  end
  
  -- Copy all project files (excluding .rpp)
  local copy_success, copy_msg = file_ops.copy_project_files(
    info.directory, 
    new_folder_path, 
    true  -- exclude .rpp files
  )
  
  if not copy_success then
    return false, "File copy error: " .. copy_msg
  end
  
  -- Save project to new location
  -- Option &8 = set as new project filename
  reaper.Main_SaveProjectEx(info.project, new_project_path, 8)
  
  -- Verify save succeeded
  local _, new_path = reaper.EnumProjects(-1)
  if new_path and file_ops.normalize_path(new_path) == file_ops.normalize_path(new_project_path) then
    return true, new_folder_name
  else
    return false, "Project save failed"
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
