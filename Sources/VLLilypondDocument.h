//
// File: VLLilypondDocument.h - Export document in LilyPond format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (Lilypond)

- (NSFileWrapper *)lilypondFileWrapperWithError:(NSError **)outError;

@end
