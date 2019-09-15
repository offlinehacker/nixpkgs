{ config, lib, ... }:

{
  config = {
    services.kubernetes.pki = {
      enable = true;
      local.enable = true;
    };
  };
}
