{
  description = "DID PLC Method - A self-authenticating DID method with TypeScript reference implementation and directory server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Node.js version specified in package.json engines
        nodejs = pkgs.nodejs;
        pnpm = pkgs.pnpm;

        # Common dependencies for building
        buildInputs = with pkgs; [
          nodejs
          pnpm
          python3
          pkg-config
        ];

        # Runtime dependencies
        runtimeDeps = with pkgs; [
          postgresql_15
        ];

        # Build the project
        did-plc-server = pkgs.stdenv.mkDerivation {
          pname = "did-plc-server";
          version = "0.0.1";

          src = ./.;

          nativeBuildInputs = buildInputs;

          configurePhase = ''
            export HOME=$TMPDIR
            pnpm config set store-dir $TMPDIR/pnpm-store
            pnpm install --frozen-lockfile
          '';

          buildPhase = ''
            pnpm build
          '';

          installPhase = ''
            mkdir -p $out/lib/did-plc
            cp -r . $out/lib/did-plc/

            # Create wrapper script for the server
            mkdir -p $out/bin
            cat > $out/bin/did-plc-server <<EOF
#!/bin/sh
cd $out/lib/did-plc/packages/server
exec ${nodejs}/bin/node dist/bin.js "\$@"
EOF
            chmod +x $out/bin/did-plc-server

            # Create wrapper script for CLI tools
            cat > $out/bin/did-plc-create <<EOF
#!/bin/sh
cd $out/lib/did-plc/packages/server
exec ${nodejs}/bin/npx ts-node bin/did-create.ts "\$@"
EOF
            chmod +x $out/bin/did-plc-create
          '';

          meta = with pkgs.lib; {
            description = "DID PLC Directory Service";
            homepage = "https://web.plc.directory";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.all;
          };
        };

      in
      {
        # Default package
        packages.default = did-plc-server;
        packages.did-plc-server = did-plc-server;

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = buildInputs ++ runtimeDeps ++ (with pkgs; [
            # Development tools
            docker
            docker-compose

            # Database tools
            postgresql_15

            # Additional development dependencies
            git
            curl
            jq
          ]);

          shellHook = ''
            echo "🚀 DID PLC Development Environment"
            echo ""
            echo "Available commands:"
            echo "  pnpm install       - Install dependencies"
            echo "  pnpm build         - Build all packages"
            echo "  pnpm test          - Run tests"
            echo "  pnpm --filter @did-plc/server start - Start the server"
            echo ""
            echo "Database setup:"
            echo "  cd packages/server && docker-compose -f pg/docker-compose.yaml up -d"
            echo "  export DATABASE_URL='postgres://pg:password@localhost:5432/postgres'"
            echo ""
            echo "Environment variables:"
            echo "  PORT=3000 (default)"
            echo "  DATABASE_URL - PostgreSQL connection string"
            echo "  LOG_LEVEL=debug (optional)"
            echo ""

            # Set default environment variables
            export PORT=''${PORT:-3000}
            export LOG_LEVEL=''${LOG_LEVEL:-info}
            export NODE_ENV=''${NODE_ENV:-development}

            # Ensure pnpm is available
            if ! command -v pnpm &> /dev/null; then
              echo "Installing pnpm globally..."
              npm install -g pnpm
            fi
          '';
        };

        # App for running the server
        apps.default = {
          type = "app";
          program = "${did-plc-server}/bin/did-plc-server";
        };

        apps.server = {
          type = "app";
          program = "${did-plc-server}/bin/did-plc-server";
        };

        # NixOS service module (optional)
        nixosModules.did-plc-server = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.services.did-plc-server;
          in {
            options.services.did-plc-server = {
              enable = mkEnableOption "DID PLC Directory Server";

              port = mkOption {
                type = types.port;
                default = 3000;
                description = "Port to listen on";
              };

              databaseUrl = mkOption {
                type = types.str;
                description = "PostgreSQL database URL";
              };

              logLevel = mkOption {
                type = types.enum [ "error" "warn" "info" "debug" ];
                default = "info";
                description = "Log level";
              };

              user = mkOption {
                type = types.str;
                default = "did-plc";
                description = "User to run the service as";
              };

              group = mkOption {
                type = types.str;
                default = "did-plc";
                description = "Group to run the service as";
              };
            };

            config = mkIf cfg.enable {
              systemd.services.did-plc-server = {
                description = "DID PLC Directory Server";
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" "postgresql.service" ];

                environment = {
                  PORT = toString cfg.port;
                  DATABASE_URL = cfg.databaseUrl;
                  LOG_LEVEL = cfg.logLevel;
                  NODE_ENV = "production";
                };

                serviceConfig = {
                  Type = "simple";
                  User = cfg.user;
                  Group = cfg.group;
                  ExecStart = "${did-plc-server}/bin/did-plc-server";
                  Restart = "always";
                  RestartSec = "10s";

                  # Security settings
                  NoNewPrivileges = true;
                  PrivateTmp = true;
                  ProtectSystem = "strict";
                  ProtectHome = true;
                  ReadWritePaths = [ "/var/lib/did-plc" ];
                };
              };

              users.users.${cfg.user} = {
                isSystemUser = true;
                group = cfg.group;
                description = "DID PLC server user";
                home = "/var/lib/did-plc";
                createHome = true;
              };

              users.groups.${cfg.group} = {};
            };
          };
      });
}