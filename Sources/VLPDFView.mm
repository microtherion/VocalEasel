//
//  VLPDFView.m
//  Lilypond
//
//  Created by Matthias Neeracher on 5/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "VLPDFView.h"

@implementation VLPDFView

- (BOOL)tryOpenURL:(NSURL *)url
{
	if ([[url scheme] isEqual: @"textedit"]) {
		//
		// Handle TextEdit links internally
		//
		NSString *	path		= [url path];
		NSArray  *	components	= [[path lastPathComponent] componentsSeparatedByString: @":"];
		unsigned	count		= [components count];
		if (count > 2) {
			int	line	= [[components objectAtIndex: count-2] intValue];
			int	pos		= [[components objectAtIndex: count-1] intValue];
			
			[[[[self window] windowController] document] selectCharacter:pos inLine:line];
		}
		return YES;
	} else
		return [super tryOpenURL:url] != NULL;
}

- (BOOL) canBecomeKeyView
{
	return YES;
}

@end
