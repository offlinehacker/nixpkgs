{ config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  pki = top.pki;
  cfg = pki.serviceAccountCertSync;

in {
  options.services.kubernetes.pki.serviceAccountCertSync = {
    enable = mkOption {
      description = "Whether to enable service account cert sync accross nodes.";
      type = types.bool;
      default = false;
    };

    path = mkOption {
      description = "Aggregated cert path";
      type = types.path;
      default = "${pki.pkiBasePath}/service-accounts.pem";
    };

    serviceAccountCertUpsert = mkOption {
      description = "Whether to enable service account cert upsert service.";
      type = types.bool;
      default = top.controllerManager.enable;
    };

    serviceAccountCertSync = mkOption {
      description = "Whether to enable service account cert sync service.";
      type = types.bool;
      default = top.apiserver.enable;
    };

    etcd = {
      endpoints = mkOption {
        description = "Etcd endpoint";
        type = types.listOf types.str;
        default = ["https://127.0.0.1:2379"];
      };

      ca = mkOption {
        description = "Etcd certificate authority path";
        type = types.path;
        default = pki.certs.apiserverEtcdClient.ca.cert;
      };

      cert = mkOption {
        description = "Etcd certificate path";
        type = types.path;
        default = pki.certs.apiserverEtcdClient.cert;
      };

      key = mkOption {
        description = "Etcd certificate key path";
        type = types.path;
        default = pki.certs.apiserverEtcdClient.key;
      };

      prefix = mkOption {
        description = "Etcd prefix";
        type = types.str;
        default = "/nixos/kubernetes";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.kube-service-account-cert-upsert = mkIf cfg.serviceAccountCertUpsert {
      description = "Kubernetes service account cert upsert";

      wantedBy = ["kube-pki.target"];
      after = [ "certmgr.service" "etcd.service" ];

      path = with pkgs; [ etcd coreutils ];
      environment = {
        ETCDCTL_API = "3";
        ETCDCTL_ENDPOINTS = concatStringsSep "," cfg.etcd.endpoints;
        ETCDCTL_CACERT = cfg.etcd.ca;
        ETCDCTL_CERT = cfg.etcd.cert;
        ETCDCTL_KEY = cfg.etcd.key;
      };
      script = ''
        hash=`sha1sum ${pki.certs.serviceAccountSigner.cert} | cut -d ' ' -f1`
        until cat ${pki.certs.serviceAccountSigner.cert} | \
          etcdctl put ${cfg.etcd.prefix}/kube-sa-cert/$hash
        do
          echo failed cert upsert
          sleep 2
        done
      '';

      serviceConfig = {
        Type = "oneshot";
        User = "kubernetes";
      };

      unitConfig = {
        ConditionPathExists = [ pki.certs.serviceAccountSigner.cert ];
      };
    };

    systemd.paths.kube-service-account-cert-upsert = {
      wantedBy = [ "kube-pki.target" ];
      pathConfig.PathChanged = [ pki.certs.serviceAccountSigner.cert ];
    };

    systemd.services.kube-service-account-cert-sync = mkIf cfg.serviceAccountCertSync {
      description = "Kubernetes service account cert syncer";

      wantedBy = ["kube-pki.target"];
      after = [ "etcd.service" ];

      path = with pkgs; [ etcd bash ];
      environment = {
        ETCDCTL_API = "3";
        ETCDCTL_ENDPOINTS = concatStringsSep "," cfg.etcd.endpoints;
        ETCDCTL_CACERT = cfg.etcd.ca;
        ETCDCTL_CERT = cfg.etcd.cert;
        ETCDCTL_KEY = cfg.etcd.key;
      };
      preStart = ''
        etcdctl get --print-value-only --prefix ${cfg.etcd.prefix}/kube-sa-cert/ > ${cfg.path}
        chown kubernetes:kubernetes ${cfg.path}
        chmod 0400 ${cfg.path}
      '';
      script = ''
        etcdctl watch --prefix ${cfg.etcd.prefix}/kube-sa-cert/ -- \
          bash -ec '
            ETCDCTL_API=3 etcdctl get --print-value-only --prefix ${cfg.etcd.prefix}/kube-sa-cert/ > ${cfg.path}
          '
      '';

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # change service account path to aggregated certs
    services.kubernetes.apiserver.serviceAccountKeyFile = cfg.path;

    systemd.paths.kube-service-account-cert-changed = {
      wantedBy = [ "kube-pki.target" ];
      pathConfig.PathChanged = [ cfg.path ];
    };

    systemd.services.kube-service-account-cert-changed = mkIf top.apiserver.enable {
      wants = [ "kube-pki.target" ];
      script = "systemctl restart kube-apiserver.service";
      serviceConfig.Type = "oneshot";
    };
  };
}
