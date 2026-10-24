-- Review a diff hunk by hunk and leave comments for a coding agent.
--
-- Comments are appended to <git-dir>/agent-review.md: outside the worktree, so
-- they never get committed, and one file per worktree. Hand them over with
-- :ReviewYank (clipboard) or point the agent at the file.
local M = {}

local ns = vim.api.nvim_create_namespace('review')
local PREAMBLE = '# Review comments\n\n'
  .. 'Line numbers refer to the new version of each file unless marked (old).\n'

local function diffview(win)
  local ok, lib = pcall(require, 'diffview.lib')
  if not ok then return nil end
  local tab = win and vim.api.nvim_win_get_tabpage(win) or vim.api.nvim_get_current_tabpage()
  return lib.tabpage_to_view(tab)
end

-- The other window of a two-way diff in this tabpage.
local function diff_partner(win)
  if not vim.wo[win].diff then return nil end
  local partner
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win))) do
    if w ~= win and vim.wo[w].diff then
      if partner then return nil end -- A three-way merge has no unambiguous pair.
      partner = w
    end
  end
  return partner
end

-- Where the buffer in `win` comes from: repo root, path relative to it, and
-- side ('a' = old, 'b' = new).
local function locate(win)
  local view = diffview(win)
  if view and view.cur_layout then
    for _, w in ipairs(view.cur_layout.windows) do
      if w.id == win and w.file then
        if #view.cur_layout.windows ~= 2 then return nil end
        local side = w.file.symbol == 'a' and 'a' or 'b'
        return { root = view.adapter.ctx.toplevel, path = w.file.path, side = side }
      end
    end
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  local root = vim.bo[buf].buftype == '' and name ~= '' and vim.fs.root(buf, '.git')
  if not root then return nil end
  -- Plain :diffsplit: treat the left (or, split horizontally, the top) window
  -- as the old side.
  local side = 'b'
  local partner = diff_partner(win)
  if partner then
    local mine, theirs = vim.fn.win_screenpos(win), vim.fn.win_screenpos(partner)
    if mine[2] < theirs[2] or (mine[2] == theirs[2] and mine[1] < theirs[1]) then side = 'a' end
  end
  return { root = root, path = vim.fs.relpath(root, name) or name, side = side }
end

local function current_root()
  local loc = locate(vim.api.nvim_get_current_win())
  if loc then return loc.root end
  local view = diffview()
  if view then return view.adapter.ctx.toplevel end
  return vim.fs.root(0, '.git') or vim.fs.root(vim.fn.getcwd(), '.git')
end

-- Git dir per repo root; false when git refuses (e.g. safe.directory), so it
-- isn't asked again on every BufWinEnter.
local git_dirs = {}
local function review_file(root)
  if git_dirs[root] == nil then
    local out = vim.system({ 'git', '-C', root, 'rev-parse', '--absolute-git-dir' }, { text = true }):wait()
    git_dirs[root] = out.code == 0 and vim.trim(out.stdout)
  end
  return git_dirs[root] and git_dirs[root] .. '/agent-review.md' or nil
end

