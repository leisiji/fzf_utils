local fzf = require('fzf').fzf
local fn = vim.fn
local M = {}
local utils = require('fzf_utils.utils')

local function get_rg_cmd(pattern, dir)
  local rgcmd = "rg -w --vimgrep --no-heading --color ansi " .. fn.shellescape(pattern)

  if type(dir) == "string" then
    rgcmd = rgcmd .. ' ' .. dir
  elseif type(dir) == "table" then
    for _,val in ipairs(dir) do
      rgcmd = rgcmd .. ' ' .. val
    end
  end

  return rgcmd
end

local function deal_with_rg_results(key, result)
  local parsed_content = {string.match(result, "(.-):(%d+):(%d+):.*")}
  local filename = parsed_content[1]
  local row = tonumber(parsed_content[2])
  local col = tonumber(parsed_content[3]) - 1

  utils.handle_key(key, filename, row, col)
end

local function get_all_buffers(pattern)
  local api = vim.api
  local buffers = {}
  for _, bufhandle in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_loaded(bufhandle) and fn.buflisted(bufhandle) == 1 then
      local name = fn.bufname(bufhandle)
      buffers[#buffers+1] = name
    end
  end
  return get_rg_cmd(pattern, buffers)
end

--------------------- command function ----------------------
function M.search_path(pattern, path)
  coroutine.wrap(function ()
    local choices = fzf(get_rg_cmd(pattern, path), utils.vimgrep_preview)
    deal_with_rg_results(choices[1], choices[2])
  end)()
end

function M.search_all_buffers(pattern)
  coroutine.wrap(function ()
    local choices = fzf(get_all_buffers(pattern), utils.vimgrep_preview)
    deal_with_rg_results(choices[1], choices[2])
  end)()
end

return M
