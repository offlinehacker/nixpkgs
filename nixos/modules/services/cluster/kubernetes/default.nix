{ config, lib, ... }:

with lib;

let
  cfg = config.services.kubernetes;

  hasMasterRole = elem "master" cfg.roles;
  hasWorkerRole = elem "worker" cfg.roles;
  hasMultipleMasters = (length cfg.masterNodes) > 1;
  isSingleNode = cfg.roles == [];
  isMasterNode = isSingleNode || hasMasterRole;
  isWorkerNode = isSingleNode || hasWorkerRole;
  isPrimaryNode = cfg.nodeName == cfg.primaryNode;

  etcdEndpoints = map (n: "https://${n}:2379") cfg.masterNodes;

in {
  options.services.kubernetes = {
    enable = mkEnableOption "kubernetes";

    roles = mkOption {
      description = ''
        Kubernetes role that this machine should take.

        <itemizedlist>

        <listitem><para>
        <literal>master</literal> role will enable etcd, apiserver, scheduler,
        controller manager and proxy services.
        </para></listitem>

        <listitem><para>
        <literal>worker</literal> role will enable flannel, docker, kubelet and
        proxy services.
        </para></listitem>

        </itemizedlist>
      '';
      default = [];
      type = types.listOf (types.enum ["master" "worker"]);
    };

    nodeName = mkOption {
      description = "Name of the node (must be resolvable).";
      example = "node1";
      type = types.str;
      default = config.networking.hostName;
      defaultText = "\${config.networking.hostName}";
    };

    primaryNode = mkOption {
      description = "Name of the primary node (must be resolvable).";
      type = types.str;
      default = head cfg.masterNodes;
      defaultText = "first master node";
    };

    masterNodes = mkOption {
      description = "List of master node names (must be resolvable).";
      example = [ "node1" "node" "node3" ];
      type = types.listOf types.str;
      default = [ cfg.nodeName ];
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = mkIf (!isSingleNode) (mkMerge [
      (mkIf isMasterNode [
        6443 # kube apiserver
      ])

      (mkIf (hasMultipleMasters && isMasterNode) [
        2379 # etcd client port
        2380 # etcd peer port
      ])

      (mkIf (isWorkerNode && cfg.kubelet.enable) [
        10250 # kubelet
      ])

      (mkIf (isPrimaryNode && cfg.pki.certmgr.cfssl.enable) [
        8888 # cfssl
      ])
    ]);

    services.etcd = mkIf isMasterNode {
      enable = true;
      listenClientUrls = mkDefault
        (if hasMultipleMasters
         then ["https://0.0.0.0:2379"]
         else ["https://127.0.0.1:2379"]);
      listenPeerUrls = mkDefault
        (if hasMultipleMasters
         then ["https://0.0.0.0:2380"]
         else ["https://127.0.0.1:2380"]);
      initialCluster = map (n: "${n}=https://${n}:2380") cfg.masterNodes;
      initialAdvertisePeerUrls = mkDefault ["https://${cfg.nodeName}:2380"];
    };

    services.cfssl = {
      initssl.csr.hosts = [ "localhost" cfg.nodeName ];
      address = mkIf (!isSingleNode) "0.0.0.0";
    };

    services.kubernetes = {
      # defaults to primary node, since kubernetes does not support multiple
      # addresses and requires load balancer, set this to load balancer address
      # in production
      apiserverAddress = mkDefault "https://${cfg.primaryNode}:6443";

      apiserver = {
        enable = mkDefault isMasterNode;
        etcd.servers = etcdEndpoints;
      };
      controllerManager = {
        enable = mkDefault isMasterNode;
        allocateNodeCIDRs = true;
      };
      scheduler.enable = mkDefault isMasterNode;

      kubelet = {
        enable = mkDefault true;
        hostname = mkDefault cfg.nodeName;

        # kubelet is unschedulable by default on masters, except if also
        # running as a node
        taints = mkIf (isMasterNode && !isWorkerNode) {
          master = {
            key = "node-role.kubernetes.io/master";
            value = "true";
            effect = "NoSchedule";
          };
        };
      };
      proxy.enable = mkDefault true;

      runtime.docker.enable = mkDefault true;

      # enable flannel by default if not running on single node
      networking.flannel.enable = mkDefault (!isSingleNode);

      pki = {
        enable = mkDefault true;
        certmgr = {
          enable = mkDefault true;
          cfssl = {
            enable = mkDefault isPrimaryNode;
            remote = mkIf (!isPrimaryNode) "https://${cfg.primaryNode}:8888";
            rootCA = mkIf (!isPrimaryNode) "/var/lib/kubernetes/pki/ca.crt";
            authKeyFile =
              mkIf (!isPrimaryNode) (mkDefault "/var/lib/kubernetes/pki/cfssl-auth-key.secret");
          };
        };

        certs = {
          apiserver.csr.hosts = [ cfg.nodeName ];
          etcdServer.csr.hosts = [ cfg.nodeName ];
        };

        serviceAccountCertSync = {
          enable = mkDefault isMasterNode;
          etcd.endpoints = mkDefault etcdEndpoints;
          serviceAccountCertSync = mkDefault true;
          serviceAccountCertUpsert = mkDefault true;
        };
      };
    };
  };
}
