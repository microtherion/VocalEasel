//
// File: VLPitchName.cpp - Translate between (MIDI) pitches and their UTF-8 representation
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2011 Matthias Neeracher
//

#include "VLPitchName.h"
#include "VLModel.h"

#define	SHARP   "\xE2\x99\xAF"
#define FLAT    "\xE2\x99\xAD"

const char *	kVLSharpStr     =   SHARP;
const char *    kVLFlatStr      =   FLAT;
const char *    kVL2SharpStr    =   "\xF0\x9D\x84\xAA";
const char *    kVL2FlatStr     =   "\xF0\x9D\x84\xAB";
const char *    kVLNaturalStr   =   "\xE2\x99\xAE";

static const char   kScale[]            = "C D EF G A B";
static const char * kFancyAccidental[]  =
{
    kVL2SharpStr, kVLSharpStr, "", kVLFlatStr, kVL2FlatStr
};
const int8_t kAccidentalBase = 2;

std::string	VLPitchName(int8_t pitch, uint16_t accidental)
{
	if (pitch == VLNote::kNoPitch)
		return "r";
    int8_t adjust;
    accidental  &= VLNote::kAccidentalsMask;
    switch (accidental) {
        case VLNote::kWant2Flat:
            adjust  = 2;
            break;
        case VLNote::kWantFlat:
            adjust  = 1;
            break;
        case VLNote::kWantSharp:
            adjust  = -1;
            break;    
        case VLNote::kWant2Sharp:
            adjust  = -2;
            break;
        default:
            adjust  = 0;
            break;
    }
    pitch       += adjust;
    pitch       %= 12;
    //
    // Will either succeed immediately, or after one adjustment
    //
    if (kScale[pitch] == ' ')
        if (adjust < 0 || (accidental & VLNote::kPreferFlats) == VLNote::kPreferFlats) {
            ++adjust;
            pitch = (pitch+1)%12;
        } else {
            --adjust;
            pitch = (pitch+11)%12;           
        }
    std::string name = std::string(1, kScale[pitch]);
    if (adjust)
        return name+kFancyAccidental[adjust+kAccidentalBase];
    else if ((accidental & VLNote::kWantNatural) == VLNote::kWantNatural)
        return name+kVLNaturalStr;
    else
        return name;
}

static bool TestAccidental(uint16_t acc, int8_t adjust, std::string & str, size_t at, 
                           const char * fancyStr, const char * asciiString, 
                           int8_t & pitch, uint16_t * accidental)
{
    size_t sz       = str.size()-at;
    size_t fancySz  = strlen(fancyStr);
    if (sz >= fancySz && !memcmp(fancyStr, &str[at], fancySz)) {
        pitch          += adjust;
        *accidental     = acc;
        str.erase(at, fancySz);
        return true;
    }
    size_t asciiSz  = strlen(asciiString);
    if (!asciiSz || sz < asciiSz)
        return false;
    
    for (size_t cmp = at; *asciiString; )
        if (std::toupper(str[cmp++]) != *asciiString++)
            return false;
    pitch          += adjust;
    *accidental     = acc;
    str.erase(at, asciiSz);
    return true;
}

int8_t VLParsePitch(std::string & str, size_t at, uint16_t * accidental)
{
    int8_t pitch    = VLNote::kNoPitch;
    //
	// Determine key
	//
	if (const char * key = strchr(kScale, std::toupper(str[at]))) {
		pitch	= key-kScale+VLNote::kMiddleC;
    } else if (str[at] == 'r' || str[at] == 's') {
        str.erase(at, 1); // Rest
        return VLNote::kNoPitch;
    } else
		return kPitchError;
    str.erase(at, 1);
    //
    // Look for accidentals
    //
    TestAccidental(VLNote::kWant2Flat,  -2, str, at, kVL2FlatStr,   "BB", pitch, accidental) ||
    TestAccidental(VLNote::kWantFlat,   -1, str, at, kVLFlatStr,    "B",  pitch, accidental) ||
    TestAccidental(VLNote::kWantNatural, 0, str, at, kVLNaturalStr, "",   pitch, accidental) ||
    TestAccidental(VLNote::kWant2Sharp,  2, str, at, kVL2SharpStr,  "##", pitch, accidental) ||
    TestAccidental(VLNote::kWantSharp,   1, str, at, kVLSharpStr,   "#",  pitch, accidental) ||
    (*accidental = 0);

    return pitch;
}


