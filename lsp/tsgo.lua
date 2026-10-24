-- TypeScript 7 (native) language server: `tsc --lsp`. Prefers the project's
-- node_modules/.bin/tsc over one on PATH when it supports the native LSP.
-- The version check blocks (it starts Node), so its answer is kept per tsc.
local supports_lsp = {}
local function native_tsc(tsc)
  if supports_lsp[tsc] == nil then
    local version = vim.system({ tsc, '--version' }, { text = true }):wait(2000)
    local major = version.code == 0 and tonumber((version.stdout or ''):match('Version (%d+)'))
    supports_lsp[tsc] = major ~= nil and major >= 7
  end
  return supports_lsp[tsc]
end

return {
  cmd = function(dispatchers, config)
    local tsc = config.root_dir and vim.fs.joinpath(config.root_dir, 'node_modules/.bin/tsc')
    if not (tsc and vim.fn.executable(tsc) == 1 and native_tsc(tsc)) then tsc = nil end
    return vim.lsp.rpc.start({ tsc or 'tsc', '--lsp', '--stdio' }, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
  root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
}
