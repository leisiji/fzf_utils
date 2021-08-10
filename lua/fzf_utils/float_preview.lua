-- references: https://github.com/rmagatti/goto-preview
local M = {}
local u = require('fzf_utils.utils')

-- parse preview percentage from fzf env
local fzf_opt = vim.env['FZF_DEFAULT_OPTS']
local parse_percent = nil
local percent = 0.5
if fzf_opt ~= nil then
  parse_percent = string.match(fzf_opt, ".*:(%d+)%.*")
  if parse_percent ~= nil then
    percent = parse_percent / 100
  end
end

local function open_floating_win(path, line_nr)
  local api = vim.api
  local buffer = vim.fn.bufadd(path)
  local columns, lines = vim.o.columns, vim.o.lines
  local fzf_width = math.min(columns - 4, math.max(80, columns - 20))
  local width = math.floor(fzf_width * percent)
  local height = math.min(lines - 4, math.max(20, lines - 10)) - 1
  local opts = {
    relative = 'editor',
    focusable = false,
    border = {"↖", "─" ,"┐", "│", "┘", "─", "└", "│"},
    --bufpos = bufpos,
    --win = api.nvim_get_current_win()
    width = width,
    height = height,
    row = math.floor((lines - height)/2),
    col = math.floor((columns - fzf_width)/2 +  fzf_width * (1 - percent)),
  }

  local w = api.nvim_open_win(buffer, true, opts)
  api.nvim_buf_set_option(buffer, 'bufhidden', 'wipe')
  api.nvim_win_set_cursor(w, {line_nr, 0})
end

function M.get_preview_action(path)
  local shell = require('fzf.actions').action(function(selections, _, _)
    if selections ~= nil then
      local line_nr = u.get_leading_num(selections[1])
      open_floating_win(path, line_nr)
      return ""
    end
  end)
  return shell
end

return M
