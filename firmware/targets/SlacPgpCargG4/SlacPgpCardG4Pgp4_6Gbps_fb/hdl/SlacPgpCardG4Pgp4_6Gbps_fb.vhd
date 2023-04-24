-------------------------------------------------------------------------------
-- File       : SlacPgpCardG4Pgp4_6Gbps.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'PGP PCIe APP DEV'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'PGP PCIe APP DEV', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library axi_pcie_core;
use axi_pcie_core.AxiPciePkg.all;

library unisim;
use unisim.vcomponents.all;

entity SlacPgpCardG4Pgp4_6Gbps_fb is
   generic (
      TPD_G                : time    := 1 ns;
      ROGUE_SIM_EN_G       : boolean := false;
      PGP_TYPE_G           : string  := "PGP4";
      RATE_G               : string  := "6.25Gbps";
      DMA_AXIS_CONFIG_G    : AxiStreamConfigType         := ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 8, 2);  -- 64-bit interface
      BUILD_INFO_G         : BuildInfoType);
   port (
      ---------------------
      --  Application Ports
      ---------------------
      -- SFP Ports
      -- sfpRefClkP  : in    slv(1 downto 0);
      -- sfpRefClkN  : in    slv(1 downto 0);
      -- sfpRxP      : in    sl;
      -- sfpRxN      : in    sl;
      -- sfpTxP      : out   sl;
      -- sfpTxN      : out   sl;
      -- QSFP[1:0] Ports
      qsfpRefClkP : in    sl;
      qsfpRefClkN : in    sl;
      qsfp0RxP    : in    slv(3 downto 0);
      qsfp0RxN    : in    slv(3 downto 0);
      qsfp0TxP    : out   slv(3 downto 0);
      qsfp0TxN    : out   slv(3 downto 0);
      qsfp1RxP    : in    slv(3 downto 0);
      qsfp1RxN    : in    slv(3 downto 0);
      qsfp1TxP    : out   slv(3 downto 0);
      qsfp1TxN    : out   slv(3 downto 0);
      --------------
      --  Core Ports
      --------------
      -- System Ports
      emcClk      : in    sl;
      pwrScl      : inout sl;
      pwrSda      : inout sl;
      sfpScl      : inout sl;
      sfpSda      : inout sl;
      qsfpScl     : inout slv(1 downto 0);
      qsfpSda     : inout slv(1 downto 0);
      qsfpRstL    : out   slv(1 downto 0);
      qsfpLpMode  : out   slv(1 downto 0);
      qsfpModSelL : out   slv(1 downto 0);
      qsfpModPrsL : in    slv(1 downto 0);
      -- Boot Memory Ports
      flashCsL    : out   sl;
      flashMosi   : out   sl;
      flashMiso   : in    sl;
      flashHoldL  : out   sl;
      flashWp     : out   sl;
      -- PCIe Ports
      pciRstL     : in    sl;
      pciRefClkP  : in    sl;
      pciRefClkN  : in    sl;
      pciRxP      : in    slv(7 downto 0);
      pciRxN      : in    slv(7 downto 0);
      pciTxP      : out   slv(7 downto 0);
      pciTxN      : out   slv(7 downto 0));
end SlacPgpCardG4Pgp4_6Gbps_fb;

architecture top_level of SlacPgpCardG4Pgp4_6Gbps_fb is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   constant HDW_INDEX_C       : natural := 0;
   constant ASS_INDEX_C       : natural := 1;
   constant NUM_AXI_MASTERS_C : natural := 2;
   constant AXI_BASE_ADDR_G   : slv(31 downto 0) := x"0080_0000";
   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 21, 20);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   
   signal dmaClk          : sl;
   signal dmaRst          : sl;
   signal dmaBuffGrpPause : slv(7 downto 0);
   signal dmaObMasters    : AxiStreamMasterArray(7 downto 0);
   signal dmaObSlaves     : AxiStreamSlaveArray (7 downto 0);
   signal dmaIbMasters    : AxiStreamMasterArray(7 downto 0);
   signal dmaIbSlaves     : AxiStreamSlaveArray (7 downto 0);
   signal hdwClk          : sl;
   signal hdwRst          : sl;
   signal pgpObMasters    : AxiStreamMasterArray(7 downto 0);
   signal pgpObSlaves     : AxiStreamSlaveArray (7 downto 0);
   signal pgpIbMasters    : AxiStreamMasterArray(7 downto 0);
   signal pgpIbSlaves     : AxiStreamSlaveArray (7 downto 0);

