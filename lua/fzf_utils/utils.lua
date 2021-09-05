local M = {}

function M.get_leading_num(str)
  return tonumber(string.match(str, "%d+"))
end

M.expect_key = '--expect=ctrl-v,ctrl-r,ctrl-t,ctrl-s'

--local fn = vim.fn
--local function preview_lines(path, line, fzf_preview_lines)
--  local half_preview_lines = fzf_preview_lines / 2
--  local start_line = line - half_preview_lines
--  local end_line = line + half_preview_lines
--
--  if start_line < 0 then
--    end_line = end_line - start_line
--    start_line = 0
--  end
--
--  local cmd = string.format("bat -H %i --color always --style numbers --pager never -r %i:%i %s",
--        line, start_line, end_line, path)
--  return fn.system(cmd)
--end
--M.vimgrep_preview = M.expect_key.." --preview="..require('fzf.actions').action(function(selections, fzf_preview_lines, _)
--  local parsed_content = M.parse_vimgrep(selections[1])
--  return preview_lines(parsed_content[1], parsed_content[2], fzf_preview_lines)
--end)
-- get preview action that has result starting with line number
--function M.get_preview_action(path)
--  local shell = require('fzf.actions').action(function(selections, fzf_preview_lines, _)
--    if selections ~= nil then
--      local line_nr = M.get_leading_num(selections[1])
--      return preview_lines(path, line_nr, fzf_preview_lines)
--    end
--  end)
--  return shell
--end

-- return: { path, line, column }
function M.parse_vimgrep(content)
  local res = { string.match(content, "(.-):(%d+):(%d*)") }
  return { res[1], tonumber(res[2]), tonumber(res[3]) }
end

function M.cmdedit(action, path, row, col)
  -- avoid second load
  vim.cmd(string.format('%s %s', action, path))
  if col ~= nil and row ~= nil then
    vim.api.nvim_win_set_cursor(0, {row, col})
  end
  vim.cmd("normal! zz")
end

local key_actions = {
  ['ctrl-v']='vsplit',
  ['ctrl-s']='split',
  ['ctrl-t']='tab drop',
}

function M.handle_key(key, path, row, col)
  local action = key_actions[key] or 'tab drop'
  M.cmdedit(action, path, row, col)
end

-- file operation
local a = require('plenary.async_lib')
local async = a.async
local await = a.await

-- file
M.readfile = async(function (path)
  local _, fd = await(a.uv.fs_open(path, "r", 438))
  if fd == nil then return nil end
  local _, stat = await(a.uv.fs_fstat(fd))
  local _, data = await(a.uv.fs_read(fd, stat.size, 0))
  await(a.uv.fs_close(fd))
  return data
end)

return M
