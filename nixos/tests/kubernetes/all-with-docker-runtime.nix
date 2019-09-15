# this test deploys k8s control plane and tests integration of kubelet and
# docker runtime

import ../make-test.nix ({ pkgs, ...} : {
  name = "k8s-all-with-docker-runtime";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    one = { config, ... }: let
      busyboxContainer = pkgs.dockerTools.buildImage {
        name = "busybox";
        tag = "latest";
        contents = pkgs.busybox;
        config.Cmd = "/bin/sh";
      };
    in {
      virtualisation.memorySize = 768;

      environment.systemPackages = [ pkgs.kubectl ];

      services.kubernetes = {
        apiserver.enable = true;
        controllerManager.enable = true;
        scheduler.enable = true;
        kubelet.enable = true;
        proxy.enable = true;
        runtime.docker = {
          enable = true;
          seedDockerImages = [ busyboxContainer ];
        };

        pki = {
          enable = true;
          local.enable = true;

          certs.apiserver.csr.hosts = ["one"];
          certs.etcdServer = {
            name = "etcd-server";
            kind = "server";
            csr = {
              CN = "etcd-server";
              hosts = ["127.0.0.1" "one"];
            };
            privateKeyOwner = "etcd";
          };
        };
      };

      services.etcd = {
        enable = true;

        clientCertAuth = true;
        peerClientCertAuth = true;
        certFile = config.services.kubernetes.pki.certs.etcdServer.cert;
        keyFile = config.services.kubernetes.pki.certs.etcdServer.key;
        trustedCaFile = config.services.kubernetes.pki.certs.etcdServer.ca.cert;
        listenClientUrls = ["https://127.0.0.1:2379"];
        listenPeerUrls = ["https://0.0.0.0:2380"];
        initialCluster = ["one=https://one:2380"];
        initialAdvertisePeerUrls = ["https://one:2380"];
      };
    };
  };

  testScript = ''
    startAll;

    $one->waitForUnit("kube-control-plane.target");
    $one->waitForUnit("kube-runtime.target");
    $one->waitForUnit("kube-worker.target");
    $one->waitForUnit("kubernetes.target");
    $one->requireActiveUnit("docker.service");
    $one->requireActiveUnit("kube-apiserver.service");
    $one->requireActiveUnit("kube-controller-manager.service");
    $one->requireActiveUnit("kube-scheduler.service");
    $one->requireActiveUnit("kubelet.service");
    $one->requireActiveUnit("kube-proxy.service");

    $one->waitUntilSucceeds("kubectl run -ti --rm --image=busybox:latest --image-pull-policy=Never busybox echo 'hello from kubernetes' | grep -i 'hello from kubernetes'")
  '';
})
