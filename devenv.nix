{
  pkgs,
  config,
  ...
}:

{
  # Configuration automatique du language JavaScript (50+ langages supportés)
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_24;

    npm = {
      enable = true;
      install.enable = true;
    };
  };

  # Paquets "unitaires" disponibles dans l'environnement
  packages = with pkgs; [
    git
    ffmpeg
  ];

  # Script d'activation
  enterShell = ''
    echo -e "\n\033[1;32m🚀 Welcome to the Media Analysis Dev Environment!\033[0m\n"
    echo
    echo "Run the server with 'devenv up'."
  '';

  # Variables d'environnements
  env.PGDATABASE = "kyr-demo";

  # Base de données PostgreSQL avec initialisation automatique
  services.postgres = {
    enable = true;
    package = pkgs.postgresql_17;

    initialDatabases = [
      {
        name = config.env.PGDATABASE;
        schema = ./init.sql;
      }
    ];
  };

  # Processus (assimilé service) pour exécuter le serveur Node.js, avec health check et restart on-watch
  processes.run-server = {
    exec = "npm start";

    ready = {
      initial_delay = 1;

      http.get = {
        path = "/health";
        port = 3000;
      };
    };

    watch = {
      paths = [ ./index.js ];
    };
  };

  # Configuration du formatteur de code treefmt (100+ formatteurs builtin)
  treefmt = {
    enable = true;

    config.programs = {
      nixfmt.enable = true;
      prettier.enable = true;

      sql-formatter = {
        enable = true;
        dialect = "postgresql";
      };
    };
  };

  # Hooks Git pre-commit (100+ intégrations)
  git-hooks.hooks = {
    treefmt.enable = true;
  };
}
