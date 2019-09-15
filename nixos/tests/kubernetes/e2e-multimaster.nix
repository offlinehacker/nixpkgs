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
    virtualisation.cores = 2;

    services.kubernetes = {
      enable = true;
      masterNodes = [ "node1" "node2" "node3" ];
      runtime.docker.seedDockerImages = [ busyboxContainer kuardContainer ];
    };

    services.flannel.iface = "eth1";
    environment.systemPackages = [ pkgs.kubectl ];
  };

  master = {
    services.kubernetes.roles = [ "master" ];
  };

  worker = {
    services.kubernetes.roles = [ "worker" ];
  };

in {
  name = "k8s-e2e-multimaster";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    node1 = { config, nodes, ... }: {
      imports = [ base master worker ];
    };

    node2 = { config, nodes, ... }: {
      imports = [ base master worker ];
    };

    node3 = { config, nodes, ... }: {
      imports = [ base master worker ];
    };
  };

  testScript = ''
    startAll;

    $node1->waitForUnit("cfssl.service");

    my ($status, $authKey) = $node1->execute_("cat /var/lib/cfssl/default-key.secret");

    $node2->execute("echo '$authKey' > /var/lib/kubernetes/pki/cfssl-auth-key.secret");
    $node3->execute("echo '$authKey' > /var/lib/kubernetes/pki/cfssl-auth-key.secret");

    $node1->waitForUnit("kubernetes.target");
    $node2->waitForUnit("kubernetes.target");
    $node3->waitForUnit("kubernetes.target");

    $node1->waitUntilSucceeds("kubectl get nodes node1 | grep -i Ready");
    $node2->waitUntilSucceeds("kubectl get nodes node2 | grep -i Ready");
    $node3->waitUntilSucceeds("kubectl get nodes node3 | grep -i Ready");

    $node1->succeed("kubectl run --image=kuard:latest --image-pull-policy=Never --port=8080 --replicas=3 kuard");
    $node1->succeed("kubectl expose deployment kuard --port=8080");
    $node1->waitUntilSucceeds("curl http://`kubectl get services -o template --template='{{.spec.clusterIP}}' kuard`:8080");
    $node2->waitUntilSucceeds("curl http://`kubectl get services -o template --template='{{.spec.clusterIP}}' kuard`:8080");
    $node3->waitUntilSucceeds("curl http://`kubectl get services -o template --template='{{.spec.clusterIP}}' kuard`:8080");
  '';
})
