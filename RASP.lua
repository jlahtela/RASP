-- @description RASP - Reaper Archiving System Project
-- @author RASP Team
-- @version 0.1.0
-- @changelog Initial release - versioning functionality
-- @provides
--   [main] RASP.lua
--   modules/*.lua

--[[
  RASP - Reaper Archiving System Project
  
  Version 0.1 - Auto-versioning with full project copy
  - Creates new versioned folder for each save
  - Copies all media files to new folder
  - Increments version number in folder and project name
  
  Future versions will add cloud archiving support.
]]--

-- Get script path for module loading
local info = debug.getinfo(1, "S")
local script_path = info.source:match("@?(.+)[/\\]")
if not script_path then
  script_path = reaper.GetResourcePath() .. "/Scripts/RASP"
end

-- Add modules path
package.path = script_path .. "/modules/?.lua;" .. package.path

-- Load modules
local config = require("config")
local gui = require("gui")
local versioning = require("versioning")
local file_ops = require("file_operations")
local archiving = require("archiving")

-- Initialize configuration
config.init()

-- Main loop
local function main()
  -- Update GUI
  local should_continue = gui.update()
  
  -- Handle GUI events
  if gui.should_create_version then
    gui.should_create_version = false
    
    local mode = gui.get_versioning_mode()
    if mode == "auto" then
      gui.set_status("Creating new version (auto)...")
    else
      gui.set_status("Opening Save As dialog...")
    end
    
    local success, result = versioning.create_new_version(mode)
    if success then
      if mode == "native" then
        gui.set_status("Save As dialog opened")
      else
        gui.set_status("Version created successfully")
      end
      gui.update_project_info()
    else
      gui.set_status("Error: " .. (result or "Unknown error"), true)
    end
  end
  
  -- Handle archive browsing
  if gui.should_browse_archive_dest then
    gui.should_browse_archive_dest = false
    
    -- Try to use JS extension for folder browser if available
    local has_js = reaper.JS_Dialog_BrowseForFolder and true or false
    local selected_path
    
    if has_js then
      local retval
      retval, selected_path = reaper.JS_Dialog_BrowseForFolder("Select Archive Destination", config.get("archive_destination"))
      if retval == 1 and selected_path and selected_path ~= "" then
        config.set("archive_destination", selected_path)
        gui.update_project_info()
        gui.set_status("Archive destination updated")
      end
    else
      -- Fallback to text input dialog
      local retval
      retval, selected_path = reaper.GetUserInputs("Archive Destination", 1, "Folder path (full path required):", config.get("archive_destination"))
      if retval and selected_path ~= "" then
        -- Basic validation: check if path looks reasonable
        if selected_path:match("[/\\]") or selected_path:len() > 2 then
          config.set("archive_destination", selected_path)
          gui.update_project_info()
          gui.set_status("Archive destination updated")
        else
          gui.set_status("Invalid path format. Use full folder path.", true)
        end
      end
    end
  end
  
  -- Handle archiving
  if gui.should_archive_now then
    gui.should_archive_now = false
    gui.set_status("Archiving old versions...")
    
    local archive_dest = config.get("archive_destination")
    local versions_to_keep = config.get("versions_to_keep")
    
    local success, result = archiving.archive_versions(archive_dest, versions_to_keep)
    if success then
      gui.set_status(result)
    else
      gui.set_status("Error: " .. result, true)
    end
  end
  
  -- Continue loop if window is open
  if should_continue then
    reaper.defer(main)
  else
    -- Save window state on exit
    config.save_window_state()
  end
end

-- Initialize GUI and start main loop
local function init()
  -- Load saved window state
  local dock, x, y, w, h = config.load_window_state()
  
  -- Initialize GUI window
  gui.init(dock, x, y, w, h)
  gui.update_project_info()
  
  -- Register cleanup on exit
  reaper.atexit(function()
    config.save_window_state()
  end)
  
  -- Start main loop
  main()
end

-- Run
init()
