//
// File: VLMMADocument.h - Export document in MMA format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (MMA)

- (NSFileWrapper *)mmaFileWrapperWithError:(NSError **)outError;

@end
