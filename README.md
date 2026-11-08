# Neovim configuration

Requires Neovim 0.12 or newer. The configuration uses `vim.pack`, the bundled
undo tree, and the experimental `vim._core.ui2` message UI.

`init.lua` contains editor settings, plugin declarations, setup, and keymaps in
load order. `lsp/` holds one configuration per language server. `lua/review.lua`
implements Git review comments and navigation across Diffview files.

Plugins are installed automatically by `vim.pack`; revisions are recorded in
`nvim-pack-lock.json`. Update them with `:lua vim.pack.update()`. Treesitter
parsers are installed when `tree-sitter` is available and updated after the
Treesitter plugin changes; building them also requires a C compiler and Git/curl.

External programs must come from your system or project environment:

- Pickers and Git tools: `fzf`, `rg`, and `git`.
- Formatting: `prettier` for JavaScript, TypeScript, JSON, and Markdown;
  otherwise an attached LSP formatter is used when available. Lua formatting is
  deliberately disabled.
- Language servers: `gopls`, `rust-analyzer`, `basedpyright-langserver`, `ruff`,
  TypeScript 7's native `tsc`, `roc`, `nixd`, `regal`, and `lua-language-server`.
  Nix formatting also requires `nixfmt`.
- Oxlint runs only in projects with `.oxlintrc.json`, using the project's
  `node_modules/.bin/oxlint` or `oxlint` on PATH. The TypeScript server prefers a
  project-local `tsc` when its version is 7 or newer.
- Clipboard support needs a provider appropriate for your desktop, such as
  `wl-copy`/`wl-paste` on Wayland.

Use `:checkhealth vim.lsp` and `:ConformInfo` to inspect language support.

Space is the leader. The keymaps and their descriptions live beside each
plugin's setup; pause after a prefix to see which-key hints. `<leader>h` groups
help pickers, `<leader>g` groups Git commands, and `<leader>w` prefixes native
window commands.

Review comments are stored per worktree in `<git-dir>/agent-review.md`.
`<leader>gc` comments on a hunk or visual selection; `<leader>gC` opens the
comments, `<leader>gy` copies them, and `:ReviewClear` deletes them after a
confirmation. Comments in Diffview require a two-way layout. `<leader>gl` picks
commits to compare; selecting several includes the changes between them.
