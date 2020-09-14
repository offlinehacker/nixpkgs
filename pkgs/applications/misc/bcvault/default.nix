{ stdenv, lib, appimageTools, fetchurl
, dbus, freetype, fontconfig, libX11, xorg, libgcc, zlib }:

with lib;

let
  runInstaller = {name, src}: stdenv.mkDerivation {
    name = "${name}-appimage";

    LD_LIBRARY_PATH = stdenv.lib.makeLibraryPath [
      dbus
      libX11
      xorg.libxcb
      stdenv.cc.cc.lib
      freetype
      fontconfig
    ];

    buildCommand = ''
      install ${src} installer
      chmod +wx installer

      patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} installer

      ./installer --script ${./qt-installer-noninteractive.qs} -v -platform minimal | tee log &
      installer_pid=$!

      until cat log | grep AuthorizationError >/dev/null 2>/dev/null; do
        sleep 1
      done

      authorization_command=./$(cat log | grep AuthorizationError | sed -e 's/.*\(installer.*\)\\n\\n.*/\1/')

      $authorization_command

      wait $installer_pid

      cp result/*.AppImage $out
    '';
  };

  pname = "BCVault";
  version = "1.0.0";

in appimageTools.wrapAppImage rec {
  name = "${pname}-${version}";

  src = appimageTools.extractType2 {
    inherit name;
    src = runInstaller {
      inherit name;
      src =
        if stdenv.hostPlatform.system == "x86_64-linux" then
          fetchurl {
            url = "https://bc-vault.com/download/BCVaultSetup?v=ce774d9cab3";
            sha256 = "EDE71AB73F8CA3EC0247DCFBCC615F2D60871E5EF54A14C19A5C44AB2F8BE928";
          }
        else throw "Platform is not supported by BCVault";
    };
  };

  multiPkgs = null; # no 32bit needed
  extraPkgs = appimageTools.defaultFhsEnvArgs.multiPkgs;
  extraInstallCommands = ''
    mv $out/bin/{${name},${pname}}

    cp -R ${src}/usr/share $out/share
  '';

  meta = {
    description = "Modern tracker-based DAW";
    homepage = https://www.renoise.com/;
    license = licenses.unfree;
    maintainers = [];
    platforms = [ "i686-linux" "x86_64-linux" ];
  };
}
