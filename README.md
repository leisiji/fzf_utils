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
- [bat](https://github.com/sharkdp/bat)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [fd-find](https://github.com/sharkdp/fd)
- [fzf >= 0.30.0](https://github.com/junegunn/fzf)

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
FzfCommand --live_grep [path]

" Lsp provide default jump action, if there is only one result.
" If there are multiple results, it will first display the results in fzf.
FzfCommand --lsp jump_def edit
FzfCommand --lsp jump_def tab drop
FzfCommand --lsp jump_def vsplit
FzfCommand --lsp ref tab drop
FzfCommand --lsp workspace_symbol

" mru
FzfCommand --mru
```

## Inspiration

- [LeaderF](https://github.com/Yggdroot/LeaderF)
- [nvim-fzf-commands](https://github.com/vijaymarupudi/nvim-fzf-commands)
- [OneTerm.nvim](https://github.com/LoricAndre/OneTerm.nvim)
