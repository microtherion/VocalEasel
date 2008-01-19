//
// File: VLModel.cpp - Represent song music data
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
//

#include "VLModel.h"
#include <ctype.h>

VLFraction & VLFraction::Normalize()
{
	//
	// Divide GCD
	//
	if (fNum) {
		unsigned	a	= fNum;
		unsigned 	b	= fDenom;

		while (b) {
			unsigned c = a % b;
			a = b;
			b = c;
		}

		fNum	/= a;
		fDenom	/= a;
	} else
		fDenom = 1;

	return *this;
}

VLFraction & VLFraction::operator+=(VLFraction other)
{
	fNum 	= fNum*other.fDenom + other.fNum*fDenom;
	fDenom *= other.fDenom;

	return Normalize();
}

VLFraction & VLFraction::operator-=(VLFraction other)
{
	fNum 	= fNum*other.fDenom - other.fNum*fDenom;
	fDenom *= other.fDenom;

	return Normalize();
}

VLFraction & VLFraction::operator*=(VLFraction other)
{
	fNum   *= other.fNum;
	fDenom *= other.fDenom;

	return Normalize();
}

VLFraction & VLFraction::operator/=(VLFraction other)
{
	fNum   *= other.fDenom;
	fDenom *= other.fNum;

	return Normalize();
}

VLFraction & VLFraction::operator%=(VLFraction other)
{
	fNum   *= other.fDenom;
	fDenom *= other.fNum;
	fNum   %= fDenom;
	
	return *this *= other;
}

static const char kScale[] = "c d ef g a b";

static std::string	PitchName(int8_t pitch, bool useSharps)
{
	if (pitch == VLNote::kNoPitch)
		return "r";
	pitch %= 12;
	if (kScale[pitch] != ' ')
		return static_cast<char>(std::toupper(kScale[pitch])) + std::string();
	else if (useSharps)
		return static_cast<char>(std::toupper(kScale[pitch-1])) 
			+ std::string(kVLSharpStr);
	else
		return static_cast<char>(std::toupper(kScale[pitch+1])) 
			+ std::string(kVLFlatStr);
}

VLNote::VLNote(std::string name)
{
	//
	// Determine key
	//
	if (const char * key = strchr(kScale, name[0])) 
		fPitch	= key-kScale+kMiddleC;
	else
		goto failed;
	name.erase(0, 1);
	//
	// Look for sharp / flat
	//
	if (name.size())
		if (name[0] == '#') {
			++fPitch;
			name.erase(0);
		} else if (name[0] == 'b') {
			--fPitch;
			name.erase(0, 1);
		}
	if (name == "")
		return;

 failed:
	fPitch = kNoPitch; // Failed to parse completely
}	

VLNote::VLNote(VLFraction dur, int pitch)
	: fDuration(dur), fPitch(pitch), fTied(0), fVisual(0)
{
}

void VLNote::Name(std::string & name, bool useSharps) const
{
	name = PitchName(fPitch, useSharps);
}

void VLNote::MakeRepresentable()
{
	if (fDuration > 1)
		fDuration = 1;
	fVisual	= kWhole;
	VLFraction part(1,1);
	VLFraction triplet(2,3);
	//
	// Power of 2 denominators are not triplets
	//
	bool 	   nonTriplet(!(fDuration.fDenom & (fDuration.fDenom-1)));
	while (part.fDenom < 64) {
		if (fDuration >= part) {
			fDuration = part;
			return;
		} else if (fVisual > kWhole && !nonTriplet && fDuration >= triplet) {
			fDuration = triplet;
			fVisual	 |= kTriplet;
			return;
		}
		part	/= 2;
		triplet /= 2;
		++fVisual;
	}
	fprintf(stderr, "Encountered preposterously brief note: %d/%d\n",
			fDuration.fNum, fDuration.fDenom);
	abort();
}

void VLNote::AlignToGrid(VLFraction at, VLFraction grid)
{
	if (at+fDuration > grid) {	
		fDuration	= grid-at;
		MakeRepresentable();
	}
}

VLLyricsNote::VLLyricsNote(const VLNote & note)
	: VLNote(note)
{ 
}

VLLyricsNote::VLLyricsNote(VLFraction dur, int pitch)
	: VLNote(dur, pitch)
{
} 

#define _ VLChord::

static const VLChordModifier kModifiers[] = {
	{"b13", _ kmMin13th, 0},
	{"add13", _ kmMaj13th, 0},
	{"13", _ kmMin7th | _ kmMaj9th | _ km11th | _ kmMaj13th, 0},
	{"#11", _ kmAug11th, 0},
	{"add11", _ km11th, 0},
	{"11", _ kmMin7th | _ kmMaj9th | _ km11th, 0},
	{"#9", _ kmAug9th, _ kmMaj9th},
	{"+9", _ kmAug9th, _ kmMaj9th},
	{"b9", _ kmMin9th, _ kmMaj9th},
	{"-9", _ kmMin9th, _ kmMaj9th},
	{"69", _ kmDim7th | _ kmMaj9th, 0},
	{"add9", _ kmMaj9th, 0},
	{"9", _ kmMin7th | _ kmMaj9th, 0},
	{"7", _ kmMin7th, 0},
	{"maj", _ kmMaj7th, _ kmMin7th},
	{"6", _ kmDim7th, 0},
	{"#5", _ kmAug5th, _ km5th},
	{"+5", _ kmAug5th, _ km5th},
	{"aug", _ kmAug5th, _ km5th},
	{"+", _ kmAug5th, _ km5th},
	{"b5", _ kmDim5th, _ km5th},
	{"-5", _ kmDim5th, _ km5th},
	{"sus4", _ km4th, _ kmMaj3rd},
	{"sus2", _ kmMaj2nd, _ kmMaj3rd},
	{"sus", _ km4th, _ kmMaj3rd},
	{"4", _ km4th, _ kmMaj3rd},
	{"2", _ kmMaj2nd, _ kmMaj3rd},
	{NULL, 0, 0}
};

VLChord::VLChord(VLFraction dur, int pitch, int rootPitch)
	: VLNote(dur, pitch), fSteps(0), fRootPitch(kNoPitch)
{
}

VLChord::VLChord(std::string name)
{
	size_t		root;
	//
	// Determine key
	//
	if (const char * key = strchr(kScale, name[0])) 
		fPitch	= key-kScale+kMiddleC;
	else
		goto failed;
	name.erase(0, 1);
	//
	// Look for sharp / flat
	//
	if (name.size())
		if (name[0] == '#') {
			++fPitch;
			name.erase(0, 1);
		} else if (name[0] == 'b') {
			--fPitch;
			name.erase(0, 1);
		}
	//
	// Root
	//
	fRootPitch	= kNoPitch;
	if ((root = name.find('/')) != std::string::npos) {
		if (root+1 >= name.size())
			goto failed;
		if (const char * key = strchr(kScale, name[root+1])) 
			fRootPitch	= key-kScale+kMiddleC-12;
		else
			goto failed;
		if (root+2 < name.size()) {
			switch (name[root+2]) {
			case 'b':
				--fRootPitch;
				break;
			case '#':
				++fRootPitch;
				break;
			default:
				goto failed;
			}
			name.erase(root, 3);
		} else
			name.erase(root, 2);
	}
			
	//
	// Apply modifiers
	//
	fSteps	= kmUnison | kmMaj3rd | km5th;
	
	for (const VLChordModifier * mod = kModifiers; mod->fName && name.size() && name != "dim" && name != "m" && name != "-"; ++mod) {
		size_t pos = name.find(mod->fName);
		if (pos != std::string::npos) {
			name.erase(pos, strlen(mod->fName));
			fSteps	&=	~mod->fDelSteps;
			fSteps	|=	mod->fAddSteps;
		}
	}
	if (name == "m" || name == "-") {
		fSteps	= (fSteps & ~kmMaj3rd) | kmMin3rd;
		name.erase(0, 1);
	} else if (name == "dim") {
		uint32_t steps	= fSteps & (kmMaj3rd | km5th | kmMin7th);
		fSteps		   ^= steps;
		fSteps		   |= steps >> 1; // Diminish 3rd, 5th, and 7th, if present
		name.erase(0, 3);
	}
	if (name == "")
		return;		// Success
failed:
	fPitch = kNoPitch;
}

static const char * kStepNames[] = {
	"", "", "sus2", "", "", "sus", kVLFlatStr "5", "", kVLSharpStr "5", "6", 
	"7", kVLSharpStr "7", "", kVLFlatStr "9", "9", kVLSharpStr "9", "", 
	"11", kVLSharpStr "11", "", kVLFlatStr "13", "13"
};

