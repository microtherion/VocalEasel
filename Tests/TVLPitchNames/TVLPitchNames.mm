//
//  TVLPitchNames.m
//  TVLPitchNames
//
//  Created by Matthias Neeracher on 8/27/11.
//  Copyright 2011 Matthias Neeracher
//

#import "TVLPitchNames.h"
#import "TVLStringAccidentals.h"
#import "VLPitchName.h"
#import "VLModel.h"

@implementation TVLPitchNames

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#define TestPitchName(expected, pitch, accidental) \
    STAssertEqualObjects(expected, \
        [NSString stringWithUTF8String:VLPitchName(pitch, accidental).c_str()], \
        @"VLPitchName(%d, %d)", pitch, accidental);

- (void)testPitchName
{
    //
    // These pitches should cover all cases
    //
    const int8_t kC     = VLNote::kMiddleC;     // Beginning of octave, 1 step below, 2 above
    const int8_t kCis   = VLNote::kMiddleC+1;   // 1&2 steps below, 1 above
    const int8_t kD     = VLNote::kMiddleC+2;   // 2 steps below, 2 above
    const int8_t kBes   = VLNote::kMiddleC+10;  // 1 step below, 1&2 above
    const int8_t kB     = VLNote::kMiddleC+11;  // End of octave, 2 steps below, 1 above
    const int8_t kF     = VLNote::kMiddleC+5;   // Test name only
    const int8_t kG     = VLNote::kMiddleC+7;   // Test name only
    
    TestPitchName(@"C",                 kC,     0);
    TestPitchName([@"C" natural],       kC,     VLNote::kWantNatural);
    TestPitchName(@"C",                 kC,     VLNote::kPreferSharps);
    TestPitchName(@"C",                 kC,     VLNote::kPreferFlats);
    TestPitchName([@"B" sharp],         kC,     VLNote::kWantSharp);
    TestPitchName(@"C",                 kC,     VLNote::kWantFlat);
    TestPitchName([@"B" sharp],         kC,     VLNote::kWant2Sharp);
    TestPitchName([@"D" doubleFlat],    kC,     VLNote::kWant2Flat);
    TestPitchName([@"C" natural],       kC,     VLNote::kNaturalOrSharp);
    TestPitchName([@"C" natural],       kC,     VLNote::kNaturalOrFlat);
    
    TestPitchName([@"C" sharp],         kCis,   0);
    TestPitchName([@"C" sharp],         kCis,   VLNote::kWantNatural);
    TestPitchName([@"C" sharp],         kCis,   VLNote::kPreferSharps);
    TestPitchName([@"D" flat],          kCis,   VLNote::kPreferFlats);
    TestPitchName([@"C" sharp],         kCis,   VLNote::kWantSharp);
    TestPitchName([@"D" flat],          kCis,   VLNote::kWantFlat);
    TestPitchName([@"B" doubleSharp],   kCis,   VLNote::kWant2Sharp);
    TestPitchName([@"D" flat],          kCis,   VLNote::kWant2Flat);
    TestPitchName([@"C" sharp],         kCis,   VLNote::kNaturalOrSharp);
    TestPitchName([@"D" flat],          kCis,   VLNote::kNaturalOrFlat);
    
    TestPitchName(@"D",                 kD,     0);
    TestPitchName([@"D" natural],       kD,     VLNote::kWantNatural);
    TestPitchName(@"D",                 kD,     VLNote::kPreferSharps);
    TestPitchName(@"D",                 kD,     VLNote::kPreferFlats);
    TestPitchName(@"D",                 kD,     VLNote::kWantSharp);
    TestPitchName(@"D",                 kD,     VLNote::kWantFlat);
    TestPitchName([@"C" doubleSharp],   kD,     VLNote::kWant2Sharp);
    TestPitchName([@"E" doubleFlat],    kD,     VLNote::kWant2Flat);

    TestPitchName(@"F",                 kF,     0);
    TestPitchName(@"G",                 kG,     0);
    
    TestPitchName([@"A" sharp],         kBes,   0);
    TestPitchName([@"A" sharp],         kBes,   VLNote::kWantNatural);
    TestPitchName([@"A" sharp],         kBes,   VLNote::kPreferSharps);
    TestPitchName([@"B" flat],          kBes,   VLNote::kPreferFlats);
    TestPitchName([@"A" sharp],         kBes,   VLNote::kWantSharp);
    TestPitchName([@"B" flat],          kBes,   VLNote::kWantFlat);
    TestPitchName([@"A" sharp],         kBes,   VLNote::kWant2Sharp);
    TestPitchName([@"C" doubleFlat],    kBes,   VLNote::kWant2Flat);
    TestPitchName([@"A" sharp],         kBes,   VLNote::kNaturalOrSharp);
    TestPitchName([@"B" flat],          kBes,   VLNote::kNaturalOrFlat);
    
    TestPitchName(@"B",                 kB,     0);
    TestPitchName([@"B" natural],       kB,     VLNote::kWantNatural);
    TestPitchName(@"B",                 kB,     VLNote::kPreferSharps);
    TestPitchName(@"B",                 kB,     VLNote::kPreferFlats);
    TestPitchName(@"B",                 kB,     VLNote::kWantSharp);
    TestPitchName([@"C" flat],          kB,     VLNote::kWantFlat);
    TestPitchName([@"A" doubleSharp],   kB,     VLNote::kWant2Sharp);
    TestPitchName([@"C" flat],          kB,     VLNote::kWant2Flat);
    TestPitchName([@"B" natural],       kB,     VLNote::kNaturalOrSharp);
    TestPitchName([@"B" natural],       kB,     VLNote::kNaturalOrFlat);
}

