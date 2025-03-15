num_cores ?= 1
ref ?= Nemu

curr_dir = $(shell pwd)
difftest_csrc_dir = $(curr_dir)/env/difftest/src/test/csrc

config_dir = $(curr_dir)/env/difftest/config
diffsrc_dir = $(difftest_csrc_dir)/difftest
common_dir = $(difftest_csrc_dir)/common
gensrc_dir = $(difftest_csrc_dir)/generated-src
plugin_dir = $(difftest_csrc_dir)/plugin/spikedasm
vcssrc_dir = $(difftest_csrc_dir)/vcs

diffsrc_cxxfiles = $(shell find $(diffsrc_dir) -name "*.cpp")
common_cxxfiles = $(shell find $(common_dir) -name "*.cpp")
gensrc_cxxfiles = $(shell find $(gensrc_dir) -name "*.cpp")
plugin_cxxfiles = $(shell find $(plugin_dir) -name "*.cpp")
vcssrc_cxxfiles = $(shell find $(vcssrc_dir) -name "*.cpp")

vcs_home = $(VCS_HOME)

difftest_cxxfiles = $(diffsrc_cxxfiles) $(common_cxxfiles) $(gensrc_cxxfiles) $(plugin_cxxfiles) $(vcssrc_cxxfiles)
difftest_cxxflags = -std=c++17 -static -Wall -fPIC -DNUM_CORES=$(num_cores) -DREF_PROXY=$(ref)Proxy -DDEFAULT_EMU_RAM_SIZE=0x80000000 #(40 bit paddr)
difftest_cxxflags += -I$(config_dir) -I$(diffsrc_dir) -I$(common_dir) -I$(gensrc_dir) -I$(plugin_dir) -I$(vcssrc_dir) -I$(vcs_home)/include
difftest_ldflags = -Wl,--no-as-needed -lpthread -lSDL2 -ldl -lz -lsqlite3

libdifftest = $(curr_dir)/env/libdifftest.so

objs = $(difftest_cxxfiles:.cpp=.o)

$(libdifftest): $(objs)
	g++ -shared -o $@ $(objs) $(difftest_ldflags)

%.o: %.cpp
	g++ $(difftest_cxxflags) -c $< -o $@ $(difftest_ldflags)

clean-lib:
	rm -rf $(objs) $(libdifftest)

############################

rtl_dir = $(curr_dir)/rtl
simrtl_dir = $(curr_dir)/env/SimTop
vcstop_dir = $(curr_dir)/env/difftest/src/test/vsrc/vcs

flist:
	$(shell find $(rtl_dir) -name "*.v" -or -name "*.sv" > filelist.f)
	$(shell find $(simrtl_dir) -name "*.v" -or -name "*.sv" >> filelist.f)
	$(shell find $(gensrc_dir) -name "*.v" -or -name "*.sv" >> filelist.f)
	$(shell find $(vcstop_dir) -name "*.v" -or -name "*.sv" >> filelist.f)


sim_dir = $(curr_dir)/sim
vcs_flags = -full64 +v2k -timescale=1ns/1ns -sverilog -debug_access+all +lint=TFIPC-L
vcs_flags += -l comp.log -top tb_top -fgp -lca -kdb +nospecify +notimingcheck -xprop
vcs_flags += +define+DIFFTEST +define+ASSERT_VERBOSE_COND_=1 +define+PRINTF_COND_=1 +define+STOP_COND_=1 +define+VCS +define+CONSIDER_FSDB
vcs_flags += +incdir+$(gensrc_dir)

simv: flist
	$(shell if [ ! -e $(sim_dir)/comp ];then mkdir -p $(sim_dir)/comp; fi)
	cd $(sim_dir)/comp && vcs $(vcs_flags) -f $(curr_dir)/filelist.f
	rm $(curr_dir)/filelist.f

run_bin_dir = $(curr_dir)/bin
run_bin ?= hello.bin

run_opts += +workload=$(run_bin_dir)/$(run_bin) +diff=$(curr_dir)/NEMU/build/riscv64-nemu-interpreter-so
run_opts += -sv_root $(curr_dir)/env -sv_lib libdifftest
run_opts += +dump-wave=fsdb -fgp=num_threads:4,num_fsdb_threads:4
run_opts += -assert finish_maxfail=30 -assert global_finish_maxfail=10000

run: $(libdifftest)
	$(shell if [ ! -e $(sim_dir)/$(run_bin) ];then mkdir -p $(sim_dir)/$(run_bin); fi)
	touch $(sim_dir)/$(run_bin)/sim.log
	$(shell if [ -e $(sim_dir)/$(run_bin)/simv ];then rm -f $(sim_dir)/$(run_bin)/simv; fi)
	$(shell if [ -e $(sim_dir)/$(run_bin)/simv.daidir ];then rm -rf $(sim_dir)/$(run_bin)/simv.daidir; fi)
	ln -s $(sim_dir)/comp/simv $(sim_dir)/$(run_bin)/simv
	ln -s $(sim_dir)/comp/simv.daidir $(sim_dir)/$(run_bin)/simv.daidir
	cd $(sim_dir)/$(run_bin) && (export REF=$(ref); ./simv $(run_opts) 2> assert.log | tee sim.log)

clean:
	rm -rf $(sim_dir)
	rm -rf filelist.f