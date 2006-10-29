//
//  VLXMLDocument.h
//  Vocalese
//
//  Created by Matthias Neeracher on 10/10/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (XML) 

- (NSFileWrapper *)XMLFileWrapperWithError:(NSError **)outError flat:(BOOL)flat;
- (BOOL)readFromXMLFileWrapper:(NSFileWrapper *)wrapper error:(NSError **)outError;

@end
