local M = {}
local lsp, fn = vim.lsp, vim.fn
local utils = require('fzf_utils.utils')
local a = require('plenary.async_lib')
local request = require('plenary.async_lib.lsp').buf_request_all
local fzf = require('fzf').fzf
local preview = require('fzf_utils.float_preview').vimgrep_preview

-- transform function
local function lsp_item_to_vimgrep(r)
  if r.location ~= nil then
    r = r.location
  end
  local range = r.range or r.targetRange
  local uri = r.uri or r.targetUri
  local loc = range.start
  local path = fn.fnamemodify(vim.uri_to_fname(uri), ':.')
  local line = vim.lsp.util.get_line(uri, loc.line)

  return string.format('%s:%d:%d %s', path, loc.line + 1, loc.character + 1, line)
end

local function lsp_to_vimgrep(ret)
  local res = {}
  for _, v in pairs(ret) do
    if v.result ~= nil then
      for _, item in pairs(v.result) do
        res[#res+1] = lsp_item_to_vimgrep(item)
      end
    else
      res[#res+1] = lsp_item_to_vimgrep(v)
    end
  end
  return res
end

local function lsp_to_fzf(res, cli_args)
  coroutine.wrap(function ()
    local choices = fzf(res, cli_args)
    local c = utils.parse_vimgrep(choices[2])
    utils.handle_key(choices[1], c[1], c[2], c[3])
  end)()
end

-- core function for finding def or ref
local function lsp_handle(ret, action)
  local res = lsp_to_vimgrep(ret)

  if #res == 1 then
    local c = utils.parse_vimgrep(res[1])
    utils.cmdedit(action, c[1], c[2], c[3])
  else
    lsp_to_fzf(res, preview(fn.expand('<cword>')))
  end
end

local function lsp_async(method, action)
  a.async_void(function ()
    local params = lsp.util.make_position_params()
    params.context = { includeDeclaration = true; }
    local r = a.await(request(0, method, params))
    if r == nil then
      print(method + 'not found')
    else
      lsp_handle(r, action)
    end
  end)()
end

function M.jump_def(action)
  lsp_async('textDocument/definition', action or 'edit')
end

function M.ref(action)
  lsp_async('textDocument/references', action or 'edit')
end

function M.workspace_symbol()
  local timer
  local bufnr = fn.bufnr()
  local raw_fzf = require("fzf.actions").raw_async_action

  local ws_act = raw_fzf(function(pipe, args)
    if args == nil or args[2] == '' then
      return
    end

    if timer ~= nil then
      vim.loop.timer_stop(timer)
      timer = nil
    end

    timer = vim.defer_fn(a.async_void(function ()
      local r = a.await(request(bufnr, 'workspace/symbol', { query = args[2] }))
      if r ~= nil then
        a.await(a.uv.write(pipe, table.concat(lsp_to_vimgrep(r), '\n')))
        a.await(a.uv.close(pipe))
      end
    end), 1000)
  end)

  local act = preview()..string.format([[ --bind "change:reload:%s {q}"]], ws_act)
  lsp_to_fzf({}, act)
end

return M
