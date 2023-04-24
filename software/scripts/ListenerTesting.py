#!/usr/bin/env python3
##############################################################################
## This file is part of 'PGP PCIe APP DEV'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'PGP PCIe APP DEV', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import sys
import rogue
import argparse

import rogue.hardware.axi
import rogue.interfaces.stream

import pyrogue as pr
import pyrogue.pydm
import pyrogue.utilities.prbs

import axipcie            as pcie
import surf.axi           as axi
import surf.protocols.pgp as pgp

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Convert str to bool
argBool = lambda s: s.lower() in ['true', 't', 'yes', '1']

# Add arguments
parser.add_argument(
    "--dev",
    type     = str,
    required = False,
    default  = '/dev/datadev_0',
    help     = "path to device",
)

parser.add_argument(
    "--numLane",
    type     = int,
    required = False,
    default  = 1,
    help     = "# of DMA Lanes",
)

parser.add_argument(
    "--numVc",
    type     = int,
    required = False,
    default  = 1,
    help     = "# of VC (virtual channels)",
)

parser.add_argument(
    "--version",
    type     = int,
    required = False,
    default  = 4,
    help     = "PGP Protocol Version",
)

parser.add_argument(
    "--swRx",
    type     = argBool,
    required = False,
    default  = True,
    help     = "Enable read all variables at start",
)

parser.add_argument(
    "--swTx",
    type     = argBool,
    required = False,
    default  = True,
    help     = "Enable read all variables at start",
)

parser.add_argument(
    "--prbsWidth",
    type     = int,
    required = False,
    default  = 256,
    help     = "# of DMA Lanes",
)

parser.add_argument(
    "--pollEn",
    type     = argBool,
    required = False,
    default  = True,
    help     = "Enable auto-polling",
)

parser.add_argument(
    "--initRead",
    type     = argBool,
    required = False,
    default  = True,
    help     = "Enable read all variables at start",
)

parser.add_argument(
    "--boardType",
    type     = str,
    required = False,
    default  = None,
    help     = "define the type of PCIe card, used to select I2C mapping. Options: [none or SlacPgpCardG4, Kcu1500, etc]",
)

# Get the arguments
args = parser.parse_args()

#################################################################

class Listener(pr.Device):
    def __init__(self, **kwargs):
      super().__init__(description='Listener', **kwargs)

      for i in range(6):
          self.add(pr.RemoteVariable(
              name        = f'Port{i+2}_FwdEnable',
              description = 'Enable forwarding',
              offset      = 0x108+4*i,
              bitSize     = 1,
              bitOffset   = 3,
              mode        = 'RW',
              base        = pr.UInt,
          ))
          self.add(pr.RemoteVariable(
              name        = f'Port{i+2}_FwdPort_Ctl',
              description = 'Port forwarding',
              offset      = 0x108+4*i,
              bitSize     = 3,
              bitOffset   = 0,
              mode        = 'RW',
              base        = pr.UInt,
          ))
          self.add(pr.RemoteVariable(
              name         = f'Port{i+2}_FwdPort_RO',
              offset       = 0x0+16*i,
              bitSize      = 4,
              bitOffset    = 0,
              mode         = 'RO',
              pollInterval = 1,
          ))

          self.add(pr.RemoteVariable(
              name         = f'Port{i+2}_FwdState',
              offset       = 0x4+16*i,
              bitSize      = 4,
              bitOffset    = 0,
              mode         = 'RO',
              pollInterval = 1,
          ))

          self.add(pr.RemoteVariable(
              name         = f'Port{i+2}_PacketsFwd',
              offset       = 0x8+16*i,
              bitSize      = 32,
              bitOffset    = 0,
              mode         = 'RO',
              pollInterval = 1,
          ))

          self.add(pr.RemoteVariable(
              name         = f'Port{i+2}_PacketsDrop',
              offset       = 0xc+16*i,
              bitSize      = 32,
              bitOffset    = 0,
              mode         = 'RO',
              pollInterval = 1,
          ))

      for i in range(2):
          self.add(pr.RemoteVariable(
              name        = f'Slice{i}_StartByte',
              description = 'Value starting byte',
              offset      = 0x100+4*i,
              bitSize     = 16,
              mode        = 'RW',
              base        = pr.UInt,
          ))
          self.add(pr.RemoteVariable(
              name        = f'Slice{i}_State',
              description = 'Stream Slice State',
              offset      = 0x60+16*i,
              bitSize     = 2,
              bitOffset   = 0,
              mode        = 'RO',
              base        = pr.UInt,
              pollInterval = 1,
          ))
          self.add(pr.RemoteVariable(
              name        = f'Slice{i}_Starts',
              description = 'Stream Slice Starts',
              offset      = 0x64+16*i,
              bitSize     = 32,
              bitOffset   = 0,
              mode        = 'RO',
              base        = pr.UInt,
              pollInterval = 1,
          ))
          self.add(pr.RemoteVariable(
              name        = f'Slice{i}_Ends',
              description = 'Stream Slice Ends',
              offset      = 0x68+16*i,
              bitSize     = 32,
              bitOffset   = 0,
              mode        = 'RO',
              base        = pr.UInt,
              pollInterval = 1,
          ))


