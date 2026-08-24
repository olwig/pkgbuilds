#!/usr/bin/env bash

pkg_name="grok-build"

. ./scripts/package.sh


pkg_name() {
    echo "$pkg_name"
}

pkg_get_upstream_version() {
    local version=$(curl -s https://x.ai/cli/stable)
    echo "$version"
}

pkg_is_version() {
    # test for format x.y.z
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

pkg_is_version_gt() {
    local version1="$1"
    local version2="$2"
    
    # check version format
    if ! pkg_is_version "$version1" || ! pkg_is_version "$version2"; then
        pkg_echo "ERROR: Invalid version format. Expected x.y.z"
        exit 1
    fi

    if [[ "$version1" == "$version2" ]]; then
        echo "false"
        return 1
    fi

    if [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" == "$version1" ]]; then
        echo "false"
        return 1
    fi

    echo "true"
    return 0
}

pkg_ensure_is_pkg_lib
pkg_debug_echo "sourced ./scripts/pkg_$pkg_name.sh"