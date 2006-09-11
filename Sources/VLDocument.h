//
//  MyDocument.h
//  Vocalese
//
//  Created by Matthias Neeracher on 12/17/05.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "VLModel.h"

@interface VLDocument : NSDocument
{
	VLSong *	song;
}

- (VLSong *)	song;
- (NSNumber *)	songKey;
- (NSNumber *)  songTime;
- (NSNumber *)  songDivisions;

- (void)		setKey:(int)key transpose:(BOOL)transpose;
- (void)		setTimeNum:(int)num denom:(int)denom;
- (void)		setDivisions:(int)divisions;
@end
