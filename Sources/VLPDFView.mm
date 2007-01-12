//
//  VLPDFView.m
//  Lilypond
//
//  Created by Matthias Neeracher on 5/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "VLPDFView.h"

#include <algorithm>

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

- (IBAction) displaySinglePage: (id) sender
{
	// Display single page mode.
	if ([self displayMode] > kPDFDisplaySinglePageContinuous)
		[self setDisplayMode: [self displayMode] - 2];
}

- (IBAction) displayTwoUp: (id) sender
{
	// Display two-up.
	if ([self displayMode] < kPDFDisplayTwoUp)
		[self setDisplayMode: [self displayMode] + 2];
}

- (IBAction) zoomToFit: (id) sender
{
	NSSize sz 	=  [self frame].size;
	NSSize frame=  [[self documentView] frame].size;
	
	float scale =  std::min(sz.width / frame.width, sz.height / frame.height);
	
	[self setScaleFactor: scale];
}

- (IBAction) zoomToFitWidth: (id) sender
{
	NSSize sz 	=  [self frame].size;
	NSSize frame=  [[self documentView] frame].size;
	
	[self setScaleFactor: sz.width / frame.width];
}

- (IBAction) zoomToActualSize: (id) sender
{
	[self setScaleFactor: 1.0];
}

@end