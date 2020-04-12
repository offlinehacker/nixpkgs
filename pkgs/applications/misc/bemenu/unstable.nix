{ stdenv, fetchFromGitHub, pkgconfig
, cairo, pango, libxkbcommon ? null
, ncursesSupport ? true, ncurses ? null
, waylandSupport ? true, wayland-protocols ? null, wayland ? null
, x11Support ? true, xlibs ? null, xorg ? null
}:

with stdenv.lib;

assert ncursesSupport -> ncurses != null;
assert waylandSupport -> wayland != null && wayland-protocols != null;
assert x11Support -> xlibs != null && xorg != null;
assert waylandSupport || x11Support -> libxkbcommon != null;

stdenv.mkDerivation rec {
  pname = "bemenu";
  version = "0.4.0-${builtins.substring 0 8 rev}";
  rev = "6343a658bb020db26783b0123ed0577f13bf91ee";

  src = fetchFromGitHub {
    owner = "Cloudef";
    repo = pname;
    rev = rev;
    sha256 = "EzhRiC39Qx5NRVTDrsvtFCZD9WFO+vyUvN9P7cMjDyY=";
  };

  nativeBuildInputs = [ pkgconfig ];

  buildInputs = with stdenv.lib; [
    cairo pango
  ] ++ optionals ncursesSupport [ ncurses ]
    ++ optionals waylandSupport [ wayland-protocols wayland libxkbcommon ]
    ++ optionals x11Support [ xlibs.libX11 xlibs.libXinerama libxkbcommon ];

  makeFlags = [
    "PREFIX=$(out)"
    "clients"
    (optionals ncursesSupport "curses")
    (optionals waylandSupport "wayland")
    (optionals x11Support "x11")
  ];

  meta = with stdenv.lib; {
    homepage = "https://github.com/Cloudef/bemenu";
    description = "Dynamic menu library and client program inspired by dmenu";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ thiagokokada offline ];
    platforms = with platforms; linux;
  };
}
