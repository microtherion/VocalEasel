//
//  VLGrooveController.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 2/1/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "VLGrooveController.h"
#import "VLSheetView.h"

@implementation VLGrooveController

- (id) initWithSheetView:(VLSheetView *)view;
{
	self		= [super initWithWindowNibName:@"VLGroove"];
	fGrooves	= [[NSDictionary alloc] initWithContentsOfFile:
		[[NSBundle mainBundle] pathForResource:@"Grooves" ofType:@"plist"]];
	fSubStyleFilter	= 
		[[NSPredicate predicateWithFormat:
			@"!(SELF like[c] '.DESC') AND !(SELF matches[c] '.*(Intro|End)\\\\d*$')"]
			retain];

	[NSApp beginSheet: [self window]
		   modalForWindow: [view window]
		   modalDelegate: self
		   didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
		   contextInfo: view];

	return self;
}

- (void) dealloc
{
	[fGrooves release];
	[super dealloc];
}

- (IBAction)endSheet:(id)sender
{
	[NSApp endSheet:[self window] returnCode:[sender tag]];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn)
		[(VLSheetView *)contextInfo setGroove:[[fBrowser selectedCellInColumn:1] stringValue]];
	
	[[self window] orderOut:self];
}

- (NSString *)browser:(NSBrowser *)sender titleOfColumn:(NSInteger)column
{
	if (!column)
		return @"Style";
	else
		return @"Substyle";
}

- (void)updateStyle
{
	[fStyle autorelease];
	[fSubStyleList release];
	fStyle	 		= [[[fBrowser selectedCellInColumn:0] stringValue] retain];
	fSubStyles		= [fGrooves objectForKey:fStyle];	
	fSubStyleList	= [[[fSubStyles allKeys]
						   filteredArrayUsingPredicate:fSubStyleFilter]
						  retain];
}

- (NSInteger)browser:(NSBrowser *)sender numberOfRowsInColumn:(NSInteger)column
{
	[fBrowser setTakesTitleFromPreviousColumn:NO];
	[fBrowser setDoubleAction:@selector(endSheet:)];

	if (!column) {
		return [fGrooves count];
	} else {
		[self updateStyle];
		return [fSubStyleList count];
	}
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(NSInteger)row column:(NSInteger)column
{
	if (!column) {
		[cell setStringValue:
				  [[[fGrooves allKeys] 
					   sortedArrayUsingSelector:@selector(compare:)]
					  objectAtIndex:row]];
	} else {
		[cell setStringValue:[fSubStyleList objectAtIndex:row]];
		[cell setLeaf:YES];
	}
}

- (IBAction)updateDescription:(id)sender
{
	BOOL validStyle = [fBrowser selectedColumn];
	[fOKButton setEnabled:validStyle];
	if (validStyle) 
		[fDescription setStringValue:
			[NSString stringWithFormat:@"%@\n\n%@",
			    [fSubStyles objectForKey:@".DESC"],
			    [fSubStyles objectForKey:
				    [[fBrowser selectedCellInColumn:1] stringValue]]]];
	else
		[fDescription setStringValue:[fSubStyles objectForKey:@".DESC"]];
}

@end
