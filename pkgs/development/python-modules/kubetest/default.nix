{ stdenv, buildPythonPackage, fetchPypi, pythonAtLeast,
  kubernetes, pyyaml, pytest }:

buildPythonPackage rec {
  pname = "kubetest";
  version = "0.6.4";

  doCheck = pythonAtLeast "3";

  src = fetchPypi {
    inherit pname version;
    sha256 = "lZMg0OL/oLHJ2A5cyjlOjBHIfjf7ffKFg+NGmKKlXBk=";
  };

  propagatedBuildInputs = [ kubernetes pyyaml pytest ];

  meta = with stdenv.lib; {
    description = "Kubernetes integration tests in Python";
    homepage = https://github.com/vapor-ware/kubetest;
    license = licenses.gpl3;
    maintainers = with maintainers; [ offline ];
  };
}
