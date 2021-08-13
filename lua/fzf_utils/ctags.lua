local M = {}
local fzf = require('fzf').fzf
local fn = vim.fn
local preview = require('fzf_utils.float_preview').get_preview_action

-- example: {"_type": "tag", "pattern": "/^void thaw_secondary_cpus(void)$/", "line": 1412, "kind": "function"}
local function get_ctags(file)
  local cmd = string.format("ctags --output-format=json -u --fields=nzP -f- %s", file)
  local res = fn.systemlist(cmd)
  local funcs = {}

  for _,val in pairs(res) do
    local tag_json_obj = fn.json_decode(val)
    local tag_type = tag_json_obj["kind"]
    if tag_type == "function" or tag_type == "method" or tag_type == "member" then
      local pattern = tag_json_obj["pattern"]
      local func_name = string.sub(pattern, 3, #pattern - 2)
      local ln = tag_json_obj["line"]
      local str = string.format("%s: %s", ln, func_name)
      funcs[#funcs+1] = str
    end
  end

  return funcs
end

function M.get_cur_buf_func()
  coroutine.wrap(function ()
    local utils = require('fzf_utils.utils')
    local cur_file = fn.expand("%:p")
    local col = fn.getcurpos()[3]
    local res = get_ctags(cur_file)
    local cmd = string.format('%s --preview=%s',
                  utils.expect_key, preview(cur_file))
    local choices = fzf(res, cmd)
    utils.handle_key(choices[1], cur_file,
                  utils.get_leading_num(choices[2]), col)
  end)()
end

return M
