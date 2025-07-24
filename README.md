# nix-linkman

A nix link manager for managing symbolic links in a Nix environment. 
This extension allow you to define a service that will create symbolic links in a specified directory,
and ensure the links are updated when the target files change.

# USAGE

To use this extension, you need to define a service in your Nix configuration.

```nix
{
  services.linkman = {
    enable = true;
    links = [
      # source is a path
      # target is a string that will be the symlink name
      { source = /path/to/source; target = "/path/to/target"; }
    ];
    user = "yourusername"; # Optional, defaults to root
    group = "yourgroup"; # Optional, defaults to root
    # Optional, defaults to 60 seconds
    configs = {
        # Time in seconds to wait before checking for changes and updating links
        checkInterval = 3000; # Optional, defaults 5 minutes
    };

  };
}
```
This will create a systemd service that will manage the symbolic links defined in the `links` list.
```nix
# Example

```nix
{
  services.linkman = {
    enable = true;
    links = [
      { source = ./tmux; target = "./.config/tmux"; }
      { source = ./nvim; target = "./.config/nvim"; }
    ];
    user = "jonh";
    group = "users";
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
  inputs.linkman.url = "github:yourusername/nix-linkman";
  outputs = { self, nixpkgs, ... }: {
    nixosModules.linkman = import self.nixosModules.linkman;
  };
}
```

Using NixOS configuration
```nix
{
  imports = [
    ./path/to/linkman.nix
  ];
}
```

# License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
