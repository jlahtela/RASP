--[[
  RASP Archiving Module
  
  Handles project archiving logic:
  - Find all version folders for a project
  - Determine which versions should be archived
  - Move old versions to archive destination
]]--

local archiving = {}

-- Load dependencies
local config = require("config")
local file_ops = require("file_operations")
local versioning = require("versioning")

-- Find all version folders for a project in the parent directory
function archiving.find_all_versions(parent_dir, base_name)
  if not parent_dir then return {} end
  
  local versions = {}
  local prefix = config.get("version_prefix")
  
  local i = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(parent_dir, i)
    if not subdir then break end
    
    -- Check if this directory matches our naming pattern
    if subdir:sub(1, #base_name) == base_name then
      local version = config.parse_version(subdir)
      if version then
        table.insert(versions, {
          name = subdir,
          version = version,
          path = file_ops.join_path(parent_dir, subdir)
        })
      end
    end
    
    i = i + 1
  end
  
  -- Sort by version number
  table.sort(versions, function(a, b) return a.version < b.version end)
  
  return versions
end

-- Get versions that should be archived based on current version and keep count
function archiving.get_versions_to_archive(current_version, versions_to_keep)
  local info = versioning.get_project_info()
  if not info then
    return {}, "No project loaded"
  end
  
  -- Find all versions
  local all_versions = archiving.find_all_versions(info.parent_directory, info.base_name)
  
  if #all_versions == 0 then
    return {}, "No versioned folders found"
  end
  
  -- Determine which versions to archive
  local to_archive = {}
  local cutoff_version = current_version - versions_to_keep
  
  for _, ver in ipairs(all_versions) do
    -- Archive if version is less than cutoff AND not the current version
    if ver.version < cutoff_version and ver.version ~= current_version then
      table.insert(to_archive, ver)
    end
  end
  
  return to_archive, nil
end

-- Archive versions by moving them to archive destination
function archiving.archive_versions(archive_dest, versions_to_keep)
  -- Validate archive destination
  if not archive_dest or archive_dest == "" then
    return false, "Archive destination not set"
  end
  
  -- Create archive destination if it doesn't exist
  if not file_ops.dir_exists(archive_dest) then
    local success = file_ops.create_directory(archive_dest)
    if not success then
      return false, "Could not create archive destination"
    end
  end
  
  -- Get project info
  local info = versioning.get_project_info()
  if not info then
    return false, "No project loaded"
  end
  
  -- Get current version
  local current_version = info.current_version or 0
  
  -- Get versions to archive
  local to_archive, err = archiving.get_versions_to_archive(current_version, versions_to_keep)
  if err then
    return false, err
  end
  
  if #to_archive == 0 then
    return true, "No versions to archive"
  end
  
  -- Archive each version (creates copies, originals are preserved)
  local archived_count = 0
  local errors = {}
  
  for _, ver in ipairs(to_archive) do
    local dest_path = file_ops.join_path(archive_dest, ver.name)
    
    -- Copy directory to archive location
    local success = file_ops.copy_directory(ver.path, dest_path)
    
    if success then
      archived_count = archived_count + 1
    else
      table.insert(errors, "Failed to archive: " .. ver.name)
    end
  end
  
  if #errors > 0 then
    return false, string.format("Archived %d/%d versions, errors occurred", archived_count, #to_archive)
  end
  
  return true, string.format("Successfully archived %d version(s)", archived_count)
end

return archiving
