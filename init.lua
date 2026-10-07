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
vim.o.linebreak = true
vim.o.breakindent = true
vim.o.expandtab = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.completeopt = 'menuone,noinsert,popup,fuzzy'

vim.diagnostic.config({ virtual_text = true })

-- Re-balance splits in every tab when the terminal is resized (fixed-width
-- windows like the Diffview panel keep their width).
vim.api.nvim_create_autocmd('VimResized', {
  callback = function()
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      vim.api.nvim_win_call(vim.api.nvim_tabpage_get_win(tab), function() vim.cmd('wincmd =') end)
    end
  end,
})

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
  'https://github.com/folke/zen-mode.nvim',
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
    markdown = { 'prettier' },
  },
  default_format_opts = { lsp_format = 'fallback' },
  format_on_save = { timeout_ms = 2000 },
})
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

-- Git: Neogit for magit-style status/commits (uses diffview for full diffs),
-- gitsigns for hunks in the current file.
-- Neogit diff colours as doom-rose-pine styles Magit in ~/.emacs.d: foam/love
-- text on a faint tint, brighter and bold in the hunk under the cursor, dimmed
-- context, iris hunk headers. Neogit only fills in groups that aren't set, so
-- define them first and again on every colorscheme load.
local function magit_diff_colors()
  local p = require('rose-pine.palette')
  local function mix(a, b, alpha)
    local function ch(hex, i) return tonumber(hex:sub(i, i + 1), 16) end
    return ('#%02x%02x%02x'):format(unpack(vim.tbl_map(function(i)
      return math.floor(ch(a, i) * alpha + ch(b, i) * (1 - alpha) + 0.5)
    end, { 2, 4, 6 })))
  end
  local function darken(c, alpha) return mix(c, '#000000', 1 - alpha) end
  local hl = {
    NeogitDiffAdd = { fg = darken(p.foam, 0.2), bg = mix(p.foam, p.base, 0.1) },
    NeogitDiffAddHighlight = { fg = p.foam, bg = mix(p.foam, p.base, 0.2), bold = true },
    NeogitDiffDelete = { fg = darken(p.love, 0.2), bg = mix(p.love, p.overlay, 0.1) },
    NeogitDiffDeleteHighlight = { fg = p.love, bg = mix(p.love, p.overlay, 0.2), bold = true },
    NeogitDiffContext = { fg = darken(p.text, 0.4), bg = p.base },
    NeogitDiffContextHighlight = { fg = p.text, bg = p.surface },
    NeogitHunkHeader = { fg = p.base, bg = mix(p.iris, p.base, 0.3) },
    NeogitHunkHeaderHighlight = { fg = p.base, bg = p.iris, bold = true },
  }
  for group, spec in pairs(hl) do vim.api.nvim_set_hl(0, group, spec) end
end
magit_diff_colors()
vim.api.nvim_create_autocmd('ColorScheme', { callback = magit_diff_colors })

-- Neogit takes "green" from the String highlight, which is gold in rose-pine;
-- use foam for what's left (word-level highlights, cursor line).
require('neogit').setup({
  highlight = { green = require('rose-pine.palette').foam },
})
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

-- Review for the agent (lua/review.lua): in Diffview, ]c/[c walk every hunk
-- across all files, ediff-style; <leader>gc comments on the hunk (or the
-- visual selection), collected in <git-dir>/agent-review.md.
local review = require('review')
review.setup()
local hunk_keys = {
  { 'n', ']c', review.next_hunk, { desc = 'Next hunk (across files)' } },
  { 'n', '[c', review.prev_hunk, { desc = 'Previous hunk (across files)' } },
  { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close Diffview' } },
}
require('diffview').setup({
  keymaps = { view = hunk_keys, file_panel = hunk_keys, file_history_panel = hunk_keys },
})
vim.keymap.set('n', '<leader>gc', review.comment, { desc = 'Review: comment on hunk' })
vim.keymap.set('x', '<leader>gc', review.comment_visual, { desc = 'Review: comment on selection' })
vim.keymap.set('n', '<leader>gC', review.open, { desc = 'Review: edit comments' })
vim.keymap.set('n', '<leader>gy', review.yank, { desc = 'Review: copy comments' })
vim.keymap.set('n', '<leader>gl', review.diff_commits, { desc = 'Diff commits (pick)' })

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

-- Reading/writing: the buffer alone in a centred float, 100 columns of text
-- plus the line-number gutter.
require('zen-mode').setup({
  window = {
    width = function()
      return 100 + math.max(vim.o.numberwidth, #tostring(vim.fn.line('$')) + 1)
    end,
    options = { signcolumn = 'no' },
  },
})
vim.keymap.set('n', '<leader>z', '<cmd>ZenMode<cr>', { desc = 'Zen mode' })

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
