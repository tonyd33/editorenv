{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  languages.nix.enable = true;

  git-hooks.hooks = {
    nixfmt.enable = true;
  };
}
