//
// File: VLPDFDocument.h - Export document in PDF format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (PDF)

- (NSFileWrapper *)pdfFileWrapperWithError:(NSError **)outError;

@end
