{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "k3s";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/rancher/k3s/releases/download/v${version}/k3s";
    sha256 = "1abj0vmnsgfa753r1yv7pkxp0s0ms703ma8sfr6cbqnhp256byik";
  };

  dontUnpack = true;
  installPhase = "install -Dm755 $src $out/bin/k3s";

  meta = with stdenv.lib; {
    description = "Lightweight Kubernetes. 5 less than k8s.";
    homepage = https://k3s.io/;
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
