//
//  VLLilypondDocument.h
//  Vocalese
//
//  Created by Matthias Neeracher on 10/20/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (Lilypond)

- (NSData *)lilypondDataWithError:(NSError **)outError;

@end
