local M = {}
local lsp, fn = vim.lsp, vim.fn
local utils = require("fzf_utils.utils")
local a = require("plenary.async_lib")
local request = require("plenary.async_lib.lsp").buf_request_all

local function get_offset_encoding(bufnr)
  local client = vim.lsp.get_clients({ bufnr = bufnr })[1]
  return client and client.offset_encoding or "utf-16"
end

local function gen_vimgrep(item)
  local s = string.format(
    "\27[35m%s\27[0m:\27[32m%d\27[0m %s \27[30m %s:%d:%d\27[0m",
    vim.fs.basename(item.filename),
    item.lnum,
    item.text,
    fn.fnamemodify(item.filename, ":."),
    item.lnum,
    item.col
  )
  return s
end

local function highlight_word(text, word, col)
  local hi
  local ori = string.sub(text, col, col + #word - 1)
  if ori == word then
    hi = string.format("\27[31m%s\27[0m", word)
  else
    hi = ori
  end
  local res = string.sub(text, 1, col - 1) .. hi
  if col <= #text then
    -- remove space of head and tail
    res = res:gsub("^[%s]+", "") .. string.sub(text, col + #word):gsub("[%s]+$", "")
  end
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
          item.text = highlight_word(item.text, word, item.col)
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
    local bufnr = 0
    local params = lsp.util.make_position_params(0, get_offset_encoding(bufnr))
    params.context = { includeDeclaration = true }
    local r = a.await(request(bufnr, method, params))
    if r == nil then
      vim.notify(method .. "not found", vim.log.levels.INFO)
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

local function symbols_to_vimgrep(results, bufnr)
  local greps = ""
  for _, v in pairs(results) do
    if v.result then
      local offset_encoding = get_offset_encoding(bufnr)
      local symbols = lsp.util.symbols_to_items(v.result, bufnr, offset_encoding)
      for _, symbol in pairs(symbols) do
        greps = greps .. gen_vimgrep(symbol) .. "\n"
      end
    end
  end
  return greps
end

local function add_symbol(list, items)
  for _, item in pairs(items) do
    local col = item.range.start.line + 1
    list[#list + 1] = string.format("%d: %s \27[38;2;67;72;82m%s\27[0m", col, item.name, item.detail or "")
    -- function (kind=12) deeping skips, as function has local variables
    if item.children ~= nil and item.kind ~= 12 then
      add_symbol(list, item.children)
    end
  end
end

function M.document_symbol()
  a.async_void(function()
    local param = { textDocument = vim.lsp.util.make_text_document_params() }
    local results = a.await(request(0, "textDocument/documentSymbol", param))
    local symbols = {}

    for _, v in pairs(results) do
      if v.result then
        add_symbol(symbols, v.result)
      end
    end

    coroutine.wrap(function()
      local preview = require("fzf_utils.float_preview").get_preview_action
      local cur_file = fn.expand("%:p")
      local choices = require("fzf").fzf(symbols, preview(cur_file))
      utils.handle_key(choices[1], cur_file, utils.get_leading_num(choices[2]), fn.getcurpos()[3])
    end)()
  end)()
end

function M.workspace_symbol()
  local bufnr = fn.bufnr()
  coroutine.wrap(function()
    utils.fzf_live(function(query, pipe)
      local r = a.await(request(bufnr, "workspace/symbol", { query = query }))
      if r ~= nil then
        a.await(a.uv.write(pipe, symbols_to_vimgrep(r, bufnr)))
        a.await(a.uv.close(pipe))
      end
    end)
  end)()
end

return M
