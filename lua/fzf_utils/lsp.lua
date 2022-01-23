local M = {}
local lsp, fn = vim.lsp, vim.fn
local utils = require('fzf_utils.utils')
local a = require('plenary.async_lib')
local request = require('plenary.async_lib.lsp').buf_request_all
local fzf = require('fzf').fzf
local preview = require('fzf_utils.float_preview').vimgrep_preview
local color_vimgrep = "\27[0;35m%s:%d:%d\27[0m %s"

local function gen_vimgrep(pattern, item)
  local s = string.format(pattern, fn.fnamemodify(item.filename, ':.'),
                          item.lnum, item.col, item.text)
  return s
end

local function lsp_to_vimgrep(results)
  local greps = {}
  for _, v in pairs(results) do
    if v.result then
      local items = lsp.util.locations_to_items(v.result, 'utf-8')
      if #items == 1 then
        return { gen_vimgrep("%s:%d:%d %s", items[1]) }
      else
        for _, item in pairs(items) do
          local s = gen_vimgrep(color_vimgrep, item)
          table.insert(greps, s)
        end
      end
    end
  end
  return greps
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
      vim.notify(method + 'not found')
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

local function symbols_to_vimgrep(results)
  local greps = ""
  for _, v in pairs(results) do
    if v.result then
      local symbols = lsp.util.symbols_to_items(v.result)
      for _, symbol in pairs(symbols) do
        greps = greps .. gen_vimgrep(color_vimgrep, symbol) .. '\n'
      end
    end
  end
  return greps
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
        a.await(a.uv.write(pipe, symbols_to_vimgrep(r)))
        a.await(a.uv.close(pipe))
      end
    end), 1000)
  end)

  local act = preview()..string.format([[ --bind "change:reload:%s {q}"]], ws_act)
  lsp_to_fzf({}, act)
end

return M
