-- mru is stored at ~/.cache/nvim/fzf_mru
-- every accessed file path is stored at each line
local M = {}
local fn = vim.fn
local a = require('plenary.async_lib')
local u = require('fzf_utils.utils')
local uv = a.uv
local mru = string.format('%s/%s', fn.stdpath('cache'), 'fzf_mru')
local fzf_mru_size = 64 * 1024
local lock = false

-- fzf_mru_mtime, fzf_mru_cache is for cache.
-- When 'fzf_mru' is modified in another vim, it should update the cache
local function add_file(f)
  a.async_void(function ()
    lock = true
    local data
    local res = f .. '\n'
    local i, p = 1, 1
    local _, fd = a.await(uv.fs_open(mru, 'r+', 438))
    local _, stat = a.await(uv.fs_fstat(fd))

    if vim.g.fzf_mru_mtime ~= stat.mtime.sec then
      _, data = a.await(uv.fs_read(fd, stat.size, 0))
    else
      data = vim.g.fzf_mru_cache
    end

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

    -- if file not found in mru, then check size and append
    if i > #data then
      i = fzf_mru_size - #data
      if i < #res then
        while string.sub(res, i, i) ~= '\n' do
          i = i - 1
          if i == 0 then
            vim.notify(string.format('Corrupted mru files: %s', mru))
            a.await(uv.fs_close(fd))
            lock = false
            return
          end
        end
        res = string.sub(res, 1, i) .. data
      else
        res = res .. data
      end
    end

    a.await(uv.fs_write(fd, res, 0))

    _, stat = a.await(uv.fs_fstat(fd))
    vim.g.fzf_mru_cache = res
    vim.g.fzf_mru_mtime = stat.mtime.sec
    a.await(uv.fs_close(fd))
    lock = false
  end)()
end

function M.refresh_mru()
  if lock then
    return
  end

  local f = fn.expand('%:p')
  if fn.filereadable(f) == 0 then
    return
  end

  if fn.filereadable(mru) == 0 then
    local file = io.open(mru, "a")
    io.close(file)
  end

  add_file(f)
end

function M.fzf_mru()
  coroutine.wrap(function ()
    local choices = require('fzf').fzf('cat ' .. mru, u.expect_key())
    if choices[1] == "ctrl-r" then
      os.remove(mru)
      vim.schedule(M.fzf_mru)
    else
      u.handle_key(choices[1], choices[2], nil, nil)
    end
  end)()
end

return M
