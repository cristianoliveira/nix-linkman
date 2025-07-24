{ config, pkgs, lib, ... }: let
  cfg = config.services.linkman;

  # Create a list of links to manage
  links = builtins.concatStringsSep "\n" (
    map (d: "ln -sf ${d.source} ${d.target}") cfg.configs
  );

  # Attempt to remove existing symbolic links if they exist
  # if it fails, it will restore the previusly backed up link
  removeLinks = builtins.concatStringsSep "\n" (
    map (d: builtins.concatStringsSep " \n" [ 
      # Backup existing file
      "mv -f ${d.target} ${d.target}.bak || true"
      # Create symlink or restore backup
      "ln -sf ${d.source} ${d.target} || mv -f ${d.target}.bak ${d.target}"
      # Remove backup file
      "rm -f ${d.target}.bak || true"
    ]) cfg.configs
  );

  # Create the target directories if they don't exist
  createTargetDirs = builtins.concatStringsSep "\n" (
    map (d: "mkdir -p $(dirname ${d.target})") cfg.configs
  );

  # Build a small script that iterates over links
  linkScript = pkgs.writeShellScriptBin "nix-linkman" ''
    #!/bin/sh

    set -e

    # Create the target directories if they don't exist
    ${createTargetDirs}

    mkdir -p /tmp/dotfiles

    # Remove existing symbolic links
    ${removeLinks}

    while true; do
      # Recreate symbolic links for dotfiles from time to time
      # To ensure that the links are always up to date
      sleep ${toString cfg.restartIntervalInSecs}

      ${links}
    done
  '';
in
{
  options.services.linkman = with lib; {
    enable = mkEnableOption "the linkman service";
    links = mkOption {
      type = types.listOf types.attrs;
      default = [];
      example = [ { source = /path/to/src; target = "/path/to/tgt"; } ];
      description = "List of links to manage";
    };
    user = mkOption {
      type = types.str;
      default = "root";
      description = "User to own the links";
    };
    group = mkOption {
      type = types.str;
      default = "root";
      description = "Group to own the links";
    };
    configs.checkInterval = mkOption {
      type = types.int;
      default = 300;
      description = "Seconds between link updates";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ linkScript ];

    systemd.services."dotfiles-${cfg.user}" = {
      enable = cfg.enable;
      description = "Dotfiles management for ${cfg.user}";

      wantedBy = [ "multi-user.target" ];

      script = ''
        #!/bin/sh

        ${linkScript}/bin/nix-linkman
      '';

      serviceConfig = {
        User = "${cfg.user}";
        Group = "users";
        Type = "simple";
        Restart = "always";
        RestartSec = "${toString cfg.restartIntervalInSecs}s";
      };
    };
  };
}
