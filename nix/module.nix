{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    types
    mkEnableOption
    mkOption
    mkIf
    literalExpression
    ;
  cfg = config.services.infra-keyval;

  package = pkgs.callPackage ./package.nix { };
in
{
  options = {
    services.infra-keyval = {
      enable = mkEnableOption (lib.mdDoc "infra-keyval");

      port = mkOption {
        type = types.port;
        default = 5000;
        description = lib.mdDoc "Port where infra-keyval listens.";
      };

      user = mkOption {
        type = types.str;
        default = "infra-keyval";
        description = lib.mdDoc "User account under which infra-keyval runs.";
      };

      group = mkOption {
        type = types.str;
        default = "infra-keyval";
        description = lib.mdDoc "Group under which infra-keyval runs.";
      };

      configureDatabase = mkEnableOption "configure postgresql database using unix sockets";

      package = mkOption {
        type = types.package;
        default = package;
        defaultText = literalExpression "pkgs.infra-keyval";
        description = lib.mdDoc ''
          infra-keyval package to use.
        '';
      };

      settings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = lib.mdDoc ''
          Structural infra-keyval configuration.
          Refer to upstream's documentation for details and supported values.
        '';
        example = literalExpression ''
          {
            LISTEN_ADDR = "[::1]:3000";
            DB_URL = "postgresql:://localhost:5432";
          }
        '';
      };

      settingsFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = lib.mdDoc ''
          File containing settings to pass onto infra-keyval.
          This is useful for secret configuration that should not be copied
          into the world-readable Nix store, for example, WRITE_TOKEN.

          File must be in the following format:

          ```
          KEY=value
          ```
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.postgresql = mkIf cfg.configureDatabase {
      enable = true;
      ensureDatabases = [ cfg.user ];
      ensureUsers = [
        {
          name = cfg.user;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };

    systemd.services.infra-keyval = {
      description = "infra-keyval";
      after = [ "network.target" ] ++ lib.optionals cfg.configureDatabase [ "postgresql.target" ];
      requires = lib.optionals cfg.configureDatabase [ "postgresql.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        LISTEN_ADDR = "[::1]:${toString cfg.port}";
      }
      // (lib.optionalAttrs cfg.configureDatabase {
        DB_URL = "postgresql:///${cfg.user}?host=/run/postgresql";
      })
      // cfg.settings;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${lib.getExe cfg.package}";
        Restart = "on-failure";
        EnvironmentFile = [ cfg.settingsFile ];

        # systemd hardening
        NoNewPrivileges = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = !config.boot.isContainer;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        ProtectControlGroups = !config.boot.isContainer;
        ProtectHostname = true;
        ProtectKernelLogs = !config.boot.isContainer;
        ProtectKernelModules = !config.boot.isContainer;
        ProtectKernelTunables = !config.boot.isContainer;
        LockPersonality = true;
        PrivateTmp = !config.boot.isContainer;
        PrivateDevices = true;
        PrivateUsers = true;
        RemoveIPC = true;

        SystemCallFilter = [
          "~@clock"
          "~@aio"
          "~@chown"
          "~@cpu-emulation"
          "~@debug"
          "~@keyring"
          "~@memlock"
          "~@module"
          "~@mount"
          "~@obsolete"
          "~@privileged"
          "~@raw-io"
          "~@reboot"
          "~@setuid"
          "~@swap"
        ];
        SystemCallErrorNumber = "EPERM";
      };
    };

    users.users = mkIf (cfg.user == "infra-keyval") {
      infra-keyval = {
        isSystemUser = true;
        group = cfg.group;
      };
    };

    users.groups = mkIf (cfg.group == "infra-keyval") {
      infra-keyval = { };
    };
  };
}
