.DEFAULT_GOAL := regression

.PHONY: all regression test vcs compile run sim verdi postsyn postsyn-functional clean help

# Server-side VCS/Verdi RTL simulation.
# Run this Makefile from the rtl_group directory.
VCS          ?= vcs
VERDI        ?= Verdi-Ultra
TEST         ?= basic_instr
TESTS        := basic_instr sid if rt pwm

TOP_basic_instr      := tb_g03_basic_instr
TOP_sid              := tb_g03_sid
TOP_if               := tb_g03_if
TOP_rt               := tb_g03_rt
TOP_pwm              := tb_g03_pwm
FILELIST_basic_instr := tb/g03_basic_instr.f
FILELIST_sid         := tb/g03_sid.f
FILELIST_if          := tb/g03_if.f
FILELIST_rt          := tb/g03_rt.f
FILELIST_pwm         := tb/g03_pwm.f
PASS_MARKER_basic_instr := G03_BASIC_ALL_CORES_PASS
PASS_MARKER_sid         := G03_SID_ALL_CORES_PASS
PASS_MARKER_if          := G03_IF_ALL_CORES_PASS
PASS_MARKER_rt          := G03_RT_ALL_CORES_PASS
PASS_MARKER_pwm         := G03_PWM_ALL_CORES_PASS

# Post-synthesis simulation follows the course VCS flow: the file list
# supplies the gate netlist and timing library, and the testbench calls
# $sdf_annotate on the DUT. Paths in the file list are relative to this
# Makefile, matching the tutorial convention.
POSTSYN_TOP       ?= tb_g03_postsyn_smoke
POSTSYN_FILELIST  ?= tb/g03_postsyn_smoke.f
POSTSYN_BUILD     ?= build/g03_postsyn_smoke
POSTSYN_SIMV      := $(POSTSYN_BUILD)/simv
POSTSYN_LOG       := $(POSTSYN_BUILD)/vcs.log
POSTSYN_DEFINES   ?= +define+G03_POSTSYN_SDF
POSTSYN_VCS_FLAGS ?= +v2k -full64 -R -debug_access+all +mindelays -negdelay +neg_tchk

TOP          ?= $(TOP_$(TEST))
FILELIST     ?= $(FILELIST_$(TEST))
PASS_MARKER  ?= $(PASS_MARKER_$(TEST))
BUILD_DIR    ?= build/g03_$(TEST)
SIMV         := $(BUILD_DIR)/simv
FSDB         := $(BUILD_DIR)/g03_$(TEST).fsdb
VCS_LOG      := $(BUILD_DIR)/vcs.log
SIM_LOG      := $(BUILD_DIR)/sim.log
VERDI_LOG    := $(BUILD_DIR)/verdi.log

ifeq ($(strip $(TOP)),)
$(error Unknown TEST '$(TEST)'. Choose one of: $(TESTS))
endif
ifeq ($(strip $(FILELIST)),)
$(error No file list configured for TEST '$(TEST)')
endif
ifeq ($(strip $(PASS_MARKER)),)
$(error No pass marker configured for TEST '$(TEST)')
endif

# Most teaching servers export VERDI_HOME or NOVAS_HOME after the tool
# environment is initialized. Override FSDB_PLI when the local layout differs.
NOVAS_HOME   ?= $(VERDI_HOME)
FSDB_PLI     ?=
ifeq ($(strip $(FSDB_PLI)),)
ifneq ($(strip $(NOVAS_HOME)),)
FSDB_PLI := -P $(NOVAS_HOME)/share/PLI/VCS/LINUX64/novas.tab \
            $(NOVAS_HOME)/share/PLI/VCS/LINUX64/pli.a
endif
endif

