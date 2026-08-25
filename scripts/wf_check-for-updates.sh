#! /bin/bash

# Workflow for checking upstream updates on all packages.
# This script checks each package in the repository for available upstream updates
# and automatically creates an issue for packages that need updating.
#
# The script sources wf_lib.sh, which:
# - Sets up the environment correctly with necessary variables and functions
# - Simulates GitHub Actions environments for local Bash execution
# - Works with both 'act --bind' (local Docker) and GitHub Actions runners
# - Creates a temporary working directory to safely stage workflow changes
#   without modifying the original data
#
# Before making modifications, the workflow copies data into a temporary work
# directory (the WORK_DIR environment variable) to ensure safe, isolated
# execution. WORK_DIR is relative to the GitHub workspace, which is the
# workflow job's starting working directory.

ls -A

if [[ -d '.git' ]]; then
    echo "Git repository detected."
fi

if [[ -f '.git' ]]; then
    echo "Git worktree detected."
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Inside a Git worktree."
else
    echo "Not inside a Git worktree."
fi

echo "PWD: $PWD"

env | grep -E '^(GITHUB|WORK)_'

. ./scripts/wf_lib.sh

pkg_dir="packages"

for pkg_path in "$pkg_dir"/*; do
    if [[ -d "$pkg_path" ]]; then
        pkg_name=$(basename "$pkg_path")
        pkg_script="./scripts/pkg_$pkg_name.sh"

        if [[ -f "$pkg_script" ]]; then
            . "$pkg_script"
            if ! data=$(pkg_has_update); then
                echo "No update available for $pkg_name"
                continue
            fi

            upstream_version=$(awk '{print $1}' <<< "$data")
            pkgbuild_pkgver=$(awk '{print $2}' <<< "$data")

            echo "Update available for $pkg_name:"
            echo "Upstream version: $upstream_version"
            echo "PKGBUILD version: $pkgbuild_pkgver"
        else
            echo "No package script found for $pkg_name, skipping."
        fi
    fi
done

