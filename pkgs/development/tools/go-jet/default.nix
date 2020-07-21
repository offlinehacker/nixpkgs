{ stdenv, buildGoPackage, fetchFromGitHub }:

buildGoPackage rec {
  pname = "jet";
  version = "2.3.0";

  src = fetchFromGitHub {
    owner = "go-jet";
    repo = pname;
    rev = "v${version}";
    sha256 = "VwN0DVXH1WHzb4aiwTnVqVCUMfmD5nu7s2YXPa8i0Ag=";
  };

  goPackagePath = "github.com/go-jet/jet";
  subPackages = [ "cmd/jet" ];

  meta = with stdenv.lib; {
    homepage    = "https://github.com/go-jet/jet";
    description = "Type safe SQL Builder for Go with automatic scan to desired arbitrary object structure .";
    maintainers = with maintainers; [ offline ];
    license     = licenses.mit;
  };
}
