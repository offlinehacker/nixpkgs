{ options, config, lib, pkgs, ... }:

with lib;

let
  top = config.services.kubernetes;
  cfg = top.kubelet;

  cniConfig =
    if cfg.cni.config != [] && !(isNull cfg.cni.configDir) then
      throw "Verbatim CNI-config and CNI configDir cannot both be set."
    else if !(isNull cfg.cni.configDir) then
      cfg.cni.configDir
    else
      (pkgs.buildEnv {
        name = "kubernetes-cni-config";
        paths = imap (i: entry:
          pkgs.writeTextDir "${toString (10+i)}-${entry.type}.conf" (builtins.toJSON entry)
        ) cfg.cni.config;
      });

  manifests = pkgs.buildEnv {
    name = "kubernetes-manifests";
    paths = mapAttrsToList (name: manifest:
      pkgs.writeTextDir "${name}.json" (builtins.toJSON manifest)
    ) cfg.manifests;
  };

  manifestPath = "kubernetes/manifests";

  taintOptions = { name, ... }: {
    options = {
      key = mkOption {
        description = "Key of taint.";
        default = name;
        type = types.str;
      };

      value = mkOption {
        description = "Value of taint.";
        type = types.str;
      };

      effect = mkOption {
        description = "Effect of taint.";
        example = "NoSchedule";
        type = types.enum ["NoSchedule" "PreferNoSchedule" "NoExecute"];
      };
    };
  };

  taints = concatMapStringsSep "," (v: "${v.key}=${v.value}:${v.effect}") (mapAttrsToList (n: v: v) cfg.taints);

