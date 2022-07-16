local M = {}
local fzf = require("fzf").fzf
local fn = vim.fn

-- example: {"_type": "tag", "pattern": "/^void thaw_secondary_cpus(void)$/", "line": 1412, "kind": "function"}
local function get_ctags(file)
  local cmd = string.format("ctags --output-format=json -u --fields=nzP -f- %s", file)
  local res = fn.systemlist(cmd)
  local funcs = {}

  for _, val in pairs(res) do
    local tag_obj = fn.json_decode(val)
    local type = tag_obj.kind
    if type == "function" or type == "method" or type == "member" then
      local pattern = tag_obj.pattern
      local func_name = string.sub(pattern, 3, #pattern - 2)
      funcs[#funcs + 1] = string.format("%s: %s", tag_obj["line"], func_name)
    end
  end

  return funcs
end

function M.get_cur_buf_func()
  coroutine.wrap(function()
    local utils = require("fzf_utils.utils")
    local cur_file = fn.expand("%:p")
    local col = fn.getcurpos()[3]
    local res = get_ctags(cur_file)
    local preview = require("fzf_utils.float_preview").get_preview_action
    local choices = fzf(res, preview(cur_file))
    utils.handle_key(choices[1], cur_file, utils.get_leading_num(choices[2]), col)
  end)()
end

return M
