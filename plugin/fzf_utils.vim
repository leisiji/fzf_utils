command! -complete=dir -nargs=+ FzfCommand lua require('fzf_utils.commands').load_command(<f-args>)
