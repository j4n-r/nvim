vim.g.mapleader = ' '

-- Clearing our group keeps :source $MYVIMRC from duplicating callbacks.
local config_group = vim.api.nvim_create_augroup('user_config', { clear = true })

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

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<cr>', { desc = 'Clear search highlight' })

-- Command-line completion like vertico: fuzzy matches pop up as you type
-- (see :h cmdline-autocompletion); <Tab>/<S-Tab> pick, nothing is inserted
-- until then. The menu is nearly always open, so the arrows close it first:
-- <Up>/<Down> walk history, <Left>/<Right> move the cursor.
vim.o.wildmode = 'noselect:lastused,full'
vim.o.wildoptions = 'pum,fuzzy'
vim.o.pumheight = 12
vim.api.nvim_create_autocmd('CmdlineChanged', {
  group = config_group,
  pattern = { ':', '/', '?' },
  callback = function() vim.fn.wildtrigger() end,
})
for _, key in ipairs({ '<Up>', '<Down>', '<Left>', '<Right>' }) do
  vim.keymap.set('c', key, function()
    return vim.fn.wildmenumode() == 1 and '<C-e>' .. key or key
  end, { expr = true })
end

-- Only errors are underlined: lints like clippy's span whole blocks, and a
-- multi-line underline squiggles every line including indentation.
-- ]d/[d show the diagnostic they land on in a float, like <C-w>d.
vim.diagnostic.config({
  virtual_text = true,
  underline = { severity = vim.diagnostic.severity.ERROR },
  jump = {
    on_jump = function(diagnostic, bufnr)
      if not diagnostic then return end
      vim.diagnostic.open_float({ bufnr = bufnr, scope = 'cursor', focus = false })
    end,
  },
})

-- Re-balance splits in every tab when the terminal is resized (fixed-width
-- windows like the Diffview panel keep their width).
vim.api.nvim_create_autocmd('VimResized', {
  group = config_group,
  callback = function()
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      vim.api.nvim_win_call(vim.api.nvim_tabpage_get_win(tab), function() vim.cmd('wincmd =') end)
    end
  end,
})

-- Reload files changed outside Nvim (agents, git) when coming back to Nvim,
-- switching buffers, or idling; 'autoread' alone only checks on some events.
-- A buffer with unsaved edits isn't overwritten, Nvim asks instead.
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
  group = config_group,
  callback = function()
    if vim.fn.getcmdwintype() == '' then vim.cmd.checktime() end
  end,
})

-- Help opens as a right-hand panel sized to its 78-column text instead of a
-- half-screen horizontal split; next to an empty [No Name] it takes the tab.
-- Help shown in a float (e.g. by a plugin) is left alone.
local function is_empty_buffer(buf)
  return vim.bo[buf].buftype == ''
    and vim.api.nvim_buf_get_name(buf) == ''
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''
end

vim.api.nvim_create_autocmd('BufWinEnter', {
  group = config_group,
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= 'help' then return end
    local help_window = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(help_window).relative ~= '' then return end
    local windows = vim.tbl_filter(function(win)
      return vim.api.nvim_win_get_config(win).relative == ''
    end, vim.api.nvim_tabpage_list_wins(0))
    local other_window = windows[1] == help_window and windows[2] or windows[1]
    if #windows == 2 and is_empty_buffer(vim.api.nvim_win_get_buf(other_window)) then
      vim.cmd.only()
    else
      vim.cmd.wincmd('L')
      local gutter_width = vim.fn.getwininfo(help_window)[1].textoff
      vim.cmd.resize({ 80 + gutter_width, mods = { vertical = true } })
      -- Keep the width when VimResized runs `wincmd =`.
      vim.wo[help_window].winfixwidth = true
    end
  end,
})

-- Plugins --------------------------------------------------------------------

-- Parsers must match nvim-treesitter's queries, so rebuild them after it updates.
vim.api.nvim_create_autocmd('PackChanged', {
  group = config_group,
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
  { src = 'https://github.com/rose-pine/neovim', name = 'rose-pine' },
  'https://github.com/folke/flash.nvim',
  'https://github.com/nvim-mini/mini.icons',
  'https://github.com/folke/zen-mode.nvim',
  'https://github.com/folke/snacks.nvim',
})

-- Icons for fzf-lua, oil, which-key; the devicons shim covers diffview.
require('mini.icons').setup({})
MiniIcons.mock_nvim_web_devicons()

vim.cmd.colorscheme('rose-pine')

-- Images (Kitty graphics, e.g. Ghostty): opening a .png shows it in the buffer.
require('snacks').setup({ image = { enabled = true } })

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
  group = config_group,
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
  group = config_group,
  callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
})

