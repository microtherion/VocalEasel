#!/usr/bin/env python


# This program will take a mma file and use timidity to split it into
# a series of .wav files. 1 wav for each track in the file.


import sys, os, commands

tmpname = "tmp-%s" % os.getpid()
tmpmid  = "%s.mid" % tmpname 
bgtrack = "bg.wav"

def usage():
    print "timsplit, (c) Bob van der Poel"
    print "Create multi-track wav files using"
    print "  MMA files and timidity."
    print
    sys.exit(0)
    
if len(sys.argv[1:]) != 1:
    print "timsplit: requires 1 filename argument."
    usage()

mmafile = sys.argv[1]

if mmafile.endswith(".mma"):
    basemid = mmafile[:-4]
else:
    basemid = mmafile

basemid += ".mid"


# Create the background midi and wav. FIXME: have a command line option to skip

status, txt = commands.getstatusoutput("mma -0 %s -f %s" % (mmafile, basemid))
if status:
    print "timsplit error", status
    print txt
    sys.exit(1)

# create a wav of the base file. This should get copied to your mixer

print "Creating background track:", bgtrack
status, txt = commands.getstatusoutput("timidity -Ow -o %s %s" % (bgtrack, basemid ))
if status:
    print "timsplit error", status
    print txt
    sys.exit(1)

# Get the tracks generated in the file

status, txt = commands.getstatusoutput("mma -c %s" % mmafile)
txt = txt.split()
txt=txt[txt.index('assignments:')+1:]
tracklist=[]
for a in sorted(txt):
    try:
        int(a)
    except:
        tracklist.append(a)

print "MMA file '%s' being split to: " % mmafile,
for a in tracklist:
    print a,
print


# Do the magic. For each track call mma and timidity.

for trackname in tracklist:
  
    trackname = trackname.title()
    status, txt = commands.getstatusoutput ("mma -0 %s -T %s -f %s " % (mmafile, trackname, tmpmid) )
    if status:
        if txt.find("No data created") >= 0:
            print "NO DATA for '%s', skipping" % trackname
            continue
        print "timsplit error creating MIDI file:", status
        print txt
        sys.exit(1)

    # create wav file
    # Options for timidity:  Ow -- output to wave
    #                         M -- mono

    print "Creating: %s.wav" % trackname
    status, txt = commands.getstatusoutput ("timidity -OwM -o%s.wav %s" % (trackname, tmpmid) )
    if status:
        print "timsplit error running timidity:", status
        print txt
        sys.exit(1)
 
    os.remove(tmpmid)





