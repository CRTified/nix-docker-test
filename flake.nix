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

            # Minimize config
            ({ config, pkgs, ... }: {
              imports = [
                (nixpkgs + "/nixos/modules/profiles/minimal.nix")
                (nixpkgs + "/nixos/modules/profiles/headless.nix")
              ];
              services.udisks2.enable = false;
              programs.command-not-found.enable = false;
            })

            # Demo Application
            ({ config, pkgs, ... }: {
              system.stateVersion = "23.05";

              users.users.root.password = "1234";

              networking.firewall.enable = false;

              services.iperf3 = {
                enable = true;
                verbose = true;
                port = 3333;
              };
            })
          ];
        };

        apps = {
          default = self.apps."${system}".podman;

          podman = {
            type = "app";
            program = toString (pkgs.writeShellScript "run-podman.sh" ''
              podman run \
                -ti \
                -p 3333:3333 \
                --systemd=always \
                docker-archive:${self.packages."${system}".default}
            '');
          };

          docker = {
            type = "app";
            program = toString (pkgs.writeShellScript "run-docker.sh" ''
              docker run \
                --tty \
                --interactive \
                --privileged \
                -p 3333:3333 \
                $(docker load < "${
                  self.packages."${system}".default
                }" | grep -Po '[:a-z0-9]+$')
            '');
          };
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