-- Fuzzy finder
local fzf = require('fzf-lua')
fzf.setup({})
-- Every vim.ui.select prompt (code actions, LSP choices, plugins) goes through
-- fzf-lua, like completing-read through vertico.
fzf.register_ui_select()
vim.keymap.set('n', '<leader><leader>', fzf.files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>/', fzf.live_grep, { desc = 'Grep' })
vim.keymap.set('n', '<leader>b', fzf.buffers, { desc = 'Buffers' })
-- Describe/help, like Emacs' C-h: <leader>h then a key.
vim.keymap.set('n', '<leader>hh', fzf.helptags, { desc = 'Help tags' })
vim.keymap.set('n', '<leader>hk', fzf.keymaps, { desc = 'Keymaps' })
vim.keymap.set('n', '<leader>hv', fzf.nvim_options, { desc = 'Options' })
vim.keymap.set('n', '<leader>hc', fzf.commands, { desc = 'Commands' })
vim.keymap.set('n', '<leader>ha', fzf.autocmds, { desc = 'Autocmds' })
vim.keymap.set('n', '<leader>hl', fzf.highlights, { desc = 'Highlight groups' })
vim.keymap.set('n', '<leader>hm', fzf.manpages, { desc = 'Man pages' })
vim.keymap.set('n', '<leader>hi', '<cmd>Inspect<cr>', { desc = 'Inspect highlight at cursor' })
vim.keymap.set('n', '<leader>hM', '<cmd>messages<cr>', { desc = 'Messages' })
vim.keymap.set('n', '<leader>d', fzf.diagnostics_workspace, { desc = 'Diagnostics' })
-- Search: <leader>s then a key.
vim.keymap.set('n', '<leader>sg', fzf.live_grep, { desc = 'Grep project' })
vim.keymap.set('n', '<leader>sw', fzf.grep_cword, { desc = 'Grep word under cursor' })
vim.keymap.set('n', '<leader>sb', fzf.blines, { desc = 'Lines in buffer' })
vim.keymap.set('n', '<leader>ss', fzf.lsp_document_symbols, { desc = 'Symbols in file' })
vim.keymap.set('n', '<leader>sS', fzf.lsp_live_workspace_symbols, { desc = 'Symbols in project' })
vim.keymap.set('n', '<leader>r', fzf.resume, { desc = 'Resume last picker' })

-- Format on save with Prettier for the filetypes below; otherwise use an
-- attached LSP formatter when available. Lua LSP formatting is disabled.
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
-- gq formats through conform, but falls back to Vim's own line wrapping where
-- no formatter runs (prose, commit messages, comments): conform's formatexpr
-- alone never hands back to it, so gq would do nothing there.
function _G.user_formatexpr()
  local formatters, lsp = require('conform').list_formatters_to_run(0)
  if #formatters == 0 and not lsp then return 1 end
  return require('conform').formatexpr()
end
vim.o.formatexpr = 'v:lua.user_formatexpr()'

-- Git: Neogit for magit-style status/commits (uses diffview for full diffs),
-- gitsigns for hunks in the current file.
-- Neogit diff colours as doom-rose-pine styles Magit in ~/.emacs.d: foam/love
-- text on a faint tint, brighter and bold in the hunk under the cursor, dimmed
-- context, iris hunk headers. Neogit only fills in groups that aren't set, so
-- define them first and again on every colorscheme load.
local function magit_diff_colors()
  -- The palette module picks its variant (main/moon/dawn) when first loaded;
  -- reload it so a switch to the light variant gets light tints.
  package.loaded['rose-pine.palette'] = nil
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
vim.api.nvim_create_autocmd('ColorScheme', { group = config_group, callback = magit_diff_colors })

-- Neogit takes "green" from the String highlight, which is gold in rose-pine;
-- use foam for what's left (word-level highlights, cursor line).
require('neogit').setup({
  highlight = { green = require('rose-pine.palette').foam },
})
local gs = require('gitsigns')
gs.setup({})
-- Like Magit, save the repo's modified files first so Neogit sees edits made
-- in buffers (e.g. by an LSP rename). Neogit opens the repo of the cwd, so
-- only files inside that repo are written; a buffer that fails is reported.
vim.keymap.set('n', '<leader>gg', function()
  local root = vim.fs.root(vim.uv.cwd(), '.git')
  for _, buf in ipairs(root and vim.api.nvim_list_bufs() or {}) do
    if vim.bo[buf].modified and vim.bo[buf].buftype == ''
      and vim.fs.relpath(root, vim.api.nvim_buf_get_name(buf)) then
      local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd('silent update') end)
      if not ok then vim.notify(err, vim.log.levels.WARN) end
    end
  end
  vim.cmd('Neogit')
end, { desc = 'Save repo files, Neogit' })
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
  -- Keep <leader>b as the buffer picker; <leader>e still focuses the files.
  { 'n', '<leader>b', false },
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

