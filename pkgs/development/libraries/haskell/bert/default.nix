# This file was auto-generated by cabal2nix. Please do NOT edit manually!

{ cabal, async, binary, binaryConduit, conduit, conduitExtra, mtl
, network, parsec, smallcheck, tasty, tastyHunit, tastySmallcheck
, time, void
}:

cabal.mkDerivation (self: {
  pname = "bert";
  version = "1.2.2.3";
  sha256 = "1waq40hd9wqavzhnvfk1i6wjqkmfb4pl17h4acfzzyz8bj76alkq";
  buildDepends = [
    binary binaryConduit conduit conduitExtra mtl network parsec time
    void
  ];
  testDepends = [
    async binary network smallcheck tasty tastyHunit tastySmallcheck
  ];
  meta = {
    homepage = "https://github.com/feuerbach/bert";
    description = "BERT implementation";
    license = self.stdenv.lib.licenses.bsd3;
    platforms = self.ghc.meta.platforms;
    maintainers = with self.stdenv.lib.maintainers; [ ocharles ];
  };
})
