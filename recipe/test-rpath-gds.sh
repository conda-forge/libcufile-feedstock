#!/bin/bash

[[ ${target_platform} == "linux-64" ]] && targetsDir="targets/x86_64-linux"
[[ ${target_platform} == "linux-ppc64le" ]] && targetsDir="targets/ppc64le-linux"
[[ ${target_platform} == "linux-aarch64" && ${arm_variant_type} == "sbsa" ]] && targetsDir="targets/sbsa-linux"
[[ ${target_platform} == "linux-aarch64" && ${arm_variant_type} == "tegra" ]] && targetsDir="targets/aarch64-linux"

errors=""

for item in `find ${PREFIX}/gds/tools -type f`; do
    [[ -L $item ]] && continue
    filename=`basename $item`
    [[ $filename == "gdscp" ]] || [[ $filename == "gdsio" ]] || [[ $filename == "gdscheck" ]] || [[ $filename == "gds_stats" ]] || [[ $filename == "gdsio_verify" ]] || continue

    echo "Artifact to test: $item"

    pkg_info=$(conda package -w "${item}")
    echo "\$PKG_NAME: ${PKG_NAME}"
    echo "\$pkg_info: ${pkg_info}"

    if [[ ! "$pkg_info" == *"$PKG_NAME"* ]]; then
        echo "Not a match, skipping ${item}"
        continue
    fi

    echo "Match found, testing ${item}"

    rpath=$(patchelf --print-rpath $item)
    echo "$item rpath: $rpath"
    if [[ $item =~ gds && $rpath != "\$ORIGIN/../../lib:\$ORIGIN/../../${targetsDir}/lib" ]]; then
        errors+="$item\n"
    elif [[ $(objdump -x ${item} | grep "PATH") == *"RUNPATH"* ]]; then
        errors+="$item\n"
    fi
done

if [[ $errors ]]; then
    echo "The following files were found with an unexpected RPATH:"
    echo -e "$errors"
    exit 1
fi