void	VLChord::Name(std::string & base, std::string & ext, std::string & root, bool useSharps) const
{
	base = PitchName(fPitch, useSharps);
	ext  = "";
	root = "";
	
	uint32_t steps = fSteps;
	//
	// m / dim
	//
	if (steps & kmMin3rd)
		if (steps & (kmDim5th|kmDim7th) 
		 && !(steps & (km5th|kmMin7th|kmMaj7th|kmMin9th|kmMaj9th|km11th|kmAug11th|kmMin13th|kmMaj13th))
		) {
			ext += "dim";
			steps|= (steps & kmDim7th) << 1;
			steps&=	~(kmMin3rd|kmDim5th|kmDim7th);
		} else {
			base += "m";
			steps&= ~kmMin3rd;
		}
	//	
	// +
	//
	steps &= ~(kmUnison | kmMaj3rd | km5th);
	if (steps == kmAug5th) {
		ext += "+";
		steps= 0;
	}
	//
	// Maj
	//
	if (steps & kmMaj7th) {
		ext += "Maj";
		steps&= ~kmMaj7th;
		steps|= kmMin7th; // Write out the 7 for clarification
	}
	//
	// 6/9
	//
	if ((steps & (kmDim7th|kmMaj9th)) == (kmDim7th|kmMaj9th)) {
		ext += "69";
		steps&= ~(kmDim7th|kmMaj9th);
	}
	//
	// Other extensions. Only the highest unaltered extension is listed.
	//
	bool has7th = steps & (kmMin7th|kmMaj7th);
	bool has9th	= steps & (kmMin9th|kmMaj9th|kmAug9th);
	if ((steps & kmMaj13th) && has7th && has9th ) {	
		ext 	+= kStepNames[kMaj13th];
		steps	&= ~(kmMin7th | kmMaj9th | km11th | kmMaj13th);
	} else if ((steps & km11th) && has7th && has9th) {
		ext 	+= kStepNames[k11th];
		steps	&= ~(kmMin7th | kmMaj9th | km11th);
	} else if ((steps & kmMaj9th) && has7th) {
		ext 	+= kStepNames[kMaj9th];
		steps	&= ~(kmMin7th | kmMaj9th);
	} else if (steps & kmMin7th) {
		ext		+= kStepNames[kMin7th];
		steps   &= ~(kmMin7th);
	}
		
	for (int step = kMin2nd; steps; ++step) 
		if (steps & (1 << step)) {
			if ((1 << step) & (kmMaj9th|km11th|kmMaj13th))
				ext += "add";
			ext += kStepNames[step];
			steps &= ~(1 << step);
		}
	//
	// Root
	//
	if (fRootPitch != kNoPitch)
		root = PitchName(fRootPitch, useSharps);
}

VLMeasure::VLMeasure()
	: fBreak(0), fPropIdx(0)
{
}

bool VLMeasure::IsEmpty() const
{
	return fChords.size() == 1 && fMelody.size() == 1
		&& fChords.front().fPitch == VLNote::kNoPitch
		&& fMelody.front().fPitch == VLNote::kNoPitch;
}

bool VLMeasure::NoChords() const
{
	return fChords.size() == 1 
		&& fChords.front().fPitch == VLNote::kNoPitch;
}

void VLMeasure::DecomposeNotes(const VLProperties & prop, VLNoteList & decomposed) const
{
	decomposed.clear();

	const VLFraction kQuarterDur(1,4);
	const VLFraction kEighthLoc(1,8);
	const VLFraction kQuarTripLoc(1,6);

	VLFraction 	at(0);
	VLNoteList::const_iterator 	i 	= fMelody.begin();
	VLNoteList::const_iterator 	e 	= fMelody.end();
	int			prevTriplets	    = 0;
	int			prevVisual;
	VLFraction  prevTripDur;

	while (i!=e) {	
		VLNoteList::const_iterator 	n 	= i;
		++n;
		
		VLLyricsNote c	= *i;	// Current note, remaining duration
		VLLyricsNote p  = c;	// Next partial note
		do {
			//
			// Start with longest possible note
			//
			p.MakeRepresentable(); 
			//
			// Prefer further triplets
			//
			if (prevTriplets) {
				if (p.fDuration >= 2*prevTripDur) {
					p.fDuration = 2*prevTripDur;
					if (prevTriplets == 1) {
						p.fVisual   = prevVisual-1;
						prevTriplets = 2; // 1/8th, 1/4th triplet or similar
					} else {
						p.fDuration = prevTripDur; // 1/8th, 1/8th, 1/4th
						p.fVisual   = prevVisual;
					}
					goto haveDuration;
				} else if (p.fDuration >= prevTripDur) {
					p.fDuration	= prevTripDur;
					p.fVisual   = prevVisual;
					goto haveDuration;
				} else if (p.fDuration >= prevTripDur/2) {
					p.fDuration = prevTripDur/2;
					p.fVisual   = prevVisual+1; 
					prevTripDur	/= 2;
					if (prevTriplets == 1) 
						prevTriplets = 2;	// 1/4th, 1/8th
					else 
						prevTriplets = 1; 	// 1/4th, 1/4th, 1/8th
					goto haveDuration;
				}
				prevTriplets = 0;
			}
			if (at.fDenom > 4) { 
				//
				// Break up notes not starting on quarter beat
				//  - Never cross middle of measure
				//
				VLFraction middle;
				if (prop.fTime.fNum & 1) // Treat 5/4 as 3+2, not 2+3
					middle = VLFraction((prop.fTime.fNum+1)/2, prop.fTime.fDenom);
				else
					middle = prop.fTime / 2;
				if (at < middle) 
					p.AlignToGrid(at, middle);
				VLFraction inBeat = at % kQuarterDur;
				if ((inBeat == kEighthLoc || inBeat == kQuarTripLoc)
				 && p.fDuration == kQuarterDur
				)
					; // Allow syncopated quarters
				else
					p.AlignToGrid(inBeat, kQuarterDur); // Align all others
			}
			if (p.fVisual & VLNote::kTriplet) {
				//
				// Distinguish swing 8ths/16ths from triplets
				//
				bool	   swing16 =  prop.fDivisions >= 6;
				VLFraction sw6(1,6);
				VLFraction sw12(1,12);
				VLFraction sw24(1,24);
				VLFraction grid4(1, 4);
				VLFraction grid8(1, 8);
				if ((p.fDuration == sw6 && (at % grid4 == 0)) 
				 || (swing16 && p.fDuration == sw12 && (at % grid8 == 0))
				) {
					if (p.fDuration == c.fDuration && n!=e 
					 && n->fDuration == p.fDuration
					) {
						; // Triplet, not swing note
					} else {
						//
						// First swing note (4th triplet -> 8th)
						//
						p.fVisual = (p.fVisual+1) & VLNote::kNoteHead;
					}
				} else if ((p.fDuration == sw12 && ((at+p.fDuration) % grid4 == 0))
				 || (swing16 && p.fDuration == sw24 && ((at+p.fDuration) % grid8 == 0))
				) {
					//
					// Second swing note (8th triplet -> 8th)
					//
					p.fVisual &= VLNote::kNoteHead;
				} else if ((at % p.fDuration != 0)
				  || (p.fDuration != c.fDuration 
				   && 2*p.fDuration != c.fDuration)
				) {
					//
					// Get rid of awkward triplets
					//
					p.fDuration *= VLFraction(3,4);
					p.fVisual    = (p.fVisual+1) & VLNote::kNoteHead;
				}
			}
		haveDuration:
			if (p.fVisual & VLNote::kTriplet) 
				if (prevTriplets = (prevTriplets+1)%3) {
					prevTripDur = p.fDuration;
					prevVisual  = p.fVisual;
				}
			p.fTied &= VLNote::kTiedWithPrev;
			if (p.fDuration == c.fDuration) 
				p.fTied |= c.fTied & VLNote::kTiedWithNext;
			else
				p.fTied |= VLNote::kTiedWithNext;
			if (p.fPitch == VLNote::kNoPitch)
				p.fTied = VLNote::kNotTied;
			decomposed.push_back(p);
			at			+= p.fDuration;
			c.fDuration	-= p.fDuration;
			p.fDuration  = c.fDuration;
			p.fTied |= VLNote::kTiedWithPrev;
			p.fLyrics.clear();
		} while (c.fDuration > 0);
		i = n;
	}
}

VLSong::VLSong(bool initialize)
{
	if (!initialize)
		return;

	const VLFraction 	fourFour(4,4);
	VLProperties 		defaultProperties = {fourFour, 0, 1, 3, "Swing"};
	
	fProperties.push_back(defaultProperties);

	AddMeasure();

	fGoToCoda	= -1;
	fCoda		= -1;
}

void VLSong::AddMeasure()
{
	VLFraction		dur  = fProperties.back().fTime;
	dur.Normalize();
	VLLyricsNote 	rest(dur);
	VLChord 		rchord(dur);
	VLMeasure meas;
	
	meas.fChords.push_back(rchord);
	meas.fMelody.push_back(rest);

	fMeasures.push_back(meas);
}

