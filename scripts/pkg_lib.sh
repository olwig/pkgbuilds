#!/usr/bin/env bash

# Shared package-scoped helpers.
#
# This file is sourced by a package-specific lib script and operates in the
# context of exactly one package (`pkg_name`).
#
# Expected usage in `scripts/pkg_<pkg>.sh`:
# 1) Set `pkg_name`.
# 2) Source this file.
# 3) Define required package functions (see `pkg_ensure_is_pkg_lib`).
# 4) Call `pkg_ensure_is_pkg_lib` at the end.
#
# Most helpers are package-related (paths, PKGBUILD/.SRCINFO handling, checks),
# while some are generic (e.g., random string generation). Log output is always
# prefixed with the current package name for clarity.

set -euo pipefail

# default
pkg_debug="${pkg_debug:-false}"

# commands required by the lib
# value is an optional command to validate the command is working as expected
declare -A pkg_commands_needed=(
    ['git']=""
    ["curl"]=""
    ["makepkg"]=""
    ["yq"]="yq --version | grep '^yq (https://github.com/mikefarah/yq/) version v' > /dev/null 2>&1"
)

declare -a pkg_types=(
    "local"
    "subtree"
)

# initialize the lib
pkg_init() {
    pkg_ensure_commands
    pkg_ensure_pkg
}

# ensure all required external commands are available and valid
pkg_ensure_commands()   {
    for cmd in "${!pkg_commands_needed[@]}"; do
        local check_cmd="${pkg_commands_needed[$cmd]}"

        if ! command -v "$cmd" > /dev/null 2>&1; then
            pkg_echo_fatal "Required command '$cmd' is not installed or not in PATH."
        fi

        if [[ -n "$check_cmd" ]]; then
            if ! eval "$check_cmd" > /dev/null 2>&1; then
                pkg_echo_fatal "Command '$cmd' failed validation: $check_cmd"
            fi
        fi
    done
}

# check if the current context is a valid package context
# after calling this function inside this lib, we assume all context checks below remain valid
# i.e., assume pkg_name is valid and folders/files exist; they are not checked again
pkg_ensure_pkg() {
    local name="${pkg_name:-}"

    # check for required facts
    if [[ -n "$name" && \
        -d $(pkg_pkg_path) && \
        -f "$(pkg_get_pkg_file)" && \
        -f "$(pkg_pkgbuild_file)" && \
        -f "$(pkg_srcinfo_file)" && \
        -f "$(pkg_license_file)" && \
        -f "repo.yml" ]] && \
        yq -e ".packages | has(\"$name\")" repo.yml >/dev/null 2>&1 && \
        yq -e ".packages.$name | has(\"type\")" repo.yml >/dev/null 2>&1 && \
        yq -e ".packages.$name | has(\"sync\")" repo.yml >/dev/null 2>&1; then

        # type must be set and valid
        local type=$(yq -e ".packages.$name.type" repo.yml 2>/dev/null)
        if [[ ! " ${pkg_types[*]} " =~ " $type " ]]; then
            pkg_echo_fatal "Invalid package type '$type' for '$name'. Expected one of: ${pkg_types[*]}"
        fi
        pkg_debug_echo "Package context verified for '$name' with type '$type'."

        # type object must exist in repo.yml
        local obj=$(yq -e ".packages.$name.$type" repo.yml 2>/dev/null)
        if [[ $? -ne 0 ]]; then
            pkg_echo_fatal "Failed to retrieve object for '$name'. Ensure the package structure and repo.yml are correct."
        fi
        
        pkg_debug_echo "Object type for '$name': $obj"

        return 0
    else
        pkg_echo_fatal "Invalid package context for '$name'. Ensure the package structure and repo.yml are correct."
    fi
}

pkg_type() {
    local type=$(yq -e ".packages.$pkg_name.type" repo.yml 2>/dev/null)
    echo "$type"
}

pkg_type_obj() {
    # assume keys are ensured
    local type=$(pkg_type)
    local obj=$(yq -e ".packages.$pkg_name.$type" repo.yml 2>/dev/null)

    echo "$obj"
}

pkg_is_sync_enabled() {
    # assume sync key is ensured
    local sync=$(yq -e ".packages.$pkg_name.sync" repo.yml 2>/dev/null)

    # value must be true or false
    if [[ ! " false true " =~ " $sync " ]]; then
        pkg_echo_fatal "Invalid sync value '$sync' for package '$pkg_name'. Expected 'true' or 'false'."
    fi

    echo "$sync"
    if [[ "$sync" == "true" ]]; then 
        return 0
    else
        return 1
    fi
}

