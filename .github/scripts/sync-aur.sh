#!/bin/bash

set -euo pipefail
          
if [[ ! -f ".github/aur/mapping.env" ]]; then
    echo "No mapping.env file found. Skipping AUR sync."
    exit 0
fi

is_version_git_style() {
    [[ "$1" =~ r[0-9]+ ]]
}

normalize_version_for_compare() {
    local v="$1"

    if [[ "$v" =~ r([0-9]+) ]]; then
        local rnum="${BASH_REMATCH[1]}"   # die Zahl nach dem r
        local rel="${v##*-}"              # der Teil nach dem letzten -
        echo "${rnum}-${rel}"
    else
        echo "$v"
    fi
}

pkgbuild_version() {
    local pkg="$1"
    local pkgver=$(grep -E '^pkgver=' "$pkg/PKGBUILD" | cut -d= -f2)
    local pkgrel=$(grep -E '^pkgrel=' "$pkg/PKGBUILD" | cut -d= -f2)
    echo "$pkgver-$pkgrel"
}

aur_version() {
    # TODO incase of rate limit use git clone, rpc's limited harder
    local pkg="$1"
    local version=$(curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg=$pkg" | jq -r '.results[0].Version')
    echo "$version"
}

ensure_pkgs_exist() {
    local pkg="$1"
    local aur_pkg="$2"

    if [[ ! -d "$pkg" ]]; then
        echo "Error: Local package folder $pkg does not exist."
        exit 1
    fi

    if ! curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg=$aur_pkg" | jq -e '.results[0]' > /dev/null; then
        echo "Error: AUR package $aur_pkg does not exist."
        exit 1
    fi
}

ensure_matching_type() {
    local pkg="$1"
    local aur_pkg="$2"

    if [[ "$pkg" != *-git || "$aur_pkg" != *-git ]]; then
        echo "Error: Both local package $pkg and AUR package $aur_pkg must be git packages."
        exit 1
    fi
}

ensure_matching_version_style() {
    local v1="$1"
    local v2="$2"

    # TODO assumed when not git style its or x.y.z-r

    if [[ $(is_version_git_style "$v1") != $(is_version_git_style "$v2") ]]; then
        echo "Error: Version styles do not match: local=$v1, AUR=$v2."
        exit 1
    fi
}

is_pkg_newer() {
    local pkg_version="$1"
    local aur_version="$2"

    local pkg_version_cmp aur_version_cmp
    pkg_version_cmp="$(normalize_version_for_compare "$pkg_version")"
    aur_version_cmp="$(normalize_version_for_compare "$aur_version")"

    if dpkg --compare-versions "$pkg_version_cmp" gt "$aur_version_cmp"; then
        return 0  
    else
        return 1  
    fi
}

sync_pkg() {
    local pkg="$1"
    local aur_pkg="$2"

    # TODO for now names must match, otherwise files needs to be modfier beforesync
    if [[ "$pkg" != "$aur_pkg" ]]; then
        echo "Error: Local package name $pkg and AUR package name $aur_pkg must be the same."
        exit 1
    fi

    ensure_pkgs_exist "$pkg" "$aur_pkg"
    ensure_matching_type "$pkg" "$aur_pkg"            

    read pkg_version <<< $(pkgbuild_version "$pkg")
    read aur_version <<< $(aur_version "$aur_pkg")

    pkg_version_cmp="$(normalize_version_for_compare "$pkg_version")"
    aur_version_cmp="$(normalize_version_for_compare "$aur_version")"

    ensure_matching_version_style "$pkg_version" "$aur_version"

    if ! is_pkg_newer "$pkg_version" "$aur_version"; then
        echo "No sync needed for $pkg. Local version ($pkg_version) is not newer than AUR version ($aur_version)."
        return 0
    fi
        
    echo "Syncing $pkg to AUR package $aur_pkg"
    echo "Local version: $pkg_version"
    echo "AUR version: $aur_version"
}

source .github/aur/mapping.env
for var in $(compgen -v | grep '^sync_aur_'); do
    aur_pkg="${!var}"
    pkg="${var#sync_aur_}"
    pkg="${pkg//_/-}"

    sync_pkg "$pkg" "$aur_pkg"
done