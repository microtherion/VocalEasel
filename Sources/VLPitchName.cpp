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

const char *	kVLSharpStr     =   "\xE2\x99\xAF";
const char *    kVLFlatStr      =   "\xE2\x99\xAD";
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
