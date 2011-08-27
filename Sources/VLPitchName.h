//
// File: VLPitchName.h - Translate between (MIDI) pitches and their UTF-8 representation
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2011 Matthias Neeracher
//

#include <string>
#include <inttypes.h>

const int           kVLSharpChar    =   0x266F;
const int           kVLFlatChar     =   0x266D;
extern const char *	kVLSharpStr;
extern const char * kVLFlatStr;
extern const char * kVL2SharpStr;
extern const char * kVL2FlatStr;
extern const char * kVLNaturalStr;

//
// UTF-8 representation of pitch
//
std::string VLPitchName(int8_t pitch, uint16_t accidental);

//
// Parse pitch, erase from string
//
enum { kPitchError = -1 };
int8_t      VLParsePitch(std::string & str, size_t at, uint16_t * accidental);
