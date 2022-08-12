local a = vim.api
a.nvim_create_user_command("FzfCommand", function(input)
  require("fzf_utils.commands").load(input.fargs)
end, {
  nargs = "+",
  complete = function(args)
    require("fzf_utils.commands").complete(args)
  end,
})

local group = "fzf_utils"
a.nvim_create_augroup(group, { clear = true })
a.nvim_create_autocmd({ "TabNew" }, {
  callback = function ()
    require("fzf_utils.mru").refresh_mru()
  end,
  group = group,
})
