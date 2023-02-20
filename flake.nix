{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        nixosConfigurations.demoConfig = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            # Required to boot without defining file systems
            ({ config, pkgs, ... }: { boot.isContainer = true; })

            # Demo Application
            ({ config, pkgs, ... }: {
              users.users.root.password = "1234";

              networking.firewall.enable = false;
              services.nginx = {
                enable = true;
                defaultHTTPListenPort = 3333;
                virtualHosts.default = {
                  default = true;
                  root = "/";
                  extraConfig = ''
                    autoindex on;
                  '';
                };
              };
            })
          ];
        };

        apps.default = {
          type = "app";
          program = toString (pkgs.writeShellScript "run-docker.sh" ''
            docker run \
              -ti \
              --privileged \
              -p 3333:3333 \
              $(docker load < "${
                self.packages."${system}".default
              }" | grep -Po '[:a-z0-9]+$')
          '');
        };

        packages.default = pkgs.dockerTools.buildLayeredImage {
          name = "demoserver";
          config = {
            Cmd = [
              "${
                self.nixosConfigurations."${system}".demoConfig.config.system.build.toplevel
              }/init"
            ];
            ExposedPorts = { "3333/tcp" = { }; };
          };
        };
      });
}
