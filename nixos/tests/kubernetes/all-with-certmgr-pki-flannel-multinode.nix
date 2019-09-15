# this test deploys k8s control plane and tests integration of kubelet and
# docker runtime

import ../make-test.nix ({ pkgs, lib, ...} :

with lib;

let
  busyboxContainer = pkgs.dockerTools.buildImage {
    name = "busybox";
    tag = "latest";
    contents = pkgs.busybox;
    config.Cmd = "/bin/sh";
  };

  kuardContainer = pkgs.dockerTools.buildImage {
    name = "kuard";
    tag = "latest";
    contents = pkgs.kuard;
    config.Cmd = "/bin/kuard";
  };

  base = {
    virtualisation.memorySize = 768;
    virtualisation.cores = 3;

    environment.systemPackages = [ pkgs.kubectl ];

    networking.firewall.allowedTCPPorts = [ 10250 ];

    services.flannel.iface = "eth1";

    services.kubernetes = {
      kubelet.enable = true;
      networking.flannel.enable = true;

      proxy.enable = true;
      runtime.docker = {
        enable = true;
        seedDockerImages = [ busyboxContainer kuardContainer ];
      };

      pki = {
        enable = true;
        certmgr = {
          enable = true;
          cfssl = {
            enable = false;
            remote = "https://cfssl:8888";
            rootCA = "/var/lib/kubernetes/pki/ca.crt";
            authKeyFile = "/var/lib/kubernetes/pki/cfssl-auth-key.secret";
          };
        };
      };
    };
  };

  master = { config, nodes, ... }: {
    imports = [ base ];

    networking.firewall.allowedTCPPorts = [ 6443 2379 2380 ];

    services.etcd = {
      enable = true;
      listenClientUrls = ["https://0.0.0.0:2379"];
      listenPeerUrls = ["https://0.0.0.0:2380"];
      initialCluster = [
        "master1=https://master1:2380"
        "master2=https://master2:2380"
        "master3=https://master3:2380"
      ];
      initialAdvertisePeerUrls = ["https://${config.networking.hostName}:2380"];
      extraConf = {
        HEARTBEAT_INTERVAL = "1000";
        ELECTION_TIMEOUT = "5000";
      };
    };

    services.kubernetes = {
      apiserver.enable = true;
      controllerManager.enable = true;
      scheduler.enable = true;

      pki = {
        certs.apiserver.csr.hosts = [ config.networking.hostName ];
        certs.etcdServer.csr.hosts = [ config.networking.hostName ];

        serviceAccountCertSync = {
          enable = true;
          etcd.endpoints =
            mapAttrsToList (_: node: "https://${node.config.networking.hostName}:2379") nodes;
          serviceAccountCertUpsert = true;
          serviceAccountCertSync = true;
        };
      };
    };
  };

  worker = { config, ... }: {
    services.kubernetes = {
      kubelet.enable = true;
      proxy.enable = true;
      runtime.docker.enable = true;
    };
  };

in {
  name = "k8s-all-with-certmgr-pki-multinode";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    # node exposing cfssl
    cfssl = { config, ... }: {
      networking.firewall.allowedTCPPorts = [ 8888 ];

      virtualisation.memorySize = 256;

      services.cfssl = {
        initssl.csr.hosts = ["cfssl"];
        address = "0.0.0.0";
      };

      # enable integration of cfssl with kubernetes
      services.kubernetes.pki.certmgr.cfssl.enable = true;
    };

    master1 = { config, nodes, ... }: {
      imports = [ master ];
    };

    master2 = { config, nodes, ... }: {
      imports = [ master ];
    };

    master3 = { config, nodes, ... }: {
      imports = [ master ];
    };
  };

  testScript = ''
    startAll;

    $cfssl->waitForUnit("cfssl.service");

    my ($status, $authKey) = $cfssl->execute_("cat /var/lib/cfssl/default-key.secret");

    $master1->execute("echo '$authKey' > /var/lib/kubernetes/pki/cfssl-auth-key.secret");
    $master2->execute("echo '$authKey' > /var/lib/kubernetes/pki/cfssl-auth-key.secret");
    $master3->execute("echo '$authKey' > /var/lib/kubernetes/pki/cfssl-auth-key.secret");

    $master1->waitForUnit("kubernetes.target");
    $master2->waitForUnit("kubernetes.target");
    $master3->waitForUnit("kubernetes.target");

    $master1->waitUntilSucceeds("kubectl get nodes master1 | grep -i Ready");
    $master2->waitUntilSucceeds("kubectl get nodes master2 | grep -i Ready");
    $master3->waitUntilSucceeds("kubectl get nodes master3 | grep -i Ready");

    $master1->succeed("kubectl run --image=kuard:latest --image-pull-policy=Never --port=8080 --replicas=3 kuard");
    $master1->waitUntilSucceeds("kubectl get deployment kuard -o jsonpath='{.status.readyReplicas}' | grep 3");

    $master1->succeed("curl http://`kubectl get pods -l run=kuard -o jsonpath='{.items[0].status.podIP}'`:8080");
    $master1->succeed("curl http://`kubectl get pods -l run=kuard -o jsonpath='{.items[1].status.podIP}'`:8080");
    $master1->succeed("curl http://`kubectl get pods -l run=kuard -o jsonpath='{.items[2].status.podIP}'`:8080");

    $master2->succeed("curl http://`kubectl get pods -l run=kuard -o jsonpath='{.items[0].status.podIP}'`:8080");
    $master2->succeed("curl http://`kubectl get pods -l run=kuard -o jsonpath='{.items[1].status.podIP}'`:8080");
    $master2->succeed("curl http://`kubectl get pods -l run=kuard -o jsonpath='{.items[2].status.podIP}'`:8080");

    $master3->succeed("curl http://`kubectl get pods -l run=kuard -o jsonpath='{.items[0].status.podIP}'`:8080");
    $master3->succeed("curl http://`kubectl get pods -l run=kuard -o jsonpath='{.items[1].status.podIP}'`:8080");
    $master3->succeed("curl http://`kubectl get pods -l run=kuard -o jsonpath='{.items[2].status.podIP}'`:8080");

    $master1->succeed("kubectl expose deployment kuard --port=8080 --cluster-ip=10.0.0.100");
    $master1->waitUntilSucceeds("curl http://10.0.0.100:8080");
    $master2->succeed("curl http://10.0.0.100:8080");
    $master3->succeed("curl http://10.0.0.100:8080");
  '';
})
