{ pkgs, ... }:
{
  editors.vscode.enable = true;

  lsp.servers = {
    rust_analyzer = {
      package = pkgs.writeShellScriptBin "rust-analyzer" "";
      settings."rust-analyzer" = {
        cargo.features = "all";
        cargo.extraEnv = { };
      };
    };

    gopls.settings.gopls = {
      "ui.semanticTokens" = true;
      gofumpt = true;
    };

    nixd = {
      package = pkgs.writeShellScriptBin "nixd" "";
      settings.nixd.formatting.command = [ "nixfmt" ];
    };

    # Unknown to editorenv.
    fake.settings.fake.greeting = "hello";
    other.enable = true;

    ts_ls.enable = false;
    lua_ls.enable = false;
  };

  editors.vscode.servers = {
    other.extension = "example.other";
    rust_analyzer.settings."rust-analyzer.check.command" = "clippy";
  };

  format = {
    formatters = {
      nixfmt.package = pkgs.writeShellScriptBin "nixfmt" "";
      prettier.command = [ "prettier" ];
      # Unknown to editorenv: runs through custom-local-formatters.
      shfmt = {
        package = pkgs.writeShellScriptBin "shfmt" "";
        command = [
          "shfmt"
          "--filename"
          "$FILENAME"
        ];
      };
      taplo.command = [
        "taplo"
        "fmt"
        "-"
      ];
    };
    filetypes = {
      nix = [ "nixfmt" ];
      typescript = [ "prettier" ];
      sh = [ "shfmt" ];
      bash = [ "shfmt" ];
      toml = [ "taplo" ];
      rust = [ { lsp = "rust_analyzer"; } ];
    };
  };

  editors.vscode.formatters.taplo = {
    extension = "tamasfe.even-better-toml";
    settings."evenBetterToml.formatter.alignEntries" = true;
  };

  editors.vscode.settings."editor.formatOnSave" = true;
}
