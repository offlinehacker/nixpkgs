{ lib, kustomize, remarshal, runCommand, writeText }:

name: options:

with lib;

let
  config = (evalModules {
    modules = [ options ./kustomize-options.nix ];
    check = true;
  }).config;

  /* Check whether a value can be coerced to a string */
  isCoercibleToString = x:
    builtins.elem (builtins.typeOf x) [ "path" "string" "null" "int" "float" "bool" ] ||
    (builtins.isList x && lib.all isCoercibleToString x) ||
    x ? outPath ||
    x ? __toString;

  isPath = p: isCoercibleToString p && builtins.substring 0 1 (toString p) == "/";

  isJSONOrYaml = p: isPath p && (hasSuffix "json" p || hasSuffix "yaml" p);

  copyResource = group: name: r:
    if isJSONOrYaml r then "cp ${r} ${group}/${name}"
    else if isPath r then "cp -R ${r} ${group}/${name}"
    else "cp ${builtins.toFile name (builtins.toJSON r)} ${group}/${name}";

  nameFromPath = r: removePrefix (builtins.storeDir + "/") r;

  nameFromResource = r: r.metadata.name + ".json";

  resourceName = r: if isPath	r then nameFromPath r else nameFromResource r;

  isEmpty = v: v == null || v == {} || v == [];

  filterEmpty = x:
    if isList x then filter (v: (!isEmpty v)) x
    else filterAttrs (_: v: !(isEmpty v)) x;

  kustomization = filterEmpty {
    inherit (config) namespace namePrefix nameSuffix commonLabels commonAnnotations;
    images = filterEmpty config.images;
    replicas = filterEmpty config.replicas;
    resources = map (r: "resources/${resourceName r}") config.resources;
    crds = map (r: "crds/${resourceName r}") config.crds;
    patches = map (p: filterEmpty {
      target = filterEmpty p.target;
      path = optionals (isPath p.patch) p.patch;
      patch = optionals (!(isPath p.patch)) (builtins.toJSON p.patch);
    }) config.patches;
    patchesStrategicMerge = map (p:
      if (isPath p) then p else builtins.toJSON p
    ) config.patchesStrategicMerge;
    patchesJson6902 = map (p:
      if (isPath p) then p else builtins.toJSON p
    ) config.patchesJson6902;
  };

  kustomizationJSON = writeText "${name}-kustomization.json" (builtins.toJSON kustomization);

  kustomizationDir = runCommand name {
    buildInputs = [ remarshal ];

    passthru.build = runCommand (name + ".yaml") {
      buildInputs = [ kustomize ];
    } ''
      kustomize build ${kustomizationDir} > $out
    '';

  } ''
    mkdir work
    cd work

    mkdir resources crds patches

    ${concatStringsSep "\n" (map (r: copyResource "resources" (resourceName r) r) config.resources)}
    ${concatStringsSep "\n" (map (r: copyResource "crds" (resourceName r) r) config.crds)}
    ${concatStringsSep "\n" (imap (i: p: copyResource "patches" "patch-${toString i}.json" p.patch) (filter (p: isAttrs p.patch) config.patches))}

    remarshal -i ${kustomizationJSON} -if json -o kustomization.yaml -of yaml

    cp -R . $out
  '';
in kustomizationDir
