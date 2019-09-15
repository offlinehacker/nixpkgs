{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kubernetes;

in {
  options.services.kubernetes = {
    enabled = mkOption {
      description = "Whether kubernetes is enabled (this options is set implicitly)";
      type = types.bool;
      default = false;
      internal = true;
    };

    package = mkOption {
      description = "Kubernetes package to use.";
      type = types.package;
      default = pkgs.kubernetes;
      defaultText = "pkgs.kubernetes";
    };

    kubeconfig = mkOption {
      description = "Kubernetes kubeconfig defaults.";
      type = types.submodule {
        imports = [ ./kubeconfig.nix ];
      };
      default = {};
    };

    dataDir = mkOption {
      description = "Kubernetes root directory for managing kubelet files.";
      default = "/var/lib/kubernetes";
      type = types.path;
    };

    apiserverAddress = mkOption {
      description = ''
        Clusterwide accessible address for the kubernetes apiserver,
        including protocol and optional port.
      '';
      example = "https://kubernetes-apiserver.example.com:6443";
      default = "https://${config.networking.hostName}:${toString cfg.apiserver.securePort}";
      type = types.str;
    };

   featureGates = mkOption {
      description = "List set of feature gates.";
      default = [];
      type = types.listOf types.str;
    };

    clusterCidr = mkOption {
      description = "Kubernetes controller manager and proxy CIDR Range for Pods in cluster.";
      default = "10.1.0.0/16";
      type = types.nullOr types.str;
    };

    clusterDomain = mkOption {
      description = "Kubernetes cluster domain";
      default = "cluster.local";
      type = types.str;
    };
  };

  config = mkIf cfg.enabled {
    # set default server for kubeconfig
    services.kubernetes.kubeconfig.server = mkDefault cfg.apiserverAddress;

    systemd.targets.kubernetes = {
      description = "Kubernetes";
      wantedBy = [ "multi-user.target" ];
    };

    # kube-control-plane is separate systemd target that group
    # kube-apiserver, kube-controller-manager, kube-scheduler and all
    # other requirements to have kubernetes control plane up and running
    systemd.targets.kube-control-plane = {
      description = "Kubernetes control plane";
      wantedBy = [ "kubernetes.target" ];
      before = [ "kubernetes.target" ];
    };

    # kube-worker is separate systemd target that groups
    # kubelet, kube-proxy, kube-runtime (docker, containerd, crio) and
    # nixos managed container network interfaces like flannel
    systemd.targets.kube-worker = {
      description = "Kubernetes worker";
      wantedBy = [ "kubernetes.target" ];
      before = [ "kubernetes.target" ];
      after = [ "kube-control-plane.target" ];
    };

    systemd.tmpfiles.rules = [
      "d /run/kubernetes 0755 kubernetes kubernetes -"
      "d ${cfg.dataDir} 0755 kubernetes kubernetes -"
    ];

    users.users = singleton {
      name = "kubernetes";
      uid = config.ids.uids.kubernetes;
      description = "Kubernetes user";
      group = "kubernetes";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.kubernetes.gid = config.ids.gids.kubernetes;
  };
}