#define TestParsePitchAtOffset(pitch, accidental, str, at) \
    do { std::string cppStr = [str UTF8String]; uint16_t acc; \
      STAssertEquals(pitch, (int)VLParsePitch(cppStr, at, &acc),@"VLParsePitch(%@, %lu)", str, at); \
      STAssertEquals((uint16_t)accidental, acc,                 @"VLParsePitch(%@, %lu) [accidental]", str, at); \
      STAssertEquals((size_t)at, cppStr.size(),                 @"VLParsePitch(%@, %lu) [cleanup]", str, at); \
    } while (0)
        
#define TestParsePitch(pitch, accidental, str) TestParsePitchAtOffset(pitch,accidental,str,0)

- (void)testParsePitch
{
    const int kBes   = VLNote::kMiddleC-2;
    const int kCes   = VLNote::kMiddleC-1;
    const int kC     = VLNote::kMiddleC;
    const int kCis   = VLNote::kMiddleC+1;
    const int kD     = VLNote::kMiddleC+2;    
    const int kE     = VLNote::kMiddleC+4;    
    const int kF     = VLNote::kMiddleC+5;    
    const int kB     = VLNote::kMiddleC+11;   
    
    TestParsePitch(kC,      0, @"C");
    TestParsePitch(kC,      VLNote::kWantNatural,   [@"C" natural]);
    TestParsePitch(kCes,    VLNote::kWantFlat,      [@"C" flat]);
    TestParsePitch(kCes,    VLNote::kWantFlat,      @"cb");
    TestParsePitch(kCis,    VLNote::kWantSharp,     [@"C" sharp]);
    TestParsePitch(kCis,    VLNote::kWantSharp,     @"C#");
    TestParsePitch(kBes,    VLNote::kWant2Flat,     [@"C" doubleFlat]);
    TestParsePitch(kBes,    VLNote::kWant2Flat,     @"CbB");
    TestParsePitch(kD,      VLNote::kWant2Sharp,    [@"C" doubleSharp]);
    TestParsePitch(kD,      VLNote::kWant2Sharp,    @"C##");
    
    TestParsePitchAtOffset(kE, 0,                   @"xE",              1);
    TestParsePitchAtOffset(kE, VLNote::kWantFlat,   [@"xF" flat],       1);
    TestParsePitchAtOffset(kF, VLNote::kWant2Flat,  @"CGBb",            1);
    TestParsePitchAtOffset(kB, VLNote::kWant2Sharp, [@"gA" doubleSharp],1);
    TestParsePitchAtOffset(kB, 0,                   @"C/B",             2);
}

