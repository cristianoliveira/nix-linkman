{ config, pkgs, lib, ... }: let
  cfg = config.services.linkman;

  # Ensure the target directories exist
  createTargetDirs  = builtins.concatStringsSep "\n" (
    map (d: "mkdir -p ${d}") cfg.targets
  );

  # Create a list of links to manage
  links = builtins.concatStringsSep "\n" (
    map (d: "ln -sf ${d.source} ${d.target}") cfg.links
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
    ]) cfg.links
  );

  linkScript = pkgs.writeShellScriptBin "nix-linkman" ''
    #!/bin/sh

    set -e

    CMD_ARG="$1"
    function create_target_dirs {
      ${createTargetDirs}
    }
    function apply_links {
      ${links}
    }
    function remove_links {
      ${removeLinks}
    }

    # Create the target directories if they don't exist
    create_target_dirs

    # Remove existing symbolic links
    remove_links

    # if CMD_ARG is "serve" then run the service loop
    if [ "$CMD_ARG" = "serve" ]; then
      echo "Linkman service started. Managing links..."
    else
      apply_links

      echo "Linkman script executed. Use 'serve' to run the service."
      exit 0
    fi

    # Recreate symbolic links for dotfiles from time to time
    # To ensure that the links are always up to date
    while true; do
      apply_links
      sleep ${toString cfg.checkInterval}
    done
  '';
in
{
  options.services.linkman = with lib; {
    enable = mkEnableOption "the linkman service";

    targets = mkOption {
      type = types.listOf types.str;
      example = [ "/path/to/folder1" "/path/to/folder2" ];
      description = "Required: List of target directories to ensure exist";
    };

    links = mkOption {
      type = types.listOf types.attrs;
      example = [ { source = /path/to/src; target = "/path/to/tgt"; } ];
      description = "Required: List of links to manage";
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

    checkInterval = mkOption {
      type = types.int;
      default = 300;
      description = "Seconds between link updates";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ linkScript ];

    systemd.services."linkman-${cfg.user}" = {
      enable = cfg.enable;
      description = "Link management for ${cfg.user}";

      wantedBy = [ "multi-user.target" ];

      script = ''
        #!/bin/sh

        ${linkScript}/bin/nix-linkman serve
      '';

      serviceConfig = {
        User = "${cfg.user}";
        Group = "users";
        Type = "simple";
        Restart = "always";
        RestartSec = "${toString cfg.checkInterval}s";
      };
    };
  };
}
