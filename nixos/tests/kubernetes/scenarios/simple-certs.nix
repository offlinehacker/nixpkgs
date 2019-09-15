{ config, ... }:

{
  services.kubernetes.pki = {
    enable = true;

    csrDefaults = {
      names = [{
        C = "Kuber";
        L = "KubeLand";
        O = "NixOS";
        OU = "Kubernauts";
        emailAddress = "kubernauts@nixos.org";
      }];
      key = {
        size = 2048;
        algo = "rsa";
      };
    };

    certs = {
      client = {
        name = "test-client";
        kind = "client";
        csr = {
          CN = "client";
          names = [{ O = "system:clients"; }];
        };
        privateKeyOwner = "root";
      };

      server = {
        name = "test-server";
        kind = "server";
        csr = {
          CN = "server";
        };
      };

      signer = {
        name = "test-signer";
        kind = "signing";
        csr = {
          CN = "signer";
        };
        privateKeyOwner = "root";
      };
    };
  };
}
