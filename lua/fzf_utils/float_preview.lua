-- references: https://github.com/rmagatti/goto-preview
-- preview is single instance
local M = {}
local u = require('fzf_utils.utils')
local api = vim.api
local percent = 0.5
local preview_win = {
  win = nil, path = nil, line = nil,
  toggle = false, word = nil, match_id = nil
}

local function float_act(str)
  return string.format([[<cmd>lua require('fzf_utils.float_preview').%s<cr>]], str)
end

local keymap = {
  ['<C-p>'] = float_act('toggle_preview()'),
  ['<M-j>'] = float_act('scroll(1)'),
  ['<M-k>'] = float_act('scroll(-1)'),
}

local function w_exe(win, cmd)
  vim.fn.win_execute(win, 'norm! ' .. cmd)
end

-- parse preview percentage and keymaps from fzf env
local function init_opts()
  local fzf_opt = vim.env['FZF_DEFAULT_OPTS']
  if fzf_opt ~= nil then
    local parse_percent = string.match(fzf_opt, ".*:(%d+)%.*")
    if parse_percent ~= nil then
      percent = parse_percent / 100
    end
  end
end

local function set_float_win_options(w)
  api.nvim_win_set_option(w, 'signcolumn', 'no')
  api.nvim_win_set_option(w, 'winhl', 'NormalFloat:Normal')
end

local function highlight_word(word, w)
  return vim.fn.matchadd('LspReferenceText',
      string.format([[\V\<%s\>]], word), 11, -1, { window = w })
end

local function create_buf(path)
  local b = vim.fn.bufadd(path)
  api.nvim_buf_set_option(b, 'bufhidden', 'wipe')
  return b
end

local function create_win(path)
  local fzf_width = api.nvim_win_get_width(0)
  local fzf_pos = api.nvim_win_get_position(0)
  local fzf_height = api.nvim_win_get_height(0)
  local width = math.floor(fzf_width * percent)
  local row = fzf_pos[2] + fzf_width - width

  local w = M.open_float_win(path, fzf_pos[1], row, width, fzf_height)

  -- buffer related
  for k, v in pairs(keymap) do
    api.nvim_buf_set_keymap(0, 't', k, v, { noremap = true })
  end
  vim.cmd([[
    augroup close_float_fzf
      au! * <buffer>
      au BufHidden <buffer> lua require('fzf_utils.float_preview').close_preview_win()
    augroup end
  ]])

  local word = preview_win.word
  if word ~= nil then
    preview_win.match_id = highlight_word(word, w)
  end

  return w
end

local function open_floating_win_(path, l)
  local w = preview_win.win
  if w == nil then
    w = create_win(path)
    preview_win.win = w
  elseif path ~= preview_win.path then
    local b = create_buf(path)
    api.nvim_win_set_buf(w, b)
    set_float_win_options(w)
  end
  api.nvim_win_set_cursor(w, {l, 0})
  w_exe(w, 'zz')
end

local function open_floating_win(path, l)
  if not preview_win.toggle then
    open_floating_win_(path, l)
  end
  preview_win.line = l
  preview_win.path = path
end

local function fzf_preview(cmd)
  return string.format([[ --preview-window=right,0 --preview=%s ]], cmd)
end

local act = require('fzf.actions').action(function(s, _, _)
  local c = u.parse_vimgrep(s[1])
  open_floating_win(c[1], c[2])
  return ''
end)

local function close_win()
  local w = preview_win.win
  if w ~= nil and api.nvim_win_is_valid(w) then
    api.nvim_win_close(w, true)
  end
  preview_win.win = nil
end

-------------- Module Export Function -----------
function M.close_preview_win()
  close_win()
  preview_win.path = nil
  preview_win.toggle = false
  preview_win.match_id = nil
  preview_win.word = nil
end

function M.scroll(line)
  local cmd
  if line > 0 then
    cmd = [[]]
  else
    cmd = [[]]
  end
  w_exe(preview_win.win, math.abs(line)..cmd)
end

function M.toggle_preview()
  local toggle = preview_win.toggle
  if not toggle then
    close_win()
  else
    open_floating_win_(preview_win.path, preview_win.line)
  end
  preview_win.toggle = not toggle
end

function M.open_float_win(path, row, col, width, height, focus, zindex)
  local opts = {
    relative = 'editor', border = 'rounded',
    width = width, height = height, zindex = zindex or 60,
    row = row, col = col,
  }
  local b = create_buf(path)
  local w = api.nvim_open_win(b, focus or false, opts)

  set_float_win_options(w)
  return w
end

function M.get_preview_action(path, word)
  local action = require('fzf.actions').action
  local shell = action(function(s, _, _)
    if s ~= nil then
      preview_win.word = word
      open_floating_win(path, u.get_leading_num(s[1]))
      return ""
    end
  end)
  return u.expect_key() .. fzf_preview(shell)
end

function M.vimgrep_preview(word)
  preview_win.word = word
  return fzf_preview(act)..u.expect_key()
end

init_opts()

return M
