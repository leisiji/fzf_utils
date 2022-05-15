local a = vim.api
a.nvim_create_user_command("FzfCommand", function(input)
  require("fzf_utils.commands").load(input.fargs)
end, { nargs = "+", complete = "dir" })

local group = "fzf_utils"
a.nvim_create_augroup(group, { clear = true })
a.nvim_create_autocmd({ "TabEnter" }, {
  callback = require("fzf_utils.mru").refresh_mru,
  group = group,
})
