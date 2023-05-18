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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AxiStreamListener is
   generic (
      TPD_G           : time                        := 1 ns;
      AXIS_CONFIG_G   : AxiStreamConfigType         := ssiAxiStreamConfig(dataBytes => 16, tDestBits => 8, tIdBits => 3) );  --- 16 Byte (128-bit) tData interface
   port (
    saxisClk          : in  sl;
    saxisRst          : in  sl;
    saxisObMasters    : in  AxiStreamMasterArray(7 downto 0);
    saxisObSlaves     : out AxiStreamSlaveArray (7 downto 0);
    saxisIbMasters    : out AxiStreamMasterArray(7 downto 0);
    saxisIbSlaves     : in  AxiStreamSlaveArray (7 downto 0);

    maxisClk          : in  sl;
    maxisRst          : in  sl;
    maxisObMasters    : out AxiStreamMasterArray(7 downto 0);
    maxisObSlaves     : in  AxiStreamSlaveArray (7 downto 0);
    maxisIbMasters    : in  AxiStreamMasterArray(7 downto 0);
    maxisIbSlaves     : out AxiStreamSlaveArray (7 downto 0);

    axilClk           : in  sl;
    axilRst           : in  sl;
    axilWriteMaster   : in  AxiLiteWriteMasterType;
    axilWriteSlave    : out AxiLiteWriteSlaveType;
    axilReadMaster    : in  AxiLiteReadMasterType;
    axilReadSlave     : out AxiLiteReadSlaveType
 );
end AxiStreamListener;

architecture rtl of AxiStreamListener is

   signal ibMasters       : AxiStreamMasterArray(7 downto 0);
   signal ibSlaves        : AxiStreamSlaveArray (7 downto 0);
   signal tmMasters       : AxiStreamMasterArray(7 downto 0);
   signal tmSlaves        : AxiStreamSlaveArray (7 downto 0);
   signal tsMasters       : AxiStreamMasterArray(7 downto 0);
   signal tsSlaves        : AxiStreamSlaveArray (7 downto 0);

   constant NSW_C : integer := 2;
   type RpMasterArray is array(natural range<>) of AxiStreamMasterArray(2 downto 0);
   type RpSlaveArray  is array(natural range<>) of AxiStreamSlaveArray (2 downto 0);
   type SwMasterArray is array(natural range<>) of AxiStreamMasterArray(7 downto NSW_C);
   type SwSlaveArray  is array(natural range<>) of AxiStreamSlaveArray (7 downto NSW_C);
   signal rpMasters       : RpMasterArray(7 downto 0);
   signal rpSlaves        : RpSlaveArray (7 downto 0);
   signal swMasters       : SwMasterArray(NSW_C-1 downto 0);
   signal swSlaves        : SwSlaveArray (NSW_C-1 downto 0);
   signal appObMaster     : AxiStreamMasterArray(NSW_C-1 downto 0);
   signal appObSlave      : AxiStreamSlaveArray (NSW_C-1 downto 0);
   signal axilRegs        : Slv32Array(2*NSW_C-1 downto 0);
   signal axilRegsSync    : Slv32Array(2*NSW_C-1 downto 0);
   signal monRegs         : Slv32Array(8*NSW_C-1 downto 0);
   signal monRegsSync     : Slv32Array(8*NSW_C-1 downto 0);

