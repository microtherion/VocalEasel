
# docs.py

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
import time

import MMA.midiC
import MMA.grooves

import gbl
from   MMA.common import *




def docDrumNames(order):
    """ Print LaTex table of drum names. """

    notenames = ['E\\flat', 'E', 'F', 'G\\flat', 'G', 'A\\flat',
                 'A', 'B\\flat', 'B', 'C', 'D\\flat', 'D'] * 5

    n=zip( MMA.midiC.drumNames, range(27,len(MMA.midiC.drumNames)+27), notenames )

    if order == "a":
        for a,v,m in sorted(n):
            print "\\insline{%s} {%s$^{%s}$}" % (a, v, m )

    else:
        for a,v,m in n:
            print "\\insline{%s} {%s$^{%s}$}" % (v, a, m)

def docCtrlNames(order):
    """ Print LaTex table of MIDI controller names. """

    n=zip( MMA.midiC.ctrlNames, range(len(MMA.midiC.ctrlNames)) )

    if order == "a":
        for a,v in sorted(n):
            print "\\insline{%s} {%02x}" % (a, v)

    else:
        for a,v in n:
            print "\\insline{%02x} {%s}" % (v, a)

def docInstNames(order):
    """ Print LaTex table of instrument names. """

    n=zip( MMA.midiC.voiceNames, range(len(MMA.midiC.voiceNames)) )
    if order == "a":
        for a,v in sorted(n):
            a=a.replace('&', '\&')
            print "\\insline{%s} {%s}" % (a, v)

    else:
        for a,v in n:
            a=a.replace('&', '\&')
            print "\\insline{%s} {%s}" % (v, a)


""" Whenever MMA encounters a DOC command, or if it defines
    a groove with DEFGROOVE it calls the docAdd() function.

    The saved docs are printed to stdout with the docDump() command.
    This is called whenever parse() encounters an EOF.

    Both routines are ignored if the -Dx command line option has
    not been set.

    Storage is done is in the following arrays.
"""

fname     = ''
author    = ""
notes     = ""
defs      = []
variables = []

def docAuthor(ln):
    global author

    author = ' '.join(ln)


def docNote(ln):
    """ Add a doc line. """

    global fname, notes

    if not gbl.createDocs or not ln:
        return

    # Grab the arg and data, save it

    fname = os.path.basename(gbl.inpath.fname)
    if notes:
        notes += ' '
    notes +=  ' '.join(ln)

def docVars(ln):
    """ Add a VARIABLE line (docs vars used in lib file)."""

    global fname, variables

    if not gbl.createDocs or not ln:
        return

    fname = os.path.basename(gbl.inpath.fname)
    variables.append([ln[0], ' '.join(ln[1:]) ] )


def docDefine(ln):
    """ Save a DEFGROOVE comment string.

        Entries are stored as a list. Each item in the list is
        complete groove def looking like:
        defs[ [ Name, Seqsize, Description, [ [TRACK,INST]...]] ...]

    """

    global defs

    l = [ ln[0], gbl.seqSize, ' '.join(ln[1:]) ]
    for a in sorted(gbl.tnames.keys()):
        c=gbl.tnames[a]
        if c.sequence and len(c.sequence) != c.sequence.count(None):
            if c.vtype=='DRUM':
                v=MMA.midiC.valueToDrum(c.toneList[0])
            else:
                v=MMA.midiC.valueToInst(c.voice[0])
            l.append( [c.name, v ] )

    defs.append(l)


