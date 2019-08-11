#! /usr/bin/env bash

set -eufxo pipefail

echo '[]' >versions.json

kops_recommended_versions() {
    http https://raw.githubusercontent.com/kubernetes/kops/master/channels/stable \
        | yq -r '.spec.kubernetesVersions[] | .recommendedVersion'
}

stable_releases() {
    http --session github https://api.github.com/repos/kubernetes/kubernetes/releases per_page==100 \
        | jq -r '. | map(.tag_name) | unique_by(.[:5])[] | select(test("\\Av\\d+\\.\\d+\\.\\d+\\Z", "s")) | ltrimstr("v")'
}

all_releases() {
    http --session github https://api.github.com/repos/kubernetes/kubernetes/releases per_page==100 \
        | jq -r '.[] | .tag_name | ltrimstr("v")'
}

for version in $(kops_recommended_versions); do
    jq \
        --arg version "$version" \
        --arg sha256 "$(nix-prefetch-url --unpack "https://github.com/kubernetes/kubernetes/tarball/v${version}")" \
        '. + [{version: $version, sha256: $sha256}]' \
        versions.json \
        | sponge versions.json
done
