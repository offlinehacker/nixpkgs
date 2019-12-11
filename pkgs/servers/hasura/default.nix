{ haskellPackages, haskell }:

with haskell.lib;

let
  pkgs = haskellPackages.override {
    overrides = self: super: {
      graphql-engine = self.callPackage ./graphql-engine.nix { };
      cli = self.callPackage ./cli.nix { };

      ci-info = self.callPackage ./ci-info.nix { };
      graphql-parser = self.callPackage ./graphql-parser.nix { };
      pg-client = self.callPackage ./pg-client.nix { };
      stm-hamt = doJailbreak (unmarkBroken super.stm-hamt);
      superbuffer = doJailbreak (unmarkBroken super.superbuffer);
      Spock-core = unmarkBroken super.Spock-core;
      stm-containers = unmarkBroken super.stm-containers;
    };
  };
in {
  inherit (pkgs) graphql-engine cli;
}
