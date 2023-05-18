-------------------------------------------------------------------------------
-- File       : AxiStreamSwitch.vhd
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
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiStreamSwitch is
   generic (
      TPD_G                : time                        := 1 ns;
      NUM_SLAVES_G         : integer                     := 8;
      SLAVE0_INDEX_G       : integer                     := 0
      );
   port (
     axisClk      : in  sl;
     axisRst      : in  sl;
     saxisMasters : in  AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
     saxisSlaves  : out AxiStreamSlaveArray (NUM_SLAVES_G-1 downto 0);
     maxisMaster  : out AxiStreamMasterType;
     maxisSlave   : in  AxiStreamSlaveType;
     forward      : in  slv(2 downto 0);
     monRegs      : out Slv32Array(3 downto 0)
     );
end AxiStreamSwitch;

architecture behavior of AxiStreamSwitch is

  constant NB : integer := bitSize(NUM_SLAVES_G-1);
  
  type StateType is ( IDLE_S, MOVE_S, FLUSH_S );

  type RegType is record
    forward : slv(NB-1 downto 0);
    monRegs : Slv32Array(3 downto 0);
    state   : StateType;
    master  : AxiStreamMasterType;
    slaves  : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    forward  => (others=>'0'),
    monRegs  => (others=>(others=>'0')),
    state    => IDLE_S,
    master   => AXI_STREAM_MASTER_INIT_C,
    slaves   => (others=>AXI_STREAM_SLAVE_INIT_C)
    );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

  comb : process ( r, axisRst, saxisMasters, maxisSlave, forward ) is
    variable v    : RegType;
    variable ifwd : integer range 0 to NUM_SLAVES_G-1;
  begin
      v := r;

      v.monRegs(0) := resize(r.forward,32);
      v.slaves := (others=>AXI_STREAM_SLAVE_FORCE_C);
      ifwd     := conv_integer(r.forward)-SLAVE0_INDEX_G;
      
      if maxisSlave.tReady = '1' then
        v.master.tValid := '0';
      end if;

      case r.state is
           
        when IDLE_S =>
          v.monRegs(1) := toSlv(0,32);
          v.forward := forward;
          if conv_integer(v.forward) < SLAVE0_INDEX_G then
            null;
          else
            ifwd := conv_integer(v.forward)-SLAVE0_INDEX_G;
            v.slaves(ifwd) := AXI_STREAM_SLAVE_INIT_C;
            if saxisMasters(ifwd).tValid = '1' then
              v.monRegs(2) := r.monRegs(2)+1;
              v.state := MOVE_S;
            end if;
          end if;
               
        when MOVE_S =>
          v.monRegs(1) := toSlv(1,32);
          if v.master.tValid = '0' then
            v.monRegs(3) := r.monRegs(3)+1;
            v.master       := saxisMasters(ifwd);
            -- Forward until we see tlast
            if saxisMasters(ifwd).tValid = '1' and saxisMasters(ifwd).tLast = '1' then
              v.state := IDLE_S;
            end if;
          else
            v.slaves(ifwd) := AXI_STREAM_SLAVE_INIT_C;
          end if;
               
        -- Flushing data
        when FLUSH_S =>
          v.monRegs(1) := toSlv(2,32);
          -- Dump until we see tlast
          if saxisMasters(ifwd).tValid = '1' and saxisMasters(ifwd).tLast = '1' then
            v.state := IDLE_S;
          end if;

        when others =>
          v.state := IDLE_S;
      end case;

      saxisSlaves <= v.slaves;

      if axisRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;

      maxisMaster <= r.master;
      monRegs     <= r.monRegs;
      
   end process comb;

   seq : process (axisClk) is
   begin
      if rising_edge(axisClk) then
         r <= rin;
      end if;
   end process seq;
   
end behavior;