-- Textobjects. Built in: an/in in Visual mode grow/shrink the selection by
-- treesitter node. mini.ai adds a/i for args (a), function calls (f), tags
-- (t), any bracket (b) or quote (q); F and c use the treesitter queries from
-- nvim-treesitter-textobjects. Its "next" variants move to aN/iN so they don't
-- replace the built-in an/in.
local ai = require('mini.ai')
ai.setup({
  mappings = { around_next = 'aN', inside_next = 'iN' },
  custom_textobjects = {
    F = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
    c = ai.gen_spec.treesitter({ a = '@class.outer', i = '@class.inner' }),
  },
})

-- Jump: `s` + any chars, then the label. Also adds labels/repeat to f/t/F/T.
-- f/t/F/T: after the char, the nearest matches get number labels to jump to
-- directly; f/; still step to the next match.
require('flash').setup({
  modes = { char = { jump_labels = true, labels = '123456789' } },
})
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

-- Obsidian: show the current file in the running app, in a new tab. For a
-- note, the URI's path finds the vault; everything but unreserved chars and /
-- is encoded (vim.uri_encode leaves & and = alone, which would end the query
-- value). Any other file opens in the ~/vault window like "Open file from
-- outside the vault...": the CLI resolves a file:<absolute path> to it.
local obsidian_vaults = { vim.fs.normalize('~/vault'), vim.fs.normalize('~/arrivo/Arrivo') }
vim.keymap.set('n', '<leader>oo', function()
  local file = vim.api.nvim_buf_get_name(0)
  local stat = vim.bo.buftype == '' and vim.uv.fs_stat(file)
  if not (stat and stat.type == 'file') then
    vim.notify('Not a saved file', vim.log.levels.WARN)
    return
  end
  local in_vault = vim.iter(obsidian_vaults):any(function(vault)
    return vim.fs.relpath(vault, file) ~= nil
  end)
  if not in_vault then
    -- The CLI reports errors on stdout and still exits 0.
    vim.system({ 'obsidian', 'vault=vault', 'open', 'path=file:' .. file, 'newtab' }, { text = true },
      function(res)
        local out = vim.trim((res.stdout or '') .. (res.stderr or ''))
        if res.code ~= 0 or out:match('^Error') then
          vim.schedule(function() vim.notify('Obsidian: ' .. out, vim.log.levels.ERROR) end)
        end
      end)
    return
  end
  local path = file:gsub('[^%w%-._~/]', function(c) return ('%%%02X'):format(c:byte()) end)
  local _, err = vim.ui.open('obsidian://open?paneType=tab&path=' .. path)
  if err then vim.notify(err, vim.log.levels.ERROR) end
end, { desc = 'Open file in Obsidian' })

-- Windows: <leader>w is <C-w>, so every built-in window command works after it.
vim.keymap.set('n', '<leader>w', '<C-w>', { remap = true, desc = 'Window' })

-- Key hints
-- Popup only after a pause, so keys typed fluently don't flash it.
require('which-key').setup({ delay = 400 })
require('which-key').add({
  { '<leader>g', group = 'git' },
  { '<leader>h', group = 'help' },
  { '<leader>s', group = 'search' },
  { '<leader>o', group = 'obsidian' },
})

-- LSP ------------------------------------------------------------------------
-- Server configs live in lsp/<name>.lua. Default keymaps: K, grn, gra, grr,
-- gri, grt, grx, gO, i_CTRL-S, and <C-]> to the definition (via 'tagfunc').
-- See :h lsp-defaults. Diagnostics: ]d [d ]D [D <C-w>d, :h default-mappings.

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
  'lua_ls',
})

-- Completion only on demand: <C-Space> opens the menu, <C-y> accepts.
-- gd goes to the LSP definition only where a server provides one; elsewhere
-- it keeps Vim's own gd (local declaration).
vim.api.nvim_create_autocmd('LspAttach', {
  group = config_group,
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = false })
    end
    if client:supports_method('textDocument/definition') then
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = ev.buf, desc = 'Go to definition' })
    end
  end,
})
vim.keymap.set('i', '<C-Space>', vim.lsp.completion.get, { desc = 'Complete' })
