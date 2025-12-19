--[[
  RASP GUI Module
  
  Provides a dockable user interface for RASP functionality.
  Built with gfx functions for cross-platform compatibility.
  
  Designed to be extensible for future features (archiving, etc.)
]]--

local gui = {}

-- Window settings
local WINDOW_TITLE = "RASP - Reaper Archiving System"
local MIN_WIDTH = 300
local MIN_HEIGHT = 200

-- Colors (RGB 0-1)
local colors = {
  background = {0.18, 0.18, 0.20},
  panel = {0.22, 0.22, 0.25},
  text = {0.9, 0.9, 0.9},
  text_dim = {0.6, 0.6, 0.6},
  accent = {0.3, 0.6, 0.9},
  button = {0.3, 0.5, 0.7},
  button_hover = {0.4, 0.6, 0.8},
  button_text = {1, 1, 1},
  success = {0.3, 0.7, 0.4},
  error = {0.8, 0.3, 0.3},
  border = {0.3, 0.3, 0.35},
}

-- UI State
local state = {
  -- Project info
  project_name = "",
  current_version = "",
  project_path = "",
  
  -- Status message
  status_text = "",
  status_color = colors.text_dim,
  status_time = 0,
  
  -- Button states
  version_button_hover = false,
  
  -- Fonts
  font_normal = 1,
  font_large = 2,
  font_small = 3,
}

-- Public flags
gui.should_create_version = false

-- Set status message
function gui.set_status(text, is_error)
  state.status_text = text
  state.status_color = is_error and colors.error or colors.success
  state.status_time = reaper.time_precise()
end

-- Update project information display
function gui.update_project_info()
  local versioning = require("versioning")
  state.project_name = versioning.get_project_display()
  state.current_version = versioning.get_version_display()
  
  local info = versioning.get_project_info()
  if info then
    state.project_path = info.directory or ""
  else
    state.project_path = ""
  end
end

-- Helper: Set drawing color
local function set_color(color, alpha)
  gfx.set(color[1], color[2], color[3], alpha or 1)
end

-- Helper: Draw filled rectangle
local function draw_rect(x, y, w, h, color, alpha)
  set_color(color, alpha)
  gfx.rect(x, y, w, h, true)
end

-- Helper: Draw rectangle border
local function draw_border(x, y, w, h, color, alpha)
  set_color(color, alpha)
  gfx.rect(x, y, w, h, false)
end

-- Helper: Draw text centered in area
local function draw_text_centered(text, x, y, w, h, color)
  set_color(color)
  gfx.setfont(state.font_normal)
  local text_w, text_h = gfx.measurestr(text)
  gfx.x = x + (w - text_w) / 2
  gfx.y = y + (h - text_h) / 2
  gfx.drawstr(text)
end

-- Helper: Draw text left-aligned
local function draw_text(text, x, y, color, font)
  set_color(color)
  gfx.setfont(font or state.font_normal)
  gfx.x = x
  gfx.y = y
  gfx.drawstr(text)
end

-- Helper: Check if mouse is in area
local function mouse_in(x, y, w, h)
  return gfx.mouse_x >= x and gfx.mouse_x <= x + w and
         gfx.mouse_y >= y and gfx.mouse_y <= y + h
end

-- Helper: Draw button, returns true if clicked
local function draw_button(text, x, y, w, h, enabled)
  enabled = enabled ~= false
  local hover = enabled and mouse_in(x, y, w, h)
  local clicked = hover and (gfx.mouse_cap & 1 == 1)
  
  -- Draw button background
  local bg_color = not enabled and colors.panel or (hover and colors.button_hover or colors.button)
  draw_rect(x, y, w, h, bg_color)
  draw_border(x, y, w, h, colors.border)
  
  -- Draw button text
  local text_color = enabled and colors.button_text or colors.text_dim
  draw_text_centered(text, x, y, w, h, text_color)
  
  -- Return click state (only on mouse release)
  if hover and gfx.mouse_cap == 0 and gui._last_mouse_cap == 1 then
    return true
  end
  
  return false
end

-- Draw header section
local function draw_header(x, y, w)
  local h = 60
  
  -- Title
  gfx.setfont(state.font_large)
  set_color(colors.accent)
  local title = "RASP"
  local title_w = gfx.measurestr(title)
  gfx.x = x + 15
  gfx.y = y + 12
  gfx.drawstr(title)
  
  -- Subtitle
  gfx.setfont(state.font_small)
  set_color(colors.text_dim)
  gfx.x = x + 15
  gfx.y = y + 38
  gfx.drawstr("Reaper Archiving System Project")
  
  -- Separator line
  set_color(colors.border)
  gfx.line(x + 10, y + h - 1, x + w - 10, y + h - 1)
  
  return h
