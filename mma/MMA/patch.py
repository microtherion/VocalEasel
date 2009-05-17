# patch.py

"""
This module is an integeral part of the program
MMA - Musical Midi Accompaniment.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Bob van der Poel <bob@mellowood.ca>

This module contains the various patch manger routines.

"""

from MMA.common import *
from MMA.miditables import *
import MMA.file
import MMA.midiC

def patch(ln):
    """ Main routine to manage midi patch names. """

    for i,a in enumerate(ln):
        
        if a.count('=') == 1:
            a,b = a.split('=')
        else:
            b=''
        a=a.upper()

        if a == "LIST":
            b=b.upper()
            if b == "ALL":
                plistall()
            elif b == "EXT":
                plistext()
            elif b == "GM":
                plistgm()
            else:
                error("Expecting All, EXT or GM argument for List")

        if a == "RENAME":
            prename(ln[i+1:])
            break

        if a == 'SET':
            patchset(ln[i+1:])
            break

        error("Unknown option for Patch: %s" % a)

# Set a patch value=name

def patchset(ln):
    if not ln:
        error("Patch Set expecting list of value pairs.")

    for a in ln:
        
        try:
            v,n = a.split('=', 1)
        except:
            error("Patch Set expecting value=name pair, not: %s" % a)
        
        v=v.split('.')
        if len(v) > 3 or len(v) < 1:
            error("Patch Set: Expecting a voice value Prog.MSB.LSB." )

        voc = 0
        if len(v) > 2:    # ctrl32
            i = stoi(v[2], "Patch Set LSB expecting integer.")
            if i<0 or i>127:
                error("LSB must be 0..127, not '%s'." % i)
            voc = i << 16

        if len(v) > 1:    # ctrl0
            i = stoi(v[1], "Patch Set MSB expecting integer.")
            if i<0 or i>127:
                error("MSB must be 0..127, not '%s'." % i)
            voc += i << 8

        i = stoi(v[0], "Patch Set Voice expecting integer.")
        if i<0 or i>127:
            error("Program must be 0..127, not '%s'." % i)
        voc += i
    
        if voc in voiceNames:
            warning("Patch Set duplicating voice name %s with %s=%s" % \
                      (voiceNames[voc], n, MMA.midiC.extVocStr(voc) ))
        if n.upper() in voiceInx:
            warning("Patch Set duplicating voice value %s with %s=%s" % \
                     (MMA.midiC.extVocStr(voiceInx[n.upper()]),
                      MMA.midiC.extVocStr(voc), n) )
        voiceNames[voc]=n
        voiceInx[n.upper()]=voc


        
# Rename

def prename(ln):
    if not ln:
        error("Patch Rename expecting list of value pairs.")

    for a in ln:
        if not a.count("=") == 1:
            error("Patch Rename expecting oldname=newname pair")

        a,b = a.split("=")

        if not a.upper() in voiceInx:
            error("Patch %s doen't exist, can't be renamed." % a)

        if b.upper() in voiceInx:
            error("Patch name %s already exists" % b)

        v = voiceInx[a.upper()]
        voiceNames[v]=b
        del voiceInx[a.upper()]
        voiceInx[b.upper()]=v

# list funcs

def plistgm():
    for v in sorted(voiceNames.keys()):
        if v <= 127:
            print "%s=%s" % (MMA.midiC.extVocStr(v), voiceNames[v] )

def plistall():
    plistgm()
    plistext()

def plistext():
    for v in sorted(voiceNames.keys()):
        if v>127:
            print "%s=%s" % (MMA.midiC.extVocStr(v), voiceNames[v])
