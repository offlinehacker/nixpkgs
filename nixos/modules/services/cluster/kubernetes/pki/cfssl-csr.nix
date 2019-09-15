{ config, lib, ... }:

with lib;

let
  filterEmpty = filterAttrsRecursive (_: v: v != null && v != {} && v != []);

in {
  imports = [ ./csr.nix ];

  options = {
    ca.expiry = mkOption {
      description = "CA certificate expiry time";
      type = types.nullOr types.str;
      default = null;
    };

    cfssl = {
      generated = mkOption {
        description = "Generated cfssl csr attrs.";
        type = types.attrs;
        default = filterEmpty (filterEmpty {
          key = {
            algo = config.key.algo;
            size = config.key.size;
          };
          ca = {
            expiry = config.ca.expiry;
          };
          CN = config.CN;
          hosts = config.hosts;
          names = map (v: filterAttrs (_: v: v != null) {
            inherit (v) C L O OU ST emailAddress;
          }) (if config.names == null then [] else config.names);
        });
        internal = true;
      };

      file = mkOption {
        description = "Generated cfssl csr json file.";
        type = types.package;
        default = builtins.toFile "${config.name}-csr.json" (builtins.toJSON config.cfssl.generated);
        internal = true;
      };
    };
  };
}