void VLSong::swap(VLSong & other)
{
	fProperties.swap(other.fProperties);
	fMeasures.swap(other.fMeasures);
	fRepeats.swap(other.fRepeats);
	std::swap(fGoToCoda, other.fGoToCoda);
	std::swap(fCoda, other.fCoda);
}

void VLSong::clear()
{
	fProperties.resize(1);
	fMeasures.clear();
	fRepeats.clear();
	
	fGoToCoda	= -1;
	fCoda		= -1;
}

//
// Deal with chords - a bit simpler
//
void VLSong::AddChord(VLChord chord, size_t measure, VLFraction at)
{
	//	
	// Always keep an empty measure in reserve
	//
	while (measure+1 >= fMeasures.size())
		AddMeasure();

	VLChordList::iterator i = fMeasures[measure].fChords.begin();
	VLFraction			  t(0);

	for (;;) {
		VLFraction tEnd = t+i->fDuration;
		if (tEnd > at) {
			if (t == at) {
				//
				// Exact match, replace current
				//
				chord.fDuration = i->fDuration;
				*i				= chord;
			} else {
				//
				// Overlap, split current
				//
				chord.fDuration = tEnd-at;
				i->fDuration	= at-t;
				fMeasures[measure].fChords.insert(++i, chord);
			}
			break; // Exit here
		}
		t = tEnd;
		++i;
	}
}

void VLSong::DelChord(size_t measure, VLFraction at)
{
	VLChordList::iterator i = fMeasures[measure].fChords.begin();
	VLFraction			  t(0);

	for (;;) {
		if (t == at) {
			// 
			// Found it. Extend previous or make rest
			//
			if (i != fMeasures[measure].fChords.begin()) {
				//
				// Extend previous
				//
				VLChordList::iterator j = i;
				--j;
				j->fDuration += i->fDuration;
				fMeasures[measure].fChords.erase(i);
			} else {
				//
				// Turn into rest
				//
				i->fPitch	= VLNote::kNoPitch;
			}
			break;
		}
		VLFraction tEnd = t+i->fDuration;
		if (tEnd > at) 
			break; // Past the point, quit
		t = tEnd;
		++i;
	}
	//
	// Trim excess empty measures
	//
	if (measure == fMeasures.size()-2 && fMeasures[measure].IsEmpty())
		fMeasures.pop_back();
}

uint8_t & FirstTie(VLMeasure & measure)
{
	VLNoteList::iterator i = measure.fMelody.begin();
	return i->fTied;
}

uint8_t & LastTie(VLMeasure & measure)
{
	VLNoteList::iterator i = measure.fMelody.end();
	--i;
	return i->fTied;
}

//
// Dealing with notes is similar, but we also have to handle ties
//
void VLSong::AddNote(VLLyricsNote note, size_t measure, VLFraction at)
{
	//	
	// Always keep an empty measure in reserve
	//
	while (measure+1 >= fMeasures.size())
		AddMeasure();

	VLNoteList::iterator	i = fMeasures[measure].fMelody.begin();
	VLFraction			  	t(0);

	for (;;) {
		VLFraction tEnd = t+i->fDuration;
		if (tEnd > at) {
			if (t == at) {
				//
				// Exact match, replace current
				//
				if (i->fTied) {
					//
					// Break ties
					//
					if (i->fTied & VLNote::kTiedWithPrev) 
						LastTie(fMeasures[measure-1]) &= ~VLNote::kTiedWithNext;
					if (i->fTied & VLNote::kTiedWithNext) 
						FirstTie(fMeasures[measure+1]) &= ~VLNote::kTiedWithPrev;
				}
				note.fDuration 	= i->fDuration;
				*i				= note;
			} else {
				//
				// Overlap, split current
				//
				note.fDuration 	= tEnd-at;
				i->fDuration	= at-t;
				i = fMeasures[measure].fMelody.insert(++i, note);
			}
			if (i->fPitch == VLNote::kNoPitch) {
				//
				// Merge with adjacent rests
				//
				if (i != fMeasures[measure].fMelody.begin()) {
					VLNoteList::iterator j = i;
					--j;
					if (j->fPitch == VLNote::kNoPitch) {
						j->fDuration += i->fDuration;
						fMeasures[measure].fMelody.erase(i);
						i = j;
					}
				}
				VLNoteList::iterator j = i;
				++j;
				if (j != fMeasures[measure].fMelody.end() && j->fPitch == VLNote::kNoPitch) {
					i->fDuration += j->fDuration;
					fMeasures[measure].fMelody.erase(j);
				}
			}
			break; // Exit here
		}
		t = tEnd;
		++i;
	}
	i->fTied = 0;
	if (note.fTied & VLNote::kTiedWithPrev) // kTiedWithNext is NEVER user set
		if (measure && i == fMeasures[measure].fMelody.begin()) {
			VLNoteList::iterator	j = fMeasures[measure-1].fMelody.end();
			--j;
			if (j->fPitch == i->fPitch) {
				j->fTied |= VLNote::kTiedWithNext;
				i->fTied |= VLNote::kTiedWithPrev;
			}
		}	
}

void VLSong::DelNote(size_t measure, VLFraction at)
{
	VLNoteList::iterator i = fMeasures[measure].fMelody.begin();
	VLFraction			  t(0);

	for (;;) {
		if (t == at) {
			// 
			// Found it. Break ties.
			//
			if (i->fTied & VLNote::kTiedWithNext)
				FirstTie(fMeasures[measure+1]) &= ~VLNote::kTiedWithPrev;
			if (i->fTied & VLNote::kTiedWithPrev)
				LastTie(fMeasures[measure-1]) &= ~VLNote::kTiedWithNext;
			//
			// Extend previous or make rest
			//
			if (i != fMeasures[measure].fMelody.begin()) {
				//
				// Extend previous
				//
				VLNoteList::iterator j = i;
				--j;
				j->fDuration += i->fDuration;
				fMeasures[measure].fMelody.erase(i);
			} else {
				//
				// Merge with next if it's a rest, otherwise, just turn into rest
				//
				VLNoteList::iterator j = i;
				++j;
				if (j != fMeasures[measure].fMelody.end() && j->fPitch == VLNote::kNoPitch) {	
					i->fDuration += j->fDuration;
					fMeasures[measure].fMelody.erase(j);
				}
				i->fPitch	= VLNote::kNoPitch;
				i->fTied	= 0;				
			} 
			break;
		}
		VLFraction tEnd = t+i->fDuration;
		if (tEnd > at) 
			break; // Past the point, quit
		t = tEnd;
		++i;
	}
	//
	// Trim excess empty measures
	//
	if (measure == fMeasures.size()-2 && fMeasures[measure].IsEmpty())
		fMeasures.pop_back();
}

void VLSong::ExtendNote(size_t measure, VLFraction at)
{
	VLNoteList::iterator i 	= fMeasures[measure].fMelody.begin();
	VLNoteList::iterator end= fMeasures[measure].fMelody.end();
	
	for (VLFraction t(0); i != end && t+i->fDuration <= at; ++i) 
		t += i->fDuration;

	if (i == end)
		--i;
	if (i->fPitch == VLNote::kNoPitch)
		return; // Don't extend rests

	for (;;) {
		VLNoteList::iterator j=i;
		++j;
		if (j != fMeasures[measure].fMelody.end()) {
			//
			// Extend across next note/rest
			//
			i->fDuration += j->fDuration;
			fMeasures[measure].fMelody.erase(j);				
		} else if (++measure < fMeasures.size()) { 
			//
			// Extend into next measure
			//
			VLNoteList::iterator k = fMeasures[measure].fMelody.begin();
			if (k->fTied & VLNote::kTiedWithPrev) {
				//
				// Already extended, extend further
				//
				i = k;
				continue; // Go for another spin
			} else {
				for (;;) {
					bool wasTied = k->fTied & VLNote::kTiedWithNext;
					//
					// Extend previous note
					//
					k->fPitch = i->fPitch;
					k->fTied  = VLNote::kTiedWithPrev;
					i->fTied |= VLNote::kTiedWithNext;
					k->fLyrics.clear();
					if (!wasTied) 
						break;
					i = k;
					k = fMeasures[++measure].fMelody.begin();
				}
			}
			if (measure+1 == fMeasures.size())
				AddMeasure();
		}
		break;
	} 
}

bool VLSong::IsNonEmpty() const
{
	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		VLNoteList::const_iterator i = fMeasures[measure].fMelody.begin();
		VLNoteList::const_iterator e = fMeasures[measure].fMelody.end();
		
		for (; i!=e; ++i) 
			if (i->fPitch != VLNote::kNoPitch)
				return true;
	}
	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		VLChordList::const_iterator i = fMeasures[measure].fChords.begin();
		VLChordList::const_iterator e = fMeasures[measure].fChords.end();

		for (; i!=e; ++i) 
			if (i->fPitch != VLNote::kNoPitch)
				return true;
	}
	return false;
}

