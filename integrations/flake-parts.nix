# Adds `perSystem.editorenv`: `settings` for configuration, and the shell
# outputs beside it. Takes no inputs of its own.
{ lib, flake-parts-lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, pkgs, ... }:
    let
      cfg = config.editorenv;
      output =
        type: description:
        mkOption {
          inherit type description;
          readOnly = true;
        };
    in
    {
      options.editorenv = {
        settings = mkOption {
          type = types.submoduleWith {
            modules = import ../modules ++ [ ./shell.nix ];
            specialArgs = { inherit pkgs; };
          };
          default = { };
          description = "Project editor configuration (language servers, generated editor files).";
        };

        devShell = output types.package ''
          A shell with the server packages and the hook that links the generated
          files. Add it to your own shell with `inputsFrom`, or use it as-is.
        '';
        shellHook = output types.lines "Shell code that links the generated files into the project.";
        packages = output (types.listOf types.package) "Packages the shell needs (the enabled servers).";
        files = output (types.attrsOf types.package) "The generated files as store paths, keyed by project-relative path.";
      };

      config.editorenv = {
        devShell = cfg.settings.shell.devShell;
        shellHook = cfg.settings.shell.hook;
        packages = cfg.settings.shell.packages;
        files = cfg.settings.shell.files;
      };
    }
  );
}