in {

  ###### interface
  options.services.kubernetes.kubelet = {
    enable = mkEnableOption "Kubernetes kubelet.";

    address = mkOption {
      description = "Kubernetes kubelet info server listening address.";
      default = "0.0.0.0";
      type = types.str;
    };

    allowPrivileged = mkOption {
      description = "Whether to allow Kubernetes containers to request privileged mode.";
      default = false;
      type = types.bool;
    };

    clusterDns = mkOption {
      description = "Use alternative DNS.";
      default = "10.1.0.1";
      type = types.str;
    };

    clusterDomain = mkOption {
      description = "Use alternative domain.";
      default = "cluster.local";
      type = types.str;
    };

    clientCaFile = mkOption {
      description = "Kubernetes apiserver CA file for client authentication.";
      default = null;
      type = types.nullOr types.path;
    };

    cni = {
      packages = mkOption {
        description = "List of network plugin packages to install.";
        type = types.listOf types.package;
        default = [];
      };

      config = mkOption {
        description = "Kubernetes CNI configuration.";
        type = types.listOf types.attrs;
        default = [];
        example = literalExample ''
          [{
            "cniVersion": "0.2.0",
            "name": "mynet",
            "type": "bridge",
            "bridge": "cni0",
            "isGateway": true,
            "ipMasq": true,
            "ipam": {
                "type": "host-local",
                "subnet": "10.22.0.0/16",
                "routes": [
                    { "dst": "0.0.0.0/0" }
                ]
            }
          } {
            "cniVersion": "0.2.0",
            "type": "loopback"
          }]
        '';
      };

      configDir = mkOption {
        description = "Path to Kubernetes CNI configuration directory.";
        type = types.nullOr types.path;
        default = null;
      };
    };

    featureGates = mkOption {
      description = "List set of feature gates";
      default = top.featureGates;
      defaultText = "config.kubernetes.featureGates";
      type = types.listOf types.str;
    };

    healthz = {
      bindAddress = mkOption {
        description = "Kubernetes kubelet healthz listening address.";
        default = "127.0.0.1";
        type = types.str;
      };

      port = mkOption {
        description = "Kubernetes kubelet healthz port.";
        default = 10248;
        type = types.int;
      };
    };

    hostname = mkOption {
      description = "Kubernetes kubelet hostname override.";
      type = types.str;
      default = config.networking.hostName;
      defaultText = "config.networking.hostName";
    };

    kubeconfig = mkOption {
      description = "Kubernetes kubelet kubeconfig.";
      type = types.submodule {
        imports = [ ../kubeconfig.nix ];
        config = mkAliasDefinitions options.services.kubernetes.kubeconfig;
      };
      default = {};
    };

    manifests = mkOption {
      description = "List of manifests to bootstrap with kubelet (only pods can be created as manifest entry)";
      type = types.attrsOf types.attrs;
      default = {};
    };

    networkPlugin = mkOption {
      description = "Network plugin to use by kubernetes kubelet.";
      type = types.nullOr (types.enum ["cni" "kubenet"]);
      default = "kubenet";
    };

    podCIDR = mkOption {
      description = " The CIDR to use for pod IP addresses, only used in standalone mode.";
      type = types.nullOr types.str;
      default = null;
    };

    nodeIp = mkOption {
      description = "IP address of the node. If set, kubelet will use this IP address for the node.";
      default = null;
      type = types.nullOr types.str;
    };

    registerNode = mkOption {
      description = "Whether to auto register kubelet with API server.";
      default = true;
      type = types.bool;
    };

    port = mkOption {
      description = "Kubernetes kubelet info server listening port.";
      default = 10250;
      type = types.int;
    };

    taints = mkOption {
      description = "Node taints (https://kubernetes.io/docs/concepts/configuration/assign-pod-node/).";
      default = {};
      type = types.attrsOf (types.submodule [ taintOptions ]);
    };

    tlsCertFile = mkOption {
      description = "File containing x509 Certificate for HTTPS.";
      default = null;
      type = types.nullOr types.path;
    };

    tlsKeyFile = mkOption {
      description = "File containing x509 private key matching tlsCertFile.";
      default = null;
      type = types.nullOr types.path;
    };

    unschedulable = mkOption {
      description = "Whether to set node taint to unschedulable=true as it is the case of node that has only master role.";
      default = false;
      type = types.bool;
    };

    path = mkOption {
      description = "Packages added to the services' PATH environment variable. Both the bin and sbin subdirectories of each package are added.";
      type = types.listOf types.package;
      default = [];
    };

    verbosity = mkOption {
      description = ''
        Optional glog verbosity level for logging statements. See
        <link xlink:href="https://github.com/kubernetes/community/blob/master/contributors/devel/logging.md"/>
      '';
      default = null;
      type = types.nullOr types.int;
    };

    podInfraContainerImage = mkOption {
      description = "Image to use for kubernetes pod infra container";
      default = null;
      type = types.nullOr types.str;
    };

    extraOpts = mkOption {
      description = "Kubernetes kubelet list of extra command line options.";
      default = [];
      type = types.listOf types.str;
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    services.kubernetes.kubelet = {
      # default packages required by kubelet
      path = with pkgs; [
        curl gitMinimal openssh utillinux iproute ethtool
        thin-provisioning-tools iptables socat
      ];

      # default CNI packages
      cni.packages = [ pkgs.cni-plugins ];

      # if kubelet is set as unschedulable, set taint
      taints.unschedulable = mkIf cfg.unschedulable {
        value = "true";
        effect = "NoSchedule";
      };
    };

    systemd.services.kubelet = {
      description = "Kubernetes Kubelet Service";
      wantedBy = [ "kube-worker.target" ];
      before = [ "kube-worker.target" ];
      after = [ "kube-runtime.target" ];
      requires = [ "kube-runtime.target" ];
      path = cfg.path;

      # initialize container network interfaces
      preStart = ''
        rm -f /opt/cni/bin/* || true
        ${concatMapStrings (package: ''
          echo "Linking cni package: ${package}"
          ln -fs ${package}/bin/* /opt/cni/bin
        '') cfg.cni.packages}
      '';

      # wait until kubelet is healthy, no authorization needed
      postStart = ''
        until curl -sSf -o /dev/null http://${cfg.healthz.bindAddress}:${toString cfg.healthz.port}/healthz; do
          sleep 2
        done
      '';

      serviceConfig = {
        Slice = "kubernetes.slice";
        CPUAccounting = true;
        MemoryAccounting = true;
        Restart = "on-failure";
        RestartSec = "1000ms";
        ExecStart = concatStringsSep " " ([
          "${top.package}/bin/kubelet"
          "--address=${cfg.address}"
          "--allow-privileged=${boolToString cfg.allowPrivileged}"
          "--authentication-token-webhook"
          ''--authentication-token-webhook-cache-ttl="10s"''
          "--authorization-mode=Webhook"
          (optionalString (cfg.clientCaFile != null)
            "--client-ca-file=${cfg.clientCaFile}")
          (optionalString (cfg.clusterDns != "")
            "--cluster-dns=${cfg.clusterDns}")
          (optionalString (cfg.clusterDomain != "")
            "--cluster-domain=${cfg.clusterDomain}")
          "--cni-conf-dir=${cniConfig}"
          (optionalString (cfg.featureGates != [])
            "--feature-gates=${concatMapStringsSep "," (feature: "${feature}=true") cfg.featureGates}")
          "--hairpin-mode=hairpin-veth"
          "--healthz-bind-address=${cfg.healthz.bindAddress}"
          "--healthz-port=${toString cfg.healthz.port}"
          "--hostname-override=${cfg.hostname}"
          "--kubeconfig=${cfg.kubeconfig.file}"
          (optionalString (cfg.networkPlugin != null)
            "--network-plugin=${cfg.networkPlugin}")
          (optionalString (cfg.podCIDR != null)
            "--pod-cidr=${cfg.podCIDR}")
          (optionalString (cfg.nodeIp != null)
            "--node-ip=${cfg.nodeIp}")
          (optionalString (cfg.podInfraContainerImage != null)
            "--pod-infra-container-image=${cfg.podInfraContainerImage}")
          (optionalString (cfg.manifests != {})
            "--pod-manifest-path=/etc/${manifestPath}")
          "--port=${toString cfg.port}"
          "--register-node=${boolToString cfg.registerNode}"
          (optionalString (taints != "")
            "--register-with-taints=${taints}")
          "--root-dir=${top.dataDir}"
          (optionalString (cfg.tlsCertFile != null)
            "--tls-cert-file=${cfg.tlsCertFile}")
          (optionalString (cfg.tlsKeyFile != null)
            "--tls-private-key-file=${cfg.tlsKeyFile}")
          (optionalString (cfg.verbosity != null) "--v=${toString cfg.verbosity}")
        ] ++ cfg.extraOpts);
        WorkingDirectory = top.dataDir;
      };
    };

    environment.etc = mapAttrs' (name: manifest:
      nameValuePair "${manifestPath}/${name}.json" {
        text = builtins.toJSON manifest;
        mode = "0755";
      }
    ) cfg.manifests;

    # kube-runtime target defines target for kubernetes runtimes like
    # docker, containerd, crio and similar
    systemd.targets.kube-runtime = {
      wantedBy = [ "kube-worker.target" ];
      before = [ "kube-worker.target" ];
    };

    systemd.targets.kube-networking = {
      wantedBy = [ "kube-worker.target" ];
      before = [ "kube-worker.target" ];
    };

    systemd.tmpfiles.rules = [
      # container network interface binaries
      "d /opt/cni/bin 0755 root root -"
    ];

    services.kubernetes.enabled = true;
  };
}
