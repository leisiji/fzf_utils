command! -complete=dir -nargs=+ FzfCommand lua require('fzf_utils.commands').load_command(<f-args>)

augroup user_plugin
    autocmd!
    au BufWinEnter * lua require('fzf_utils.mru').refresh_mru()
augroup END
