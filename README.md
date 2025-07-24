# nix-linkman

A nix link manager for managing symbolic links in a Nix environment. 
This extension allow you to define a service that will create symbolic links in a specified directory,
and ensure the links are updated when the target files change.

# USAGE

To use this extension, you need to define a service in your Nix configuration.

```nix
{
  services.linkman =  let
    # Define the targets where the links will be created
    # The folders will be created if they do not exist
    targets = {
      "home" = "~/"; 
      "home-config" = "~/.config";
    };
  in {
    enable = true;
    user = "yourusername"; # Optional, defaults to root
    group = "yourgroup"; # Optional, defaults to root

    inherit targets;

    links = [
      # source is a path
      # target is a string that will be the symlink name
      { source = /path/to/linkfile; target = "${targets.home}/linkfile"; }
    ];

    # Configs
    checkInterval = 3000; # Optional, defaults 5 minutes
  };
}
```
This will create a systemd service that will manage the symbolic links defined in the `links` list.

# Example

```nix
{
  services.linkman = {
    enable = true;

    # Define the targets where the links will be created
    targets = {
      "home-config" = "~/.config";
    };

    links = [
      { source = ./tmux; target = "~/.config/tmux"; }
      { source = ./nvim; target = "~/.config/nvim"; }
    ];

    user = "jonh";
  };
}
```

That will create the following symbolic links in the user's home directory:
```
ls -la ~/.config
lrwxrwxrwx  1 jonh users   48 Jul 24 00:05 tmux -> /nix/store/lwhrs7rjs984f3jqk7d56vq8ykgs3lpv-tmux
lrwxrwxrwx  1 jonh users   49 Jul 24 00:05 nvim -> /nix/store/0v3q7x5z6f8g2j9k4c5b6v8y9z3l4m5n-nvim
```

## Installation

Using flake
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    linkman = {
      url = "github:cristianoliveira/nix-linkman";
      nixpkgs.follows = "nixpkgs";
    };
  }

  outputs = { nixpkgs, linkman, ... }: let
      system = "aarch64-linux";
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;

      modules = [
        # Import the linkman module
        linkman.nixosModules."${system}".linkman;
  
        # System
        ./nix/configuration.nix
      ];
    };
  };
}

```

# License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
