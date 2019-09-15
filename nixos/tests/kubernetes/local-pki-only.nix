import ../make-test.nix ({ pkgs, ...} : {
  name = "k8s-local-pki-only";

  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ offline ];
  };

  nodes = {
    one = { pkgs, ... }: {
      imports = [ ./scenarios/simple-certs.nix ];

      environment.systemPackages = [ pkgs.openssl.bin ];

      services.kubernetes.pki = {
        local.enable = true;
        local.cfssl.config.signing.profiles = {
          server.expiry = "43800h";
          client.expiry = "43800h";
          signing.expiry = "43800h";
        };
      };
    };
  };

  testScript = ''
    startAll;

    $one->waitForUnit("kube-pki.target");
    $one->succeed("openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/test-signer.crt");
    $one->succeed("openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/test-client.crt");
    $one->succeed("openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/test-server.crt");
  '';
})
