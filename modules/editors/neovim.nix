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

  byFiletype = config.format.byFiletype;

  formatLua = ''

    do
      local chains = ${
        toLua (
          lib.mapAttrs (
            _:
            map (step: if step ? server then { server = nameOf step.server; } else { inherit (step) command; })
          ) byFiletype
        )
      }
      local diff = vim.text and vim.text.diff or vim.diff

      local function text_of(buf)
        return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
      end

      local function run(command, file, input)
        local argv = vim.tbl_map(function(arg)
          return (arg:gsub("%$FILENAME", function() return file end))
        end, command)
        local ok, result = pcall(function()
          return vim.system(argv, { stdin = input, text = true }):wait()
        end)
        if not ok or result.code ~= 0 then
          vim.notify(("%s: %s"):format(argv[1], ok and result.stderr or result), vim.log.levels.WARN)
          return nil
        end
        local output = result.stdout
        if output:sub(-1) ~= "\n" then
          output = output .. "\n"
        end
        return output
      end

      local function apply(buf, output)
        local lines = vim.split(output, "\n", { plain = true })
        table.remove(lines)
        local hunks = diff(text_of(buf), output, { result_type = "indices" })
        for i = #hunks, 1, -1 do
          local a, a_count, b, b_count = unpack(hunks[i])
          local first = a_count == 0 and a or a - 1
          vim.api.nvim_buf_set_lines(buf, first, first + a_count, false, vim.list_slice(lines, b, b + b_count - 1))
        end
      end

      local function format(buf)
        local steps = chains[vim.bo[buf].filetype]
        if not steps then
          return
        end
        local file = vim.api.nvim_buf_get_name(buf)
        local pending
        for _, step in ipairs(steps) do
          if step.server then
            if pending then
              apply(buf, pending)
              pending = nil
            end
            vim.lsp.buf.format({ bufnr = buf, name = step.server })
          else
            pending = run(step.command, file, pending or text_of(buf))
            if not pending then
              return
            end
          end
        end
        if pending then
          apply(buf, pending)
        end
      end

      vim.api.nvim_create_user_command("Format", function()
        format(vim.api.nvim_get_current_buf())
      end, { desc = "Format the buffer with the project's formatter" })

      if ${toLua config.format.onSave} then
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = vim.api.nvim_create_augroup("editorenv_format", {}),
          callback = function(ev)
            format(ev.buf)
          end,
        })
      end
    end
  '';

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
      + lib.optionalString (byFiletype != { }) formatLua
      + lib.optionalString (cfg.extraLua != "") "\n${cfg.extraLua}";
    }
    (lib.mkIf cfg.enable {
      editors.files.${cfg.path}.text = cfg.text;
    })
  ];
}
