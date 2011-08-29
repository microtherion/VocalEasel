//
// File: VLSheetWindow.mm - Control lead sheet editing window
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#import "VLSheetWindow.h"
#import "VLDocument.h"


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

@implementation VLSheetWindow

- (id)initWithWindow:(NSWindow *)window
{
	if (self = [super initWithWindow:window]) {
		editTarget			= nil;
	}
	return self;
}

- (VLEditable *)editTarget
{
	return editTarget;
}

- (void)setEditTarget:(VLEditable *)editable
{
	editTarget = editable;
}

- (void)windowDidLoad
{
}

- (void) startAnimation
{
	[progressIndicator startAnimation:self];
}

- (void) stopAnimation
{
	[progressIndicator stopAnimation:self];
}

- (IBAction) zoomIn: (id) sender
{
	[sheetView zoomIn:sender];
}

- (IBAction) zoomOut: (id) sender
{
	[sheetView zoomOut:sender];
}

- (void) mouseMoved:(NSEvent *)event
{
	[sheetView mouseMoved:event];
}

- (void) willPlaySequence:(MusicSequence)music
{
	[sheetView willPlaySequence:music];
}

@end
