{
  description = "nix link manager for managing symbolic links in a Nix environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, utils, nixpkgs, ... }:
    utils.lib.eachDefaultSystem (system: {
        # Expose the NixOS module for flake users
        nixosModules = { 
          linkman = ./nix/linkman.nix;
        };

        devShells = let
          pkgs = import nixpkgs { inherit system; };

          configFile = pkgs.writeTextFile {
            name = ".watch.yml";
            text = pkgs.lib.generators.toYAML { } [
              {
                name = "linkman";
                run = [
                  "nix flake check"
                ];
                change = [ "**/*.nix" ];
              }
              {
                name = "git stage changed files";
                run = [
                  "git add {{relative_path}}"
                ];
                change = [ "**/*.nix" ];
              }
            ];
          };
        in {
          default = pkgs.mkShell {
            name = "linkman-shell";
            buildInputs = [
              pkgs.funzzy
            ];

            shellHook = ''
              ln -sf ${configFile} .watch.yml
            '';
          };
        }; 
      });
}
