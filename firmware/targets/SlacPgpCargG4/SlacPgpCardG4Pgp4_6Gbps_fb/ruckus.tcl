# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load common and sub-module ruckus.tcl files
loadRuckusTcl $::env(PROJ_DIR)/../../../submodules/surf
loadRuckusTcl $::env(PROJ_DIR)/../../../submodules/axi-pcie-core/hardware/SlacPgpCardG4
loadRuckusTcl $::env(PROJ_DIR)/../../../common/pgp4/hardware/SlacPgpCardG4
loadRuckusTcl $::env(PROJ_DIR)/../../../common/core

# Load local source Code and constraints
loadSource      -dir "$::DIR_PATH/hdl"
loadConstraints -dir "$::DIR_PATH/hdl"

set_property top {Pgp4Tb} [get_filesets sim_1]
