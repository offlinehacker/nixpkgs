{ stdenv, lib, fetchgit, fetchurl, curl, removeReferencesTo, which, go, go-bindata, makeWrapper, git, pkgconfig, libseccomp, glibc, sqlite, zlib
}:

with lib;

let
  rancherPlugins = fetchgit rec {
    url = "https://github.com/rancher/plugins.git";
    rev = "v0.7.6-k3s1";
    sha256 = "1j3g9ammhapx5xvbiv4adkr80kc3ybpnrb4qggqz38hyalr5xbfi";
    leaveDotGit = true;
    postFetch = "cd $out && git tag ${rev}";
  };

  k3sRoot = fetchurl {
    url = "https://github.com/rancher/k3s-root/releases/download/v0.3.0/k3s-root-amd64.tar";
    sha256 = "0sq4b6schxfqrvj9m1x4hs5misl47z1jqn4f7fkm7s8nf15wwc7k";
  };
in stdenv.mkDerivation rec {
  pname = "k3s";
  version = "1.0.0";

  src = fetchgit {
    url = "https://github.com/rancher/k3s.git";
    rev = "refs/tags/v${version}";
    sha256 = "049129wrsavbsgbx1m1jilf2khfzmmkrjwfn5n3pfbhc8z857zx9";
    leaveDotGit = true;
  };

  nativeBuildInputs = [ pkgconfig ];
  buildInputs = [ removeReferencesTo makeWrapper which go go-bindata git curl
    (libseccomp.overrideAttrs (oldAttrs: {
      dontDisableStatic = true;
    }))
    (sqlite.overrideAttrs (oldAttrs: {
      dontDisableStatic = true;
    }))
    zlib.static
    glibc.static
  ];

  GOFLAGS = "-mod=vendor";
  STATIC_BUILD = "true";

  buildPhase = ''
    export HOME=$PWD

    git config --global url."file://${rancherPlugins}.insteadOf" "${rancherPlugins.url}"
    patchShebangs ./scripts
    substituteInPlace scripts/download \
      --replace \
        'https://github.com/rancher/k3s-root/releases/download/''${ROOT_VERSION}/k3s-root-''${ARCH}.tar' \
        file://${k3sRoot}
    substituteInPlace main.go --replace "/bin/rm" "rm"

    ./scripts/download
    ./scripts/build
    ./scripts/package-cli
  '';

  preFixup = ''
    find $out/bin $pause/bin -type f -exec remove-references-to -t ${go} '{}' +
  '';

  meta = {
    description = "Production-Grade Container Scheduling and Management";
    license = licenses.asl20;
    homepage = https://kubernetes.io;
    maintainers = with maintainers; [johanot offline];
    platforms = platforms.unix;
  };
}
