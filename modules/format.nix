# Editor-agnostic registry of formatters.
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.format;

  formatterModule =
    { config, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether the project uses this formatter.";
        };

        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          example = lib.literalExpression "pkgs.nixfmt";
          description = ''
            Package providing the formatter. It is added to the project shell,
            and a bare executable name in `command` resolves to its `bin/`, so
            editors needn't be started from the shell.
          '';
        };

        command = mkOption {
          type = types.listOf types.str;
          default = lib.optional (config.package != null) (lib.getExe config.package);
          defaultText = lib.literalExpression "[ (lib.getExe package) ]";
          example = [
            "prettier"
            "--stdin-filepath"
            "$FILENAME"
          ];
          description = ''
            Command (and arguments) that reads the file on stdin and writes the
            formatted file to stdout. `$FILENAME` is replaced by the path of
            the file being formatted.
          '';
        };
      };
    };

  resolve =
    formatter:
    let
      exe = lib.head formatter.command;
    in
    if formatter.package != null && !lib.hasInfix "/" exe then
      [ "${formatter.package}/bin/${exe}" ] ++ lib.tail formatter.command
    else
      formatter.command;

  resolveStep =
    ft: step:
    if lib.isAttrs step then
      if !(config.lsp.servers ? ${step.lsp}) || !config.lsp.servers.${step.lsp}.enable then
        throw "editorenv: format.filetypes.${ft} names ${step.lsp}, which is not an enabled server in lsp.servers."
      else
        [ { server = step.lsp; } ]
    else if !(cfg.formatters ? ${step}) then
      throw "editorenv: format.filetypes.${ft} names ${step}, which is not in format.formatters."
    else if !cfg.formatters.${step}.enable then
      [ ]
    else if cfg.formatters.${step}.command == [ ] then
      throw "editorenv: format.formatters.${step} has no command; set `command` or `package`."
    else
      [
        {
          formatter = step;
          command = resolve cfg.formatters.${step};
        }
      ];
in
{
  options.format = {
    formatters = mkOption {
      type = types.attrsOf (types.submodule formatterModule);
      default = { };
      description = "External formatters used by this project, keyed by an id of your choosing.";
    };

    filetypes = mkOption {
      type = types.attrsOf (
        types.listOf (
          types.either types.str (
            types.submodule {
              options.lsp = mkOption {
                type = types.str;
                description = "Id of the server in `lsp.servers` that formats this filetype.";
              };
            }
          )
        )
      );
      default = { };
      example = {
        python = [
          "ruff_fix"
          "ruff_format"
        ];
        rust = [ { lsp = "rust_analyzer"; } ];
      };
      description = ''
        Formatters for each filetype, by Neovim's filetype names, run in order.
        A step is a formatter id from `format.formatters`, or `{ lsp = id; }`
        to format with a language server. Disabled formatters are skipped.
      '';
    };

    onSave = mkOption {
      type = types.bool;
      default = false;
      description = "Format on save in every filetype that has a formatter.";
    };

    byFiletype = mkOption {
      type = types.attrsOf (types.listOf types.attrs);
      readOnly = true;
      description = ''
        Filetype -> the steps to run, each `{ formatter; command; }` (the
        command with its executable resolved) or `{ server; }`. Filetypes left
        with no steps are omitted.
      '';
    };

    packages = mkOption {
      type = types.listOf types.package;
      readOnly = true;
      description = "Packages of the enabled formatters, for the project shell.";
    };
  };

  config.format = {
    byFiletype = lib.filterAttrs (_: steps: steps != [ ]) (
      lib.mapAttrs (ft: steps: lib.concatMap (resolveStep ft) steps) cfg.filetypes
    );

    packages = lib.unique (
      lib.filter (p: p != null) (
        lib.mapAttrsToList (_: f: if f.enable then f.package else null) cfg.formatters
      )
    );
  };
}
