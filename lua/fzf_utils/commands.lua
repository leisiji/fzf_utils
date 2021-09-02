local M = {}

local function get_fzf(submodule)
  return require('fzf_utils.'..submodule)
end
local fzf_commands = get_fzf('nvim_fzf_commands')

local function gtags_command(arg2, arg3)
  local gtags = get_fzf('gtags')

  if arg2 == "-d" then
    gtags.find_definition(arg3)
  elseif arg2 == "-r" then
    gtags.find_references(arg3)
  elseif arg2 == "--update" then
    gtags.generate_gtags()
  elseif arg2 == "--update-buffer" then
    gtags.gtags_update_buffer()
  end
end

local function rg_command(arg2, arg3)
  local rg = get_fzf('rg')

  if arg2 == "--all-buffers" then
    rg.search_all_buffers(arg3)
  else
    rg.search_path(arg2, arg3)
  end
end

local function ctags_command()
  local ctags = get_fzf('ctags')
  ctags.get_cur_buf_func()
end

local function vim_command(arg2)
  local u = get_fzf('vim_utils')
  if arg2 ~= nil and u[arg2] ~= nil then
    u[arg2]()
  end
end

-- arg4 to support 'tab drop'
local function lsp_command(arg2, arg3, arg4)
  local lsp = get_fzf('lsp')

  if arg4 ~= nil then
    arg3 = string.format('%s %s', arg3, arg4)
  end

  if arg2 ~= nil and lsp[arg2] ~= nil then
    lsp[arg2](arg3)
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

function M.load_command(arg1, ...)
  if arg1 == nil then
    return
  end

  local sub = string.sub(arg1, 3)
  for idx,val in pairs(command) do
    if sub == idx then
      val(...)
      break
    end
  end
end

return M
