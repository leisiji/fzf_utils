# fzf_utils

A [nvim-fzf](https://github.com/vijaymarupudi/nvim-fzf) plugin that provides:

- ctags symbol
- gtags
- find files
- rg search
- lsp definitino/references
- mru
- vim: help, command history, filetypes
- man
- buffers

## Dependency

- [nvim-fzf](https://github.com/vijaymarupudi/nvim-fzf)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Usage

Example:

```vim
FzfCommand --files
FzfCommand --lines
FzfCommand --ctags
FzfCommand --buffers
FzfCommand --man

" vim
FzfCommand --vim help
FzfCommand --vim cmdHists
FzfCommand --vim filetypes

" gtags
FzfCommand --gtags -d {word} " definition
FzfCommand --gtags -r {word} " references
FzfCommand --gtags --update

" rg
FzfCommand --rg --all-buffers {word}
FzfCommand --rg {word} [path]

" Lsp provide default jump action, if there is only one result.
" If there are multiple results, it will first display the results in fzf.
FzfCommand --lsp jump_def edit
FzfCommand --lsp jump_def tab drop
FzfCommand --lsp jump_def vsplit
FzfCommand --lsp ref tab drop

" mru
FzfCommand --mru
```

## Inspiration

- [LeaderF](https://github.com/Yggdroot/LeaderF)
- [nvim-fzf-commands](https://github.com/vijaymarupudi/nvim-fzf-commands)