# echo functions with the package name prefix and an emoji for better visibility
pkg_echo() {
    local msg="${1:-}"
    local type="${2:-}"

    local -A emoji_map=(
        ["ok"]="✅"
        ["err"]="❌"
        ["fatal"]="💀"
        ["info"]="ℹ️"
        ["warn"]="⚠️"
        ["debug"]="🐛"
        ["todo"]="📝"
    )

    prefix="${emoji_map[$type]:-}"
    echo "$prefix ${pkg_name:-unset}: $msg"
}

# lib echos if pkg_debug is true
pkg_debug_echo() {
    if [[ "$pkg_debug" == "true" ]]; then
        pkg_echo "${1:-}" debug
    fi
}

# pkg_echo with pre defined type fatal and exit 1
pkg_echo_fatal() {
    pkg_echo "${1:-}" fatal
    exit 1
}

# pkg_echo with pre defined type todo
pkg_echo_todo() {
    pkg_echo "${1:-}" todo
}

# pkg_echo with pre defined type err
pkg_echo_error() {
    pkg_echo "${1:-}" err
}

# pkg_echo with pre defined type info
pkg_echo_info() {
    pkg_echo "${1:-}" info
}

# pkg_echo with pre defined type warn
pkg_echo_warning() {
    pkg_echo "${1:-}" warn
}

# ensure that the package-specific lib file defines all required functions
# should be called at the end of pkgs lib file
pkg_ensure_is_pkg_lib() {
    local required_functions=(
        "pkg_get_upstream_version"
        "pkg_is_version"
        "pkg_is_version_gt"
    )
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" > /dev/null; then
            pkg_echo "required function '$func' is not defined" err
            exit 1
        fi
        pkg_debug_echo "required function '$func' is defined"
    done

    pkg_debug_echo "all required functions are defined and valid"
}

pkg_has_update() {
    local upstream_version=$(pkg_get_upstream_version)
    local pkgbuild_pkgver=$(pkg_get_pkgver)

    if ! pkg_is_version "$upstream_version"; then
        pkg_echo "ERROR: Invalid upstream version format: $upstream_version"
        exit 1
    fi

    if pkg_is_version_gt "$upstream_version" "$pkgbuild_pkgver" > /dev/null; then
        echo "$upstream_version" "$pkgbuild_pkgver"
        return 0 
    else
        echo "false"
        return 1
    fi
}

# generate a random alpha numeric string 
pkg_random() {
    local charset='A-Za-z0-9'
    local length="${1:-16}"
    local random_string=$(tr -dc "$charset" < /dev/urandom | head -c "$length")
    echo "$random_string"
}

# return the relative path to pkg
pkg_pkg_path() {
    echo "packages/$pkg_name"
}

# return the relative path to the package's PKGBUILD file
pkg_pkgbuild_file() {
    echo "$(pkg_pkg_path)/PKGBUILD"
}

# return the relative path to the package's .SRCINFO file
pkg_srcinfo_file() {
    echo "$(pkg_pkg_path)/.SRCINFO"
}

# return the relative path to the package's LICENSE file
pkg_license_file() {
    echo "$(pkg_pkg_path)/LICENSE"
}

pkg_rebuild_srcinfo() {
    local pkgbuild_file=$(pkg_pkgbuild_file)
    if [[ -f "$pkgbuild_file" ]]; then
        makepkg -D "$(pkg_pkg_path)" --printsrcinfo > "$(pkg_srcinfo_file)"
        pkg_debug_echo "Rebuilt .SRCINFO from $pkgbuild_file"
    else
        pkg_echo_fatal "PKGBUILD file not found at $pkgbuild_file. Cannot rebuild .SRCINFO."
    fi
}

# return the pkgbuild's pkgver value
pkg_get_pkgver() {
    echo $(grep '^pkgver=' "$(pkg_pkgbuild_file)" | cut -d '=' -f2)
}

# return the pkgbuild's pkgrel value
pkg_get_pkgrel() {
    echo $(grep '^pkgrel=' "$(pkg_pkgbuild_file)" | cut -d '=' -f2)
}

# return relative path to the package's lib script file
pkg_get_pkg_file() {
    echo "scripts/pkg_$pkg_name.sh"
}

pkg_init
pkg_debug_echo "sourced pkg.sh"