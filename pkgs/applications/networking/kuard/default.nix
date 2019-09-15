{ stdenv, callPackage, buildGoModule, fetchFromGitHub
, nodejs-10_x, go-bindata }:

let
  fetchNodeModules = callPackage ./fetchNodeModules.nix {};
in buildGoModule rec {
  pname = "kuard";
  version = "0.10.0";

  goPackagePath = "github.com/kubernetes-up-and-running/kuard";

  src = fetchFromGitHub {
    owner = "kubernetes-up-and-running";
    repo = pname;
    rev = "v${version}";
    sha256 = "0s5cbf8sm8pkrji5h2m14hvh482z30nfr4k7hdpndikz6ab69a87";
  };

  modSha256 = "0pj258ydivzjbpw71pcq4pl41lwmci8zb5r6pr3pvxbr4k8laav6";

  nodeModules = fetchNodeModules {
    src = "${src}/client";
    nodejs = nodejs-10_x;
    sha256 = "1k4d0lldhnc2iqb3zdb91734ga3vazd5kkdqh1yg2m8y01aiv89i";
  };

  buildInputs = [ nodejs-10_x go-bindata ];

  preBuild = ''
    (
      cd client
      cp -R $nodeModules node_modules
      chmod -R +w node_modules
      patchShebangs .
      npm run build
    )

    go generate ./cmd/... ./pkg/...
  '';

  buildFlagsArray = ''
    -ldflags=
    -X "${goPackagePath}/pkg/version.VERSION=${version}"
  '';

  meta = with stdenv.lib; {
    homepage = https://ethereum.github.io/go-ethereum/;
    description = "Official golang implementation of the Ethereum protocol";
    license = with licenses; [ lgpl3 gpl3 ];
    maintainers = with maintainers; [ adisbladis asymmetric lionello ];
  };
}
