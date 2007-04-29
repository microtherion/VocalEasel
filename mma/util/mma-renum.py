#!/usr/bin/env python

# Renumber a mma song file. Just take any lines
# which start with a number and do those sequenially.

import sys, os


def usage():
    print "Mma-renum, (c) Bob van der Poel"
    print "Re-numbers a mma song file and"
    print "  cleans up chord tabbing."
    print "Overwrites existing file!"
    print
    sys.exit(1)
    
if len(sys.argv[1:]) != 1:
    print "mma-rnum: requires 1 filename argument."
    usage()
    
filename = sys.argv[1]
tempfile = filename + ".temp"

if filename[0] == '-':
    usage()
    
if not os.path.exists(filename):
    error("Can't access the file '%s'" % filename)
    
try:
    inpath = open(filename, 'r')
except:
    usage()
        
try:
    outpath = open( tempfile, 'w')
except:
    error("Can't open scratchfile '%s', error '%s'" % (tempfile, sys.exc_info()[0]) )
    
linenum = 1

for l in inpath:
    l=l.rstrip()
    s = l.split()
    if s:
        try:   # only modify lines starting with a number
            x=int(s[0]) 
            l='%-5s' % linenum
            linenum += 1
            for a in s[1:]:
                l += "%-4s " % a
        except:
            pass
    outpath.write(l + "\n")
    
inpath.close()
outpath.close()

try:
    os.remove(filename)
except:
    error("Cannot delete '%s', new file '%s' remains", (filename, tempfile) )
    
try:
    os.rename(tempfile, filename)
except:
    error("Cannot rename '%s' to '%s'." (tempfile, filename) )





