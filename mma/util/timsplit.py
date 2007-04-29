#!/usr/bin/env python

# Create a set of wav files from MMA using timidity.

import sys, os, commands


def usage():
    print "timsplit, (c) Bob van der Poel"
    print "Create multi-track wav files using"
    print "  MMA files and timidity."
    print
    sys.exit(0)
    
if len(sys.argv[1:]) != 1:
    print "timsplit: requires 1 filename argument."
    usage()

filename = sys.argv[1]

status, txt = commands.getstatusoutput("mma -c %s" % filename)

if status:
    print "timsplit error", status
    print txt
    sys.exit(1)

# Get the track list

ch=[]
for a in txt.split('\n'):
    a=a.strip().split()
    try:
        ch.append(int(a[0]))
    except:
        pass

ch.sort()
print "Found channels:",
for a in ch:
    print a,
print

# Create midi file

status = os.system("mma -0 %s -foutfile.mid" % filename)

if status:
    sys.exit(1)

# Create wav tracks with timidity

for a in ch:
    os.system("timidity -Ow -Q0 -Q-%s -o%s.wav outfile.mid" % (a,a) ) 
    
