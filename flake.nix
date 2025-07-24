{
  description = "nix link manager for managing symbolic links in a Nix environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, ... }:
    {
      # Expose the NixOS module for flake users
      nixosModules = {
        linkman = ./nix/linkman.nix;
      };
    };
}
