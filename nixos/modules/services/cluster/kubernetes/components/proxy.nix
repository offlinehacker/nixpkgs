{ options, config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  cfg = top.proxy;

in {

  ###### interface
  options.services.kubernetes.proxy = {
    enable = mkEnableOption "Kubernetes proxy";

    bindAddress = mkOption {
      description = "Kubernetes proxy listening address.";
      default = "0.0.0.0";
      type = types.str;
    };

    clusterCidr = mkOption {
      description = "Kubernetes CIDR Range for Pods in cluster.";
      default = top.clusterCidr;
      type = types.nullOr types.str;
    };

    featureGates = mkOption {
      description = "List set of feature gates";
      default = top.featureGates;
      type = types.listOf types.str;
    };

    kubeconfig = mkOption {
      description = "Kubernetes proxy kubeconfig.";
      type = types.submodule {
        imports = [ ../kubeconfig.nix ];
        config = mkAliasDefinitions options.services.kubernetes.kubeconfig;
      };
      default = {};
    };

    healthz = {
      bindAddress = mkOption {
        description = "Kubernetes kubelet healthz listening address.";
        default = "127.0.0.1";
        type = types.str;
      };

      port = mkOption {
        description = "Kubernetes kubelet healthz port.";
        default = 10256;
        type = types.int;
      };
    };

    proxyMode = mkOption {
      description = "Which proxy mode to use.";
      type = types.enum ["userspace" "iptables" "ipvs"];
      default = "iptables";
    };

    verbosity = mkOption {
      description = ''
        Optional glog verbosity level for logging statements. See
        <link xlink:href="https://github.com/kubernetes/community/blob/master/contributors/devel/logging.md"/>
      '';
      default = null;
      type = types.nullOr types.int;
    };

    extraOpts = mkOption {
      description = "Kubernetes proxy extra command line options.";
      default = [];
      type = types.listOf types.str;
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    systemd.services.kube-proxy = {
      description = "Kubernetes Proxy Service";
      wantedBy = [ "kube-worker.target" ];
      after = [ "kubelet.service" ];
      before = [ "kube-worker.target" ];
      path = with pkgs; [ curl kubectl iptables conntrack_tools ];
      environment.KUBECONFIG = cfg.kubeconfig.file;

      # wait until kube-apiserver is avalible
      preStart = ''
        until kubectl auth can-i -q get /api >/dev/null; do
          echo kubectl auth can-i get /api: exit status $?
          sleep 2
        done
      '';

      # wait until kube-proxy is healthy, no authorization needed
      postStart = ''
        until curl -sSf -o /dev/null http://${cfg.healthz.bindAddress}:${toString cfg.healthz.port}/healthz; do
          sleep 2
        done
      '';

      serviceConfig = {
        Slice = "kubernetes.slice";
        ExecStart = concatStringsSep " " ([
          "${top.package}/bin/kube-proxy"
          "--bind-address=${cfg.bindAddress}"
          (optionalString (cfg.clusterCidr!=null)
            "--cluster-cidr=${cfg.clusterCidr}")
          (optionalString (cfg.featureGates != [])
            "--feature-gates=${concatMapStringsSep "," (feature: "${feature}=true") cfg.featureGates}")
          "--kubeconfig=${cfg.kubeconfig.file}"
          "--healthz-bind-address=${cfg.healthz.bindAddress}"
          "--healthz-port=${toString cfg.healthz.port}"
          "--proxy-mode=${cfg.proxyMode}"
          (optionalString (cfg.verbosity != null) "--v=${toString cfg.verbosity}")
        ] ++ cfg.extraOpts);
        WorkingDirectory = top.dataDir;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    boot.kernelModules = ["br_netfilter"];
  };
}
