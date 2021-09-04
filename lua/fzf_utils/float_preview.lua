-- references: https://github.com/rmagatti/goto-preview
-- preview is single instance
local M = {}
local u = require('fzf_utils.utils')
local p = nil
local w = nil
local api = vim.api
local percent = 0.5
local initialized = false

local function w_exe(win, cmd)
  vim.fn.win_execute(win, 'norm! ' .. cmd)
end

local function float_act(str)
  return string.format([[<cmd>lua require('fzf_utils.float_preview').%s<cr>]], str)
end
local keymap = {
  ['<C-p>'] = float_act('close_preview_win()'),
  ['<M-j>'] = float_act('scroll(1)'),
  ['<M-k>'] = float_act('scroll(-1)'),
}

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

function M.scroll(line)
  local cmd
  if line > 0 then
    cmd = [[]]
  else
    cmd = [[]]
  end
  w_exe(w, math.abs(line)..cmd)
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

  local fzf_width = api.nvim_win_get_width(0)
  local fzf_pos = api.nvim_win_get_position(0)
  local width = math.floor(fzf_width * percent)
  local height = api.nvim_win_get_height(0)
  local opts = {
    relative = 'editor', border = 'rounded',
    width = width, height = height, zindex = 200,
    row = fzf_pos[1], col = fzf_pos[2] + fzf_width - width
  }

  w = api.nvim_open_win(b, false, opts)
  api.nvim_buf_set_option(b, 'bufhidden', 'wipe')

  vim.cmd([[
    augroup close_float_fzf
      au! * <buffer>
      au BufHidden <buffer> lua require('fzf_utils.float_preview').close_preview_win()
    augroup end
  ]])

  for k, v in pairs(keymap) do
    api.nvim_buf_set_keymap(0, 't', k, v, { noremap = true })
  end
  api.nvim_win_set_option(w, 'signcolumn', 'no')

  return w
end

local function open_floating_win(path, l)
  local win = create_win(path)
  api.nvim_win_set_cursor(win, {l, 0})
  w_exe(win, 'zz')
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

local act = require('fzf.actions').action(function(s, _, _)
  local c = u.parse_vimgrep(s[1])
  open_floating_win(c[1], c[2])
  return ''
end)

M.vimgrep_preview = string.format([[%s --preview=%s ]], u.expect_key, act)

return M
