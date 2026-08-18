#!/bin/bash

#upstream_version="${{ steps.compare.outputs.upstream_version }}"
GITHUB_WORKSPACE=$PWD
upstream_version="1.0.0"
package_name="grok-build-bin"
GITHUB_OUTPUT="$GITHUB_WORKSPACE/.github/workflows/_update_pkgbuild_output.txt"


# above comes from github


package_dir="$GITHUB_WORKSPACE/$package_name"

pkgbuild_file="$package_dir/PKGBUILD"
if [[ ! -f "$pkgbuild_file" ]]; then
    echo "ERROR: $pkgbuild_file not found"
    exit 1
fi

# prepare work dir
work_dir="$(mktemp -d)"
cp -r $package_dir/* $work_dir

# update version and reset release in PKGBUILD
sed -i "s/pkgver=.*/pkgver=$upstream_version/" "$work_dir/PKGBUILD"
sed -i "s/pkgrel=.*/pkgrel=1/" "$work_dir/PKGBUILD"

# get arches from pkgbuild
arches=$(grep -oP "arch=\(\K[^\)]+" "$work_dir/PKGBUILD" | tr -d "'")



# for each arch, download the source via makepkg and calculate the b2sum
cd "$work_dir"
for arch in $arches; do
    echo "Downloading source for architecture: $arch"
    CARCH=$arch makepkg --noprogressbar --nobuild --nodeps --skipchecksums --force


    b2sum=$(b2sum "$work_dir/grok-$upstream_version-$arch" | awk '{print $1}')
    echo "b2sum for $arch: $b2sum"

    sed -i "s|b2sums_$arch=(.*)|b2sums_$arch=('$b2sum')|" "$work_dir/PKGBUILD"
done

# update .SRCINFO file
cd "$work_dir"
makepkg --printsrcinfo > $work_dir/.SRCINFO


# check if license in LICENSE file is still apache 2.0, if not, create issue to check manually
license_file="$work_dir/LICENSE"
if [[ -f "$license_file" ]]; then
    license=$(grep -i "Apache License" "$license_file")
    license_version=$(echo "$license" | grep -oP "Version 2.0")

    echo "License found in LICENSE file: $license"
    echo "License version: $license_version"

    if [[ "$license_version" != "Version 2.0" ]]; then
        # TODO create issue to check manually
        echo "ERROR: License is not Apache 2.0. Please check manually."
        echo "issue_license_check=true" >> $GITHUB_OUTPUT
        echo "skip_makepkg=true" >> $GITHUB_OUTPUT
        issue_license_check=true
        skip_makepkg=true
        exit 0
    fi
else
    echo "ERROR: LICENSE file not found. Please check manually."
    exit 1
fi

# update .SRCINFO file
makepkg --printsrcinfo > $work_dir/.SRCINFO

# copy updated PKGBUILD and .SRCINFO back to package dir
cp "$work_dir/PKGBUILD" "$package_dir/PKGBUILD"
cp "$work_dir/.SRCINFO" "$package_dir/.SRCINFO"

# cleanup and commit changes to git
ls -l "$work_dir"
echo $work_dir

exit 0


if [[ "$skip_makepkg" != "true" ]]; then
    # TODO to in approviate x86 arm envionment

    # run makepkg to update .SRCINFO and test build
    cd "$work_dir"

    

    for arch in $arches; do
        echo "Testing build for architecture: $arch"
        CARCH=$arch makepkg --noprogressbar --nodeps --force

        # check if the package was created
        pkg_file="$work_dir/grok-build-bin-$upstream_version-1-$arch.pkg.tar.zst"
        if [[ ! -f "$pkg_file" ]]; then
            echo "ERROR: Package file not created for architecture $arch. Please check the build logs."
            exit 1
        fi
    done

    # check if the package was created
    pkg_file="$work_dir/grok-build-bin-$upstream_version-1-x86_64.pkg.tar.zst"
    if [[ ! -f "$pkg_file" ]]; then
        echo "ERROR: Package file not created. Please check the build logs."
        exit 1
    fi
fi

exit 0

if [[ "$issue_license_check" != "true" ]]; then
    # move updated PKGBUILD and .SRCINFO back to package dir
    mv "$work_dir/PKGBUILD" "$package_dir/PKGBUILD"
    mv "$work_dir/.SRCINFO" "$package_dir/.SRCINFO"
fi

ls -l "$work_dir"
echo $work_dir
echo $work_dir/PKGUILD

echo "Updated PKGBUILD to version ${upstream_version}"