static const char * kStepNames[] = {
	"", "", "sus2", "", "", "sus", FLAT "5", "", SHARP "5", "6", 
	"7", SHARP "7", "", FLAT "9", "9", SHARP "9", "", 
	"11", SHARP "11", "", FLAT "13", "13"
};

#define _ VLChord::

void VLChordName(int8_t pitch, uint16_t accidental, uint32_t steps, 
                 int8_t rootPitch, uint16_t rootAccidental,
                 std::string & baseName, std::string & extName, std::string & rootName)
{
    baseName = VLPitchName(pitch, accidental);
    if (rootPitch == VLNote::kNoPitch)
        rootName.clear();
    else
        rootName = VLPitchName(rootPitch, rootAccidental);
	//
	// m / dim
	//
    extName.erase();
	if (steps & _ kmMin3rd)
		if (steps & _ kmDim5th
         && !(steps & (_ km5th|_ kmMin7th|_ kmMaj7th|_ kmMin9th|_ kmMaj9th|
                       _ km11th|_ kmAug11th|_ kmMin13th|_ kmMaj13th))
        ) {
			extName += "dim";
			steps|= (steps & _ kmDim7th) << 1;
			steps&=	~(_ kmMin3rd|_ kmDim5th|_ kmDim7th);
		} else {
			baseName += "m";
			steps&= ~_ kmMin3rd;
		}
	//	
	// +
	//
	steps &= ~(_ kmUnison | _ kmMaj3rd | _ km5th);
	if (steps == _ kmAug5th) {
		extName += "+";
		steps= 0;
	}
	//
	// Maj
	//
	if (steps & _ kmMaj7th) {
		extName +=  "Maj";
		steps   &=  ~_ kmMaj7th;
		steps   |=  +_ kmMin7th; // Write out the 7 for clarification
	}
	//
	// 6/9
	//
	if ((steps & (_ kmDim7th|_ kmMaj9th)) == (_ kmDim7th|_ kmMaj9th)) {
		extName += "69";
		steps   &= ~(_ kmDim7th|_ kmMaj9th);
	}
	//
	// Other extensions. Only the highest unaltered extension is listed.
	//
	bool has7th = steps & (_ kmMin7th|_ kmMaj7th);
	bool has9th	= steps & (_ kmMin9th|_ kmMaj9th|_ kmAug9th);
	if ((steps & _ kmMaj13th) && has7th && has9th ) {	
		extName += kStepNames[_ kMaj13th];
		steps	&= ~(_ kmMin7th |_ kmMaj9th |_ km11th |_ kmMaj13th);
	} else if ((steps & _ km11th) && has7th && has9th) {
		extName += kStepNames[_ k11th];
		steps	&= ~(_ kmMin7th | _ kmMaj9th | _ km11th);
	} else if ((steps & _ kmMaj9th) && has7th) {
		extName += kStepNames[_ kMaj9th];
		steps	&= ~(_ kmMin7th | _ kmMaj9th);
	} else if (steps & _ kmMin7th) {
		extName	+= kStepNames[_ kMin7th];
		steps   &= ~(_ kmMin7th);
	}
    
	for (int step = _ kMin2nd; steps; ++step) 
		if (steps & (1 << step)) {
			if ((1 << step) & (_ kmMaj9th|_ km11th|_ kmMaj13th))
				extName += "add";
			extName += kStepNames[step];
			steps &= ~(1 << step);
		}
}