def docDump():
    """ Print the LaTex docs. """

    global fname, author, notes, defs, variables

    if gbl.createDocs == 1:    # latex docs
        if notes:
            if fname.endswith(gbl.ext):
                fname='.'.join(fname.split('.')[:-1])
            print "\\filehead{%s}{%s}" % (totex(fname), totex(notes))
            print

        if variables:
            print "  \\variables{" 
            for l in variables:
                print "     \\insvar{%s}{%s}" % ( totex(l[0]), totex(l[1]) )
            print "  }"
            print

        if defs:
            for l in defs:
                alias = MMA.grooves.getAlias(l[0])
                if alias:
                    if len(alias)>1:
                        alias="Aliases: %s" % alias
                    else:
                        alias="Alias: %s" % alias
                else:
                    alias=''
                print "     \\instable{%s}{%s}{%s}{%s}{" % \
                    (totex(l[0]), totex(l[2]), l[1], alias)
                for c,v in l[3:]:
                    print "       \\insline{%s}{%s}" % (c.title(), totex(v))
                print "     }"
              
    if gbl.createDocs == 2:    # html docs
        if notes:
            print '<!-- Auto-Generated by MMA on: %s -->' % time.ctime()
            print '<HTML>'
            print '<BODY  BGCOLOR="#B7DFFF" Text=Black>'
            if fname.endswith(gbl.ext):
                fname='.'.join(fname.split('.')[:-1])
            print "<H1>%s</H1>" % fname.title()
            print "<P>%s" % notes

        if variables:
            print "<P>"
            print '<Table Border=3 CELLSPACING=0 CELLPADDING=5 BGColor="#eeeeee" Width="60%">'
            print '  <TR><TD>'
            print '    <H2> Variables </H2> ' 
            print '  </TD></TR>'
            print '  <TR><TD>'
            print '    <Table CELLSPACING=0 CELLPADDING=5 BGColor="#eeeeee" Width="100%">'
            for l in variables:
                print "       <TR>"
                print "          <TD Valign=Top> <B> %s </B> </TD> " % l[0]
                print "          <TD Valign=Top> %s </TD>" %  l[1]
                print "       </TR>"
            print '    </Table>'
            print '  </TD></TR>'
            print '</Table>'

        if defs:
            print "<ul>"
            for l in defs:
                print "<LI><A Href=#%s>%s</a>" % (l[0], l[0])
            print "</ul>"
            for l in defs:
                print '<A Name=%s></a>' % l[0]
                print '<Table Border=3 CELLSPACING=0 CELLPADDING=5 BGColor="#eeeeee" Width="60%">'
                print '  <TR><TD>'
                print '    <H2> %s </H2> ' % l[0]
                alias=MMA.grooves.getAlias(l[0])
                if alias:
                    if len(alias)>1:
                        ll="Aliases"
                    else:
                        ll="Alias"
                    print ' <H4> %s: %s </H4>' % (ll, alias)
                print '    %s <B>(%s)</B> ' % ( l[2], l[1] )
                print '  </TD></TR>'
                print '  <TR><TD>'
                print '    <Table CELLSPACING=0 CELLPADDING=5 BGColor="#eeeeee" Width="10%">'
                for c,v in l[3:]:
                    print "       <TR><TD> %s </TD> <TD> %s </TD></TR>" % (c.title(), v)
                print '    </Table>'
                print '  </TD></TR>'
                print '</Table>'
            print
            print '</Body></HTML>'

    if gbl.createDocs == 3:
         if notes:
             if fname.endswith(gbl.ext):
                 fname='.'.join(fname.split('.')[:-1])
             print "%s.mma %s" % (fname, notes)
             print

         if variables:
             print " Variables:" 
             for l in variables:
                 print "  %s %s" % ( l[0], l[1] )
             print

         if defs:
             for l in defs:
                 print "Groove %s" % l[0].title()
                 
                 MMA.grooves.grooveDo(l[0].upper())
                 for t in sorted(gbl.tnames):
                     tr = gbl.tnames[t]
                     sq = tr.sequence
                     if sq[0]:
                         rt = []
                         for a in range(gbl.seqSize):
                             s=sq[a]
                             x = '{' + tr.formatPattern(sq[a]) + '}'
                             rt.append(x)
                         print " %s Sequence %s" % (tr.name, ' '.join(rt))
                         if tr.vtype == 'DRUM':
                             print " %s Tone %s" % (tr.name, 
                                   ' '.join([MMA.midiC.valueToDrum(a) for a in tr.toneList]))
                         else:
                             print " %s Voice %s" % (tr.name, 
                                   ' '.join([MMA.midiC.voiceNames[a] for a in tr.voice]))
                 
                 print
    
    defs = []
    variables=[]
    notes = ""
    author = ""


def totex(s):
    """ Parse a string and quote tex stuff.

        Also handles proper quotation style.
    """

    s = s.replace("$", "\$")
    s = s.replace("*", "$*$")
    s = s.replace("_", "\\_")
    #s = s.replace("\\", "\\\\")
    s = s.replace("#", "\\#")
    s = s.replace("&", "\\&")

    q="``"
    while s.count('"'):
        s=s.replace('"', q, 1)
        if q=="``":
            q="''"
        else:
            q="``"


    return s



def docVerbose():
    """ Print verbose pattern/sequence info: -Dp command line. """

    global fname, author, notes, defs, variables

   
    defs = []
    variables=[]
    notes = ""
    author = ""

