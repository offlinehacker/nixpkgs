{ config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  pki = top.pki;
  cfg = pki.certmgr;
  cfssl = config.services.cfssl;

  serverProfile = {
    usages = mkDefault [ "signing" "key encipherment" "server auth" ];
    expiry = mkDefault "87600h";
  };

  clientProfile = {
    usages = mkDefault [ "signing" "key encipherment" "client auth" ];
    expiry = mkDefault "87600h";
  };

  signingProfile = {
    usages = mkDefault [ "digital signature" "cert sign" "crl sign" "signing" ];
    expiry = mkDefault "87600h";
    caConstraint = {
      isCA = true;
      maxPathLength = mkDefault 0;
      maxPathLenZero = mkDefault true;
    };
  };

in {
  options.services.kubernetes.pki = {
    certmgr = {
      enable = mkOption {
        description = "Whether to use cloudflare certmgr for pki management";
        type = types.bool;
        default = false;
      };

      serviceAccountCertSync = mkOption {
        description = "Whether to enable sync of service account between nodes";
        type = types.bool;
        default = false;
      };

      cfssl = {
        enable = mkOption {
          description = "Whether to enable CFSSL service.";
          default = cfg.enable;
          type = types.bool;
        };

        remote = mkOption {
          description = "CFSSL remote address";
          type = types.str;
          default = "https://localhost:8888";
        };

        authKeyFile = mkOption {
          description = "CFSSL auth key file used for connection";
          type = types.path;
          default = "${cfssl.dataDir}/default-key.secret";
        };

        rootCA = mkOption {
          description = "Root CA used for cfssl server cert checking.";
          type = types.path;
          default = "${cfssl.dataDir}/ca.pem";
        };
      };
    };

    pki = {
      # extend services.kubernetes.pki.certs to expose local generated certs
      # and services.kubernetes.pki.certs.csr with cfssl specific options
      certs = mkOption {
        type = types.attrsOf (types.submodule ({ config, name, ... }: {
          options = {
            cfssl.profile = mkOption {
              description = "Name of the cfssl profile to use";
              type = types.str;
              default = config.name;
            };

            csr = mkOption {
              type = types.submodule {
                imports = [ ./cfssl-csr.nix ];
              };
            };
          };
        }));
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.kubernetes.pki = {
        enable = true;
        pkiBasePath = "/var/lib/kubernetes/pki";
        restartOnChange = false; # certmgr takes care of restarting

        ca.alwaysUseDefault = false;
        certs = {
          serviceAccountCertSyncEtcdClient.cfssl.profile = "etcd-client";
          apiserverEtcdClient.cfssl.profile = "etcd-client";
        };
      };

      services.certmgr = {
        enable = true;
        ensurePreStart = true;
        svcManager = "command";

        specs = mapAttrs' (_: cert: nameValuePair cert.name {
          action = optionalString (cert.action != null) cert.action;
          authority = {
            remote = cfg.cfssl.remote;
            profile = cert.cfssl.profile;
            authKeyFile = cfg.cfssl.authKeyFile;
            rootCA = cfg.cfssl.rootCA;
            trustOnBootstrap = mkDefault true;
            file = {
              path = cert.ca.cert;
              mode = "0644";
            };
          };
          certificate = {
            path = cert.cert;
            mode = "0644";
          };
          privateKey = {
            owner = cert.privateKeyOwner;
            group = "nogroup";
            mode = "0600";
            path = cert.key;
          };
          request = cert.csr.cfssl.generated;
        }) (filterAttrs (_: cert: cert.enable) pki.certs);
      };

      # add cfssl to kube-pki target
      systemd.services.cfssl = mkIf config.services.cfssl.enable {
        wantedBy = [ "kube-pki.target" ];
        before = [ "kube-pki.target" ];
      };

      # add certmgr to kube-pki target
      systemd.services.certmgr = {
        wantedBy = [ "kube-pki.target" ];
        before = [ "kube-pki.target" "etcd.service" ];
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/kubernetes/pki 0755 kubernetes kubernetes -"
      ];
    })

    # cfssl can be enabled independently
    (mkIf cfg.cfssl.enable {
      services.cfssl = {
        enable = true;
        address = mkDefault "localhost";
        initca.enable = mkDefault true;
        initssl.enable = mkDefault true;
        configuration = {
          authKeys.default.generate = mkDefault true;
          signing = {
            profiles = {
              # etcd server profile
              etcdServer = mkMerge [serverProfile {
                name = "etcd-server";
                authKey = mkDefault "default";
              }];
              etcdClient = mkMerge [clientProfile {
                name = "etcd-client";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(etcd-client)$";
              }];

              # kube-apiserver profiles
              apiserver = mkMerge [serverProfile {
                name = "kube-apiserver";
                authKey = mkDefault "default";
                #nameWhitelist = mkDefault "^(kuberneter|localhost|kubernetes.default.svc|kubernetes.default.svc.${top.clusterDomain}|${top.apiserver.advertiseAddress})$";
              }];
              apiserverProxyClient = mkMerge [clientProfile {
                name = "kube-apiserver-proxy-client";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(front-proxy-client)$";
              }];
              apiserverKubeletClient = mkMerge [clientProfile {
                name = "kube-apiserver-kubelet-client";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(system:kube-apiserver)$";
              }];
              clusterAdmin = mkMerge [clientProfile {
                name = "kube-cluster-admin";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(cluster-admin|system:masters)$";
              }];
              resourceBootstrapper = mkMerge [clientProfile {
                name = "kube-resource-bootstrapper";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(resource-bootstrapper|system:masters)$";
              }];

              # kube-controller-manager profiles
              controllerManager = mkMerge [serverProfile {
                name = "kube-controller-manager";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(kube-controller-manager)$";
              }];
              controllerManagerClient = mkMerge [clientProfile {
                name = "kube-controller-manager-client";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(system:kube-controller-manager)$";
              }];
              serviceAccountSigner = mkMerge [signingProfile {
                name = "kube-service-account-signer";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(system:service-account-signer)$";
              }];

              # kube-scheduler profiles
              schedulerClient = mkMerge [clientProfile {
                name = "kube-scheduler-client";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(system:kube-scheduler)$";
              }];

              # kubelet profiles
              kubelet = mkMerge [serverProfile {
                name = "kubelet";
                authKey = mkDefault "default";
              }];
              kubeletClient = mkMerge [clientProfile {
                name = "kubelet-client";
                authKey = mkDefault "default";
                nameWhitelist = mkDefault "^(system:node:.*)$";
              }];

              # kube-proxy profiles
              kubeProxyClient = mkMerge [clientProfile {
                name = "kube-proxy-client";
                authKey = mkDefault "default";
                nameWhitelist = "^(system:kube-proxy)$";
              }];

              # flannel client profile
              flannelClient = mkMerge [clientProfile {
                name = "flannel-client";
                authKey = mkDefault "default";
                nameWhitelist = "flannel-client";
              }];
            };
          };
        };
      };
    })
  ];
}
