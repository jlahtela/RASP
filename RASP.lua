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

-- Initialize configuration
config.init()

-- Main loop
local function main()
  -- Update GUI
  local should_continue = gui.update()
  
  -- Handle GUI events
  if gui.should_create_version then
    gui.should_create_version = false
    gui.set_status("Creating new version...")
    
    local success, result = versioning.create_new_version()
    if success then
      gui.set_status("Version created: " .. result)
      gui.update_project_info()
    else
      gui.set_status("Error: " .. result)
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
