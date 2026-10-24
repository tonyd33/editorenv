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

  # Neovim filetype -> VS Code language id, where they differ.
  languageIds = {
    bash = "shellscript";
    cs = "csharp";
    make = "makefile";
    objc = "objective-c";
    objcpp = "objective-cpp";
    sh = "shellscript";
    tex = "latex";
    text = "plaintext";
    zsh = "shellscript";
  }
  // cfg.languageIds;
  languageOf = ft: languageIds.${ft} or ft;

  pinnedPath =
    key: command:
    lib.optionalAttrs (lib.hasInfix "/" (lib.head command)) { ${key} = [ (lib.head command) ]; };

  nixFormatter = {
    extension = "jnoortheen.nix-ide";
    settings = command: {
      "nix.formatterPath" = map (lib.replaceStrings [ "$FILENAME" ] [ "{file}" ]) command;
    };
  };

  # Formatter id -> the extension that runs it, and the settings that point it
  # at the formatter.
  knownFormatters = {
    alejandra = nixFormatter;
    black = {
      extension = "ms-python.black-formatter";
      settings = pinnedPath "black-formatter.path";
    };
    nixfmt = nixFormatter;
    nixpkgs-fmt = nixFormatter;
    prettier.extension = "esbenp.prettier-vscode";
    ruff = {
      extension = "charliermarsh.ruff";
      settings = pinnedPath "ruff.path";
    };
  };

  genericFormatter = "jkillian.custom-local-formatters";

  byFiletype = config.format.byFiletype;

  overridden = id: cfg.formatters ? ${id} && cfg.formatters.${id}.extension != null;

  # Filetype -> the extension that formats it, its settings, and the command
  # custom-local-formatters runs, if it is that extension.
  plan =
    ft: steps:
    let
      step = lib.head steps;
    in
    if lib.length steps > 1 then
      throw "editorenv: format.filetypes.${ft} has ${toString (lib.length steps)} steps, and VS Code runs one formatter per language."
    else if step ? server then
      let
        extension = extensionOf step.server;
      in
      if extension == null then
        throw "editorenv: format.filetypes.${ft} needs the VS Code extension of ${step.server}; set editors.vscode.servers.${step.server}.extension."
      else
        { inherit extension; }
    else if overridden step.formatter then
      { inherit (cfg.formatters.${step.formatter}) extension; }
    else if knownFormatters ? ${step.formatter} then
      {
        inherit (knownFormatters.${step.formatter}) extension;
        settings = (knownFormatters.${step.formatter}.settings or (_: { })) step.command;
      }
    else
      {
        extension = genericFormatter;
        command = lib.concatMapStringsSep " " (
          arg: lib.escapeShellArg (lib.replaceStrings [ "$FILENAME" ] [ "\${file}" ] arg)
        ) step.command;
      };

  plans = lib.mapAttrs plan byFiletype;

  formatExtensions = lib.unique (lib.mapAttrsToList (_: p: p.extension) plans);

  generic = lib.filterAttrs (_: p: p ? command) plans;

  genericFormatters = lib.mapAttrsToList (_: fts: {
    inherit (plans.${lib.head fts}) command;
    languages = lib.naturalSort (lib.unique (map languageOf fts));
  }) (lib.groupBy (ft: (lib.head byFiletype.${ft}).formatter) (lib.attrNames generic));

  formatSettings = lib.foldl' lib.recursiveUpdate { } (
    lib.mapAttrsToList (ft: p: {
      "[${languageOf ft}]" = {
        "editor.defaultFormatter" = p.extension;
      }
      // lib.optionalAttrs config.format.onSave { "editor.formatOnSave" = true; };
    }) plans
    ++ lib.mapAttrsToList (_: p: p.settings or { }) plans
    ++ lib.mapAttrsToList (_: f: f.settings) cfg.formatters
    ++ [
      (lib.optionalAttrs (genericFormatters != [ ]) {
        "customLocalFormatters.formatters" = genericFormatters;
      })
    ]
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
    lib.mapAttrsToList serverSettings (lib.filterAttrs (_: s: s.enable) servers)
    ++ [
      formatSettings
      cfg.settings
    ]
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

    formatters = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            extension = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "foxundermoon.shell-format";
              description = ''
                Id of the extension that runs the formatter. `null` uses the one
                editorenv knows for this formatter id, else
                `${genericFormatter}` running `command`.
              '';
            };
            settings = mkOption {
              type = types.attrsOf types.anything;
              default = { };
              description = "VS Code settings for this formatter.";
            };
          };
        }
      );
      default = { };
      description = "VS Code-specific settings for formatters declared in `format.formatters`.";
    };

    languageIds = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        fish = "fish";
      };
      description = "VS Code language ids of Neovim filetypes, where editorenv doesn't know them.";
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
        recommendations = lib.naturalSort (
          lib.unique (
            extensionsWhere true
            ++ formatExtensions
            ++ lib.optional config.editors.editorconfig.enable "editorconfig.editorconfig"
          )
        );
        unwantedRecommendations = extensionsWhere false;
      };
    };
  };
}
