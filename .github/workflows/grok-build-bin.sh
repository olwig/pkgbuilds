#!/bin/bash

set -e

GITHUB_OUTPUT=".github/workflows/github_output.txt"

echo "" > $GITHUB_OUTPUT

function update_pkgbuild {
    local new_version="$1"
    local new_release="$2"

    base_dir=$(pwd)
    pkgbuild_file="grok-build-bin/PKGBUILD"
    work_dir="grok-build-bin/work"

    mkdir -p "$work_dir"

    pkgbuild_file_new="$work_dir/PKGBUILD.new"
    pkgbuild_file_old="$work_dir/PKGBUILD.old"

    cp "$pkgbuild_file" "$pkgbuild_file_old"
    cp "$pkgbuild_file" "$pkgbuild_file_new"

    echo "Updating PKGBUILD version to $new_version and release to $new_release"

    # update version and release
    sed -i "s/pkgver=.*/pkgver=$new_version/" "$pkgbuild_file_new"
    sed -i "s/pkgrel=.*/pkgrel=$new_release/" "$pkgbuild_file_new"

    # new files for new version
    source_x86_64_new="grok-$new_version-x86_64::https://x.ai/cli/grok-${new_version}-linux-x86_64"
    source_aarch64_new="grok-$new_version-aarch64::https://x.ai/cli/grok-${new_version}-linux-aarch64"
    source_license_new="LICENSE::https://raw.githubusercontent.com/xai-org/grok-build/refs/heads/main/LICENSE"

    # download new files, to work dir
    # TODO: no puplicate download. update PKGBUILD and net mnakepkg download and cache it.
    curl -L -o "$work_dir/grok-$new_version-linux-x86_64" "https://x.ai/cli/grok-${new_version}-linux-x86_64"
    curl -L -o "$work_dir/grok-$new_version-linux-aarch64" "https://x.ai/cli/grok-${new_version}-linux-aarch64"
    curl -L -o "$work_dir/LICENSE" "https://raw.githubusercontent.com/xai-org/grok-build/refs/heads/main/LICENSE"

    # calc checksums
    b2sum_x86_64=$(b2sum "$work_dir/grok-$new_version-linux-x86_64" | awk '{print $1}')
    b2sum_aarch64=$(b2sum "$work_dir/grok-$new_version-linux-aarch64" | awk '{print $1}')
    b2sum_license=$(b2sum "$work_dir/LICENSE" | awk '{print $1}')

    # echo new checksums with filenams and files sizes
    echo "New checksums:"
    echo "x86_64: $b2sum_x86_64"
    echo "aarch64: $b2sum_aarch64"
    echo "LICENSE: $b2sum_license"
    echo "x86_64 size: $(stat -c%s "$work_dir/grok-$new_version-linux-x86_64")"
    echo "aarch64 size: $(stat -c%s "$work_dir/grok-$new_version-linux-aarch64")"
    echo "LICENSE size: $(stat -c%s "$work_dir/LICENSE")"

    # update checksums in PKGBUILD
    sed -i "s|b2sums_x86_64=(.*)|b2sums_x86_64=('$b2sum_x86_64')|" "$pkgbuild_file_new"
    sed -i "s|b2sums_aarch64=(.*)|b2sums_aarch64=('$b2sum_aarch64')|" "$pkgbuild_file_new"
    sed -i "s|b2sums=(.*)|b2sums=('$b2sum_license')|" "$pkgbuild_file_new"

    # update .SRCINFO file and test build
    cd $work_dir
    makepkg -p PKGBUILD.new --printsrcinfo > .SRCINFO
    makepkg -f -p PKGBUILD.new
    cd $base_dir

    # check for valid build
    x86_pkg="$work_dir/grok-build-bin-$new_version-1-x86_64.pkg.tar.zst"
    arm_pkg="$work_dir/grok-build-bin-$new_version-1-aarch64.pkg.tar.zst"

    if [[ -f "$x86_pkg" || -f "$arm_pkg" ]]; then
        echo "Build successful. New package created."
        [[ -f "$x86_pkg" ]] && echo "$x86_pkg"
        [[ -f "$arm_pkg" ]] && echo "$arm_pkg"
    else
        echo "Build failed. No new packages created."
        exit 1
    fi

    # cleanup and move PKGBUILD.new and .SRCINFO to pkg's root
    mv "$work_dir/PKGBUILD.new" "$base_dir/grok-build-bin/PKGBUILD"
    mv "$work_dir/.SRCINFO" "$base_dir/grok-build-bin/.SRCINFO"
    rm -rf "$work_dir"

    # commmit changes to git
    git config --global user.name "github-actions[bot]"
    git config --global user.email "github-actions[bot]@users.noreply.github.com"
    git add "$base_dir/grok-build-bin/PKGBUILD" "$base_dir/grok-build-bin/.SRCINFO"
    git commit -m "Update PKGBUILD to version $new_version and release $new_release"
}


# step: get latest version grok-build
VERSION=$(curl -s https://x.ai/cli/stable)
echo "Current stable version: $VERSION"
echo "version=$VERSION" >> $GITHUB_OUTPUT

# step: get current PKGBUILD version and release in grok-build-bin/PKGBUILD
pkgbuild_file="grok-build-bin/PKGBUILD"
pkgbuild_version=$(grep -oP 'pkgver=\K[0-9]+\.[0-9]+\.[0-9]+' "$pkgbuild_file")
pkgbuild_release=$(grep -oP 'pkgrel=\K[0-9]+' "$pkgbuild_file")
echo "Current PKGBUILD version: $pkgbuild_version"
echo "Current PKGBUILD release: $pkgbuild_release"
echo "pkgbuild_version=$pkgbuild_version" >> $GITHUB_OUTPUT
echo "pkgbuild_release=$pkgbuild_release" >> $GITHUB_OUTPUT

# dispatch next job based on version comparison
if [[ "$pkgbuild_version" == "$VERSION" ]]; then
    echo "PKGBUILD version is the same as the latest version. Nothing to do."
    exit 0
elif [[ "$pkgbuild_version" < "$VERSION" ]]; then
    echo "PKGBUILD version is lower than the latest version. Updating version and resetting release number."
    update_pkgbuild "$VERSION" "1"
else
    echo "PKGBUILD version is higher than the latest version. Check manually whats going on."
    exit 1
fi