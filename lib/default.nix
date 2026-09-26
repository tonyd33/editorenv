# Entry points for plain Nix / plain flakes.
{ lib }:
let
  coreModules = import ../modules;
in
{
  inherit coreModules;

  # Evaluate the core with only `lib`: no pkgs, no shell.
  #   (evalConfig { modules = [ { editors.neovim.enable = true; ... } ]; }).config.editors.files
  evalConfig =
    {
      modules ? [ ],
      specialArgs ? { },
    }:
    lib.evalModules {
      modules = coreModules ++ modules;
      inherit specialArgs;
    };

  # Returns the evaluated config. Its `shell` attribute holds `devShell`,
  # `packages`, `hook` and `files`.
  #
  #   let editor = editorenv.lib.mkProject { inherit pkgs; modules = [ ./editor.nix ]; };
  #   in pkgs.mkShell { inputsFrom = [ editor.shell.devShell ]; packages = [ ... ]; }
  mkProject =
    {
      pkgs,
      modules ? [ ],
      specialArgs ? { },
    }:
    (pkgs.lib.evalModules {
      modules = coreModules ++ [ ../integrations/shell.nix ] ++ modules;
      specialArgs = {
        inherit pkgs;
      }
      // specialArgs;
    }).config;
}
