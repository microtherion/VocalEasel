//
//  MyDocument.m
//  Vocalese
//
//  Created by Matthias Neeracher on 12/17/05.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.
//

#import "VLDocument.h"
#import "VLXMLDocument.h"
#import "VLLilypondDocument.h"

@implementation VLEditable

- (NSString *) stringValue
{
	return @"";
}

- (void) setStringValue:(NSString*)val
{
}

- (BOOL) validValue:(NSString*)val
{
	return YES;
}

- (void) moveToNext
{
}

- (void) moveToPrev
{
}

- (void) highlightCursor
{
}

@end

@implementation VLDocument

- (id)init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    
		song 				= new VLSong;
		editTarget			= nil;
		lilypondTemplate	= @"default";
    }
    return self;
}

- (void) dealloc
{
	delete song;
	[super dealloc];
}

- (VLSong *) song
{
	return song;
}

- (NSNumber *)	songKey
{
	const VLProperties & prop = song->fProperties.front();

	return [NSNumber numberWithInt: (prop.fKey << 8) | (prop.fMode & 0xFF)];
}

- (void) setKey:(int)key transpose:(BOOL)transpose
{
	VLProperties & prop = song->fProperties.front();

	if (transpose)
		song->Transpose((7*((key>>8)-prop.fKey) % 12));

	prop.fKey = key >> 8;
	prop.fMode= key & 0xFF;

	[self updateChangeCount:NSChangeDone];
}

- (NSNumber *)  songTime
{
	const VLProperties & prop = song->fProperties.front();

	return [NSNumber numberWithInt: (prop.fTime.fNum << 8) | prop.fTime.fDenom];
}

- (void) setTimeNum:(int)num denom:(int)denom
{
	VLProperties & prop = song->fProperties.front();

	prop.fTime = VLFraction(num, denom);

	[self updateChangeCount:NSChangeDone];
}

- (NSNumber *) songDivisions
{
	const VLProperties & prop = song->fProperties.front();

	return [NSNumber numberWithInt: prop.fDivisions];	
}

- (void) setDivisions:(int)divisions
{
	VLProperties & prop = song->fProperties.front();

	prop.fDivisions	= divisions;

	[self updateChangeCount:NSChangeDone];
}

- (NSString *)windowNibName
{
    return @"VLDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) controller
{
    [super windowControllerDidLoadNib:controller];
	[controller setShouldCloseDocument:YES];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if ([typeName isEqual:@"Song"])
		return [self XMLDataWithError:outError];
	else if ([typeName isEqual:@"Lilypond"])
		return [self lilypondDataWithError:outError];
	else
		return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	if ([typeName isEqual:@"Song"])
		return [self readFromXMLData:data error:outError];
	else
		return NO;
}

@end
