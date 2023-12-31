-- references: https://github.com/rmagatti/goto-preview
-- preview is single instance
local M = {}
local u = require("fzf_utils.utils")
local api = vim.api
local PreviewWin = {}

local function float_act(str)
  return string.format([[<cmd>lua require('fzf_utils.float_preview').%s<cr>]], str)
end

function PreviewWin:new()
  local object = {
    win = nil,
    context_win = nil,
    path = nil,
    prev_path = nil,
    line = nil,
    toggled = false,
    word = nil,
    match_id = nil,
    timer = nil,
    percent = 0.65,
  }

  local opt = vim.env["FZF_DEFAULT_OPTS"]
  if opt ~= nil then
    local percent = string.match(opt, ".*:(%d+)%.*")
    if percent ~= nil then
      object.percent = percent / 100
    end
  end
  object.keymaps = {
    ["<C-p>"] = float_act("toggle_preview()"),
    ["<M-j>"] = float_act("scroll(1)"),
    ["<M-k>"] = float_act("scroll(-1)"),
  }
  object.group = api.nvim_create_augroup("close_float_fzf", { clear = true })

  self.__index = self
  return setmetatable(object, self)
end

local preview = PreviewWin:new()

local function w_exe(win, cmd)
  vim.fn.win_execute(win, "norm! " .. cmd)
end

-- parse preview percentage and keymaps from fzf env
local function set_float_win_options(w)
  api.nvim_win_set_option(w, "signcolumn", "no")
  api.nvim_win_set_option(w, "winhl", "NormalFloat:Normal")
end

local function highlight_word(word, w)
  return vim.fn.matchadd("LspReferenceText", string.format([[\V\<%s\>]], word), 11, -1, { window = w })
end

local function create_buf(w, path)
  vim.fn.win_execute(w, "e " .. path)
  local b = vim.fn.winbufnr(w)
  api.nvim_buf_set_option(b, "bufhidden", "wipe")
  return b
end

function PreviewWin:create_win(path)
  local fzf_width = api.nvim_win_get_width(0)
  local fzf_pos = api.nvim_win_get_position(0)
  local fzf_height = api.nvim_win_get_height(0)
  local width = math.floor(fzf_width * self.percent)
  local row = fzf_pos[2] + fzf_width - width

  local w = M.open_float_win(path, fzf_pos[1], row, width, fzf_height)

  -- buffer related
  for k, v in pairs(self.keymaps) do
    api.nvim_buf_set_keymap(0, "t", k, v, { noremap = true })
  end
  local bufnr = api.nvim_get_current_buf()
  api.nvim_clear_autocmds({ group = self.group, buffer = bufnr })
  api.nvim_create_autocmd({ "BufHidden" }, {
    group = self.group,
    callback = require("fzf_utils.float_preview").close_preview_win,
    buffer = bufnr,
  })

  local word = self.word
  if word ~= nil then
    self.match_id = highlight_word(word, w)
  end

  return w
end

function PreviewWin:open_floating_win_(path, l)
  local w = self.win

  if w == nil then
    w = self:create_win(path)
    self.win = w
  elseif path ~= self.prev_path then
    create_buf(w, path)
    set_float_win_options(self.win)
    local config = api.nvim_win_get_config(self.win)
    config.title = path
    api.nvim_win_set_config(self.win, config)
  else
    api.nvim_win_get_buf(w)
  end

  self.prev_path = path
  api.nvim_win_set_cursor(w, { l, 0 })
end

function PreviewWin:open_floating_win(path, l)
  if not self.toggled then
    if self.timer ~= nil then
      vim.loop.timer_stop(self.timer)
    end
    self.timer = vim.defer_fn(function()
      self:open_floating_win_(path, l)
      self.timer = nil
    end, 300)
  end
  self.line = l
  self.path = path
end

local function fzf_preview(cmd)
  return string.format([[ --preview-window=right,0 --preview=%s ]], cmd)
end

local function close_win(w)
  if w ~= nil and api.nvim_win_is_valid(w) then
    api.nvim_win_close(w, true)
  end
end

function PreviewWin:close_float_win()
  self.prev_path = nil
  self.toggled = false
  self.match_id = nil
  self.word = nil
  close_win(self.win)
  close_win(self.context_win)
  self.win = nil
  self.context_win = nil
end

function PreviewWin:toggle()
  local toggled = self.toggled
  if not toggled then
    self:close_float_win()
  else
    self:open_floating_win_(self.path, self.line)
  end
  self.toggled = not toggled
end

-------------- Module Export Function -----------
local act = require("fzf.actions").action(function(s, _, _)
  local c = u.parse_vimgrep(s[1])
  preview:open_floating_win(c[1], c[2])
  return ""
end)

function M.close_preview_win()
  preview:close_float_win()
end

function M.scroll(line)
  local cmd
  if line > 0 then
    cmd = [[]]
  else
    cmd = [[]]
  end
  w_exe(preview.win, math.abs(line) .. cmd)
end

function M.toggle_preview()
  preview:toggle()
end

function M.open_float_win(path, row, col, width, height, focus, zindex)
  local opts = {
    relative = "editor",
    border = "rounded",
    width = math.floor(width),
    height = math.floor(height),
    zindex = zindex or 60,
    row = math.floor(row),
    col = math.floor(col),
    focusable = focus or false,
    title = path,
    title_pos = "right",
  }
  local w = api.nvim_open_win(0, focus or false, opts)
  local b = create_buf(w, path)

  set_float_win_options(w)
  w_exe(w, "zz")
  return w, b
end

function M.get_preview_action(path, word)
  local action = require("fzf.actions").action
  local shell = action(function(s, _, _)
    if s ~= nil then
      preview.word = word
      preview:open_floating_win(path, u.get_leading_num(s[1]))
      return ""
    end
  end)
  return u.expect_key() .. fzf_preview(shell)
end

function M.vimgrep_preview(word)
  preview.word = word
  return fzf_preview(act) .. u.expect_key()
end

return M
