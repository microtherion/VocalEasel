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

void VLNote::LilypondName(std::string & name, VLFraction at, const VLProperties & prop) const
{
	std::string n = LilypondPitchName(fPitch, prop.fKey >= 0);
	if (fPitch != kNoPitch) {
		for (int ticks = (fPitch-kMiddleC+kOctave)/kOctave; ticks>0; --ticks)
			n += '\'';
		for (int commas = (kMiddleC-kOctave-fPitch)/kOctave; commas>0; --commas)
			n += ',';
	}

	std::vector<std::string> 	durations;
	VLFraction					prevPart(0);
	for (VLFraction dur = fDuration; dur.fNum; ) {
		char duration[32];
		VLFraction part, visual;
		bool	   triplet;
		prop.PartialNote(at, dur, &part);
		prop.VisualNote(at, part, &visual, &triplet);
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
		if (i)
			name += " ~ ";
		name += durations[i];
	}
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

void VLNote::MMAName(std::string & name, VLFraction at, const VLProperties & prop) const
{
	bool useSharps = prop.fKey >= 0;

	name.clear();
	for (VLFraction dur = fDuration; dur.fNum; ) {
		VLFraction part;
		prop.PartialNote(at, dur, &part);
		for (int d=0; sMMADur[d].fName; ++d)
			if (part == sMMADur[d].fVal) {
				if (name.size())
					name += '+';
				name += sMMADur[d].fName;
			}
		dur	-= part;
		at  += part;
	}
	name += MMAPitchName(fPitch, useSharps);
	if (fPitch != kNoPitch) {
		for (int raise = (fPitch-kMiddleC)/kOctave; raise>0; --raise)
			name += '+';
		for (int lower = (kMiddleC-fPitch)/kOctave; lower>0; --lower)
			name += '-';
	}
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
	if (fDuration.fNum == 1 && !(fDuration.fDenom & (fDuration.fDenom-1)))
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

void VLChord::MMAName(std::string & name, bool useSharps) const
{
	VLFraction dur = fDuration;
	int   quarters = static_cast<int>(dur*4.0f+0.5f);
	name = "";
	if (!quarters--)
		return;
	if (fPitch == kNoPitch) {
		name = '/';
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

void VLProperties::VisualNote(VLFraction at, VLFraction actualDur, 
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
			} else if (actualDur == 2*swung/3 && ((at+actualDur) % swingGrid) == 0) {
				*visualDur	= swung;
				*triplet	= false;
			} else {
				*visualDur = 4*actualDur/3;
			}
		} else {
			*visualDur = 4*actualDur/3;
		}
	} else {
		*visualDur = actualDur;
	}
}

VLMeasure::VLMeasure()
	: fPropIdx(0)
{
}

void VLMeasure::MMANotes(std::string & notes, const VLProperties & prop) const
{
	VLFraction					at(0);
	VLNoteList::const_iterator 	i 	= fMelody.begin();
	VLNoteList::const_iterator 	e 	= fMelody.end();

	notes.clear();
	for (; i!=e; ++i) {
		std::string note;
		i->MMAName(note, at, prop);
		if (notes.size())
			notes += ' ';
		notes += note+';';
		at    += i->fDuration;
	}
}

void VLMeasure::MMAChords(std::string & chords, const VLProperties & prop) const
{
  VLChordList::const_iterator i	= fChords.begin();
  VLChordList::const_iterator e	= fChords.end();

  chords.clear();
  for (; i!=e; ++i) {
    std::string chord;
    i->MMAName(chord, prop.fKey >= 0);
    if (chords.size())
      chords += ' ';
    chords += chord;
  }
}

VLSong::VLSong()
{
	const VLFraction 	fourFour(4,4);
	VLProperties 		defaultProperties = {fourFour, 0, 1, 3};
	
	fProperties.push_back(defaultProperties);
	fMeasures.resize(32); // Leadin, AABA
	
	VLLyricsNote 	rest = VLLyricsNote(VLRest(1));
	VLChord 		rchord;
	rchord.fDuration = 1;
	
	for (int i=0; i<32; ++i) {
		fMeasures[i].fChords.push_back(rchord);
		fMeasures[i].fMelody.push_back(rest);
	}
}

void VLSong::swap(VLSong & other)
{
	fProperties.swap(other.fProperties);
	fMeasures.swap(other.fMeasures);
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
void VLSong::AddNote(VLLyricsNote note, size_t measure, VLFraction at)
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

void VLSong::Transpose(int semi)
{
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
			semi	+= 12;	// Transpose an Octave up
		else if (low > VLNote::kMiddleC+7 && high > VLNote::kMiddleC+16)
			semi 	-= 12;	// Transpose an Octave down
		else
			break;			// Looks like we're done
	}
	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		VLChordList::iterator i = fMeasures[measure].fChords.begin();
		VLChordList::iterator e = fMeasures[measure].fChords.end();

		for (; i!=e; ++i) {
			TransposePinned(i->fPitch, semi);
			TransposePinned(i->fRootPitch, semi);
		}
	}
}

