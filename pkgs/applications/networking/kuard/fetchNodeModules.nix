{ stdenv, jq }: { src, nodejs, sha256 }:

# Only npm >= 5.4.2 is deterministic, see:
# https://github.com/npm/npm/issues/17979#issuecomment-332701215
assert stdenv.lib.versionAtLeast nodejs.version "8.9.0";

stdenv.mkDerivation {
  name = "node_modules";

  outputHashAlgo = "sha256";
  outputHash = sha256;
  outputHashMode = "recursive";

  nativeBuildInputs = [ jq nodejs ];

  buildCommand = ''
    cp -r ${src}/* .
    HOME=. npm install --force --ignore-scripts
    mv node_modules $out
  '';
}
