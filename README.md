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
- git commit

## Dependency

- [nvim-fzf](https://github.com/vijaymarupudi/nvim-fzf)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [bat](https://github.com/sharkdp/bat)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [fd-find](https://github.com/sharkdp/fd)
- [fzf >= 0.30.0](https://github.com/junegunn/fzf)
- [diffview.nvim](https://github.com/sindrets/diffview.nvim)

## Usage

Example:

```vim
FzfCommand --files
FzfCommand --lines
FzfCommand --ctags
FzfCommand --buffers
FzfCommand --man
FzfCommand --commit " support preview and open commit in diffview.nvim

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
FzfCommand --lsp document_symbol

" mru
FzfCommand --mru
```

prefer using `document_symbol`

```lua
vim.keymap.set("n", "<C-r>", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_active_clients({ bufnr = bufnr })
  if client ~= nil and #client ~= 0 then
    vim.cmd("FzfCommand --lsp document_symbol")
  else
    vim.cmd("FzfCommand --ctags")
  end
end, { noremap = true, silent = true })
```

Although the preview is neovim's float window, but it still uses `FZF_DEFAULT_OPTS` to configure:

```bash
# place this in .bashrc or .zshrc
export FZF_DEFAULT_OPTS='--ansi --reverse --cycle --preview-window=hidden:65%'
```

## Inspiration

- [LeaderF](https://github.com/Yggdroot/LeaderF)
- [nvim-fzf-commands](https://github.com/vijaymarupudi/nvim-fzf-commands)
- [OneTerm.nvim](https://github.com/LoricAndre/OneTerm.nvim)
- [nnn.nvim](https://github.com/luukvbaal/nnn.nvim)
