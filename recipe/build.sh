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
        mkdir -p ${PREFIX}/${targetsDir}/libcufile
        cp -rv $i ${PREFIX}/${targetsDir}/libcufile
    fi
done

check-glibc "$PREFIX"/lib*/*.so.* "$PREFIX"/bin/* "$PREFIX"/targets/*/lib*/*.so.* "$PREFIX"/targets/*/bin/*
