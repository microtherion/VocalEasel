
# chords.py

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

import copy


from MMA.common import *
from MMA.chordtable import _chords



def defChord(ln):
	""" Add a new chord type to the _chords{} dict. """

	emsg="DefChord needs NAME (NOTES) (SCALE)"

	# At this point ln is a list. The first item should be
	# the new chord type name.

	if not len(ln):
		error(emsg)
	name = ln.pop(0)
	if name in _chords.keys():
		warning("Redefining chordtype '%s'." % name)

	if '/' in name:
		error("A slash in not permitted in chord type name")

	if '>' in name:
		error("A '>' in not permitted in chord type name")

	ln=pextract(''.join(ln), '(', ')')

	if ln[0] or len(ln[1])!=2:
		error(emsg)

	notes=ln[1][0].split(',')
	if len(notes) < 2 or len(notes)>8:
		error("There must be 2..8 notes in a chord, not '%s'." % len(note))
	notes.sort()
	for i,v in enumerate(notes):
		v=stoi(v, "Note offsets in chord must be integers, not '%s'." % v)
		if v<0 or v>24:
			error("Note offsets in chord must be 0..24, not '%s'." % v)
		notes[i]=v

	scale=ln[1][1].split(',')
	if len(scale) != 7:
		error("There must be 7 offsets in chord scale, not '%s'" % len(scale))
	scale.sort()
	for i,v in enumerate(scale):
		v=stoi(v, "Scale offsets in chord must be integers, not '%s'." % v)
		if v<0 or v>24:
			error("Scale offsets in chord must be 0..24, not '%s'." % v)
		scale[i]=v


	_chords[name] = ( notes, scale, "User Defined")

	if gbl.debug:
		print "ChordType '%s', %s" % (name, _chords[name])


def printChord(ln):
	""" Display the note/scale/def for chord(s). """

	for c in ln:
		if not _chords.has_key(c):
			error("Chord '%s' is unknown" % c)
		print c, ':', _chords[c][0], _chords[c][1], _chords[c][2]


"""
Table of chord adjustment factors. Since the initial chord is based
on a C scale, we need to shift the chord for different degrees. Note,
that with C as a midpoint we shift left for G/A/B and right for D/E/F.

Should the shifts take in account the current key signature?
"""

_chordAdjust = {
	'Gb':-6,
	'G' :-5,
	'G#':-4, 'Ab':-4,
	'A' :-3,
	'A#':-2, 'Bb':-2,
	'B' :-1, 'Cb':-1,
	'B#': 0, 'C' : 0,
	'C#': 1, 'Db': 1,
	'D' : 2,
	'D#': 3, 'Eb': 3,
	'E' : 4, 'Fb': 4,
	'E#': 5, 'F' : 5,
	'F#': 6 }

def chordAdjust(ln):
	""" Adjust the chord point up/down one octave. """

	if not ln:
		error("ChordAdjust: Needs at least one argument.")

	for l in ln:
		try:
			pitch, octave = l.split('=')
		except:
			error("Each arg must contain an '=', not '%s'." % l)

		if pitch not in _chordAdjust:
			error("ChordAdjust: '%s' is not a valid pitch." % pitch)

		octave = stoi(octave, "ChordAdjust: expecting integer, not '%s'." % octave)

		p=_chordAdjust[pitch]
		if octave == 0:
			if p < -6:
				_chordAdjust[pitch] += 12
			elif p > 6:
				_chordAdjust[pitch]-=12

		elif octave == -1 and p <= 6 and p >= -6:
			_chordAdjust[pitch] -= 12

		elif octave == 1 and p <= 6 and p >= -6:
			_chordAdjust[pitch] += 12

		else:
			error("ChordAdjust: '%s' is not a valid octave. Use 1, 0 or -1." % octave)



###############################
# Chord creation/manipulation #
###############################

