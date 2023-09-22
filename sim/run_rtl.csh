#!/usr/bin/env tcsh

# -------------------- Configure this line, keep rest the same!
setenv design CIS_Control_tb

# --- Cleanup older simulation files and directories
reset
rm -rf build/
# --- Create a new work directory
mkdir -p build/
cd build

# --- Set compiler arguments
setenv cargs "-full64 -nc +libext+.v+.sv+ "
setenv cargs_vhdl "-full64 -nc"

# --- Compile synthesis sources
vlogan -sverilog $cargs ../../CIS_Control/CIS_Control.sv
# --- Compile sim sources
vlogan -sverilog $cargs ../../CIS_Control/CIS_Control_tb.sv

# Run the testbench
vcs $design -full64 -debug_acc+all
./simv -gui=dve -ucli -i ../simoptions.tcl -gui=dve
#echo "\n\n ###################################"
#echo "\n You can run \n vcs <name_of_top_module> -full64 -debug_all -R -gui"

#echo "\n or ./simv"
cd ..
