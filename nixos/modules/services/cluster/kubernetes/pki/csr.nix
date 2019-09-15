{ config, lib, ... }:

with lib;

let
  csrNameOptions = {
    options = {
      C = mkOption {
        description = "Certificate country.";
        type = types.nullOr types.str;
        default = null;
      };

      L = mkOption {
        description = "Certificate locality.";
        type = types.nullOr types.str;
        default = null;
      };

      O = mkOption {
        description = "Certificate organization.";
        type = types.nullOr types.str;
        default = null;
      };

      OU = mkOption {
        description = "Certificate organization unit.";
        type = types.nullOr types.str;
        default = null;
      };

      ST = mkOption {
        description = "Certificate state or province.";
        type = types.nullOr types.str;
        default = null;
      };

      emailAddress = mkOption {
        description = "Certificate email address.";
        type = types.nullOr types.str;
        default = null;
      };
    };
  };
in {
  options = {
    name = mkOption {
      description = "Name of the CSR";
      type = types.str;
      internal = true;
    };

    key = {
      algo = mkOption {
        description = "Algorithm to use when generating certs.";
        type = types.nullOr (types.enum ["rsa" "ecdsa"]);
        default = null;
        example = "rsa";
      };

      size = mkOption {
        description = "Certificate size.";
        type = types.nullOr types.int;
        default = null;
        example = 4096;
      };
    };

    CN = mkOption {
      description = "Cert common name.";
      type = types.nullOr types.str;
      default = null;
    };

    hosts = mkOption {
      description = "Extra cert hosts.";
      type = types.listOf types.str;
      default = [];
    };

    names = mkOption {
      description = "Cert names to set.";
      type = types.listOf (types.submodule csrNameOptions);
      default = [];
    };
  };
}
