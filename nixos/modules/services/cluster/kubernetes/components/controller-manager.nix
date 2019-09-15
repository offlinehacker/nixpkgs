{ options, config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  cfg = top.controllerManager;

in {

  ###### interface
  options.services.kubernetes.controllerManager = {
    enable = mkEnableOption "Kubernetes controller manager";

    allocateNodeCIDRs = mkOption {
      description = "Whether to automatically allocate CIDR ranges for cluster nodes.";
      default = true;
      type = types.bool;
    };

    bindAddress = mkOption {
      description = "Kubernetes controller manager listening address.";
      default = "127.0.0.1";
      type = types.str;
    };

    clusterCidr = mkOption {
      description = "Kubernetes CIDR Range for Pods in cluster.";
      default = top.clusterCidr;
      type = types.str;
    };

    featureGates = mkOption {
      description = "List set of feature gates";
      default = top.featureGates;
      type = types.listOf types.str;
    };

    kubeconfig = mkOption {
      description = "Kubernetes controller manager kubeconfig.";
      type = types.submodule {
        imports = [ ../kubeconfig.nix ];
        config = mkAliasDefinitions options.services.kubernetes.kubeconfig;
      };
      default = {};
    };

    leaderElect = mkOption {
      description = "Whether to start leader election before executing main loop.";
      type = types.bool;
      default = true;
    };

    rootCaFile = mkOption {
      description = ''
        Kubernetes controller manager certificate authority file included in
        service account's token secret.
      '';
      default = null;
      type = types.nullOr types.path;
    };

    securePort = mkOption {
      description = "Kubernetes controller manager secure listening port.";
      default = 10257;
      type = types.int;
    };

    serviceAccountKeyFile = mkOption {
      description = ''
        Kubernetes controller manager PEM-encoded private RSA key file used to
        sign service account tokens
      '';
      default = null;
      type = types.nullOr types.path;
    };

    useServiceAccountCredentials = mkOption {
      description = ''
        Run each control loop using separate service account. Corresponding
        roles exist for each control loop, prefixed with system:controller.
        If this flag is disabled, it runs all control loops using its own
        credentials.
      '';
      default = cfg.serviceAccountKeyFile != null;
      type = types.bool;
    };

    controllers = mkOption {
      description = "List of controllers to run. (use * to run all controllers)";
      default = ["*"];
      type = types.listOf types.str;
      example = ["*" "tokencleaner" "bootstrapsigner"];
    };

    tlsCertFile = mkOption {
      description = "Kubernetes controller-manager certificate file.";
      default = null;
      type = types.nullOr types.path;
    };

    tlsKeyFile = mkOption {
      description = "Kubernetes controller-manager private key file.";
      default = null;
      type = types.nullOr types.path;
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
      description = "Kubernetes controller manager extra command line options.";
      default = [];
      type = types.listOf types.str;
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    systemd.services.kube-controller-manager = {
      description = "Kubernetes Controller Manager Service";
      wantedBy = [ "kube-control-plane.target" ];
      after = [ "kube-apiserver.service" ];
      path = [ pkgs.kubectl pkgs.curl ];
      environment.KUBECONFIG = cfg.kubeconfig.file;

      # wait until kube-apiserver is avalible
      preStart = ''
        until kubectl auth can-i -q get /api >/dev/null; do
          echo kubectl auth can-i get /api: exit status $?
          sleep 2
        done
      '';

      # wait until kube-controller-manager is healthy, no authorization needed
      postStart = ''
        until curl -sSfk -o /dev/null https://${cfg.bindAddress}:${toString cfg.securePort}/healthz; do
          sleep 2
        done
      '';

      serviceConfig = {
        RestartSec = "30s";
        Restart = "on-failure";
        Slice = "kubernetes.slice";
        ExecStart = concatStringsSep " " ([
          "${top.package}/bin/kube-controller-manager"
          "--allocate-node-cidrs=${boolToString cfg.allocateNodeCIDRs}"
          "--bind-address=${cfg.bindAddress}"
          (optionalString (cfg.clusterCidr!=null)
            "--cluster-cidr=${cfg.clusterCidr}")
          (optionalString (cfg.featureGates != [])
            "--feature-gates=${concatMapStringsSep "," (feature: "${feature}=true") cfg.featureGates}")
          "--kubeconfig=${cfg.kubeconfig.file}"
          "--leader-elect=${boolToString cfg.leaderElect}"
          (optionalString (cfg.rootCaFile!=null)
            "--root-ca-file=${cfg.rootCaFile}")
          "--secure-port=${toString cfg.securePort}"
          (optionalString (cfg.serviceAccountKeyFile!=null)
            "--service-account-private-key-file=${cfg.serviceAccountKeyFile}")
          (optionalString (cfg.tlsCertFile!=null)
            "--tls-cert-file=${cfg.tlsCertFile}")
          (optionalString (cfg.tlsKeyFile!=null)
            "--tls-private-key-file=${cfg.tlsKeyFile}")
          (optionalString (cfg.useServiceAccountCredentials)
            "--use-service-account-credentials")
          "--controllers=${concatStringsSep "," cfg.controllers}"
          (optionalString (cfg.verbosity != null) "--v=${toString cfg.verbosity}")
        ] ++ cfg.extraOpts);
        WorkingDirectory = top.dataDir;
        User = "kubernetes";
        Group = "kubernetes";
      };
    };

    services.kubernetes.enabled = true;
  };
}
