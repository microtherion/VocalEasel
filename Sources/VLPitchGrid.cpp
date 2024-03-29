//
// File: VLPitchGrid.h - Translate between (MIDI) pitches and their vertical position
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2011 Matthias Neeracher
//

#include "VLPitchGrid.h"
#include "VLModel.h"

#define P(x) (1<<x)

static inline bool IsBasicNote(int semi) 
{
    //
    // Bitmap of basic notes, padded left and right by two positions
    //                              B     C     D     E     F     G     A     B     C 
    const uint16_t kBasicNotes = P( 1)|P( 2)|P( 4)|P( 6)|P( 7)|P( 9)|P(11)|P(13)|P(14);
    
    return kBasicNotes & (1<<(semi+2));
}

static inline bool HasFlat(int semi, int key)
{
    const uint16_t kFMajor  =     P(1) | P(13);         // Bb
    const uint16_t kBbMajor = kFMajor  | P(6);          // Eb
    const uint16_t kEbMajor = kBbMajor | P(11);         // Ab
    const uint16_t kAbMajor = kEbMajor | P(4);          // Db
    const uint16_t kDbMajor = kAbMajor | P(9);          // Gb
    const uint16_t kGbMajor = kDbMajor | P(2) | P(14);  // Cb
    
    static const uint16_t sFlats[] = 
        {kFMajor, kBbMajor, kEbMajor, kAbMajor, kDbMajor, kGbMajor};
    
    return sFlats[-1-key] & (1<<(semi+2));
}

static inline bool HasSharp(int semi, int key)
{
    const uint16_t kGMajor  =           P(7);           // F#
    const uint16_t kDMajor  = kGMajor | P(2) | P(14);   // C#
    const uint16_t kAMajor  = kDMajor | P(9);           // G#
    const uint16_t kEMajor  = kAMajor | P(4);           // D#
    const uint16_t kBMajor  = kEMajor | P(11);          // A#
    const uint16_t kFsMajor = kBMajor | P(6);           // E#
    
    static const uint16_t sSharps[] = 
        {kGMajor, kDMajor, kAMajor, kEMajor, kBMajor, kFsMajor};
    
    return sSharps[key-1] & (1<<(semi+2));
}

uint16_t    VLVisualInKey(int8_t pitch, int key)
{
    if (key < 0 && HasFlat(pitch % 12, key))
        return VLNote::kWantFlat;
    else if (key > 0 && HasSharp(pitch % 12, key))
        return VLNote::kWantSharp;
    else
        return 0;
}

static inline int8_t SemiToStep(int semi)
{
    static const int8_t sSteps[] = 
    //   Bb  B C   D   E F   G   A   B C
        {-1,-1,0,0,1,1,2,3,3,4,4,5,5,6,7,7};

    return sSteps[semi+2];
}

static inline int8_t StepToSemi(int step)
{
    //                             C D E F G A B
    static const int8_t sSemi[] = {0,2,4,5,7,9,11};
    
    return sSemi[step];
}

uint16_t VLPitchAccidental(int8_t pitch, uint16_t visual, int key)
{
    int         semi            = pitch % 12;
    //
    // The user expressed a preference, try to match it
    //
    switch (visual & VLNote::kAccidentalsMask) {
    case VLNote::kWantNatural:
        if (IsBasicNote(semi))
            return visual;
        break;
    case VLNote::kWant2Flat:
        if (IsBasicNote(semi+2)) 
            return visual;
        else
            return VLNote::kWantFlat;
    case VLNote::kWantFlat:
        if (IsBasicNote(semi+1)) 
            return visual;
        break;
    case VLNote::kWant2Sharp:
        if (IsBasicNote(semi-2)) 
            return visual;
        else
            return VLNote::kWantSharp;
    case VLNote::kWantSharp:
        if (IsBasicNote(semi-1)) 
            return visual;
        break;
    default:
        break;
    }
    //
    // No visuals, or no match
    //
    visual &= ~VLNote::kAccidentalsMask;
    if (IsBasicNote(semi)) 
        return visual | VLNote::kWantNatural;
    else if (key <= 0) 
        return visual | VLNote::kWantFlat;
    else 
        return visual | VLNote::kWantSharp;
}

int VLPitchToGrid(int8_t pitch, uint16_t visual, int key)
{
    int semi    = pitch % 12;
    int octave  = (pitch/12)-5;
    
    switch (visual & VLNote::kAccidentalsMask) {
    case VLNote::kWantNatural:
        break;
    case VLNote::kWant2Flat:
        semi    +=  2;
        break;
    case VLNote::kWantFlat:
        semi    +=  1;
        break;
    case VLNote::kWant2Sharp:
        semi    -=  2;
        break;
    case VLNote::kWantSharp:
        semi    -=  1;
        break;
    default:
        if (IsBasicNote(semi)) {
            ;
        } else if (key <= 0) {
            semi       += 1;
        } else {
            semi       -= 1;
        } 
        break;
    }
    return SemiToStep(semi)+7*octave;
}

int8_t  VLGridToPitch(int gridPos, uint16_t visual, int key)
{
    int octave = VLNote::kMiddleC;
    
    while (gridPos > 6) {
        octave  +=  12;
        gridPos -=   7;
    }
    while (gridPos < 0) {
        octave  -=  12;
        gridPos +=   7;
    }
    int semi        = StepToSemi(gridPos);
    int accidental;
    switch (visual) {
    case VLNote::kWantFlat:
        accidental  = -1;
        break;
    case VLNote::kWant2Flat:
        accidental  = -2;
        break;
    case VLNote::kWantSharp:
        accidental  = 1;
        break;
    case VLNote::kWant2Sharp:
        accidental  = 2;
        break;
    case VLNote::kWantNatural:
        accidental  = 0;
        break;
    default:
        if (key > 0 && HasSharp(semi, key))
            accidental = 1;
        else if (key < 0 && HasFlat(semi, key))
            accidental = -1;
        else
            accidental = 0;
        break;
    }
    return octave+semi+accidental;
}

void VLVisualFilter::ResetWithKey(int key)
{
    memset(&fState[0], 0, 7*sizeof(fState[0]));
    switch (key) { // Almost every state falls through
    case -6:
        fState[0]   = VLNote::kWantFlat;
    case -5:
        fState[4]   = VLNote::kWantFlat;
    case -4:
        fState[1]   = VLNote::kWantFlat;
    case -3:
        fState[5]   = VLNote::kWantFlat;
    case -2:
        fState[2]   = VLNote::kWantFlat;
    case -1:
        fState[6]   = VLNote::kWantFlat;
    case 0:
        break;
    case 6:
        fState[2]   = VLNote::kWantSharp;
    case 5:
        fState[5]   = VLNote::kWantSharp;
    case 4:
        fState[1]   = VLNote::kWantSharp;
    case 3:
        fState[4]   = VLNote::kWantSharp;
    case 2:
        fState[0]   = VLNote::kWantSharp;
    case 1:
        fState[3]   = VLNote::kWantSharp;
    default:
        break;
    }
}

uint16_t VLVisualFilter::operator()(int gridPos, uint16_t visual)
{
    uint16_t acc    = visual & VLNote::kAccidentalsMask;
    gridPos         = (gridPos+700) % 7;
    if (acc == VLNote::kWantNatural)
        acc = 0;
    if (acc != fState[gridPos]) {
        fState[gridPos] = acc;
        if (!acc) 
            acc = VLNote::kWantNatural;
    } else {
        acc = 0;
    }
    return (visual & ~VLNote::kAccidentalsMask) | acc;
}
