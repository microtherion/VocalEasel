
# chordtable.py

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



Table of chords. All are based on a C scale.
Generating chords is easy in MIDI since we just need to
add/subtract constants, based on yet another table.

CAUTION, if you add to this table make sure there are at least
3 notes in each chord! Don't make any chord longer than 8 notes
(The pattern define sets volumes for only 8).

There is a corresponding scale set for each chord. These are
used by bass and scale patterns.

Each chord needs an English doc string. This is extracted by the
-Dn option to print a table of chordnames for inclusion in the
reference manual.

"""

C  = 0
Cs = Db = 1
D       = 2
Ds = Eb = 3
E  = Fb = 4
Es = F  = 5
Fs = Gb = 6
G       = 7
Gs = Ab = 8
A  = Bbb= 9
As = Bb = 10
B  = Cb = 11

_chords = {
	'M':	((C,	E,	  G ),
			 (C, D, E, F, G, A, B),
			 "Major triad. This is the default and is used in  "
			 "the absense of any other chord type specification."),

	'm':	((C,	Eb,    G ),
			 (C, D, Eb, F, G, Ab, Bb),
			 "Minor triad."),

	'mb5':	((C,	Eb,	   Gb ),
			 (C, D, Eb, F, Gb, Ab, Bb),
			 "Minor triad with flat 5th."),

	'm#5':	((C,	Eb,	   Gs ),
			 (C, D, Eb, F, Gs, Ab, Bb),
			 "Major triad with augmented 5th."),

	'm6':	((C,	Eb,	   G, A ),
			 (C, D, Eb, F, G, A, Bb),
			 "Minor 6th."),

	'm6(add9)':	((C, Eb, G, D+12, A+12),
			 (C, D, Eb, F, G, A, B),
			 "Minor 6th with added 9th. This is sometimes notated as a slash chord "
			 "in the form ``m6/9''." ),

	'm7':	((C,	Eb,	   G,	  Bb ),
			 (C, D, Eb, F, G, Ab, Bb),
			 "Minor 7th."),

	'mM7':	((C,	Eb,	  G,	  B ),
			 (C, D, Eb, F, G, Ab, B),
			 "Minor Triad plus Major 7th. You will also see this printed "
			 "as ``m(maj7)'', ``m+7'', ``min(maj7)'' and ``min$\sharp$7'' "
			 "(which \mma\ accepts); as well as the \mma\ \emph{invalid} "
			 "forms: ``-($\Delta$7)'', and ``min$\\natural$7''."),

	'm7b5': ((C,	Eb,	   Gb,	   Bb ),
			 (C, D, Eb, F, Gb, Ab, Bb),
			 "Minor 7th, flat 5 (aka 1/2 diminished). "),

	'm7b9': ((C,     Eb,    G,     Bb, Db+12 ),
			 (C, Db, Eb, F, G, Ab, Bb),
			 "Minor 7th with added flat 9th."),

	'7':	((C,    E,	  G,	Bb ),
			 (C, D, E, F, G, A, Bb),
			 "Dominant 7th."),

	'7#5':	((C,    E,    Gs,    Bb ),
			 (C, D, E, F, Gs, A, Bb),
			 "7th, sharp 5."),

	'7b5':	((C,    E,	  Gb,    Bb ),
			 (C, D, E, F, Gb, A, Bb),
			 "7th, flat 5."),

	'dim7': ((C,	Eb,	   Gb,	   Bbb ),
			 (C, D, Eb, F, Gb, Ab, Bbb ),	# missing 8th note
			 "Diminished seventh."),

	'aug':	((C,    E,	  Gs ),
			 (C, D, E, F, Gs, A, B ),
			 "Augmented triad."),

	'6':	((C,    E,	  G, A ),
			 (C, D, E, F, G, A, B),
			 "Major tiad with added 6th."),

	'6(add9)':	((C,   E, G, D+12, A+12),
			 (C, D, E, F, G, A, B),
			 "6th with added 9th. This is sometimes notated as a slash chord "
			 "in the form ``6/9''."),

	'M7':	((C,    E,    G,    B),
			 (C, D, E, F, G, A, B),
			 "Major 7th."),

	'M7#5':	((C,    E,    Gs,    B),
			 (C, D, E, F, Gs, A, B),
			 "Major 7th with sharp 5th."),

	'M7b5': ((C,    E,	  Gb,    B ),
			 (C, D, E, F, Gb, A, B ),
			 "Major 7th with a flat 5th."),

	'9':	((C,    E,    G,    Bb, D+12 ),
			 (C, D, E, F, G, A, Bb),
			 "Dominant 7th plus 9th."),

	'sus9': ((C,    E,    G,    D+12),
			 (C, D, E, F, G, A, D+12),
			 "Dominant 7th plus 9th, omit 7th."),

	'9b5':	((C,    E,    Gb,    Bb, D+12 ),
			 (C, D, E, F, Gb, A, Bb),
			 "Dominant 7th plus 9th with flat 5th."),

	'm9':	((C,	Eb,	   G,	  Bb, D+12 ),
			 (C, D, Eb, F, G, Ab, Bb),
			 "Minor triad plus 7th and 9th."),

	'm9b5': ((C,	Eb,    Gb, Bb, D+12 ),
			 (C, D, Eb, F, Gb, Ab, Bb),
			 "Minor triad, flat 5, plus 7th and 9th."),

	'm(sus9)':((C,	  Eb,    G,     D+12 ),
			   (C, D, Eb, F, G, Ab, D+12),
			   "Minor triad plus 9th (no 7th)."),

	'M9':	((C,    E,    G,    B, D+12 ),
			 (C, D, E, F, G, A, B),
			 "Major 7th plus 9th."),

	'7b9':	((C,     E,    G,    Bb, Db+12 ),
			 (C, Db, E, F, G, A, Bb),
			 "Dominant 7th with flat 9th."),

	'7#9':	((C,     E,    G,    Bb, Ds+12 ),
			 (C, Ds, E, F, G, A, Bb),
			 "Dominant 7th with sharp 9th."),

	'7b5b9':((C,     E,    Gb,    Bb, Db+12 ),
			 (C, Db, E, F, Gb, A, Bb),
			 "Dominant 7th with flat 5th and flat 9th."),

	'7b5#9':((C,     E,    Gb,    Bb, Ds+12 ),
			 (C, Ds, E, F, Gb, A, Bb),
			 "Dominant 7th with flat 5th and sharp 9th."),

	'7#5#9':((C,     E,    Gs,    Bb, Ds+12 ),
			 (C, Ds, E, F, Gs, A, Bb),
			 "Dominant 7th with sharp 5th and sharp 9th."),

	'7#5b9':((C,     E,    Gs,    Bb, Db+12 ),
			 (C, Db, E, F, Gs, A, Bb),
			 "Dominant 7th with sharp 5th and flat 9th."),

	'aug7': ((C,    E,    Gs,    Bb ),
			 (C, D, E, F, Gs, A, Bb),
			 "An augmented chord (raised 5th) with a dominant 7th."),

	'aug7b9':((C,     E,    Gs,    Bb, Db+12 ),
			  (C, Db, E, F, Gs, A, Bb),
			  "Augmented 7th with flat 5th and sharp 9th."),

	'11':	((C,    E,    G,    Bb, D+12, F+12 ),
			 (C, D, E, F, G, A, Bb),
			 "9th chord plus 11th."),

	'm11':	((C,    Eb,    G,     Bb, D+12, F+12 ),
			 (C, D, Eb, F, G, Ab, Bb),
			 "9th with minor 3rd,  plus 11th."),

	'11b9': ((C,     E,    G,    Bb, Db+12, F+12 ),
			 (C, Db, E, F, G, A, Bb),
			 "9th chord plus flat 11th."),

	'9#5':	((C,    E,    Gs,    Bb, D+12 ),
			 (C, D, E, F, Gs, A, Bb),
			 "Dominant 7th plus 9th with sharp 5th."),

	'9#11': ((C,    E,     G,    Bb, D+12, Fs+12 ),
			 (C, D, E, Fs, G, A, Bb),
			 "Dominant 7th plus 9th and sharp 11th."),

	'7#9#11':((C,     E,     G,    Bb, Ds+12, Fs+12 ),
			  (C, Ds, E, Fs, G, A, Bb),
			  "Dominant 7th plus sharp 9th and sharp 11th."),


	'M7#11':((C,    E,     G,    B, D+12, Fs+12 ),
			 (C, D, E, Fs, G, A, B),
			 "Major 7th plus 9th and sharp 11th."),

	# Sus chords. Not sure what to do with the associated scales. For
	# now just duplicating the 2nd or 3rd in the scale seems to make sense.

	'sus4': ((C,    F,    G ),
			 (C, D, F, F, G, A, B),
			 "Suspended 4th, major triad with 3rd raised half tone."),

	'7sus': ((C,    F,    G,    Bb ),
			 (C, D, F, F, G, A, Bb),
			 "7th with suspended 4th, dominant 7th with 3rd "
			 "raised half tone."),

	'sus2': ((C,    D,    G ),
			 (C, D, D, F, G, A, B),
			 "Suspended 2nd, major triad with major 2nd above "
			 "root substituted for 3rd."),

	'7sus2':((C,    D,    G,    Bb ),
			 (C, D, D, F, G, A, Bb),
			 "A sus2 with dominant 7th added."),

	# these two chords should probably NOT have the 5th included,
	# but since a number of voicings depend on the 5th being
	# the third note of the chord, they're here.

	'13':	((C,    E,    G,    Bb, A+12),
			 (C, D, E, F, G, A, Bb),
			 "Dominant 7th (including 5th) plus 13th."),

	'M13':	((C,    E,    G,    B, A+12),
			 (C, D, E, F, G, A, B),
			 "Major 7th (including 5th) plus 13th."),

	# Because some patterns assume that the 3rd note in a chord is a 5th,
	# or a varient, we duplicate the root into the position of the 3rd ... and
	# to make the sound even we duplicate the 5th into the 4th position as well.

	'5':	((C, C,	G, G ),
			 (C, D, E, F, G, A, B),
			 "Altered Fifth or Power Chord; root and 5th only."),
}


""" Extend our table with common synomyns. These are real copies,
not pointers. This is done so that a user redefine only affects
the original.
"""

aliases = (
	('aug9',     '9#5'  , ''),
	('69',       '6(add9)', ''),
	('m69',      'm6(add9)', ''),
	('9+5',      '9#5'  , ''),
	('m+5',		 'm#5'	, ''),
	('M6',		 '6'	, ''),
	('m7-5',	 'm7b5' , ''),
	('+',		 'aug'	, ''),
	('+7',       'aug7' , ''),
	('#5',       'aug'  , ''),
	('7-9',		 '7b9'	, ''),
	('7+9',		 '7#9'	, ''),
	('maj7',	 'M7'	, ''),
	('M7-5',	 'M7b5'	, ''),
	('M7+5',	 'M7#5'	, ''),
	('7alt',     '7b5b9', ''),
	('7sus4',	 '7sus' , ''),
	('7#11',	 '9#11' , ''),
	('7+',		 'aug7' , ''),
	('7+5',		 '7#5'	, ''),
	('7-5',		 '7b5'	, ''),
	('sus',		 'sus4' , ''),
	('m(maj7)',	 'mM7'	, ''),
	('m+7',		 'mM7'	, ''),
	('min(maj7)','mM7'	, ''),
	('min#7',	 'mM7'	, ''),
	('m#7',      'mM7'  , ''),
	('dim',		 'dim7' , 'A dim7, not a triad!'),
	('9sus',	 'sus9' , ''),
	('9-5',      '9b5'  , ''),
	('dim3',	 'mb5'	, 'Diminished triad (non-standard notation).')
	)

for a,b,d in aliases:
	n=_chords[b][0]
	s=_chords[b][1]
	if not d:
		d=_chords[b][2]

	_chords[a] = (n, s, d)

