-------------------------------------------------------------------------------
-- File       : XilinxKcu1500Pgp4_6Gbps.vhd
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

entity XilinxKcu1500Pgp4_6Gbps_lockerapp is
   generic (
      TPD_G                : time                        := 1 ns;
      ROGUE_SIM_EN_G       : boolean                     := false;
      ROGUE_SIM_PORT_NUM_G : natural range 1024 to 49151 := 8000;
      DMA_AXIS_CONFIG_G    : AxiStreamConfigType         := ssiAxiStreamConfig(dataBytes => 16, tDestBits => 8, tIdBits => 3);  --- 16 Byte (128-bit) tData interface
      BUILD_INFO_G         : BuildInfoType);
   port (
      ---------------------
      --  Application Ports
      ---------------------
      -- QSFP[0] Ports
      qsfp0RefClkP : in    slv(1 downto 0);
      qsfp0RefClkN : in    slv(1 downto 0);
      qsfp0RxP     : in    slv(3 downto 0);
      qsfp0RxN     : in    slv(3 downto 0);
      qsfp0TxP     : out   slv(3 downto 0);
      qsfp0TxN     : out   slv(3 downto 0);
      -- QSFP[1] Ports
      qsfp1RefClkP : in    slv(1 downto 0);
      qsfp1RefClkN : in    slv(1 downto 0);
      qsfp1RxP     : in    slv(3 downto 0);
      qsfp1RxN     : in    slv(3 downto 0);
      qsfp1TxP     : out   slv(3 downto 0);
      qsfp1TxN     : out   slv(3 downto 0);
      --------------
      --  Core Ports
      --------------
      -- System Ports
      emcClk       : in    sl;
      userClkP     : in    sl;
      userClkN     : in    sl;
      i2cRstL      : out   sl;
      i2cScl       : inout sl;
      i2cSda       : inout sl;
      -- QSFP[0] Ports
      qsfp0RstL    : out   sl;
      qsfp0LpMode  : out   sl;
      qsfp0ModSelL : out   sl;
      qsfp0ModPrsL : in    sl;
      -- QSFP[1] Ports
      qsfp1RstL    : out   sl;
      qsfp1LpMode  : out   sl;
      qsfp1ModSelL : out   sl;
      qsfp1ModPrsL : in    sl;
      -- Boot Memory Ports
      flashCsL     : out   sl;
      flashMosi    : out   sl;
      flashMiso    : in    sl;
      flashHoldL   : out   sl;
      flashWp      : out   sl;
      -- PCIe Ports
      pciRstL      : in    sl;
      pciRefClkP   : in    sl;
      pciRefClkN   : in    sl;
      pciRxP       : in    slv(7 downto 0);
      pciRxN       : in    slv(7 downto 0);
      pciTxP       : out   slv(7 downto 0);
      pciTxN       : out   slv(7 downto 0));
end XilinxKcu1500Pgp4_6Gbps_lockerapp;

