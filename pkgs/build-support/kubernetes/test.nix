{ pkgs ? import ../../.. {} }:

let
  kustomize = pkgs.callPackage ./kustomize.nix {};
in rec {
  base = kustomize "base" {
    resources = [
      ./pod.yaml

      {
        apiVersion = "v1";
        kind = "Deployment";
        metadata.name = "myapp-deployment";
        metadata.labels.app = "myapp";
        spec.template = {
          replicas = 1;
          spec.containers = [{
            image = "nginx";
            name = "nginx";
          }];
        };
      }
    ];
    commonAnnotations.build-with = "nixos";
  };

  prod = kustomize "prod" {
    resources = [ base ];
    namespace = "prod";
    commonLabels.env = "prod";
    images = [{
      name = "nginx";
      newName = "nixpkgs/mynginx";
    }];
    replicas = [{
      name = "myapp-deployment";
      count = 2;
    }];
    patches = [{
      target = {
        kind = "Deployment";
        labelSelector = "app=myapp";
      };
      patch = [{
        op = "add";
        path = "/spec/template/spec/containers/-";
        value = {
          image = "helloworld";
          name = "helloworld";
        };
      }];
    } {
      target.kind = "Deployment";
      patch = {
        apiVersion = "v1";
        kind = "Deployment";
        metadata.labels."patch-label" = "patch-value";
      };
    }];
    patchesStrategicMerge = [{
      apiVersion = "v1";
      kind = "Deployment";
      metadata.name = "myapp-deployment";
      metadata.labels.my-label = "my-value";
    }];
  };
}
