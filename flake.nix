{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        nixosConfigurations.demoConfig = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ({ config, pkgs, ... }: {
              services.nginx = {
                enable = true;
                defaultHTTPListenPort = 3333;
                virtualHosts.default = {
                  default = true;
                  root = "/";
                };
              };
            })
          ];
        };

        packages.default = pkgs.dockerTools.buildLayeredImage {
          name = "demoserver";
          contents = [ self.nixosConfigurations.demoConfig.config.syste.build.toplevel ];
          config = {
            Cmd = [
              "${self.nixosConfigurations.demoConfig.config.syste.build.toplevel}/init"
            ];
            ExposedPorts = { "3333/tcp" = { }; };
          };
        };
      });
}
