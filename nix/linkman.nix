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

  executeCopies = builtins.concatStringsSep "\n" (
    map (entry: let
      src = entry.source;
      dst = lib.replaceStrings [ "${cfg.targets.home}" ] [ "${cfg.targets.home}" ] entry.target;
    in ''
      ${if entry.recursive then "cp -r" else "cp"} "${src}" "${dst}"
    '') cfg.copies
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
    function execute_copies {
      ${executeCopies}
    }

    trap rollback ERR
    trap clean_up EXIT

    # Create the target directories if they don't exist
    create_target_dirs

    replace_links

    execute_copies

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
      execute_copies
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

    copies = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.path;
            description = "The path to copy (a file or directory).";
          };
          target = lib.mkOption {
            type = lib.types.str;
            description = "Where to copy it to (shell‑expanded).";
          };
          recursive = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to pass -r for directories.";
          };
        };
      });
      default = [];
      description = "A list of files or directories to copy into place.";
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