#define TestChord(base, ext, root, stp, str) \
    do {   int8_t pitch; uint16_t accidental; uint32_t steps; int8_t rootPitch; uint16_t rootAccidental; \
        std::string baseName, extName, rootName, cppStr = [str UTF8String]; \
        pitch = VLParseChord(cppStr, &accidental, &steps, &rootPitch, &rootAccidental); \
        STAssertEquals((size_t)0, cppStr.size(),                @"VLParseChord(%@)", str); \
        STAssertEquals((uint32_t)stp, steps,                    @"VLParseChord(%@)", str); \
        VLChordName(pitch, accidental, steps, rootPitch, rootAccidental, baseName, extName, rootName); \
        STAssertEqualObjects(base, [NSString stringWithUTF8String:baseName.c_str()], \
                             @"VLChordName(%@ <%d,%d,%08x,%d,%d>) [base]", str, \
                             pitch, accidental, steps, rootPitch, rootAccidental); \
        STAssertEqualObjects(ext, [NSString stringWithUTF8String:extName.c_str()], \
                             @"VLChordName(%@ <%d,%d,%08x,%d,%d>) [ext]", str, \
                            pitch, accidental, steps, rootPitch, rootAccidental); \
        STAssertEqualObjects(root, [NSString stringWithUTF8String:rootName.c_str()], \
                            @"VLChordName(%@ <%d,%d,%08x,%d,%d>) [root]", str, \
                            pitch, accidental, steps, rootPitch, rootAccidental); \
    } while (0)

