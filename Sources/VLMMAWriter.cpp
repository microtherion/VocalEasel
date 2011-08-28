//
// File: VLMMAWriter.cpp
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#include "VLMMAWriter.h"

void VLMMAWriter::Visit(VLSong & song)
{
	fSong	= &song;
	fMeas	= 0;
	fInitial= true;
	fMeasures.clear();
	fKey	= -999;
	fGroove = "";

	VisitMeasures(song, true);
}

void VLMMAWriter::VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas) 
{
	if (fPreview)
		if (meas.fPropIdx < fBeginSection || meas.fPropIdx >= fEndSection)
			return; // Skip this measure

	char buf[64];

	if (p.fKey != fKey) {
		fKey       = p.fKey;
		sprintf(buf, "KeySig %ld%c\n", labs(fKey), fKey>=0 ? '#' : '&');
		fMeasures += buf;
	}
	if (!fPreview && p.fGroove != fGroove) {
		fGroove    = p.fGroove;
		fMeasures += "Groove " + fGroove + '\n';
	}

	sprintf(buf, "%-3d", ++fMeas);

	fUseSharps	= fKey >= 0;

	//
	// Generate chords
	//
	fAccum.clear();
	VisitChords(meas);
	std::string chords = buf+fAccum;

	//
	// Generate melody and account for ties
	//
	fAccum.clear();
	bool tiedWithPrev = (meas.fMelody.front().fTied & VLNote::kTiedWithPrev)
		|| fSong->DoesTieWithPrevRepeat(m);
	bool tiedWithNext = (meas.fMelody.back().fTied & VLNote::kTiedWithNext)
		|| fSong->DoesTieWithNextRepeat(m);
	fTied	= tiedWithPrev;
	VisitNotes(meas, p, true);
	if (fTied || fAccum == "~") {
		fAccum = tiedWithNext ? "~<>~;" : "~<>;";
	} else if (tiedWithNext) {
		fAccum.replace(fAccum.find_last_of(';'), 0, "~", 1);
    }
	
	std::string melody = fAccum;

	fMeasures	+= chords+"\t{ " + melody + " }\n";
	if (!fTied && tiedWithNext)
		fLastDur = fMeasures.find_last_of("123468");
}

static const char kScale[] = "c d ef g a b";

static std::string MMAPitchName(int8_t pitch, bool useSharps, bool showNatural=false)
{
	if (pitch == VLNote::kNoPitch)
		return "r";
	char name[3];
	name[2] = 0;
	name[1] = showNatural?'n':0;
	pitch %= 12;
	if (kScale[pitch] != ' ') {
		name[0] = kScale[pitch];
	} else if (useSharps) {
		name[0] = kScale[pitch-1];
		name[1] = '#';
	} else {
		name[0] = kScale[pitch+1];
		name[1] = '&';
	}
	if (!showNatural)
		name[0] = toupper(name[0]);

	return name;
}

static std::string MMAOctave(int8_t pitch)
{
	std::string name;
	if (pitch != VLNote::kNoPitch) {
		for (int raise = (pitch-VLNote::kMiddleC)/VLNote::kOctave; raise>0; --raise)	
			name += '+';
		for (int lower = (VLNote::kMiddleC+VLNote::kOctave-1-pitch)/VLNote::kOctave; lower>0; --lower)
			name += '-';
	}

	return name;
}

void VLMMAWriter::VisitNote(VLLyricsNote & n)							   
{
	char buf[4];
	std::string dur;
	if (n.fDuration.fNum == 1) 
		if (!(n.fDuration.fDenom & (n.fDuration.fDenom-1))) {
			sprintf(buf, "%d", n.fDuration.fDenom);
			dur = buf;
		} else if (n.fDuration.fDenom == 3) {
			dur = "23"; // Half note triplet
		} else if (n.fDuration.fDenom == 6) {
			//
			// Quarter note triplet / swing 8th
			//
			dur = n.fVisual==VLNote::kEighth ? "81" : "43"; 
		} else if (n.fDuration.fDenom == 12) {
			//
			// Eighth note triplet / swing 8th / swing 16th
			//
			dur = n.fVisual==VLNote::kEighth ? "82" : "3"; 
		} else if (n.fDuration.fDenom == 24) {
			dur = "6"; // 16th note triplet
		}
	if (fTied) {
		fMeasures.replace(fLastDur+1, 0, '+'+dur);
		fLastDur += 1+dur.size();
		if (!(n.fTied & VLNote::kTiedWithNext)) {
			fAccum += "~";
			fTied   = false;
		}
		return;
	} else if (n.fTied & VLNote::kTiedWithPrev) {
		size_t d = fAccum.find_last_of("123468");
		fAccum.replace(d+1, 0, '+'+dur);
		return;
	}
	if (fAccum.size() > 1)
		fAccum += ' ';
	fAccum += dur+MMAPitchName(n.fPitch, fUseSharps, true)+MMAOctave(n.fPitch)+';';
}

#define _ VLChord::

