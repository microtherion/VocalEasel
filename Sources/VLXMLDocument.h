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

- (NSData *)XMLDataWithError:(NSError **)outError;
- (BOOL)readFromXMLData:(NSData *)data error:(NSError **)outError;

@end
