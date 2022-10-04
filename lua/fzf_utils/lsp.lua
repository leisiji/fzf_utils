local M = {}
local lsp, fn = vim.lsp, vim.fn
local utils = require("fzf_utils.utils")
local a = require("plenary.async_lib")
local request = require("plenary.async_lib.lsp").buf_request_all

local function gen_vimgrep(item)
  local s = string.format(
    "\27[0;35m%s\27[0m:\27[0;32m%d\27[0m %s         \27[0;30m%s:%d:%d\27[0m",
    vim.fs.basename(item.filename),
    item.lnum,
    item.text,
    fn.fnamemodify(item.filename, ":."),
    item.lnum,
    item.col
  )
  return s
end

local function highlight_word(text, word)
  local len = string.len(text)
  local s = 1
  local e
  local last = 1
  local res = ""
  local hi = string.format("\27[0;31m%s\27[0m", word)
  while s <= len do
    s, e = string.find(text, word, s)
    if s ~= nil then
      res = res .. string.sub(text, last, s - 1) .. hi
    else
      break
    end
    s = e + 1
    last = s
  end
  res = res .. string.sub(text, last)
  return res
end

local function lsp_to_vimgrep(results, word)
  local greps = {}
  for _, v in pairs(results) do
    if v.result then
      local items = lsp.util.locations_to_items(v.result, "utf-8")
      if #items == 1 then
        local item = items[1]
        return { string.format("%s:%d:%d", fn.fnamemodify(item.filename, ":."), item.lnum, item.col) }
      else
        for _, item in pairs(items) do
          item.text = highlight_word(item.text, word)
          local s = gen_vimgrep(item)
          table.insert(greps, s)
        end
      end
    end
  end
  return greps
end

-- core function for finding def or ref
local function lsp_handle(ret, action)
  local preview = require("fzf_utils.float_preview").vimgrep_preview
  local word = fn.expand("<cword>")
  local res = lsp_to_vimgrep(ret, word)

  if #res == 1 then
    local c = utils.parse_vimgrep(res[1])
    utils.cmdedit(action, c[1], c[2], c[3])
  else
    coroutine.wrap(function()
      utils.vimgrep_fzf(res, preview(word))
    end)()
  end
end

local function lsp_async(method, action)
  a.async_void(function()
    local params = lsp.util.make_position_params(0, nil)
    params.context = { includeDeclaration = true }
    local r = a.await(request(0, method, params))
    if r == nil then
      vim.notify(method + "not found", vim.log.levels.INFO)
    else
      lsp_handle(r, action)
    end
  end)()
end

function M.jump_def(action)
  lsp_async("textDocument/definition", action or "edit")
end

function M.ref(action)
  lsp_async("textDocument/references", action or "edit")
end

local function symbols_to_vimgrep(results)
  local greps = ""
  for _, v in pairs(results) do
    if v.result then
      local symbols = lsp.util.symbols_to_items(v.result)
      for _, symbol in pairs(symbols) do
        greps = greps .. gen_vimgrep(symbol) .. "\n"
      end
    end
  end
  return greps
end

function M.workspace_symbol()
  local bufnr = fn.bufnr()
  coroutine.wrap(function()
    utils.fzf_live(function(query, pipe)
      local r = a.await(request(bufnr, "workspace/symbol", { query = query }))
      if r ~= nil then
        a.await(a.uv.write(pipe, symbols_to_vimgrep(r)))
        a.await(a.uv.close(pipe))
      end
    end)
  end)()
end

return M
