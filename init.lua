vim.g.mapleader = ' '

-- Experimental message/cmdline UI (Nvim 0.12)
require('vim._core.ui2').enable({})

vim.o.termguicolors = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.scrolloff = 10
vim.o.signcolumn = 'yes'
vim.o.undofile = true
vim.o.clipboard = 'unnamedplus'
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.completeopt = 'menuone,noinsert,popup,fuzzy'

vim.diagnostic.config({ virtual_text = true })

-- Plugins --------------------------------------------------------------------

-- Parsers must match nvim-treesitter's queries, so rebuild them after it updates.
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    if ev.data.spec.name == 'nvim-treesitter' and ev.data.kind == 'update' then
      require('nvim-treesitter').update()
    end
  end,
})

vim.pack.add({
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
  'https://github.com/ibhagwan/fzf-lua',
  'https://github.com/stevearc/conform.nvim',
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/NeogitOrg/neogit',
  'https://github.com/sindrets/diffview.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/stevearc/oil.nvim',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/nvim-mini/mini.ai',
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'main' },
  'https://github.com/nvim-orgmode/orgmode',
  { src = 'https://github.com/rose-pine/neovim', name = 'rose-pine' },
  'https://github.com/folke/flash.nvim',
  'https://github.com/nvim-mini/mini.icons',
})

-- Icons for fzf-lua, oil, which-key; the devicons shim covers diffview.
require('mini.icons').setup({})
MiniIcons.mock_nvim_web_devicons()

vim.cmd.colorscheme('rose-pine')

-- Treesitter: Nvim ships the engine and a few parsers (c, lua, vim, vimdoc,
-- query, markdown); nvim-treesitter compiles the rest (needs `tree-sitter` CLI).
local ts_parsers = {
  'go', 'gomod', 'gosum', 'gowork',
  'rust', 'toml',
  'python',
  'javascript', 'typescript', 'tsx', 'json',
  'nix',
  'rego',
  'roc',
}
-- nvim-treesitter pins tree-sitter-roc from before the new (Zig compiler)
-- syntax; use upstream with its own Neovim queries instead.
vim.api.nvim_create_autocmd('User', {
  pattern = 'TSUpdate',
  callback = function()
    require('nvim-treesitter.parsers').roc = {
      install_info = {
        url = 'https://github.com/faldor20/tree-sitter-roc',
        revision = '2760de95b87004ed537151f2467377a6ddafdef0',
        queries = 'queries-generated/neovim/queries',
      },
    }
  end,
})
if vim.fn.executable('tree-sitter') == 1 then
  require('nvim-treesitter').install(ts_parsers)
end
vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
})

-- Fuzzy finder
local fzf = require('fzf-lua')
fzf.setup({})
vim.keymap.set('n', '<leader><leader>', fzf.files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>f', fzf.files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>/', fzf.live_grep, { desc = 'Grep' })
vim.keymap.set('n', '<leader>b', fzf.buffers, { desc = 'Buffers' })
vim.keymap.set('n', '<leader>h', fzf.helptags, { desc = 'Help' })
vim.keymap.set('n', '<leader>d', fzf.diagnostics_workspace, { desc = 'Diagnostics' })
vim.keymap.set('n', '<leader>s', fzf.lsp_live_workspace_symbols, { desc = 'Workspace symbols' })
vim.keymap.set('n', '<leader>r', fzf.resume, { desc = 'Resume last picker' })

-- Formatting: prettier for JS/TS (no LSP for it), every other language
-- formats through its LSP server. Runs on save.
require('conform').setup({
  formatters_by_ft = {
    javascript = { 'prettier' },
    javascriptreact = { 'prettier' },
    typescript = { 'prettier' },
    typescriptreact = { 'prettier' },
    json = { 'prettier' },
  },
  default_format_opts = { lsp_format = 'fallback' },
  format_on_save = { timeout_ms = 2000 },
})
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

-- Git: Neogit for magit-style status/commits (uses diffview for full diffs),
-- gitsigns for hunks in the current file.
require('neogit').setup({})
local gs = require('gitsigns')
gs.setup({})
vim.keymap.set('n', '<leader>gg', '<cmd>Neogit<cr>', { desc = 'Neogit' })
vim.keymap.set('n', '<leader>gd', '<cmd>DiffviewOpen<cr>', { desc = 'Diff working tree' })
vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', { desc = 'File history' })
vim.keymap.set('n', '<leader>gs', gs.stage_hunk, { desc = 'Stage/unstage hunk' })
vim.keymap.set('n', '<leader>gr', gs.reset_hunk, { desc = 'Reset hunk' })
vim.keymap.set('n', '<leader>gp', gs.preview_hunk_inline, { desc = 'Preview hunk' })
vim.keymap.set('n', '<leader>gb', gs.blame_line, { desc = 'Blame line' })
vim.keymap.set('n', ']h', function() gs.nav_hunk('next') end, { desc = 'Next hunk' })
vim.keymap.set('n', '[h', function() gs.nav_hunk('prev') end, { desc = 'Previous hunk' })

-- Files: edit directories as buffers (replaces netrw). `-` opens the parent dir.
require('oil').setup({})
vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Open parent directory' })

-- Undo tree (ships with Nvim, opt-in)
vim.cmd.packadd('nvim.undotree')
vim.keymap.set('n', '<leader>u', '<cmd>Undotree<cr>', { desc = 'Undo tree' })

-- Textobjects. Built in: an/in (treesitter node). mini.ai adds a/i for
-- brackets, quotes, args (a), function calls (f), tags (t); F and c use the
-- treesitter queries from nvim-treesitter-textobjects.
local ai = require('mini.ai')
ai.setup({
  custom_textobjects = {
    F = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
    c = ai.gen_spec.treesitter({ a = '@class.outer', i = '@class.inner' }),
  },
})

-- Org
require('orgmode').setup({
  org_agenda_files = '~/notes/*.org',
  org_default_notes_file = '~/notes/inbox.org',
})

-- Jump: `s` + any chars, then the label. Also adds labels/repeat to f/t/F/T.
require('flash').setup({})
vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = 'Flash jump' })

-- Key hints
require('which-key').setup({})
require('which-key').add({
  { '<leader>g', group = 'git' },
  { '<leader>o', group = 'org' },
})

-- LSP ------------------------------------------------------------------------
-- Server configs live in lsp/<name>.lua. Default keymaps: K, grn, gra, grr,
-- gri, grt, gO, [d ]d, i_CTRL-S. See :h lsp-defaults.

vim.lsp.enable({
  'gopls',
  'rust_analyzer',
  'basedpyright',
  'ruff',
  'tsgo',
  'oxlint',
  'roc',
  'nixd',
  'regal',
})

vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = 'Go to definition' })

-- Completion only on demand: <C-Space> opens the menu, <C-y> accepts.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = false })
    end
  end,
})
vim.keymap.set('i', '<C-Space>', vim.lsp.completion.get, { desc = 'Complete' })
