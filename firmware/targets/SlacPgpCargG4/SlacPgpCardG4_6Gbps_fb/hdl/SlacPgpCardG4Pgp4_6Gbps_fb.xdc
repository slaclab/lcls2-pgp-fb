##############################################################################
## This file is part of 'PGP PCIe APP DEV'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'PGP PCIe APP DEV', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_axilClk/PllGen.U_Pll/CLKOUT0]] -group [get_clocks -of_objects [get_pins U_Core/REAL_PCIE.U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/gt_top_i/phy_clk_i/bufg_gt_userclk/O]]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_axilClk/PllGen.U_Pll/CLKOUT1]] -group [get_clocks -of_objects [get_pins U_Core/REAL_PCIE.U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/U0/gt_top_i/phy_clk_i/bufg_gt_userclk/O]]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {U_Hardware/GEN_LANE[*].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]] -group [get_clocks -of_objects [get_pins {U_Hardware/GEN_LANE[*].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]]

#create_clock -name phyRxClk0 -period 10.560 [get_pins {U_Hardware/GEN_LANE[0].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name phyRxClk1 -period 10.560 [get_pins {U_Hardware/GEN_LANE[1].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name phyRxClk2 -period 10.560 [get_pins {U_Hardware/GEN_LANE[2].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name phyRxClk3 -period 10.560 [get_pins {U_Hardware/GEN_LANE[3].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name phyRxClk4 -period 10.560 [get_pins {U_Hardware/GEN_LANE[4].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name phyRxClk5 -period 10.560 [get_pins {U_Hardware/GEN_LANE[5].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name phyRxClk6 -period 10.560 [get_pins {U_Hardware/GEN_LANE[6].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name phyRxClk7 -period 10.560 [get_pins {U_Hardware/GEN_LANE[7].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_rx_user_clocking_internal.gen_single_instance.gtwiz_userclk_rx_inst/gen_gtwiz_userclk_rx_main.bufg_gt_usrclk2_inst/O}]

#create_clock -name pgpClk0 -period 10.560 [get_pins {U_Hardware/GEN_LANE[0].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name pgpClk1 -period 10.560 [get_pins {U_Hardware/GEN_LANE[1].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name pgpClk2 -period 10.560 [get_pins {U_Hardware/GEN_LANE[2].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name pgpClk3 -period 10.560 [get_pins {U_Hardware/GEN_LANE[3].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name pgpClk4 -period 10.560 [get_pins {U_Hardware/GEN_LANE[4].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name pgpClk5 -period 10.560 [get_pins {U_Hardware/GEN_LANE[5].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name pgpClk6 -period 10.560 [get_pins {U_Hardware/GEN_LANE[6].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]
#create_clock -name pgpClk7 -period 10.560 [get_pins {U_Hardware/GEN_LANE[7].U_Lane/U_Pgp/U_Pgp3GthUsIpWrapper_1/GEN_6G.U_Pgp3GthUsIp/inst/gen_gtwizard_gthe3_top.Pgp3GthUsIp6G_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.bufg_gt_usrclk2_inst/O}]


######################
# Timing Constraints #
######################

#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {phyRxClk0}] -group [get_clocks -include_generated_clocks {pgpClk0}] -group [get_clocks -include_generated_clocks {qsfpRefClkP}] -group [get_clocks -include_generated_clocks {pciRefClkP}]
#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {phyRxClk1}] -group [get_clocks -include_generated_clocks {pgpClk1}] -group [get_clocks -include_generated_clocks {qsfpRefClkP}] -group [get_clocks -include_generated_clocks {pciRefClkP}]
#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {phyRxClk2}] -group [get_clocks -include_generated_clocks {pgpClk2}] -group [get_clocks -include_generated_clocks {qsfpRefClkP}] -group [get_clocks -include_generated_clocks {pciRefClkP}]
#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {phyRxClk3}] -group [get_clocks -include_generated_clocks {pgpClk3}] -group [get_clocks -include_generated_clocks {qsfpRefClkP}] -group [get_clocks -include_generated_clocks {pciRefClkP}]

#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {phyRxClk4}] -group [get_clocks -include_generated_clocks {pgpClk4}] -group [get_clocks -include_generated_clocks {qsfpRefClkP}] -group [get_clocks -include_generated_clocks {pciRefClkP}]
#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {phyRxClk5}] -group [get_clocks -include_generated_clocks {pgpClk5}] -group [get_clocks -include_generated_clocks {qsfpRefClkP}] -group [get_clocks -include_generated_clocks {pciRefClkP}]
#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {phyRxClk6}] -group [get_clocks -include_generated_clocks {pgpClk6}] -group [get_clocks -include_generated_clocks {qsfpRefClkP}] -group [get_clocks -include_generated_clocks {pciRefClkP}]
#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {phyRxClk7}] -group [get_clocks -include_generated_clocks {pgpClk7}] -group [get_clocks -include_generated_clocks {qsfpRefClkP}] -group [get_clocks -include_generated_clocks {pciRefClkP}]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_axilClk/PllGen.U_Pll/CLKOUT0]] -group [get_clocks -of_objects [get_pins U_axilClk/PllGen.U_Pll/CLKOUT1]]
