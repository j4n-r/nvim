-- TypeScript 7 (native) language server: `tsc --lsp`. Prefers the project's
-- node_modules/.bin/tsc over one on PATH.
return {
  cmd = function(dispatchers, config)
    local tsc = config.root_dir and vim.fs.joinpath(config.root_dir, 'node_modules/.bin/tsc')
    if not (tsc and vim.uv.fs_stat(tsc)) then
      tsc = 'tsc'
    end
    return vim.lsp.rpc.start({ tsc, '--lsp', '--stdio' }, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
  root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
}
