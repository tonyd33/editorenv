# Renders `lsp.servers` as VS Code workspace settings and extension
# recommendations.
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.editors.vscode;
  servers = config.lsp.servers;

  # Server id -> the extension that runs it, the settings that point it at the
  # server executable, and where it reads the server's settings from when that
  # is not the settings' own section.
  known = {
    basedpyright.extension = "detachhead.basedpyright";
    bashls.extension = "mads-hartmann.bash-ide-vscode";
    clangd = {
      extension = "llvm-vs-code-extensions.vscode-clangd";
      path = exe: { "clangd.path" = exe; };
    };
    gopls = {
      extension = "golang.go";
      path = exe: { "go.alternateTools".gopls = exe; };
    };
    hls = {
      extension = "haskell.haskell";
      path = exe: { "haskell.serverExecutablePath" = exe; };
    };
    lua_ls = {
      extension = "sumneko.lua";
      path = exe: { "Lua.misc.executablePath" = exe; };
    };
    nil_ls = nixIde;
    nixd = nixIde;
    pyright.extension = "ms-pyright.pyright";
    ruff = {
      extension = "charliermarsh.ruff";
      path = exe: { "ruff.path" = [ exe ]; };
    };
    rust_analyzer = {
      extension = "rust-lang.rust-analyzer";
      path = exe: { "rust-analyzer.server.path" = exe; };
    };
    terraformls = {
      extension = "hashicorp.terraform";
      path = exe: { "terraform.languageServer.path" = exe; };
    };
    tinymist = {
      extension = "myriad-dreamin.tinymist";
      path = exe: { "tinymist.serverPath" = exe; };
    };
    yamlls.extension = "redhat.vscode-yaml";
    zls = {
      extension = "ziglang.vscode-zig";
      path = exe: { "zig.zls.path" = exe; };
    };
  };

  nixIde = {
    extension = "jnoortheen.nix-ide";
    path = exe: {
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = exe;
    };
    settings = s: { "nix.serverSettings" = s; };
  };

  # VS Code splits setting keys on `.` to rebuild the nested value, so an
  # object whose keys contain a dot has to stay an object.
  flatten =
    key: value:
    if lib.isAttrs value && value != { } && !lib.any (lib.hasInfix ".") (lib.attrNames value) then
      lib.concatMapAttrs (k: flatten "${key}.${k}") value
    else
      { ${key} = value; };

  serverSettings =
    id: server:
    let
      entry = known.${id} or { };
      toSettings = entry.settings or (lib.concatMapAttrs flatten);
    in
    lib.recursiveUpdate (
      lib.optionalAttrs (server.settings != { }) (toSettings server.settings)
      // lib.optionalAttrs (server.package != null && entry ? path) (
        entry.path (lib.getExe server.package)
      )
    ) (cfg.servers.${id}.settings or { });

  extensionOf =
    id:
    if cfg.servers ? ${id} && cfg.servers.${id}.extension != null then
      cfg.servers.${id}.extension
    else
      known.${id}.extension or null;

  extensionsWhere =
    enabled:
    lib.naturalSort (
      lib.unique (
        lib.filter (e: e != null) (
          lib.mapAttrsToList (id: s: if s.enable == enabled then extensionOf id else null) servers
        )
      )
    );

  toJSON =
    indent: v:
    let
      next = indent + "  ";
    in
    if lib.isAttrs v && v != { } then
      "{\n"
      + lib.concatStringsSep ",\n" (
        lib.mapAttrsToList (k: x: "${next}${builtins.toJSON k}: ${toJSON next x}") v
      )
      + "\n${indent}}"
    else if lib.isList v && v != [ ] then
      "[\n" + lib.concatMapStringsSep ",\n" (x: next + toJSON next x) v + "\n${indent}]"
    else
      builtins.toJSON v;

  render = value: ''
    // Generated from the project's Nix configuration (editors.vscode). Do not edit.
    ${toJSON "" value}
  '';

  settings = lib.foldl' lib.recursiveUpdate { } (
    lib.mapAttrsToList serverSettings (lib.filterAttrs (_: s: s.enable) servers) ++ [ cfg.settings ]
  );
in
{
  options.editors.vscode = {
    enable = lib.mkEnableOption "generated VS Code workspace settings";

    path = mkOption {
      type = types.str;
      default = ".vscode/settings.json";
      description = "Where to write the workspace settings, relative to the project root.";
    };

    extensionsPath = mkOption {
      type = types.nullOr types.str;
      default = ".vscode/extensions.json";
      description = ''
        Where to write the extension recommendations, relative to the project
        root. `null` skips the file.
      '';
    };

    servers = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            extension = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "rust-lang.rust-analyzer";
              description = ''
                Id of the extension that runs the server. `null` uses the one
                editorenv knows for this server id, if any.
              '';
            };
            settings = mkOption {
              type = types.attrsOf types.anything;
              default = { };
              example = {
                "rust-analyzer.check.command" = "clippy";
              };
              description = ''
                VS Code settings for this server, merged over the ones derived
                from `lsp.servers`.
              '';
            };
          };
        }
      );
      default = { };
      description = "VS Code-specific settings for servers declared in `lsp.servers`.";
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      example = {
        "editor.formatOnSave" = true;
      };
      description = "Workspace settings merged over everything else.";
    };
  };

  config = lib.mkIf cfg.enable {
    editors.files = {
      ${cfg.path}.text = render settings;
    }
    // lib.optionalAttrs (cfg.extensionsPath != null) {
      ${cfg.extensionsPath}.text = render {
        recommendations = extensionsWhere true;
        unwantedRecommendations = extensionsWhere false;
      };
    };
  };
}
