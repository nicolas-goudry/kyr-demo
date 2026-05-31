{
  pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/e8e446a361172fe838243958325845d0b845c5e5.tar.gz") { },
}:

let
  pg = pkgs.postgresql_18;
  node = pkgs.nodejs_24;

  startDB = pkgs.writeShellApplication {
    name = "start-db";

    runtimeInputs = (with pkgs; [
      coreutils
      gnugrep
    ]) ++ [ pg ];

    text = ''
      PGDATA_DIR="''${PGDATA_DIR:-$PWD/.run/pg_data}";
      PGHOST="''${PGHOST:-$PWD/.run/pg_socket}";
      PGDATABASE="''${PGDATABASE:-kyr-demo-nix}";
      PGUSER="''${PGUSER:-$USER}";
      mkdir -p "$PGHOST"
      chmod 700 "$PGHOST"

      if [ ! -d "$PGDATA_DIR" ]; then
        echo "Initializing database in $PGDATA_DIR..."
        initdb -D "$PGDATA_DIR" --auth=peer
      else
        echo "Database directory already exists at $PGDATA_DIR."
      fi

      echo "Starting PostgreSQL..."
      pg_ctl -D "$PGDATA_DIR" \
        -o "-k $PGHOST -c listen_addresses='''" \
        -l "$PGDATA_DIR/logfile" \
        start || echo "Postgres is already running or failed to start."

      echo "Waiting for database to accept connections..."
      until psql -h "$PGHOST" -d postgres -c '\q' 2>/dev/null; do
        sleep 1
      done

      echo "Creating database..."
      psql -h "$PGHOST" -d postgres -f init.sql
    '';
  };
in
pkgs.mkShellNoCC {
  nativeBuildInputs = (with pkgs; [
    ffmpeg
  ])
  ++ [
    node
    pg
    startDB
  ];

  shellHook = ''
    export PGDATA_DIR="$PWD/.run/pg_data"
    export PGHOST="$PWD/.run/pg_socket"
    export PGUSER="$USER"
    export PGDATABASE="kyr-demo"

    npm ci

    # Print a welcoming message
    echo -e "\n\033[1;32m🚀 Welcome to the Media Analysis Dev Environment!\033[0m\n"

    echo -e "\033[1;34m🛠️  Available Tools:\033[0m"
    echo -e "  • Node.js $(node -v)"
    echo -e "  • PostgreSQL"
    echo -e "  • FFmpeg"

    echo -e "\n\033[1;34m📜 Quick Commands:\033[0m"
    echo -e "  • \033[1;33mstart-db\033[0m   -> Initializes and starts the local PostgreSQL database via socket"
    echo -e "  • \033[1;33mnpm start\033[0m  -> Starts the Fastify server"

    echo -e "\n\033[1;30mInstalling Node dependencies (\`npm ci\`)...\033[0m"
    npm ci
    echo -e "\n\033[1;32m✨ Environment ready!\033[0m\n"
  '';
}
