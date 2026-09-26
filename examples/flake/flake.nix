{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    editorenv.url = "path:../..";
    editorenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, editorenv, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      editor = editorenv.lib.mkProject {
        inherit pkgs;
        modules = [
          {
            editors.neovim.enable = true;
            editors.vscode.enable = true;

            lsp.servers.zls = {
              package = pkgs.zls;
              settings.zls.enable_build_on_save = true;
            };
          }
        ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [ editor.shell.devShell ];
        packages = [ pkgs.zig ];
      };
    };
}
