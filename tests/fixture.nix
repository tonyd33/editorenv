# `fake` runs a real LSP server. The other servers are only checked against
# `vim.lsp.config`.
{ lib, ... }:
{
  editors.neovim.enable = true;

  lsp.servers = {
    fake = {
      command = [ "fake-ls" ];
      filetypes = [ "fakelang" ];
      rootMarkers = [
        ".git"
        "fake.toml"
      ];
      settings.fake = {
        greeting = "hello";
        nested.list = [
          1
          2
          3
        ];
      };
      initializationOptions.mode = "test";
    };

    # Relies on nvim-lspconfig's defaults for cmd/filetypes.
    zls.settings.zls.enable_build_on_save = true;

    # Settings key with a dash.
    rust_analyzer.settings."rust-analyzer".cargo.features = "all";

    # Turned off even though the user's global config enables it.
    ts_ls.enable = false;
  };

  editors.neovim.servers = {
    rust_analyzer.config.on_attach = lib.generators.mkLuaInline "function() end";
    fake.config.flags.debounce_text_changes = 42;
  };

  editors.neovim.extraLua = ''
    vim.g.editorenv_extra = true
  '';
}
