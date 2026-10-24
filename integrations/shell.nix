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
      local src=$1 path=$2 dest=$__editorenv_root/$2
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
      __editorenv_links+=$path$'\t'$src$'\n'
    }
    __editorenv_generated() {
      ${
        if generated == { } then
          "return 1"
        else
          "case $1 in ${
            lib.concatMapStringsSep " | " lib.escapeShellArg (lib.attrNames generated)
          }) return 0 ;; *) return 1 ;; esac"
      }
    }
    # Removes the links recorded last time that are no longer generated, unless
    # something else has since replaced them, and the directories that leaves
    # empty.
    __editorenv_prune() {
      local path target dest dir
      [ -f "$__editorenv_manifest" ] || return 0
      while IFS=$'\t' read -r path target; do
        __editorenv_generated "$path" && continue
        dest=$__editorenv_root/$path
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$target" ]; then
          rm "$dest"
          dir=$(dirname "$dest")
          while [ "$dir" != "$__editorenv_root" ] && rmdir "$dir" 2>/dev/null; do
            dir=$(dirname "$dir")
          done
        fi
      done < "$__editorenv_manifest"
    }
    __editorenv_record() {
      local dir
      dir=$(dirname "$__editorenv_manifest")
      if [ -z "$__editorenv_links" ]; then
        rm -f "$__editorenv_manifest" "$dir/.gitignore"
        rmdir "$dir" 2>/dev/null || :
        return 0
      fi
      mkdir -p "$dir"
      [ -e "$dir/.gitignore" ] || echo '*' > "$dir/.gitignore"
      printf %s "$__editorenv_links" > "$__editorenv_manifest"
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
    __editorenv_manifest=$__editorenv_root/.editorenv/links
    __editorenv_links=
  ''
  + lib.concatStrings (
    lib.mapAttrsToList (path: drv: ''
      __editorenv_link ${drv} ${lib.escapeShellArg path}
    '') generated
  )
  + ''
    __editorenv_prune
    __editorenv_record
    unset -f __editorenv_link __editorenv_find_root __editorenv_generated __editorenv_prune __editorenv_record
    unset __editorenv_root __editorenv_manifest __editorenv_links
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
      description = "Packages the shell needs (the enabled servers and formatters).";
    };

    hook = mkOption {
      type = types.lines;
      readOnly = true;
      description = ''
        Shell code that links the generated files into the project, and
        removes the links it made earlier for files no longer generated. Never
        replaces or removes a file that is not one of its links.
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
    packages = lib.unique (config.lsp.packages ++ config.format.packages);
    inherit hook;
    devShell = pkgs.mkShell {
      name = "editorenv";
      packages = cfg.packages;
      shellHook = cfg.hook;
    };
  };
}
