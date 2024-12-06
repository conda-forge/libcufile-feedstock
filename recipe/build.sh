#! /bin/bash

set -ex

${GCC} test_load_elf.c -std=c99 -Werror -ldl -o ${PREFIX}/bin/test_load_elf

${GCC} test_hello_world.c -std=c99 -Werror -ldl -o ${PREFIX}/bin/test_hello_world
