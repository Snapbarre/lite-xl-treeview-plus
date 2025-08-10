local core = require "core"
local common = require "core.common"
local style = require "core.style"

local treeview = require "plugins.treeview"
local fsutils = require "plugins.treeview-plus.src.lua.fsutils" -- if you use helpers
local command = require "core.command"


local events = {
  context_path = nil
}

-- Save original function
local original_on_mouse_pressed = treeview.on_mouse_pressed

-- Override
function treeview:on_mouse_pressed(button, x, y, clicks)
  print("[DEBUG] mouse pressed")
  -- Call original behavior first
  local result = original_on_mouse_pressed(self, button, x, y, clicks)

  -- Check what item is currently hovered
  local item = self.hovered_item
  -- core.log("[PRESS EVENT] ", item)
  -- if item and item.abs_filename then
  --   if fsutils.is_dir(item.abs_filename) then
  --     events.context_path = item.abs_filename
  --   else
  --     events.context_path = fsutils.dirname(item.abs_filename)
  --   end
  --   print("[DEBUG] context_path set to :",events.context_path)
  --   -- Optional: log it for debugging
  --   core.log("Context path set to: %s", events.context_path)
  -- end

  return result
end


local old_root_press = core.root_view.on_mouse_pressed
function core.root_view:on_mouse_pressed(button, x, y, clicks)
  -- command.perform "debugger:break"
  -- print("[DEBUG] Global mouse press: button %d", button)
  -- Check what item is currently hovered
  local item = treeview.hovered_item
  -- core.log("[PRESS EVENT] ", item)
  if item and item.abs_filename then
    if fsutils.is_dir(item.abs_filename) then
      events.context_path = item.abs_filename
    else
      events.context_path = fsutils.dirname(item.abs_filename)
    end
  end
    -- print("[DEBUG] context_path set to :",events.context_path)
  -- core.log("Global mouse press: button %d", button)
  return old_root_press(self, button, x, y, clicks)
end



return events