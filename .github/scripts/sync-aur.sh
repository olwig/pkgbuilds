#!/bin/bash

#set -euo pipefail
#set -euxo pipefail
#trap 'echo "ERROR in line $LINENO: $BASH_COMMAND" >&2' ERR

# inputs via env vars (e.g. for direct bash execution):
# GITHUB_WORKSPACE: the root of the repository

# if not running with act or on gh actions, init the env vars for testing, and simulate all previous steps
if [[ -z "${GITHUB_WORKSPACE:-}" && "${ACT:-}" != "true" ]]; then

    # wf inputs
    WORK_FLUSH="true"
    WORK_ROOT=".github/work"
    GITHUB_WORKSPACE=$(git rev-parse --show-toplevel)

    # flush work if requested
    if [[ "$WORK_FLUSH" == "true" ]]; then
        rm -rf "$GITHUB_WORKSPACE/$WORK_ROOT"
    fi
    
    # create unique work dir
    work_id=$(tr -dc a-z0-9 </dev/urandom | head -c 12 || true)
    WORK_DIR="$WORK_ROOT/$work_id/sync"
    mkdir -p "$GITHUB_WORKSPACE/$WORK_DIR"

    # copy data (checkout) repo to workdir sub
    cd "$GITHUB_WORKSPACE"
    rsync -a --exclude "$WORK_ROOT" . "$WORK_DIR/pkg_repo/"

    echo "GITHUB_WORKSPACE: $GITHUB_WORKSPACE"
    echo "WORK_ROOT: $WORK_ROOT"
    echo "WORK_DIR: $WORK_DIR"


    cd "$GITHUB_WORKSPACE/$WORK_DIR"

    tree -a -L 3
fi

# globals to be used in functions, will be set in the main loop
declare -A aur_versions
declare -A pkg_aur_map

init_pkg_aur_map() {
    
    mapping_file="pkg_repo/.github/aur/mapping.env"
    if [[ ! -f "$mapping_file" ]]; then
        echo "No mapping.env file found. Nothing to sync."
        return 0
    fi

    source "$mapping_file"
    for var in $(compgen -v | grep '^sync_aur_'); do
        aur_pkg="${!var}"
        pkg="${var#sync_aur_}"
        pkg="${pkg//_/-}"
        pkg_aur_map["$pkg"]="$aur_pkg"
    done

    # dump the mapping for debugging
    echo "Package to AUR mapping:"
    for pkg in "${!pkg_aur_map[@]}"; do
        echo "  $pkg -> ${pkg_aur_map[$pkg]}"
    done
}

init_aur_versions() {
    # fetch aur pkg infos via rpc, if json data already set (debug) don't fetch new, due to rate limit 
    aur_rpc_json=""
    rpc_cache_file="pkg_repo/.github/aur/debug_rpc_cache.json"
    if [[ -f "$rpc_cache_file" ]]; then
        aur_rpc_json=$(cat "$rpc_cache_file")
    else
        args=""
        for aur_pkg in "${pkg_aur_map[@]}"; do
            args+="&arg[]=${aur_pkg}"
        done

        url="https://aur.archlinux.org/rpc/v5/info?${args:1}"
        aur_rpc_json=$(curl -s "$url")
    fi

    echo "$aur_rpc_json" | jq '.'

    # extract AUR versions from the JSON data
    for aur_pkg in "${pkg_aur_map[@]}"; do
        aur_version=$(echo "$aur_rpc_json" | jq -r --arg pkg "$aur_pkg" '.results[] | select(.Name == $pkg) | .Version')
        aur_versions["$aur_pkg"]="$aur_version"
    done

    # dump the AUR versions for debugging
    echo "AUR package versions:"
    for aur_pkg in "${!aur_versions[@]}"; do
        echo "  $aur_pkg -> ${aur_versions[$aur_pkg]}"
    done
}

is_version_git_style() {
    # must be rN.hash-release, e.g. r1.abcdefg-1
    [[ "$1" =~ ^r[0-9]+\.[a-f0-9]+-[0-9]+$ ]]
}

is_version_x_y_z_r_style() {
    # must be x.y.z-r, e.g. 1.2.3-1
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?$ ]]
}

version_style() {
    local v="$1"
    if is_version_git_style "$v"; then
        echo "git"
    elif is_version_x_y_z_r_style "$v"; then
        echo "x.y.z-r"
    else
        echo "unknown"
    fi
}

normalize_version_for_compare() {
    # since we use dpkg --compare-versions, we need to normalize the version string to a format that dpkg understands
    # rN.hash-relase -> N-release
    # x.y.z-r stays the same
    local v="$1"

    if [[ "$v" =~ r([0-9]+) ]]; then
        local rnum="${BASH_REMATCH[1]}"   
        local rel="${v##*-}"              
        echo "${rnum}-${rel}"
    else
        echo "$v"
    fi
}

pkgbuild_version() {
    local pkg="$1"
    local pkbuild_file="pkg_repo/$pkg/PKGBUILD"
    if [[ ! -f "$pkbuild_file" ]]; then
        echo "Error: PKGBUILD file not found for package $pkg."
        exit 1
    fi

    local pkgver=$(grep -E '^pkgver=' "$pkbuild_file" | cut -d= -f2)
    local pkgrel=$(grep -E '^pkgrel=' "$pkbuild_file" | cut -d= -f2)

    echo "$pkgver-$pkgrel"
}