size_t  VLSong::CountStanzas() const
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


void VLSong::LilypondNotes(std::string & notes) const
{
	notes = "";
	for (size_t measure=0; measure<fMeasures.size(); ++measure) {
		VLNoteList::const_iterator i 	= fMeasures[measure].fMelody.begin();
		VLNoteList::const_iterator e 	= fMeasures[measure].fMelody.end();
		VLFraction 				   at(0);

		for (; i!=e; ++i) {
			std::string note;
			i->LilypondName(note, at, fProperties[fMeasures[measure].fPropIdx]);
			at += i->fDuration;
			notes += note+" ";
		}
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

	return false;
}

bool VLSong::NextWord(size_t stanza, size_t & measure, VLFraction & at)
{  
	bool firstMeasure = true;
	do {
		VLMeasure & 			meas	= fMeasures[measure];
		VLNoteList::iterator 	note 	= fMeasures[measure].fMelody.begin();
		VLNoteList::iterator 	end  	= fMeasures[measure].fMelody.end();
		bool					hasWord	= false;
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

	do {
		VLMeasure & 			meas	= fMeasures[measure];
		VLNoteList::iterator 	note 	= fMeasures[measure].fMelody.begin();
		VLNoteList::iterator 	end  	= fMeasures[measure].fMelody.end();
		VLFraction				now(0);

		while (note != meas.fMelody.end()) {
			if (now >= at && note->fPitch != VLNote::kNoPitch) {
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
	} while (++measure < fMeasures.size());
	
	return word;
}

void VLSong::SetWord(size_t stanza, size_t measure, VLFraction at, std::string word)
{
	uint8_t	kind = 0;
	bool	cleanup = false;

	do {
		VLMeasure & 			meas	= fMeasures[measure];
		VLNoteList::iterator 	note 	= fMeasures[measure].fMelody.begin();
		VLNoteList::iterator 	end  	= fMeasures[measure].fMelody.end();
		VLFraction				now(0);

		while (note != meas.fMelody.end()) {
			if (now >= at && note->fPitch != VLNote::kNoPitch) {
				if (cleanup) {
					//
					// Make sure that following syllable doesn't have
					// kHasPrev set
					//
					if (note->fLyrics.size() >= stanza)
						note->fLyrics[stanza-1].fKind &= ~VLSyllable::kHasPrev;
					
					return;
				}
				if (note->fLyrics.size()<stanza)
					note->fLyrics.resize(stanza);
				size_t root = word.find('-');
				std::string syll;
				if (root == std::string::npos) {
					syll 	= word;
					kind   &= ~VLSyllable::kHasNext;
					cleanup = true;
				} else {
					syll 	= word.substr(0, root);
					word.erase(0, root+1);
					kind   |= VLSyllable::kHasNext;
				}
				note->fLyrics[stanza-1].fText = syll;
				note->fLyrics[stanza-1].fKind = kind;
				kind |= VLSyllable::kHasPrev;
			}
			now += note->fDuration;
			++note;
		}	
		at = 0;
	} while (++measure < fMeasures.size());	
}

