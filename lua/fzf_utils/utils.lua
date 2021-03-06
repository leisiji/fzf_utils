local M = {}
local expect_key = nil

local function open_float_win(path, row, col)
  local win_width = vim.api.nvim_win_get_width(0)
  local w = math.floor(win_width * 0.5)
  local h = vim.api.nvim_win_get_height(0) / 2
  local pos = vim.api.nvim_win_get_cursor(0)
  local win = require("fzf_utils.float_preview").open_float_win(path, pos[1], pos[2], w, h, true, 40)
  vim.api.nvim_win_set_cursor(win, { row, col })
end

local key_actions = {
  ["ctrl-v"] = "vsplit",
  ["ctrl-s"] = "split",
  ["ctrl-t"] = "tabe",
  ["ctrl-f"] = open_float_win,
}

function M.get_leading_num(str)
  return tonumber(string.match(str, "%d+"))
end

function M.expect_key()
  if expect_key == nil then
    expect_key = "--expect="
    for key, _ in pairs(key_actions) do
      expect_key = expect_key .. key .. ","
    end
  end
  return expect_key
end

-- return: { path, line, column }
function M.parse_vimgrep(content)
  local res = { string.match(content, "(.-):(%d+):(%d*)") }
  return { res[1], tonumber(res[2]), tonumber(res[3]) }
end

function M.cmdedit(action, path, row, col)
  -- avoid second load
  vim.cmd(string.format("%s %s", action, path))
  if col ~= nil and row ~= nil then
    vim.api.nvim_win_set_cursor(0, { row, col })
  end
  vim.cmd("normal! zz")
end

function M.handle_key(key, path, row, col)
  local action = key_actions[key] or "tab drop"
  if type(action) == "function" then
    action(path, row, col)
  else
    M.cmdedit(action, path, row, col)
  end
end

-- file operation
local a = require("plenary.async_lib")
local async = a.async
local await = a.await

-- file
M.readfile = async(function(path)
  local _, fd = await(a.uv.fs_open(path, "r", 438))
  if fd == nil then
    return nil
  end
  local _, stat = await(a.uv.fs_fstat(fd))
  local _, data = await(a.uv.fs_read(fd, stat.size, 0))
  await(a.uv.fs_close(fd))
  return data
end)

return M
