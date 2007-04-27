//
// File: VLSheetViewSelection.mm - Measure selection functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import "VLSheetView.h"
#import "VLSheetViewSelection.h"
#import "VLDocument.h"

//	
// We're too lazy to properly serialize our private pasteboard format.
//
static VLSong	sPasteboard;

@implementation VLSheetView (Selection)

- (void)editSelection
{
	fSelStart	= fSelEnd	= fCursorMeasure;
	[self setNeedsDisplay:YES];	
}

- (void)adjustSelection:(NSEvent *)event
{
	int prevMeasure = fCursorMeasure;
	switch ([self findRegionForEvent:event]) {
	case kRegionNote:
	case kRegionChord:
	case kRegionLyrics:
		if (fCursorAt.fNum)
			++fCursorMeasure;
		//
		// Fall through
		//
	case kRegionMeasure:
		fCursorMeasure = 
			std::max(0, std::min<int>(fCursorMeasure, [self song]->CountMeasures()));
		if (fCursorMeasure > fSelEnd) {
			fSelEnd		= fCursorMeasure;
			[self setNeedsDisplay:YES];
		} else if (fCursorMeasure < fSelStart) {
			fSelStart	= fCursorMeasure;
			[self setNeedsDisplay:YES];
		} else if (prevMeasure == fSelEnd && fCursorMeasure<prevMeasure) {
			fSelEnd		= fCursorMeasure;
			[self setNeedsDisplay:YES];
		} else if (prevMeasure == fSelStart && fCursorMeasure>prevMeasure) {
			fSelStart	= fCursorMeasure;
			[self setNeedsDisplay:YES];
		}
		break;
	default:
		fCursorMeasure	= prevMeasure;
		break;
	}
	fCursorRegion = kRegionMeasure;
}

- (BOOL)validateMenuItem:(id) item
{
	SEL action = [item action];
	if (action == @selector(insertJumpToCoda:))
		if (fSelStart == fSelEnd) {
			[item setState:[self song]->fGoToCoda==fSelStart];
			
			return YES;
		} else
			return NO;
	else if (action == @selector(insertStartCoda:))
		if (fSelStart == fSelEnd) {
			[item setState:[self song]->fCoda==fSelStart];
			
			return YES;
		} else
			return NO;
	else 
		return [self validateUserInterfaceItem:item];
}

- (BOOL)validateUserInterfaceItem:(id) item
{
	SEL action = [item action];
	if (action == @selector(cut:) 
	 || action == @selector(copy:)
	 || action == @selector(delete:)
    )
		return fSelStart < fSelEnd;
	else if (action == @selector(editRepeat:))
		return fSelEnd > fSelStart 
			&& [self song]->CanBeRepeat(fSelStart, fSelEnd);
	else if (action == @selector(editRepeatEnding:))
		return fSelEnd > fSelStart
			&& [self song]->CanBeEnding(fSelStart, fSelEnd);
	else if (action == @selector(paste:))
		return fSelStart <= fSelEnd;
	else
		return YES;
}

- (IBAction)cut:(id)sender
{
	[self copy:sender];	
	[self delete:sender];
}

- (IBAction)copy:(id)sender
{
	NSPasteboard * pb = [NSPasteboard generalPasteboard];
	NSString * pbType = [[NSBundle mainBundle] bundleIdentifier];
	
	[pb declareTypes:[NSArray arrayWithObject:pbType] owner:nil];
	if ([pb setString:@"whatever" forType:pbType])
		sPasteboard = [self song]->CopyMeasures(fSelStart, fSelEnd);
}

- (IBAction)paste:(id)sender
{
	NSPasteboard * pb = [NSPasteboard generalPasteboard];
	NSString * pbType = [[NSBundle mainBundle] bundleIdentifier];

	if ([pb availableTypeFromArray:[NSArray arrayWithObject:pbType]]) {
		[[self document] willChangeSong];
		if (![sender tag]) // Delete on paste, but not on overwrite 
			[self song]->DeleteMeasures(fSelStart, fSelEnd);
		[self song]->PasteMeasures(fSelStart, sPasteboard, [sender tag]);
		[[self document] didChangeSong];
		[self setNeedsDisplay:YES];
	}
}

