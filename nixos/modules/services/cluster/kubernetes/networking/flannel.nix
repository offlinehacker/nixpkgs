{ options, config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  cfg = top.networking.flannel;

in {
  ###### interface
  options.services.kubernetes.networking.flannel = {
    enable = mkEnableOption "flannel networking";

    kubeconfig = mkOption {
      description = "Kubernetes flannel kubeconfig";
      type = types.submodule {
        imports = [ ../kubeconfig.nix ];
        config = mkAliasDefinitions options.services.kubernetes.kubeconfig;
      };
      default = {};
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    services.flannel = {
      enable = mkDefault true;
      storageBackend = "kubernetes";
      network = mkDefault top.clusterCidr;
      kubeconfig = cfg.kubeconfig.file;
      nodeName = top.kubelet.hostname;
    };

    services.kubernetes.kubelet = {
      networkPlugin = mkDefault "cni";
      cni.config = mkDefault [{
        name = "mynet";
        type = "flannel";
        delegate = {
          isDefaultGateway = true;
          harpinMode = true;
        };
      } {
        name = "mynet";
        type = "portmap";
        capabilities = {
          portMappings = true;
        };
      }];
    };

    services.kubernetes.apiserver.bootstrap.resources = {
      flannel-cr = {
        apiVersion = "rbac.authorization.k8s.io/v1beta1";
        kind = "ClusterRole";
        metadata = { name = "flannel"; };
        rules = [{
          apiGroups = [ "extensions" ];
          resources = [ "podsecuritypolicies" ];
          verbs = [ "use" ];
          resourceNames = [ "psp.flannel.unprivileged" ];
        } {
          apiGroups = [ "" ];
          resources = [ "pods" ];
          verbs = [ "get" ];
        }
        {
          apiGroups = [ "" ];
          resources = [ "nodes" ];
          verbs = [ "list" "watch" ];
        }
        {
          apiGroups = [ "" ];
          resources = [ "nodes/status" ];
          verbs = [ "patch" ];
        }];
      };

      flannel-crb = {
        apiVersion = "rbac.authorization.k8s.io/v1beta1";
        kind = "ClusterRoleBinding";
        metadata = { name = "flannel"; };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "flannel";
        };
        subjects = [{
          kind = "User";
          name = "flannel-client";
        }];
      };
    };

    # delay flannel after kubelet is started
    systemd.services.flannel = {
      wantedBy = [ "kube-networking.target" ];
      before = [ "kube-networking.target" ];
      after = [ "kubelet.service" ];
    };

    networking = {
      firewall = {
        allowedUDPPorts = [
          8285  # flannel udp
          8472  # flannel vxlan
        ];
        trustedInterfaces = [ "cni0" "flannel.1" ];
      };
      dhcpcd.denyInterfaces = [ "docker*" "flannel*" ];
    };
  };
}
