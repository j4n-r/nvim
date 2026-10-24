-- Lua here is Neovim config: LuaJIT, plus the runtime's vim.* sources so K and
-- gd work on the API. Formatting stays off so saving doesn't reindent files.
return {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = {
        checkThirdParty = false,
        library = { vim.env.VIMRUNTIME },
      },
      format = { enable = false },
    },
  },
}
