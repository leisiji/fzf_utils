local M = {}

local function get_fzf(submodule)
  return require('fzf_utils.'..submodule)
end
local fzf_commands = get_fzf('nvim_fzf_commands')

local function gtags_command(args)
  local gtags = get_fzf('gtags')

  if args[2] == "-d" then
    gtags.find_definition(args[3])
  elseif args[2] == "-r" then
    gtags.find_references(args[3])
  elseif args[2] == "--update" then
    gtags.generate_gtags()
  elseif args[2] == "--update-buffer" then
    gtags.gtags_update_buffer()
  end
end

local function rg_command(args)
  local rg = get_fzf('rg')

  if args[2] == "--all-buffers" then
    rg.search_all_buffers(args[3])
  else
    rg.search_path(args[2], args[3])
  end
end

local function ctags_command()
  local ctags = get_fzf('ctags')
  ctags.get_cur_buf_func()
end

local function vim_command(args)
  local u = get_fzf('vim_utils')
  if args[2] ~= nil and u[args[2]] ~= nil then
    u[args[2]]()
  end
end

-- args[4] to support 'tab drop'
local function lsp_command(args)
  local lsp = get_fzf('lsp')

  if args[4] ~= nil then
    args[3] = string.format('%s %s', args[3], args[4])
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
  mru = require('fzf_utils.mru').fzf_mru,
  commit = fzf_commands.commit,
}

function M.load(args)
  if args == nil then
    return
  end

  local sub = string.sub(args[1], 3)
  for idx,val in pairs(command) do
    if sub == idx then
      val(args)
      break
    end
  end
end

function M.complete()
  local list = {}
  for key, _ in pairs(command) do
    list[#list+1] = "--" .. key
  end
  return list
end

return M
