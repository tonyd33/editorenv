# Editor-agnostic registry of language servers.
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  defaults = import ./server-defaults.nix;

  serverModule =
    { name, ... }:
    let
      known = field: defaults.${name}.${field} or null;
    in
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether the project uses this server. `false` actively disables it
            in editors that support it (Neovim), overriding the user's global
            editor config.
          '';
        };

        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          example = lib.literalExpression "pkgs.zls";
          description = ''
            Package providing the server executable. It is added to the
            project shell, and a bare executable name in `command` resolves to
            its `bin/`, so editors needn't be started from the shell. Leave
            `null` when something else already provides the executable.
          '';
        };

        command = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = known "command";
          example = [
            "zls"
            "--enable-debug-log"
          ];
          description = ''
            Command (and arguments) that starts the server. A bare executable
            name resolves to the `bin/` of `package`, when set. Defaults to
            nvim-lspconfig's command for known ids. `null` defers to the
            editor's default for `${name}`.
          '';
        };

        filetypes = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = known "filetypes";
          example = [
            "zig"
            "zir"
          ];
          description = ''
            Filetypes the server attaches to. Defaults to nvim-lspconfig's for
            known ids. `null` uses the editor default.
          '';
        };

        rootMarkers = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = known "rootMarkers";
          example = [
            "build.zig"
            ".git"
          ];
          description = ''
            Files that mark the workspace root, searched for in order. Defaults
            to nvim-lspconfig's for known ids. `null` uses the editor default.
          '';
        };

        settings = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          example = {
            zls.enable_build_on_save = true;
          };
          description = ''
            Server settings, returned for `workspace/configuration` requests and
            sent with `workspace/didChangeConfiguration`. Must be
            JSON-serialisable. Put editor-specific values (Lua functions and the
            like) in the editor's own options.
          '';
        };

        initializationOptions = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "`initializationOptions` sent in the LSP `initialize` request.";
        };
      };
    };
in
{
  options.lsp = {
    servers = mkOption {
      type = types.attrsOf (types.submodule serverModule);
      default = { };
      description = ''
        Language servers used by this project, keyed by server id.

        Ids follow nvim-lspconfig's naming (`rust_analyzer`, `lua_ls`, `ts_ls`,
        ...). Editors that name servers differently map ids in their own
        module.
      '';
    };

    packages = mkOption {
      type = types.listOf types.package;
      readOnly = true;
      description = "Packages of the enabled servers, for the project shell.";
    };
  };

  config.lsp.packages = lib.unique (
    lib.filter (p: p != null) (
      lib.mapAttrsToList (_: s: if s.enable then s.package else null) config.lsp.servers
    )
  );
}