static void TransposePinned(int8_t & pitch, int semi)
{
	if (pitch == VLNote::kNoPitch)
		return;

	int pitchInOctave = pitch % 12;
	int octave		  = pitch-pitchInOctave;
	pitchInOctave	 += semi;
	if (pitchInOctave < 0)
		pitch		  = octave+pitchInOctave+12;
	else if (pitchInOctave > 11)
		pitch		  = octave+pitchInOctave-12;
	else
		pitch 		  = octave+pitchInOctave;
}

void VLSong::ChangeKey(int section, int newKey, int newMode, bool transpose)
{
	VLProperties & prop = fProperties[section];
	int semi 	= 7*(newKey-prop.fKey) % 12;
	prop.fKey 	= newKey;
	prop.fMode	= newMode;	
	if (!transpose)
		return;

	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		if (fMeasures[measure].fPropIdx != section)
			continue;

		VLChordList::iterator i = fMeasures[measure].fChords.begin();
		VLChordList::iterator e = fMeasures[measure].fChords.end();

		for (; i!=e; ++i) {
			TransposePinned(i->fPitch, semi);
			TransposePinned(i->fRootPitch, semi);
		}
	}
	for (int pass=0; pass<2 && semi;) {
		int8_t low		= 127;
		int8_t high	= 0;
		for (size_t measure=0; measure<fMeasures.size(); ++measure) {
			if (fMeasures[measure].fPropIdx != section)
				continue;

			VLNoteList::iterator i = fMeasures[measure].fMelody.begin();
			VLNoteList::iterator e = fMeasures[measure].fMelody.end();

			for (; i!=e; ++i) {
				if (i->fPitch == VLNote::kNoPitch)
					continue;
				i->fPitch	+= semi;
				low			 = std::min(low, i->fPitch);
				high		 = std::max(high, i->fPitch);
			}
		}
		if (low < VLNote::kMiddleC-6 && high < VLNote::kMiddleC+7)
			semi	= 12;	// Transpose an Octave up
		else if (low > VLNote::kMiddleC+7 && high > VLNote::kMiddleC+16)
			semi 	= -12;	// Transpose an Octave down
		else
			break;			// Looks like we're done
	}
}

//
// We try a table based approach for converting the beginning and end of
// notes
//

static const uint8_t sDiv2_3[] = {0, 2};
static const uint8_t sDiv2_4[] = {0, 2};
static const uint8_t sDiv2_6[] = {0, 3};
static const uint8_t sDiv2_8[] = {0, 4};
static const uint8_t sDiv2_12[]= {0, 6};
static const uint8_t * sDiv2[] = {
	          NULL,     sDiv2_3,  sDiv2_4,  NULL,     sDiv2_6,  
	NULL,     sDiv2_8,  NULL,     NULL,     NULL,     sDiv2_12};

static const uint8_t sDiv3_2[] = {0, 1, 1};
static const uint8_t sDiv3_4[] = {0, 2, 3};
static const uint8_t sDiv3_6[] = {0, 2, 4};
static const uint8_t sDiv3_8[] = {0, 3, 6};
static const uint8_t sDiv3_12[]= {0, 4, 8};
static const uint8_t * sDiv3[] = {
	          sDiv3_2,  NULL,     sDiv3_4,  NULL,     sDiv3_6,  
	NULL,     sDiv3_8,  NULL,     NULL,     NULL,     sDiv3_12};
	   
static const uint8_t sDiv4_2[] = {0, 0, 1, 1};
static const uint8_t sDiv4_3[] = {0, 1, 2, 2};
static const uint8_t sDiv4_6[] = {0, 2, 3, 5};
static const uint8_t sDiv4_8[] = {0, 2, 4, 6};
static const uint8_t sDiv4_12[]= {0, 3, 6, 9};
static const uint8_t * sDiv4[] = {
	          sDiv4_2,  sDiv4_3,  NULL,     NULL,     sDiv4_6,  
	NULL,     sDiv4_8,  NULL,     NULL,     NULL,     sDiv4_12};

static const uint8_t sDiv6_2[] = {0, 0, 0, 1, 1, 1};
static const uint8_t sDiv6_3[] = {0, 0, 1, 1, 2, 2};
static const uint8_t sDiv6_4[] = {0, 1, 2, 2, 3, 3};
static const uint8_t sDiv6_8[] = {0, 2, 3, 4, 6, 7};
static const uint8_t sDiv6_12[]= {0, 2, 4, 6, 8,10};
static const uint8_t * sDiv6[] = {
	          sDiv6_2,  sDiv6_3,  sDiv6_4,  NULL,     NULL,  
	NULL,     sDiv6_8,  NULL,     NULL,     NULL,     sDiv6_12};

static const uint8_t sDiv8_2[] = {0, 0, 0, 0, 1, 1, 1, 1};
static const uint8_t sDiv8_3[] = {0, 0, 1, 1, 1, 2, 2, 2};
static const uint8_t sDiv8_4[] = {0, 0, 1, 1, 2, 2, 3, 3};
static const uint8_t sDiv8_6[] = {0, 1, 2, 2, 3, 4, 5, 5};
static const uint8_t sDiv8_12[]= {0, 2, 3, 5, 6, 8, 9,11};
static const uint8_t * sDiv8[] = {
	          sDiv8_2,  sDiv8_3,  sDiv8_4,  NULL,     sDiv8_6,  
	NULL,     NULL,     NULL,     NULL,     NULL,     sDiv8_12};

static const uint8_t sDiv12_2[]= {0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1};
static const uint8_t sDiv12_3[]= {0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2};
static const uint8_t sDiv12_4[]= {0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3};
static const uint8_t sDiv12_6[]= {0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5};
static const uint8_t sDiv12_8[]= {0, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 7};
static const uint8_t * sDiv12[]= {
	          sDiv12_2, sDiv12_3, sDiv12_4, NULL,     sDiv12_6,  
	NULL,     sDiv12_8, NULL,     NULL,     NULL,     NULL};

static const uint8_t ** sDiv[]  = {
	        sDiv2,  sDiv3,  sDiv4,  NULL,   sDiv6,
	NULL,   sDiv8,  NULL,   NULL,   NULL,   sDiv12};

class VLRealigner {
public:
	VLRealigner(int oldDiv, int newDiv);

	VLFraction operator()(VLFraction at);
private:
	VLFraction		fOldFrac;
	VLFraction  	fNewFrac;
	const uint8_t *	fTable;
};

VLRealigner::VLRealigner(int oldDiv, int newDiv)
	: fOldFrac(1, 4*oldDiv), fNewFrac(1, 4*newDiv), 
	  fTable(sDiv[oldDiv-2][newDiv-2])
{
}

VLFraction VLRealigner::operator()(VLFraction at)
{
	VLFraction quarters(4*at.fNum / at.fDenom, 4);
	at   = (at-quarters) / fOldFrac;
	
	return quarters + fTable[at.fNum / at.fDenom]*fNewFrac;
}

static VLChordList Realign(const VLChordList & chords, 
						   const VLProperties& fromProp,
						   const VLProperties& toProp)
{
	if (fromProp.fTime == toProp.fTime)
		return chords;
	if (fromProp.fTime < toProp.fTime) {
		VLChord	rchord(toProp.fTime-fromProp.fTime);
		VLChordList newChords(chords);
		newChords.push_back(rchord);

		return newChords;
	} else {
		VLChordList::const_iterator i = chords.begin();
		VLChordList::const_iterator e = chords.end();
		VLFraction 	at(0);
		VLChordList	newChords;

		for (; i!=e; ++i) {
			VLChord	c = *i;
			if (at+c.fDuration >= toProp.fTime) {
				if (at < toProp.fTime) {
					c.fDuration = toProp.fTime-at;
					newChords.push_back(c);
				}
				break;
			} else {
				newChords.push_back(c);
				at += c.fDuration;
			}
		}

		return newChords;
	}
}

