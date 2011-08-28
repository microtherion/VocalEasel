//
//  TVLPitchGrid.m
//  TVLPitchGrid
//
//  Created by Matthias Neeracher on 8/28/11.
//  Copyright 2011 Matthias Neeracher
//

#import "TVLPitchGrid.h"
#import "VLPitchGrid.h"
#import "VLModel.h"

@implementation TVLPitchGrid

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#define TestPitchToGrid(grid,visualOut,pitch,visualIn,key) \
    do {    uint16_t vis = VLPitchAccidental(pitch, visualIn, key); \
            STAssertEquals(grid, VLPitchToGrid(pitch,vis,key),\
                @"VLPitchToGrid(%d,%02x,%d)", pitch, visualIn, key);\
            STAssertEquals((uint16_t)visualOut, vis,\
                @"VLPitchToGrid(%d,%02x,%d) [acc]", pitch, visualIn, key);\
    } while (0)
                    
- (void)testPitchToGrid
{
    TestPitchToGrid(  0,  VLNote::kWantNatural, 60, 0,                      0);    // Middle C, C Major
    TestPitchToGrid(  0,  VLNote::kWantNatural, 60, 0,                      2);    // Middle C, D Major
    TestPitchToGrid(  0,  VLNote::kWantNatural, 60, 0,                     -5);    // Middle C, Db Major
    TestPitchToGrid(  0,  VLNote::kWantNatural, 60, 0,                     -6);    // Middle C, Gb Major
    TestPitchToGrid(  0,  VLNote::kWantNatural, 60, VLNote::kWantNatural,   0);
    TestPitchToGrid( -1,  VLNote::kWantSharp,   60, VLNote::kWantSharp,     0);
    TestPitchToGrid(  0,  VLNote::kWantNatural, 60, VLNote::kWantFlat,      0);
    TestPitchToGrid(  0,  VLNote::kWantNatural, 60, VLNote::kWantFlat,      2);
    TestPitchToGrid( -1,  VLNote::kWantSharp,   60, VLNote::kWant2Sharp,    0);
    TestPitchToGrid(  1,  VLNote::kWant2Flat,   60, VLNote::kWant2Flat,     0);

    TestPitchToGrid(  1,  VLNote::kWantFlat,    61, 0,                      0);    // D flat, C Major
    TestPitchToGrid(  1,  VLNote::kWantFlat,    61, 0,                     -1);    // D flat, F Major
    TestPitchToGrid(  1,  VLNote::kWantFlat,    61, 0,                     -4);    // D flat, Ab Major
    TestPitchToGrid(  0,  VLNote::kWantSharp,   61, 0,                      1);    // D flat, G Major
    TestPitchToGrid(  0,  VLNote::kWantSharp,   61, 0,                      2);    // D flat, D Major
    TestPitchToGrid(  1,  VLNote::kWantFlat,    61, VLNote::kWantNatural,   0);
    TestPitchToGrid(  0,  VLNote::kWantSharp,   61, VLNote::kWantSharp,     0);
    TestPitchToGrid(  0,  VLNote::kWantSharp,   61, VLNote::kWantSharp,     2);
    TestPitchToGrid(  1,  VLNote::kWantFlat,    61, VLNote::kWantFlat,      0);
    TestPitchToGrid(  1,  VLNote::kWantFlat,    61, VLNote::kWantFlat,     -4);
    TestPitchToGrid( -1,  VLNote::kWant2Sharp,  61, VLNote::kWant2Sharp,    0);
    TestPitchToGrid(  1,  VLNote::kWantFlat,    61, VLNote::kWant2Flat,     0);

    TestPitchToGrid(  1,  VLNote::kWantNatural, 62, 0,                      0);    // D, C Major
    TestPitchToGrid(  1,  VLNote::kWantNatural, 62, VLNote::kWantNatural,   0);
    TestPitchToGrid(  1,  VLNote::kWantNatural, 62, VLNote::kWantSharp,     0);
    TestPitchToGrid(  1,  VLNote::kWantNatural, 62, VLNote::kWantFlat,      0);
    TestPitchToGrid(  0,  VLNote::kWant2Sharp,  62, VLNote::kWant2Sharp,    0);
    TestPitchToGrid(  2,  VLNote::kWant2Flat,   62, VLNote::kWant2Flat,     0);
    
    TestPitchToGrid(  6,  VLNote::kWantNatural, 71, 0,                      0);    // B, C Major
    TestPitchToGrid(  6,  VLNote::kWantNatural, 71, VLNote::kWantNatural,   0);
    TestPitchToGrid(  6,  VLNote::kWantNatural, 71, VLNote::kWantSharp,     0);
    TestPitchToGrid(  7,  VLNote::kWantFlat,    71, VLNote::kWantFlat,      0);
    TestPitchToGrid(  5,  VLNote::kWant2Sharp,  71, VLNote::kWant2Sharp,    0);
    TestPitchToGrid(  7,  VLNote::kWantFlat,    71, VLNote::kWant2Flat,     0);

    TestPitchToGrid(  7,  VLNote::kWantNatural, 72, 0,                      0);    // Octaves
    TestPitchToGrid( 14,  VLNote::kWantNatural, 84, 0,                      0);
    TestPitchToGrid( -7,  VLNote::kWantNatural, 48, 0,                      0);
}

#define TestGridToPitch(pitch,grid,visualIn,key) \
    do {    uint16_t vis = visualIn; \
            STAssertEquals(pitch, (int)VLGridToPitch(grid,vis,key),\
                @"VLGridToPitch(%d,%02x,%d)", grid, visualIn, key);\
    } while (0)

- (void)testGridToPitch
{
    TestGridToPitch(60,  0, 0,                      0);
    TestGridToPitch(60,  0, VLNote::kWantNatural,   0);
    TestGridToPitch(61,  0, 0,                      2);
    TestGridToPitch(60,  0, VLNote::kWantNatural,   2);
    TestGridToPitch(59,  0, 0,                     -6);
    TestGridToPitch(60,  0, VLNote::kWantNatural,  -6);
    TestGridToPitch(61,  0, VLNote::kWantSharp,     0);
    TestGridToPitch(59,  0, VLNote::kWantFlat,      0);
    TestGridToPitch(62,  0, VLNote::kWant2Sharp,    0);
    TestGridToPitch(58,  0, VLNote::kWant2Flat,     0);
    TestGridToPitch(48, -7, 0,                      0);
    TestGridToPitch(72,  7, 0,                      0);
}

#define TestVisualFilter(visualOut, grid, visualIn, filter) \
    STAssertEquals((uint16_t)visualOut, filter(grid, visualIn), \
        @"VLVisualFilter(%d,%02x)", grid, visualIn);

- (void)testVisualFilter
{
    VLVisualFilter  filterBbMajor(-2);
    
    TestVisualFilter(0,                     0,  VLNote::kWantNatural,   filterBbMajor);
    TestVisualFilter(VLNote::kWantFlat,     0,  VLNote::kWantFlat,      filterBbMajor);
    TestVisualFilter(VLNote::kWantNatural,  0,  VLNote::kWantNatural,   filterBbMajor);
    TestVisualFilter(VLNote::kWantSharp,    0,  VLNote::kWantSharp,     filterBbMajor);
    TestVisualFilter(0,                     2,  VLNote::kWantFlat,      filterBbMajor);
    TestVisualFilter(VLNote::kWantSharp,    2,  VLNote::kWantSharp,     filterBbMajor);
    TestVisualFilter(VLNote::kWantNatural,  2,  VLNote::kWantNatural,   filterBbMajor);
}
@end
