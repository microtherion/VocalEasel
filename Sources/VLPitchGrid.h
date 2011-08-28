//
// File: VLPitchGrid.h - Translate between (MIDI) pitches and their vertical position
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2011 Matthias Neeracher
//

#include <inttypes.h>

//
// Grid position is defined from middle C
//
int     VLPitchToGrid(int8_t pitch, uint16_t & visual, int key);
int8_t  VLGridToPitch(int gridPos, uint16_t visual, int key);

//
// Avoid repeating accidentals
//
class VLVisualFilter {
public:
    VLVisualFilter(int key);
    
    uint16_t    operator()(int gridPos, uint16_t visual);
private:
    uint16_t    fState[7];
    uint16_t    fKeyState[7];
};