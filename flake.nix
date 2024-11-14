{
  description = "Virtual machines repository for my NixOS flakes (public)";

  nixConfig = {
    extra-trusted-substituters = [ "https://cache.nixos.org/" ];
    extra-trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    nixfigs-helpers.url = "github:shymega/nixfigs-helpers";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      inherit (inputs) self;
      genPkgs = system: import inputs.nixpkgs { inherit system; };
      systems = [ "x86_64-linux" ];
      forEachSystem = inputs.nixpkgs.lib.genAttrs systems;
      treeFmtEachSystem =
        f: inputs.nixpkgs.lib.genAttrs systems (system: f inputs.nixpkgs.legacyPackages.${system});
      treeFmtEval = treeFmtEachSystem (
        pkgs:
        inputs.nixfigs-helpers.inputs.treefmt-nix.lib.evalModule pkgs "${inputs.nixfigs-helpers.helpers.formatter
        }"
      );
    in
    rec {
      # for `nix fmt`
      formatter = treeFmtEachSystem (pkgs: treeFmtEval.${pkgs.system}.config.build.wrapper);
      # for `nix flake check`
      checks =
        treeFmtEachSystem (pkgs: {
          formatting = treeFmtEval.${pkgs}.config.build.wrapper;
        })
        // forEachSystem (system: {
          pre-commit-check = import "${inputs.nixfigs-helpers.helpers.checks}" {
            inherit self system;
            inherit (inputs.nixfigs-helpers) inputs;
            inherit (inputs.nixpkgs) lib;
          };
        });
      devShells = forEachSystem (
        system:
        let
          pkgs = genPkgs system;
        in
        import inputs.nixfigs-helpers.helpers.devShells { inherit pkgs self system; }
      );

      oci = rec { };
      libvirt = rec { };
      nspawn = rec { };
    };
}
