//
// File: VLXMLDocument.h - Read and write native (MusicXML) document format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (XML) 

- (NSFileWrapper *)XMLFileWrapperWithError:(NSError **)outError flat:(BOOL)flat;
- (BOOL)readFromXMLFileWrapper:(NSFileWrapper *)wrapper error:(NSError **)outError;

@end
