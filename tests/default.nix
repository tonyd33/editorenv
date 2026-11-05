{ pkgs }:
let
  inherit (pkgs) lib;
  editorenv = import ../lib { inherit lib; };

  project = editorenv.mkProject {
    inherit pkgs;
    modules = [ ./fixture.nix ];
  };
  generated = project.shell.files.".nvim.lua";

  neovimTest =
    withLspconfig:
    pkgs.runCommand "editorenv-neovim-${if withLspconfig then "lspconfig" else "bare"}"
      {
        nativeBuildInputs = [
          pkgs.neovim-unwrapped
          pkgs.python3
        ];
        LSPCONFIG = lib.optionalString withLspconfig pkgs.vimPlugins.nvim-lspconfig;
      }
      ''
        export HOME=$TMPDIR
        bash ${./nvim}/run.sh ${generated}
        touch $out
      '';
in
{
  neovim-with-lspconfig = neovimTest true;
  neovim-without-lspconfig = neovimTest false;

  # The shell hook links files at the flake root, is idempotent, and never
  # replaces a real file.
  shell-hook = pkgs.runCommand "editorenv-shell-hook" { } ''
    set -euo pipefail
    mkdir -p proj && cd proj

    run_hook() { bash -euo pipefail -c ${lib.escapeShellArg project.shell.hook}; }

    run_hook
    [ "$(readlink .nvim.lua)" = ${generated} ] || { echo "not linked"; exit 1; }
    run_hook   # second entry is a no-op
    [ "$(readlink .nvim.lua)" = ${generated} ] || { echo "not idempotent"; exit 1; }

    rm .nvim.lua && echo "-- mine" > .nvim.lua
    run_hook 2> err
    grep -q "not replacing" err || { echo "no warning"; exit 1; }
    [ "$(cat .nvim.lua)" = "-- mine" ] || { echo "clobbered a real file"; exit 1; }

    mkdir sub && (cd sub && EDITORENV_ROOT=.. run_hook)
    [ ! -e sub/.nvim.lua ] || { echo "ignored EDITORENV_ROOT"; exit 1; }

    mkdir -p ../outer/repo && cd ../outer && touch flake.nix && cd repo
    mkdir .git a nested && touch flake.nix nested/flake.nix && mkdir -p a/b nested/x
    (cd a/b && run_hook)
    [ "$(readlink .nvim.lua)" = ${generated} ] || { echo "not linked at flake root"; exit 1; }
    [ ! -e a/b/.nvim.lua ] || { echo "linked in subdirectory"; exit 1; }
    (cd nested/x && run_hook)
    [ "$(readlink nested/.nvim.lua)" = ${generated} ] || { echo "not linked at nested flake"; exit 1; }
    [ ! -e nested/x/.nvim.lua ] || { echo "linked below nested flake"; exit 1; }

    rm flake.nix .nvim.lua
    (cd a/b && run_hook)
    [ -L a/b/.nvim.lua ] || { echo "no flake: not linked in PWD"; exit 1; }
    [ ! -e ../.nvim.lua ] || { echo "crossed the repository root"; exit 1; }
    touch $out
  '';

  # Links the hook made and no longer generates are removed, along with the
  # directories that leaves empty. Anything else is left alone.
  shell-hook-prune =
    let
      hookOf =
        modules:
        lib.escapeShellArg
          (editorenv.mkProject {
            inherit pkgs;
            inherit modules;
          }).shell.hook;
      neovim = hookOf [ { editors.neovim.enable = true; } ];
      both = hookOf [
        {
          editors.neovim.enable = true;
          editors.vscode.enable = true;
        }
      ];
      none = hookOf [ ];
    in
    pkgs.runCommand "editorenv-shell-hook-prune" { } ''
      set -euo pipefail
      mkdir proj && cd proj
      run_hook() { bash -euo pipefail -c "$1"; }

      run_hook ${both}
      [ -L .vscode/settings.json ] || { echo "not linked"; exit 1; }
      [ "$(cat .editorenv/.gitignore)" = "*" ] || { echo "manifest dir not ignored"; exit 1; }
      [ "$(cut -f1 .editorenv/links | sort | tr '\n' ' ')" = ".nvim.lua .vscode/extensions.json .vscode/settings.json " ] \
        || { echo "wrong manifest:"; cat .editorenv/links; exit 1; }

      run_hook ${neovim}
      [ ! -e .vscode ] || { echo "stale links or their directory left behind"; ls -la .vscode; exit 1; }
      [ -L .nvim.lua ] || { echo "removed a link still generated"; exit 1; }
      [ "$(cut -f1 .editorenv/links)" = ".nvim.lua" ] || { echo "manifest not updated"; exit 1; }

      run_hook ${both}
      ln -sfn /elsewhere .vscode/settings.json
      touch .vscode/launch.json
      run_hook ${neovim}
      [ "$(readlink .vscode/settings.json)" = /elsewhere ] || { echo "removed a retargeted link"; exit 1; }
      [ ! -e .vscode/extensions.json ] || { echo "stale link left behind"; exit 1; }
      [ -e .vscode/launch.json ] || { echo "removed a user file"; exit 1; }

      run_hook ${none}
      [ ! -e .nvim.lua ] || { echo "link left behind with nothing generated"; exit 1; }
      [ ! -e .editorenv ] || { echo "manifest left behind with nothing linked"; exit 1; }

      mkdir ../fresh && cd ../fresh
      run_hook ${none}
      [ -z "$(ls -A)" ] || { echo "empty config wrote files"; ls -A; exit 1; }
      touch $out
    '';

  vscode =
    let
      project = editorenv.mkProject {
        inherit pkgs;
        modules = [ ./vscode.nix ];
      };
      parse =
        path:
        builtins.fromJSON (
          lib.concatStringsSep "\n" (
            lib.drop 1 (
              lib.splitString "\n" (builtins.unsafeDiscardStringContext project.editors.files.${path}.text)
            )
          )
        );
      settings = parse ".vscode/settings.json";
      extensions = parse ".vscode/extensions.json";
      exe = name: builtins.unsafeDiscardStringContext (lib.getExe project.lsp.servers.${name}.package);
      fmt =
        name: builtins.unsafeDiscardStringContext (lib.getExe project.format.formatters.${name}.package);
      formatter = extension: { "editor.defaultFormatter" = extension; };
    in
    assert
      settings == {
        "rust-analyzer.cargo.features" = "all";
        "rust-analyzer.cargo.extraEnv" = { };
        "rust-analyzer.check.command" = "clippy";
        "rust-analyzer.server.path" = exe "rust_analyzer";
        gopls = {
          "ui.semanticTokens" = true;
          gofumpt = true;
        };
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = exe "nixd";
        "nix.serverSettings".nixd.formatting.command = [ "nixfmt" ];
        "fake.greeting" = "hello";
        "editor.formatOnSave" = true;
        "[nix]" = formatter "jnoortheen.nix-ide";
        "nix.formatterPath" = [ (fmt "nixfmt") ];
        "[typescript]" = formatter "esbenp.prettier-vscode";
        "[shellscript]" = formatter "jkillian.custom-local-formatters";
        "customLocalFormatters.formatters" = [
          {
            command = "${fmt "shfmt"} --filename '\${file}'";
            languages = [ "shellscript" ];
          }
        ];
        "[toml]" = formatter "tamasfe.even-better-toml";
        "evenBetterToml.formatter.alignEntries" = true;
        "[rust]" = formatter "rust-lang.rust-analyzer";
      };
    assert
      extensions == {
        recommendations = [
          "esbenp.prettier-vscode"
          "example.other"
          "golang.go"
          "jkillian.custom-local-formatters"
          "jnoortheen.nix-ide"
          "rust-lang.rust-analyzer"
          "tamasfe.even-better-toml"
        ];
        unwantedRecommendations = [ "sumneko.lua" ];
      };
    assert lib.elem project.format.formatters.shfmt.package project.shell.packages;
    pkgs.runCommand "editorenv-vscode" { } "touch $out";

  # Steps name formatters and enabled servers, and VS Code takes one per filetype.
  format-errors =
    let
      eval = modules: (editorenv.evalConfig { inherit modules; }).config;
      fails =
        modules:
        let
          files = (eval modules).editors.files;
        in
        !(builtins.tryEval (builtins.deepSeq files files)).success;
      neovim.editors.neovim.enable = true;
      vscode.editors.vscode.enable = true;
      formatters.format.formatters = {
        a.command = [ "a" ];
        b.command = [ "b" ];
        off = {
          enable = false;
          command = [ "off" ];
        };
      };
      chain.format.filetypes.x = [
        "a"
        "b"
      ];
    in
    assert fails [
      neovim
      { format.filetypes.x = [ "missing" ]; }
    ];
    assert fails [
      neovim
      { format.filetypes.x = [ { lsp = "missing"; } ]; }
    ];
    assert fails [
      neovim
      {
        format.filetypes.x = [ { lsp = "off"; } ];
        lsp.servers.off.enable = false;
      }
    ];
    assert fails [
      neovim
      {
        format.formatters.empty = { };
        format.filetypes.x = [ "empty" ];
      }
    ];
    assert fails [
      vscode
      {
        format.filetypes.x = [ { lsp = "fake"; } ];
        lsp.servers.fake = { };
      }
    ];
    assert fails [
      vscode
      formatters
      chain
    ];
    assert
      !fails [
        neovim
        formatters
        chain
      ];
    assert
      (eval [
        formatters
        {
          format.filetypes = {
            x = [
              "off"
              "a"
            ];
            y = [ "off" ];
          };
        }
      ]).format.byFiletype == {
        x = [
          {
            formatter = "a";
            command = [ "a" ];
          }
        ];
      };
    pkgs.runCommand "editorenv-format-errors" { } "touch $out";

  editorconfig =
    let
      config = (editorenv.evalConfig { modules = [ ./editorconfig.nix ]; }).config;
      text = config.editors.files.".editorconfig".text;
      extensions = builtins.fromJSON (
        lib.concatStringsSep "\n" (
          lib.drop 1 (lib.splitString "\n" config.editors.files.".vscode/extensions.json".text)
        )
      );
    in
    assert
      text == ''
        # Generated from the project's Nix configuration (editors.editorconfig). Do not edit.
        root = true

        [*]
        end_of_line = lf
        indent_size = 2
        indent_style = space
        insert_final_newline = true

        [*.{js,ts}]
        indent_size = 4

        [Makefile]
        indent_style = tab
      '';
    assert extensions.recommendations == [ "editorconfig.editorconfig" ];
    pkgs.runCommand "editorenv-editorconfig"
      {
        nativeBuildInputs = [ pkgs.editorconfig-core-c ];
      }
      ''
        set -euo pipefail
        mkdir proj && cd proj
        cp ${pkgs.writeText "editorconfig" text} .editorconfig

        expect() {
          local got
          got=$(editorconfig "$PWD/$1" | sort)
          [ "$got" = "$2" ] || { printf '%s: expected\n%s\ngot\n%s\n' "$1" "$2" "$got"; exit 1; }
        }
        expect a.js "$(printf '%s\n' end_of_line=lf indent_size=4 indent_style=space insert_final_newline=true tab_width=4)"
        expect Makefile "$(printf '%s\n' end_of_line=lf indent_size=2 indent_style=tab insert_final_newline=true tab_width=2)"
        touch $out
      '';

  # Known ids default `command`, `filetypes` and `rootMarkers`, a bare command
  # resolves into the package, explicit values win, and Neovim warns about any
  # enabled server it cannot start on its own.
  server-defaults =
    let
      zls = pkgs.writeShellScriptBin "zls" "";
      eval = modules: (editorenv.evalConfig { inherit modules; }).config;
      neovim.editors.neovim.enable = true;
      text =
        modules:
        builtins.unsafeDiscardStringContext (eval ([ neovim ] ++ modules)).editors.files.".nvim.lua".text;
      exe = name: builtins.unsafeDiscardStringContext "${zls}/bin/${name}";
      warnings = modules: (eval ([ neovim ] ++ modules)).editors.warnings;

      known = (eval [ { lsp.servers.zls.package = zls; } ]).lsp.servers.zls;
      overridden =
        (eval [
          {
            lsp.servers.zls = {
              package = zls;
              command = [
                "my-zls"
                "--flag"
              ];
              filetypes = [ "zig" ];
              rootMarkers = [ "build.zig" ];
            };
          }
        ]).lsp.servers.zls;
      deferred =
        (eval [
          {
            lsp.servers.zls = {
              command = null;
              filetypes = null;
              rootMarkers = null;
            };
          }
        ]).lsp.servers.zls;
    in
    assert known.command == [ "zls" ];
    assert
      known.filetypes == [
        "zig"
        "zir"
      ];
    assert
      known.rootMarkers == [
        "zls.json"
        "build.zig"
        ".git"
      ];
    assert lib.hasInfix ''"${exe "zls"}"'' (text [ { lsp.servers.zls.package = zls; } ]);

    assert
      overridden.command == [
        "my-zls"
        "--flag"
      ];
    assert overridden.filetypes == [ "zig" ];
    assert overridden.rootMarkers == [ "build.zig" ];
    assert lib.hasInfix "\"${exe "my-zls"}\",\n    \"--flag\"" (text [
      {
        lsp.servers.zls = {
          package = zls;
          command = [
            "my-zls"
            "--flag"
          ];
        };
      }
    ]);
    assert lib.hasInfix ''"/opt/zls"'' (text [
      {
        lsp.servers.zls = {
          package = zls;
          command = [ "/opt/zls" ];
        };
      }
    ]);
    assert deferred.command == null && deferred.filetypes == null && deferred.rootMarkers == null;

    assert (eval [ { lsp.servers.fake = { }; } ]).editors.warnings == [ ];
    assert warnings [ { lsp.servers.zls = { }; } ] == [ ];
    assert
      warnings [ { lsp.servers.fake = { }; } ] == [
        "editorenv: lsp.servers.fake has no cmd or filetypes for Neovim, so it starts only if nvim-lspconfig is installed. Set `command` and `filetypes` to make it self-contained."
      ];
    assert
      warnings [ { lsp.servers.fake.command = [ "fake-ls" ]; } ] == [
        "editorenv: lsp.servers.fake has no filetypes for Neovim, so it starts only if nvim-lspconfig is installed. Set `command` and `filetypes` to make it self-contained."
      ];
    assert lib.length (warnings [ { lsp.servers.zls.filetypes = null; } ]) == 1;
    assert warnings [ { lsp.servers.fake.enable = false; } ] == [ ];
    assert
      warnings [
        {
          lsp.servers.fake = {
            command = [ "fake-ls" ];
            filetypes = [ "fakelang" ];
          };
        }
      ] == [ ];
    assert
      warnings [
        {
          lsp.servers.fake = { };
          editors.neovim.servers.fake.config = {
            cmd = [ "fake-ls" ];
            filetypes = [ "fakelang" ];
          };
        }
      ] == [ ];
    pkgs.runCommand "editorenv-server-defaults" { } "touch $out";

  # devenv's `languages.<lang>.lsp.package` becomes the server's package.
  devenv-languages =
    let
      zls = pkgs.writeShellScriptBin "zls" "";
      config =
        (editorenv.evalConfig {
          modules = [
            ../integrations/devenv/languages.nix
            {
              options.languages = lib.mkOption { type = lib.types.attrsOf lib.types.anything; };
              options.warnings = lib.mkOption { type = lib.types.listOf lib.types.str; };
              config.languages.zig = {
                enable = true;
                lsp = {
                  enable = true;
                  package = zls;
                };
              };
              config.editors.neovim.enable = true;
            }
          ];
        }).config;
    in
    assert config.lsp.servers.zls.package == zls;
    assert lib.hasInfix (builtins.unsafeDiscardStringContext "${zls}/bin/zls") (
      builtins.unsafeDiscardStringContext config.editors.files.".nvim.lua".text
    );
    assert config.warnings == [ ];
    pkgs.runCommand "editorenv-devenv-languages" { } "touch $out";

  # Nothing enabled -> no files, no packages.
  empty =
    let
      empty = editorenv.mkProject { inherit pkgs; };
    in
    assert empty.editors.files == { };
    assert empty.shell.packages == [ ];
    pkgs.runCommand "editorenv-empty" { } "touch $out";
}
