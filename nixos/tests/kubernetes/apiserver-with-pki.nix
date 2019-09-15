# this test deploys only k8s apiserver and tests its integration with pki

import ../make-test.nix ({ pkgs, ...} : {
  name = "k8s-apiserver-only-with-pki";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    one = { config, ... }: {
      virtualisation.memorySize = 512;

      environment.systemPackages = [ pkgs.kubectl ];

      services.kubernetes = {
        apiserver.enable = true;
        pki = {
          enable = true;
          local.enable = true;

          certs.apiserver.csr.hosts = ["one"];
          certs.etcdServer.csr.hosts = [ "one" ];
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
    $one->succeed("kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig cluster-info | grep -i 'kubernetes master is running'");
  '';
})