static VLNoteList Realign(const VLNoteList & notes, 
						  const VLProperties& fromProp,
						  const VLProperties& toProp)
{
	if (fromProp.fTime == toProp.fTime && fromProp.fDivisions == toProp.fDivisions)
		return notes;
	VLNoteList newNotes(notes);
	if (fromProp.fTime < toProp.fTime) {
		VLNote	rest(toProp.fTime-fromProp.fTime);
		newNotes.push_back(rest);
	} else if (fromProp.fTime > toProp.fTime) {
		VLNoteList::const_iterator i = notes.begin();
		VLNoteList::const_iterator e = notes.end();
		VLFraction 	at(0);

		for (; i!=e; ++i) {
			VLNote	n = *i;
			if (at+n.fDuration >= toProp.fTime) {
				if (at < toProp.fTime) {
					n.fDuration = toProp.fTime-at;
					newNotes.push_back(n);
				}
				break;
			} else {
				newNotes.push_back(n);
				at += n.fDuration;
			}
		}
	}	
	if (fromProp.fDivisions != toProp.fDivisions) {
		VLRealigner realign(fromProp.fDivisions, toProp.fDivisions);

		VLNoteList alignedNotes;
		VLFraction at(0);
		VLFraction lastAt;

		VLNoteList::iterator i = newNotes.begin();
		VLNoteList::iterator e = newNotes.end();

		for (; i!=e; ++i) {
			VLLyricsNote n 		= *i;
			VLFraction 	 newAt 	= realign(at);
			if (alignedNotes.empty()) {
				alignedNotes.push_back(n);
				lastAt	= newAt;
			} else if (newAt != lastAt) {
				alignedNotes.back().fDuration = newAt-lastAt;
				alignedNotes.push_back(n);
				lastAt	= newAt;
			}
			at += n.fDuration;
		}
		if (lastAt == at)
			alignedNotes.pop_back();
		else
			alignedNotes.back().fDuration = at-lastAt;

		return alignedNotes;
	} else
		return newNotes;
}

void VLSong::ChangeDivisions(int section, int newDivisions)
{
	VLProperties & prop = fProperties[section];
	if (prop.fDivisions == newDivisions)
		return; // Unchanged
	VLProperties newProp = prop;
	newProp.fDivisions   = newDivisions;

	//
	// Only melody needs to be realigned, chords are already quarter notes
	//
	for (size_t measure=0; measure<fMeasures.size(); ++measure) 
		if (fMeasures[measure].fPropIdx == section)
			fMeasures[measure].fMelody = 
				Realign(fMeasures[measure].fMelody, prop, newProp);
	prop = newProp;
}

void VLSong::ChangeTime(int section, VLFraction newTime)
{
	VLProperties & prop = fProperties[section];
	if (prop.fTime == newTime)
		return; // No change
	VLProperties newProp = prop;
	newProp.fTime   = newTime;
	for (size_t measure=0; measure<fMeasures.size(); ++measure) 
		if (fMeasures[measure].fPropIdx == section) {
			fMeasures[measure].fChords = 
				Realign(fMeasures[measure].fChords, prop, newProp);
			fMeasures[measure].fMelody = 
				Realign(fMeasures[measure].fMelody, prop, newProp);
		}
	prop = newProp;
}

size_t VLSong::EmptyEnding() const
{
	size_t full = fMeasures.size();

	while (full-- && fMeasures[full].IsEmpty() 
		   && !DoesEndRepeat(full+1, 0) && !DoesEndEnding(full+1, 0, 0)
	)
		;

	return fMeasures.size()-(full+1);
}

size_t VLSong::CountStanzas() const
{
	size_t stanzas = 0;

	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		VLNoteList::const_iterator i 	= fMeasures[measure].fMelody.begin();
		VLNoteList::const_iterator e 	= fMeasures[measure].fMelody.end();

		for (; i!=e; ++i) 
			if (i->fLyrics.size() > stanzas)
				for (size_t s = stanzas; s < i->fLyrics.size(); ++s)
					if (i->fLyrics[s])
						stanzas = s+1;
	}

	return stanzas;
}

size_t VLSong::CountTopLedgers() const
{
	int8_t maxPitch = VLNote::kMiddleC;

	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		VLNoteList::const_iterator i 	= fMeasures[measure].fMelody.begin();
		VLNoteList::const_iterator e 	= fMeasures[measure].fMelody.end();

		for (; i!=e; ++i) 
			if (i->fPitch != VLNote::kNoPitch)
				maxPitch = std::max(maxPitch, i->fPitch);
	}

	if (maxPitch > 89)		// F''
		return 4;
	else if (maxPitch > 86) // D''
		return 3;
	else if (maxPitch > 83) // B'
		return 2;
	else if (maxPitch > 79) // G'
		return 1;
	else
		return 0;
}

size_t VLSong::CountBotLedgers() const
{
	int8_t minPitch = VLNote::kMiddleC+VLNote::kOctave;

	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		VLNoteList::const_iterator i 	= fMeasures[measure].fMelody.begin();
		VLNoteList::const_iterator e 	= fMeasures[measure].fMelody.end();

		for (; i!=e; ++i) 
			if (i->fPitch != VLNote::kNoPitch)
				minPitch = std::min(minPitch, i->fPitch);
	}
	
	if (minPitch < 52) 		// E,
		return 4;
	else if (minPitch < 55)	// G,
		return 3;
	else if (minPitch < 59)	// B,
		return 2;
	else if (minPitch < 62) // D
		return 1;
	else
		return 0;
}

bool VLSong::FindWord(size_t stanza, size_t & measure, VLFraction & at)
{
	at += VLFraction(1,64);
	return PrevWord(stanza, measure, at);
}

bool VLSong::PrevWord(size_t stanza, size_t & measure, VLFraction & at)
{
	do {
		VLMeasure & 			meas	= fMeasures[measure];
		VLNoteList::iterator 	note 	= fMeasures[measure].fMelody.begin();
		VLNoteList::iterator 	end  	= fMeasures[measure].fMelody.end();
		bool					hasWord	= false;
		VLFraction				word(0);
		VLFraction				now(0);

		while (note != meas.fMelody.end() && now < at) {
			if (note->fPitch != VLNote::kNoPitch)
				if (note->fLyrics.size() < stanza 
			     || !(note->fLyrics[stanza-1].fKind & VLSyllable::kHasPrev)
				) {
					word	= now;
					hasWord	= true;
				}
			now += note->fDuration;
			++note;
		}
		if (hasWord) {
			at	= word;
			
			return true;
		} else {
			at 	= fProperties[meas.fPropIdx].fTime;
		}
	} while (measure-- > 0);
	
	measure = 0;

	return false;
}

bool VLSong::NextWord(size_t stanza, size_t & measure, VLFraction & at)
{  
	bool firstMeasure = true;
	do {
		VLMeasure & 			meas	= fMeasures[measure];
		VLNoteList::iterator 	note 	= fMeasures[measure].fMelody.begin();
		VLNoteList::iterator 	end  	= fMeasures[measure].fMelody.end();
		VLFraction				now(0);

		while (note != meas.fMelody.end()) {
			if (note->fPitch != VLNote::kNoPitch && (!firstMeasure || now>at))
				if (note->fLyrics.size() < stanza 
			     || !(note->fLyrics[stanza-1].fKind & VLSyllable::kHasPrev)
				) {
					at	= now;
					
					return true;
				}
			now += note->fDuration;
			++note;
		}
		firstMeasure = false;
	} while (++measure < fMeasures.size());

	return false;
}

std::string VLSong::GetWord(size_t stanza, size_t measure, VLFraction at)
{
	std::string word;

	while (measure < fMeasures.size()) {
		VLMeasure & 			meas	= fMeasures[measure];
		VLNoteList::iterator 	note 	= meas.fMelody.begin();
		VLNoteList::iterator 	end  	= meas.fMelody.end();
		VLFraction				now(0);

		while (note != end) {
			if (now >= at && note->fPitch != VLNote::kNoPitch
				&& !(note->fTied & VLNote::kTiedWithPrev)
			) {
				if (word.size()) 
					word += '-';
				if (stanza <= note->fLyrics.size()) {
					word += note->fLyrics[stanza-1].fText;
					if (!(note->fLyrics[stanza-1].fKind & VLSyllable::kHasNext))
						return word;
				}
			}
			now += note->fDuration;
			++note;
		}	
		at = 0;
		++measure;
	} 
	
	return word;
}

