{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Garage initialization script - makes setup reproducible
  garageInit = pkgs.writeShellScript "garage-init" ''
    set -euo pipefail
    GARAGE="${pkgs.garage}/bin/garage"

    echo "Waiting for Garage to be ready..."
    for i in $(seq 1 30); do
      if $GARAGE status 2>/dev/null | grep -q "ID"; then
        echo "Garage is ready"
        break
      fi
      sleep 1
    done

    # Check if layout is configured
    LAYOUT=$($GARAGE layout show 2>&1 || true)
    if echo "$LAYOUT" | grep -q "No nodes"; then
      echo "Configuring Garage layout..."
      NODE_ID=$($GARAGE status | grep -oP '[a-f0-9]{64}' | head -1)
      if [ -n "$NODE_ID" ]; then
        $GARAGE layout assign -z dc1 -c 100G "$NODE_ID"
        # Get current layout version and apply next
        CURRENT_VERSION=$($GARAGE layout show | grep -oP 'version \K[0-9]+' | head -1 || echo "0")
        NEXT_VERSION=$((CURRENT_VERSION + 1))
        $GARAGE layout apply --version "$NEXT_VERSION"
        echo "Layout configured"
      fi
    else
      echo "Layout already configured"
    fi

    # Create key if not exists
    KEY_FILE="/var/lib/happy/garage-key"
    if ! $GARAGE key list | grep -q "happy-key"; then
      echo "Creating Garage key..."
      KEY_OUTPUT=$($GARAGE key create happy-key)
      KEY_ID=$(echo "$KEY_OUTPUT" | grep -oP 'GK[a-f0-9]+')
      SECRET=$(echo "$KEY_OUTPUT" | grep -oP 'Secret key: \K[a-f0-9]+')
      mkdir -p /var/lib/happy
      echo "S3_ACCESS_KEY=$KEY_ID" > "$KEY_FILE"
      echo "S3_SECRET_KEY=$SECRET" >> "$KEY_FILE"
      chmod 400 "$KEY_FILE"
      chown happy:happy "$KEY_FILE"
      echo "Key created and saved to $KEY_FILE"
    else
      echo "Key already exists"
    fi

    # Create bucket if not exists
    if ! $GARAGE bucket list | grep -q "happy"; then
      echo "Creating bucket..."
      $GARAGE bucket create happy
      $GARAGE bucket allow --read --write happy --key happy-key
      echo "Bucket created and permissions granted"
    else
      echo "Bucket already exists"
    fi

    echo "Garage initialization complete"
  '';

  # Database migration script - extracts schema from container at runtime
  dbMigrate = pkgs.writeShellScript "happy-db-migrate" ''
    set -euo pipefail
    echo "Running database migrations..."

    # Check if we can connect to postgres
    for i in $(seq 1 30); do
      if ${pkgs.postgresql}/bin/psql -U happy -d happy -c "SELECT 1" >/dev/null 2>&1; then
        echo "PostgreSQL is ready"
        break
      fi
      sleep 1
    done

    # Run Prisma migrations using the schema already in the container
    ${pkgs.podman}/bin/podman run --rm --network=host \
      -e DATABASE_URL="postgresql://happy@localhost:5432/happy" \
      localhost/happy-server:latest \
      npx prisma db push --accept-data-loss --skip-generate || true

    echo "Database migration complete"
  '';
in
{
  # User and group for Happy
  users.groups.happy = { };
  users.users.happy = {
    isSystemUser = true;
    createHome = false;
    home = "/storage/happy";
    group = "happy";
  };

  # Storage setup
  systemd.tmpfiles.settings = {
    "10-happy" = {
      "/storage/happy" = {
        "d" = {
          mode = "0771"; # +x for others so garage can traverse
          user = "happy";
          group = "happy";
        };
      };
      "/storage/happy/garage" = {
        "d" = {
          mode = "0750";
          user = "garage";
          group = "garage";
        };
      };
      "/var/lib/happy" = {
        "d" = {
          mode = "0750";
          user = "happy";
          group = "happy";
        };
      };
    };
  };

  # Secrets for Happy
  sops.secrets = {
    "happy.env" = {
      owner = "happy";
      group = "happy";
      mode = "0400";
    };
    "garage.toml" = {
      # Use root ownership since garage user is created by the service
      mode = "0400";
    };
  };

  # Garage for Happy file storage (S3-compatible, simpler than MinIO)
  services.garage = {
    enable = true;
    package = pkgs.garage;
    settings = {
      metadata_dir = "/var/lib/garage/meta";
      data_dir = "/storage/happy/garage";
      db_engine = "sqlite";
      replication_factor = 1;
      rpc_bind_addr = "127.0.0.1:3901";
      rpc_public_addr = "127.0.0.1:3901";
      s3_api = {
        s3_region = "us-east-1"; # Match minio SDK default
        api_bind_addr = "127.0.0.1:9010";
        root_domain = ".s3.garage.localhost";
      };
      s3_web = {
        bind_addr = "127.0.0.1:3902";
        root_domain = ".web.garage.localhost";
      };
      admin = {
        api_bind_addr = "127.0.0.1:3903";
      };
    };
    environmentFile = config.sops.secrets."garage.toml".path;
  };

  # PostgreSQL database
  services.postgresql = {
    ensureDatabases = [ "happy" ];
    ensureUsers = [
      {
        name = "happy";
        ensureDBOwnership = true;
      }
    ];
  };

  # Redis for Happy
  services.redis.servers.happy = {
    enable = true;
    bind = "127.0.0.1";
    port = 6379;
  };

  # Happy server container
  # Image built locally: cd /tmp/happy-server && podman build -t localhost/happy-server:latest .
  virtualisation.oci-containers.containers.happy = {
    autoStart = true;
    image = "localhost/happy-server:latest";
    extraOptions = [
      "--network=host"
    ];
    environmentFiles = [
      config.sops.secrets."happy.env".path
    ];
    environment = {
      NODE_ENV = "production";
      PORT = "3005";
      # Use TCP connection - postgres has enableTCPIP = true
      DATABASE_URL = "postgresql://happy@localhost:5432/happy";
      REDIS_URL = "redis://127.0.0.1:6379";
      # S3/MinIO storage
      S3_HOST = "127.0.0.1";
      S3_PORT = "9010";
      S3_USE_SSL = "false";
      S3_BUCKET = "happy";
      S3_PUBLIC_URL = "https://happy.h.lyte.dev/storage";
    };
    volumes = [
      # Mount postgres socket for peer auth fallback
      "/run/postgresql:/run/postgresql:ro"
    ];
  };

  # Garage initialization service - idempotent setup of layout, key, and bucket
  systemd.services.garage-init = {
    description = "Initialize Garage for Happy";
    after = [
      "garage.service"
      "sops-nix.service"
    ];
    requires = [ "garage.service" ];
    wants = [ "sops-nix.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = garageInit;
      EnvironmentFile = config.sops.secrets."garage.toml".path;
    };
  };

  # Database migration service - runs Prisma db push
  systemd.services.happy-db-migrate = {
    description = "Run Happy database migrations";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = dbMigrate;
    };
  };

  # Ensure happy container starts after all dependencies including init services
  systemd.services.podman-happy = {
    after = [
      "postgresql.service"
      "redis-happy.service"
      "garage.service"
      "garage-init.service"
      "happy-db-migrate.service"
      "sops-nix.service"
    ];
    requires = [
      "postgresql.service"
      "redis-happy.service"
      "garage.service"
      "garage-init.service"
      "happy-db-migrate.service"
    ];
  };

  # Reverse proxy through Caddy
  services.caddy.virtualHosts."happy.h.lyte.dev" = {
    extraConfig = ''
      reverse_proxy :3005
    '';
  };

  # Tailscale-accessible endpoint (Caddy will auto-provision cert via Tailscale)
  services.caddy.virtualHosts."happy.beefcake.hare-cod.ts.net" = {
    extraConfig = ''
      reverse_proxy :3005
    '';
  };
}
