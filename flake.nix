{
  description = "Declare language servers per project and generate editor config for them";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      modules = import ./modules;

      lib = import ./lib { inherit (nixpkgs) lib; };

      flakeModules.default = ./integrations/flake-parts.nix;

      # devenv.yaml users import the directory instead.
      devenvModules.default = ./integrations/devenv;

      checks = forAllSystems (pkgs: import ./tests { inherit pkgs; });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [ pkgs.nixfmt ];
        };
      });
    };
}
