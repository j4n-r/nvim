-- Lints JS/TS in projects that have an .oxlintrc.json. Prefers the project's
-- node_modules/.bin/oxlint over one on PATH.
return {
  cmd = function(dispatchers, config)
    local oxlint = config.root_dir and vim.fs.joinpath(config.root_dir, 'node_modules/.bin/oxlint')
    if not (oxlint and vim.uv.fs_stat(oxlint)) then
      oxlint = 'oxlint'
    end
    return vim.lsp.rpc.start({ oxlint, '--lsp' }, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
  root_markers = { '.oxlintrc.json' },
  workspace_required = true,
}
