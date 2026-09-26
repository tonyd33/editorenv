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
      };
    assert
      extensions == {
        recommendations = [
          "example.other"
          "golang.go"
          "jnoortheen.nix-ide"
          "rust-lang.rust-analyzer"
        ];
        unwantedRecommendations = [ "sumneko.lua" ];
      };
    pkgs.runCommand "editorenv-vscode" { } "touch $out";

  # Nothing enabled -> no files, no hook, no packages.
  empty =
    let
      empty = editorenv.mkProject { inherit pkgs; };
    in
    assert empty.editors.files == { };
    assert empty.shell.hook == "";
    assert empty.shell.packages == [ ];
    pkgs.runCommand "editorenv-empty" { } "touch $out";
}
