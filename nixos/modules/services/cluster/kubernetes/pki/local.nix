{ options, config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  pki = top.pki;
  cfg = pki.local;
  pkiOpts = options.services.kubernetes.pki;

  runWithCFSSL = name: cmd: let
    secrets = pkgs.runCommand "${name}-cert.json" {
      buildInputs = [ pkgs.cfssl pkgs.jq ];
      outputs = [ "out" "cert" "key" ];
    }
    ''
      (
        echo "${cmd}"
        cfssl ${cmd} > tmp
        cat tmp | jq -r .key > $key
        cat tmp | jq -r .cert > $cert

        touch $out
      ) 2>&1 | fold -w 80 -s
    '';
  in {
    key = secrets.key;
    cert = secrets.cert;
  };

  createCert = name: csr: profile: caCert: caKey: let
    csrFile = csr.cfssl.file;
    configFile = toCFSSLConfig name csr;
    cfsslConfig = cfg.cfssl.config.file;
  in runWithCFSSL name "gencert -config=${cfsslConfig} -profile=${profile} -ca=${caCert} -ca-key=${caKey} ${csrFile}";

  createSigningCert = csr: let
    csrFile = csr.cfssl.file;
  in runWithCFSSL "kube-ca" "genkey -initca ${csrFile}";

  ca = createSigningCert cfg.ca.csr;

  validProfiles = mapAttrsToList (_: p: p.name) cfg.cfssl.config.signing.profiles;

in {
  options.services.kubernetes.pki = {
    # extend services.kubernetes.pki.certs to expose local generated certs
    # and services.kubernetes.pki.certs.csr with cfssl specific options
    certs = mkOption {
      type = types.attrsOf (types.submodule ({ config, name, ... }: let
        # if profile is not in list of valid profiles, use generic profile
        profile =
          if !(elem config.cfssl.profile validProfiles)
          then config.kind else config.cfssl.profile;

        cert = createCert config.name config.csr profile cfg.ca.cert cfg.ca.key;
      in {
        options = {
          cfssl.profile = mkOption {
            description = "Name of the cfssl profile to use";
            type = types.str;
            default = config.name;
          };

          local = {
            cert = mkOption {
              description = "Generated certificate using local pki.";
              type = types.package;
              internal = true;
              default = cert.cert;
            };

            key = mkOption {
              description = "Generated certificate using local pki.";
              type = types.package;
              internal = true;
              default = cert.key;
            };
          };

          csr = mkOption {
            type = types.submodule {
              imports = [ ./cfssl-csr.nix ];
            };
          };
        };
      }));
    };

    local = {
      enable = mkEnableOption "kubernetes local PKI (uses nix store to insecurly store certs)";

      cfssl.config = mkOption {
        description = "CFSSL configuration.";
        type = types.submodule {
          imports = [ ../../../security/cfssl/cfssl-config.nix ];
        };
        default = {};
      };

      ca = {
        csr = mkOption {
          description = "Certificate authority CSR config.";
          type = types.submodule {
            imports = [ ./csr.nix ./cfssl-csr.nix ];
            config = mkAliasDefinitions pkiOpts.csrDefaults;
          };
          default = {};
        };

        cert = mkOption {
          description = "Generated certificate authority certificate path.";
          type = types.package;
          internal = true;
          default = ca.cert;
        };

        key = mkOption {
          description = "Generated certificate authority certificate key path.";
          type = types.package;
          internal = true;
          default = ca.key;
        };
      };
    };
  };

  config = mkIf cfg.enable {
    warnings = [
      ''
        Usage of local kubernetes PKI is insecure, as it uses wide readable
        nix store. Do not use this in production, you have been warned!
      ''
    ];

    services.kubernetes.pki = {
      enable = true;
      pkiBasePath = "/etc/kubernetes/pki";
      restartOnChange = mkDefault true;

      local = {
        ca.csr = {
          name = "kube-ca";
          CN = mkDefault "NixOS kubernetes test Root CA";
          ca.expiry = mkDefault "87600h";
        };
        cfssl.config.signing = {
          default.expiry = "8760h";
          profiles = {
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
        };
      };
    };

    # these certificates are put to /etc so we generate realisitc cert scenario
    # that can also be used in testing
    environment.etc = mkMerge [
      {
        "kubernetes/pki/ca.crt" = {
          mode = "0644";
          source = ca.cert;
        };

        "kubernetes/pki/ca.key" = {
          mode = "0600";
          source = ca.key;
        };
      }

      # copy certs to /etc/kubernetes/pki
      (mapAttrs' (name: cert: nameValuePair "${name}Cert" {
        mode = "0644";
        source = cert.local.cert;
        target = "kubernetes/pki/${cert.name}.crt";
      }) (filterAttrs (_: cert: cert.enable) pki.certs))

      # copy keys to /etc/kubernetes/pki
      (mapAttrs' (name: cert: nameValuePair "${name}Key" {
        mode = "0600";
        source = cert.local.key;
        target = "kubernetes/pki/${cert.name}.key";
        user = cert.privateKeyOwner;
      }) (filterAttrs (_: cert: cert.enable) pki.certs))
    ];
  };
}
