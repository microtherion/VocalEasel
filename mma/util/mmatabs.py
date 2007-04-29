#!/usr/bin/env python

# create tex files of the mma midi constants

import sys, os, commands

sys.path.insert(0, "/usr/local/share/mma/MMA/")
from miditables import *
from chordtable import chords

err, version = commands.getstatusoutput( "mma -v")
if err:
    print "Can't get MMA version ... strange error!"
    sys.ex

def dodrums(order):
    """ Print LaTex table of drum names. """

    notenames = ['E\\flat', 'E', 'F', 'G\\flat', 'G', 'A\\flat',
                 'A', 'B\\flat', 'B', 'C', 'D\\flat', 'D'] * 5

    n=zip( drumNames, range(27,len(drumNames)+27), notenames )

    if order == "a":
        for a,v,m in sorted(n):
            outfile.write ("\\insline{%s} {%s$^{%s}$}\n" % (a, v, m ))

    else:
        for a,v,m in n:
            outfile.write ("\\insline{%s} {%s$^{%s}$}\n" % (v, a, m))

def docrtls(order):
    """ Print LaTex table of MIDI controller names. """

    n=zip( ctrlNames, range(len(ctrlNames)) )

    if order == "a":
        for a,v in sorted(n):
            outfile.write ("\\insline{%s} {%02x}\n" % (a, v))

    else:
        for a,v in n:
            outfile.write("\\insline{%02x} {%s}\n" % (v, a))

def doinsts(order):
    """ Print LaTex table of instrument names. """

    n=zip( voiceNames, range(len(voiceNames)) )
    if order == "a":
        for a,v in sorted(n):
            a=a.replace('&', '\&')
            outfile.write("\\insline{%s} {%s}\n" % (a, v))

    else:
        for a,v in n:
            a=a.replace('&', '\&')
            outfile.write( "\\insline{%s} {%s}\n" % (v, a))

def dochords():
    """ Print out a list of chord names and docs in LaTex. """

    for n in sorted(chords.keys()):
        nm=n.replace("#", '$\\sharp$')
        nm=nm.replace('b', '$\\flat$')
        outfile.write( "\\insline{%s}{%s}\n" % (nm, chords[n][2]) )


for a,f,o in (
    ('m', docrtls, 'ctrlmidi.AUTO'),
    ('a', docrtls, 'ctrlalpha.AUTO'),
    ('m', dodrums, 'drumsmidi.AUTO'),
    ('a', dodrums, 'drumsalpha.AUTO'),
    ('m', doinsts, 'instmidi.AUTO'),
    ('a', doinsts, 'instalpha.AUTO') ):
        outfile = file(o, 'w')
        f(a)
        outfile.close()

outfile = file("chordnames.AUTO", 'w')
dochords()
outfile.close()

