--[[
  RASP Configuration Module
  
  Handles persistent settings using Reaper's ExtState system.
  Settings persist across Reaper sessions.
]]--

local config = {}

-- ExtState section name
local SECTION = "RASP"

-- Default configuration values
local defaults = {
  -- Version format: prefix before number
  version_prefix = "_v",
  -- Number of digits in version (e.g., 3 = 001, 002, etc.)
  version_digits = 3,
  -- Starting version number for new projects
  start_version = 1,
  -- Archiving settings
  archive_destination = "",
  versions_to_keep = 3,
  -- Window state defaults
  window_dock = 0,
  window_x = 100,
  window_y = 100,
  window_width = 350,
  window_height = 400,
}

-- Current configuration (loaded from ExtState or defaults)
config.values = {}

-- Initialize configuration
function config.init()
  for key, default_value in pairs(defaults) do
    local stored = reaper.GetExtState(SECTION, key)
    if stored ~= "" then
      -- Convert to appropriate type
      if type(default_value) == "number" then
        config.values[key] = tonumber(stored) or default_value
      else
        config.values[key] = stored
      end
    else
      config.values[key] = default_value
    end
  end
end

-- Save a configuration value
function config.set(key, value)
  config.values[key] = value
  reaper.SetExtState(SECTION, key, tostring(value), true)
end

-- Get a configuration value
function config.get(key)
  return config.values[key] or defaults[key]
end

-- Save current window state
function config.save_window_state()
  local dock, x, y, w, h = gfx.dock(-1, 0, 0, 0, 0)
  config.set("window_dock", dock)
  config.set("window_x", x)
  config.set("window_y", y)
  config.set("window_width", w)
  config.set("window_height", h)
end

-- Load window state
function config.load_window_state()
  return 
    config.get("window_dock"),
    config.get("window_x"),
    config.get("window_y"),
    config.get("window_width"),
    config.get("window_height")
end

-- Get version format string (e.g., "%03d" for 3 digits)
function config.get_version_format()
  return "%0" .. config.get("version_digits") .. "d"
end

-- Format a version number according to settings
function config.format_version(num)
  local prefix = config.get("version_prefix")
  local format = config.get_version_format()
  return prefix .. string.format(format, num)
end

-- Parse version number from string, returns number or nil
function config.parse_version(str)
  local prefix = config.get("version_prefix")
  -- Escape special pattern characters in prefix
  local escaped_prefix = prefix:gsub("([%.%-%+%*%?%[%]%^%$%(%)%%])", "%%%1")
  local pattern = escaped_prefix .. "(%d+)$"
  local version_str = str:match(pattern)
  if version_str then
    return tonumber(version_str)
  end
  return nil
end

return config
