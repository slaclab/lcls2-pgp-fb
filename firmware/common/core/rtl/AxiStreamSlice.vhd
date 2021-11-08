-------------------------------------------------------------------------------
-- File       : AxiStreamSlice.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:  Application specific module for pruning data from 
-- the stream before forwarding to the laser locker application
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

entity AxiStreamSlice is
   generic (
      TPD_G                : time                        := 1 ns;
      AXIS_CONFIG_G        : AxiStreamConfigType;
      AXI_BASE_ADDR_G      : slv(31 downto 0)            := (others=>'0')
      );
   port (
     axisClk         : in  sl;
     axisRst         : in  sl;
     saxisMaster     : in  AxiStreamMasterType;
     saxisSlave      : out AxiStreamSlaveType;
     maxisMaster     : out AxiStreamMasterType;
     maxisSlave      : in  AxiStreamSlaveType;
     start           : in  slv(15 downto 0);
     monRegs         : out Slv32Array(3 downto 0)
     );
end AxiStreamSlice;

architecture behavior of AxiStreamSlice is

  constant NBYTES_C : integer := 8;
  
  type StateType is ( IDLE_S, FIRST_S, SECOND_S, FLUSH_S );

  type RegType is record
    start   : slv(15 downto 0);
    remain  : slv( 3 downto 0);
    monRegs : Slv32Array(3 downto 0);
    state   : StateType;
    master  : AxiStreamMasterType;
    slave   : AxiStreamSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    start    => (others=>'0'),
    remain   => (others=>'0'),
    monRegs  => (others=>(others=>'0')),
    state    => IDLE_S,
    master   => AXI_STREAM_MASTER_INIT_C,
    slave    => AXI_STREAM_SLAVE_INIT_C
    );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

  comb : process ( r, axisRst, saxisMaster, maxisSlave, start ) is
    variable v    : RegType;
    variable i    : integer;
  begin
      v := r;

      v.slave.tReady := '0';
      
      if maxisSlave.tReady = '1' then
        v.master.tValid := '0';
      end if;

      case r.state is
           
        when IDLE_S =>
          v.monRegs(0) := toSlv(0,32);
          if saxisMaster.tValid = '1' and v.master.tValid = '0' then
            v.monRegs(1) := r.monRegs(1)+1;
            v.slave.tReady := '1';
            v.master := saxisMaster;
            v.master.tValid := '0';
            i := conv_integer(start);
            if i < AXIS_CONFIG_G.TDATA_BYTES_C then
              v.master.tData(8*NBYTES_C-1 downto 0) := saxisMaster.tData(8*(i+NBYTES_C)-1 downto 8*i);
              if i + NBYTES_C <= AXIS_CONFIG_G.TDATA_BYTES_C then
                v.monRegs(2) := r.monRegs(2)+1;
                v.master.tValid := '1';
                v.master.tLast  := '1';
                v.state         := FLUSH_S;
              else
                v.remain := toSlv(i + NBYTES_C - AXIS_CONFIG_G.TDATA_BYTES_C,v.remain'length);
                v.state  := SECOND_S;
              end if;
            else
              v.start := toSlv(i - AXIS_CONFIG_G.TDATA_BYTES_C, 16);
              v.state := FIRST_S;
            end if;
          end if;

        when FIRST_S =>
          v.monRegs(0) := toSlv(1,32);
          if saxisMaster.tValid = '1' then
            v.slave.tReady := '1';
            i := conv_integer(r.start);
            if i < AXIS_CONFIG_G.TDATA_BYTES_C then
              v.master.tData(8*NBYTES_C-1 downto 0) := saxisMaster.tData(8*(i+NBYTES_C)-1 downto 8*i);
              if i + NBYTES_C <= AXIS_CONFIG_G.TDATA_BYTES_C then
                v.monRegs(2) := r.monRegs(2)+1;
                v.master.tValid := '1';
                v.master.tLast  := '1';
                v.state := FLUSH_S;
                if saxisMaster.tLast = '1' then
                  v.state := IDLE_S;
                end if;
              else
                v.remain := toSlv(i + NBYTES_C - AXIS_CONFIG_G.TDATA_BYTES_C,v.remain'length);
                v.state  := SECOND_S;
              end if;
            else
              v.start := toSlv(i - AXIS_CONFIG_G.TDATA_BYTES_C, 16);
              v.state := FIRST_S;
            end if;
          end if;
            
        when SECOND_S =>
          v.monRegs(0) := toSlv(2,32);
          if saxisMaster.tValid = '1' then
            v.slave.tReady := '1';
            i := conv_integer(r.remain);
            v.master.tData(8*NBYTES_C-1 downto 8*(NBYTES_C-i)) := saxisMaster.tData(8*i-1 downto 0);
            v.monRegs(2) := r.monRegs(2)+1;
            v.master.tValid := '1';
            v.master.tLast  := '1';
            v.state         := FLUSH_S;
            if saxisMaster.tLast = '1' then
              v.state := IDLE_S;
            end if;
          end if;
            
        -- Flushing data
        when FLUSH_S =>
          -- Dump until we see tlast
          v.monRegs(0) := toSlv(3,32);
          v.slave.tReady := '1';
          if saxisMaster.tValid = '1' and saxisMaster.tLast = '1' then
            v.state := IDLE_S;
          end if;

        when others =>
          v.monRegs(0) := toSlv(4,32);
          v.state := IDLE_S;
      end case;

      saxisSlave <= v.slave;

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