-- Comment anchors, parsed back out of the review file's headings.
local function anchors(file)
  local res = {}
  local f = file and io.open(file)
  if not f then return res end
  local fence_length
  for line in f:lines() do
    local fence = line:match('^(```+)')
    if fence then
      if not fence_length then
        fence_length = #fence
      elseif #fence >= fence_length and line:match('^`+%s*$') then
        fence_length = nil
      end
    elseif not fence_length then
      local path, lnum, rest = line:match('^## (.-):(%d+)(.*)$')
      if path and tonumber(lnum) >= 1 then
        local side = rest:find('(old)', 1, true) and 'a' or 'b'
        res[#res + 1] = { path = path, lnum = tonumber(lnum), side = side }
      end
    end
  end
  f:close()
  return res
end

local function decorate(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  local buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local loc = locate(win)
  if not loc then return end
  local count = vim.api.nvim_buf_line_count(buf)
  for _, a in ipairs(anchors(review_file(loc.root))) do
    if a.path == loc.path and a.side == loc.side and a.lnum <= count then
      vim.api.nvim_buf_set_extmark(buf, ns, a.lnum - 1, 0, {
        virt_text = { { '  ◆ review', 'DiagnosticHint' } },
      })
    end
  end
end

local function decorate_tab()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do decorate(w) end
end

local function decorate_all_tabs()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do decorate(win) end
  end
end

-- Hunk of a two-way diff at line `lnum` of `side`, as unified diff lines.
-- Uses the same algorithm options as 'diffopt' so hunks match what's shown.
local function diff_hunk(old, new, lnum, side)
  local function text(t) return table.concat(t, '\n') .. '\n' end
  local diffopt = vim.o.diffopt
  local hunks = vim.text.diff(text(old), text(new), {
    result_type = 'indices',
    algorithm = diffopt:match('algorithm:(%a+)'),
    indent_heuristic = diffopt:find('indent-heuristic', 1, true) ~= nil,
    linematch = tonumber(diffopt:match('linematch:(%d+)')),
  })
  local function span(h)
    if side == 'a' then return h[1], h[2] end
    return h[3], h[4]
  end
  -- Prefer a hunk containing the line; a pure add/delete has no lines on one
  -- side and sits right after line `s` there.
  local hit
  for _, h in ipairs(hunks) do
    local s, c = span(h)
    if c > 0 and lnum >= s and lnum < s + c then hit = h break end
  end
  if not hit then
    for _, h in ipairs(hunks) do
      local s, c = span(h)
      if c == 0 and (lnum == s or lnum == s + 1) then hit = h break end
    end
  end
  if not hit then return nil end

  local sa, ca, sb, cb = unpack(hit)
  local lines = { ('@@ -%d,%d +%d,%d @@'):format(sa, ca, sb, cb) }
  for i = sa, sa + ca - 1 do lines[#lines + 1] = '-' .. old[i] end
  for i = sb, sb + cb - 1 do lines[#lines + 1] = '+' .. new[i] end
  local s, c = span(hit)
  return { first = math.max(s, 1), last = math.max(s + c - 1, s, 1), lines = lines }
end

-- Gitsigns hunk (buffer vs index) at `lnum`, for files outside a diff view.
local function gitsigns_hunk(buf, lnum)
  local ok, gs = pcall(require, 'gitsigns')
  for _, h in ipairs(ok and gs.get_hunks(buf) or {}) do
    local s, c = h.added.start, h.added.count
    if (c > 0 and lnum >= s and lnum < s + c) or (c == 0 and lnum == math.max(s, 1)) then
      return { first = math.max(s, 1), last = math.max(s + c - 1, s, 1), lines = { h.head, unpack(h.lines) } }
    end
  end
end

-- What a comment at the cursor (or on lines l1..l2) refers to.
local function target(l1, l2)
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local loc = locate(win)
  if not loc then return nil end

  local snippet
  if l1 then
    if l1 > l2 then l1, l2 = l2, l1 end
    snippet = { first = l1, last = l2, lang = vim.bo[buf].filetype,
      lines = vim.api.nvim_buf_get_lines(buf, l1 - 1, l2, false) }
  else
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    local partner = diff_partner(win)
    local hunk
    if partner then
      local mine = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local theirs = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(partner), 0, -1, false)
      if loc.side == 'a' then
        hunk = diff_hunk(mine, theirs, lnum, 'a')
      else
        hunk = diff_hunk(theirs, mine, lnum, 'b')
      end
    else
      hunk = gitsigns_hunk(buf, lnum)
    end
    if hunk then
      hunk.lang = 'diff'
      snippet = hunk
    else
      snippet = { first = lnum, last = lnum, lang = vim.bo[buf].filetype,
        lines = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false) }
    end
  end

  local label = loc.path .. ':' .. snippet.first
  if snippet.last > snippet.first then label = label .. '-' .. snippet.last end
  if loc.side == 'a' then label = label .. ' (old)' end
  return { root = loc.root, label = label, snippet = snippet }
end

-- Floating markdown buffer for a multi-line comment.
local function prompt(title, on_submit)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'markdown'
  local width = math.max(1, math.min(80, vim.o.columns - 4))
  local height = math.max(1, math.min(8, vim.o.lines - 4))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor', style = 'minimal', border = 'rounded',
    width = width, height = height,
    row = math.floor((vim.o.lines - height) / 2), col = math.floor((vim.o.columns - width) / 2),
    title = ' ' .. title .. ' ', footer = ' <C-s> save · q cancel ', footer_pos = 'right',
  })
  vim.wo[win].wrap = true
  vim.cmd.startinsert()

  local function submit()
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'))
    -- stopinsert takes effect after this returns, moving the cursor left one
    -- column; close the float only then so that lands here, not in the origin.
    vim.cmd.stopinsert()
    vim.schedule(function()
      vim.api.nvim_win_close(win, true)
      if text ~= '' then on_submit(text) end
    end)
  end
  vim.keymap.set({ 'n', 'i' }, '<C-s>', submit, { buffer = buf, desc = 'Save comment' })
  vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, desc = 'Cancel' })
