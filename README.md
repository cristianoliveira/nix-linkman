# nix-linkman

A nix link manager for managing symbolic links in a Nix environment. 
This extension allow you to define a service that will create symbolic links in a specified directory,
and ensure the links are updated when the target files change.

## Why?

> “If you don’t know how compilers work, then you don’t know how computers work. If you’re not 100% sure whether you know how compilers work, then you don’t know how they work.” — Steve Yegge

I'm applying the same principle for nix and nixos here. I'm aware of [home-manager](https://github.com/nix-community/home-manager) existence and I know it does more than just doftiles management, but 
I want to learn more about nix before adding yet another abstraction layer

**As of now this is just a learning project, Use at your own risk. I'm using it myself but expect breaking changes**

# USAGE

To use this extension, you need to define a service in your Nix configuration.

```nix
{
  services.linkman =  let
    # Define the targets where the links will be created
    # The folders will be created if they do not exist
    targets = {
      home = "~/"; 
      home_config = "~/.config";
    };
  in {
    enable = true;
    user = "yourusername"; # Optional, defaults to root
    group = "yourgroup"; # Optional, defaults to root

    inherit targets;

    links = with targets; [
      # Example of immutable link (This will be a read-only symbolic link)
      # Declare the source as nix path, which will be a stored in the Nix store
      { source = /path/to/linkfile; target = "${home}/linkfile"; }
      
      # Example of mutable link (This is a standard symbolic link)
      # Declare the source as string, which will be resolved at runtime
      { source = "~/path/to/link"; target = "${home_config}/link"; }

      # Declare target as normal string always
    ];

    copies = with targets; [
      # Example of copying files instead of creating links
      { 
        source = /path/to/folder;
        target = "${home}/folder";
        recursive = true;
      }
      { 
        source = /path/to/otherfile;
        target = "${home}/otherfile";
        recursive = false;
      }
    ];

    # Configs
    checkInterval = 3000; # Optional, interval time in second. Default: 5 minutes.
  };
}
```
This will create a systemd service that will manage the symbolic links defined in the `links` list.

# Example

```nix
# ./nix/linkman.nix
{
  services.linkman = rec {
    enable = true;

    # Define the targets where the links will be created
    targets = {
      "home_config" = "~/.config";
    };

    links = with targets; [
      { source = ./tmux; target = "${home_config}/tmux"; }
      { source = ./nvim; target = "${home_config}/nvim"; }
      { source = "/home/jonh/dotfiles/foo"; target = "${home_config}/foo"; }
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
lrwxrwxrwx  1 jonh users   42 Jul 24 00:05 foo -> /home/jonh/dotfiles/foo
```

## Installation

Using flake
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    linkman = {
      url = "github:cristianoliveira/nix-linkman";
      inputs.nixpkgs.follows = "nixpkgs";
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
        ./nix/linkman.nix # The module we defined above
      ];
    };
  };
}

```

# License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
