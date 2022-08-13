local fzf = require("fzf").fzf
local fn = vim.fn
local M = {}
local utils = require("fzf_utils.utils")
local preview = require("fzf_utils.float_preview").vimgrep_preview
local rg = "rg --with-filename --line-number --column --color ansi "

local function get_rg_cmd(pattern, dir)
  local rgcmd = rg .. "-w " .. fn.shellescape(pattern)

  if type(dir) == "string" then
    rgcmd = rgcmd .. " " .. dir
  elseif type(dir) == "table" then
    for _, val in ipairs(dir) do
      rgcmd = rgcmd .. " " .. val
    end
  end

  return rgcmd
end

local function deal_with_rg_results(key, result)
  local parsed_content = { string.match(result, "(.-):(%d+):(%d+):.*") }
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
      buffers[#buffers + 1] = name
    end
  end
  return get_rg_cmd(pattern, buffers)
end

--------------------- command function ----------------------
function M.search_path(pattern, path)
  coroutine.wrap(function()
    local choices = fzf(get_rg_cmd(pattern, path), preview(pattern))
    deal_with_rg_results(choices[1], choices[2])
  end)()
end

function M.search_all_buffers(pattern)
  coroutine.wrap(function()
    local choices = fzf(get_all_buffers(pattern), preview(pattern))
    deal_with_rg_results(choices[1], choices[2])
  end)()
end

function M.live_grep(path)
  coroutine.wrap(function()
    local a = require("plenary.async_lib")
    local job

    utils.fzf_live(function(query, pipe)
      local cmd = rg .. query .. " " .. (path or ".")
      vim.fn.jobstop(job)
      job = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
          a.async_void(function()
            a.await(a.uv.write(pipe, vim.fn.join(data, "\n")))
          end)()
        end,
        on_exit = function()
          a.async_void(function()
            a.await(a.uv.close(pipe))
          end)()
        end,
      })
    end)

    vim.fn.jobstop(job)
  end)()
end

return M
