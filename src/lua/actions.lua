
local core = require "core"
local common = require "core.common"
local style = require "core.style"
local view = require "plugins.treeview"
local fsutils = require "plugins.treeview-plus.src.lua.fsutils"
local events = require "plugins.treeview-plus.src.lua.events"
local os = require "os"
local command = require "core.command"
local DocView = require "core.docview"


local treeview_clipboard = {
  mode = nil, -- "copy" or "cut"
  source_path = nil, -- absolute source file path
}

local actions = {
  treeview_clipboard = treeview_clipboard
}

local context_path = nil

function treeview_clipboard:reset()
  self.mode = nil
  self.source_path = nil
end

function actions.duplicate_file()
  local old_filename = view.hovered_item.abs_filename
  core.command_view:enter("Filename", {
    text = view.hovered_item.filename,
    suggest = common.path_suggest,
    submit = function(filename)
      local new_filename = fsutils.project_dir() .. PATHSEP .. filename

      if (fsutils.is_object_exist(new_filename)) then
        core.error("[treeview-plus] Unable to copy file : %s to %s. Duplicate name exists.", old_filename, new_filename)
        return
      end

      fsutils.copy_file(old_filename, new_filename)

      core.root_view:open_doc(core.open_doc(new_filename))
      core.log("[treeview-plus] %s duplicated to %s", old_filename, new_filename)
    end
  })
end

function actions.copy_to()
  local source_filename = view.hovered_item.abs_filename
  core.command_view:enter("Copy to", {
    text = view.hovered_item.abs_filename,
    suggest = common.path_suggest,
    submit = function(dest_filename)
      if (fsutils.is_object_exist(dest_filename)) then
        -- Ask before rewriting
          local opt = {
            { font = style.font, text = "Yes", default_yes = true },
            { font = style.font, text = "No" , default_no = true }
          }
          core.nag_view:show(
            string.format("Rewrite existing file?"),
            string.format(
              "File %s already exist. Rewrite file?",
              dest_filename
            ),
            opt,
            function(item)
              if item.text == "Yes" then
                os.remove(dest_filename)
                fsutils.copy_file(source_filename, dest_filename)
              else
                return
              end
            end
          )
      else
        fsutils.copy_file(source_filename, dest_filename)
      end

      core.root_view:open_doc(core.open_doc(dest_filename))
      core.log("[treeview-plus] %s copied to %s", source_filename, dest_filename)
    end
  })
end

function actions.test()
  print("[TEST_FUN] doing_test")
  core.root_view:open_doc(core.open_doc("logs.txt"))
  -- local pasted_Doc = core.open_doc("logs.txt")
  -- local pasted_View = DocView(pasted_Doc)
  -- core.root_view:get_active_node():add_view(pasted_View)
  -- core.command_view:enter("Test Open ", {
  --   -- text = view.hovered_item.abs_filename,
  --   -- suggest = common.path_suggest,
  --   submit = function(dest_filename)
  --     core.root_view:open_doc(core.open_doc(dest_filename))
  --     core.log("[treeview-plus] opening %s", dest_filename)
  --   end
  -- })
end

function actions.copy()
  local hovered = view.hovered_item

  if hovered and hovered.abs_filename then
    treeview_clipboard:reset()
    treeview_clipboard.mode = "copy"
    treeview_clipboard.source_path = hovered.abs_filename
    core.log("[treeview-plus] Copied file: %s", treeview_clipboard.source_path)
  else
    core.error("[treeview-plus] No file selected to copy.")
  end
end


function actions._paste_file(src,dest_dir)
  local base = fsutils.basename(src)
  local dest = dest_dir .. PATHSEP .. base

  -- If duplicate name, auto-rename
  local counter = 1
  while fsutils.is_object_exist(dest) do
    local name, ext = base:match("(.+)(%..+)$")
    name = name or base
    ext = ext or ""
    dest = dest_dir .. PATHSEP .. string.format("%s (%d)%s", name, counter, ext)
    counter = counter + 1
  end

  fsutils.copy_file(src, dest)
  core.log("[treeview-plus] Pasted file: %s → %s", src, dest)
  
end

function actions._paste_dir(src,dest_dir)

  local base = fsutils.basename(src)
  local dest = dest_dir .. PATHSEP .. base

  local counter = 1
  while fsutils.is_object_exist(dest) do
    local name, ext = base:match("(.+)(%..+)$")
    name = name or base
    ext = ext or ""
    dest = dest_dir .. PATHSEP .. string.format("%s (%d)%s", name, counter, ext)
    counter = counter + 1
  end
  
  
  fsutils.copy_dir(src, dest)
  core.log("[treeview-plus] Pasted dir: %s → %s", src, dest)
  
