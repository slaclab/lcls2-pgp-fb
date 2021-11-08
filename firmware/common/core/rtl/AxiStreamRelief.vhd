-------------------------------------------------------------------------------
-- File       : AxiStreamRelief.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:  Prevents backpressure on axi-stream by forwarding when
-- the downstream fifo has space and sinking when it doesnt.
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

library unisim;
use unisim.vcomponents.all;

entity AxiStreamRelief is
   generic (
      TPD_G                : time                        := 1 ns;
      AXIS_CONFIG_G        : AxiStreamConfigType         := ssiAxiStreamConfig(dataBytes => 16, tDestBits => 8, tIdBits => 3);  --- 16 Byte (128-bit) tData interface
      FIFO_PAUSE_THRESH_G  : integer                     := 256 );
   port (
     axiClk      : in  sl;
     axiRst      : in  sl;
     
     saxisMaster : in  AxiStreamMasterType;
     saxisSlave  : out AxiStreamSlaveType;

     maxisMaster : out AxiStreamMasterType;
     maxisSlave  : in  AxiStreamSlaveType
     );
end AxiStreamRelief;

architecture behavior of AxiStreamRelief is

  signal fifoMaster : AxiStreamMasterType;
  signal fifoSlave  : AxiStreamSlaveType;
  signal fifoCtrl   : AxiStreamCtrlType;
  
  type StateType is ( IDLE_S, MOVE_S, FLUSH_S );

  type RegType is record
    state  : StateType;
    master : AxiStreamMasterType;
    slave  : AxiStreamSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    state    => IDLE_S,
    master   => axiStreamMasterInit(AXIS_CONFIG_G),
    slave    => AXI_STREAM_SLAVE_INIT_C
    );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin
  
  U_FIFO : entity surf.AxiStreamFifoV2
    generic map (
      TPD_G               => TPD_G,
      GEN_SYNC_FIFO_G     => true,
      FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
      SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
      MASTER_AXI_CONFIG_G => AXIS_CONFIG_G )
    port map (
      sAxisClk     => axiClk,
      sAxisRst     => axiRst,
      sAxisMaster  => fifoMaster,
      sAxisSlave   => fifoSlave ,
      sAxisCtrl    => fifoCtrl  ,
      mAxisClk     => axiClk,
      mAxisRst     => axiRst,
      mAxisMaster  => maxisMaster,
      mAxisSlave   => maxisSlave );
      
  comb : process ( r, axiRst, saxisMaster, fifoSlave, fifoCtrl ) is
      variable v : RegType;
   begin
      v := r;

      v.slave.tReady := '0';

      if fifoSlave.tReady = '1' then
        v.master.tValid := '0';
      end if;

      case r.state is
           
        when IDLE_S =>
          if saxisMaster.tValid = '1' then
            if fifoCtrl.pause = '1' then
              v.state := FLUSH_S;
            else
              v.state := MOVE_S;
            end if;
          end if;
               
        when MOVE_S =>
          if v.master.tValid = '0' then
            v.slave.tReady := '1';
            v.master := saxisMaster;
            -- Forward until we see tlast
            if saxisMaster.tValid = '1' and saxisMaster.tLast = '1' then
              v.state := IDLE_S;
            end if;
          end if;
               
        -- Flushing data
        when FLUSH_S =>
          -- Dump until we see tlast
          v.slave.tReady := '1';
          if saxisMaster.tValid = '1' and saxisMaster.tLast = '1' then
            v.state := IDLE_S;
          end if;

        when others =>
          v.state := IDLE_S;
      end case;

      saxisSlave <= v.slave;

      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;

      fifoMaster <= r.master;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin;
      end if;
   end process seq;
   
end behavior;
