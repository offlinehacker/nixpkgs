{ config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  cfg = top.addonManager;

  isRBACEnabled = elem "RBAC" top.apiserver.authorizationMode;

  resources = attrValues cfg.resources;

  resourcesHash = builtins.hashString "sha1" (builtins.toJSON resources);

  hashedList = let
    labeledItems = map (item: recursiveUpdate item {
      metadata.labels."nixos.org/hash" = resourcesHash;
    }) resources;
  in {
    kind = "List";
    apiVersion = "v1";
    items = labeledItems;
    metadata.labels."nixos.org/hash" = resourceHash;
  };

  resourcesJSON = pkgs.writeFile "k8s-resources.json" (builtins.toJSON hashedList);

in {

  ###### interface
  options.services.kubernetes.addonManager = with lib.types; {
    enable = mkEnableOption "Kubernetes addon manager";

    resources = mkOption {
      description = "Kubernetes resources to apply on cluster.";
      default = { };
      type = types.attrsOf types.attrs;
      example = literalExample ''
        {
          "my-service" = {
            "apiVersion" = "v1";
            "kind" = "Service";
            "metadata" = {
              "name" = "my-service";
              "namespace" = "default";
            };
            "spec" = { ... };
          };
        }
        // import <nixpkgs/nixos/modules/services/cluster/kubernetes/dashboard.nix> { cfg = config.services.kubernetes; };
      '';
    };

    kubeconfig = mkOption {
      description = "Kubernetes bootstraper kubeconfig";
      type = types.submodule {
        imports = [ ./kubeconfig.nix ];
        config = mkDefault top.kubeconfig;
      };
    };
  };

  ###### implementation
  config = mkIf cfg.enable {

    services.kubernetes.addonManager.bootstrapAddons = mkIf isRBACEnabled
    (let
      name = system:kube-addon-manager;
      namespace = "kube-system";
    in {
      kube-addon-manager-r = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "Role";
        metadata = {
          inherit name namespace;
        };
        rules = [{
          apiGroups = ["*"];
          resources = ["*"];
          verbs = ["*"];
        }];
      };

      kube-addon-manager-rb = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "RoleBinding";
        metadata = {
          inherit name namespace;
        };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "Role";
          inherit name;
        };
        subjects = [{
          apiGroup = "rbac.authorization.k8s.io";
          kind = "User";
          inherit name;
        }];
      };

      kube-addon-manager-cluster-lister-cr = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRole";
        metadata = {
          name = "${name}:cluster-lister";
        };
        rules = [{
          apiGroups = ["*"];
          resources = ["*"];
          verbs = ["list"];
        }];
      };

      kube-addon-manager-cluster-lister-crb = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRoleBinding";
        metadata = {
          name = "${name}:cluster-lister";
        };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "${name}:cluster-lister";
        };
        subjects = [{
          kind = "User";
          inherit name;
        }];
      };
    });

    services.kubernetes.pki.certs = {
      addonManager = top.lib.mkCert {
        name = "kube-addon-manager";
        CN = "system:kube-addon-manager";
        action = "systemctl restart kube-addon-manager.service";
      };
    };
  };

}
