# this test checks whether k8s integration with certmgr pki works

import ../make-test.nix ({ pkgs, ...} : {
  name = "k8s-certmgr-pki";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    one = { config, pkgs, ... }: {
      virtualisation.memorySize = 768;

      environment.systemPackages = [ pkgs.openssl.bin ];

      services.kubernetes = {
        pki = {
          enable = true;
          certmgr.enable = true;

          certs = {
            apiserver.enable = true;
            apiserverProxyClient.enable = true;
            apiserverKubeletClient.enable = true;
            apiserverEtcdClient.enable = true;
            clusterAdmin.enable = true;
            resourceBootstrapper.enable = true;
            controllerManager.enable = true;
            controllerManagerClient.enable = true;
            serviceAccountSigner.enable = true;
            schedulerClient.enable = true;
            kubelet.enable = true;
            kubeletClient.enable = true;
            kubeProxyClient.enable = true;
          };
        };
      };
    };
  };

  testScript = ''
    startAll;

    $one->waitForUnit("kube-pki.target");
    $one->waitForUnit("certmgr.service");
    $one->succeed("openssl verify -CAfile /var/lib/kubernetes/pki/kube-apiserver.ca.crt /var/lib/kubernetes/pki/kube-apiserver.crt");
    $one->succeed("openssl verify -CAfile /var/lib/kubernetes/pki/kubelet.ca.crt /var/lib/kubernetes/pki/kubelet.crt");
  '';
})