void VLSong::SetWord(size_t stanza, size_t measure, VLFraction at, std::string word, size_t * nextMeas, VLFract * nextAt)
{
	//	
	// Always keep an empty measure in reserve
	//
	while (measure+1 >= fMeasures.size())
		AddMeasure();

	uint8_t	kind = 0;
	bool	cleanup = false;

	do {
		VLMeasure & 			meas	= fMeasures[measure];
		VLNoteList::iterator 	note 	= fMeasures[measure].fMelody.begin();
		VLNoteList::iterator 	end  	= fMeasures[measure].fMelody.end();
		VLFraction				now(0);

		while (note != meas.fMelody.end()) {
			if (now >= at && note->fPitch != VLNote::kNoPitch
				&& !(note->fTied & VLNote::kTiedWithPrev)
			) {
				if (cleanup) {
					//
					// Make sure that following syllable doesn't have
					// kHasPrev set
					//
					if (note->fLyrics.size() >= stanza)
						note->fLyrics[stanza-1].fKind &= ~VLSyllable::kHasPrev;
					
					if (nextMeas)
						*nextMeas = measure;
					if (nextAt)
						*nextAt	  = now;

					return;
				}
				if (note->fLyrics.size()<stanza)
					note->fLyrics.resize(stanza);
				size_t sep = word.find_first_of(" \t-");
				size_t esp;
				std::string syll;
				char   type= 0;
				if (sep == std::string::npos) {
					esp = sep;
					syll= word;
				} else {
					esp = word.find_first_not_of(" \t-", sep);
					syll= word.substr(0, sep);
					if (esp != std::string::npos) {
						size_t tpos = word.substr(sep, esp-sep).find('-');
						type = (tpos != std::string::npos) ? '-' : ' ';
						word.erase(0, esp);
					}
				}
				switch (type) {
				default:
					//
					// Last syllable in text
					//
					kind   &= ~VLSyllable::kHasNext;
					cleanup = true;
					break;
				case ' ':
					//
					// Last syllable in word
					//
					kind 	&= ~VLSyllable::kHasNext;	
					break;
				case '-':
					kind   |= VLSyllable::kHasNext;
					break;
				}
				note->fLyrics[stanza-1].fText = syll;
				note->fLyrics[stanza-1].fKind = kind;
				if (type == '-')
					kind |= VLSyllable::kHasPrev;
				else 
					kind &= ~VLSyllable::kHasPrev;
			}
			now += note->fDuration;
			++note;
		}	
		at = 0;
	} while (++measure < fMeasures.size());	
	if (nextMeas)
		*nextMeas = 0;
	if (nextAt)
		*nextAt	  = VLFraction(0);
}

void VLSong::AddRepeat(size_t beginMeasure, size_t endMeasure, int times)
{
	for (size_t r=0; r<fRepeats.size(); ++r) {
		VLRepeat & rp = fRepeats[r];
		if (rp.fEndings[0].fBegin == beginMeasure
		 && rp.fEndings[0].fEnd >= endMeasure
		) 
			if (rp.fEndings[0].fEnd == endMeasure) {
				//
				// Exact match, just change times
				//
				size_t mask = ((1<<times)-1) ^ ((1<<rp.fTimes)-1);
				if (rp.fTimes < times) 
					rp.fEndings[0].fVolta |= mask;
				else if (rp.fTimes > times) 
					for (size_t e=0; e<rp.fEndings.size(); ++e)
						rp.fEndings[e].fVolta &= ~mask;
				rp.fTimes = times; 

				return;
			} else {
				fRepeats.erase(fRepeats.begin()+r);
			
				break;
			}
	}
	
	VLRepeat	rep;

	rep.fTimes	= times;
	rep.fEndings.push_back(VLRepeat::Ending(beginMeasure, endMeasure, 
											(1<<times)-1));
	fRepeats.push_back(rep);
}

void VLSong::DelRepeat(size_t beginMeasure, size_t endMeasure)
{
	for (size_t r=0; r<fRepeats.size(); ++r) {
		VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin == beginMeasure
		 && rp.fEndings[0].fEnd >= endMeasure
		) {
			fRepeats.erase(fRepeats.begin()+r);
			
			break;
		}
	}
}

void VLSong::AddEnding(size_t beginMeasure, size_t endMeasure, size_t volta)
{
	for (size_t r=0; r<fRepeats.size(); ++r) {
		VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin < beginMeasure
		 && rp.fEndings[0].fEnd >= beginMeasure
		) {
			for (size_t e=1; e<rp.fEndings.size(); ++e)
				if (rp.fEndings[e].fBegin == beginMeasure
				 && rp.fEndings[e].fEnd	== endMeasure
				) {
					//
					// Found it, just edit volta
					//
					rp.fEndings[0].fVolta |= rp.fEndings[e].fVolta;
					volta &= rp.fEndings[0].fVolta;
					rp.fEndings[0].fVolta &= ~volta;
					rp.fEndings[e].fVolta  = volta;

					return;
				}
			//
			// Not found, add new ending
			//		    
			volta &= rp.fEndings[0].fVolta;
			rp.fEndings[0].fVolta &= ~volta;
			rp.fEndings[0].fEnd 	= 
				std::max<int8_t>(rp.fEndings[0].fEnd, endMeasure);
			rp.fEndings.push_back(
                VLRepeat::Ending(beginMeasure, endMeasure, volta));
			
			return;
		}
	}
}

void VLSong::DelEnding(size_t beginMeasure, size_t endMeasure)
{
	for (size_t r=0; r<fRepeats.size(); ++r) {
		VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin <= beginMeasure
		 && rp.fEndings[0].fEnd > beginMeasure
		) 
			for (size_t e=1; e<rp.fEndings.size(); ++e)
				if (rp.fEndings[e].fBegin == beginMeasure) {
					rp.fEndings[0].fVolta |= rp.fEndings[e].fVolta;
					if (e > 1 && e == rp.fEndings.size()-1) 
						rp.fEndings[0].fEnd = rp.fEndings[e].fBegin;
					rp.fEndings.erase(rp.fEndings.begin()+e);
				}
	}
}

bool VLSong::CanBeRepeat(size_t beginMeasure, size_t endMeasure, int * times)
{
	for (size_t r=0; r<fRepeats.size(); ++r) { 
		VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin == beginMeasure) {
			//
			// Look for exact match & return
			//
			if (times)
				*times = rp.fTimes;
			if (rp.fEndings[0].fEnd == endMeasure) 
				return true;
			if (rp.fEndings.size() > 1) {
				if (rp.fEndings[1].fBegin == endMeasure)
					return true;
				if (rp.fEndings[1].fEnd == endMeasure)
					return true;
			}
		}
		//
		// Inclusions and surroundings are OK. Beginnings may match, but
		// endings must not.
		//
		if (rp.fEndings[0].fBegin >= beginMeasure 
		 && rp.fEndings[0].fEnd < endMeasure
		)
			continue;
		if (rp.fEndings[0].fBegin <= beginMeasure
		 && rp.fEndings[0].fEnd > endMeasure
		)
			continue;
		//
		// Look for overlap and reject
		//
		if (rp.fEndings[0].fBegin >= beginMeasure 
         && rp.fEndings[0].fBegin < endMeasure
		)
			return false; 
		if (rp.fEndings[0].fEnd > beginMeasure 
         && rp.fEndings[0].fEnd <= endMeasure
		)
			return false; 
	}
	//
	// Virgin territory, accept
	//
	if (times)
		*times = 2;
	return true;
}

bool VLSong::CanBeEnding(size_t beginMeasure, size_t endMeasure, 
						 size_t * volta, size_t * voltaOK)
{
	for (size_t r=0; r<fRepeats.size(); ++r)  {
		VLRepeat & rp	= fRepeats[r];
		if (beginMeasure > rp.fEndings[0].fBegin
		 && beginMeasure <= rp.fEndings[0].fEnd
		) {
			//
			// Found right repeat
			//
			//
			// Append new repeat, or carve out from ending
			//
			if (beginMeasure == rp.fEndings[0].fEnd) {
				for (size_t r2=0; r2<fRepeats.size(); ++r2)
					if (r2 != r 
					 && fRepeats[r2].fEndings[0].fBegin >= beginMeasure
					 && fRepeats[r2].fEndings[0].fBegin < endMeasure
					)
						return false; // Overlap
				if (volta)
					*volta = rp.fEndings[0].fVolta;
				if (voltaOK)
					*voltaOK = rp.fEndings[0].fVolta;
				
				return true;				
			} else if (rp.fEndings.size() == 1 
			  && endMeasure >= rp.fEndings[0].fEnd
			) {
				if (volta)
					*volta = rp.fEndings[0].fVolta;
				if (voltaOK)
					*voltaOK = rp.fEndings[0].fVolta;
				
				return true;
			}
			//
			// Otherwise must match existing
			//
			for (size_t e=1; e<rp.fEndings.size(); ++e)
				if (beginMeasure == rp.fEndings[e].fBegin
				 && endMeasure == rp.fEndings[e].fEnd
				) {
					if (volta)
						*volta = rp.fEndings[e].fVolta;
					if (voltaOK)
						*voltaOK = rp.fEndings[e].fVolta 
							     | rp.fEndings[0].fVolta;
					return true;
				}
			return false;
		}
	}
	return false;
}

bool VLSong::DoesBeginRepeat(size_t measure, int * times) const
{
	for (size_t r=0; r<fRepeats.size(); ++r) {
		const VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin == measure) {
			if (times)
				*times = rp.fTimes;

			return true;
		}
	}
	return false;
}

bool VLSong::DoesEndRepeat(size_t measure, int * times) const
{
	for (size_t r=0; r<fRepeats.size(); ++r) {
		const VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fEnd == measure 
		 && rp.fEndings.size() == 1
		) {
			if (times)
				*times = rp.fTimes;

			return true;
		}
	}
	return false;	
}

