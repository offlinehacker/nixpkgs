{ stdenv, buildPythonPackage, fetchPypi
, setuptools_scm, pytestrunner
, check-manifest, coverage, isort, mock, pydocstyle, pytestcov, pytestpep8
, pytest, tox }:

buildPythonPackage rec {
  pname = "dictdiffer";
  version = "0.8.1";

  src = fetchPypi {
    inherit pname version;
    sha256 = "Gt7A1nzfYWa9qWrik03bXlRDOZjOq2PJhFdNGHzFY9I=";
  };

  buildInputs = [
    check-manifest
    coverage
    isort
    mock
    pydocstyle
    pytestcov
    pytestpep8
    pytest
    tox
  ];

  propagatedBuildInputs = [
    setuptools_scm
    pytestrunner
  ];

  meta = with stdenv.lib; {
    homepage = "https://github.com/inveniosoftware/dictdiffer";
    description = "Dictdiffer is a helper module that helps you to diff and patch dictionaries";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
