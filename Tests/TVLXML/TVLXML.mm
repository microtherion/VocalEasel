//
//  TVLXML.mm
//  TVLXML
//
//  Created by Matthias Neeracher on 9/2/11.
//  Copyright 2011 Apple Computer. All rights reserved.
//

#import "TVLXML.h"
#import "VLDocument.h"

@implementation TVLXML

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    // Tear-down code here.
}

- (void)testXMLRoundTrip
{
    NSError *       err;
    
    NSURL *         dtdURL      = [[NSBundle bundleForClass:[TVLXML class]] URLForResource:@"partwise" withExtension:@"dtd"];
    NSXMLDTD    *   dtd         = [[NSXMLDTD alloc] initWithContentsOfURL:dtdURL options:0 error:&err];
    [dtd setName:@"partwise.dtd"];
    
    STAssertNotNil(dtd, @"DTD: %@\n", [err localizedDescription]);
    
    NSString *      testDirPath = [NSString stringWithFormat:@"%s/TestData/XML", PROJECT_DIR];
    NSURL *         testDirURL  = [NSURL fileURLWithPath:testDirPath isDirectory:YES];
    NSFileWrapper * testDir     = [[NSFileWrapper alloc] initWithURL:testDirURL options:0 error:&err];
    NSArray *       testCases   = [[testDir fileWrappers] allValues];
    
    STAssertTrue([testCases count] > 0, @"Count Test Cases");
    
    for (NSFileWrapper * testCase in testCases) {
        NSString * testName = [testCase filename];
        if (![[testName pathExtension] isEqual:@"xml"])
            continue;
        
        VLDocument *    doc     = [[VLDocument alloc] init];
        
        BOOL            succ    = [doc readFromFileWrapper:testCase ofType:VLMusicXMLType error:&err];
        STAssertTrue(succ, @"Reading `%@': %@\n", testName, [err localizedDescription]);
        
        NSFileWrapper * written = [doc fileWrapperOfType:VLMusicXMLType error:&err];
        STAssertNotNil(written, @"Writing `%@': %@", testName, [err localizedDescription]);
        
        NSXMLDocument * xml     = [[NSXMLDocument alloc] initWithData:[written regularFileContents] options:0 error:&err];
        STAssertNotNil(xml, @"Parsing `%@': %@", testName, [err localizedDescription]);
        
        [xml setDTD:dtd];
        STAssertTrue([xml validateAndReturnError:&err], @"Validating `$@': %@", testName, [err localizedDescription]);
    }
}

@end
