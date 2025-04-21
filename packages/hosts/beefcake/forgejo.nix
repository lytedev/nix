{
  config,
  pkgs,
  lib,
  ...
}:
let
  anubis = {
    user = "anubis";
    group = "anubis";
    dir = "/storage/anubis";
    port = 8529;
  };
  runnerCount = 16;
  theme = pkgs.fetchzip {
    url = "https://github.com/catppuccin/gitea/releases/download/v1.0.1/catppuccin-gitea.tar.gz";
    sha256 = "sha256-et5luA3SI7iOcEIQ3CVIu0+eiLs8C/8mOitYlWQa/uI=";
  };
  logos = {
    png = pkgs.fetchurl {
      url = "https://lyte.dev/icon.png";
      sha256 = "sha256-o/iZDohzXBGbpJ2PR1z23IF4FZignTAK88QwrfgTwlk=";
    };
    svg = pkgs.fetchurl {
      url = "https://lyte.dev/img/logo.svg";
      sha256 = "sha256-G9leVXNanoaCizXJaXn++JzaVcYOgRc3dJKhTQsMhVs=";
    };
    svg-with-background = pkgs.fetchurl {
      url = "https://lyte.dev/img/logo-with-background.svg";
      sha256 = "sha256-CdMTRXoQ3AI76aHW/sTqvZo1q/0XQdnQs9V1vGmiffY=";
    };
  };
  forgejoCustomCss = pkgs.writeText "iosevkalyte.css" ''
    @font-face {
      font-family: ldiosevka;
      font-style: normal;
      font-weight: 300;
      src: local("Iosevka"), url("//lyte.dev/font/iosevkalytewebmin/iosevkalyteweb-regular.subset.woff2");
      font-display: swap
    }

    @font-face {
      font-family: ldiosevka;
      font-style: italic;
      font-weight: 300;
      src: local("Iosevka"), url("//lyte.dev/font/iosevkalytewebmin/iosevkalyteweb-italic.subset.woff2");
      font-display: swap
    }

    @font-face {
      font-family: ldiosevka;
      font-style: italic;
      font-weight: 500;
      src: local("Iosevka"), url("//lyte.dev/font/iosevkalytewebmin/iosevkalyteweb-bolditalic.woff2");
      font-display: swap
    }
    :root {
      --fonts-monospace: ldiosevka, ui-monospace, SFMono-Regular, "SF Mono", Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace, var(--fonts-emoji);
    }
  '';
  forgejoCustomHeaderTmpl = pkgs.writeText "header.tmpl" ''
    <link rel="stylesheet" href="/assets/css/iosevkalyte.css" />
    <script async="" defer="" data-domain="git.lyte.dev" src="https://a.lyte.dev/js/script.js"></script>
  '';
  forgejoCustomHomeTmpl = pkgs.writeText "home.tmpl" ''
    {{template "base/head" .}}
    <div role="main" aria-label="{{if .IsSigned}}{{ctx.Locale.Tr "dashboard"}}{{else}}{{ctx.Locale.Tr "home"}}{{end}}" class="page-content home">
    	<div class="tw-mb-8 tw-px-8">
    		<div class="center">
    			<img class="logo" width="220" height="220" src="{{AssetUrlPrefix}}/img/logo.svg" alt="{{ctx.Locale.Tr "logo"}}">
    			<div class="hero">
    				<h1 class="ui icon header title">
              {{AppDisplayName}}
    				</h1>
    				<h2>{{ctx.Locale.Tr "startpage.app_desc"}}</h2>
    			</div>
    		</div>
    	</div>
    	<div class="ui stackable middle very relaxed page grid">
    		<div class="eight wide center column">
    			<h1 class="hero ui icon header">
    				{{svg "octicon-flame"}} {{ctx.Locale.Tr "startpage.install"}}
    			</h1>
    			<p class="large">
    				{{ctx.Locale.Tr "startpage.install_desc" "https://forgejo.org/download/#installation-from-binary" "https://forgejo.org/download/#container-image" "https://forgejo.org/download"}}
    			</p>
    		</div>
    		<div class="eight wide center column">
    			<h1 class="hero ui icon header">
    				{{svg "octicon-device-desktop"}} {{ctx.Locale.Tr "startpage.platform"}}
    			</h1>
    			<p class="large">
    				{{ctx.Locale.Tr "startpage.platform_desc"}}
    			</p>
    		</div>
    	</div>
    	<div class="ui stackable middle very relaxed page grid">
    		<div class="eight wide center column">
    			<h1 class="hero ui icon header">
    				{{svg "octicon-rocket"}} {{ctx.Locale.Tr "startpage.lightweight"}}
    			</h1>
    			<p class="large">
    				{{ctx.Locale.Tr "startpage.lightweight_desc"}}
    			</p>
    		</div>
    		<div class="eight wide center column">
    			<h1 class="hero ui icon header">
    				{{svg "octicon-code"}} {{ctx.Locale.Tr "startpage.license"}}
    			</h1>
    			<p class="large">
    				{{ctx.Locale.Tr "startpage.license_desc" "https://forgejo.org/download" "https://codeberg.org/forgejo/forgejo"}}
    			</p>
    		</div>
    	</div>
    </div>
    {{template "base/footer" .}}
  '';
