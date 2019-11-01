{ stdenv, fetchFromGitHub, pkgconfig, autoreconfHook
, openssl, db48, boost, zeromq, rapidcheck, zlib, miniupnpc, utillinux, protobuf
, python3, qrencode, libevent
, qtbase ? null, qttools ? null, wrapQtAppsHook ? null
, withGui }:

with stdenv.lib;

stdenv.mkDerivation rec {
  pname = if withGui then "bitcoin" else "bitcoind";
  version = "0.18.1";

  packaging = fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "packaging";
    rev = "a48094dca1113fb6096768993d1b80d1a4ab5871";
    sha256 = "0kkbpw4kcxffdik35vvf35vdkcpjfacj1m6vxr73v4f1fzw1kx9m";
  };

  src = fetchFromGitHub {
    owner = "bitcoin";
    repo = "bitcoin";
    rev = "v${version}";
    sha256 = "1wjspifh07bzhsrd39i81padzfdkj7bi6aijykxdsjjy12338yv3";
  };

  nativeBuildInputs =
    [ pkgconfig autoreconfHook ]
    ++ optional withGui wrapQtAppsHook;
  buildInputs = [ openssl db48 boost zlib zeromq
                  miniupnpc protobuf libevent]
                  ++ optionals stdenv.isLinux [ utillinux ]
                  ++ optionals withGui [ qtbase qttools qrencode ];

  postInstall = ''
    install -Dm644 $packaging/debian/bitcoin-qt.desktop $out/share/applications/bitcoin-qt.desktop
    install -Dm644 share/pixmaps/bitcoin128.png $out/share/pixmaps/bitcoin128.png
  '';

  configureFlags = [ "--with-boost-libdir=${boost.out}/lib"
                     "--disable-bench"
                   ] ++ optionals (!doCheck) [
                     "--disable-tests"
                     "--disable-gui-tests"
                   ]
                     ++ optionals withGui [ "--with-gui=qt5"
                                            "--with-qt-bindir=${qtbase.dev}/bin:${qttools.dev}/bin"
                                          ];

  checkInputs = [ rapidcheck python3 ];

  doCheck = true;

  checkFlags =
    [ "LC_ALL=C.UTF-8" ]
    # QT_PLUGIN_PATH needs to be set when executing QT, which is needed when testing Bitcoin's GUI.
    # See also https://github.com/NixOS/nixpkgs/issues/24256
    ++ optional withGui "QT_PLUGIN_PATH=${qtbase}/${qtbase.qtPluginPrefix}";

  enableParallelBuilding = true;

  meta = {
    description = "Peer-to-peer electronic cash system";
    longDescription= ''
      Bitcoin is a free open source peer-to-peer electronic cash system that is
      completely decentralized, without the need for a central server or trusted
      parties. Users hold the crypto keys to their own money and transact directly
      with each other, with the help of a P2P network to check for double-spending.
    '';
    homepage = http://www.bitcoin.org/;
    maintainers = with maintainers; [ roconnor AndersonTorres ];
    license = licenses.mit;
    # bitcoin needs hexdump to build, which doesn't seem to build on darwin at the moment.
    platforms = platforms.linux;
  };
}
