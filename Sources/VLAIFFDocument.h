//
// File: VLAIFFDocument.h - Export document in AIFF format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2008 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (AIFF)

- (NSFileWrapper *)aiffFileWrapperWithError:(NSError **)outError;

@end
