# Renders `editors.editorconfig.sections` as a project `.editorconfig`.
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.editors.editorconfig;

  renderValue = v: if lib.isBool v then lib.boolToString v else toString v;

  renderSection =
    glob: properties:
    "\n[${glob}]\n"
    + lib.concatStrings (lib.mapAttrsToList (k: v: "${k} = ${renderValue v}\n") properties);
in
{
  options.editors.editorconfig = {
    enable = lib.mkEnableOption "a generated `.editorconfig`";

    path = mkOption {
      type = types.str;
      default = ".editorconfig";
      description = "Where to write the file, relative to the project root.";
    };

    root = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Write `root = true`, so editors stop looking for `.editorconfig` files
        in parent directories.
      '';
    };

    sections = mkOption {
      type = types.attrsOf (
        types.attrsOf (
          types.oneOf [
            types.bool
            types.int
            types.str
          ]
        )
      );
      default = { };
      example = {
        "*" = {
          end_of_line = "lf";
          insert_final_newline = true;
          indent_style = "space";
          indent_size = 2;
        };
        "Makefile".indent_style = "tab";
      };
      description = ''
        Properties keyed by glob. Sections are written in name order, and a
        later section overrides an earlier one where both match.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    editors.files.${cfg.path}.text =
      "# Generated from the project's Nix configuration (editors.editorconfig). Do not edit.\n"
      + lib.optionalString cfg.root "root = true\n"
      + lib.concatStrings (lib.mapAttrsToList renderSection cfg.sections);
  };
}
