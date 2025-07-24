{ config, pkgs, lib, ... }: let
  cfg = config.services.linkman;

  # Ensure the target directories exist
  targetsAsList = lib.mapAttrsToList (
    _: path: builtins.toString path
  ) cfg.targets;
  createTargetDirs  = builtins.concatStringsSep "\n" (
    map (d: "mkdir -p ${d}") targetsAsList
  );

  # Create a list of links to manage
  links = builtins.concatStringsSep "\n" (
    map (d: "ln -sfnb ${d.source} ${d.target}") cfg.links
  );

  # Attempt to remove existing symbolic links if they exist
  # if it fails, it will restore the previusly backed up link
  replaceLinks = builtins.concatStringsSep " \n" (
    map (d: builtins.concatStringsSep " \n" [ 
      "ln -sfnb ${d.source} ${d.target} || mv -f ${d.target}~ ${d.target}"
    ]) cfg.links
  );
  rollbackLinks = builtins.concatStringsSep "\n" (
    map (d: "mv -f ${d.target}~ ${d.target} || true") cfg.links
  );
  cleanUpLinks = builtins.concatStringsSep "\n" (
    map (d: "rm -f ${d.target}~") cfg.links
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
    function replace_links {
      ${replaceLinks}
    }
    function rollback {
      ${rollbackLinks}
    }
    function clean_up {
      ${cleanUpLinks}
    }

    trap rollback ERR
    trap clean_up EXIT

    # Create the target directories if they don't exist
    create_target_dirs

    # Remove existing symbolic links
    replace_links

    # if CMD_ARG is "serve" then run the service loop
    if [ "$CMD_ARG" = "serve" ]; then
      echo "Linkman service started. Managing links..."
    else
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
      type = types.attrsOf types.str;
      example = {
        "home" = "~/";
        "config" = "~/.config";
      };
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
