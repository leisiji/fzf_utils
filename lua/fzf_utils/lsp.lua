local M = {}
local lsp, fn = vim.lsp, vim.fn
local utils = require('fzf_utils.utils')
local a = require('plenary.async_lib')
local request = require('plenary.async_lib.lsp').buf_request_all

-- transform function
local function lsp_to_vimgrep(r)
  local range = r.range or r.targetRange
  local uri = r.uri or r.targetUri
  local loc = range.start
  local path = fn.fnamemodify(vim.uri_to_fname(uri), ':.')
  local line = vim.lsp.util.get_line(uri, loc.line)

  return string.format('%s:%d:%d %s', path, loc.line + 1, loc.character + 1, line)
end

-- core function for finding def or ref
local function lsp_handle(ret, action)
  local c
  local res = {}

  for _, v in pairs(ret) do
    if v.result ~= nil then
      for _, item in pairs(v.result) do
        res[#res+1] = lsp_to_vimgrep(item)
      end
    else
      res[#res+1] = lsp_to_vimgrep(v)
    end
  end

  if #res == 1 then
    c = utils.parse_vimgrep(res[1])
    utils.cmdedit(action, c[1], c[2], c[3])
  else
    coroutine.wrap(function ()
      local choices = require('fzf').fzf(res, require('fzf_utils.float_preview').vimgrep_preview)
      c = utils.parse_vimgrep(choices[2])
      utils.handle_key(choices[1], c[1], c[2], c[3])
    end)()
  end
end

local function lsp_fzf(method, action)
  a.async_void(function ()
    local r = a.await(request(0, method, lsp.util.make_position_params()))
    if r == nil then
      print(method + 'not found')
    else
      lsp_handle(r, action)
    end
  end)()
end

function M.definition(action)
  lsp_fzf('textDocument/definition', action or 'edit')
end

function M.references(action)
  lsp_fzf('textDocument/references', action or 'edit')
end

return M