end

--- Comment on the hunk under the cursor, or on lines l1..l2.
function M.comment(l1, l2)
  local view = diffview()
  if view and view.cur_layout and #view.cur_layout.windows ~= 2 then
    return vim.notify('review: comments require a two-way diff; select that layout first', vim.log.levels.WARN)
  end
  local t = target(l1, l2)
  if not t then
    return vim.notify('review: not a file in a git repo', vim.log.levels.WARN)
  end
  local file = review_file(t.root)
  if not file then return vim.notify('review: cannot find git directory', vim.log.levels.ERROR) end
  local origin = vim.api.nvim_get_current_win()
  prompt(t.label, function(text)
    -- A Markdown snippet may itself contain fenced code blocks.
    local fence = '```'
    for _, line in ipairs(t.snippet.lines) do
      for run in line:gmatch('`+') do
        if #run >= #fence then fence = string.rep('`', #run + 1) end
      end
    end
    local entry = { '', '## ' .. t.label, '', fence .. (t.snippet.lang or '') }
    vim.list_extend(entry, t.snippet.lines)
    vim.list_extend(entry, { fence, '', text, '' })
    local new = not vim.uv.fs_stat(file)
    local f, err = io.open(file, 'a')
    if not f then return vim.notify('review: ' .. err, vim.log.levels.ERROR) end
    if new then f:write(PREAMBLE) end
    f:write(table.concat(entry, '\n'))
    f:close()
    if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
    decorate_tab()
    vim.notify(('review: %d comment(s) in %s'):format(#anchors(file), file))
  end)
end

function M.comment_visual()
  local l1, l2 = vim.fn.line('v'), vim.fn.line('.')
  vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'nx', false)
  M.comment(l1, l2)
end

local function file_or_warn()
  local root = current_root()
  local file = root and review_file(root)
  if not file then vim.notify('review: not in a git repo', vim.log.levels.WARN) end
  return file
end

--- Open the review file to edit or delete comments.
function M.open()
  local file = file_or_warn()
  if not file then return end
  vim.cmd.split(vim.fn.fnameescape(file))
end

--- Copy all comments to the clipboard, ready to paste to the agent.
function M.yank()
  local file = file_or_warn()
  if not file then return end
  local f = io.open(file)
  if not f then return vim.notify('review: no comments yet') end
  local text = f:read('*a')
  f:close()
  vim.fn.setreg('+', text)
  vim.notify(('review: copied %d comment(s)'):format(#anchors(file)))
end

function M.clear()
  local file = file_or_warn()
  if not file then return end
  if not vim.uv.fs_stat(file) then return vim.notify('review: no comments') end
  if vim.fn.confirm('Delete all review comments?', '&Yes\n&No', 2) ~= 1 then return end
  local ok, err = os.remove(file)
  if not ok then return vim.notify('review: ' .. err, vim.log.levels.ERROR) end
  decorate_all_tabs()
  vim.notify('review: cleared')
end

--- Pick commits (<Tab> to mark several) and diff them in Diffview: one commit
--- shows just that commit, several show everything from the oldest through
--- the newest.
function M.diff_commits()
  local root = current_root()
  if not root then return vim.notify('review: not in a git repo', vim.log.levels.WARN) end

  local function git_output(args, stdin)
    local command = vim.list_extend({ 'git', '-C', root }, args)
    local result = vim.system(command, { text = true, stdin = stdin }):wait()
    if result.code ~= 0 then
      vim.notify('review: ' .. vim.trim(result.stderr or 'git failed'), vim.log.levels.ERROR)
      return nil
    end
    return vim.trim(result.stdout)
  end

  local function open_diff(revision)
    vim.cmd('DiffviewOpen -C=' .. vim.fn.fnameescape(root) .. ' ' .. revision)
  end

  require('fzf-lua').git_commits({
    cwd = root,
    prompt = 'Diff commits> ',
    fzf_opts = { ['--no-multi'] = false, ['--multi'] = true },
    actions = {
      ['enter'] = function(selected)
        if not selected or #selected == 0 then return end
        local shas = vim.tbl_map(function(s) return s:match('^%S+') end, selected)
        for _, sha in ipairs(shas) do
          if not sha:match('^%x+$') then
            return vim.notify('review: could not read selected commit', vim.log.levels.ERROR)
          end
        end
        if #shas == 1 then return open_diff(shas[1] .. '^!') end

        -- Topological order keeps children before parents even with skewed dates.
        local history = git_output(vim.list_extend({ 'log', '--topo-order', '--format=%H' }, shas))
        if not history then return end
        local sorted = {}
        for hash in history:gmatch('[^\n]+') do
          for _, sha in ipairs(shas) do
            if hash:sub(1, #sha) == sha then sorted[#sorted + 1] = hash break end
          end
          if #sorted == #shas then break end
        end
        if #sorted ~= #shas then return end

        local parents = git_output({ 'show', '-s', '--format=%P', sorted[#sorted] })
        if not parents then return end
        -- The initial commit has no parent: diff against the empty tree instead.
        local base = parents:match('^%S+') or git_output({ 'hash-object', '-t', 'tree', '--stdin' }, '')
        if base then open_diff(base .. '..' .. sorted[1]) end
      end,
    },
  })
end

-- Hunk navigation: ]c/[c that run on into the next/previous file of a
-- Diffview (wrapping around), like ediff's n/p.

local function in_change(lnum)
  return lnum >= 1 and vim.fn.diff_hlID(lnum, 1) ~= 0
end

local function first_change()
  vim.cmd('normal! gg')
  if not in_change(1) and vim.fn.diff_filler(1) == 0 then vim.cmd('normal! ]c') end
end

local function last_change()
  vim.cmd('normal! G')
  local last = vim.fn.line('$')
  -- Already at the start of the last change: [c would skip past it.
  if not (in_change(last) and not in_change(last - 1)) then vim.cmd('normal! [c') end
end

local function step(dir)
  local key = dir > 0 and ']c' or '[c'
  local before = vim.api.nvim_win_get_cursor(0)
  vim.cmd('normal! ' .. key)
  if not vim.wo.diff or not vim.deep_equal(before, vim.api.nvim_win_get_cursor(0)) then return end

  local land = dir > 0 and first_change or last_change
  local view = diffview()
  local win = vim.api.nvim_get_current_win()
  -- DiffView steps through files, FileHistoryView through commit entries.
  local move = view and (dir > 0 and (view.next_file or view.next_item) or (view.prev_file or view.prev_item))
  if not move then return land() end

  local function on_open()
    vim.schedule(function()
      if not (vim.api.nvim_win_is_valid(win) and vim.wo[win].diff) then
        win = view.cur_layout:get_main_win().id
      end
      vim.api.nvim_set_current_win(win)
      land()
      vim.cmd('normal! zz')
    end)
  end
  view.emitter:once('file_open_post', on_open)
  if not move(view) then
    -- Only one file: wrap within it.
    view.emitter:off(on_open, 'file_open_post')
    land()
  end
end

-- From the file panel, step from the diff window instead (Diffview leaves the
-- cursor in the panel when it opens).
local function step_from(dir)
  local view = diffview()
  if view and view.cur_layout and not vim.wo.diff then
    vim.api.nvim_set_current_win(view.cur_layout:get_main_win().id)
  end
  step(dir)
end

function M.next_hunk() step_from(1) end
function M.prev_hunk() step_from(-1) end

function M.setup()
  local group = vim.api.nvim_create_augroup('review', {})
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = group,
    callback = function(ev)
      if vim.bo[ev.buf].buftype == '' then decorate(vim.api.nvim_get_current_win()) end
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'DiffviewDiffBufWinEnter',
    callback = function()
      local win = vim.api.nvim_get_current_win()
      vim.schedule(function() decorate(win) end)
    end,
  })
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = 'agent-review.md',
    callback = function() vim.schedule(decorate_all_tabs) end,
  })

  vim.api.nvim_create_user_command('ReviewComment', function(o)
    if o.range > 0 then M.comment(o.line1, o.line2) else M.comment() end
  end, { range = true, desc = 'Comment on the hunk under the cursor' })
  vim.api.nvim_create_user_command('ReviewOpen', M.open, { desc = 'Edit review comments' })
  vim.api.nvim_create_user_command('ReviewYank', M.yank, { desc = 'Copy review comments' })
  vim.api.nvim_create_user_command('ReviewClear', M.clear, { desc = 'Delete review comments' })
end

return M
