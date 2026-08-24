#!/usr/bin/env bash

set -euo pipefail

pkg_name="grok-build"
pkg_debug=true

. "scripts/pkg_$pkg_name.sh"

if ! data=$(pkg_has_update); then
    echo "No update available for $pkg_name"
    exit 0
fi

upstream_version=$(awk '{print $1}' <<< "$data")
pkgbuild_pkgver=$(awk '{print $2}' <<< "$data")

echo "Update available for $pkg_name:"
echo "Upstream version: $upstream_version"
echo "PKGBUILD version: $pkgbuild_pkgver"

type=$(pkg_type)
echo "Package type for '$pkg_name': $type"

obj=$(pkg_type_obj)
echo "Package type object for '$pkg_name': $obj"

test=$(yq -e ".test" <<< "$obj")
echo "Test value from package type object: $test"

sync=$(pkg_is_sync_enabled)
echo "Sync enabled for '$pkg_name': $sync"