end

function actions._paste(src,dest_dir)
  --check if destination directory exists
  if not dest_dir or not fsutils.is_dir(dest_dir) then
      core.error("[treeview-plus] paste action exception: destination directory does not exists :",dest_dir)
    return
  end

  if not fsutils.is_dir(src) then
    actions._paste_file(src,dest_dir)
  else
    actions._paste_dir(src,dest_dir)
  end
end

function actions.paste()
  if not treeview_clipboard.source_path then
    core.error("[treeview-plus] Clipboard is empty.")
  end
  
  --  local dest_dir = view.hovered_item and view.hovered_item.abs_filename
  local dest_dir = events.context_path
    if not dest_dir or not fsutils.is_dir(dest_dir) then
      core.error("[treeview-plus] Please hover a directory or file to paste into.")
    return
  end

  local src = treeview_clipboard.source_path
  actions._paste(src,dest_dir)

  -- Optionally clear clipboard if it's a "cut"
  --[[if file_clipboard.mode == "cut" then
    os.remove(src)
    file_clipboard.path = nil
    file_clipboard.mode = nil
  end]]--
end

-- function actions.paste()
--   if not treeview_clipboard.source_path then
--     core.error("[treeview-plus] Clipboard is empty.")
--   end
  
--   --  local dest_dir = view.hovered_item and view.hovered_item.abs_filename
--   local dest_dir = events.context_path
--   if not dest_dir or not fsutils.is_dir(dest_dir) then
--     core.error("[treeview-plus] Please hover a directory or file to paste into.")
--     return
--   end

--   local src = treeview_clipboard.source_path

--   if not fsutils.is_dir(src) then

--     local base = fsutils.basename(src)
--     local dest = dest_dir .. PATHSEP .. base

--     -- If duplicate name, auto-rename
--     local counter = 1
--     while fsutils.is_object_exist(dest) do
--       local name, ext = base:match("(.+)(%..+)$")
--       name = name or base
--       ext = ext or ""
--       dest = dest_dir .. PATHSEP .. string.format("%s (%d)%s", name, counter, ext)
--       counter = counter + 1
--     end

--     fsutils.copy_file(src, dest)
--     -- local pasted_Doc = core.open_doc(dest)
--     -- local pasted_View = = DocView(pasted_Doc)
--     -- core.root_view:get_active_node():add_view(pasted_View)

--     core.log("[treeview-plus] Pasted file: %s → %s", src, dest)

--     core.root_view:open_doc(core.open_doc(dest))

--   else

--     local base = fsutils.basename(src)
--     local dest = dest_dir .. PATHSEP .. base

--     local counter = 1
--     while fsutils.is_object_exist(dest) do
--       local name, ext = base:match("(.+)(%..+)$")
--       name = name or base
--       ext = ext or ""
--       dest = dest_dir .. PATHSEP .. string.format("%s (%d)%s", name, counter, ext)
--       counter = counter + 1
--     end
    
    
--     fsutils.copy_dir(src, dest)
--     core.log("[treeview-plus] Pasted dir: %s → %s", src, dest)

--   end

  -- Optionally clear clipboard if it's a "cut"
  --[[if file_clipboard.mode == "cut" then
    os.remove(src)
    file_clipboard.path = nil
    file_clipboard.mode = nil
  end]]--
-- end


function actions.move_to()
  local old_abs_filename = view.hovered_item.abs_filename
  core.command_view:enter("Move to", {
    text = view.hovered_item.abs_filename,
    suggest = common.path_suggest,
    submit = function(new_abs_filename)
      if (fsutils.is_object_exist(new_abs_filename)) then
        -- Ask before rewriting
        local opt = {
          { font = style.font, text = "Yes", default_yes = true },
          { font = style.font, text = "No" , default_no = true }
        }
        core.nag_view:show(
          string.format("Rewrite existing file?"),
          string.format(
            "File %s already exist. Rewrite file?",
            new_abs_filename
          ),
          opt,
          function(item)
            if item.text == "Yes" then
              os.remove(new_abs_filename)
              fsutils.move_object(old_abs_filename, new_abs_filename)

              core.log("[treeview-plus] %s moved to %s", old_abs_filename, new_abs_filename)
            end
          end
        )
      else
        fsutils.move_object(old_abs_filename, new_abs_filename)
        core.log("[treeview-plus] %s moved to %s", old_abs_filename, new_abs_filename)
      end
    end
  })
end

return actions
