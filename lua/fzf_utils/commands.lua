local M = {}

local function get_fzf(submodule)
  return require("fzf_utils." .. submodule)
end
local fzf_commands = get_fzf("nvim_fzf_commands")

local function gtags_command(args)
  local gtags = get_fzf("gtags")

  if args[2] == "-d" then
    gtags.find_definition(args[3])
  elseif args[2] == "-r" then
    gtags.find_references(args[3])
  elseif args[2] == "--update" then
    gtags.generate_gtags()
  elseif args[2] == "--update-buffer" then
    gtags.gtags_update_buffer()
  elseif args[2] == "-s" then
    gtags.find_symbol()
  end
end

local function rg_command(args)
  local rg = get_fzf("rg")

  if args[2] == "--all-buffers" then
    rg.search_all_buffers(args[3])
  else
    local path = args[3]
    if path ~= nil then
      path = vim.fn.shellescape(path)
    end
    rg.search_path(args[2], path)
  end
end

local function live_grep(args)
  local rg = get_fzf("rg")
    local path = args[2]
    if path ~= nil then
      path = vim.fn.shellescape(path)
    end
    rg.live_grep(path)
end

local function ctags_command()
  local ctags = get_fzf("ctags")
  ctags.get_cur_buf_func()
end

local function vim_command(args)
  local u = get_fzf("vim_utils")
  if args[2] ~= nil and u[args[2]] ~= nil then
    u[args[2]]()
  end
end

-- args[4] to support 'tab drop'
local function lsp_command(args)
  local lsp = get_fzf("lsp")

  if args[4] ~= nil then
    args[3] = string.format("%s %s", args[3], args[4])
  end

  if args[2] ~= nil and lsp[args[2]] ~= nil then
    lsp[args[2]](args[3])
  end
end

local command = {
  files = fzf_commands.find_files,
  lines = fzf_commands.grep_lines,
  rg = rg_command,
  ctags = ctags_command,
  buffers = fzf_commands.buffers,
  man = fzf_commands.Man,
  vim = vim_command,
  gtags = gtags_command,
  lsp = lsp_command,
  mru = function()
    require("fzf_utils.mru").fzf_mru()
  end,
  commit = fzf_commands.commit,
  live_grep = live_grep,
  zoxide = fzf_commands.zoxide,
}

function M.load(args)
  if args == nil then
    return
  end

  local sub = string.sub(args[1], 3)
  for idx, val in pairs(command) do
    if sub == idx then
      val(args)
      break
    end
  end
end

local function split(str, sep)
  local fields = {}

  local pattern = string.format("([^%s]+)", sep)
  local _ = string.gsub(str, pattern, function(c)
    fields[#fields + 1] = c
  end)

  return fields
end

local function path_complete(path, cursor)
  local list = {}

  if (path ~= nil and cursor == "/") or (path == nil and cursor == " ") or path == ".." then
    local dir = path or "."
    for name, type in vim.fs.dir(dir) do
      if type == "directory" and string.sub(name, 1, 1) ~= "." then
        list[#list + 1] = (path or "") .. name .. "/"
      end
    end
  elseif path ~= nil then
    local last = 1
    local cur = string.find(path, "/")
    while cur ~= nil and cur < string.len(path) do
      last = cur
      cur = cur + 1
      cur = string.find(path, "/", cur)
    end
    local dir
    if last == 1 then
      dir = "."
    else
      dir = string.sub(path, 1, last)
    end
    local match = string.sub(path, last)
    for name, type in vim.fs.dir(dir) do
      if type == "directory" and string.sub(name, 1, 1) ~= "." then
        if string.find(name, match) then
          list[#list + 1] = dir .. name .. "/"
        end
      end
    end
  end

  return list
end

local function gen_cmds()
  local list = {}
  for key, _ in pairs(command) do
    list[#list + 1] = "--" .. key
  end
  return list
end

function M.complete(_, line, pos)
  local args = split(line, " ")
  local num = #args

  if num == 1 then
    return gen_cmds()
  elseif num == 2 and string.sub(line, pos, pos) ~= " " then
    local sub = string.find(args[2], "--")
    if sub ~= nil then
      local list = {}
      local sub_str = string.sub(args[2], 3)
      for key, _ in pairs(command) do
        if string.find(key, sub_str) ~= nil then
          list[#list + 1] = "--" .. key
        end
      end
      if #list == 0 then
        return gen_cmds()
      end
      return list
    end
  elseif num == 3 or num == 4 then
    if num == 3 then
      if args[2] == "--gtags"  then
        return { "-d", "-r", "-s" }
      elseif args[3] == "--lsp" then
        return { "jump_def", "ref", "workspace_symbol", "document_symbol" }
      end
    end

    local cursor = string.sub(line, pos, pos)
    if args[2] == "--rg" then
      return path_complete(args[4], cursor)
    elseif args[2] == "--live_grep" then
      return path_complete(args[3], cursor)
    end
  end

  return nil
end

return M
