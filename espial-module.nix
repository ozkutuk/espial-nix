{ pkgs, lib, config, ... }:

with lib;

let
  cfg = config.services.espial;

  stateDir = "/var/lib/espial";
  databasePath = "${stateDir}/espial.sqlite3";

  dataFiles = pkgs.stdenvNoCC.mkDerivation {
    pname = "espial-data";
    version = cfg.package.version;
    src = cfg.package.src;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -r static config "$out"

      runHook postInstall
    '';
  };

  migration = pkgs.writeShellScriptBin "espial-migration" ''
    ${cfg.package}/bin/migration $@
  '';

in {
  options.services.espial = {
    enable =
      mkEnableOption "Espial, an open-source, web-based bookmarking server.";

    package = mkOption {
      type = types.package;
      default = pkgs.haskellPackages.espial;
      defaultText = "pkgs.haskellPackages.espial";
      description = "Set version of espial package to use.";
    };

    user = mkOption {
      type = types.str;
      default = "espial";
      description = "User account under which Espial runs.";
    };

    group = mkOption {
      type = types.str;
      default = "espial";
      description = "Group under which Espial runs.";
    };

    database = {
      user = mkOption {
        type = types.str;
        description = "Username";
      };

      passwordFile = mkOption {
        type = types.path;
        description = "password file";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Open the default ports in the firewall for the Espial server.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ migration ];

    systemd.services.espial = {
      description = "Espial server daemon.";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      restartIfChanged = true;

      environment = {
        SQLITE_DATABASE = databasePath;
        STATIC_DIR = "${stateDir}/static";
      };

      serviceConfig = {
        StateDirectory = "espial";
        WorkingDirectory = stateDir;
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/espial";
        ExecStartPre = [
          # Run with escalated privileges because we need to read the
          # password file.
          ("+" + pkgs.writeShellScript "setup-espial" ''
            cp -r ${dataFiles}/static ${dataFiles}/config ${stateDir}
            ${cfg.package}/bin/migration -- createdb --conn ${databasePath}
            chown -R ${cfg.user}:${cfg.group} ${stateDir}
            chmod -R 755 ${stateDir}
            ${cfg.package}/bin/migration -- createuser --conn ${databasePath} --userName ${cfg.database.user} --userPasswordFile ${cfg.database.passwordFile}
          '')
        ];
        Restart = "always";
      };
    };

    users.users = mkIf (cfg.user == "espial") {
      espial = {
        group = cfg.group;
        uid = 325;
        # uid = config.ids.uids.espial;
      };
    };

    users.groups = mkIf (cfg.group == "espial") {
      espial.gid = 325;
      # espial.gid = config.ids.gids.espial;
    };

    networking.firewall = mkIf cfg.openFirewall { allowedTCPPorts = [ 3000 ]; };
  };

  meta.maintainers = with lib.maintainers; [ ozkutuk ];
}
