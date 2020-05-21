{ stdenv, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "gomove-unstable";
  version = "2020-01-06";
  rev = "e1fa472562174d85608de06d6c9a77b7591c8091";

  goPackagePath = "github.com/KSubedi/gomove";
  subPackages = [ "." ];

  vendorSha256 = "NxF95io0792nTnesEA7vpozAT+jYx48gpEqSjutO/M0=";

  src = fetchFromGitHub {
    inherit rev;
    owner = "KSubedi";
    repo = "gomove";
    sha256 = "DksfwSSI8Fuosk+j2aYa2S2xaJ+f6XYeDFLN48iN47Q=";
  };

  meta = {
    description = "Utility to help you move golang packages by automatically changing the imports";
    homepage = "https://github.com/KSubedi/gomove";
    maintainers = with stdenv.lib.maintainers; [ offline ];
    license = stdenv.lib.licenses.gpl3;
  };
}
