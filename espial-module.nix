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
        DynamicUser = true;
        LoadCredential = "espial-password:${cfg.database.passwordFile}";
        ExecStart = "${cfg.package}/bin/espial";
        ExecStartPre = [
          (pkgs.writeShellScript "setup-espial" ''
            cp -r --no-preserve=mode ${dataFiles}/static ${dataFiles}/config ${stateDir}/
            ${cfg.package}/bin/migration -- createdb --conn ${databasePath}
            ${cfg.package}/bin/migration -- createuser --conn ${databasePath} --userName ${cfg.database.user} --userPasswordFile $CREDENTIALS_DIRECTORY/espial-password
          '')
        ];
        Restart = "always";
      };
    };

    networking.firewall = mkIf cfg.openFirewall { allowedTCPPorts = [ 3000 ]; };
  };

  meta.maintainers = with lib.maintainers; [ ozkutuk ];
}
