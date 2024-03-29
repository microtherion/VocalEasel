# globals.py

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

"""

import os

version = "1.7"        # Version -- Nov/2010

""" A few globals are actually set in the calling stub, mma.py.This is
    done to make future ports and platform specific settings a bit easier.
    The following variables are imported from mma.py and stored here:

        platform   - host platform, Windows, Linux, etc.
        MMAdir     - the home directory for mma stuff

    The above variables can be accessed from the rest of the mma modules in
    the form "gbl.MMAdir", etc. 
"""

from __main__ import MMAdir, platform

""" mtrks is storage for the MIDI data as it is created.
    It is a dict of class Mtrk() instances. Keys are the
    midi channel numbers. Ie, mtrks[2]    is for channel 2,
    etc. mtrks[0] is for the meta stuff.
"""

mtrks = {}

""" tnames is a dict of assigned track names. The keys are
    the track names; each entry is a pattern class instance.
    We have tnames['BASS-FOO'], etc.
"""

tnames = {}

""" midiAssigns keeps track of channel/track assignments. The keys
    are midi channels (1..16), the data is a list of tracks assigned
    to each channel. The tracks are only added, not deleted. Right
    now this is only used in -c reporting.
"""

midiAssigns={}
for c in range(0,17):
    midiAssigns[c]=[]

""" midiAvail is a list with each entry representing a MIDI channel.
    As channels are allocated/deallocated the appropriated slot
    is inc/decremented.
"""

midiAvail     = [ 0 ] * 17   # slots 0..16, slot 0 is not used.

deletedTracks = []    # list of deleted tracks for -c report

""" This is a user constructed list of names/channels. The keys
    are names, data is a channel. Eg. midiChPrefs['BASS-SUS']==9
"""

midiChPrefs = {}


""" Is the -T option is used only the tracks in this list
    are generated. All other tracks are muted (OFF)
"""

muteTracks = []


############# String constants ####################


ext = ".mma"        # extension for song/lib files.


##############  Tempo, and other midi positioning.  #############


BperQ       =  192    # midi ticks per quarter note
QperBar     =  4      # Beats/bar, set with TIME
tickOffset  =  0      # offset of current bar in ticks
tempo       =  120    # current tempo
seqSize     =  1      # variation sequence table size
seqCount    =  0      # running count of variation

totTime     = 0.0     # running duration count in seconds

transpose   =  0      # Transpose is global (ignored by drum tracks)

lineno      = -1      # used for error reporting

barNum      =  0      # Current line number

barPtrs     = {}      # for each bar, pointers to event start/end

synctick    =  0      # flag, set if we want a tick on all tracks at offset 0
endsync     =  0      # flag, set if we want a eof sync


#############   Path and search variables. #############
# In mma.py we checked for known directories and inserted the
# first found 'mma' directory into the sys.path list and set MMAdir.
# Assume that this is where the rest of mma's configuration file
# live. If mma runs but can't fine includes, etc. look in mma.py
# and add the proper paths.


libPath = os.path.join(MMAdir, 'lib')
if not os.path.isdir(libPath):
    print "Warning: Library directory not found."

incPath = os.path.join(MMAdir, 'includes')
if not os.path.isdir(incPath):
    print "Warning: Include directory not found."

# Set up autolib defaults. We start with MMALIB/stdlib and append
# any other directories we find in MMALIB. Note, the order of
# libs after stdlib is alphabetical.
# User can change the libs with SetAutoLibPath dir1 dir2 etc.

autoLib=['stdlib']
dirs = sorted(os.listdir(libPath))
for d in dirs:
    if os.path.isdir(os.path.join(libPath, d)) and d not in autoLib:
        autoLib.append(d)


outPath    =   ''      # Directory for MIDI file
mmaStart   =   []      # list of START files
mmaEnd     =   []      # list of END files
mmaRC      =   None    # user specified RC file, overrides defaults
inpath     =   None    # input file

midiFileType   = 1     # type 1 file, SMF command can change to 0
runningStatus  = 1     # running status enabled


#############  Options. #############


""" These variables are all set from the command line in MMA.opts.py.
    It's a bit of an easy-way-out to have them all here, but I don't think
    it hurts too much.
"""

barRange       =     []      # both -B and -b use this

# the Lxxx values are the previous settings, used for LASTDEBUG macro

debug          =     Ldebug         = 0
pshow          =     Lpshow         = 0
seqshow        =     Lseqshow       = 0
showrun        =     Lshowrun       = 0
noWarn         =     LnoWarn        = 0
noOutput       =     LnoOutput      = 0
showExpand     =     LshowExpand    = 0
showFilenames  =     LshowFilenames = 0
chshow         =     Lchshow        = 0

plecShow       =     LplecShow  = 0  # not a command line setting
rmShow         =     LrmShow    = 0  # not command

outfile        =     None
infile         =     None
createDocs     =     0
maxBars        =     500
makeGrvDefs    =     0
cmdSMF         =     None

playFile       =     0       # set if we want to call a player


