//
//  MyDocument.h
//  Vocalese
//
//  Created by Matthias Neeracher on 12/17/05.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.
//

#import "VLModel.h"
#import <Cocoa/Cocoa.h>

@interface VLEditable : NSObject 
{
}

- (NSString *) stringValue;
- (void) setStringValue:(NSString*)val;
- (BOOL) validValue:(NSString*)val;

@end

@interface VLDocument : NSDocument
{
	VLSong *	song;
	VLEditable *editTarget;
}

- (VLSong *)	song;
- (NSNumber *)	songKey;
- (NSNumber *)  songTime;
- (NSNumber *)  songDivisions;

- (void)		setKey:(int)key transpose:(BOOL)transpose;
- (void)		setTimeNum:(int)num denom:(int)denom;
- (void)		setDivisions:(int)divisions;

@end