architecture top_level of XilinxKcu1500Pgp4_6Gbps_lockerapp is

   signal userClk156      : sl;
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
   signal hdwIbMasters    : AxiStreamMasterArray(7 downto 0);
   signal hdwIbSlaves     : AxiStreamSlaveArray (7 downto 0);
   signal tmMasters       : AxiStreamMasterArray(7 downto 0);
   signal tmSlaves        : AxiStreamSlaveArray (7 downto 0);
   signal tsMasters       : AxiStreamMasterArray(7 downto 0);
   signal tsSlaves        : AxiStreamSlaveArray (7 downto 0);
   signal rpMasters       : AxiStreamDualMasterArray(7 downto 0);
   signal rpSlaves        : AxiStreamDualSlaveArray (7 downto 0);
   signal swMasters       : AxiStreamMasterArray(7 downto 0);
   signal swSlaves        : AxiStreamSlaveArray (7 downto 0);
   signal appObMaster     : AxiStreamMasterType;
   signal appObSlave      : AxiStreamSlaveType;
   signal axilRegs        : Slv32Array(1 downto 0);
   signal axilRegsSync    : Slv32Array(1 downto 0);
   signal monRegs         : Slv32Array(7 downto 0);
   signal monRegsSync     : Slv32Array(7 downto 0);

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
         CLKIN_PERIOD_G    => 6.4,      -- 156.25 MHz
         CLKFBOUT_MULT_G   => 8,        -- 1.25GHz = 8 x 156.25 MHz
         CLKOUT0_DIVIDE_G  => 8,        -- 156.25MHz = 1.25GHz/8
         CLKOUT1_DIVIDE_G  => 6)        -- 208.33MHz = 1.25GHz/6
      port map(
         -- Clock Input
         clkIn     => userClk156,
         rstIn     => dmaRst,
         -- Clock Outputs
         clkOut(0) => axilClk,
         clkOut(1) => hdwClk,
         -- Reset Outputs
         rstOut(0) => axilRst,
         rstOut(1) => hdwRst);

   U_Core : entity axi_pcie_core.XilinxKcu1500Core
      generic map (
         TPD_G                => TPD_G,
         ROGUE_SIM_EN_G       => ROGUE_SIM_EN_G,
         ROGUE_SIM_PORT_NUM_G => ROGUE_SIM_PORT_NUM_G,
         BUILD_INFO_G         => BUILD_INFO_G,
         DMA_AXIS_CONFIG_G    => DMA_AXIS_CONFIG_G,
         DMA_SIZE_G           => 8)
      port map (
         ------------------------
         --  Top Level Interfaces
         ------------------------
         userClk156      => userClk156,
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
         userClkP        => userClkP,
         userClkN        => userClkN,
         i2cRstL         => i2cRstL,
         i2cScl          => i2cScl,
         i2cSda          => i2cSda,
         -- QSFP[0] Ports
         qsfp0RstL       => qsfp0RstL,
         qsfp0LpMode     => qsfp0LpMode,
         qsfp0ModSelL    => qsfp0ModSelL,
         qsfp0ModPrsL    => qsfp0ModPrsL,
         -- QSFP[1] Ports
         qsfp1RstL       => qsfp1RstL,
         qsfp1LpMode     => qsfp1LpMode,
         qsfp1ModSelL    => qsfp1ModSelL,
         qsfp1ModPrsL    => qsfp1ModPrsL,
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
         qsfp0RefClkP    => qsfp0RefClkP,
         qsfp0RefClkN    => qsfp0RefClkN,
         qsfp0RxP        => qsfp0RxP,
         qsfp0RxN        => qsfp0RxN,
         qsfp0TxP        => qsfp0TxP,
         qsfp0TxN        => qsfp0TxN,
         -- QSFP[1] Ports
         qsfp1RefClkP    => qsfp1RefClkP,
         qsfp1RefClkN    => qsfp1RefClkN,
         qsfp1RxP        => qsfp1RxP,
         qsfp1RxN        => qsfp1RxN,
         qsfp1TxP        => qsfp1TxP,
         qsfp1TxN        => qsfp1TxN);

   swMasters(0) <= AXI_STREAM_MASTER_INIT_C;
   swSlaves (0) <= AXI_STREAM_SLAVE_FORCE_C;
   tmMasters(0) <= AXI_STREAM_MASTER_INIT_C;
   tmSlaves (0) <= AXI_STREAM_SLAVE_FORCE_C;
   
   GEN_LANE : for lane in 7 downto 1 generate
     
      U_Tap : entity surf.AxiStreamTap
         generic map (
            TPD_G          => TPD_G,
            TAP_DEST_G     => 1 )  -- event data
         port map (
            sAxisMaster    => pgpIbMasters(lane),
            sAxisSlave     => pgpIbSlaves (lane),
            mAxisMaster    => hdwIbMasters(lane),
            mAxisSlave     => hdwIbSlaves (lane),
            tmAxisMaster   => tmMasters   (lane),
            tmAxisSlave    => tmSlaves    (lane),
            tsAxisMaster   => tsMasters   (lane),
            tsAxisSlave    => tsSlaves    (lane),
            axisClk        => hdwClk,
            axisRst        => hdwRst );

      U_REPEAT : entity surf.AxiStreamRepeater
        generic map (
          TPD_G               => TPD_G,
          NUM_MASTERS_G       => 2,
          INPUT_PIPE_STAGES_G => 1
          )
        port map (
          axisClk      => hdwClk,
          axisRst      => hdwRst,
          sAxisMaster  => tmMasters(lane),
          sAxisSlave   => tmSlaves (lane),
          mAxisMasters => rpMasters(lane),
          mAxisSlaves  => rpSlaves (lane) );
      
      U_RELIEF : entity work.AxiStreamRelief
        generic map (
          TPD_G         => TPD_G,
          AXIS_CONFIG_G => DMA_AXIS_CONFIG_G
         )
        port map (
          axiClk      => hdwClk,
          axiRst      => hdwRst,
          saxisMaster => rpMasters(lane)(0),
          saxisSlave  => rpSlaves (lane)(0),
          maxisMaster => tsMasters(lane),
          maxisSlave  => tsSlaves (lane) );

      swMasters(lane)    <= rpMasters(lane)(1);
      rpSlaves (lane)(1) <= swSlaves (lane);

      U_DmaIbFifo : entity surf.AxiStreamFifoV2
        generic map (
          TPD_G               => TPD_G,
          SLAVE_AXI_CONFIG_G  => DMA_AXIS_CONFIG_G,
          MASTER_AXI_CONFIG_G => DMA_AXIS_CONFIG_G )
        port map (
          sAxisClk     => hdwClk,
          sAxisRst     => hdwRst,
          sAxisMaster  => hdwIbMasters(lane),
          sAxisSlave   => hdwIbSlaves (lane) ,
          sAxisCtrl    => open  ,
          mAxisClk     => dmaClk,
          mAxisRst     => dmaRst,
          mAxisMaster  => dmaIbMasters(lane),
          mAxisSlave   => dmaIbSlaves (lane) );
      
      U_DmaObFifo : entity surf.AxiStreamFifoV2
        generic map (
          TPD_G               => TPD_G,
          SLAVE_AXI_CONFIG_G  => DMA_AXIS_CONFIG_G,
          MASTER_AXI_CONFIG_G => DMA_AXIS_CONFIG_G )
        port map (
          sAxisClk     => dmaClk,
          sAxisRst     => dmaRst,
          sAxisMaster  => dmaObMasters(lane),
          sAxisSlave   => dmaObSlaves (lane) ,
          sAxisCtrl    => open  ,
          mAxisClk     => hdwClk,
          mAxisRst     => hdwRst,
          mAxisMaster  => pgpObMasters(lane),
          mAxisSlave   => pgpObSlaves (lane) );
      
   end generate GEN_LANE;

   -- dmaObMasters(0) is sunk
   dmaObSlaves (0) <= AXI_STREAM_SLAVE_INIT_C;

   U_DmaIbFifo0 : entity surf.AxiStreamFifoV2
     generic map (
       TPD_G               => TPD_G,
       SLAVE_AXI_CONFIG_G  => DMA_AXIS_CONFIG_G,
       MASTER_AXI_CONFIG_G => DMA_AXIS_CONFIG_G )
     port map (
       sAxisClk     => hdwClk,
       sAxisRst     => hdwRst,
       sAxisMaster  => pgpIbMasters(0),
       sAxisSlave   => pgpIbSlaves (0) ,
       sAxisCtrl    => open  ,
       mAxisClk     => dmaClk,
       mAxisRst     => dmaRst,
       mAxisMaster  => dmaIbMasters(0),
       mAxisSlave   => dmaIbSlaves (0) );
      
   U_AxiLite : entity surf.AxiLiteRegs
     generic map (
       TPD_G           => TPD_G,
       NUM_WRITE_REG_G => 2,
       NUM_READ_REG_G  => 8 )
     port map (
       axiClk         => axilClk,
       axiClkRst      => axilRst,
       axiWriteMaster => axilWriteMasters(ASS_INDEX_C),
       axiWriteSlave  => axilWriteSlaves (ASS_INDEX_C),
       axiReadMaster  => axilReadMasters (ASS_INDEX_C),
       axiReadSlave   => axilReadSlaves  (ASS_INDEX_C),
       writeRegister  => axilRegs,
       readRegister   => monRegsSync );

   GEN_SYNCWR : for i in 0 to 1 generate
     U_SyncReg : entity surf.SynchronizerVector
       generic map (
         TPD_G         => TPD_G,
         WIDTH_G       => 32 )
       port map (
         clk        => hdwClk,
         dataIn     => axilRegs    (i),
         dataOut    => axilRegsSync(i) );
   end generate GEN_SYNCWR;
   
   GEN_SYNCRD : for i in 0 to 7 generate
     U_SyncReg : entity surf.SynchronizerVector
       generic map (
         TPD_G         => TPD_G,
         WIDTH_G       => 32 )
       port map (
         clk        => axilClk,
         dataIn     => monRegs    (i),
         dataOut    => monRegsSync(i) );
   end generate GEN_SYNCRD;
   
   U_FWD : entity work.AxiStreamSwitch
     generic map (
       TPD_G           => TPD_G,
       NUM_SLAVES_G    => 8 )
     port map (
       axisClk         => hdwClk,
       axisRst         => hdwRst,
       saxisMasters    => swMasters,
       saxisSlaves     => swSlaves,
       maxisMaster     => appObMaster,
       maxisSlave      => appObSlave,
       forward         => axilRegsSync(0)(2 downto 0),
       monRegs         => monRegs(3 downto 0));

  U_SLICE : entity work.AxiStreamSlice
    generic map (
      TPD_G           => TPD_G,
      AXIS_CONFIG_G   => DMA_AXIS_CONFIG_G,
      AXI_BASE_ADDR_G => (others=>'0') )
    port map (
      axisClk         => hdwClk,
      axisRst         => hdwRst,
      saxisMaster     => appObMaster,
      saxisSlave      => appObSlave,
      maxisMaster     => pgpObMasters(0),
      maxisSlave      => pgpObSlaves (0),
      start           => axilRegsSync(1)(15 downto 0),
      monRegs         => monRegs(7 downto 4));

end top_level;