aur_version() {
    local pkg="$1"
    local version=${aur_versions[$pkg]:-}
    if [[ -z "$version" ]]; then
        echo "Error: AUR package $pkg does not exist or could not be fetched."
        exit 1
    fi
    echo "$version"
}

ensure_pkgs_exist() {
    local pkg="$1"
    local aur_pkg="$2"

    if [[ ! -d "pkg_repo/$pkg" ]]; then
        echo "Error: Local package folder $pkg does not exist."
        exit 1
    fi

    if [[ -z "${aur_versions[$aur_pkg]:-}" ]]; then
        echo "Error: AUR package $aur_pkg does not exist or could not be fetched."
        exit 1
    fi
}

ensure_matching_pkg_type() {
    local pkg="$1"
    local aur_pkg="$2"
    local pkg_is_git=0
    local aur_is_git=0

    [[ "$pkg" == *-git ]] && pkg_is_git=1
    [[ "$aur_pkg" == *-git ]] && aur_is_git=1

    if (( pkg_is_git != aur_is_git )); then
        echo "Error: Both local package $pkg and AUR package $aur_pkg must either both be git packages or both non-git packages."
        exit 1
    fi
}

ensure_valid_version() {
    # version style must be x.y.z-r or rN.hash-release
    local v="$1"
    local type=$(version_style "$v")

    if [[ "$type" == "unknown" ]]; then
        echo "Error: Invalid version style: $v. Must be x.y.z-r or rN.hash-release."
        exit 1
    fi
}

ensure_matching_version_style() {
    local v1="$1"
    local v2="$2"

    ensure_valid_version "$v1"
    ensure_valid_version "$v2"

    local v1_type=$(version_style "$v1")
    local v2_type=$(version_style "$v2")

    if [[ "$v1_type" != "$v2_type" ]]; then
        echo "Error: Version styles do not match: local=$v1, AUR=$v2."
        exit 1
    fi
}

ensure_pkgs_name_match() {
    local pkg="$1"
    local aur_pkg="$2"

    # TODO for now names must match, otherwise files needs to be modified before sync
    if [[ "$pkg" != "$aur_pkg" ]]; then
        echo "Error: Local package name $pkg and AUR package name $aur_pkg must be the same."
        echo "TODO modify PKGBUILD to match AUR package name before sync."
        exit 1
    fi
}

is_pkg_newer() {
  local pkg_version_norm="$(normalize_version_for_compare "$1")"
  local aur_version_norm="$(normalize_version_for_compare "$2")"

  if command -v dpkg >/dev/null 2>&1; then
    # return other wise exit would kill script with set -e
    dpkg --compare-versions "$pkg_version_norm" gt "$aur_version_norm" && return 0 || return 1
  elif command -v vercmp >/dev/null 2>&1; then
    # return other wise exit would kill script with set -e
    (( $(vercmp "$pkg_version_norm" "$aur_version_norm") > 0 )) && return 0 || return 1
  else
    echo "Error: Neither dpkg nor vercmp available" >&2
    exit 1
  fi
}

sync_pkg() {
    local pkg="$1"
    local aur_pkg="$2"

    ensure_pkgs_name_match "$pkg" "$aur_pkg"
    ensure_matching_pkg_type "$pkg" "$aur_pkg"
    ensure_pkgs_exist "$pkg" "$aur_pkg"   

    pkg_version="$(pkgbuild_version "$pkg")"
    aur_version="$(aur_version "$aur_pkg")"

    ensure_matching_version_style "$pkg_version" "$aur_version"

    echo "Local package: $pkg ($pkg_version)"
    echo "AUR package: $aur_pkg ($aur_version)"   

    if ! is_pkg_newer "$pkg_version" "$aur_version"; then
        echo "No sync needed for $pkg. Local version ($pkg_version) is not newer than AUR version ($aur_version)."
        return 0
    fi
        
    echo "Syncing $pkg to AUR package $aur_pkg"
    echo "Local version: $pkg_version"
    echo "AUR version: $aur_version"

    mkdir -p "aur_repo/$aur_pkg"
    asur_git_url="ssh://aur@aur.archlinux.org/$aur_pkg.git"
    
    git clone "$asur_git_url" "aur_repo/$aur_pkg"

    rsync -av \
        --exclude '.git' \
        --exclude '.github' \
        "pkg_repo/$pkg/" "aur_repo/$aur_pkg/"

    echo "$GITHUB_WORKSPACE/$WORK_DIR/aur_repo/$aur_pkg/"
}

main() {
    init_pkg_aur_map
    init_aur_versions

    for pkg in "${!pkg_aur_map[@]}"; do
        aur_pkg="${pkg_aur_map[$pkg]}"

        echo ""
        echo "########################################"
        echo "Processing package: $pkg (AUR: $aur_pkg)"
        echo "----------------------------------------"

        sync_pkg "$pkg" "$aur_pkg"
    done
}

main