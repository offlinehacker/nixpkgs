# pki defines abstraction for pki on kubernetes

{ options, config, lib, ... }:

with lib;

let
  cfg = config.services.kubernetes.pki;
  opts = options.services.kubernetes.pki;

  mkLowPrioDefault = mkOverride 1100;

  certsWithAction = filterAttrs (_: cert: cert.action != null) cfg.certs;

  certOptions =  { name, config, ... }: {
    options = {
      enable = mkOption {
        description = "Whether to enable certificate";
        type = types.bool;
        default = true;
      };

      name = mkOption {
        description = "Name of the certificate.";
        type = types.str;
        default = name;
      };

      csr = mkOption {
        description = "Certificate signin request options.";
        type = types.submodule {
          imports = [ ./csr.nix ];
          config.name = name;
        };
        default = {};
      };

      kind = mkOption {
        description = "Certificate kind (currently server, client and signing)";
        type = types.enum ["server" "client" "signing"];
      };

      ca.cert = mkOption {
        description = "Certificate authority path.";
        type = types.path;
        default =
          if cfg.ca.alwaysUseDefault
          then cfg.ca.cert
          else "${cfg.pkiBasePath}/${config.name}.ca.crt";
        defaultText = "config.services.kubernetes.pki.ca.cert";
      };

      privateKeyOwner = mkOption {
        description = "Owner of the private key.";
        type = types.str;
        default = "root";
      };

      action = mkOption {
        description = "Action to run when cert changes.";
        type = types.nullOr types.str;
        default = null;
      };

      cert = mkOption {
        description = "Generated certificate path.";
        type = types.path;
        default = "${cfg.pkiBasePath}/${config.name}.crt";
      };

      key = mkOption {
        description = "Generated cetificate key path.";
        type = types.path;
        default = "${cfg.pkiBasePath}/${config.name}.key";
      };
    };

    config = {
      # assign csrDefaults
      csr = mkAliasDefinitions opts.csrDefaults;
    };
  };

in {

  ###### interface
  options.services.kubernetes.pki = {
    enable = mkEnableOption "kubernetes pki";

    certs = mkOption {
      description = "Attribute set of certs that should be created.";
      type = types.attrsOf (types.submodule certOptions);
      default = {};
    };

    ca = {
      cert = mkOption {
        description = "Default certificate authority path.";
        type = types.path;
        default = "${cfg.pkiBasePath}/ca.crt";
      };

      alwaysUseDefault = mkOption {
        description = "Whether to always use default CA";
        type = types.bool;
        default = true;
      };
    };

    pkiBasePath = mkOption {
      description = "Base path for where cerificates are stored";
      type = types.path;
      default = "/etc/kubernetes/pki";
    };

    csrDefaults = mkOption {
      description = "CSR defaults.";
      type = types.submodule {
        imports = [ ./csr.nix ];
      };
      default = {};
    };

    restartOnChange = mkOption {
      description = "Whether to restart kubernetes components on cert changes";
      type = types.bool;
      default = true;
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    services.kubernetes.enabled = true;

    systemd.targets.kube-pki = {
      description = "Kubernetes PKI";
      wantedBy = [ "kubernetes.target" ];
      before = [ "kube-control-plane.target" "kube-worker.target" ];
    };

     # signing profile defaults
    services.kubernetes.pki.csrDefaults = {
      names = mkLowPrioDefault [{ C = "xx"; L = "x"; O = "x"; OU = "x"; ST = "x"; }];
      key = {
        size = mkLowPrioDefault 256;
        algo = mkLowPrioDefault "ecdsa";
      };
    };

    systemd.paths = mkIf cfg.restartOnChange (mapAttrs' (_: cert:
      nameValuePair "${cert.name}-cert-changed" {
        wantedBy = [ "kube-pki.target" ];
        pathConfig.PathChanged = [
          cert.ca.cert
          cert.key
          cert.cert
        ];
      }
    ) certsWithAction);

    systemd.services = mkIf cfg.restartOnChange (mapAttrs' (_: cert:
      nameValuePair "${cert.name}-cert-changed" {
        script = "${cert.action}";
        wants = [ "kube-pki.target" ]; # after pki has been bootstrapped
        serviceConfig.Type = "oneshot";
      }
    ) certsWithAction);
  };
}
