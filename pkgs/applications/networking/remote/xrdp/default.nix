{ stdenv, fetchFromGitHub, fetchpatch
, pkgconfig, which, autoconf, automake, libtool, nasm, perl
, openssl, systemd, pam, fuse, libjpeg, libopus, pixman, xorg, xorgxrdp }:

stdenv.mkDerivation rec {
  version = "0.9.12";
  pname = "xrdp";

  src = fetchFromGitHub {
    owner = "neutrinolabs";
    repo = "xrdp";
    rev = "v${version}";
    fetchSubmodules = true;
    sha256 = "155yixhhq64gyacjhd5llvhxc1ys4smkhlk5573vc9n1h4f49nix";
  };

  patches = [
    # patch to allow to specify runtime config
    (fetchpatch {
      url = "https://github.com/xtruder/xrdp/commit/fd437b3500d763bb1a9958aefa9506fa363530ea.patch";
      sha256 = "1xijqpvp7mzzwcja2mz0nmb5n344zgmx3knnigkfd96y60xf4rj4";
    })
  ];

  nativeBuildInputs = [ pkgconfig autoconf automake which libtool nasm perl ];

  buildInputs = with xorg; [
    openssl systemd pam fuse
    libjpeg libopus
    libX11 libXfixes libXrandr pixman
  ];

  postPatch = ''
    substituteInPlace sesman/xauth.c --replace "xauth -q" "${xorg.xauth}/bin/xauth -q"
  '';

  preConfigure = ''
    (cd librfxcodec && ./bootstrap && ./configure --prefix=$out --enable-static --disable-shared)
    ./bootstrap
  '';
  dontDisableStatic = true;
  configureFlags = [
    "--with-systemdsystemunitdir=/var/empty"
    "--enable-ipv6"
    "--enable-jpeg"
    "--enable-fuse"
    "--enable-rfxcodec"
    "--enable-pixman"
    "--enable-painter"
    "--enable-vsock"
    "--enable-opus"
  ];

  installFlags = [ "DESTDIR=$(out)" "prefix=" ];

  postInstall = ''
    # remove generated keys (as non-determenistic) and upstart script
    rm $out/etc/xrdp/{rsakeys.ini,key.pem,cert.pem}

    cp $src/keygen/openssl.conf $out/share/xrdp/openssl.conf

    substituteInPlace $out/etc/xrdp/sesman.ini --replace /etc/xrdp/pulse $out/etc/xrdp/pulse

    # remove all session types except Xorg (they are not supported by this setup)
    ${perl}/bin/perl -i -ne 'print unless /\[(X11rdp|Xvnc|console|vnc-any|sesman-any|rdp-any|neutrinordp-any)\]/ .. /^$/' $out/etc/xrdp/xrdp.ini

    # remove all session types and then add Xorg
    ${perl}/bin/perl -i -ne 'print unless /\[(X11rdp|Xvnc|Xorg)\]/ .. /^$/' $out/etc/xrdp/sesman.ini

    cat >> $out/etc/xrdp/sesman.ini <<EOF

    [Xorg]
    param=${xorg.xorgserver}/bin/Xorg
    param=-modulepath
    param=${xorgxrdp}/lib/xorg/modules,${xorg.xorgserver}/lib/xorg/modules
    param=-config
    param=${xorgxrdp}/etc/X11/xrdp/xorg.conf
    param=-noreset
    param=-nolisten
    param=tcp
    param=-logfile
    param=.xorgxrdp.%s.log
    EOF
  '';

  enableParallelBuilding = true;

  meta = with stdenv.lib; {
    description = "An open source RDP server";
    homepage = https://github.com/neutrinolabs/xrdp;
    license = licenses.asl20;
    maintainers = with maintainers; [ volth offline ];
    platforms = platforms.linux;
  };
}
