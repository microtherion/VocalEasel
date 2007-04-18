//
//  VLPDFDocument.h
//  Vocalese
//
//  Created by Matthias Neeracher on 10/20/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (PDF)

- (NSFileWrapper *)pdfFileWrapperWithError:(NSError **)outError;

@end