class ChordNotes:
	""" The Chord class creates and manipulates chords for MMA. The
	class is initialized with a call with the chord name. Eg:

	ch = ChordNotes("Am")

	The following methods and variables are defined:

	noteList  - the notes in the chord as a list. The "Am"
		would be [9, 12, 16].

	noteListLen	 - length of noteList.

	tonic	   - the tonic of the chord ("Am" would be "A").

	chordType  - the type of chord ("Am" would be "m").

	rootNote   - the root note of the chord ("Am" would be a 9).

	bnoteList  - the original chord notes, bypassing any
	invert(), etc. mangling.

	scaleList  - a 7 note list representing a scale similar to
	the chord.

	reset() - resets noteList to the original chord notes.
	This is useful to restore the original after
	chord note mangling by invert(), etc. without having to
	create a new chord object.


	invert(n) - Inverts a chord by 'n'. This is done inplace and
	returns None. 'n' can have any integer value, but -1 and 1
	are most common. The order of the notes is not changed. Eg:

	ch=Chord('Am')
	ch.noteList == [9, 12, 16]
	ch.invert(1)
	ch.noteList	 = [21, 12, 16]

	compress() - Compresses the range of a chord to a single octave. This is
	done inplace and return None. Eg:

	ch=Chord("A13")
	ch.noteList == [1, 5, 8, 11, 21]
	ch.compress()
	ch.noteList == [1, 5, 8, 11, 10 ]


	limit(n) -	Limits the range of the chord 'n' notes. Done inplace
	and returns None. Eg:

	ch=Chord("CM711")
	ch.noteList == [0, 4, 7, 11, 15, 18]
	ch.limit(4)
	ch.noteList ==	[0, 4, 7, 11]


	"""


	#################
	### Functions ###
	#################

	def __init__(self, name, line=''):
		""" Create a chord object. Pass the chord name as the only arg.

		NOTE: Chord names ARE case-sensitive!

		The chord NAME at this point is something like 'Cm' or 'A#7'.
		Split off the tonic and the type.
		If the 2nd char is '#' or 'b' we have a 2 char tonic,
		otherwise, it's the first char only.

		A chord can start with a single '+' or '-'. This moves
		the entire chord and scale up/down an octave.

		Note pythonic trick: By using ranges like [1:2] we
		avoid runtime errors on too-short strings. If a 1 char
		string,	 name[1] is an error; name[1:2] just returns None.

		Further note: I have tried to enable caching of the generated
		chords, but found no speed difference. So, to make life simpler
		I've decided to generate a new object each time.

		"""

		slash = None
		octave = 0
		inversion = 0

		if name == 'z':
			self.tonic = self.chordType = None
			self.noteListLen = 0
			self.notesList = self.bnoteList = []
			return

		if '/' in name and '>' in name:
			error("You cannot use both an inversion and a slash in the same chord.")

		if '>' in name:
			name, inversion = name.split('>', 1)
			inversion = stoi(inversion, "Expecting interger after '>'.")
			if inversion < -5 or inversion > 5:
				error("Chord inversions limited to -5 to 5 (more seems silly).")

		if name.startswith('-'):
			name = name[1:]
			octave = -12

		if name.startswith('+'):
			name = name[1:]
			octave = 12

		name = name.replace('&', 'b')

		# Strip off the slash part of the chord. Use later
		# to do proper inversion.

		if name.find('/') > 0:
			name, slash = name.split('/')

		if name[1:2] in ( '#b' ):
			tonic = name[0:2]
			ctype  = name[2:]
		else:
			tonic = name[0:1]
			ctype  = name[1:]

		if not ctype:		# If no type, make it a Major
			ctype='M'

		try:
			notes = _chords[ctype][0]
			adj =	_chordAdjust[tonic] + octave
		except:
			error( "Illegal/Unknown chord name: '%s'." % name )

		self.noteList	 = [ x + adj for x in notes ]
		self.bnoteList	 = tuple(self.noteList)
		self.scaleList	 = tuple([ x + adj for x in _chords[ctype][1] ])
		self.chordType	 = ctype
		self.tonic		 = tonic
		self.rootNote	 = self.noteList[0]

		self.noteListLen = len(self.noteList)

		# Inversion

		if inversion:
			self.invert(inversion)
			self.bnoteList = tuple(self.noteList)

		# Do inversions if there is a valid slash notation.

		if slash:
			if not _chordAdjust.has_key(slash):
				error("The note '%s' in the slash chord is unknown." % slash)

			r=_chordAdjust[slash]	# r = -6 to 6

			# If the slash note is in the chord we invert
			# the chord so the slash note is in root position.

			c_roted = 0
			s=self.noteList
			for octave in [0, 12, 24]:
				if r+octave in s:
					rot=s.index(r+octave)
					for i in range(rot):
						s.append(s.pop(0)+12)
					if s[0] >= 12:
						for i,v in enumerate(s):
							s[i] = v-12
							self.noteList = s
					self.bnoteList = tuple(s)
					self.rootNote = self.noteList[0]
					c_roted = 1
					break

			s_roted = 0
			s=list(self.scaleList)
			for octave in [0, 12, 24]:
				if r+octave in s:
					rot=s.index(r+octave)
					for i in range(rot):
						s.append(s.pop(0)+12)
						if s[0] > 12:
							for i,v in enumerate(s):
								s[i] = v-12
						self.scaleList=tuple(s)
					s_roted = 1
					break

			if not c_roted and not s_roted:
				warning("The slash chord note '%s' not in "
						"chord or scale." % slash)

			elif not c_roted:
				warning("The slash chord note '%s' not in "
						"chord '%s'" % (slash, name))

			elif not s_roted:	# Probably will never happen :)
				warning("The slash chord note '%s' not in "
						"scale for the chord '%s'" % (slash, name))


	def reset(self):
		""" Restores notes array to original, undoes mangling. """

		self.noteList	 = list(self.bnoteList[:])
		self.noteListLen = len(self.noteList)


	def invert(self, n):
		""" Apply an inversion to a chord.

		This does not reorder any notes, which means that the root note of
		the chord reminds in postion 0. We just find that highest/lowest
		notes in the chord and adjust their octave.

		NOTE: Done on the existing list of notes. Returns None.
		"""

		if n:
			c=self.noteList[:]

			while n>0:		# Rotate up by adding 12 to lowest note
				n -= 1
				c[c.index(min(c))]+=12

			while n<0:		# Rotate down, subtract 12 from highest note
				n += 1
				c[c.index(max(c))]-=12

			self.noteList = c

		return None



	def compress(self):
		""" Compress a chord to one ocatve.


		Get max permitted value. This is the lowest note
		plus 12. Note: use the unmodifed value bnoteList!
		"""

		mx = self.bnoteList[0] + 12
		c=[]

		for i, n in enumerate(self.noteList):
			if n > mx:
				n -= 12
			c.append(n)

		self.noteList = c

		return None



	def limit(self, n):
		""" Limit the number of notes in a chord. """

		if n < self.noteListLen:
			self.noteList =	 self.noteList[:n]
			self.noteListLen = len(self.noteList)

		return None


	def center1(self, lastChord):
		""" Descriptive comment needed here!!!! """

		def minDistToLast(x, lastChord):
			dist=99
			for j in range(len(lastChord)):
				if abs(x-lastChord[j])<abs(dist):
					dist=x-lastChord[j]
			return dist

		def sign(x):
			if (x>0):
				return 1
			elif (x<0):
				return -1
			else:
				return 0

		# Only change what needs to be changed compared to the last chord
		# (leave notes where they are if they are in the new chord as well).

		if lastChord:
			ch=self.noteList

			for i in range(len(ch)):

				# minimize distance to last chord

				oldDist = minDistToLast(ch[i], lastChord)
				while abs(minDistToLast(ch[i] - sign(oldDist)*12,
								lastChord)) < abs(oldDist):
					ch[i] -= 12* sign(oldDist)
					oldDist = minDistToLast(ch[i], lastChord)

		return None

	def center2(self, centerNote, noteRange):
		""" Need COMMENT """

		ch=self.noteList
		for i,v in enumerate(ch):

			dist = v - centerNote
			if dist < -noteRange:
				ch[i] = v + 12 * ( abs(dist) / 12+1 )
			if dist > noteRange:
				ch[i] = v - 12 * ( abs(dist) / 12+1 )


		return None


######## End of Chord class #####



def docs():
	""" Print out a list of chord names and docs in LaTex. """

	import copy

	# Just in case someone else wants to use _chords, work on a copy

	chords=copy.copy(_chords)

	for n in sorted(chords.keys()):
		nm=n.replace("#", '$\\sharp$')
		nm=nm.replace('b', '$\\flat$')
		print "\\insline{%s}{%s}" % (nm, chords[n][2])



