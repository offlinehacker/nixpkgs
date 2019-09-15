# this test deploys only k8s apiserver and tests its integration with pki

import ../make-test.nix ({ pkgs, ...} : {
  name = "k8s-control-plane-no-pki";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    one = { config, ... }: let
      clusterAdminToken = builtins.hashString "sha1" "cluster-admin";
      controllerManagerToken = builtins.hashString "sha1" "controller-manager";
      schedulerToken = builtins.hashString "sha1" "scheduler";
    in {
      virtualisation.memorySize = 512;

      environment.systemPackages = [ pkgs.kubectl ];

      services.kubernetes = {
        kubeconfig.insecureSkipTlsVerify = true;

        apiserver = {
          enable = true;
          kubeconfig.token = clusterAdminToken;

          # since we have no PKI, we need other means of authentication with apiserver
          tokenAuthFile = pkgs.writeText "k8s-tokens" ''
            ${clusterAdminToken},cluster-admin,cluster-admin,"system:masters"
            ${controllerManagerToken},system:kube-controller-manager,system:kube-controller-manager,"system:kube-controller-manager"
            ${schedulerToken},system:kube-scheduler,system:kube-scheduler,"system:kube-scheduler"
          '';
        };

        controllerManager = {
          enable = true;
          kubeconfig.token = controllerManagerToken;
        };

        scheduler = {
          enable = true;
          kubeconfig.token = schedulerToken;
        };
      };

      services.etcd.enable = true;
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
