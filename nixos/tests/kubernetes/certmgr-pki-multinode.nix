# this test checks whether k8s integration with certmgr pki works

import ../make-test.nix ({ pkgs, ...} : let
  baseConfig = { config, pkgs, ... }: {
    virtualisation.memorySize = 386;

    environment.systemPackages = [ pkgs.openssl.bin ];

    services.kubernetes = {
      pki = {
        enable = true;
        certmgr.enable = true;

        serviceAccountCertSync = {
          enable = true;
          etcd.endpoints = ["https://one:2379"];
          serviceAccountCertUpsert = true;
          serviceAccountCertSync = true;
        };

        certs = {
          apiserver.enable = true;
          kubelet.enable = true;
          apiserverEtcdClient.enable = true;
          serviceAccountSigner.enable = true;
        };
      };
    };
  };

in {
  name = "k8s-certmgr-pki-multinode";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    one = { config, pkgs, ... }: {
      imports = [ baseConfig ];

      services.kubernetes.pki.certs.etcdServer.csr.hosts = [ "one" ];

      services.etcd = {
        enable = true;

        clientCertAuth = true;
        peerClientCertAuth = true;
        certFile = config.services.kubernetes.pki.certs.etcdServer.cert;
        keyFile = config.services.kubernetes.pki.certs.etcdServer.key;
        trustedCaFile = config.services.kubernetes.pki.certs.etcdServer.ca.cert;
        listenClientUrls = ["https://0.0.0.0:2379"];
        listenPeerUrls = ["https://0.0.0.0:2380"];
        initialCluster = ["one=https://one:2380"];
        initialAdvertisePeerUrls = ["https://one:2380"];
      };

      # expose cfssl
      services.cfssl = {
        address = "0.0.0.0";
        initssl.csr.hosts = ["one" "0.0.0.0" "localhost"];
      };
      networking.firewall.allowedTCPPorts = [ 8888 2379 ];
    };

    two = { config, pkgs, ... }: {
      imports = [ baseConfig ];
      services.kubernetes.pki.certmgr.cfssl = {
        enable = false;
        remote = "https://one:8888";
        rootCA = "/var/lib/kubernetes/pki/ca.crt";
        authKeyFile = "/var/lib/kubernetes/pki/cfssl-auth-key.secret";
      };
    };
  };

  testScript = ''
    startAll;

    $one->waitForUnit("kube-pki.target");

    my ($status, $out) = $one->execute_("cat /var/lib/cfssl/default-key.secret");
    if ($status != 0) {
      $one->log("output: $out");
      die "command `cat /var/lib/cfssl/default-key.secret` did no succceed (exit status $status)\n";
    }

    my ($status, $out) = $two->execute_("echo '$out' > /var/lib/kubernetes/pki/cfssl-auth-key.secret");
    if ($status != 0) {
      $two->log("output: $out");
      die "command `echo $out > /var/lib/kubernetes/pki/cfssl-auth-key.secret` did no succceed (exit status $status)\n";
    }

    $two->waitForUnit("kube-pki.target");
    $two->waitForUnit("certmgr.service");
    $two->succeed("openssl verify -CAfile /var/lib/kubernetes/pki/ca.crt /var/lib/kubernetes/pki/kube-apiserver.crt");
    $two->succeed("openssl verify -CAfile /var/lib/kubernetes/pki/ca.crt /var/lib/kubernetes/pki/kubelet.crt");

    $one->waitForUnit("kube-service-account-cert-sync.service");
    $two->waitForUnit("kube-service-account-cert-sync.service");
  '';
})
