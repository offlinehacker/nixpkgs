{ config, lib, ... }:

with lib;

{
  options = {
    resources = mkOption {
      description = "List of resources or packages containing other kustumizations";
      type = types.listOf (types.either types.attrs types.path);
      default = [];
    };

    crds = mkOption {
      description = "List of resources or packages containing custom resource definitions";
      type = types.listOf (types.either types.attrs types.path);
      default = [];
    };

    namespace = mkOption {
      description = "Adds namespace to all resources";
      type = types.nullOr types.str;
      default = null;
    };

    namePrefix = mkOption {
      description = "Prepends value to the names of all resources";
      type = types.nullOr types.str;
      default = null;
    };

    nameSuffix = mkOption {
      description = "The value is appended to the names of all resources";
      type = types.nullOr types.str;
      default = null;
    };

    commonLabels = mkOption {
      description = "Adds labels to all resources and selectors";
      type = types.attrsOf types.str;
      default = {};
    };

    commonAnnotations = mkOption {
      description = "Adds annotations to all resources";
      type = types.attrsOf types.str;
      default = {};
    };

    images = mkOption {
      description = "Modify image name and tag";
      type = types.listOf (types.submodule ({ config, ... }: {
        options = {
          name = mkOption {
            description = "Name of the image to match";
            type = types.str;
          };

          newName = mkOption {
            description = "New name to apply";
            type = types.nullOr types.str;
            default = null;
          };

          newTag = mkOption {
            description = "New tag to apply";
            type = types.nullOr types.str;
            default = null;
          };

          digest = mkOption {
            description = "Image digest to use";
            type = types.nullOr types.str;
            default = null;
          };
        };
      }));
      default = [];
    };

    replicas = mkOption {
      description = "Replicas modified the number of replicas for a resources";
      type = types.listOf (types.submodule ({ config, ... }: {
        options = {
          name = mkOption {
            description = "Name of the resource to apply change";
            type = types.str;
          };

          count = mkOption {
            description = "Number of replicas to set";
            type = types.int;
          };
        };
      }));
      default = [];
    };

    patches = mkOption {
      description = "List of patches to apply";
      type = types.listOf (types.submodule ({ config, ... }: {
        options = {
          patch = mkOption {
            type = types.either (types.either (types.listOf types.attrs) types.attrs) types.path;
            description = ''
              Patch to apply, can be either patch file or attrs, either in
              JSON patch format or as strategic merge patch.
            '';

            # patch the patch and set metadata.name, as else patch cannot be
            # loaded
            apply = p:
              if isAttrs p
              then (recursiveUpdate p (setAttrByPath ["metadata" "name"] "dummy"))
              else p;
          };

          target = {
            group = mkOption {
              type = types.nullOr types.str;
              description = "Group of resources to apply patch to";
              example = "apps";
              default = null;
            };

            version = mkOption {
              type = types.nullOr types.str;
              description = "Version of resources to apply patch to";
              example = "v1";
              default = null;
            };

            kind = mkOption {
              type = types.nullOr types.str;
              description = "Kind of resources to apply patch to";
              example = "Deployment";
              default = null;
            };

            name = mkOption {
              type = types.nullOr types.str;
              description = "Name of the resource to apply patch to";
              example = "deploy.*";
              default = null;
            };

            labelSelector = mkOption {
              type = types.nullOr types.str;
              description = "Label selector to filter resources to apply patch to";
              example = "env=dev";
              default = null;
            };

            annotationSelector = mkOption {
              type = types.nullOr types.str;
              description = "Annotation selector to filter resources to apply patch to";
              example = "zone=west";
              default = null;
            };
          };
        };
      }));
      default = [];
    };

    patchesStrategicMerge = mkOption {
      type = types.listOf (types.either types.attrs types.path);
      description = "List of stategic merge patches to apply";
      default = [];
    };

    patchesJson6902 = mkOption {
      type = types.listOf (types.either types.attrs types.path);
      description = "List of json 6902 patches to apply";
      default = [];
    };
  };
}
