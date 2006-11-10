
# patChord.py

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

Bob van der Poel <bvdp@xplornet.com>

"""


import random

import gbl
from   MMA.notelen import getNoteLen
from   MMA.common import *
from   MMA.pat import PC


class Chord(PC):
	""" Pattern class for a chord track. """

	vtype = 'CHORD'


	def getPgroup(self, ev):
		""" Get group for chord pattern.

		Tuples: [start, length, volume (,volume ...) ]
		"""

		if len(ev) < 3:
			error("There must be at least 3 items in each group "
				  "of a chord pattern definition, not <%s>." % ' '.join(ev))

		a = struct()

		a.offset = self.setBarOffset(ev[0])
		a.duration = getNoteLen(ev[1])

		vv = ev[2:]
		if len(vv)>8:
			error("Only 8 volumes are permitted in Chord definition, not %s." % len(vv))

		a.vol = [0] * 8
		for i,v in enumerate(vv):
			v=stoi(v, "Expecting integer in volume list for Chord definition.")
			a.vol[i]=v

		for i in range(i+1,8): # force remaining volumes
			a.vol[i]=v

		return a

	def restart(self):
		self.ssvoice = -1
		self.lastChord = None


	def chordVoicing(self, chord, vMove):
		""" Voicing algorithm by Alain Brenzikofer. """


		sc = self.seq
		vmode=self.voicing.mode

		if vmode == "OPTIMAL":

			# Initialize with a voicing around centerNote

			chord.center1(self.lastChord)

			# Adjust range and center

			if not (self.voicing.bcount or self.voicing.random):
				chord.center2(self.voicing.center, self.voicing.range/2)


			# Move voicing

			elif self.lastChord:
				if (self.lastChord != chord.noteList ) and vMove:
					chord.center2(self.voicing.center,self.voicing.range/2)
					vMove = 0

					# Update voicingCenter

					sum=0
					for n in chord.noteList:
						sum += n
					c=sum/chord.noteListLen

					""" If using random voicing move it it's possible to
					get way off the selected octave. This check ensures
					that the centerpoint stays in a tight range.
					Note that if using voicingMove manually (not random)
					it is quite possible to move the chord centers to very
					low or high keyboard positions!
					"""

					if self.voicing.random:
						if	 c < -4: c=0
						elif c >4: c=4
					self.voicing.center=c


		elif vmode == "COMPRESSED":
			chord.compress()

		elif vmode == "INVERT":
			if chord.rootNote < -2:
				chord.invert(1)

			elif chord.rootNote > 2:
				chord.invert(-1)
			chord.compress()

		self.lastChord = chord.noteList[:]

		return vMove


	def trackBar(self, pattern, ctable):
		""" Do a chord bar. Called from self.bar() """

		sc = self.seq
		unify = self.unify[sc]

		""" Set voicing move ONCE at the top of each bar.
		    The voicing code resets vmove to 0 the first
		    time it's used. That way only one movement is
		    done in a bar.
		"""

		vmove = 0

		if self.voicing.random:
			if random.randrange(100) <= self.voicing.random:
				vmove = random.choice((-1,1))
		elif self.voicing.bcount and self.voicing.dir:
			vmove = self.voicing.dir


		for p in pattern:
			tb = self.getChordInPos(p.offset, ctable)

			if tb.chordZ:
				continue

			self.crDupRoot = self.dupRoot[sc]

			vmode = self.voicing.mode
			vols = p.vol[0:tb.chord.noteListLen]

			# Limit the chord notes. This works even if THERE IS A VOICINGMODE!

			if self.chordLimit:
				tb.chord.limit(self.chordLimit)

			""" Compress chord into single octave if 'compress' is set
			    We do it here, before octave, transpose and invert!
			    Ignored if we have a VOICINGMODE.
			"""

			if self.compress[sc] and not vmode:
				tb.chord.compress()

			# Do the voicing stuff.

			if vmode:
				vmove=self.chordVoicing(tb.chord, vmove)

			# Invert.

			if self.invert[sc]:
				tb.chord.invert(self.invert[sc])

			# Set STRUM flags

			strumAdjust = self.strum[sc]
			strumOffset = 0
			sd = self.direction[sc]
			if sd=='BOTH':
				sd = 'BOTHDOWN'
			if sd == 'BOTHDOWN':
				sd = 'BOTHUP'
			elif sd == 'BOTHUP':
				sd = 'BOTHDOWN'

			if strumAdjust and sd in ('DOWN', 'BOTHDOWN'):
				strumOffset += strumAdjust * tb.chord.noteListLen
				strumAdjust = -strumAdjust


			""" Voicing adjustment for 'jazz' or altered chords. If a chord (most
			    likely something like a M7 or flat-9 ends up with any 2 adjacent
				notes separated by a single tone an unconfortable dissonance results.
				This little check compares all notes in the chord and will cut the
				volume of one note to reduce the disonance. Usually this will be
				the root note volume being decreased.
			"""

			nl=tb.chord.noteList
			l=len(nl)
			for j in range(l-1):
				r = nl[j]
				for i in range(j+1, l):
					if nl[i] in (r-1, r+1, r-13, r+13) and vols[i] >= vols[0]:
						vols[j] = vols[i]/2
						break

			loo = zip(nl, vols)	# this is a note/volume array of tuples


			""" Duplicate the root. This can be set from a DupRoot command
			    or by chordVoicing(). Notes:
			     - The volume for the added root will be the average of the chord
				   notes (ignoring OFF notes) divided by 2.
			     - If the new note (after transpose and octave adjustments
			       is out of MIDI range it will be ignored.
			"""

			if self.crDupRoot:
				root = tb.chord.rootNote + self.crDupRoot
				t = root + self.octave[sc] + gbl.transpose
				if t >=0 and t < 128:
					v=0
					c=0
					for vv in vols:
						if vv:
							v += vv
							c += 2
					v /= c
					loo.append( (tb.chord.rootNote + self.crDupRoot, v))

			for note, v in sorted(loo):  # sorting low-to-high notes. Mainly for STRUM.
				self.sendNote(
					p.offset+strumOffset,
					self.getDur(p.duration),
					self.adjustNote(note),
					self.adjustVolume( v,  p.offset) )

				strumOffset += strumAdjust

			tb.chord.reset()	# important, other tracks chord object

		# Adjust the voicingMove counter at the end of the bar

		if self.voicing.bcount:
				self.voicing.bcount -= 1



