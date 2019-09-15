{ options, config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  cfg = top.apiserver;

  isRBACEnabled = elem "RBAC" cfg.authorizationMode;

  resources = attrValues cfg.bootstrap.resources;

  resourcesHash = builtins.hashString "sha1" (builtins.toJSON resources);

  hashedList = let
    labeledItems = map (item: recursiveUpdate item {
      metadata.labels."nixos.org/hash" = resourcesHash;
    }) resources;
  in {
    kind = "List";
    apiVersion = "v1";
    items = labeledItems;
    metadata.labels."nixos.org/hash" = resourcesHash;
  };

  resourcesJSON = pkgs.writeText "k8s-resources.json" (builtins.toJSON hashedList);

in {

  ###### interface
  options.services.kubernetes.apiserver = {
    enable = mkEnableOption "Kubernetes apiserver";

    advertiseAddress = mkOption {
      description = ''
        Kubernetes apiserver IP address on which to advertise the apiserver
        to members of the cluster. This address must be reachable by the rest
        of the cluster.
      '';
      default = config.networking.primaryIPAddress;
      type = types.nullOr types.types.str;
    };

    allowPrivileged = mkOption {
      description = "Whether to allow privileged containers on Kubernetes.";
      default = false;
      type = types.bool;
    };

    authorizationMode = mkOption {
      description = ''
        Kubernetes apiserver authorization mode (AlwaysAllow/AlwaysDeny/ABAC/Webhook/RBAC/Node). See
        <link xlink:href="https://kubernetes.io/docs/reference/access-authn-authz/authorization/"/>
      '';
      default = ["RBAC" "Node"]; # Enabling RBAC by default, although kubernetes default is AlwaysAllow
      type = types.listOf (types.enum ["AlwaysAllow" "AlwaysDeny" "ABAC" "Webhook" "RBAC" "Node"]);
    };

    authorizationPolicy = mkOption {
      description = ''
        Kubernetes apiserver authorization policy file. See
        <link xlink:href="https://kubernetes.io/docs/reference/access-authn-authz/authorization/"/>
      '';
      default = [];
      type = types.listOf types.attrs;
    };

    basicAuthFile = mkOption {
      description = ''
        Kubernetes apiserver basic authentication file. See
        <link xlink:href="https://kubernetes.io/docs/reference/access-authn-authz/authentication"/>
      '';
      default = null;
      type = types.nullOr types.path;
    };

    bindAddress = mkOption {
      description = ''
        The IP address on which to listen for the --secure-port port.
        The associated interface(s) must be reachable by the rest
        of the cluster, and by CLI/web clients.
      '';
      default = "0.0.0.0";
      type = types.str;
    };

    clientCaFile = mkOption {
      description = "Kubernetes apiserver CA file for client auth.";
      default = null;
      type = types.nullOr types.path;
    };

    disableAdmissionPlugins = mkOption {
      description = ''
        Kubernetes admission control plugins to disable. See
        <link xlink:href="https://kubernetes.io/docs/admin/admission-controllers/"/>
      '';
      default = [];
      type = types.listOf types.str;
    };

    enableAdmissionPlugins = mkOption {
      description = ''
        Kubernetes admission control plugins to enable. See
        <link xlink:href="https://kubernetes.io/docs/admin/admission-controllers/"/>
      '';
      default = [
        "NamespaceLifecycle" "LimitRanger" "ServiceAccount"
        "ResourceQuota" "DefaultStorageClass" "DefaultTolerationSeconds"
        "NodeRestriction"
      ];
      example = [
        "NamespaceLifecycle" "NamespaceExists" "LimitRanger"
        "SecurityContextDeny" "ServiceAccount" "ResourceQuota"
        "PodSecurityPolicy" "NodeRestriction" "DefaultStorageClass"
      ];
      type = types.listOf types.str;
    };

    etcd = {
      servers = mkOption {
        description = "List of etcd servers.";
        default =
          if config.services.etcd.clientCertAuth
          then ["https://127.0.0.1:2379"]
          else ["http://127.0.0.1:2379"];
        type = types.listOf types.str;
      };

      keyFile = mkOption {
        description = "Etcd key file.";
        default = null;
        type = types.nullOr types.path;
      };

      certFile = mkOption {
        description = "Etcd cert file.";
        default = null;
        type = types.nullOr types.path;
      };

      caFile = mkOption {
        description = "Etcd CA file.";
        default = null;
        type = types.nullOr types.path;
      };
    };

    featureGates = mkOption {
      description = "List set of feature gates";
      default = [];
      type = types.listOf types.str;
    };

    kubeletClientCaFile = mkOption {
      description = "Path to a cert file for connecting to kubelet.";
      default = null;
      type = types.nullOr types.path;
    };

    kubeletClientCertFile = mkOption {
      description = "Client certificate to use for connections to kubelet.";
      default = null;
      type = types.nullOr types.path;
    };

    kubeletClientKeyFile = mkOption {
      description = "Key to use for connections to kubelet.";
      default = null;
      type = types.nullOr types.path;
    };

    kubeletHttps = mkOption {
      description = "Whether to use https for connections to kubelet.";
      default = true;
      type = types.bool;
    };

    proxyClientCertFile = mkOption {
      description = "Client certificate to use for connections to proxy.";
      default = null;
      type = types.nullOr types.path;
    };

    proxyClientKeyFile = mkOption {
      description = "Key to use for connections to proxy.";
      default = null;
      type = types.nullOr types.path;
    };

    runtimeConfig = mkOption {
      description = ''
        Api runtime configuration. See
        <link xlink:href="https://kubernetes.io/docs/tasks/administer-cluster/cluster-management/"/>
      '';
      default = "authentication.k8s.io/v1beta1=true";
      example = "api/all=false,api/v1=true";
      type = types.str;
    };

    storageBackend = mkOption {
      description = ''
        Kubernetes apiserver storage backend.
      '';
      default = "etcd3";
      type = types.enum ["etcd2" "etcd3"];
    };

    securePort = mkOption {
      description = "Kubernetes apiserver secure port.";
      default = 6443;
      type = types.int;
    };

    serviceAccountKeyFile = mkOption {
      description = ''
        Kubernetes apiserver PEM-encoded x509 RSA private or public key file,
        used to verify ServiceAccount tokens. By default tls private key file
        is used.
      '';
      default = null;
      type = types.nullOr types.path;
    };

    serviceClusterIpRange = mkOption {
      description = ''
        A CIDR notation IP range from which to assign service cluster IPs.
        This must not overlap with any IP ranges assigned to nodes for pods.
      '';
      default = "10.0.0.0/24";
      type = types.str;
    };

    tlsCertFile = mkOption {
      description = "Kubernetes apiserver certificate file.";
      default = null;
      type = types.nullOr types.path;
    };

    tlsKeyFile = mkOption {
      description = "Kubernetes apiserver private key file.";
      default = null;
      type = types.nullOr types.path;
    };

    tokenAuthFile = mkOption {
      description = ''
        Kubernetes apiserver token authentication file. See
        <link xlink:href="https://kubernetes.io/docs/reference/access-authn-authz/authentication"/>
      '';
      default = null;
      type = types.nullOr types.path;
    };

    webhookConfig = mkOption {
      description = ''
        Kubernetes apiserver Webhook config file. It uses the kubeconfig file format.
        See <link xlink:href="https://kubernetes.io/docs/reference/access-authn-authz/webhook/"/>
      '';
      default = null;
      type = types.nullOr types.path;
    };

    clusterServiceIP = mkOption {
      description = "Kubernetes apiservice cluster service IP.";
      default = (concatStringsSep "." (
        take 3 (splitString "." cfg.serviceClusterIpRange
      )) + ".1");
      type = types.str;
    };

    kubeconfig = mkOption {
      description = "Kubernetes cluster admin kubeconfig";
      type = types.submodule {
        imports = [ ../kubeconfig.nix ];

        options = {
          enable = mkOption {
            description = "Whether to create cluster admin kubeconfig file";
            type = types.bool;
            default = true;
          };
        };

        config = mkAliasDefinitions options.services.kubernetes.kubeconfig;
      };
      default = {};
    };

    bootstrap = {
      resources = mkOption {
        description = "Attribute set of kubernetes resources to boostrap.";
        type = types.attrsOf types.attrs;
        default = {};
      };

      kubeconfig = mkOption {
        description = "Kubernetes kubeconfig used for bootstrapping resources";
        type = types.submodule {
          imports = [ ../kubeconfig.nix ];
          config = mkAliasDefinitions options.services.kubernetes.kubeconfig;
        };
        default = {};
      };
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
      description = "Kubernetes apiserver extra command line options.";
      default = [];
      type = types.listOf types.str;
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    systemd.services.kube-apiserver = {
      description = "Kubernetes APIServer Service";
      wantedBy = [ "kube-control-plane.target" ];
      after = [ "etcd.service" ];
      requires = [ "etcd.service" ];
      path = [ pkgs.curl ];

      # wait until kube-apiserver is healthy, no authorization needed
      postStart = ''
        until curl -sSfk -o /dev/null https://${cfg.bindAddress}:${toString cfg.securePort}/healthz; do
          sleep 2
        done
      '';

      serviceConfig = {
        Slice = "kubernetes.slice";
        ExecStart = concatStringsSep " " ([
          "${top.package}/bin/kube-apiserver"
          "--allow-privileged=${boolToString cfg.allowPrivileged}"
          "--authorization-mode=${concatStringsSep "," cfg.authorizationMode}"
          (optionalString (elem "ABAC" cfg.authorizationMode)
          "--authorization-policy-file=${
            pkgs.writeText "kube-auth-policy.jsonl"
            (concatMapStringsSep "\n" (l: builtins.toJSON l) cfg.authorizationPolicy)
          }")
          (optionalString (elem "Webhook" cfg.authorizationMode)
            "--authorization-webhook-config-file=${cfg.webhookConfig}"
          )
          "--bind-address=${cfg.bindAddress}"
          (optionalString (cfg.advertiseAddress != null)
            "--advertise-address=${cfg.advertiseAddress}")
          (optionalString (cfg.clientCaFile != null)
            "--client-ca-file=${cfg.clientCaFile}")
          "--disable-admission-plugins=${concatStringsSep "," cfg.disableAdmissionPlugins}"
          "--enable-admission-plugins=${concatStringsSep "," cfg.enableAdmissionPlugins}"
          "--etcd-servers=${concatStringsSep "," cfg.etcd.servers}"
          (optionalString (cfg.etcd.caFile != null)
            "--etcd-cafile=${cfg.etcd.caFile}")
          (optionalString (cfg.etcd.certFile != null)
            "--etcd-certfile=${cfg.etcd.certFile}")
          (optionalString (cfg.etcd.keyFile != null)
            "--etcd-keyfile=${cfg.etcd.keyFile}")
          (optionalString (cfg.featureGates != [])
            "--feature-gates=${concatMapStringsSep "," (feature: "${feature}=true") cfg.featureGates}")
          (optionalString (cfg.basicAuthFile != null)
            "--basic-auth-file=${cfg.basicAuthFile}")
          "--kubelet-https=${boolToString cfg.kubeletHttps}"
          (optionalString (cfg.kubeletClientCaFile != null)
            "--kubelet-certificate-authority=${cfg.kubeletClientCaFile}")
          (optionalString (cfg.kubeletClientCertFile != null)
            "--kubelet-client-certificate=${cfg.kubeletClientCertFile}")
          (optionalString (cfg.kubeletClientKeyFile != null)
            "--kubelet-client-key=${cfg.kubeletClientKeyFile}")
          (optionalString (cfg.proxyClientCertFile != null)
            "--proxy-client-cert-file=${cfg.proxyClientCertFile}")
          (optionalString (cfg.proxyClientKeyFile != null)
            "--proxy-client-key-file=${cfg.proxyClientKeyFile}")
          (optionalString (cfg.runtimeConfig != "")
            "--runtime-config=${cfg.runtimeConfig}")
          "--secure-port=${toString cfg.securePort}"
          (optionalString (cfg.serviceAccountKeyFile!=null)
            "--service-account-key-file=${cfg.serviceAccountKeyFile}")
          "--service-cluster-ip-range=${cfg.serviceClusterIpRange}"
          "--storage-backend=${cfg.storageBackend}"
          (optionalString (cfg.tlsCertFile != null)
            "--tls-cert-file=${cfg.tlsCertFile}")
          (optionalString (cfg.tlsKeyFile != null)
            "--tls-private-key-file=${cfg.tlsKeyFile}")
          (optionalString (cfg.tokenAuthFile != null)
            "--token-auth-file=${cfg.tokenAuthFile}")
          (optionalString (cfg.verbosity != null) "--v=${toString cfg.verbosity}")
        ] ++ cfg.extraOpts);
        WorkingDirectory = top.dataDir;
        User = "kubernetes";
        Group = "kubernetes";
        AmbientCapabilities = "cap_net_bind_service";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.kube-bootstrap-resources = mkIf (cfg.bootstrap.resources != {}) {
      description = "Kubernetes bootstrap resources";
      wantedBy = [ "kubernetes.target" ];
      after = [ "kube-apiserver.service" ];
      requires = [ "kube-apiserver.service" ];
      environment = {
        KUBECONFIG = cfg.bootstrap.kubeconfig.file;
      };
      path = [ pkgs.kubectl ];

      # wait until kube-apiserver is ready
      preStart = with pkgs; ''
        until kubectl auth can-i -q '*' '*'>/dev/null; do
          echo kubectl auth can-i '*' '*': exit status $?
          sleep 2
        done
      '';

      # bootstrap resources and garbase collect old resources
      script = ''
        # apply resources
        kubectl apply -n kube-system -f ${resourcesJSON}

        # gc old resources
        kubectl delete all -A -l nixos.org/hash,nixos.org/hash!=${resourcesHash}
      '';

      serviceConfig = {
        Type = "oneshot";
        Slice = "kubernetes.slice";
        WorkingDirectory = top.dataDir;
        User = "kubernetes";
        Group = "kubernetes";
      };
    };

    environment.etc."kubernetes/cluster-admin.kubeconfig" = mkIf cfg.kubeconfig.enable {
      source = cfg.kubeconfig.file;
      user = "kubernetes";
    };

    services.kubernetes = {
      enabled = true;

      # this clusterRoleBinding is needed for kube-apiserver to communicate
      # with kubelet
      apiserver.bootstrap.resources.kube-apiserver-to-kubelet-crb = {
        apiVersion = "rbac.authorization.k8s.io/v1beta1";
        kind = "ClusterRoleBinding";
        metadata.name = "system:kube-apiserver";
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "system:kubelet-api-admin";
        };
        subjects = [{
          apiGroup = "rbac.authorization.k8s.io";
          kind = "User";
          name = "system:kube-apiserver";
        }];
      };
    };
  };
}