begin

   U_axilClk : entity surf.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => true,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 2,
         -- MMCM attributes
         BANDWIDTH_G       => "OPTIMIZED",
         CLKIN_PERIOD_G    => 4.0,      -- 250 MHz
         CLKFBOUT_MULT_G   => 5,        -- 1.25GHz = 5 x 250 MHz
         CLKOUT0_DIVIDE_G  => 8,        -- 156.25MHz = 1.25GHz/8
         CLKOUT1_DIVIDE_G  => 6)        -- 208.33MHz = 1.25GHz/6
      port map(
         -- Clock Input
         clkIn     => dmaClk,
         rstIn     => dmaRst,
         -- Clock Outputs
         clkOut(0) => axilClk,
         clkOut(1) => hdwClk,
         -- Reset Outputs
         rstOut(0) => axilRst,
         rstOut(1) => hdwRst);

   U_Core : entity axi_pcie_core.SlacPgpCardG4Core
      generic map (
         TPD_G                => TPD_G,
         ROGUE_SIM_EN_G       => ROGUE_SIM_EN_G,
         ROGUE_SIM_CH_COUNT_G => 4,     -- 4 Virtual Channels per DMA lane
         BUILD_INFO_G         => BUILD_INFO_G,
         DMA_AXIS_CONFIG_G    => DMA_AXIS_CONFIG_G,
         DMA_SIZE_G           => 8)
      port map (
         ------------------------
         --  Top Level Interfaces
         ------------------------
         -- DMA Interfaces
         dmaClk          => dmaClk,
         dmaRst          => dmaRst,
         dmaBuffGrpPause => dmaBuffGrpPause,
         dmaObMasters    => dmaObMasters,
         dmaObSlaves     => dmaObSlaves,
         dmaIbMasters    => dmaIbMasters,
         dmaIbSlaves     => dmaIbSlaves,
         -- AXI-Lite Interface
         appClk          => axilClk,
         appRst          => axilRst,
         appReadMaster   => axilReadMaster,
         appReadSlave    => axilReadSlave,
         appWriteMaster  => axilWriteMaster,
         appWriteSlave   => axilWriteSlave,
         --------------
         --  Core Ports
         --------------
         -- System Ports
         emcClk          => emcClk,
         pwrScl         => pwrScl,
         pwrSda         => pwrSda,
         sfpScl         => sfpScl,
         sfpSda         => sfpSda,
         qsfpScl        => qsfpScl,
         qsfpSda        => qsfpSda,
         qsfpRstL       => qsfpRstL,
         qsfpLpMode     => qsfpLpMode,
         qsfpModSelL    => qsfpModSelL,
         qsfpModPrsL    => qsfpModPrsL,
         -- Boot Memory Ports
         flashCsL        => flashCsL,
         flashMosi       => flashMosi,
         flashMiso       => flashMiso,
         flashHoldL      => flashHoldL,
         flashWp         => flashWp,
         -- PCIe Ports
         pciRstL         => pciRstL,
         pciRefClkP      => pciRefClkP,
         pciRefClkN      => pciRefClkN,
         pciRxP          => pciRxP,
         pciRxN          => pciRxN,
         pciTxP          => pciTxP,
         pciTxN          => pciTxN);

   ---------------------
   -- AXI-Lite Crossbar
   ---------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_Hardware : entity work.Hardware
      generic map (
         TPD_G             => TPD_G,
         RATE_G            => "6.25Gbps",
         DMA_AXIS_CONFIG_G => DMA_AXIS_CONFIG_G,
         AXI_BASE_ADDR_G   => AXI_CONFIG_C(HDW_INDEX_C).baseAddr)
      port map (
         ------------------------
         --  Top Level Interfaces
         ------------------------
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters (HDW_INDEX_C),
         axilReadSlave   => axilReadSlaves  (HDW_INDEX_C),
         axilWriteMaster => axilWriteMasters(HDW_INDEX_C),
         axilWriteSlave  => axilWriteSlaves (HDW_INDEX_C),
         -- DMA Interface (dmaClk domain)
         dmaClk          => hdwClk,
         dmaRst          => hdwRst,
         dmaBuffGrpPause => dmaBuffGrpPause,
         dmaObMasters    => pgpObMasters,
         dmaObSlaves     => pgpObSlaves,
         dmaIbMasters    => pgpIbMasters,
         dmaIbSlaves     => pgpIbSlaves,
         ------------------
         --  Hardware Ports
         ------------------
         -- QSFP[0] Ports
         qsfpRefClkP     => qsfpRefClkP,
         qsfpRefClkN     => qsfpRefClkN,
         qsfp0RxP        => qsfp0RxP,
         qsfp0RxN        => qsfp0RxN,
         qsfp0TxP        => qsfp0TxP,
         qsfp0TxN        => qsfp0TxN,
         -- QSFP[1] Ports
         -- qsfp1RefClkP    => qsfp1RefClkP,
         -- qsfp1RefClkN    => qsfp1RefClkN,
         qsfp1RxP        => qsfp1RxP,
         qsfp1RxN        => qsfp1RxN,
         qsfp1TxP        => qsfp1TxP,
         qsfp1TxN        => qsfp1TxN);

   U_Listener : entity work.AxiStreamListener
      generic map (
         TPD_G             => TPD_G,
         AXIS_CONFIG_G     => DMA_AXIS_CONFIG_G )
      port map (
         saxisClk          => dmaClk,
         saxisRst          => dmaRst,
         saxisObMasters    => dmaObMasters,
         saxisObSlaves     => dmaObSlaves,
         saxisIbMasters    => dmaIbMasters,
         saxisIbSlaves     => dmaIbSlaves,

         maxisClk          => hdwClk,
         maxisRst          => hdwRst,
         maxisObMasters    => pgpObMasters,
         maxisObSlaves     => pgpObSlaves,
         maxisIbMasters    => pgpIbMasters,
         maxisIbSlaves     => pgpIbSlaves,

         axilClk           => axilClk,
         axilRst           => axilRst,
         axilWriteMaster   => axilWriteMasters(ASS_INDEX_C),
         axilWriteSlave    => axilWriteSlaves (ASS_INDEX_C),
         axilReadMaster    => axilReadMasters (ASS_INDEX_C),
         axilReadSlave     => axilReadSlaves  (ASS_INDEX_C)
      );
   
end architecture top_level;
