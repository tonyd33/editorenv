# Maps the core's outputs onto devenv's `packages` and `files`, and fills
# `lsp.servers` from `languages.<lang>.lsp`.
{ lib, config, ... }:
{
  imports = import ../../modules ++ [ ./languages.nix ];

  config = {
    packages = config.lsp.packages;
    files = lib.mapAttrs (_: file: { inherit (file) text; }) config.editors.files;
  };
}
