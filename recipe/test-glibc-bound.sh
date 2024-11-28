#!/bin/bash
set -ex

LIB_PATH=$PREFIX/lib/libcufile.so.0
# resolve symlinks
LIB_PATH=$(readlink -f $LIB_PATH)
# the upper bound of glibc symbols that we find linked in the library
# may at most be the same as c_stdlib_version, which is the lower bound
# at runtime enforced by the package metadata
GLIBC_UPPER_BOUND=${c_stdlib_version}

# get glibc versions from the symbols linked in the library; entries look like
#   212: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND log2f@GLIBC_2.27 (14)
#   235: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND fopen@GLIBC_2.17 (3)
found_versions=$(readelf -Ws $LIB_PATH | sed -n 's/.*@GLIBC_\([0-9.]*\).*/\1/p' | sort -u)
# check that we've actually found something
[[ $(echo "$found_versions" | wc -l) -lt 1 ]] && exit 1

# Compare each version we found against the upper bound
for version in $found_versions; do
    # if `max(ver, upper) != upper`, we found a violation
    if [[ $(printf '%s\n' "$version" "$GLIBC_UPPER_BOUND" | sort -V | tail -n 1) != "$GLIBC_UPPER_BOUND" ]]; then
        echo "Error: Found symbol from glibc $version, which exceeds upper bound $GLIBC_UPPER_BOUND."
        exit 1
    fi
done
