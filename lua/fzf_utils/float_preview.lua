-- references: https://github.com/rmagatti/goto-preview
-- preview is single instance
local M = {}
local u = require('fzf_utils.utils')
local p = nil
local w = nil
local api = vim.api
local percent = 0.5
local initialized = false

-- parse preview percentage from fzf env
local function init_opts()
  if initialized then
    return
  end

  local fzf_opt = vim.env['FZF_DEFAULT_OPTS']
  if fzf_opt ~= nil then
    local parse_percent = string.match(fzf_opt, ".*:(%d+)%.*")
    if parse_percent ~= nil then
      percent = parse_percent / 100
    end
  end

  initialized = true
end

local function create_win(path)
  if path == p then
    return w
  else
    p = path
  end

  local b = vim.fn.bufadd(path)
  if w ~= nil and api.nvim_win_is_valid(w) then
    api.nvim_win_set_buf(w, b)
    return w
  end

  init_opts()

  local columns, lines = vim.o.columns, vim.o.lines
  local fzf_width = math.min(columns - 4, math.max(80, columns - 20))
  local width = math.floor(fzf_width * percent)
  local height = math.min(lines - 4, math.max(20, lines - 10)) - 1
  local opts = {
    relative = 'editor', border = 'rounded',
    width = width, height = height, zindex = 200,
    row = math.floor((lines - height)/2),
    col = math.floor((columns - fzf_width)/2 +  fzf_width * (1 - percent)),
  }

  w = api.nvim_open_win(b, false, opts)
  api.nvim_buf_set_option(b, 'bufhidden', 'wipe')

  vim.cmd([[
    augroup close_float_fzf
      au! * <buffer>
      au BufHidden <buffer> lua require('fzf_utils.float_preview').close_preview_win()
    augroup end
  ]])
  return w
end

local function open_floating_win(path, l)
  api.nvim_win_set_cursor(create_win(path), {l, 0})
end

function M.get_preview_action(path)
  local shell = require('fzf.actions').action(function(s, _, _)
    if s ~= nil then
      open_floating_win(path, u.get_leading_num(s[1]))
      return ""
    end
  end)
  return shell
end

function M.close_preview_win()
  if w ~= nil and api.nvim_win_is_valid(w) then
    api.nvim_win_close(w, true)
    w = nil
    p = nil
  end
end

M.vimgrep_preview = u.expect_key.." --preview="..require('fzf.actions').action(function(s, _, _)
  local c = u.parse_vimgrep(s[1])
  open_floating_win(c[1], c[2])
  return ""
end)

return M
