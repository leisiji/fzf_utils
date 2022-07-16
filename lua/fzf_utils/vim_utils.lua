local M = {}
local fzf = require("fzf").fzf
local u = require("fzf_utils.utils")
local a = require("plenary.async_lib")

local deal_with_tags = a.async(function(path, cb)
  local data = a.await(u.readfile(path))
  if data == nil then
    return
  end
  for _, line in ipairs(vim.split(data, "\n")) do
    local items = vim.split(line, "\t")
    local tag = string.format("%s\t\27[0;37m%s\27[0m", items[1], items[2])
    cb(tag, function() end)
  end
end)

local function get_help_tags(cb)
  a.async_void(function()
    local paths = vim.api.nvim_list_runtime_paths()
    local futures = {}
    -- start coroutine on per tag file
    for _, rtp in ipairs(paths) do
      local f = string.format("%s/doc/tags", rtp)
      futures[#futures + 1] = deal_with_tags(f, cb)
    end
    a.await_all(futures)
    cb(nil, function() end)
  end)()
end

function M.filetypes()
  coroutine.wrap(function()
    local fn = vim.fn
    local syntax_files = fn.globpath(vim.o.rtp, "syntax/*.vim")
    local filetypes = fn.split(syntax_files, "\n")
    local ft_list = {}
    for _, filetype in ipairs(filetypes) do
      ft_list[#ft_list + 1] = fn.fnamemodify(filetype, ":t:r")
    end
    local result = fzf(ft_list, "")
    vim.cmd("set ft=" .. result[1])
  end)()
end

function M.help()
  coroutine.wrap(function()
    local result = fzf(get_help_tags, "--nth 1 --expect=ctrl-t")
    if not result then
      return
    end

    local choice = vim.split(result[2], "\t")[1]
    local key = result[1]
    local windowcmd
    if key == "ctrl-t" then
      windowcmd = "tab"
    else
      windowcmd = "vertical"
    end

    vim.cmd(string.format("%s h %s", windowcmd, choice))
  end)()
end

function M.cmdHists()
  local fn = vim.fn
  local search = "cmd"
  local nr = fn.histnr(search)
  local cmds = {}

  while nr >= 0 do
    local cmd = fn.histget(search, nr - #cmds)
    nr = nr - 1
    if cmd ~= nil and #cmd > 0 then
      cmds[#cmds + 1] = cmd
    end
  end

  coroutine.wrap(function()
    local result = fzf(cmds, "")
    vim.cmd(result[1])
  end)()
end

return M