begin

   GEN_LANE : for lane in 7 downto NSW_C generate
     
      U_Tap : entity surf.AxiStreamTap
         generic map (
            TPD_G          => TPD_G,
            TAP_DEST_G     => 1 )  -- event data
         port map (
            sAxisMaster    => maxisIbMasters(lane),
            sAxisSlave     => maxisIbSlaves (lane),
            mAxisMaster    => ibMasters(lane),
            mAxisSlave     => ibSlaves (lane),
            tmAxisMaster   => tmMasters   (lane),
            tmAxisSlave    => tmSlaves    (lane),
            tsAxisMaster   => tsMasters   (lane),
            tsAxisSlave    => tsSlaves    (lane),
            axisClk        => maxisClk,
            axisRst        => maxisRst );

      U_REPEAT : entity surf.AxiStreamRepeater
        generic map (
          TPD_G               => TPD_G,
          NUM_MASTERS_G       => 3,
          INPUT_PIPE_STAGES_G => 1,
          OUTPUT_PIPE_STAGES_G => 1
          )
        port map (
          axisClk      => maxisClk,
          axisRst      => maxisRst,
          sAxisMaster  => tmMasters(lane),
          sAxisSlave   => tmSlaves (lane),
          mAxisMasters => rpMasters(lane),
          mAxisSlaves  => rpSlaves (lane) );
      
      U_RELIEF : entity work.AxiStreamRelief
        generic map (
          TPD_G         => TPD_G,
          AXIS_CONFIG_G => AXIS_CONFIG_G
         )
        port map (
          axiClk      => maxisClk,
          axiRst      => maxisRst,
          saxisMaster => rpMasters(lane)(0),
          saxisSlave  => rpSlaves (lane)(0),
          maxisMaster => tsMasters(lane),
          maxisSlave  => tsSlaves (lane) );

      U_SaxisIbFifo : entity surf.AxiStreamFifoV2
        generic map (
          TPD_G               => TPD_G,
          SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
          MASTER_AXI_CONFIG_G => AXIS_CONFIG_G )
        port map (
          sAxisClk     => maxisClk,
          sAxisRst     => maxisRst,
          sAxisMaster  => ibMasters(lane),
          sAxisSlave   => ibSlaves (lane) ,
          sAxisCtrl    => open  ,
          mAxisClk     => saxisClk,
          mAxisRst     => saxisRst,
          mAxisMaster  => saxisIbMasters(lane),
          mAxisSlave   => saxisIbSlaves (lane) );
      
      U_SaxisObFifo : entity surf.AxiStreamFifoV2
        generic map (
          TPD_G               => TPD_G,
          SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
          MASTER_AXI_CONFIG_G => AXIS_CONFIG_G )
        port map (
          sAxisClk     => saxisClk,
          sAxisRst     => saxisRst,
          sAxisMaster  => saxisObMasters(lane),
          sAxisSlave   => saxisObSlaves (lane) ,
          sAxisCtrl    => open  ,
          mAxisClk     => maxisClk,
          mAxisRst     => maxisRst,
          mAxisMaster  => maxisObMasters(lane),
          mAxisSlave   => maxisObSlaves (lane) );

      GEN_SW : for sw in NSW_C-1 downto 0 generate
        swMasters(sw)(lane)    <= rpMasters(lane)(sw+1);
        rpSlaves (lane)(sw+1)  <= swSlaves (sw)(lane);
      end generate GEN_SW;
      
   end generate GEN_LANE;

   -- saxisObMasters(0) is sunk
   saxisObSlaves (0) <= AXI_STREAM_SLAVE_INIT_C;

   U_SaxisIbFifo0 : entity surf.AxiStreamFifoV2
     generic map (
       TPD_G               => TPD_G,
       SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
       MASTER_AXI_CONFIG_G => AXIS_CONFIG_G )
     port map (
       sAxisClk     => maxisClk,
       sAxisRst     => maxisRst,
       sAxisMaster  => maxisIbMasters(0),
       sAxisSlave   => maxisIbSlaves (0) ,
       sAxisCtrl    => open  ,
       mAxisClk     => saxisClk,
       mAxisRst     => saxisRst,
       mAxisMaster  => saxisIbMasters(0),
       mAxisSlave   => saxisIbSlaves (0) );
      
   U_AxiLite : entity surf.AxiLiteRegs
     generic map (
       TPD_G           => TPD_G,
       NUM_WRITE_REG_G => axilRegs'length,
       NUM_READ_REG_G  => monRegsSync'length )
     port map (
       axiClk         => axilClk,
       axiClkRst      => axilRst,
       axiWriteMaster => axilWriteMaster,
       axiWriteSlave  => axilWriteSlave,
       axiReadMaster  => axilReadMaster,
       axiReadSlave   => axilReadSlave,
       writeRegister  => axilRegs,
       readRegister   => monRegsSync );

   GEN_SYNCWR : for i in axilRegs'range generate
     U_SyncReg : entity surf.SynchronizerVector
       generic map (
         TPD_G         => TPD_G,
         WIDTH_G       => 32 )
       port map (
         clk        => maxisClk,
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

   GEN_SW : for sw in NSW_C-1 downto 0 generate
--     swMasters(sw)(NSW_C-1 downto 0) <= (others=>AXI_STREAM_MASTER_INIT_C);
--     swSlaves (sw)(NSW_C-1 downto 0) <= (others=>AXI_STREAM_SLAVE_FORCE_C);
     tmMasters(sw) <= AXI_STREAM_MASTER_INIT_C;
     tmSlaves (sw) <= AXI_STREAM_SLAVE_FORCE_C;
   
     U_FWD : entity work.AxiStreamSwitch
       generic map (
         TPD_G           => TPD_G,
         NUM_SLAVES_G    => 8-NSW_C,
         SLAVE0_INDEX_G  => NSW_C  )
       port map (
         axisClk         => maxisClk,
         axisRst         => maxisRst,
         saxisMasters    => swMasters  (sw),
         saxisSlaves     => swSlaves   (sw),
         maxisMaster     => appObMaster(sw),
         maxisSlave      => appObSlave (sw),
         forward         => axilRegsSync(2*sw+0)(2 downto 0),
         monRegs         => monRegs(8*sw+3 downto 8*sw+0));

     U_SLICE : entity work.AxiStreamSlice
       generic map (
         TPD_G           => TPD_G,
         AXIS_CONFIG_G   => AXIS_CONFIG_G,
         AXI_BASE_ADDR_G => (others=>'0') )
       port map (
         axisClk         => maxisClk,
         axisRst         => maxisRst,
         saxisMaster     => appObMaster   (sw),
         saxisSlave      => appObSlave    (sw),
         maxisMaster     => maxisObMasters(sw),
         maxisSlave      => maxisObSlaves (sw),
         start           => axilRegsSync(2*sw+1)(15 downto 0),
         monRegs         => monRegs(8*sw+7 downto 8*sw+4));
   end generate GEN_SW;
   
end architecture rtl;
