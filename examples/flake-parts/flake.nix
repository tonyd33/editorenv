{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    editorenv.url = "path:../..";
    editorenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, editorenv, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ editorenv.flakeModules.default ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          editorenv.settings = {
            editors.neovim.enable = true;

            lsp.servers = {
              rust_analyzer = {
                package = pkgs.rust-analyzer;
                settings."rust-analyzer".check.command = "clippy";
              };
              nixd.package = pkgs.nixd;
            };

            # Neovim-only extras, merged into vim.lsp.config("rust_analyzer", ...).
            editors.neovim.servers.rust_analyzer.config.on_attach = lib.generators.mkLuaInline ''
              function(_, buf) vim.lsp.inlay_hint.enable(true, { bufnr = buf }) end
            '';
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [ config.editorenv.devShell ];
            packages = [
              pkgs.cargo
              pkgs.rustc
              pkgs.clippy
            ];
          };
        };
    };
}
