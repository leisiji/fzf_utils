local fzf = require("fzf").fzf
local utils = require("fzf_utils.utils")
local fn = vim.fn
local api = vim.api
local M = {}

local function get_buf_lines()
  local lines = api.nvim_buf_get_lines(fn.bufnr(), 0, fn.line("$"), 1)
  local n = 1
  local bufs = {}

  for _, line in pairs(lines) do
    line = string.format("%d %s", n, line)
    bufs[n] = line
    n = n + 1
  end

  return bufs
end

function M.grep_lines()
  local preview = require("fzf_utils.float_preview").get_preview_action
  coroutine.wrap(function()
    local path = fn.expand("%:p")
    local col = fn.getcurpos()[3]
    local p = " --nth=2.. " .. preview(path)
    local cmd
    local is_file = fn.filereadable(path) == 1
    if is_file then
      cmd = "cat -n " .. path
    else
      cmd = get_buf_lines()
    end
    local choices = fzf(cmd, p)
    local row = utils.get_leading_num(choices[2])
    if is_file then
      utils.handle_key(choices[1], path, row, col)
    else
      vim.api.nvim_win_set_cursor(0, { row, col })
    end
  end)()
end

function M.find_files()
  local FZF_CAHCE_FILES_DIR = fn.stdpath("cache") .. "/fzf_files/"
  local cache_file = FZF_CAHCE_FILES_DIR .. fn.sha256(fn.getcwd())
  local command

  if fn.filereadable(cache_file) == 0 then
    if fn.isdirectory(FZF_CAHCE_FILES_DIR) == 0 then
      fn.mkdir(FZF_CAHCE_FILES_DIR)
    end

    command = (vim.env.FZF_DEFAULT_COMMAND or "fd -t f -L") .. "| tee "
  else
    command = "cat "
  end

  command = command .. cache_file

  coroutine.wrap(function()
    local choices = fzf(command, utils.expect_key() .. "ctrl-r")
    if choices[1] == "ctrl-r" then
      os.remove(cache_file)
      vim.defer_fn(M.find_files, 200)
    else
      utils.handle_key(choices[1], choices[2], nil, nil)
    end
  end)()
end

function M.buffers()
  coroutine.wrap(function()
    local items = {}
    for _, bufhandle in ipairs(api.nvim_list_bufs()) do
      if api.nvim_buf_is_loaded(bufhandle) and fn.buflisted(bufhandle) == 1 then
        local name = fn.bufname(bufhandle)
        if #name ~= 0 then
          table.insert(items, name)
        end
      end
    end
    local choices = fzf(items, utils.expect_key())
    utils.handle_key(choices[1], choices[2], nil, nil)
  end)()
end

local function query_man()
  local job = nil
  local ws_act = require("fzf.actions").raw_async_action(function(pipe, args)
    local a = require("plenary.async_lib")
    if args[2] == "" or args[2] == nil then
      a.async_void(a.uv.close(pipe))()
      return
    end

    if job ~= nil then
      vim.fn.jobstop(job)
    end

    local query = args[2]
    local cmd = "apropos " .. query
    a.async_void(function()
      job = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
          vim.loop.write(pipe, vim.fn.join(data, "\n"))
        end,
        on_exit = function()
          vim.loop.close(pipe)
        end,
      })
    end)()
  end)

  local choices = require("fzf").fzf({}, utils.live_act(ws_act))
  return choices[1]
end

function M.Man()
  coroutine.wrap(function()
    local res = query_man()
    if res ~= nil then
      local s = string.find(res, "%(")
      local name = vim.split(string.sub(res, 1, s - 1), ",")[1]
      local chap = string.match(string.sub(res, s + 1, -1), "(%d+).+")
      api.nvim_command(string.format("vertical Man %s %s", chap, name))
    end
  end)()
end

function M.commit()
  coroutine.wrap(function()
    local choices = fzf("git log --oneline --color", "--preview='git show --color {1} --stat'")
    local res = choices[1]
    local id = string.sub(res, 1, string.find(res, " ") - 1)
    local cmd = string.format("DiffviewOpen %s~1..%s", id, id)
    api.nvim_command(cmd)
  end)()
end

function M.zoxide()
  coroutine.wrap(function()
    local w = api.nvim_win_get_width(0)
    local h = api.nvim_win_get_height(0)
    local choices = fzf("zoxide query --list", "--preview='eza -l --color=always {1}'")
    if choices == nil then
      return
    end

    local _, buf = require("fzf_utils.float_preview").open_float_win(nil, h / 4, w / 4, w / 2, h / 2, true)
    api.nvim_set_option_value("filetype", "joshuto", { buf = buf })
    vim.cmd("cd " .. choices[1])

    local cmd = string.format("joshuto --change-directory %s", choices[1])
    local job = vim.fn.termopen(cmd, {
      on_exit = function()
        api.nvim_buf_delete(buf, { force = true, unload = false })
      end,
    })
    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = buf,
      callback = function()
        vim.fn.jobstop(job)
      end,
    })
    -- TODO: if no delay to startinsert, it will not take effect
    vim.defer_fn(function()
      vim.cmd("startinsert!")
    end, 500)
  end)()
end

return M