- (void)testChords
{
    //
    // Chords appearing in The New Real Book
    //
    TestChord(@"C",         @"",        @"",                0x00000091, @"c");
    TestChord(@"C",         @"6",       [@"B" sharp],       0x00000291, @"c6/b#");
    TestChord(@"C",         @"69",      [@"G" flat],        0x00004291, @"c69/gb");
    TestChord(@"C",         @"add9",    @"",                0x00004091, @"cadd9");
    TestChord([@"C" sharp], @"Maj7",    @"",                0x00000891, @"c#maj");
    TestChord([@"C" flat],  @"Maj7add13", @"",              0x00200891, @"cbmajadd13");
    TestChord(@"C",         @"Maj9",    @"",                0x00004891, @"cmaj9");
    TestChord(@"C",         @"Maj13",   @"",                0x00224891, @"cmaj13");
    TestChord(@"C",         @"7",       @"",                0x00000491, @"c7");
    TestChord(@"C",         @"9",       @"",                0x00004491, @"C9");
    TestChord(@"C",         @"13",      @"",                0x00224491, @"c13");
    TestChord(@"Dm",        @"",        @"",                0x00000089, @"dm");
    TestChord(@"Em",        @"6",       @"",                0x00000289, @"e-6");
    TestChord(@"Fm",        @"69",      @"",                0x00004289, @"fm69");
    TestChord(@"Gm",        @"add9",    @"",                0x00004089, @"gmadd9");
    TestChord(@"Am",        @"7",       @"",                0x00000489, @"am7");
    TestChord(@"Bm",        @"7add11",  @"",                0x00020489, @"bm7add11");
    TestChord(@"Cm",        @"9",       @"",                0x00004489, @"cm9");
    TestChord(@"Cm",        @"11",      @"",                0x00024489, @"cm11");
    TestChord(@"Cm",        @"13",      @"",                0x00224489, @"cm13");
    TestChord(@"Cm",        @"Maj7",    @"",                0x00000889, @"cmmaj");
    TestChord(@"Cm",        @"Maj9",    @"",                0x00004889, @"cm9maj7");
    TestChord(@"Cm",        [@"7" flat5],   @"",            0x00000449, @"cm7b5");
    TestChord(@"Cm",        [@"9" flat5],   @"",            0x00004449, @"cm9b5");
    TestChord(@"Cm",        [@"11" flat5],  @"",            0x00024449, @"cm11b5");
    TestChord(@"C",         @"dim",     @"",                0x00000049, @"cdim");
    TestChord(@"C",         @"dim7",    @"",                0x00000249, @"cdim7");
    // TestChord(@"C",         @"dim7Maj7",@"",             0x00000A49, @"cdim7maj");
    TestChord(@"C",         @"+",       @"",                0x00000111, @"c+");
    TestChord(@"C",         @"sus",     @"",                0x000000A1, @"csus");    
    TestChord(@"C",         @"7sus",    @"",                0x000004A1, @"csus7");    
    TestChord(@"C",         @"9sus",    @"",                0x000044A1, @"csus9");    
    TestChord(@"C",         @"13sus",   @"",                0x002244A1, @"csus13");
    // TestChord(@"C",      @"???", @"",                    ???, @"c7sus4-3");
    TestChord(@"C",         [@"Maj7" flat5], @"",           0x00000851, @"cmaj7b5");
    TestChord(@"C",         [@"Maj7" sharp5], @"",          0x00000911, @"cmaj7#5");
    TestChord(@"C",         [@"Maj7" sharp11], @"",         0x00040891, @"cmaj7#11");
    TestChord(@"C",         [@"Maj9" sharp11], @"",         0x00044891, @"cmaj9#11");
    TestChord(@"C",         [@"Maj13" sharp11], @"",        0x00244891, @"cmaj13#11");
    TestChord(@"C",         [@"7" flat5], @"",              0x00000451, @"c7b5");
    TestChord(@"C",         [@"9" flat5], @"",              0x00004451, @"c9-5");
    TestChord(@"C",         [@"7" sharp5], @"",             0x00000511, @"c7+5");
    TestChord(@"C",         [@"9" sharp5], @"",             0x00004511, @"c9#5");
    TestChord(@"C",         [@"7" flat9], @"",              0x00002491, @"c7b9");
    TestChord(@"C",         [@"7" sharp9], @"",             0x00008491, @"c7+9");
    TestChord(@"C",         [[@"7" flat5] flat9], @"",      0x00002451, @"c7b9b5");
    TestChord(@"C",         [[@"7" sharp5] sharp9], @"",    0x00008511, @"c7+9+5");
    TestChord(@"C",         [[@"7" sharp5] flat9], @"",     0x00002511, @"c7b9#5");
    TestChord(@"C",         [@"7" sharp11], @"",            0x00040491, @"c7#11");
    TestChord(@"C",         [@"9" sharp11], @"",            0x00044491, @"c9#11");
    TestChord(@"C",         [[@"7" flat9] sharp11], @"",    0x00042491, @"c7#11b9");
    TestChord(@"C",         [[@"7" sharp9] sharp11], @"",   0x00048491, @"c7+11+9");
    TestChord(@"C",         [@"13" flat5], @"",             0x00224451, @"c13-5");
    TestChord(@"C",         [@"13" flat9], @"",             0x00222491, @"c13-9");
    TestChord(@"C",         [@"13" sharp11], @"",           0x00244491, @"c13+11");
    TestChord(@"C",         [@"7sus" flat9], @"",           0x000024A1, @"csus7b9");    
    TestChord(@"C",         [@"13sus" flat9], @"",          0x002224A1, @"csus13b9");
    TestChord(@"C",         [@"Maj7sus" flat5], @"",        0x00000861, @"cmaj7sus-5");        
    // TestChord(@"C",         @"7susadd3", @"",            0x000004B1, @"csus7add3");    
    TestChord(@"C",         [@"add9" flat13], @"",          0x00104091, @"cadd9b13");
    TestChord(@"C",     [[[@"" sharp5] flat9] sharp9], @"", 0x0000A111, @"c+b9+9");
    TestChord(@"C",         @"Maj7sus",    @"",             0x000008A1, @"cmaj7sus");    
}

@end
