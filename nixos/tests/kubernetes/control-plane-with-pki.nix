# this test deploys k8s control plane and tests its integration with pki

import ../make-test.nix ({ pkgs, ...} : {
  name = "k8s-control-plane-with-pki";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    one = { config, ... }: {
      virtualisation.memorySize = 512;

      environment.systemPackages = [ pkgs.kubectl ];

      services.kubernetes = {
        apiserver.enable = true;
        controllerManager.enable = true;
        scheduler.enable = true;

        pki = {
          enable = true;
          local.enable = true;

          certs.apiserver.csr.hosts = ["one"];
          certs.etcdServer.csr.hosts = ["127.0.0.1" "one"];
        };
      };

      services.etcd = {
        enable = true;
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
    $one->requireActiveUnit("kube-apiserver.service");
    $one->requireActiveUnit("kube-controller-manager.service");
    $one->requireActiveUnit("kube-scheduler.service");
    $one->succeed("kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig cluster-info | grep -i 'kubernetes master is running'");
  '';
})
