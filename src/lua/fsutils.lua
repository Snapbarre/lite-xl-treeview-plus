
local core = require "core"
local lfs = require("lfs")

local fsutils = {}
local PATHSEP = package.config:sub(1,1)

--- Checks whether a file or directory exists
-- @param string path Path of object to be checked
function fsutils.is_object_exist(path)
  local stat = system.get_file_info(path)
  if not stat or (stat.type ~= "file" and stat.type ~= "dir") then
    return false
  end
  return true
end

--- Checks whether an object is a directory
-- @param string path Path of object to be checked
  function fsutils.is_dir(path)
    if type(path) ~= "string" then
      core.error("path argument is not a string")
    end

    local file_info = system.get_file_info(path)
    if (file_info ~= nil) then
      return file_info.type == "dir"
    end

    return false
  end

--- Moves object (file or directory) to another path
-- @param string old_abs_filename Absolute old filename
-- @param string new_abs_filename Absolute new filename
function fsutils.move_object(old_abs_filename, new_abs_filename)
  local res, err = os.rename(old_abs_filename, new_abs_filename)
  if res then -- successfully renamed
    core.log("[treeview-plus] Moved \"%s\" to \"%s\"", old_abs_filename, new_abs_filename)
  else
    core.error("[treeview-plus] Error while moving \"%s\" to \"%s\": %s", old_abs_filename, new_abs_filename, err)
  end
end

--- Copy source file to destination path
-- @param string source_abs_filename Absolute source filename
-- @param string dest_abs_filename Absolute destination filename
function fsutils.copy_file(source_abs_filename, dest_abs_filename)
  local source_file = io.open(source_abs_filename, "rb")
  local dest_file = io.open(dest_abs_filename, "wb")

  if source_file ~= nil and dest_file ~= nil then

    local chunk_size = 2^13 -- 8KB
    while true do
      local chunk = source_file:read(chunk_size)
      if not chunk then break end
      dest_file:write(chunk)
    end

    source_file:close()
    dest_file:close()

  end
end

function fsutils.copy_dir(src, dst)
  -- Create destination dir if it doesn't exist
  print("dest :", dst)
  print("src : ",src)
  lfs.mkdir(dst)
  local entries = {}
  for entry in lfs.dir(src) do
    print("entry : ",entry)
    table.insert(entries, entry)
  end
  -- local entry_list = lfs.dir(src)
  for _, entry in ipairs(entries) do
    if entry ~= "." and entry ~= ".." then
      local src_path = src .. PATHSEP .. entry
      local dst_path = dst .. PATHSEP .. entry
      local mode = lfs.attributes(src_path, "mode")

      if mode == "file" then
        fsutils.copy_file(src_path, dst_path)
      elseif mode == "directory" then
        fsutils.copy_dir(src_path, dst_path)
      end
    end
  end
end

function fsutils.project_dir()
  return core.project_dir or core.root_project().path
end

function fsutils.dirname(path)
  return path:match("^(.*)[/\\]")
end

-- function fsutils.basename(path)
--   return path:match("^.+/(.+)$") or path
-- end

function fsutils.basename(path)
  if path:sub(-1) == "/" then
    path = path:sub(1, -2)
  end
  return path:match("^.+/(.+)$") or path
end

-- function fsutils.isdir(path)
--   return lfs.attributes(path, "mode") == "directory"
-- end

return fsutils