bool VLSong::DoesBeginEnding(size_t measure, bool * repeat, size_t * volta) const
{
	for (size_t r=0; r<fRepeats.size(); ++r) {
		const VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin < measure
		 && rp.fEndings[0].fEnd >= measure 
		 && rp.fEndings.size() > 1
		) {
			size_t v = (1<<rp.fTimes)-1;
			for (size_t e=1; e<rp.fEndings.size(); ++e)
				if (rp.fEndings[e].fBegin == measure) {
					if (repeat)
						if (e == rp.fEndings.size()-1 
						 && rp.fEndings[e].fVolta == v
						)
							*repeat = false; // Not after last alternative
						else
							*repeat = true;
					if (volta)
						*volta = rp.fEndings[e].fVolta;

					return true;
				} else
					v &= ~rp.fEndings[e].fVolta;
			if (v && rp.fEndings[0].fEnd == measure) {
				//
				// Implied ending for all not mentioned
				//	
				if (repeat)
					*repeat = false;
				if (volta)
					*volta = v;

				return true;
			}
		}
	}
	return false;	
}

bool VLSong::DoesEndEnding(size_t measure, bool * repeat, size_t * volta) const
{
	for (size_t r=0; r<fRepeats.size(); ++r) {
		const VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin < measure
		 && rp.fEndings[0].fEnd+1 >= measure 
		 && rp.fEndings.size() > 1
		) {
			size_t v = (1<<rp.fTimes)-1;
			for (size_t e=1; e<rp.fEndings.size(); ++e)
				if (rp.fEndings[e].fEnd == measure) {
					if (repeat)
						if (e == rp.fEndings.size()-1 
						 && rp.fEndings[e].fVolta == v
						)
							*repeat = false; // Not after last alternative
						else
							*repeat = true;
					if (volta)
						*volta = rp.fEndings[e].fVolta;
					return true;
				} else
					v &= ~rp.fEndings[e].fVolta;
			if (v && rp.fEndings[0].fEnd+1 == measure) {
				//
				// Implied ending for all not mentioned
				//
				if (repeat)
					*repeat = false;
				if (volta)
					*volta  = v;

				return true;
			}
		}
	}
	return false;	
}

bool VLSong::DoesTieWithPrevRepeat(size_t measure) const
{
	if (fMeasures[measure].fMelody.front().fPitch == VLNote::kNoPitch)
		return false; // Rests don't tie
	for (size_t r=0; r<fRepeats.size(); ++r) {
		const VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin < measure 
         && rp.fEndings[0].fEnd >= measure 
		 && rp.fEndings.size() > 1
		) {
			size_t v 				= (1<<rp.fTimes)-1;
			int8_t firstEnding 		= rp.fEndings[0].fEnd;
			bool   doesStartEnding  = false;
			for (size_t e=1; e<rp.fEndings.size(); ++e) {
				firstEnding = std::min(firstEnding, rp.fEndings[e].fBegin);
				if (rp.fEndings[e].fBegin == measure) 
					doesStartEnding =  true;
				else
					v &= ~rp.fEndings[e].fVolta;
			}
			if (doesStartEnding || (v && rp.fEndings[0].fEnd == measure))
				return fMeasures[firstEnding-1].fMelody.back().fTied
					& VLNote::kTiedWithNext;
		}
	}
	return false;	
}

bool VLSong::DoesTieWithNextRepeat(size_t measure) const
{
	if (fMeasures[measure].fMelody.back().fPitch == VLNote::kNoPitch)
		return false; // Rests don't tie
	for (size_t r=0; r<fRepeats.size(); ++r) {
		const VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin < measure
		 && rp.fEndings[0].fEnd >= measure 
		 && rp.fEndings.size() > 1
		) {
			for (size_t e=1; e<rp.fEndings.size(); ++e) {
				if (rp.fEndings[e].fEnd == measure+1) 
					return !(rp.fEndings[e].fVolta & (1<<(rp.fTimes-1)))
					  && (fMeasures[rp.fEndings[0].fBegin].fMelody.front().fTied
						  & VLNote::kTiedWithPrev);
			}
		}
	}
	return false;	
}

VLSong::iterator::iterator(const VLSong & song, bool end)
	: fSong(song)
{
	if (end) {
		fMeasure	= fSong.CountMeasures()-fSong.EmptyEnding();
	} else {
		fMeasure	= 0;
		AdjustStatus();
	}
}

VLSong::iterator & VLSong::iterator::operator++()
{
	++fMeasure;
	AdjustStatus();
	
	return *this;
}

void VLSong::iterator::AdjustStatus()
{
	int 	times;
	size_t	volta;
	bool 	repeat;
	if (fSong.DoesEndRepeat(fMeasure)
	 || (fSong.DoesEndEnding(fMeasure, &repeat) && repeat)
	) {
		if (++fStatus.back().fVolta < fStatus.back().fTimes) {
			//
			// Repeat again
			//
			fMeasure = fStatus.back().fBegin;
			
			return;
		} 
	}
	if (fSong.fCoda > 0 && fMeasure==fSong.fGoToCoda)
		if (fStatus.size() && fStatus.back().fVolta == fStatus.back().fTimes-1) {
			fMeasure = fSong.fCoda;
			
			return;
		}
	if (fMeasure == fSong.CountMeasures()-fSong.EmptyEnding())
		while (fStatus.size())
			if (++fStatus.back().fVolta < fStatus.back().fTimes) {
				fMeasure = fStatus.back().fBegin;
				
				return;
			} else
				fStatus.pop_back();
	while (fSong.DoesBeginEnding(fMeasure, 0, &volta)) {
		if (!(volta & (1<<fStatus.back().fVolta))) {
			//
			// Skip this ending this time around
			//
			do {
				++fMeasure;
			} while (!fSong.DoesEndEnding(fMeasure));
		} else
			break;
	}
	if (fSong.DoesBeginRepeat(fMeasure, &times)) {
		if (fStatus.size() && fStatus.back().fVolta == fStatus.back().fTimes)
			fStatus.pop_back();
		fStatus.push_back(Repeat(fMeasure, times));
	}
}

VLSong VLSong::CopyMeasures(size_t beginMeasure, size_t endMeasure)
{
	VLSong	subSong(false);

	int8_t	firstProp	= fMeasures[beginMeasure].fPropIdx;
	int8_t	lastProp	= fMeasures[endMeasure-1].fPropIdx;
	
	subSong.fProperties.insert(subSong.fProperties.end(),
							   fProperties.begin()+firstProp, 
							   fProperties.begin()+lastProp+1);
	subSong.fMeasures.insert(subSong.fMeasures.end(),
							 fMeasures.begin()+beginMeasure,
							 fMeasures.begin()+endMeasure);

	if (firstProp)
		for (size_t i=0; i<subSong.fMeasures.size(); ++i)
			subSong.fMeasures[i].fPropIdx	-= firstProp;

	for (size_t r=0; r<fRepeats.size(); ++r) {
		VLRepeat & rp	= fRepeats[r];
		if (rp.fEndings[0].fBegin >= beginMeasure 
         && rp.fEndings[0].fEnd   <= endMeasure
		) {
			for (size_t e=0; e<rp.fEndings.size(); ++e) {
				rp.fEndings[e].fBegin	-= beginMeasure;
				rp.fEndings[e].fEnd		-= endMeasure;
			}
			subSong.fRepeats.push_back(rp);
		}
	}
	
	return subSong;
}

