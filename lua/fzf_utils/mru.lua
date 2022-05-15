-- mru is stored at ~/.cache/nvim/fzf_mru
-- every accessed file path is stored at each line
local M = {}
local fn = vim.fn
local a = require('plenary.async_lib')
local u = require('fzf_utils.utils')
local uv = a.uv
local fzf_mru = {
  mtime = 0,
  cache = "",
  nums = 1024,
  lock = false,
  file = string.format('%s/%s', fn.stdpath('cache'), 'fzf_mru')
}

-- fzf_mru_mtime, fzf_mru_cache is for cache.
-- When 'fzf_mru' is modified in another vim, it should update the cache
local function add_file(f)
  a.async_void(function ()
    fzf_mru.lock = true
    local data
    local res = f .. '\n'
    local i, p = 1, 1
    local _, fd = a.await(uv.fs_open(fzf_mru.file, 'r+', 438))
    local _, stat = a.await(uv.fs_fstat(fd))
    local nums = 0

    if fzf_mru.mtime ~= stat.mtime.sec then
      _, data = a.await(uv.fs_read(fd, stat.size, 0))
    else
      data = fzf_mru.cache
    end

    while i <= #data do
      if string.sub(data, i, i) == '\n' then
        if string.sub(data, p, i - 1) == f then
          res = res .. string.sub(data, 1, p - 1) .. string.sub(data, i + 1, #data)
          break
        end
        p = i + 1
        nums = nums + 1
      end
      i = i + 1
    end

    -- if file not found in mru, then check nums and append
    if i > #data then
      if nums > fzf_mru.nums then
        local oversize = nums - fzf_mru.nums
        local j = #data
        while oversize > 0 do
          j = j - 1
          if string.sub(data, j, j) == '\n' then
            oversize = oversize - 1
          end
        end
        res = res .. string.sub(data, 1, j)
      else
        res = res .. data
      end
    end

    a.await(uv.fs_write(fd, res, 0))
    a.await(uv.fs_ftruncate(fd, #res))

    _, stat = a.await(uv.fs_fstat(fd))
    fzf_mru.cache = res
    fzf_mru.mtime = stat.mtime.sec
    a.await(uv.fs_close(fd))
    fzf_mru.lock = false
  end)()
end

function M.refresh_mru()
  if fzf_mru.lock then
    return
  end

  vim.defer_fn(function ()
    local f = fn.expand('%:p')
    if fn.filereadable(f) == 0 then
      return
    end

    if fn.filereadable(fzf_mru.file) == 0 then
      local file = io.open(fzf_mru.file, "a")
      io.close(file)
    end

    add_file(f)
  end, 500)

end

function M.fzf_mru()
  coroutine.wrap(function ()
    local choices = require('fzf').fzf('cat ' .. fzf_mru.file, u.expect_key())
    if choices[1] == "ctrl-r" then
      os.remove(fzf_mru.file)
      vim.schedule(M.fzf_mru)
    else
      u.handle_key(choices[1], choices[2], nil, nil)
    end
  end)()
end

return M
