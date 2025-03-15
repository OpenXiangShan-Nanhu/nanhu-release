#!/bin/bash

export NOOP_HOME=$(pwd)/Nanhu-V5 

function release_xstop() {
    make -C $NOOP_HOME verilog RELEASE=1 XSTOP_PREFIX=bosc_ BUILD_DIR=xstop 2>&1 | tee $release_dir/.release_log/xstop.log
    cp -r $NOOP_HOME/xstop/rtl $release_dir
}

# env contain difftest and sim-verilog
function release_env() {
    make -C $NOOP_HOME sim-verilog 2>&1 | tee $release_dir/.release_log/simtop.log
    cd $NOOP_HOME && python3 scripts/parser.py SimTop --ignore XSTop  --include difftest/src/test/vsrc/common && cd ..

    env_dir=$release_dir/env
    mkdir -p $env_dir

    cp -r $NOOP_HOME/SimTop*/SimTop $env_dir
    cp -f $NOOP_HOME/difftest/src/test/vsrc/common/assert.v $env_dir/SimTop
    sed -i 's/XSTop l_soc/bosc_&/' $env_dir/SimTop/SimTop.v

    cp -r $NOOP_HOME/difftest $env_dir
    cp -r $NOOP_HOME/build/generated-src $env_dir/difftest/src/test/csrc
    sed -i 's/RAM_SIZE 0x7ff80000000UL/RAM_SIZE 0xff80000000UL/' $env_dir/difftest/config/config.h #(40 bit paddr)
}

function release_misc() {
    cp -r NEMU Makefile bin $release_dir
}


git -C $NOOP_HOME clean -fd
rm -rf $NOOP_HOME/build
# create release dir
date=$(date +%Y%m%d)
commit=$(git -C $NOOP_HOME rev-parse --short HEAD)
release_dir=output/release_${date}_${commit}
mkdir -p $release_dir
mkdir -p $release_dir/.release_log

release_misc &
release_xstop &
release_env &
wait

echo "release done"