void VLSong::PasteMeasures(size_t beginMeasure, const VLSong & measures, int mode)
{
	size_t numMeas		= measures.CountMeasures();
	size_t nextMeasure 	= mode==kInsert ? beginMeasure : beginMeasure+numMeas;

	if (mode == kInsert) {
		int propAt     = fMeasures[beginMeasure].fPropIdx;
		int propOffset = 0;
		VLPropertyList::const_iterator	beginProp = measures.fProperties.begin();
		VLPropertyList::const_iterator	endProp	  = measures.fProperties.end();
		
		if (beginMeasure) {
			propOffset = fMeasures[beginMeasure-1].fPropIdx;
			if (fProperties[propOffset] == beginProp[0])
				++beginProp;
			else 
				++propOffset;
			if (fProperties[propAt] == endProp[-1])
				--endProp;
		}
		int postOffset = endProp - beginProp;
		
		fProperties.insert(fProperties.begin()+propAt, beginProp, endProp);
		fMeasures.insert(fMeasures.begin()+beginMeasure, 
						 measures.fMeasures.begin(), measures.fMeasures.end());
		if (propOffset)
			for (size_t meas=beginMeasure; meas<beginMeasure+numMeas; ++meas)
				fMeasures[meas].fPropIdx += propOffset;
		if (postOffset)
			for (size_t meas=beginMeasure+numMeas; meas<fMeasures.size(); ++meas)	
				fMeasures[meas].fPropIdx += postOffset;
			
		for (size_t r=0; r<fRepeats.size(); ++r) {
			VLRepeat & repeat = fRepeats[r];
			for (size_t e=0; e<repeat.fEndings.size(); ++e) {
				if (repeat.fEndings[e].fBegin >= beginMeasure)
					repeat.fEndings[e].fBegin += numMeas;
				if (repeat.fEndings[e].fEnd >= beginMeasure)
					repeat.fEndings[e].fEnd += numMeas;
			}
		}
		for (size_t r=0; r<measures.fRepeats.size(); ++r) {
			VLRepeat repeat = measures.fRepeats[r];
			for (size_t e=0; e<repeat.fEndings.size(); ++e) {
				repeat.fEndings[e].fBegin 	+= beginMeasure;
				repeat.fEndings[e].fEnd 	+= beginMeasure;
			}	
			fRepeats.push_back(repeat);
		}
	} else {
		if (CountMeasures() < nextMeasure) {
			VLMeasure 	rest;
			rest.fPropIdx	= fMeasures.back().fPropIdx;
			VLFraction	dur	= fProperties[rest.fPropIdx].fTime;
			rest.fMelody.push_back(VLLyricsNote(dur));
			rest.fChords.push_back(VLChord(dur));

			fMeasures.insert(fMeasures.end(), nextMeasure-CountMeasures(), rest);
		}
		for (size_t m=0; m<numMeas; ++m) {
			const VLMeasure &	srcMeas = measures.fMeasures[m];
			VLMeasure &			dstMeas = fMeasures[beginMeasure+m];
			if (mode & kOverwriteChords)
				dstMeas.fChords = Realign(srcMeas.fChords, 
										  measures.fProperties[srcMeas.fPropIdx],
										  fProperties[dstMeas.fPropIdx]);
			if (mode & kOverwriteMelody)
				dstMeas.fMelody = Realign(srcMeas.fMelody, 
										  measures.fProperties[srcMeas.fPropIdx],
										  fProperties[dstMeas.fPropIdx]);
		}
	}
}

void VLSong::DeleteMeasures(size_t beginMeasure, size_t endMeasure, int mode)
{
	if (mode == kOverwriteMelody) {
		for (size_t m=beginMeasure; m<endMeasure; ++m) {
			VLLyricsNote rest(Properties(m).fTime);
			fMeasures[m].fMelody.clear();
			fMeasures[m].fMelody.push_back(rest);
		}
		return;
	}
	int8_t	firstProp	= fMeasures[beginMeasure].fPropIdx;
	int8_t	lastProp	= fMeasures[endMeasure-1].fPropIdx+1;

	if (beginMeasure && fMeasures[beginMeasure-1].fPropIdx == firstProp)
		++firstProp;
	if (endMeasure < CountMeasures() && fMeasures[endMeasure].fPropIdx == lastProp)
		--lastProp;
	if (lastProp - firstProp == fProperties.size())	
		++firstProp;
	if (lastProp > firstProp) {
		fProperties.erase(fProperties.begin()+firstProp, 
						  fProperties.begin()+lastProp);
		for (size_t m=endMeasure; m<CountMeasures(); ++m)
			fMeasures[m].fPropIdx -= lastProp-firstProp;
	}
	fMeasures.erase(fMeasures.begin()+beginMeasure, 
					fMeasures.begin()+endMeasure);

	size_t delta = endMeasure-beginMeasure;
	for (size_t r=0; r<fRepeats.size(); ) {
		VLRepeat & repeat = fRepeats[r];
		if (repeat.fEndings[0].fBegin >= beginMeasure 
		 && repeat.fEndings[0].fEnd	<= endMeasure
		) {
			fRepeats.erase(fRepeats.begin()+r);	
		} else {
			for (size_t e=0; e<repeat.fEndings.size(); ) {
				if (repeat.fEndings[e].fBegin > beginMeasure)
					repeat.fEndings[e].fBegin = 
						std::max(beginMeasure, repeat.fEndings[e].fBegin-delta);
				if (repeat.fEndings[e].fEnd > beginMeasure)
					repeat.fEndings[e].fEnd = 
						std::max(beginMeasure, repeat.fEndings[e].fEnd-delta);
				if (e && repeat.fEndings[e].fBegin==repeat.fEndings[e].fEnd) 
					repeat.fEndings.erase(repeat.fEndings.begin()+e);
				else
					++e;
			}
			++r;
		}
	}
	//
	// Keep an empty meausure at the end
	//
	if (!EmptyEnding())
		AddMeasure();
}

VLFract VLSong::TiedDuration(size_t measure)
{
	VLFraction total(0);

	while (measure < fMeasures.size()) {
		VLNote n = fMeasures[measure++].fMelody.front();
		
		if (!(n.fTied & VLNote::kTiedWithPrev))
			break;
		total += n.fDuration;
		if (!(n.fTied & VLNote::kTiedWithNext))
			break;	   
	}
	return total;
}

bool VLSong::DoesBeginSection(size_t measure) const
{
	return measure && measure < fMeasures.size()
	  && fMeasures[measure-1].fPropIdx!=fMeasures[measure].fPropIdx;
}

void VLSong::AddSection(size_t measure)
{
	int splitIdx = fMeasures[measure].fPropIdx;

	VLProperties newProp = fProperties[splitIdx];
	if (splitIdx < fProperties.size()-1) 
		fProperties.insert(fProperties.begin()+splitIdx, newProp);
	else
		fProperties.push_back(newProp);
	while (measure < fMeasures.size())
		++fMeasures[measure++].fPropIdx;
}

void VLSong::DelSection(size_t measure)
{
	int delIdx = fMeasures[measure].fPropIdx;

	fProperties.erase(fProperties.begin()+delIdx);
	while (measure < fMeasures.size())
		--fMeasures[measure++].fPropIdx;
}

std::string VLSong::PrimaryGroove() const
{
	std::string bestGroove = fProperties[0].fGroove;

	for (size_t p=1; p<fProperties.size()-EmptyEnding(); ++p)
		if (fProperties[p].fGroove != bestGroove) {
			//
			// Multiple grooves in song, count them the hard way
			//
			std::vector<size_t> numMeas(fProperties.size());
			for (size_t m=0; m<fMeasures.size(); ++m)
				++numMeas[fMeasures[m].fPropIdx];

			size_t bestCount = numMeas[0];
			for (size_t px=1; px<fProperties.size(); ++px)
				if (fProperties[px].fGroove == bestGroove) {
					bestCount += numMeas[px];
					numMeas[px]= 0;
				}

			for (; p<fProperties.size(); ++p)
				if (numMeas[p]) {
					std::string	curGroove= fProperties[p].fGroove;
					size_t 		curCount = numMeas[p];
					for (size_t px=p+1; px<fProperties.size(); ++px)
						if (fProperties[px].fGroove == curGroove) {
							curCount  += numMeas[px];
							numMeas[px]= 0;
						}
					if (curCount > bestCount) {
						bestGroove= curGroove;
						bestCount = curCount;
					}
				}

			break;
		}

	return bestGroove;
}

//////////////////////// VLSongVisitor ////////////////////////////////

VLSongVisitor::~VLSongVisitor()
{
}

void VLSongVisitor::VisitMeasures(VLSong & song, bool performanceOrder)
{
	if (performanceOrder) {
		VLSong::iterator e = song.end();
		
		for (VLSong::iterator m=song.begin(); m!=e; ++m) {
			VLMeasure 	& meas = song.fMeasures[*m];
			VLProperties& prop = song.fProperties[meas.fPropIdx];
			VisitMeasure(*m, prop, meas);
		}
	} else {
		size_t  e = song.CountMeasures() - song.EmptyEnding();

		for (size_t m=0; m!=e; ++m) {
			VLMeasure 	& meas = song.fMeasures[m];
			VLProperties& prop = song.fProperties[meas.fPropIdx];
			VisitMeasure(m, prop, meas);
		}
	}
}

void VLSongVisitor::VisitNotes(VLMeasure & measure, const VLProperties & prop, 
							   bool decomposed)
{
	VLNoteList				decomp;
	VLNoteList::iterator	n;
	VLNoteList::iterator	e;

	if (decomposed) {	
		measure.DecomposeNotes(prop, decomp);
		n = decomp.begin();
		e = decomp.end();
	} else {
		n = measure.fMelody.begin();
		e = measure.fMelody.end();
	}

	for (; n!=e; ++n)
		VisitNote(*n);
}

void VLSongVisitor::VisitChords(VLMeasure & measure)
{
	VLChordList::iterator	c = measure.fChords.begin();
	VLChordList::iterator	e = measure.fChords.end();

	for (; c!=e; ++c)
		VisitChord(*c);
}

