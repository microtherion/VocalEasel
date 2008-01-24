//
// File: VLGrooveController.mm - Control groove selection sheet
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#import "VLGrooveController.h"
#import "VLSheetView.h"
#import "VLDocument.h"

@implementation VLGrooveController

- (id) initWithSheetView:(VLSheetView *)view;
{
	self		= [super initWithWindowNibName:@"VLGroove"];
	fGrooves	= [[NSDictionary alloc] initWithContentsOfFile:
		[[NSBundle mainBundle] pathForResource:@"Grooves" ofType:@"plist"]];
	fSubStyleFilter	= 
		[[NSPredicate predicateWithFormat:
			@"!(SELF matches[c] '.*(Intro|End)\\\\d*$')"]
			retain];
	fView		= view;
	fDocument	= [view document];

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

- (IBAction) togglePlay:(id)sender
{
	if ([sender state])
		[fView playWithGroove:[[fBrowser selectedCellInColumn:1] stringValue]];
	else
		[fDocument stop:sender];
}

- (IBAction)endSheet:(id)sender
{
	[NSApp endSheet:[self window] returnCode:[sender tag]];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[fDocument stop:self];
	if (returnCode == NSAlertFirstButtonReturn)
		[fView setGroove:[[fBrowser selectedCellInColumn:1] stringValue]];
		
	[[self window] orderOut:self];
}

- (NSString *)browser:(NSBrowser *)sender titleOfColumn:(int)column
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
	fSubStyleList	= [[[fSubStyles objectForKey:@".ORDER"]
						   filteredArrayUsingPredicate:fSubStyleFilter]
						  retain];
}

- (int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column
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

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column
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
	[fPlayButton setEnabled:validStyle];
	if (validStyle) {
		[fDescription setStringValue:
			[NSString stringWithFormat:@"%@\n\n%@",
			    [fSubStyles objectForKey:@".DESC"],
			    [fSubStyles objectForKey:
				    [[fBrowser selectedCellInColumn:1] stringValue]]]];
		[fDocument stop:self];
		[self togglePlay:fPlayButton];
	} else
		[fDescription setStringValue:[fSubStyles objectForKey:@".DESC"]];
}

@end