#################################################################

class MyRoot(pr.Root):
    def __init__(   self,
            name        = "pciServer",
            description = "DMA Loopback Testing",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        # Create PCIE memory mapped interface
        self.memMap = rogue.hardware.axi.AxiMemMap(args.dev)

        if (args.swRx or args.swTx):
            self.dmaStream   = [[None for x in range(args.numVc)] for y in range(args.numLane)]
            self.prbsRx      = [[None for x in range(args.numVc)] for y in range(args.numLane)]
            self.prbsTx      = [[None for x in range(args.numVc)] for y in range(args.numLane)]

        # Add the PCIe core device to base
        self.add(pcie.AxiPcieCore(
            offset     = 0x00000000,
            memBase     = self.memMap,
            numDmaLanes = args.numLane,
            boardType   = args.boardType,
            expand      = True,
        ))

        # Add the ListenerApp registers
        self.add(Listener(
            name    = 'Listener',
            offset  = 0x00900000,
            memBase = self.memMap,
        ))

        # Add PGP Core
        for lane in range(args.numLane):
            if (args.version == 4):
                self.add(pgp.Pgp4AxiL(
                    name    = f'Lane[{lane}]',
                    offset  = (0x00800000 + lane*0x00010000),
                    memBase = self.memMap,
                    numVc   = args.numVc,
                    writeEn = True,
                    expand  = True,
                ))
            elif (args.version == 3):
                self.add(pgp.Pgp3AxiL(
                    name    = f'Lane[{lane}]',
                    offset  = (0x00800000 + lane*0x00010000),
                    memBase = self.memMap,
                    numVc   = args.numVc,
                    writeEn = True,
                    expand  = False,
                ))
            else:
                self.add(pgp.Pgp2bAxi(
                    name    = f'Lane[{lane}]',
                    offset  = (0x00800000 + lane*0x00010000 + 0x1000),
                    memBase = self.memMap,
                    expand  = False,
                ))

            self.add(axi.AxiStreamMonAxiL(
                name        = (f'PgpTxAxisMon[{lane}]'),
                offset      = (0x00800000 + lane*0x00010000 + 0x3000),
                numberLanes = args.numVc,
                memBase     = self.memMap,
                expand      = False,
            ))

            self.add(axi.AxiStreamMonAxiL(
                name        = (f'PgpRxAxisMon[{lane}]'),
                offset      = (0x00800000 + lane*0x00010000 + 0x4000),
                numberLanes = args.numVc,
                memBase     = self.memMap,
                expand      = False,
            ))

            # Loop through the virtual channels
            for vc in range(args.numVc):

                if (args.swRx or args.swTx):
                    self.dmaStream[lane][vc] = rogue.hardware.axi.AxiStreamDma(args.dev,(0x100*lane)+vc,1)

                if (args.swRx):

                    # Connect the SW PRBS Receiver module
                    self.prbsRx[lane][vc] = pr.utilities.prbs.PrbsRx(
                        name         = ('SwPrbsRx[%d][%d]'%(lane,vc)),
                        width        = args.prbsWidth,
                        checkPayload = True,
                        expand       = False,
                    )
                    self.dmaStream[lane][vc] >> self.prbsRx[lane][vc]
                    self.add(self.prbsRx[lane][vc])

                if (args.swTx):

                    # Connect the SW PRBS Transmitter module
                    self.prbsTx[lane][vc] = pr.utilities.prbs.PrbsTx(
                        name    = ('SwPrbsTx[%d][%d]'%(lane,vc)),
                        width   = args.prbsWidth,
                        expand  = False,
                    )
                    self.prbsTx[lane][vc] >> self.dmaStream[lane][vc]
                    self.add(self.prbsTx[lane][vc])

        @self.command()
        def EnableAllSwTx():
            swTxDevices = root.find(typ=pr.utilities.prbs.PrbsTx)
            for tx in swTxDevices:
                tx.txEnable.set(True)

        @self.command()
        def DisableAllSwTx():
            swTxDevices = root.find(typ=pr.utilities.prbs.PrbsTx)
            for tx in swTxDevices:
                tx.txEnable.set(False)

#################################################################

with MyRoot(pollEn=args.pollEn, initRead=args.initRead) as root:
     pyrogue.pydm.runPyDM(root=root)

#################################################################
