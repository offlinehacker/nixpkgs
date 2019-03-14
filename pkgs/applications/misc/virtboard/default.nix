{ stdenv
, fetchFromGitLab
, meson
, ninja
, pkgconfig
, wrapGAppsHook
, pixman
, libxkbcommon
, libpng
, wayland
, wayland-protocols
, cairo
, gsettings-desktop-schemas
}:

stdenv.mkDerivation rec {
  pname = "virtboard";
  version = "0.0.6";

  src = fetchFromGitLab {
    domain = "source.puri.sm";
    owner = "Librem5";
    repo = pname;
    rev = "v${version}";
    sha256 = "ujsAVjhlzEstnyQ66+l+lDl+j0TQ3ijuYlK51kjWmyc=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkgconfig
    wrapGAppsHook
  ];

  buildInputs = [
    pixman
    libxkbcommon
    libpng
    wayland
    wayland-protocols
    cairo
    gsettings-desktop-schemas
  ];

  meta = with stdenv.lib; {
    description = "A basic keyboard, blazing the path of modern Wayland keyboards";
    homepage = https://source.puri.sm/Librem5/virtboard;
    license = licenses.mit;
    maintainers = with maintainers; [ jtojnar ];
    platforms = platforms.linux;
  };
}
