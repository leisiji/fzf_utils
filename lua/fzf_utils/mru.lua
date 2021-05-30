-- mru is stored at ~/.cache/nvim/fzf_mru
-- every accessed file path is stored at each line
local M = {}
local fn = vim.fn
local a = require('plenary.async_lib')
local u = require('fzf_utils.utils')
local mru = string.format('%s/%s', fn.stdpath('cache'), 'fzf_mru')
local fzf_mru_size = 64 * 1024

function M.refresh_mru()
  if fn.filereadable(mru) == 0 then
    local file = io.open(mru, "a")
    io.close(file)
  end

  local f = fn.expand('%:p')
  if fn.filereadable(f) == 0 then
    return
  end

  a.async_void(function ()
    local res = f .. '\n'
    local i, p = 1, 1
    local data = a.await(u.readfile(mru))

    while i <= #data do
      if string.sub(data, i, i) == '\n' then
        if string.sub(data, p, i - 1) == f then
          res = res .. string.sub(data, 1, p - 1) .. string.sub(data, i + 1, #data)
          break
        end
        p = i + 1
      end
      i = i + 1
    end

    if i > #data then
      res = res .. data
    end

    if #res > fzf_mru_size then
      i = fzf_mru_size
      while string.sub(res, i, i) ~= '\n' do
        i = i - 1
      end
      res = string.sub(res, 1, i)
    end

    a.await(u.writefile(mru, res))
  end)()
end

function M.fzf_mru()
  coroutine.wrap(function ()
    local choices = require('fzf').fzf('cat ' .. mru, u.expect_key)
    if choices[1] == "ctrl-r" then
      os.remove(mru)
      vim.schedule(M.fzf_mru)
    else
      u.handle_key(choices[1], choices[2], nil, nil)
    end
  end)()
end

return M