static const VLChordModifier kModifiers[] = {
	{"b13", _ kmMin13th, 0},
	{FLAT "13", _ kmMin13th, 0},
	{"add13", _ kmMaj13th, 0},
	{"13", _ kmMin7th | _ kmMaj9th | _ km11th | _ kmMaj13th, 0},
	{"#11", _ kmAug11th, _ km11th},
	{SHARP "11", _ kmAug11th, _ km11th},
	{"+11", _ kmAug11th, _ km11th},
	{"add11", _ km11th, 0},
	{"11", _ kmMin7th | _ kmMaj9th | _ km11th, 0},
	{"#9", _ kmAug9th, _ kmMaj9th},
	{SHARP "9", _ kmAug9th, _ kmMaj9th},
	{"+9", _ kmAug9th, _ kmMaj9th},
	{"b9", _ kmMin9th, _ kmMaj9th},
	{FLAT "9", _ kmMin9th, _ kmMaj9th},
	{"-9", _ kmMin9th, _ kmMaj9th},
	{"69", _ kmDim7th | _ kmMaj9th, 0},
	{"add9", _ kmMaj9th, 0},
	{"9", _ kmMin7th | _ kmMaj9th, 0},
	{"7", _ kmMin7th, 0},
	{"maj", _ kmMaj7th, _ kmMin7th},
	{"6", _ kmDim7th, 0},
	{"#5", _ kmAug5th, _ km5th},
	{SHARP "5", _ kmAug5th, _ km5th},
	{"+5", _ kmAug5th, _ km5th},
	{"aug", _ kmAug5th, _ km5th},
	{"+", _ kmAug5th, _ km5th},
	{"b5", _ kmDim5th, _ km5th},
	{FLAT "5", _ kmDim5th, _ km5th},
	{"-5", _ kmDim5th, _ km5th},
	{"sus4", _ km4th, _ kmMaj3rd},
	{"sus2", _ kmMaj2nd, _ kmMaj3rd},
	{"sus", _ km4th, _ kmMaj3rd},
	{"4", _ km4th, _ kmMaj3rd},
    {"add3", _ kmMaj3rd, 0},
	{"2", _ kmMaj2nd, _ kmMaj3rd},
	{NULL, 0, 0}
};

int8_t      VLParseChord(std::string & str, uint16_t * accidental, uint32_t * steps, 
                         int8_t * rootPitch, uint16_t * rootAccidental)
{
    int8_t pitch = VLParsePitch(str, 0, accidental);
    if (pitch < 0)
        return pitch;
    size_t root = str.find('/');
    if (root != std::string::npos) {
        *rootPitch = VLParsePitch(str, root+1, rootAccidental);
        if (*rootPitch < 0)
            return kPitchError;
        str.erase(root, 1);
    } else {
        *rootPitch      = VLNote::kNoPitch;
        *rootAccidental = 0;
    }
	//
	// Apply modifiers
	//
	*steps	= _ kmUnison | _ kmMaj3rd | _ km5th;
	
	for (const VLChordModifier * mod = kModifiers; mod->fName && str.size() 
      && str != "dim" && str != "m" && str != "-"; ++mod
    ) {
		size_t pos = str.find(mod->fName);
		if (pos != std::string::npos) {
			str.erase(pos, strlen(mod->fName));
			*steps	&=	~mod->fDelSteps;
			*steps	|=	mod->fAddSteps;
		}
	}
	if (str == "m" || str == "-") {
		*steps	= (*steps & ~_ kmMaj3rd) | _ kmMin3rd;
		str.erase(0, 1);
	} else if (str == "dim") {
		uint32_t st     = *steps & (_ kmMaj3rd |_ km5th |_ kmMin7th);
		*steps		    = (*steps ^ st) | (st >> 1); // Diminish 3rd, 5th, and 7th, if present
		str.erase(0, 3);
	}
    return str.empty() ? pitch : kPitchError;
}
