{
  description = "nix link manager for managing symbolic links in a Nix environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, utils, ... }:
    utils.lib.eachDefaultSystem (_: {
        # Expose the NixOS module for flake users
        nixosModules = { 
          linkman = ./nix/linkman.nix;
        };
      });
}
