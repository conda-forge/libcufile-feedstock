#!/bin/bash

# Install to conda style directories
[[ -d lib64 ]] && mv lib64 lib
mkdir -p ${PREFIX}/lib
mkdir -p ${PREFIX}/lib/pkgconfig
mkdir -p ${PREFIX}/gds
rm -rv etc
mv -v man ${PREFIX}/man
[[ -d pkg-config ]] && mv pkg-config/* ${PREFIX}/lib/pkgconfig/
[[ -d "$PREFIX/lib/pkgconfig" ]] && sed -E -i "s|cudaroot=.+|cudaroot=$PREFIX|g" $PREFIX/lib/pkgconfig/cufile*.pc

[[ ${target_platform} == "linux-64" ]] && targetsDir="targets/x86_64-linux"
[[ ${target_platform} == "linux-aarch64" ]] && targetsDir="targets/sbsa-linux"

for i in `ls`; do
    [[ $i == "build_env_setup.sh" ]] && continue
    [[ $i == "conda_build.sh" ]] && continue
    [[ $i == "metadata_conda_debug.yaml" ]] && continue

    if [[ $i == "lib" ]] || [[ $i == "include" ]]; then
        mkdir -p ${PREFIX}/${targetsDir}
        mkdir -p ${PREFIX}/$i
        cp -rv $i ${PREFIX}/${targetsDir}
        if [[ $i == "lib" ]]; then
            for j in "$i"/*.so*; do
                echo j = $j
                [[ -L ${PREFIX}/$j ]] && continue

                # Shared libraries are symlinked in $PREFIX/lib
                echo ln -s ${PREFIX}/${targetsDir}/$j ${PREFIX}/$j
                ln -s ${PREFIX}/${targetsDir}/$j ${PREFIX}/$j

                echo patchelf --set-rpath '$ORIGIN' --force-rpath ${PREFIX}/${targetsDir}/$j
                patchelf --set-rpath '$ORIGIN' --force-rpath ${PREFIX}/${targetsDir}/$j
            done
        fi
    elif [[ $i == "tools" ]]; then
        cp -rv $i ${PREFIX}/gds/
        for j in `find $PREFIX/gds/$i`; do
            echo j = $j
            [[ -f $j ]] || continue
            k=`basename $j`
            if [[ $k == "gdscp" ]] || [[ $k == "gdsio" ]] || [[ $k == "gdscheck" ]] || [[ $k == "gds_stats" ]] || [[ $k == "gdsio_verify" ]]; then
                echo patchelf --set-rpath "\$ORIGIN/../../lib:\$ORIGIN/../../${targetsDir}/lib" --force-rpath $j
                patchelf --set-rpath "\$ORIGIN/../../lib:\$ORIGIN/../../${targetsDir}/lib" --force-rpath $j
            fi
        done
    else
        # Put all other files in targetsDir
        mkdir -p ${PREFIX}/${targetsDir}/${PKG_NAME}
        cp -rv $i ${PREFIX}/${targetsDir}/${PKG_NAME}
    fi
done

if [[ -f "${RECIPE_DIR}/common/detect-glibc" ]] ; then
  source "${RECIPE_DIR}/common/detect-glibc"
fi

SYSTEM_GLIBC_VERSION="$(glibc-detect system)"
RECIPE_GLIBC_VERSION="${c_stdlib_version:=0.0.0}"

for file in "${PREFIX}/${targetsDir}"/lib/libcufile*.so.*; do
    if [[ -f "$file" && ! -L "$file" ]]; then  # Ensure it's a file
      BINARY_GLIBC_VERSION="$(glibc-detect req $file)"
      echo "binary glibc ${BINARY_GLIBC_VERSION} <= recipe glibc ${RECIPE_GLIBC_VERSION} <= system glibc ${SYSTEM_GLIBC_VERSION} $file"
      BINARY_IS_COMPATIBLE="$(glibc-check compatible $BINARY_GLIBC_VERSION $RECIPE_GLIBC_VERSION)"
      if [[ $BINARY_IS_COMPATIBLE == "false" ]] ; then
        echo "The binary is not compatible with the recipe glibc pinning."
        exit 1
      fi
      echo "The binary is compatible."
    fi
done
