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

static std::string	LilypondPitchName(int8_t pitch, bool useSharps)
{
	if (pitch == VLNote::kNoPitch)
		return "r";
	pitch %= 12;
	if (kScale[pitch] != ' ')
		return kScale[pitch] + std::string();
	else if (useSharps)
		return kScale[pitch-1] + std::string("is");
	else
		return kScale[pitch+1] + std::string("es");
}

static std::string MMAPitchName(int8_t pitch, bool useSharps)
{
	if (pitch == VLNote::kNoPitch)
		return "r";
	char name[3];
	name[2] = 0;
	name[1] = 'n';
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

	return name;
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

void VLNote::LilypondName(std::string & name, VLFraction at, VLFraction prevDur, VLFraction nextDur, bool & triplet, bool & pickup, const VLProperties & prop) const
{
	std::string n = LilypondPitchName(fPitch, prop.fKey >= 0);
	if (fPitch != kNoPitch) {
		for (int ticks = (fPitch-kMiddleC+kOctave)/kOctave; ticks>0; --ticks)
			n += '\'';
		for (int commas = (kMiddleC-kOctave-fPitch)/kOctave; commas>0; --commas)
			n += ',';
		pickup = false;
	} else if (pickup) {
		n = "s";
	}

	std::vector<std::string> 	durations;
	VLFraction					prevPart(0);
	for (VLFraction dur = fDuration; dur.fNum; ) {
		char duration[32];
		VLFraction part, visual;
		bool	   grouped = dur==nextDur ||
			(prevPart!=0 ? dur==prevPart : dur==prevDur);
		prop.PartialNote(at, dur, grouped, &part);
		prop.VisualNote(at, part, triplet, &visual, &triplet);
		if (!triplet && fPitch != kNoPitch && part == dur && 2*visual == prevPart) {
			durations.pop_back();
			sprintf(duration, "%s%d.", n.c_str(), visual.fDenom/2);
		} else if (triplet) {
			sprintf(duration, "\\times 2/3 { %s%d }", n.c_str(), visual.fDenom);
		} else {
			sprintf(duration, "%s%d", n.c_str(), visual.fDenom);
		}
		durations.push_back(duration);
		prevPart	= part;
		at         += part;
		dur        -= part;
	}
	for (size_t i=0; i<durations.size(); ++i) {
		if (i && fPitch != kNoPitch)
			name += " ~ ";
		name += durations[i];
	}
	if (fTied & kTiedWithNext)
		name += " ~";
}

static struct {
  VLFract      fVal;
  const char * fName;
} sMMADur [] = {
  {{1,1},  "1"},
  {{1,2},  "2"},
  {{1,3},  "23"},
  {{1,4},  "4"},
  {{1,6},  "81"},
  {{1,8},  "8"},
  {{1,12}, "82"},
  {{1,16}, "16"},
  {{1,24}, "6"},
  {{1,32}, "32"},
  {{1,64}, "64"},
  {{0,0}, 0}
};

void VLNote::MMAName(std::string & name, VLFraction at, VLFraction dur, VLFraction prevDur, VLFraction nextDur, const VLProperties & prop) const
{
	if (fTied & kTiedWithPrev) {
		if (fTied & kTiedWithNext) {
			name = "~<>~";
		} else {
			name = '~';
		}
		return;
	}
	bool useSharps = prop.fKey >= 0;

	name.clear();
	VLFraction prevPart(0);
	while (dur.fNum) {
		VLFraction part;
		bool	   grouped = dur==nextDur ||
			(prevPart!=0 ? dur==prevPart : dur==prevDur);
		prop.PartialNote(at, dur, grouped, &part);
		for (int d=0; sMMADur[d].fName; ++d)
			if (part == sMMADur[d].fVal) {
				if (name.size())
					name += '+';
				name += sMMADur[d].fName;
			}
		prevPart	= part;
		dur		   -= part;
		at  	   += part;
	}
	int pitch = fTied & kTiedWithPrev ? kNoPitch : fPitch;
	name += MMAPitchName(pitch, useSharps);
	if (pitch != kNoPitch) {
		for (int raise = (pitch-kMiddleC)/kOctave; raise>0; --raise)
			name += '+';
		for (int lower = (kMiddleC+kOctave-1-pitch)/kOctave; lower>0; --lower)
			name += '-';
	}
	if (fTied & kTiedWithNext)
		name += '~';
}

struct VLChordModifier {
	const char *	fName;
	uint32_t		fAddSteps;
	uint32_t		fDelSteps;
};

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

static const char * kLilypondStepNames[] = {
	"", "", "sus2", "", "", "sus", "5-", "", "5+", "6", "7", "7+", "",
	"9-", "9", "9+", "", "11", "11+", "", "13-", "13"
};

void VLChord::LilypondName(std::string & name, bool useSharps) const
{
	name = LilypondPitchName(fPitch, useSharps);
	char duration[16];
	if (fDuration.fNum == 1 && !(fDuration.fDenom & (fDuration.fDenom-1))) // Power of two
		sprintf(duration, "%d", fDuration.fDenom);
	else
		sprintf(duration, "1*%d/%d", fDuration.fNum, fDuration.fDenom);
	name += std::string(duration);
	if (fPitch == kNoPitch)
		return;

	std::string ext;
	uint32_t steps = fSteps;
	//
	// m / dim
	//
	if (steps & kmMin3rd)
		if (steps & (kmDim5th|kmDim7th) 
		 && !(steps & (km5th|kmMin7th|kmMaj7th|kmMin9th|kmMaj9th|km11th|kmAug11th|kmMin13th|kmMaj13th))
		) {
			ext = "dim";
			steps|= (steps & kmDim7th) << 1;
			steps&=	~(kmMin3rd|kmDim5th|kmDim7th);
		} else {
			ext = "m";
			steps&= ~kmMin3rd;
		}
	steps &= ~(kmUnison | km5th);
	//
	// Maj
	//
	if (steps & kmMaj7th) {
		if (ext.size())
			ext += '.';
		ext += "maj"; 
		if (steps & kmMaj9th) {
			ext += "9";	
			steps &= ~kmMaj9th;
		} else
			ext += "7";
		steps&= ~kmMaj7th;
	}
	//
	// Sus
	//
	if (steps & (kmMaj2nd|km4th)) {
		if (ext.size())
			ext += '.';
		ext += "sus";
		if (steps & kmMaj2nd)
			ext += "2";
		else
			ext += "4";
		steps&= ~(kmMaj2nd|km4th);
	}
	//
	// 6/9
	//
	if ((steps & (kmDim7th|kmMaj9th)) == (kmDim7th|kmMaj9th)) {
		if (ext.size() && !isalpha(ext[ext.size()-1]))
			ext += '.';
		ext += "6.9";
		steps&= ~(kmDim7th|kmMaj9th);
	}
	//
	// Other extensions. Only the highest unaltered extension is listed.
	//
	if (uint32_t unaltered = steps & (kmMin7th | kmMaj9th | km11th | kmMaj13th)) {
		steps			  &= ~unaltered;
	
		for (int step = kMaj13th; step > kDim7th; --step)
			if (unaltered & (1 << step)) {
				std::string sn = kLilypondStepNames[step];
				if (ext.size() && !isalpha(ext[ext.size()-1]) && sn.size())
					ext += '.';
				ext += sn;
				break;
			}
	}
	for (int step = kMin2nd; steps; ++step) 
		if (steps & (1 << step)) {
			std::string sn = kLilypondStepNames[step];
			if (ext.size() && !isalpha(ext[ext.size()-1]) && sn.size())
				ext += '.';
			ext   += sn;
			steps &= ~(1 << step);
		}
	
	if (ext.size())
		name += ':' + ext;
	//
	// Root
	//
	if (fRootPitch != kNoPitch)
		name += "/+" + LilypondPitchName(fRootPitch, useSharps);
}

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

bool VLChord::MMAName(std::string & name, bool useSharps, bool initial) const
{
	VLFraction dur = fDuration;
	int   quarters = static_cast<int>(dur*4.0f+0.5f);
	name = "";
	if (!quarters--)
		return initial;
	if (fPitch == kNoPitch) {
		name = initial ? 'z' : '/';
	} else {
		std::string base, ext;
		VLNote::Name(base, useSharps);

		size_t best 	= 0;
		size_t bestBits	= 32;
		size_t bestScore= 0;
		for (size_t i=0; kMMAModifiers[i].fName; ++i) {
			uint32_t steps = (kmUnison | kmMaj3rd | km5th)
				| kMMAModifiers[i].fAddSteps
				&~kMMAModifiers[i].fDelSteps;
			if (fSteps == steps) {
				//
				// Exact match
				//
				best = i;
				break;
			}
			steps ^= fSteps;
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
		if (fRootPitch != kNoPitch)
			name += '/' + PitchName(fRootPitch, useSharps);
		std::toupper(base[0]);
		size_t mod;
		while ((mod = name.find("Maj")) != std::string::npos)
			name.erase(mod+1, 2);
		while ((mod = name.find(kVLSharpStr)) != std::string::npos)
			name.replace(mod, 3, "#", 1);
		while ((mod = name.find(kVLFlatStr)) != std::string::npos)
			name.replace(mod, 3, "&", 1);
	}
	while (quarters--) 
		name += " /";
	
	return false;
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
							   bool grouped, VLFraction * noteDuration) const
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
	if (!(noteDuration->fDenom % 3))
		if (*noteDuration != totalDuration) {
			if (((at+*noteDuration)%kBeat) > 0)
				*noteDuration *= VLFraction(3,4); // avoid frivolous triplets
		} else if (*noteDuration > VLFraction(1,4*fDivisions) && !grouped) {
			if (*noteDuration == VLFraction(1,2*fDivisions))
				if (at % VLFraction(1, 4*fDivisions/3) == 0)
					return; // Permit larger swing notes
			*noteDuration *= VLFraction(3,4); // avoid other isolated triplets
		}
}

void VLProperties::VisualNote(VLFraction at, VLFraction actualDur, 
							  bool prevTriplet,
							  VLFraction *visualDur, bool * triplet) const
{
	bool 		swing= !(fDivisions % 3);		// In swing mode?
	VLFraction 	swung(3, fDivisions*8, true);	// Which notes to swing
	VLFraction	swingGrid(2*swung);			   	// Alignment of swing notes

	if (*triplet = !(actualDur.fDenom % 3)) {
		if (swing) {	// Swing 8ths / 16ths are written as straight 8ths	
			if (actualDur == 4*swung/3 && (at % swingGrid) == 0) {	
				*visualDur	= swung;
				*triplet	= false;
			} else if (actualDur == 2*swung/3 && ((at+actualDur) % swingGrid) == 0 && !prevTriplet) {
				*visualDur	= swung;
				*triplet	= false;
			} else {
				*visualDur = 3*actualDur/2;
			}
		} else {
			*visualDur = 3*actualDur/2;
		}
	} else {
		*visualDur = actualDur;
	}
}

VLMeasure::VLMeasure()
	: fPropIdx(0)
{
}

void VLMeasure::MMANotes(std::string & notes, const VLProperties & prop,
						 VLFraction extra) const
{
	VLFraction					at(0);
	VLNoteList::const_iterator 	i 	= fMelody.begin();
	VLNoteList::const_iterator 	e 	= fMelody.end();

	notes.clear();
	VLFraction	prevDur(0);
	for (; i!=e; ++i) {
		std::string 				note;
		VLFraction 					nextDur(0);
		VLFraction					dur(i->fDuration);
		VLNoteList::const_iterator	n=i;
		if (++n != e)
			nextDur = n->fDuration;
		else
			dur	   += extra;
		i->MMAName(note, at, dur, prevDur, nextDur, prop);
		if (notes.size()>1)
			notes += ' ';
		if (note == "~")
			notes += note;
		else
			notes += note+';';
		at    += i->fDuration;
	}
	if (notes == "~")
		notes += "<>;";
}

void VLMeasure::MMAChords(std::string & chords, const VLProperties & prop,
						  bool initial) const
{
  VLChordList::const_iterator i	= fChords.begin();
  VLChordList::const_iterator e	= fChords.end();

  chords.clear();
  for (; i!=e; ++i) {
    std::string chord;
    initial = i->MMAName(chord, prop.fKey >= 0, initial);
    if (chords.size())
      chords += ' ';
    chords += chord;
  }
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

VLSong::VLSong(bool initialize)
{
	if (!initialize)
		return;

	const VLFraction 	fourFour(4,4);
	VLProperties 		defaultProperties = {fourFour, 0, 1, 3};
	
	fProperties.push_back(defaultProperties);

	AddMeasure();

	fGoToCoda	= -1;
	fCoda		= -1;
}

void VLSong::AddMeasure()
{
	VLFraction		dur  = fProperties.front().fTime;
	VLLyricsNote 	rest = VLLyricsNote(VLRest(dur));
	VLChord 		rchord;
	rchord.fDuration = dur;
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

void VLSong::ChangeKey(int newKey, bool newMode, bool transpose)
{
	VLProperties & prop = fProperties.front();
	int semi 	= 7*(newKey-prop.fKey) % 12;
	prop.fKey 	= newKey;
	prop.fMode	= newMode;	
	if (!transpose)
		return;

	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
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

void VLSong::ChangeDivisions(int newDivisions)
{
	VLProperties & prop = fProperties.front();
	if (newDivisions == prop.fDivisions)
		return; // Unchanged
	
	VLRealigner realign(prop.fDivisions, newDivisions);
	//
	// Only melody needs to be realigned, chords are already quarter notes
	//
	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		VLNoteList newMelody;
		VLFraction at(0);
		VLFraction lastAt;

		VLNoteList::iterator i = fMeasures[measure].fMelody.begin();
		VLNoteList::iterator e = fMeasures[measure].fMelody.end();

		for (; i!=e; ++i) {
			VLLyricsNote n 		= *i;
			VLFraction 	 newAt 	= realign(at);
			if (newMelody.empty()) {
				newMelody.push_back(n);
				lastAt	= newAt;
			} else if (newAt != lastAt) {
				newMelody.back().fDuration = newAt-lastAt;
				newMelody.push_back(n);
				lastAt	= newAt;
			}
			at += n.fDuration;
		}
		if (lastAt == at)
			newMelody.pop_back();
		else
			newMelody.back().fDuration = at-lastAt;
		fMeasures[measure].fMelody.swap(newMelody);
	}
	prop.fDivisions = newDivisions;
}

void VLSong::ChangeTime(VLFraction newTime)
{
	VLProperties & prop = fProperties.front();
	if (prop.fTime == newTime)
		return; // No change
	VLChord 		rchord;
	rchord.fDuration	= newTime-prop.fTime;
	VLLyricsNote rnote  = VLLyricsNote(VLRest(newTime-prop.fTime));
	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		if (newTime < prop.fTime) {
			VLChordList::iterator i = fMeasures[measure].fChords.begin();
			VLChordList::iterator e = fMeasures[measure].fChords.end();
			VLFraction 	at(0);
			VLChordList	newChords;

			for (; i!=e; ++i) {
				VLChord	c = *i;
				if (at+c.fDuration >= newTime) {
					if (at < newTime) {
						c.fDuration = newTime-at;
						newChords.push_back(c);
					}
					break;
				} else {
					newChords.push_back(c);
					at += c.fDuration;
				}
			}
			fMeasures[measure].fChords.swap(newChords);
		} else
			fMeasures[measure].fChords.push_back(rchord);

		if (newTime < prop.fTime) {
			VLNoteList::iterator i = fMeasures[measure].fMelody.begin();
			VLNoteList::iterator e = fMeasures[measure].fMelody.end();
			VLFraction 	at(0);
			VLNoteList	newMelody;

			for (; i!=e; ++i) {
				VLLyricsNote	n = *i;
				if (at+n.fDuration >= newTime) {
					if (at < newTime) {
						n.fDuration = newTime-at;
						newMelody.push_back(n);
					}
					break;
				} else {
					newMelody.push_back(n);
					at += n.fDuration;
				}
			}
			fMeasures[measure].fMelody.swap(newMelody);
		} else
			fMeasures[measure].fMelody.push_back(rnote);
	}
	prop.fTime	= newTime;
}

size_t VLSong::EmptyEnding() const
{
	size_t full = fMeasures.size();

	while (full-- && fMeasures[full].IsEmpty())
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

void VLSong::LilypondNotes(std::string & notes) const
{
	notes 					= "";
	std::string indent 		= "";
	size_t		seenEnding 	= 0;
	int			numEndings	= 0;
	size_t		endMeasure  = fMeasures.size()-EmptyEnding();
	bool		pickup		= fMeasures[0].NoChords();
	for (size_t measure=0; measure<endMeasure; ++measure) {
		VLNoteList::const_iterator i 	= fMeasures[measure].fMelody.begin();
		VLNoteList::const_iterator e 	= fMeasures[measure].fMelody.end();
		VLFraction 				   at(0);

		int		times;
		size_t	volta;
		bool	repeat;
		
		if (DoesBeginRepeat(measure, &times)) {
			char volta[8];
			sprintf(volta, "%d", times);
			notes 	    = notes + "\\repeat volta "+volta+" {\n";
			indent 		= "    ";
			seenEnding 	= 0;
			numEndings	= 0;
		}
		if (DoesEndRepeat(measure)) {
			notes += "}\n";
			indent = "";
		}
		if (DoesBeginEnding(measure, &repeat, &volta)) {
			notes += seenEnding ? "}{\n" : "} \\alternative {{\n";
			notes += "    \\set Score.repeatCommands = #'((volta \"";
			const char * comma = "";
			for (int r=0; r<8; ++r)
				if (volta & (1<<r)) {
					char volta[8];
					sprintf(volta, "%s%d.", comma, r+1);
					comma	= ", ";
					notes += volta;
				}
			notes = notes + "\")" + (repeat ? "" : " end-repeat") + ")\n";
			seenEnding	|= volta;
			++numEndings;
		} else if (DoesEndEnding(measure)) {
			notes += "}}\n";
			indent = "";
		}
		notes += indent;
		if (fCoda == measure)
			notes += "\\break \\mark \\markup { \\musicglyph #\"scripts.coda\" }\n"
				+ indent;
		VLFraction prevDur(0);
		bool triplet = false;
		for (; i!=e; ++i) {
			std::string note;
			VLNoteList::const_iterator n = i;
			VLFraction nextDur(0);
			if (++n != e)
				nextDur = n->fDuration;
			i->LilypondName(note, at, prevDur, nextDur, triplet, pickup, fProperties[fMeasures[measure].fPropIdx]);
			prevDur	= i->fDuration;
			at 	   += i->fDuration;
			notes  += note+" ";
		}
		//
		// Consolidate triplets
		//
		size_t trip;
		while ((trip = notes.find("} \\times 2/3 { ")) != std::string::npos)
			notes.erase(trip, 15);
		while ((trip = notes.find("} ~ \\times 2/3 { ")) != std::string::npos)
			notes.replace(trip, 17, "~ ", 2);
		// 
		// Swap ties into correct order
		//
		while ((trip = notes.find("} ~")) != std::string::npos)
			notes.replace(trip, 3, "~ } ", 4);
			
		if (fGoToCoda == measure+1)
			notes += "\n"
				+ indent 
				+ "\\mark \\markup { \\musicglyph #\"scripts.coda\" } |";
		else
			notes += '|';
		if (!(measure % 4)) {
			char measNo[8];
			sprintf(measNo, " %% %d", measure+1);
			notes += measNo;
		}
		if (measure < fMeasures.size()-1)
			notes += '\n';
	}
}

void VLSong::LilypondChords(std::string & chords) const
{
	chords = "";
	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		bool useSharps	= fProperties[fMeasures[measure].fPropIdx].fKey>=0;
		VLChordList::const_iterator i	= fMeasures[measure].fChords.begin();
		VLChordList::const_iterator e	= fMeasures[measure].fChords.end();

		for (; i!=e; ++i) {
			std::string chord;
			i->LilypondName(chord, useSharps);
			chords += chord+" ";
		}
		if (!(measure % 4)) {
			char measNo[8];
			sprintf(measNo, " %% %d", measure+1);
			chords += measNo;
		}
		if (measure < fMeasures.size()-1)
			chords += '\n';
	}
}

void VLSong::LilypondStanza(std::string & lyrics, size_t stanza) const
{
	lyrics = "";
	std::string sep;
	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		VLNoteList::const_iterator i 	= fMeasures[measure].fMelody.begin();
		VLNoteList::const_iterator e 	= fMeasures[measure].fMelody.end();
		VLFraction 				   at(0);

		for (; i!=e; ++i) {
			if (i->fPitch == VLNote::kNoPitch 
			 || (i->fTied & VLNote::kTiedWithPrev)
			) {
				continue; // Rest or continuation note, skip
			} else if (i->fLyrics.size() < stanza || !i->fLyrics[stanza-1]) {
				lyrics += sep + "\\skip1";
			} else {
				lyrics += sep + i->fLyrics[stanza-1].fText;
				if (i->fLyrics[stanza-1].fKind & VLSyllable::kHasNext)
					lyrics += " --";
			}
			sep = " ";
		}
		if ((measure % 4) == 3) {
			sep		= "\n";
		}
	}	
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
	for (size_t r=0; r<fRepeats.size(); ++r)
		if (fRepeats[r].fEndings[0].fBegin == beginMeasure
		 && fRepeats[r].fEndings[0].fEnd >= endMeasure
		) 
			if (fRepeats[r].fEndings[0].fEnd == endMeasure) {
				//
				// Exact match, just change times
				//
				size_t mask = ((1<<times)-1) ^ ((1<<fRepeats[r].fTimes)-1);
				if (fRepeats[r].fTimes < times) 
					fRepeats[r].fEndings[0].fVolta |= mask;
				else if (fRepeats[r].fTimes > times) 
					for (size_t e=0; e<fRepeats[r].fEndings.size(); ++e)
						fRepeats[r].fEndings[e].fVolta &= ~mask;
				fRepeats[r].fTimes = times; 

				return;
			} else {
				fRepeats.erase(fRepeats.begin()+r);
			
				break;
			}
	
	VLRepeat	rep;

	rep.fTimes	= times;
	rep.fEndings.push_back(VLRepeat::Ending(beginMeasure, endMeasure, 
											(1<<times)-1));
	fRepeats.push_back(rep);
}

void VLSong::DelRepeat(size_t beginMeasure, size_t endMeasure)
{
	for (size_t r=0; r<fRepeats.size(); ++r)
		if (fRepeats[r].fEndings[0].fBegin == beginMeasure
		 && fRepeats[r].fEndings[0].fEnd >= endMeasure
		) {
			fRepeats.erase(fRepeats.begin()+r);
			
			break;
		}
}

void VLSong::AddEnding(size_t beginMeasure, size_t endMeasure, size_t volta)
{
	for (size_t r=0; r<fRepeats.size(); ++r)
		if (fRepeats[r].fEndings[0].fBegin < beginMeasure
		 && fRepeats[r].fEndings[0].fEnd >= beginMeasure
		) {
			VLRepeat & repeat = fRepeats[r];
			for (size_t e=1; e<repeat.fEndings.size(); ++e)
				if (repeat.fEndings[e].fBegin == beginMeasure
				 && repeat.fEndings[e].fEnd	== endMeasure
				) {
					//
					// Found it, just edit volta
					//
					repeat.fEndings[0].fVolta |= repeat.fEndings[e].fVolta;
					volta &= repeat.fEndings[0].fVolta;
					repeat.fEndings[0].fVolta &= ~volta;
					repeat.fEndings[e].fVolta  = volta;

					return;
				}
			//
			// Not found, add new ending
			//		    
			volta &= fRepeats[r].fEndings[0].fVolta;
			fRepeats[r].fEndings[0].fVolta &= ~volta;
			fRepeats[r].fEndings[0].fEnd 	= 
				std::max<int8_t>(fRepeats[r].fEndings[0].fEnd, endMeasure);
			fRepeats[r].fEndings.push_back(
                VLRepeat::Ending(beginMeasure, endMeasure, volta));
			
			return;
		}
}

void VLSong::DelEnding(size_t beginMeasure, size_t endMeasure)
{
	for (size_t r=0; r<fRepeats.size(); ++r)
		if (fRepeats[r].fEndings[0].fBegin <= beginMeasure
		 && fRepeats[r].fEndings[0].fEnd > beginMeasure
		) 
			for (size_t e=1; e<fRepeats[r].fEndings.size(); ++e)
				if (fRepeats[r].fEndings[e].fBegin == beginMeasure) {
					fRepeats[r].fEndings[0].fVolta |= fRepeats[r].fEndings[e].fVolta;
					if (e > 1 && e == fRepeats[r].fEndings.size()-1) 
						fRepeats[r].fEndings[0].fEnd = fRepeats[r].fEndings[e].fBegin;
					fRepeats[r].fEndings.erase(fRepeats[r].fEndings.begin()+e);
				}
}

bool VLSong::CanBeRepeat(size_t beginMeasure, size_t endMeasure, int * times)
{
	for (size_t r=0; r<fRepeats.size(); ++r) {
		const VLRepeat & rep = fRepeats[r];
		if (rep.fEndings[0].fBegin == beginMeasure) {
			//
			// Look for exact match & return
			//
			if (times)
				*times = fRepeats[r].fTimes;
			if (rep.fEndings[0].fEnd == endMeasure) 
				return true;
			if (rep.fEndings.size() > 1) {
				if (rep.fEndings[1].fBegin == endMeasure)
					return true;
				if (rep.fEndings[1].fEnd == endMeasure)
					return true;
			}
		}
		//
		// Inclusions and surroundings are OK. Beginnings may match, but
		// endings must not.
		//
		if (rep.fEndings[0].fBegin >= beginMeasure 
		 && rep.fEndings[0].fEnd < endMeasure
		)
			continue;
		if (rep.fEndings[0].fBegin <= beginMeasure
		 && rep.fEndings[0].fEnd > endMeasure
		)
			continue;
		//
		// Look for overlap and reject
		//
		if (fRepeats[r].fEndings[0].fBegin >= beginMeasure 
         && fRepeats[r].fEndings[0].fBegin < endMeasure
		)
			return false; 
		if (fRepeats[r].fEndings[0].fEnd > beginMeasure 
         && fRepeats[r].fEndings[0].fEnd <= endMeasure
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
	for (size_t r=0; r<fRepeats.size(); ++r) 
		if (beginMeasure > fRepeats[r].fEndings[0].fBegin
		 && beginMeasure <= fRepeats[r].fEndings[0].fEnd
		) {
			//
			// Found right repeat
			//
			VLRepeat & repeat = fRepeats[r];

			//
			// Append new repeat, or carve out from ending
			//
			if (beginMeasure == repeat.fEndings[0].fEnd) {
				for (size_t r2=0; r2<fRepeats.size(); ++r2)
					if (r2 != r 
					 && fRepeats[r2].fEndings[0].fBegin >= beginMeasure
					 && fRepeats[r2].fEndings[0].fBegin < endMeasure
					)
						return false; // Overlap
				if (volta)
					*volta = repeat.fEndings[0].fVolta;
				if (voltaOK)
					*voltaOK = repeat.fEndings[0].fVolta;
				
				return true;				
			} else if (repeat.fEndings.size() == 1 
			  && endMeasure >= repeat.fEndings[0].fEnd
			) {
				if (volta)
					*volta = repeat.fEndings[0].fVolta;
				if (voltaOK)
					*voltaOK = repeat.fEndings[0].fVolta;
				
				return true;
			}
			//
			// Otherwise must match existing
			//
			for (size_t e=1; e<repeat.fEndings.size(); ++e)
				if (beginMeasure == repeat.fEndings[e].fBegin
				 && endMeasure == repeat.fEndings[e].fEnd
				) {
					if (volta)
						*volta = repeat.fEndings[e].fVolta;
					if (voltaOK)
						*voltaOK = repeat.fEndings[e].fVolta 
							     | repeat.fEndings[0].fVolta;
					return true;
				}
			return false;
		}
	return false;
}

bool VLSong::DoesBeginRepeat(size_t measure, int * times) const
{
	for (size_t r=0; r<fRepeats.size(); ++r)
		if (fRepeats[r].fEndings[0].fBegin == measure) {
			if (times)
				*times = fRepeats[r].fTimes;

			return true;
		}
	return false;
}

bool VLSong::DoesEndRepeat(size_t measure, int * times) const
{
	for (size_t r=0; r<fRepeats.size(); ++r)
		if (fRepeats[r].fEndings[0].fEnd == measure 
		 && fRepeats[r].fEndings.size() == 1
		) {
			if (times)
				*times = fRepeats[r].fTimes;

			return true;
		}
	return false;	
}

bool VLSong::DoesBeginEnding(size_t measure, bool * repeat, size_t * volta) const
{
	for (size_t r=0; r<fRepeats.size(); ++r)
		if (fRepeats[r].fEndings[0].fEnd >= measure 
		 && fRepeats[r].fEndings.size() > 1
		) {
			size_t v = (1<<fRepeats[r].fTimes)-1;
			for (size_t e=1; e<fRepeats[r].fEndings.size(); ++e)
				if (fRepeats[r].fEndings[e].fBegin == measure) {
					if (repeat)
						if (e == fRepeats[r].fEndings.size()-1 
						 && fRepeats[r].fEndings[e].fVolta == v
						)
							*repeat = false; // Not after last alternative
						else
							*repeat = true;
					if (volta)
						*volta = fRepeats[r].fEndings[e].fVolta;

					return true;
				} else
					v &= ~fRepeats[r].fEndings[e].fVolta;
			if (v && fRepeats[r].fEndings[0].fEnd == measure) {
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
	return false;	
}

bool VLSong::DoesEndEnding(size_t measure, bool * repeat, size_t * volta) const
{
	for (size_t r=0; r<fRepeats.size(); ++r)
		if (fRepeats[r].fEndings[0].fEnd+1 >= measure 
		 && fRepeats[r].fEndings.size() > 1
		) {
			size_t v = (1<<fRepeats[r].fTimes)-1;
			for (size_t e=1; e<fRepeats[r].fEndings.size(); ++e)
				if (fRepeats[r].fEndings[e].fEnd == measure) {
					if (repeat)
						if (e == fRepeats[r].fEndings.size()-1 
						 && fRepeats[r].fEndings[e].fVolta == v
						)
							*repeat = false; // Not after last alternative
						else
							*repeat = true;
					if (volta)
						*volta = fRepeats[r].fEndings[e].fVolta;
					return true;
				} else
					v &= ~fRepeats[r].fEndings[e].fVolta;
			if (v && fRepeats[r].fEndings[0].fEnd+1 == measure) {
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
	return false;	
}

VLSong::iterator::iterator(const VLSong & song, bool end)
	: fSong(song)
{
	fMeasure	= end ? fSong.CountMeasures()-fSong.EmptyEnding() : 0;
	AdjustStatus();
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

	for (size_t r=0; r<fRepeats.size(); ++r) 
		if (fRepeats[r].fEndings[0].fBegin >= beginMeasure 
         && fRepeats[r].fEndings[0].fEnd   <= endMeasure
		) {
			VLRepeat repeat = fRepeats[r];
			for (size_t e=0; e<repeat.fEndings.size(); ++e) {
				repeat.fEndings[e].fBegin	-= beginMeasure;
				repeat.fEndings[e].fEnd		-= endMeasure;
			}
			subSong.fRepeats.push_back(repeat);
		}

	return subSong;
}

void VLSong::PasteMeasures(size_t beginMeasure, const VLSong & measures, int mode)
{
	size_t numMeas		= measures.CountMeasures();
	size_t nextMeasure 	= mode==kInsert ? beginMeasure : beginMeasure+numMeas;
	//
	// Ignore properties for now. We don't use multiple properties yet.
	//
	if (mode == kInsert) {
		fMeasures.insert(fMeasures.begin()+beginMeasure, 
						 measures.fMeasures.begin(), measures.fMeasures.end());
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
			rest.fMelody.push_back(VLLyricsNote(VLRest(dur)));
			VLChord		rchord;
			rchord.fDuration= dur;
			rest.fChords.push_back(rchord);

			fMeasures.insert(fMeasures.end(), nextMeasure-CountMeasures(), rest);
		}
		for (size_t m=0; m<numMeas; ++m) {
			const VLMeasure &	srcMeas = measures.fMeasures[m];
			VLMeasure &			dstMeas = fMeasures[beginMeasure+m];
			if (mode & kOverwriteChords)
				dstMeas.fChords = srcMeas.fChords;
			if (mode & kOverwriteMelody)
				dstMeas.fMelody = srcMeas.fMelody;			
		}
	}
}

void VLSong::DeleteMeasures(size_t beginMeasure, size_t endMeasure)
{
	int8_t	firstProp	= fMeasures[beginMeasure].fPropIdx;
	int8_t	lastProp	= fMeasures[endMeasure-1].fPropIdx+1;

	if (beginMeasure && fMeasures[beginMeasure-1].fPropIdx == firstProp)
		++firstProp;
	if (endMeasure < CountMeasures() && fMeasures[endMeasure].fPropIdx == lastProp)
		--lastProp;
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
