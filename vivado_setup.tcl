# ============================================================================
# vivado_setup.tcl - one-command Vivado project setup for the 8085+MUL project
#
# USAGE (pick one):
#   1) Vivado GUI : Tools -> Run Tcl Script -> select this file
#   2) Terminal   : vivado -mode batch -source vivado_setup.tcl
#      (add "-mode gui" instead of "-mode batch" to open the GUI after)
#
# WHAT IT DOES:
#   * creates project cpu8085_mul in ./vivado_proj (Artix-7 35T)
#   * adds rtl/*.v as design sources, top_8085 as synthesis top
#   * adds tb/*.v as simulation sources, tb_8085 as simulation top
#   * launches behavioral simulation and runs it to $finish
#
# Change PART below if your college lab uses a different board/chip.
# ============================================================================

set PART "xc7a35tcpg236-1"
# ^ Artix-7 35T : Basys3, Arty A7-35T (most common in college labs).
#   Examples for other boards:
#   ZedBoard (Zynq) ......... set PART "xc7z020clg484-1"
#   Nexys A7-100T ........... set PART "xc7a100tcsg324-1"
#   Spartan-7 SP701 ......... set PART "xc7s25csga324-1"

set PROJ "cpu8085_mul"
set DIR  "./vivado_proj"

# --- run from the script's own folder, no matter where Vivado was started ---
# (so the ./rtl and ./tb relative paths below always resolve correctly)
set THIS_DIR [file dirname [info script]]
cd $THIS_DIR
puts "INFO: working directory = $THIS_DIR"

# --- create project ---
create_project $PROJ $DIR -part $PART -force
puts "INFO: created project $PROJ for part $PART"

# --- design sources ---
add_files [glob ./rtl/*.v]
set_property top top_8085 [get_filesets sources_1]
puts "INFO: synthesis top = top_8085"

# --- simulation sources (full test suite) ---
add_files -fileset sim_1 [glob ./tb/*.v]
set_property top tb_8085_full [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
puts "INFO: simulation top = tb_8085_full (full test suite)"

# --- run behavioral simulation ---
puts "INFO: launching behavioral simulation ..."
launch_simulation -mode behavioral
run all
puts "INFO: simulation finished (see Tcl console log above for PASS/FAIL)."
