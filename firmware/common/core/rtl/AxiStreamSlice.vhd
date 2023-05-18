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

  type StateType is ( IDLE_S, SKIP_S, SEND_S );

  type RegType is record
    word    : slv(11 downto 0);
    monRegs : Slv32Array(3 downto 0);
    state   : StateType;
    master  : AxiStreamMasterType;
    slave   : AxiStreamSlaveType;
    tId     : slv(7 downto 0);
    tDest   : slv(7 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    word     => (others=>'0'),
    monRegs  => (others=>(others=>'0')),
    state    => IDLE_S,
    master   => AXI_STREAM_MASTER_INIT_C,
    slave    => AXI_STREAM_SLAVE_INIT_C,
    tId      => (others=>'0'),
    tDest    => (others=>'0')
    );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

  signal shiftstart : sl;
  signal startbyte : slv( 3 downto 0);
  signal startword : slv(11 downto 0);
  constant WORD_BITS_C : integer := log2(AXIS_CONFIG_G.TDATA_BYTES_C);

  signal taxisMaster : AxiStreamMasterType;
  signal taxisSlave  : AxiStreamSlaveType;
  
begin

  shiftstart <= not saxisMaster.tValid;
  startbyte  <= resize(start(WORD_BITS_C downto 0),startbyte'length);
  startword  <= resize(start(start'left downto WORD_BITS_C),startword'length);
  
  U_Shift : entity surf.AxiStreamShift
    generic map (
      TPD_G          => TPD_G,
      AXIS_CONFIG_G  => AXIS_CONFIG_G,
      PIPE_STAGES_G  => 1 )
--      ADD_VALID_EN_G : boolean               := false;
   port map (
      -- Clock and reset
      axisClk     => axisClk,
      axisRst     => axisRst,
      -- Start control
      axiStart    => shiftstart,
      axiShiftDir => '1', -- right
      axiShiftCnt => startbyte,
      -- Slave
      sAxisMaster => saxisMaster,
      sAxisSlave  => saxisSlave,
      -- Master
      mAxisMaster => taxisMaster,
      mAxisSlave  => taxisSlave );
  
  comb : process ( r, axisRst, taxisMaster, maxisSlave, startword ) is
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
          if taxisMaster.tValid = '1' and v.master.tValid = '0' then
            v.monRegs(1)      := r.monRegs(1)+1;
            v.slave.tReady    := '1';
            v.master          := taxisMaster;
            v.master.tValid   := '0';
            if startword = 0 then
              v.master.tValid := '1';
              v.monRegs(2)    := r.monRegs(2)+1;
              if taxisMaster.tLast = '0' then
                v.state       := SEND_S;
              end if;
            else
              v.tId           := taxisMaster.tId;
              v.tDest         := taxisMaster.tDest;
              v.word          := toSlv(1,12);
              v.state         := SKIP_S;
            end if;
          end if;

        when SKIP_S =>
          v.monRegs(0) := toSlv(1,32);
          if taxisMaster.tValid = '1' and v.master.tValid = '0' then
            v.slave.tReady    := '1';
            v.master          := taxisMaster;
            v.master.tValid   := '0';
            v.master.tId      := r.tId;
            v.master.tDest    := r.tDest;
            v.word            := r.word+1;
            if r.word = startword then
              v.master.tValid := '1';
              v.monRegs(2)    := r.monRegs(2)+1;
              if taxisMaster.tLast = '1' then
                v.state       := IDLE_S;
              else
                v.state       := SEND_S;
              end if;
            end if;
          end if;

        when SEND_S =>
          v.monRegs(0) := toSlv(2,32);
          if taxisMaster.tValid = '1' and v.master.tValid = '0' then
            v.slave.tReady    := '1';
            v.master          := taxisMaster;
            v.master.tValid   := '1';
            v.monRegs(2)      := r.monRegs(2)+1;
            if taxisMaster.tLast = '1' then
              v.state         := IDLE_S;
            end if;
          end if;
          
        when others =>
          v.monRegs(0) := toSlv(3,32);
          v.state := IDLE_S;
      end case;

      taxisSlave <= v.slave;

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
