{ stdenv, fetchurl, patchelf, libX11, dbus, xorg, libgcc, freetype, fontconfig
, xkeyboardconfig, makeWrapper, gnused, zlib, fuse, libGL, glib, libgpgerror }:

with stdenv.lib;

let
  libPath = stdenv.lib.makeLibraryPath [
    dbus
    libX11
    xorg.libxcb
    libgcc
    stdenv.cc.cc.lib
    freetype
    fontconfig
    zlib
    fuse
    libGL
    glib
    libgpgerror
    stdenv.glibc.out
  ];
in stdenv.mkDerivation rec {
  name = "bcvault";

  src =
    if stdenv.hostPlatform.system == "x86_64-linux" then
        fetchurl {
          url = "https://bc-vault.com/download/BCVaultSetup?v=ce774d9cab3";
          sha256 = "EDE71AB73F8CA3EC0247DCFBCC615F2D60871E5EF54A14C19A5C44AB2F8BE928";
        }
    else if stdenv.hostPlatform.system == "i686-linux" then
        fetchurl {
          url = "http://files.renoise.com/demo/Renoise_${urlVersion version}_Demo_x86.tar.bz2";
          sha256 = "1lccjj4k8hpqqxxham5v01v2rdwmx3c5kgy1p9lqvzqma88k4769";
        }
    else throw "Platform is not supported by BCVault";

  unpackPhase = "true";

  buildInputs = [ makeWrapper gnused ];
  nativeBuildInputs = [ patchelf ];

  installPhase = ''
    cp $src bcvault-installer
    chmod +wx bcvault-installer

    patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) \
      bcvault-installer

    export LD_LIBRARY_PATH="${libPath}"
    export QT_XKB_CONFIG_ROOT="${xkeyboardconfig}/share/X11/xkb"

    ./bcvault-installer --script ${./qt-installer-noninteractive.qs} -v -platform minimal | tee log &
    installed_pid=$!

    until cat log | grep AuthorizationError >/dev/null 2>/dev/null; do
      sleep 1
    done

    authorization_command=./$(cat log | grep AuthorizationError | sed -e 's/.*\(bcvault-installer.*\)\\n\\n.*/\1/')

    $authorization_command

    wait $installer_pid

    patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) \
      bcvault/BC_Vault-x86_64.AppImage

    bcvault/BC_Vault-x86_64.AppImage --appimage-extract

    mkdir -p $out
    cp -R squashfs-root/usr/* $out/

    patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) $out/bin/BCVault
    patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) $out/bin/bcdaemon

    wrapProgram $out/bin/BCVault \
      --prefix "QT_XKB_CONFIG_ROOT" : "${xkeyboardconfig}/share/X11/xkb" \
      --prefix "LD_LIBRARY_PATH" : "${libPath}:$out/lib"
  '';

  postFixup = ''
  '';

  dontStrip = true;

  meta = {
    description = "Modern tracker-based DAW";
    homepage = https://www.renoise.com/;
    license = licenses.unfree;
    maintainers = [];
    platforms = [ "i686-linux" "x86_64-linux" ];
  };
}
