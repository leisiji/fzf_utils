local fn = vim.fn
local M = {}
local fzf = require('fzf').fzf
local utils = require('fzf_utils.utils')

vim.env.GTAGSROOT = fn.getcwd()
vim.env.GTAGSDBPATH = vim.env.GTAGSROOT

local function execute_global(options, pattern)
  coroutine.wrap(function ()
    local choices = fzf("global --result=grep " .. options .. " " .. pattern,
                        require('fzf_utils.float_preview').vimgrep_preview(pattern))
    if choices == nil then
      return
    end

    local parsed_content = {string.match(choices[2], "(.-):(%d+):.*")}
    local filename = parsed_content[1]
    local row = tonumber(parsed_content[2])
    utils.handle_key(choices[1], filename, row, 1)
  end)()
end

function M.find_definition(pattern)
  execute_global("-d", pattern)
end

function M.find_references(pattern)
  execute_global("-r", pattern)
end

function M.generate_gtags()
  local cmd = string.format("cd %s && gtags", vim.env.GTAGSROOT)
  fn.jobstart(cmd, {
    on_exit = function ()
      print('generat gtags successfully')
    end
  })
end

function M.gtags_update_buffer()
  local file = fn.expand("%")
  fn.jobstart("gtags --single-update" .. file , {
    on_exit = function ()
      print('update ' .. file .. ' successfully')
    end
  })
end

return M
