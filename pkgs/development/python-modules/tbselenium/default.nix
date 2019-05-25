{ pkgs, buildPythonPackage, fetchPypi, selenium }:

buildPythonPackage rec {
  version = "0.4.2";
  pname = "tbselenium";

  src = fetchPypi {
    inherit pname version;
    sha256 = "1pwixg2zz4wyl6f7spijm33gzir4f509k41r7w4r98hcc6gzckz2";
  };

  propagatedBuildInputs = [ selenium ];

  doCheck = false;

  meta = with pkgs.lib; {
    description = "A Python library to automate Tor Browser with Selenium";
    homepage = "https://github.com/Wiredcraft/dopy";
    license = licenses.mit;
    maintainers = with maintainers; [ offline ];
  };
}
