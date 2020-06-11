{ stdenv, buildPythonPackage, fetchPypi, fetchpatch, isPy3k
, requests, CommonMark, beautifulsoup4, tzlocal, python-slugify
, dictdiffer, cached-property }:

buildPythonPackage rec {
  pname = "notion";
  version = "0.0.25";
  disabled = !isPy3k;
  commit = "56b7a904474619cf60c4768db435c921ca18f44f";

  src = fetchPypi {
    inherit pname version;
    sha256 = "lrHl7Ulbaw1qziH79JxAnTxGvnENCM7K7hLLNkuNAEk=";
  };

  patches = [
    # set of patches that makes notion usable, until they get merged to original repo
    (fetchpatch {
      name = "notion-patches-kevinjalbert-master.patch";
      url = "https://github.com/jamalex/notion-py/compare/${commit}...kevinjalbert:89b591ee6fe13262234dfcfdcc4d6277378e2deb.patch";
      sha256 = "/h5sS7OeWDAoHMD4mKlh4DqScoZYgqalVZOuEcojC5k=";
    })
  ];

  postPatch = ''
    substituteInPlace requirements.txt --replace "bs4" "beautifulsoup4"
  '';

  propagatedBuildInputs = [
    requests
    CommonMark
    beautifulsoup4
    tzlocal
    python-slugify
    dictdiffer
    cached-property
  ];

  # tests need $HOME set
  preCheck = "export HOME=$TMP";

  meta = with stdenv.lib; {
    homepage = "https://github.com/jamalex/notion-py";
    description = "Unofficial Python API client for Notion.so ";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
