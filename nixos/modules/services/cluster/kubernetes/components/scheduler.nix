{ options, config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  cfg = top.scheduler;

in {

  ###### interface
  options.services.kubernetes.scheduler = {
    enable = mkEnableOption "Kubernetes scheduler";

    bindAddress = mkOption {
      description = "Kubernetes scheduler listening address.";
      default = "127.0.0.1";
      type = types.str;
    };

    featureGates = mkOption {
      description = "List set of feature gates";
      default = top.featureGates;
      type = types.listOf types.str;
    };

    kubeconfig = mkOption {
      description = "Kubernetes scheduler kubeconfig.";
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

    securePort = mkOption {
      description = "Kubernetes scheduler listening port.";
      default = 10259;
      type = types.int;
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
      description = "Kubernetes scheduler extra command line options.";
      default = [];
      type = types.listOf types.str;
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    systemd.services.kube-scheduler = rec {
      description = "Kubernetes Scheduler Service";
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

      # wait until kube-scheduler is healthy, no authorization needed
      postStart = ''
        until curl -sSfk -o /dev/null https://${cfg.bindAddress}:${toString cfg.securePort}/healthz; do
          sleep 2
        done
      '';

      serviceConfig = {
        Slice = "kubernetes.slice";
        ExecStart = concatStringsSep " " ([
          "${top.package}/bin/kube-scheduler"
          "--bind-address=${cfg.bindAddress}"
          "--secure-port=${toString cfg.securePort}"
          (optionalString (cfg.featureGates != [])
            "--feature-gates=${concatMapStringsSep "," (feature: "${feature}=true") cfg.featureGates}")
          "--kubeconfig=${cfg.kubeconfig.file}"
          "--leader-elect=${boolToString cfg.leaderElect}"
          (optionalString (cfg.verbosity != null) "--v=${toString cfg.verbosity}")
        ] ++ cfg.extraOpts);
        WorkingDirectory = top.dataDir;
        User = "kubernetes";
        Group = "kubernetes";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    services.kubernetes.enabled = true;
  };
}