//
// MMA supports a large but finite list of chords
//
static const VLChordModifier kMMAModifiers[] = {
	{"", 0, 0},
	{"+", _ kmAug5th, _ km5th},
	{"11", _ kmMin7th | _ kmMaj9th | _ km11th, 0},
	{"11b9", _ kmMin7th | _ kmMin9th | _ km11th, 0},
	{"13", _ kmMin7th | _ kmMaj9th | _ km11th | _ kmMaj13th, 0},
	{"5", 0, _ kmMaj3rd},
	{"6", _ kmDim7th, 0},
	{"69", _ kmDim7th | _ kmMaj9th, 0},
	{"7", _ kmMin7th, 0},
	{"7#11", _ kmMin7th | _ kmAug11th, 0},
	{"7#5", _ kmMin7th | _ kmAug5th, _ km5th},
	{"7#5#9", _ kmMin7th | _ kmAug5th | _ kmAug9th, _ km5th},
	{"7#5b9", _ kmMin7th | _ kmAug5th | _ kmMin9th, _ km5th},
	{"7#9", _ kmMin7th | _ kmAug9th, 0},
	{"7#9#11", _ kmMin7th | _ kmAug9th | _ kmAug11th, 0},
	{"7b5", _ kmMin7th | _ kmDim5th, _ km5th},
	{"7b5#9", _ kmMin7th | _ kmDim5th | _ kmAug9th, _ km5th},
	{"7b5b9", _ kmMin7th | _ kmDim5th | _ kmMin9th, _ km5th},
	{"7b9", _ kmMin7th | _ kmMin9th, 0},
	{"7sus", _ kmMin7th | _ km4th, _ kmMaj3rd},
	{"7sus2", _ kmMin7th | _ kmMaj2nd, _ kmMaj3rd},
	{"9", _ kmMin7th | _ kmMaj9th, 0},
	{"9#11", _ kmMin7th | _ kmMaj9th | _ kmAug11th, 0},
	{"9#5", _ kmMin7th | _ kmMaj9th | _ kmAug5th, _ km5th},
	{"9b5", _ kmMin7th | _ kmMaj9th | _ kmDim5th, _ km5th},
	{"9sus", _ kmMaj9th, 0},
	{"M13", _ kmMaj7th | _ kmMaj13th, 0},
	{"M7", _ kmMaj7th, 0},
	{"M7#11", _ kmMaj7th | _ kmMaj9th | _ kmAug11th, 0},
	{"M7#5", _ kmMaj7th | _ kmAug5th, _ km5th},
	{"M7b5", _ kmMaj7th | _ kmDim5th, _ km5th},
	{"M9", _ kmMaj7th | _ kmMaj9th, 0},
	{"aug9", _ kmMin7th | _ kmMaj9th | _ kmAug5th, _ km5th},
	{"dim3", _ kmMin3rd | _ kmDim5th, _ kmMaj3rd | _ km5th},
	{"dim7", _ kmMin3rd | _ kmDim5th | _ kmDim7th, _ kmMaj3rd | _ km5th},
	{"m", _ kmMin3rd, _ kmMaj3rd},
	{"m#5", _ kmMin3rd | _ kmAug5th, _ kmMaj3rd | _ km5th},
	{"m(maj7)", _ kmMin3rd | _ kmMaj7th, _ kmMaj3rd},
	{"m(sus9)", _ kmMin3rd | _ kmMaj9th, _ kmMaj3rd},	
	{"m11", _ kmMin3rd | _ kmMin7th | _ kmMaj9th | _ km11th, _ kmMaj3rd},
	{"m6", _ kmMin3rd | _ kmDim7th, _ kmMaj3rd},
	{"m69", _ kmMin3rd | _ kmDim7th | _ kmMaj9th, _ kmMaj3rd},
	{"m7", _ kmMin3rd | _ kmMin7th, _ kmMaj3rd},
	{"m7b5", _ kmMin3rd | _ kmMin7th | _ kmDim5th, _ kmMaj3rd | _ km5th},
	{"m7b9", _ kmMin3rd | _ kmMin7th | _ kmMin9th, _ kmMaj3rd},
	{"m9", _ kmMin3rd | _ kmMin7th | _ kmMaj9th, _ kmMaj3rd},
	{"m9b5", _ kmMin3rd | _ kmMin7th | _ kmMaj9th | _ kmDim5th, _ kmMaj3rd | _ km5th},
	{"mM7", _ kmMin3rd | _ kmMaj7th, _ kmMaj3rd},
	{"mb5", _ kmMin3rd | _ kmDim5th, _ kmMaj3rd | _ km5th},
	{"sus", _ km4th, _ kmMaj3rd},
	{"sus2", _ kmMaj2nd, _ kmMaj3rd},
	{"sus9", _ kmMaj9th, 0},
	{NULL, 0, 0}
};

void VLMMAWriter::VisitChord(VLChord & c)									
{
	int   quarters = static_cast<int>(c.fDuration*4.0f+0.5f);
	if (!quarters--)
		return;
	std::string name;
	if (c.fPitch == VLNote::kNoPitch) {
		name = fInitial ? "z" : "/";
	} else {
		fInitial = false;

		std::string base, ext;
		base = MMAPitchName(c.fPitch, fUseSharps);

		size_t best 	= 0;
		size_t bestBits	= 32;
		size_t bestScore= 0;
		for (size_t i=0; kMMAModifiers[i].fName; ++i) {
			uint32_t steps = (VLChord::kmUnison | VLChord::kmMaj3rd | VLChord::km5th)
				| kMMAModifiers[i].fAddSteps
				&~kMMAModifiers[i].fDelSteps;
			if (c.fSteps == steps) {
				//
				// Exact match
				//
				best = i;
				break;
			}
			steps ^= c.fSteps;
			size_t bits=0;
			size_t score=0;
			for (uint32_t b=steps; b; b &= (b-1))
				++bits;
			for (size_t b=0; b<32; ++b)
				if (steps & (1<<b))
					score += 32-b;
			if (bits < bestBits || (bits==bestBits && score < bestScore)) {
				best		= i;
				bestBits	= bits;
				bestScore	= score;
			}
		}
		ext = kMMAModifiers[best].fName;
		name = base+ext;
		if (c.fRootPitch != VLNote::kNoPitch)
			name += '/' + MMAPitchName(c.fRootPitch, fUseSharps);
		std::toupper(base[0]);
	}
	while (quarters--)
		name += " /";

	fAccum += ' '+name;
}
