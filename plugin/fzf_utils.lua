vim.cmd([[
  command! -complete=dir -nargs=+ FzfCommand lua require('fzf_utils.commands').load_command(<f-args>)
]])

local group = "fzf_utils"
vim.api.nvim_create_augroup(group, {clear= true})
vim.api.nvim_create_autocmd({"BufWinEnter"}, {
  callback = require('fzf_utils.mru').refresh_mru,
  group = group
})
