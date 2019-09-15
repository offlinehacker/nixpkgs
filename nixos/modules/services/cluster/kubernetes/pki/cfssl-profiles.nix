{ config, lib, ... }:

with lib;

{
  # predefined kubernetes signing profiles
  config.signing = {
    server = {
      usages = mkDefault [ "signing" "key encipherment" "server auth" ];
      expiry = mkDefault "87600h";
    };

    client = {
      usages = mkDefault [ "signing" "key encipherment" "client auth" ];
      expiry = mkDefault "87600h";
    };

    signing = {
      usages = mkDefault [ "digital signature" "cert sign" "crl sign" "signing" ];
      expiry = mkDefault "87600h";
      caConstraint = {
        isCA = true;
        maxPathLength = mkDefault 0;
        maxPathLenZero = mkDefault true;
      };
    };
  };
}
