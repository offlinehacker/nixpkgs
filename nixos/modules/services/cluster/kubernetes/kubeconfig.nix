{ config, lib, ... }:

with lib;

{
  options = {
    user = mkOption {
      description = "Kubernetes kubeconfig user.";
      type = types.str;
      default = "kubernetes-user";
    };

    server = mkOption {
      description = "Kubernetes kube-apiserver address.";
      type = types.str;
    };

    caFile = mkOption {
      description = "Certificate authority file used to connect to kube-apiserver.";
      type = types.nullOr types.path;
      default = null;
    };

    certFile = mkOption {
      description = "Client certificate file used to connect to kube-apiserver.";
      type = types.nullOr types.path;
      default = null;
    };

    keyFile = mkOption {
      description = "Client key file used to connect to kube-apiserver.";
      type = types.nullOr types.path;
      default = null;
    };

    token = mkOption {
      description = "Token used for token based authentication";
      type = types.nullOr types.str;
      default = null;
    };

    insecureSkipTlsVerify = mkOption {
      description = "Whether to skip TLS verification";
      type = types.bool;
      default = false;
    };

    file = mkOption {
      description = "Generated kubeconfig file.";
      type = types.package;
      internal = true;
    };
  };

  config.file = builtins.toFile "${config.user}-kubeconfig" (builtins.toJSON {
    apiVersion = "v1";
    kind = "Config";
    clusters = [{
      name = "local";
      cluster = {
        certificate-authority = config.caFile;
        server = config.server;
        insecure-skip-tls-verify = config.insecureSkipTlsVerify;
      };
    }];
    users = [{
      name = config.user;
      user = {
        client-certificate = config.certFile;
        client-key = config.keyFile;
        token = config.token;
      };
    }];
    contexts = [{
      context = {
        cluster = "local";
        user = config.user;
      };
      current-context = "local";
    }];
  });
}