end

-- Draw project info section
local function draw_project_info(x, y, w)
  local h = 80
  local padding = 15
  
  -- Project name
  draw_text("Project:", x + padding, y + 10, colors.text_dim, state.font_small)
  draw_text(state.project_name, x + padding, y + 28, colors.text, state.font_normal)
  
  -- Current version
  draw_text("Version:", x + padding + 180, y + 10, colors.text_dim, state.font_small)
  draw_text(state.current_version, x + padding + 180, y + 28, colors.accent, state.font_normal)
  
  -- Path (truncated)
  draw_text("Location:", x + padding, y + 52, colors.text_dim, state.font_small)
  local path_display = state.project_path
  if #path_display > 40 then
    path_display = "..." .. path_display:sub(-37)
  end
  draw_text(path_display, x + padding, y + 68, colors.text_dim, state.font_small)
  
  return h
end

-- Draw versioning section
local function draw_versioning_section(x, y, w)
  local h = 70
  local padding = 15
  local btn_w = w - padding * 2
  local btn_h = 36
  
  -- Section title
  draw_text("Versioning", x + padding, y + 5, colors.text_dim, state.font_small)
  
  -- Create new version button
  local has_project = state.project_name ~= "" and state.project_name ~= "No project loaded"
  if draw_button("Create New Version", x + padding, y + 25, btn_w, btn_h, has_project) then
    gui.should_create_version = true
  end
  
  return h
end

-- Draw status bar
local function draw_status_bar(x, y, w)
  local h = 25
  
  -- Background
  draw_rect(x, y, w, h, colors.panel)
  draw_border(x, y, w, h, colors.border)
  
  -- Status text (fade after 5 seconds)
  local elapsed = reaper.time_precise() - state.status_time
  local alpha = math.max(0, math.min(1, 1 - (elapsed - 3) / 2))
  
  if alpha > 0 and state.status_text ~= "" then
    gfx.setfont(state.font_small)
    set_color(state.status_color, alpha)
    gfx.x = x + 10
    gfx.y = y + (h - 14) / 2
    gfx.drawstr(state.status_text)
  end
  
  return h
end

-- Draw future features placeholder
local function draw_future_section(x, y, w)
  local h = 50
  local padding = 15
  
  -- Section divider
  set_color(colors.border)
  gfx.line(x + 10, y, x + w - 10, y)
  
  -- Coming soon text
  draw_text("Archiving features coming in v0.2+", x + padding, y + 15, colors.text_dim, state.font_small)
  
  return h
end

-- Initialize GUI
function gui.init(dock, x, y, w, h)
  -- Set defaults if not provided
  dock = dock or 0
  x = x or 100
  y = y or 100
  w = w or 350
  h = h or 250
  
  -- Initialize graphics
  gfx.init(WINDOW_TITLE, w, h, dock, x, y)
  
  -- Set up fonts
  gfx.setfont(state.font_normal, "Arial", 16)
  gfx.setfont(state.font_large, "Arial", 24, string.byte('b'))
  gfx.setfont(state.font_small, "Arial", 12)
  
  -- Set background color
  gfx.clear = colors.background[1] * 255 + 
              colors.background[2] * 255 * 256 + 
              colors.background[3] * 255 * 65536
  
  -- Initialize state
  gui._last_mouse_cap = 0
end

-- Main update function - call every frame
function gui.update()
  -- Check if window is still open
  local char = gfx.getchar()
  if char < 0 then
    return false
  end
  
  -- Handle escape key
  if char == 27 then
    return false
  end
  
  -- Get window dimensions
  local w, h = gfx.w, gfx.h
  
  -- Enforce minimum size
  if w < MIN_WIDTH or h < MIN_HEIGHT then
    -- Can't resize programmatically, just adapt
    w = math.max(w, MIN_WIDTH)
    h = math.max(h, MIN_HEIGHT)
  end
  
  -- Clear background
  draw_rect(0, 0, w, h, colors.background)
  
  -- Draw sections
  local y_offset = 0
  
  y_offset = y_offset + draw_header(0, y_offset, w)
  y_offset = y_offset + draw_project_info(0, y_offset, w)
  y_offset = y_offset + draw_versioning_section(0, y_offset, w)
  y_offset = y_offset + draw_future_section(0, y_offset, w)
  
  -- Status bar at bottom
  draw_status_bar(0, h - 25, w)
  
  -- Store mouse state for click detection
  gui._last_mouse_cap = gfx.mouse_cap
  
  -- Update display
  gfx.update()
  
  return true
end

return gui
