return {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  -- Cargo.lock first so a workspace member attaches to the workspace root.
  root_markers = { 'Cargo.lock', 'Cargo.toml', '.git' },
  settings = {
    ['rust-analyzer'] = {
      check = { command = 'clippy' },
    },
  },
}
