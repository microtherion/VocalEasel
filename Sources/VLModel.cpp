/*
 *  VLModel.cpp
 *  Vocalese
 *
 *  Created by Matthias Neeracher on 12/18/05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

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
		return static_cast<char>(std::toupper(kScale[pitch-1])) + std::string("♯");
	else
		return static_cast<char>(std::toupper(kScale[pitch+1])) + std::string("♭");
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

void VLNote::Name(std::string & name, bool useSharps) const
{
	name = PitchName(fPitch, useSharps);
}

struct VLChordModifier {
	const char *	fName;
	uint32_t		fAddSteps;
	uint32_t		fDelSteps;
};

static const VLChordModifier kModifiers[] = {
	{"b13", VLChord::kmMin7th | VLChord::kmMaj9th | VLChord::km11th | VLChord::kmMin13th, 0},
	{"13", VLChord::kmMin7th | VLChord::kmMaj9th | VLChord::km11th | VLChord::kmMaj13th, 0},
	{"#11", VLChord::kmMin7th | VLChord::kmMaj9th | VLChord::kmAug11th, VLChord::km11th},
	{"11", VLChord::kmMin7th | VLChord::kmMaj9th | VLChord::km11th, 0},
	{"#9", VLChord::kmMin7th | VLChord::kmAug9th, VLChord::kmMaj9th},
	{"b9", VLChord::kmMin7th | VLChord::kmMin9th, VLChord::kmMaj9th},
	{"69", VLChord::kmDim7th | VLChord::kmMaj9th, 0},
	{"9", VLChord::kmMin7th | VLChord::kmMaj9th, 0},
	{"7", VLChord::kmMin7th, 0},
	{"maj", VLChord::kmMaj7th, VLChord::kmMin7th},
	{"6", VLChord::kmDim7th, 0},
	{"#5", VLChord::kmAug5th, VLChord::km5th},
	{"aug", VLChord::kmAug5th, VLChord::km5th},
	{"+", VLChord::kmAug5th, VLChord::km5th},
	{"b5", VLChord::kmDim5th, VLChord::km5th},
	{"sus4", VLChord::km4th, VLChord::kmMaj3rd},
	{"sus2", VLChord::kmMaj2nd, VLChord::kmMaj3rd},
	{"sus", VLChord::km4th, VLChord::kmMaj3rd},
	{"4", VLChord::km4th, VLChord::kmMaj3rd},
	{"2", VLChord::kmMaj2nd, VLChord::kmMaj3rd},
	{NULL, 0, 0}
};

static const char * kStepNames[] = {
	"", "", "sus2", "", "", "sus", "♭5", "", "+", "6", "7", "♯7", "",
	"♭9", "9", "♯9", "", "11", "♯11", "", "♭9", "13"
};

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
			name.erase(0);
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

void	VLChord::Name(std::string & base, std::string & ext, std::string & root, bool useSharps) const
{
	base = PitchName(fPitch, useSharps);
	ext  = "";
	root = "";
	
	uint32_t steps = fSteps & ~(kmUnison | km5th);
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
	// Maj
	//
	if (steps & kmMaj7th) {
		ext += "Maj";
		steps&= ~kmMaj7th;
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
	if (uint32_t unaltered = steps & (kmMin7th | kmMaj9th | km11th | kmMaj13th)) {
		steps			  &= ~unaltered;
	
		for (int step = kMaj13th; step > kDim7th; --step)
			if (unaltered & (1 << step)) {
				ext += kStepNames[step];
				break;
			}
	}
	for (int step = kMin2nd; steps; ++step) 
		if (steps & (1 << step)) {
			ext += kStepNames[step];
			steps &= ~(1 << step);
		}
	//
	// Root
	//
	if (fRootPitch != kNoPitch)
		root = PitchName(fRootPitch, useSharps);
}

static VLFraction MaxNote(VLFraction d)
{
	if (d >= 1)
		return 1;
	if (d.fNum == 1 && !(d.fDenom & (d.fDenom-1))) // Power of 2
		return d;
		
	VLFraction  note(1,2);
	VLFraction  triplet(1,3);

	for (;;) {
		if (d >= note)
			return note;
		else if (d >= triplet)
			return triplet;
		note	/= 2;
		triplet /= 2;
	}
}

static void TrimNote(VLFraction at, VLFraction & d, VLFraction grid)
{
	if (at < grid && d > grid-at)
		d = MaxNote(grid-at);
}

void VLProperties::PartialNote(VLFraction at, VLFraction totalDuration, 
							   VLFraction * noteDuration) const
{
	const VLFraction kBeat(1, fTime.fDenom);
	
	at           %= fTime;
	*noteDuration = MaxNote(std::min(MaxNote(totalDuration), fTime-at)); // Don't extend past measure
	
	if (at.fDenom > kBeat.fDenom) { // Break up notes not starting on beat
		// Don't extend past "middle" of measure
		if (fTime.fNum & 1) // Odd timecode, round up (most 5/4 seems to be 3+2, not 2+3)
			TrimNote(at, *noteDuration, VLFraction((fTime.fNum+1)/2, fTime.fDenom));
		else
			TrimNote(at, *noteDuration, fTime / 2);
		at %= kBeat;
		if (at == 2*kBeat/3)
			TrimNote(0, *noteDuration, kBeat); // Allow syncopated beats in swing
		else 
			TrimNote(at, *noteDuration, kBeat);// Don't let other notes span beats
	}
	if (!(noteDuration->fDenom % 3) && *noteDuration != totalDuration && ((at+*noteDuration)%kBeat) > 0)
		*noteDuration *= VLFraction(3,4); // avoid frivolous triplets
}

VLMeasure::VLMeasure()
	: fProperties(0)
{
}

VLSong::VLSong()
{
	const VLFraction 	fourFour(4,4);
	VLProperties 		defaultProperties = {fourFour, 0, 1, 3};
	
	fProperties.push_back(defaultProperties);
	fMeasures.resize(32); // Leadin, AABA
	
	VLNote 	rest = VLRest(1);
	VLChord rchord;
	rchord.fDuration = 1;
	
	for (int i=0; i<32; ++i) {
		fMeasures[i].fProperties = &fProperties.front();
		fMeasures[i].fChords.push_back(rchord);
		fMeasures[i].fMelody.push_back(rest);
	}
}

//
// Deal with chords - a bit simpler
//
void VLSong::AddChord(VLChord chord, size_t measure, VLFraction at)
{
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
void VLSong::AddNote(VLNote note, size_t measure, VLFraction at)
{
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
				if (i->fTied & VLNote::kTiedWithPrev) 
					LastTie(fMeasures[measure-1]) &= ~VLNote::kTiedWithNext;
				note.fDuration 	= tEnd-at;
				i->fDuration	= at-t;
				i = fMeasures[measure].fMelody.insert(++i, note);
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
				// Turn into rest
				//
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
}

