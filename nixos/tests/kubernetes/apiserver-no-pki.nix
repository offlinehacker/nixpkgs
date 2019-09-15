# this test deploys only k8s apiserver with no special configuration and checks
# whether it starts fine

import ../make-test.nix ({ pkgs, ...} : {
  name = "k8s-apiserver-only-no-pki";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    one = { config, ... }: let
      token = builtins.hashString "sha1" "cluster-admin";
    in {
      virtualisation.memorySize = 512;

      environment.systemPackages = [ pkgs.kubectl ];

      services.kubernetes.apiserver = {
        enable = true;

        kubeconfig = {
          inherit token;
          insecureSkipTlsVerify = true;
        };

        # since we have no PKI, we need other means of authentication with apiserver
        tokenAuthFile = pkgs.writeText "k8s-tokens" ''
          ${token},cluster-admin,cluster-admin,"system:masters"
        '';
      };

      services.etcd.enable = true;
    };
  };

  testScript = ''
    startAll;

    $one->waitForUnit("kube-control-plane.target");
    $one->succeed("kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig cluster-info | grep -i 'kubernetes master is running'");
  '';
})