- (IBAction)delete:(id)sender
{
	[[self document] willChangeSong];
	[self song]->DeleteMeasures(fSelStart, fSelEnd);
	[[self document] didChangeSong];
	[self setNeedsDisplay:YES];
}

- (IBAction)editRepeat:(id)sender
{
	int volta;
	[self song]->CanBeRepeat(fSelStart, fSelEnd, &volta);

	[fRepeatMsg setStringValue:
					[NSString stringWithFormat:@"Repeat measures %d through %d",
							  fSelStart+1, fSelEnd]];
	[NSApp beginSheet:fRepeatSheet modalForWindow:[self window]
		   modalDelegate:self 
		   didEndSelector:@selector(didEndRepeatSheet:returnCode:contextInfo:)
		   contextInfo:nil];
}

- (void)didEndRepeatSheet:(NSWindow *)sheet returnCode:(int)returnCode 
			  contextInfo:(void *)ctx
{
	switch (returnCode) {
	case NSAlertFirstButtonReturn:
		[[self document] willChangeSong];
		[self song]->AddRepeat(fSelStart, fSelEnd, [[self document] repeatVolta]);
		[self setNeedsDisplay:YES];
		[[self document] didChangeSong];
		break;
	case NSAlertThirdButtonReturn:
		[[self document] willChangeSong];
		[self song]->DelRepeat(fSelStart, fSelEnd);
		[[self document] didChangeSong];
		[self setNeedsDisplay:YES];
		break;
	default:
		break;
	}	
	[sheet orderOut:self];
}

- (IBAction)editRepeatEnding:(id)sender
{
	[self song]->CanBeEnding(fSelStart, fSelEnd, &fVolta, &fVoltaOK);

	[fEndingMsg setStringValue:
					[NSString stringWithFormat:@"Ending in measures %d through %d applies to repeats:",
							  fSelStart+1, fSelEnd]];

	[NSApp beginSheet:fEndingSheet modalForWindow:[self window]
		   modalDelegate:self 
		   didEndSelector:@selector(didEndEndingSheet:returnCode:contextInfo:)
		   contextInfo:nil];
}

- (void)didEndEndingSheet:(NSWindow *)sheet returnCode:(int)returnCode 
			  contextInfo:(void *)ctx
{
	switch (returnCode) {
	case NSAlertFirstButtonReturn:
		[[self document] willChangeSong];
		[self song]->AddEnding(fSelStart, fSelEnd, fVolta);
		[self setNeedsDisplay:YES];
		[[self document] didChangeSong];
		break;
	case NSAlertThirdButtonReturn:
		[[self document] willChangeSong];
		[self song]->DelEnding(fSelStart, fSelEnd);
		[[self document] didChangeSong];
		[self setNeedsDisplay:YES];
		break;
	default:
		break;
	}	
	[sheet orderOut:self];
}

//
// Data source for endings
//
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return 1;
}

- (id)tableView:(NSTableView*)tv objectValueForTableColumn:(NSTableColumn *)col
			row:(int)rowIndex
{
	int mask = [[col identifier] intValue];
	return (fVoltaOK & mask) ? [NSNumber numberWithBool:(fVolta & mask)] : nil;
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)val forTableColumn:(NSTableColumn *)col row:(int)rowIndex
{
	int mask = [[col identifier] intValue];

	if ([val boolValue])
		fVolta	|= mask;
	else
		fVolta  &= ~mask;
}

- (IBAction)insertJumpToCoda:(id)sender
{
	[[self document] willChangeSong];
	VLSong * song = [self song];
	if (song->fGoToCoda == fSelStart)
		song->fGoToCoda = -1;
	else
		song->fGoToCoda = fSelStart;
	[self setNeedsDisplay:YES];
	[[self document] didChangeSong];
}

- (IBAction)insertStartCoda:(id)sender
{
	[[self document] willChangeSong];
	VLSong * song = [self song];
	if (song->fCoda == fSelStart)
		song->fCoda = -1;
	else
		song->fCoda = fSelStart;
	[self setNeedsDisplay:YES];
	[[self document] didChangeSong];
}

@end
