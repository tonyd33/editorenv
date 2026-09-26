# Renders `lsp.servers` as a project-local Neovim config (`.nvim.lua`), loaded
# by 'exrc'. Needs Neovim 0.11+.
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.editors.neovim;
  toLua = lib.generators.toLua { };

  nonEmpty = v: v != null && v != { } && v != [ ];

  serverTable =
    id: server:
    lib.recursiveUpdate (lib.filterAttrs (_: nonEmpty) {
      cmd = server.command;
      inherit (server) filetypes settings;
      root_markers = server.rootMarkers;
      init_options = server.initializationOptions;
    }) (cfg.servers.${id}.config or { });

  nameOf =
    id: if cfg.servers ? ${id} && cfg.servers.${id}.name != null then cfg.servers.${id}.name else id;

  renderServer =
    id: server:
    let
      name = toLua (nameOf id);
      table = serverTable id server;
    in
    if !server.enable then
      "vim.lsp.enable(${name}, false)\n"
    else
      lib.optionalString (table != { }) "vim.lsp.config(${name}, ${toLua table})\n"
      + "vim.lsp.enable(${name})\n";

  servers = config.lsp.servers;
  # Enabled servers first, then disables, each sorted by id. Any change to the
  # output makes Neovim ask for trust again.
  ordering = a: b: if servers.${a}.enable != servers.${b}.enable then servers.${a}.enable else a < b;
in
{
  options.editors.neovim = {
    enable = lib.mkEnableOption "a generated project-local Neovim config";

    path = mkOption {
      type = types.str;
      default = ".nvim.lua";
      description = ''
        Where to write the config, relative to the project root. The default is
        the file Neovim's 'exrc' loads. Pick another path if the project keeps
        a hand-written `.nvim.lua`, and `dofile()` the generated one from it.
      '';
    };

    servers = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Name of the server in Neovim, when it differs from its id in `lsp.servers`.";
            };
            config = mkOption {
              type = types.attrsOf types.anything;
              default = { };
              example = lib.literalExpression ''
                {
                  on_attach = lib.generators.mkLuaInline '''
                    function(client, buf) vim.lsp.inlay_hint.enable(true, { bufnr = buf }) end
                  ''';
                }
              '';
              description = ''
                Neovim-only fields merged into the server's `vim.lsp.config()`
                table. Use `lib.generators.mkLuaInline` for raw Lua.
              '';
            };
          };
        }
      );
      default = { };
      description = "Neovim-specific settings for servers declared in `lsp.servers`.";
    };

    extraLua = mkOption {
      type = types.lines;
      default = "";
      description = "Lua appended to the generated config.";
    };

    text = mkOption {
      type = types.str;
      readOnly = true;
      description = "The generated config.";
    };
  };

  config = lib.mkMerge [
    {
      editors.neovim.text = ''
        -- Generated from the project's Nix configuration (editors.neovim). Do not edit.
        if vim.fn.has("nvim-0.11") == 0 then
          vim.notify(${toLua cfg.path} .. ": needs Neovim 0.11 or newer", vim.log.levels.WARN)
          return
        end

      ''
      + lib.concatStrings (
        map (id: renderServer id servers.${id}) (lib.sort ordering (lib.attrNames servers))
      )
      + lib.optionalString (cfg.extraLua != "") "\n${cfg.extraLua}";
    }
    (lib.mkIf cfg.enable {
      editors.files.${cfg.path}.text = cfg.text;
    })
  ];
}
