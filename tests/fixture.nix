# `fake` runs a real LSP server. `fakelang` is formatted by it and then `shout`,
# `fakefmt` by `fake-fmt` and then `shout`. The other servers are only checked
# against `vim.lsp.config`.
{ lib, pkgs, ... }:
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

  format = {
    formatters = {
      fake = {
        package = pkgs.writeShellScriptBin "fake-fmt" ''
          echo "$1" > "$FAKE_FMT_LOG"
          input=$(cat)
          case $input in
            *fail*) echo "refusing to format" >&2; exit 1 ;;
          esac
          printf '%s\n' "$input" | sed 's/^content$/CONTENT/'
        '';
        command = [
          "fake-fmt"
          "$FILENAME"
        ];
      };
      shout.package = pkgs.writeShellScriptBin "shout" "sed 's/^\\(CONTENT\\|formatted\\)$/\\1!/'";
    };
    filetypes = {
      fakefmt = [
        "fake"
        "shout"
      ];
      fakelang = [
        { lsp = "fake"; }
        "shout"
      ];
    };
    onSave = true;
  };

  editors.neovim.extraLua = ''
    vim.g.editorenv_extra = true
  '';
}
