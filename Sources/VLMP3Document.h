//
// File: VLMP3Document.h - Export document in MP3 format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2008 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (MP3)

- (NSFileWrapper *)mp3FileWrapperWithError:(NSError **)outError;

@end
