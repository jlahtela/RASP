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
-- Only matches exact project name or project name with version suffix
function archiving.find_all_versions(parent_dir, base_name)
  if not parent_dir then return {} end
  
  local versions = {}
  local prefix = config.get("version_prefix")
  
  local i = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(parent_dir, i)
    if not subdir then break end
    
    -- Check if this directory matches our naming pattern EXACTLY
    -- Valid: "ProjectName" (version 0) or "ProjectName_v001" (version 1)
    -- Invalid: "ProjectName_remix_v001" or "ProjectNameExtra"
    
    if subdir == base_name then
      -- Exact match without version suffix = version 0
      table.insert(versions, {
        name = subdir,
        version = 0,
        path = file_ops.join_path(parent_dir, subdir)
      })
    elseif subdir:sub(1, #base_name) == base_name then
      -- Check if the rest is exactly a version suffix (e.g., "_v001")
      local remainder = subdir:sub(#base_name + 1)
      local version = config.parse_version(base_name .. remainder)
      
      -- Only include if version suffix starts immediately after base_name
      -- This ensures "ProjectName_v001" matches but "ProjectName_extra_v001" doesn't
      if version then
        local escaped_prefix = prefix:gsub("([%.%-%+%*%?%[%]%^%$%(%)%%])", "%%%1")
        local expected_suffix = prefix .. string.format(config.get_version_format(), version)
        
        if remainder == expected_suffix then
          table.insert(versions, {
            name = subdir,
            version = version,
            path = file_ops.join_path(parent_dir, subdir)
          })
        end
      end
    end
    
    i = i + 1
  end
  
  -- Sort by version number
  table.sort(versions, function(a, b) return a.version < b.version end)
  
  return versions
end

-- Get versions that should be archived based on current version and keep count
-- Never includes the current active version
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
    -- Current version is NEVER archived, even if it would be below cutoff
    if ver.version < cutoff_version and ver.version ~= current_version then
      table.insert(to_archive, ver)
    end
  end
  
  return to_archive, nil
end

-- Show confirmation dialog for archiving
-- Returns: "yes" (proceed), "no" (cancel), or nil if no versions to archive
function archiving.show_archive_confirmation(to_archive, archive_dest)
  if #to_archive == 0 then
    return nil
  end
  
  -- Build list of versions
  local version_list = ""
  for _, ver in ipairs(to_archive) do
    local version_display = ver.version == 0 and "(v0 - original)" or ""
    version_list = version_list .. "  • " .. ver.name .. " " .. version_display .. "\n"
  end
  
  local message = string.format(
    "Archive and REMOVE the following versions from source?\n\n%s\nDestination: %s\n\nThis action cannot be undone.",
    version_list,
    archive_dest
  )
  
  -- 1 = OK/Cancel, 4 = Yes/No
  local result = reaper.ShowMessageBox(message, "Archive Confirmation", 4)
  
  -- 6 = Yes, 7 = No
  if result == 6 then
    return "yes"
  else
    return "no"
  end
end

-- Show dialog when archive destination already has a version
-- Returns: "skip", "replace", or "cancel"
function archiving.show_existing_version_dialog(version_name)
  local message = string.format(
    "\"%s\" already exists in archive.\n\n• Yes = Skip this version\n• No = Replace existing archive\n• Cancel = Abort entire operation",
    version_name
  )
  
  -- 3 = Yes/No/Cancel
  local result = reaper.ShowMessageBox(message, "Version Already Exists", 3)
  
  -- 6 = Yes (Skip), 7 = No (Replace), 2 = Cancel
  if result == 6 then
    return "skip"
  elseif result == 7 then
    return "replace"
  else
    return "cancel"
  end
end

-- Archive versions by moving them to archive destination
-- Shows confirmation dialog and handles existing archives
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
  
  -- Show confirmation dialog
  local confirm = archiving.show_archive_confirmation(to_archive, archive_dest)
  if confirm ~= "yes" then
    return true, "Archiving cancelled by user"
  end
  
  -- Archive each version (copy then delete source)
  local archived_count = 0
  local skipped_count = 0
  local errors = {}
  
  for _, ver in ipairs(to_archive) do
    local dest_path = file_ops.join_path(archive_dest, ver.name)
    
    -- Check if destination already exists
    if file_ops.dir_exists(dest_path) then
      local action = archiving.show_existing_version_dialog(ver.name)
      
      if action == "cancel" then
        return false, string.format("Archiving aborted. Archived %d version(s) before cancellation.", archived_count)
      elseif action == "skip" then
        skipped_count = skipped_count + 1
        goto continue
      elseif action == "replace" then
        -- Delete existing archive
        local del_success, del_err = file_ops.delete_directory(dest_path)
        if not del_success then
          table.insert(errors, "Could not remove existing archive: " .. ver.name .. " - " .. (del_err or "unknown error"))
          goto continue
        end
      end
    end
    
    -- Copy directory to archive location
    local success, copy_err = file_ops.copy_directory(ver.path, dest_path)
    
    if success then
      -- Verify copy succeeded before deleting source
      if file_ops.dir_exists(dest_path) then
        -- Delete source directory
        local del_success, del_err = file_ops.delete_directory(ver.path)
        if del_success then
          archived_count = archived_count + 1
        else
          table.insert(errors, "Archived but could not delete source: " .. ver.name .. " - " .. (del_err or "unknown error"))
        end
      else
        table.insert(errors, "Copy verification failed: " .. ver.name)
      end
    else
      table.insert(errors, "Failed to archive: " .. ver.name .. " - " .. (copy_err or "unknown error"))
    end
    
    ::continue::
  end
  
  if #errors > 0 then
    local error_summary = table.concat(errors, "\n")
    return false, string.format("Archived %d/%d versions, skipped %d, errors:\n%s", 
      archived_count, #to_archive, skipped_count, error_summary)
  end
  
  local msg = string.format("Successfully archived %d version(s)", archived_count)
  if skipped_count > 0 then
    msg = msg .. string.format(", skipped %d", skipped_count)
  end
  
  return true, msg
end

return archiving
