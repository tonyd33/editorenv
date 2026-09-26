# Links the generated files into the project from a shell hook, for
# integrations without their own file management (plain flakes, flake-parts).
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.shell;

  generated = lib.mapAttrs (
    path: file:
    pkgs.writeText (lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "." path)) file.text
  ) config.editors.files;

  hook = ''
    __editorenv_link() {
      local src=$1 dest=$2
      if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "editorenv: not replacing $dest (not a symlink); remove it or set another path" >&2
        return 0
      fi
      if [ "$(readlink "$dest" 2>/dev/null)" != "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        if ${lib.boolToString cfg.gcRoot} && command -v nix-store >/dev/null; then
          nix-store --add-root "$dest" --indirect --realise "$src" >/dev/null
        else
          ln -sfn "$src" "$dest"
        fi
      fi
    }
    # Mirrors how `nix develop` locates flake.nix.
    __editorenv_find_root() {
      local dir=$PWD
      while :; do
        if [ -e "$dir/flake.nix" ]; then
          echo "$dir"
          return 0
        fi
        if [ -e "$dir/.git" ] || [ "$dir" = / ]; then
          break
        fi
        dir=$(dirname "$dir")
      done
      echo "$PWD"
    }
    __editorenv_root=${
      if cfg.root == null then
        ''"''${EDITORENV_ROOT:-$(__editorenv_find_root)}"''
      else
        lib.escapeShellArg cfg.root
    }
  ''
  + lib.concatStrings (
    lib.mapAttrsToList (path: drv: ''
      __editorenv_link ${drv} "$__editorenv_root"/${lib.escapeShellArg path}
    '') generated
  )
  + ''
    unset -f __editorenv_link __editorenv_find_root
    unset __editorenv_root
  '';
in
{
  options.shell = {
    root = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Directory the generated files are linked into. `null` means
        `$EDITORENV_ROOT` if set, else the directory of the nearest
        `flake.nix` at or above the current directory (not crossing a
        repository root), else the current directory.
      '';
    };

    gcRoot = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Register each link as an indirect GC root. Falls back to a plain
        symlink when `nix-store` is not on PATH.
      '';
    };

    files = mkOption {
      type = types.attrsOf types.package;
      readOnly = true;
      description = "The generated files as store paths, keyed by project-relative path.";
    };

    packages = mkOption {
      type = types.listOf types.package;
      readOnly = true;
      description = "Packages the shell needs (the enabled servers).";
    };

    hook = mkOption {
      type = types.lines;
      readOnly = true;
      description = ''
        Shell code that links the generated files into the project. Never
        replaces a file that is not a symlink.
      '';
    };

    devShell = mkOption {
      type = types.package;
      readOnly = true;
      description = ''
        A shell with `packages` and `hook`. Add it to your own shell with
        `inputsFrom`, or use it as-is.
      '';
    };
  };

  config.shell = {
    files = generated;
    packages = config.lsp.packages;
    hook = if generated == { } then "" else hook;
    devShell = pkgs.mkShell {
      name = "editorenv";
      packages = cfg.packages;
      shellHook = cfg.hook;
    };
  };
}
