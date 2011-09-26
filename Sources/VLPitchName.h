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
extern const char * kVLFancyNames[];
extern const char * kVLFancyChordNames[];
extern const char * kVLLilypondNames[];
//
// UTF-8 representation of pitch
//
std::string VLPitchName(int8_t pitch, uint16_t accidental, int * octave = 0,
                        const char * names[] = kVLFancyNames);

//
// Parse pitch, erase from string
//
enum { kPitchError = -1 };
int8_t      VLParsePitch(std::string & str, size_t at, uint16_t * accidental);

//
// UTF-8 representation of chord
//
void VLChordName(int8_t pitch, uint16_t accidental, uint32_t steps, 
                 int8_t rootPitch, uint16_t rootAccidental,
                 std::string & baseName, std::string & extName, std::string & rootName,
                 const char * names[] = kVLFancyChordNames);

//
// Parse chord name, erase from string
//
int8_t      VLParseChord(std::string & str, uint16_t * accidental, uint32_t * steps, 
                         int8_t * rootPitch, uint16_t * rootAccidental);