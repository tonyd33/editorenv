{ pkgs, ... }:
{
  # Install gopls via devenv.
  languages.go.enable = true;

  editors.neovim.enable = true;
  editors.vscode.enable = true;

  # Add settings to the bridged server...
  lsp.servers.gopls.settings.gopls.gofumpt = true;

  # ...or declare servers devenv has no language module for.
  lsp.servers.buf_ls.package = pkgs.buf;
}
