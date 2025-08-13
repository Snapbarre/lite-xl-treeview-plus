-- mod-version:3 -- lite-xl 2.1
-- Author : Juliardi
-- Email : ardi93@gmail.com
-- Github : github.com/juliardi

local command = require "core.command"
local view = require "plugins.treeview"
local fsutils = require "plugins.treeview-plus.src.lua.fsutils"
local actions = require "plugins.treeview-plus.src.lua.actions"
local core = require "core"
local events = require "plugins.treeview-plus.src.lua.events"


print("[DEBUG] cplua init ")
local cplua = require "plugins.treeview-plus.cplua"
print("[DEBUG] cplua test: ", cplua~=nil)


local menu = view.contextmenu

command.add(
  function()
    return view.hovered_item ~= nil
      and fsutils.is_dir(view.hovered_item.abs_filename) ~= true
  end, {
    ["treeview:duplicate-file"] = actions.duplicate_file,
    ["treeview:copy-to"] = actions.copy_to
  })

command.add(
  function()
    return view.hovered_item ~= nil
      --and fsutils.is_dir(view.hovered_item.abs_filename) ~= true
  end, {
    ["treeview:copy"] = actions.copy,
    ["treeview:paste"] = actions.paste
  })

  command.add(nil, {
    ["treeview:test"] = actions.test
  })

command.add(
  function()
    return view.hovered_item ~= nil
      and view.hovered_item.abs_filename ~= fsutils.project_dir()
  end, {
    ["treeview:move-to"] = actions.move_to
  })

command.add(
  function()
    return view.hovered_item ~= nil
      and fsutils.is_dir(view.hovered_item.abs_filename) ~= true
  end, {
    ["treeview:clip_copy"] = function()

      core.add_thread(function()

        local path = view.hovered_item and view.hovered_item.abs_filename
        print("[DEBUG] copy to clipboard " .. path)
        if path then
            cplua.copy(path)
        else
          core.error("No hovered file to copy")
        end

      end)
    end
  })

command.add(
    function()
      return events.context_path ~= nil
    end, {
      ["treeview:clip_paste"] = function()
        -- local path = view.hovered_item and view.hovered_item.abs_filename
        print("[DEBUG] start paste thread")
        core.add_thread(function()
          local src_path = cplua.get_clipboard_fsdata()
          actions._paste(src_path,events.context_path)
        end)
      end
    })

menu:register(
  function()
    return view.hovered_item
      and (fsutils.is_dir(view.hovered_item.abs_filename) ~= true
      or view.hovered_item.abs_filename ~= fsutils.project_dir())
  end,
  {
    menu.DIVIDER,
  }
)

-- Menu 'Duplicate File..' only shown when an object is selected
-- and the object is a file
menu:register(
  function()
    return view.hovered_item
      and fsutils.is_dir(view.hovered_item.abs_filename) ~= true
  end,
  {
    { text = "Duplicate File..", command = "treeview:duplicate-file" },
    { text = "Copy To..", command = "treeview:copy-to" },
  }
)

-- Menu 'Move To..' only shown when an object is selected
-- and the object is not the project directory
menu:register(
  function()
    return view.hovered_item
      and view.hovered_item.abs_filename ~= fsutils.project_dir()
  end,
  {
    { text = "Move To..", command = "treeview:move-to" },
  }
)

menu:register(
  function()
    return view.hovered_item
      and (fsutils.is_dir(view.hovered_item.abs_filename) ~= true
      or view.hovered_item.abs_filename ~= fsutils.project_dir())
  end,
  {
    menu.DIVIDER,
  }
)

menu:register(
  function()
    return view.hovered_item
      and view.hovered_item.abs_filename ~= fsutils.project_dir()
  end,
  {
    { text = "Copy..", command = "treeview:copy" },
    -- { text = "Paste..", command = "treeview:paste" },
  }
)

menu:register(
  function()
    -- print("[MENU DEBUG] source_path : ",actions.treeview_clipboard.source_path)
    return actions.treeview_clipboard.source_path ~= nil
  end,
  {
    -- { text = "Copy..", command = "treeview:copy" },
    { text = "Paste..", command = "treeview:paste" },
  }
)

menu:register(
  function()
    return view.hovered_item
      and (fsutils.is_dir(view.hovered_item.abs_filename) ~= true
      or view.hovered_item.abs_filename ~= fsutils.project_dir())
  end,
  {
    menu.DIVIDER,
  }
)

menu:register(
  function()
    return view.hovered_item
      and view.hovered_item.abs_filename ~= fsutils.project_dir()
  end,
  {
    { text = "Copy to clip..", command = "treeview:clip_copy" },
  }
)

-- menu:register(
--   function()
--     return view.hovered_item
--       and view.hovered_item.abs_filename ~= fsutils.project_dir()
--   end,
--   {
--     { text = "Copy to clip..", command = "treeview:clip_copy" },
--   }
-- )

menu:register(
  function()
    return events.context_path ~= nil
  end,
  {
    { text = "Paste from clip..", command = "treeview:clip_paste" },
  }
)

-- menu:register(
--   function()
--     return view.hovered_item
--       and view.hovered_item.abs_filename ~= fsutils.project_dir()
--   end,
--   {
--     { text = "Test 2", command = "treeview:paste" },
--   }
-- )

menu:register(
  function()
    return true
  end,
  {
    { text = "Test..", command = "treeview:test" },
  }
)

-- local core = require "core"
-- print("[DEBUG] core test: ", core~=nil)
-- print("[DEBUG] core onquit exists: ", core.on_quit_project~=nil)

-- core.events:on("core.quit", function()
--   -- clean-up code here, e.g. stop your clipboard thread
--   print("Lite XL is quitting!")
--   -- call your stop_thread() or other cleanup here
-- end)

local on_quit_project = core.on_quit_project
function core.on_quit_project()
  print("[DEBUG] exiting")
  cplua.on_quit()
  on_quit_project()
end




return view