INC_DIRS := \
    +incdir+tb \
    +incdir+top \
    +incdir+top/clk_rst \
    +incdir+top/ip \
    +incdir+top/gpr \
    +incdir+top/perips \
    +incdir+top/perips/bridge \
    +incdir+core00_wzc \
    +incdir+core00_wzc/core \
    +incdir+core00_wzc/utils \
    +incdir+core01_xyh \
    +incdir+core01_xyh/core \
    +incdir+core01_xyh/utils \
    +incdir+core10_hjx \
    +incdir+core10_hjx/core \
    +incdir+core10_hjx/utils \
    +incdir+core11_xzr \
    +incdir+core11_xzr/core \
    +incdir+core11_xzr/utils \
    +incdir+fpga

VCS_FLAGS := \
    -v2005 \
    -full64 \
    -timescale=1ns/1ps \
    -debug_access+all \
    -top $(TOP) \
    $(INC_DIRS) \
    -f $(FILELIST) \
    -Mdir=$(BUILD_DIR)/csrc \
    -o $(SIMV) \
    -l $(VCS_LOG)

# Regressions are console-only by default. Enable FSDB for one selected test
# with, for example: make sim TEST=pwm DUMP_FSDB=1.
DUMP_FSDB ?= 0
ifeq ($(DUMP_FSDB),1)
DUMP_FLAGS := +define+G03_DUMP_FSDB $(FSDB_PLI)
else
DUMP_FLAGS :=
endif

all: regression

test: regression

# Run all conformance tests independently. Each test UART-downloads its image
# through every FPGA route and resets/runs every core before checking results.
regression:

	@set -e; \
	for test_name in $(TESTS); do \
		$(MAKE) --no-print-directory sim TEST=$$test_name DUMP_FSDB=0; \
	done

# Keep the tutorial-compatible target name. It runs the selected test.
vcs: sim

compile:
	mkdir -p $(BUILD_DIR)/csrc
	$(VCS) $(VCS_FLAGS) $(DUMP_FLAGS)

run: compile
	$(SIMV) -l $(SIM_LOG)
	@grep -q "$(PASS_MARKER)" $(SIM_LOG) || { echo "$(TEST) regression did not report $(PASS_MARKER)"; exit 1; }

sim: run

# Post-synthesis timing simulation. Keep this deliberately close to the VCS
# tutorial command: compile and run with -R, use one file list, and select
# minimum delay values. No pulse-control options are applied here.
postsyn:
	mkdir -p $(POSTSYN_BUILD)/csrc
	$(VCS) $(POSTSYN_VCS_FLAGS) -timescale=1ns/1ps $(POSTSYN_DEFINES) \
		-top $(POSTSYN_TOP) -f $(POSTSYN_FILELIST) \
		-Mdir=$(POSTSYN_BUILD)/csrc -o $(POSTSYN_SIMV) -l $(POSTSYN_LOG)
	@grep -q "G03_POSTSYN_ALL_CORES_PASS" $(POSTSYN_LOG) || { echo "Post-synthesis regression did not pass"; exit 1; }

postsyn-functional:
	$(MAKE) --no-print-directory postsyn POSTSYN_BUILD=build/g03_postsyn_functional \
		POSTSYN_DEFINES= POSTSYN_VCS_FLAGS="$(POSTSYN_VCS_FLAGS) +notimingcheck"

verdi:
	@test -f $(FSDB) || { echo "Missing $(FSDB). Run 'make sim TEST=$(TEST) DUMP_FSDB=1' first."; exit 1; }
	$(VERDI) -sv $(INC_DIRS) -f $(FILELIST) -ssf $(FSDB) -nologo -l $(VERDI_LOG) &

clean:
	rm -rf build Verdi-SXLog Verdi-UltraLog

help:
	@echo "make regression             Run basic_instr, sid, if, rt, and pwm"
	@echo "make sim TEST=pwm           Compile and run one selected test"
	@echo "make sim TEST=pwm DUMP_FSDB=1  Run one test with FSDB dumping"
	@echo "make postsyn                Run SDF-annotated post-synthesis smoke test"
	@echo "make verdi TEST=pwm         Open that test's generated FSDB"
	@echo "make clean                  Remove generated simulation output"
