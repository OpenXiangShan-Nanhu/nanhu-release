#!/bin/bash

export NOOP_HOME=$(pwd)/Nanhu-V5
export NEMU_NEMU=$(pwd)/NEMU

function release_xstop() {
    make -C $NOOP_HOME verilog RELEASE=1 XSTOP_PREFIX=bosc_ BUILD_DIR=nanhu-rtl 2>&1 | tee $release_dir/.release_log/nanhu-rtl.log

    for file in $NOOP_HOME/nanhu-rtl/rtl/*.sv; do
        if [ -f "$file" ]; then
            sed -i -e '/^  .*DummyDPICWrapper/i\`ifndef SYNTHESIS' "$file"
            sed -i -e '/^  .*DummyDPICWrapper/{:L1 N; /;/!b L1; s/;/;\n`endif/ };' "$file"
            sed -i -E -e '/^  .*DelayReg(_[0-9]*)? difftest/i\`ifndef SYNTHESIS' "$file"
            sed -i -E -e '/^  .*DelayReg(_[0-9]*)? difftest/{:L1 N; /;/!b L1; s/;/;\n`endif/ };' "$file"
        fi
    done

    cp -r $NOOP_HOME/nanhu-rtl/rtl $release_dir
}

# env contain difftest and sim-verilog
function release_env() {
    sleep 5
    make -C $NOOP_HOME sim-verilog 2>&1 | tee $release_dir/.release_log/sim-rtl.log
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

function release_nemu() {
    make -C $NEMU_HOME riscv64-xs-ref_defconfig
    make -C $NEMU_HOME -j
    cp -r NEMU $release_dir
}

function release_misc() {
    cp -r Makefile bin $release_dir
}

function release_clean(){
    git -C $NOOP_HOME clean -fd
    rm -rf $NOOP_HOME/build $NOOP_HOME/out
    make -C $NOOP_HOME init 

    rm -rf $NEMU_HOME/build 
}

# create release dir
function setup() {
    date=$(date +%Y%m%d)
    commit=$(git -C $NOOP_HOME rev-parse --short HEAD)
    release_dir=$(pwd)/output/release_${date}_${commit}
    if [ -d "$release_dir" ]; then
        echo "$release_dir already exists"
        exit 0
    else
        mkdir -p $release_dir
        mkdir -p $release_dir/.release_log
    fi
}



release_clean 
setup
release_misc &
release_nemu &
release_xstop &
release_env &
wait

echo "release done"