in
{
  # systemd.tmpfiles.settings = {
  #   "10-forgejo" = {
  #     "/storage/forgejo" = {
  #       "d" = {
  #         mode = "0700";
  #         user = "forgejo";
  #         group = "nogroup";
  #       };
  #     };
  #   };
  # };
  services.forgejo = {
    enable = true;
    package = pkgs.unstable-packages.forgejo;
    stateDir = "/storage/forgejo";
    settings = {
      DEFAULT = {
        APP_NAME = "git.lyte.dev";
      };
      server = {
        ROOT_URL = "https://git.lyte.dev";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3088;
        DOMAIN = "git.lyte.dev";
      };
      migrations = {
        ALLOWED_DOMAINS = "*.github.com,github.com,gitlab.com,*.gitlab.com";
      };
      actions = {
        ENABLED = true;
      };
      service = {
        DISABLE_REGISTRATION = true;
      };
      session = {
        COOKIE_SECURE = true;
      };
      log = {
        # LEVEL = "Debug";
      };
      security = {
        REVERSE_PROXY_TRUSTED_PROXIES = "127.0.0.0/8,::1/128";
      };
      ui = {
        THEMES = "catppuccin-mocha-sapphire,forgejo-auto,forgejo-light,forgejo-dark";
        DEFAULT_THEME = "catppuccin-mocha-sapphire";
      };
      indexer = {
        REPO_INDEXER_ENABLED = "true";
        REPO_INDEXER_PATH = "indexers/repos.bleve";
        MAX_FILE_SIZE = "1048576";
        # REPO_INDEXER_INCLUDE =
        REPO_INDEXER_EXCLUDE = "resources/bin/**";
      };
      "markup.asciidoc" = {
        ENABLED = true;
        NEED_POSTPROCESS = true;
        FILE_EXTENSIONS = ".adoc,.asciidoc";
        RENDER_COMMAND = "${pkgs.asciidoctor}/bin/asciidoctor --embedded --safe-mode=secure --out-file=- -";
        IS_INPUT_FILE = false;
      };
    };
    lfs = {
      enable = true;
    };
    dump = {
      enable = false;
    };
    database = {
      # TODO: move to postgres?
      type = "sqlite3";
    };
  };
  services.restic.commonPaths = [
    config.services.forgejo.stateDir
  ];
  sops.secrets = {
    "forgejo-runner.env" = {
      mode = "0400";
    };
  };

  systemd.services =
    lib.genAttrs (builtins.genList (n: "gitea-runner-beefcake${builtins.toString n}") runnerCount)
      (name: {
        after = [ "sops-nix.service" ];
      })
    // {
      forgejo = {
        preStart = lib.mkAfter ''
          rm -rf ${config.services.forgejo.stateDir}/custom/public
          mkdir -p ${config.services.forgejo.stateDir}/custom/public/
          mkdir -p ${config.services.forgejo.stateDir}/custom/public/assets/
          mkdir -p ${config.services.forgejo.stateDir}/custom/public/assets/img/
          mkdir -p ${config.services.forgejo.stateDir}/custom/public/assets/css/
          mkdir -p ${config.services.forgejo.stateDir}/custom/templates/custom/
          ln -sf ${logos.png} ${config.services.forgejo.stateDir}/custom/public/assets/img/logo.png
          ln -sf ${logos.svg} ${config.services.forgejo.stateDir}/custom/public/assets/img/logo.svg
          ln -sf ${logos.png} ${config.services.forgejo.stateDir}/custom/public/assets/img/favicon.png
          ln -sf ${logos.svg-with-background} ${config.services.forgejo.stateDir}/custom/public/assets/img/favicon.svg
          ln -sf ${theme}/theme-catppuccin-mocha-sapphire.css ${config.services.forgejo.stateDir}/custom/public/assets/css/
          ln -sf ${forgejoCustomCss} ${config.services.forgejo.stateDir}/custom/public/assets/css/iosevkalyte.css
          ln -sf ${forgejoCustomHeaderTmpl} ${config.services.forgejo.stateDir}/custom/templates/custom/header.tmpl
          ln -sf ${forgejoCustomHomeTmpl} ${config.services.forgejo.stateDir}/custom/templates/home.tmpl
        '';
      };
    };

  # gitea-runner-beefcake.after = [ "sops-nix.service" ];

  services.gitea-actions-runner = {
    # TODO: simple git-based automation would be dope? maybe especially for
    # mirroring to github super easy?
    package = pkgs.forgejo-runner;

    instances =
      lib.genAttrs (builtins.genList (n: "beefcake${builtins.toString n}") runnerCount)
        (name: {
          enable = true;
          name = "beefcake";
          url = "https://git.lyte.dev"; # TODO: get from nix config?
          settings = {
            container = {
              # use the shared network which is bridged by default
              # this lets us hit git.lyte.dev just fine
              # network = "podman";
              network = "host";
            };
          };
          labels = [
            # type ":host" does not depend on docker/podman/lxc
            # "beefcake:host"
            "beefcake:host"
            "nixos-host:host"
            # "podman"
            # "nix-2.24.12:docker://git.lyte.dev/lytedev/nix:forgejo-actions-container-v3-nix-v2.24.12"
            # "nix-latest:docker://git.lyte.dev/lytedev/nix:forgejo-actions-container-latest"
          ];
          tokenFile = config.sops.secrets."forgejo-runner.env".path;
          hostPackages = with pkgs; [
            nix
            bash
            coreutils
            curl
            gawk
            gitMinimal
            gnused
            nodejs
            gnutar # needed for cache action
            wget
          ];
        });
  };
  # environment.systemPackages = with pkgs; [nodejs];
  # TODO: goes through anubis now
  # services.caddy.virtualHosts."git.lyte.dev" = {
  #   extraConfig = ''
  #     reverse_proxy :${toString config.services.forgejo.settings.server.HTTP_PORT} {
  #       header_up X-Real-Ip {remote_host}
  #     }
  #   '';
  # };
  services.caddy.virtualHosts."http://git.beefcake.lan" = {
    extraConfig = ''
      reverse_proxy :${toString config.services.forgejo.settings.server.HTTP_PORT}
    '';
  };

  users.groups.${anubis.group} = { };
  users.users.${anubis.user} = {
    isSystemUser = true;
    createHome = false;
    home = anubis.dir;
    group = anubis.group;
    linger = true;
  };
  # systemd.services.podman-anubis.serviceConfig = {
  #   User = user;
  #   Group = user;
  # };
  systemd.tmpfiles.settings =
    let
      inherit (anubis) user group dir;
    in
    {
      "10-${user}" = {
        "${dir}" = {
          "d" = {
            mode = "0770";
            user = user;
            group = group;
          };
        };
      };
    };
  virtualisation.oci-containers.containers.forgejo-anubis =
    let
      inherit (anubis) port;
    in
    {
      autoStart = true;
      image = "ghcr.io/techarohq/anubis:latest"; # TODO: set specific version
      extraOptions = [ "--network=host" ];
      # user = "${toString user}:${toString config.users.groups.${anubis.group}.gid}";
      environment = {
        BIND = ":${toString port}";
        DIFFICULTY = "4";
        METRICS_BIND = "127.0.0.1:9091";
        SERVE_ROBOTS_TXT = "true";
        TARGET = "http://127.0.0.1:${toString config.services.forgejo.settings.server.HTTP_PORT}";
        POLICY_FNAME = "/data/cfg/botPolicy.json";
      };
      ports = [ "127.0.0.1:${toString port}:${toString port}" ];
      volumes = [
        "${./anubis-policy.json}:/data/cfg/botPolicy.json:ro"
      ];
    };
  services.caddy.virtualHosts."git.lyte.dev" = {
    extraConfig = ''
      reverse_proxy :${toString anubis.port} {
        header_up X-Real-Ip {remote_host}
      }
    '';
  };
}
