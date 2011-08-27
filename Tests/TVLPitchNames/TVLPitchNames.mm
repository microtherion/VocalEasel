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
    { std::string cppStr = [str UTF8String]; uint16_t acc; \
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

@end
