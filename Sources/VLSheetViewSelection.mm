//
// File: VLSheetViewSelection.mm - Measure selection functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2011 Matthias Neeracher
//

#import "VLSheetView.h"
#import "VLSheetViewNotes.h"
#import "VLSheetViewSelection.h"
#import "VLSheetViewNotes.h"
#import "VLSheetViewChords.h"
#import "VLSheetViewLyrics.h"
#import "VLSheetWindow.h"
#import "VLDocument.h"
#import "VLPitchGrid.h"
#import "VLSoundOut.h"
#import "VLMIDIWriter.h"

#pragma mark VLMeasureEditable

@interface VLMeasureEditable : VLEditable {
    VLSheetView *   fView;
    uint32_t        fAnchor;
    VLRegion        fRegion;
}

- (VLMeasureEditable *)initWithView:(VLSheetView *)view anchor:(uint32_t)anchor;
- (BOOL)canExtendSelection:(VLRegion)region;
- (void)extendSelection:(VLLocation)at;
- (BOOL)hidden;

@end

@implementation VLMeasureEditable

- (VLMeasureEditable *)initWithView:(VLSheetView *)view anchor:(uint32_t)anchor
{
    fView   = view;
    fAnchor = anchor;
    [fView selectMeasure:fAnchor to:fAnchor];
    
    return self;
}

- (void)dealloc
{
    [fView selectMeasure:0 to:kNoMeasure];
    [super dealloc];
}

- (BOOL)canExtendSelection:(VLRegion)region
{
    switch ((fRegion = region)) {
    case kRegionNote:
    case kRegionChord:
    case kRegionLyrics:
    case kRegionMeasure:
        return YES;
    default:
        return NO;
    }
}

- (void)extendSelection:(VLLocation)at
{
    uint32_t meas = at.fMeasure;
	switch (fRegion) {
    case kRegionNote:
    case kRegionChord:
    case kRegionLyrics:
        if (at.fAt > VLFraction(0) && meas >= fAnchor)
            ++meas;
        //
        // Fall through
        //
    case kRegionMeasure:
        meas = std::max<uint32_t>(0, std::min<uint32_t>(meas, [fView song]->CountMeasures()));
        if (meas >= fAnchor) {
            [fView selectMeasure:fAnchor to:meas];
        } else {
            [fView selectMeasure:meas to:fAnchor];
        }
        break;
    default:
        break;
	}
}

- (BOOL)hidden
{
    return YES;
}

@end

#pragma mark -
#pragma mark VLPlaybackEditable

@interface VLPlaybackEditable : VLEditable {
	VLSheetView *	fView;
	size_t 			fStanza;
    VLLocation      fNote;
	int				fNoteVert;
    uint16_t        fNoteVisual;
	VLLocation      fChord;
}

- (VLPlaybackEditable *)initWithView:(VLSheetView *)view;
- (void) userEvent:(const VLMIDIUserEvent *)event;
- (void) highlightCursor;
- (BOOL) hidden;

@end

@implementation VLPlaybackEditable

- (VLPlaybackEditable *)initWithView:(VLSheetView *)view
{
	fView 			= view;
	fStanza			= 1;
	fNote.fMeasure	= 0x80000000;
	fChord.fMeasure	= 0x80000000;

	return self;
}

- (void)dealloc
{
    [fView setNeedsDisplay:YES];
}

- (void) userEvent:(const VLMIDIUserEvent *) event
{
	if (event->fPitch) {
		fNote           = event->fAt;
        fNoteVisual     = event->fVisual & VLNote::kAccidentalsMask;
        if (event->fPitch == VLNote::kNoPitch)
            fNoteVert   = kCursorNoPitch;
        else
            fNoteVert 	= VLPitchToGrid(event->fPitch, fNoteVisual, [fView song]->Properties(fNote.fMeasure).fKey);
		fStanza			= event->fStanza;
        VLLocation end  = fNote;
        end.fAt         = end.fAt+VLFraction(1,128);
		[fView highlightTextInStanza:fStanza start:fNote end:end]; 
	} else {
		fChord          = event->fAt;
	}
	[fView scrollMeasureToVisible:event->fAt.fMeasure+1];
	[fView setNeedsDisplay:YES];
}

- (void) highlightCursor
{
	if (fNote.fMeasure != 0x80000000 && fNoteVert != kCursorNoPitch)
        [fView drawNoteCursor:fNoteVert at:fNote visual:fNoteVisual];
	if (fChord.fMeasure != 0x80000000)
		[fView highlightChord:fChord];
}

- (BOOL) hidden
{
    return YES;
}

@end

@interface NSMenuItem (VLSetStateToOff)
- (void) VLSetStateToOff;
@end

@implementation NSMenuItem (VLSetStateToOff)

- (void) VLSetStateToOff
{
	[self setState:NSOffState];
}

@end

//	
// We're too lazy to properly serialize our private pasteboard format.
//
static VLSong	sPasteboard;

extern "C" void 
VLSequenceCallback(
				   void * inClientData, 
				   MusicSequence inSequence, MusicTrack inTrack, 
				   MusicTimeStamp inEventTime, const MusicEventUserData *inEventData, 
				   MusicTimeStamp inStartSliceBeat, MusicTimeStamp inEndSliceBeat)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [(id)inClientData userEvent:(const VLMIDIUserEvent *)inEventData];
    });
}

@implementation VLSheetView (Selection)

- (void)editSelection
{
    [self setEditTarget:[[VLMeasureEditable alloc] 
                         initWithView:self anchor:fCursorLocation.fMeasure]];
}

- (void)selectMeasure:(uint32_t)startMeas to:(uint32_t)endMeas
{
    fSelStart       = startMeas;
    fSelEnd         = endMeas;
    fCursorRegion   = kRegionMeasure;
    
    VLSoundOut::Instance()->ResetSelection();

	[self updateMenus];
	[self setNeedsDisplay:YES];	
}

- (NSRange)sectionsInSelection
{
	NSRange sections;
	int firstSection;
	int lastSection;
	VLSong * song = [self song];

	if (fSelEnd != kNoMeasure) {
		firstSection = song->fMeasures[fSelStart].fPropIdx;
		lastSection  = fSelEnd==fSelStart ? firstSection : song->fMeasures[fSelEnd-1].fPropIdx;
	} else {
		firstSection = 0;
		lastSection  = song->fMeasures.back().fPropIdx;
	}
	sections.location = firstSection;
	sections.length   = lastSection-firstSection+1;

	return sections;
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
	else if (action == @selector(insertBreak:))
		if (fSelStart == fSelEnd && fSelStart > 0) {
			VLSong * 	song  	= [self song];
			bool 		checked = fSelStart < song->fMeasures.size();
			if ([item tag] == 256)
				checked = checked && song->DoesBeginSection(fSelStart);
			else
				checked = checked && song->fMeasures[fSelStart].fBreak == [item tag];
			[item setState:checked];

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
    else if (action == @selector(insertMeasure:))
        return fSelStart == fSelEnd;
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
        [self setNumStanzas: std::max<int>([self song]->CountStanzas(), fNumStanzas)];
		[[self document] didChangeSong];
		[self setNeedsDisplay:YES];
	}
}

- (IBAction)delete:(id)sender
{
	[[self document] willChangeSong];
	[self song]->DeleteMeasures(fSelStart, fSelEnd, [sender tag]);
	[[self document] didChangeSong];
	[self setNeedsDisplay:YES];
}

- (IBAction)insertMeasure:(id)sender
{
	[[self document] willChangeSong];
	[self song]->InsertMeasure(fSelStart);
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

- (IBAction)insertBreak:(id)sender
{
	[[self document] willChangeSong];
	VLSong * 	song = [self song];
	if ([sender tag] == 256) {
		if (song->DoesBeginSection(fSelStart))
			song->DelSection(fSelStart);
		else
			song->AddSection(fSelStart);
	} else {
		VLMeasure & meas = song->fMeasures[fSelStart];
		if (meas.fBreak == [sender tag])
			meas.fBreak = 0;
		else
			meas.fBreak = [sender tag];
	}
	fNeedsRecalc = kRecalc;
	[self setNeedsDisplay:YES];
	[[self document] didChangeSong];
}

inline int KeyModeTag(const VLProperties & prop)
{
	return (prop.fKey << 8) | (prop.fMode & 0xFF);
}

- (void)updateKeyMenu
{
	NSMenu *menu		= [fKeyMenu menu];
	NSRange sections 	= [self sectionsInSelection];
	VLSong *song		= [self song];

	[[menu itemArray] makeObjectsPerformSelector:@selector(VLSetStateToOff)];
	int 	firstTag 	= KeyModeTag(song->fProperties[sections.location]);
	[fKeyMenu selectItemWithTag:firstTag];
	int		firstState  = NSOnState;
	while (--sections.length > 0) {
		int thisTag = KeyModeTag(song->fProperties[++sections.location]);
		if (thisTag != firstTag) {
			firstState = NSMixedState;	
			[[menu itemWithTag:thisTag] setState:NSMixedState];
		}
	}
	[[menu itemWithTag:firstTag] setState:firstState];
}

inline int TimeTag(const VLProperties & prop)
{
	return (prop.fTime.fNum << 8) | prop.fTime.fDenom;
}


- (void)updateTimeMenu
{
	NSMenu *menu		= [fTimeMenu menu];
	NSRange sections 	= [self sectionsInSelection];
	VLSong *song		= [self song];

	[[menu itemArray] makeObjectsPerformSelector:@selector(VLSetStateToOff)];
	int 	firstTag 	= TimeTag(song->fProperties[sections.location]);
	[fTimeMenu selectItemWithTag:firstTag];
	int		firstState  = NSOnState;
	while (--sections.length > 0) {
		int thisTag = TimeTag(song->fProperties[++sections.location]);
		if (thisTag != firstTag) {
			firstState = NSMixedState;	
			[[menu itemWithTag:thisTag] setState:NSMixedState];
		}
	}
	[[menu itemWithTag:firstTag] setState:firstState];
}

- (void)updateDivisionMenu
{
	NSMenu *menu		= [fDivisionMenu menu];
	NSRange sections 	= [self sectionsInSelection];
	VLSong *song		= [self song];

	[[menu itemArray] makeObjectsPerformSelector:@selector(VLSetStateToOff)];
	int 	firstTag 	= song->fProperties[sections.location].fDivisions;
	[fDivisionMenu selectItemWithTag:firstTag];
	int		firstState  = NSOnState;
	while (--sections.length > 0) {
		int thisTag = song->fProperties[++sections.location].fDivisions;
		if (thisTag != firstTag) {
			firstState = NSMixedState;	
			[[menu itemWithTag:thisTag] setState:NSMixedState];
		}
	}
	[[menu itemWithTag:firstTag] setState:firstState];
}

- (void)updateGrooveMenu
{
	NSRange 		sections 	= [self sectionsInSelection];
	VLSong *		song		= [self song];
	NSMutableArray* grooves     = [NSMutableArray array];

	while (sections.length-- > 0) {
		NSString * groove = 
			[NSString stringWithUTF8String:
			   song->fProperties[sections.location++].fGroove.c_str()];
		if (![grooves containsObject:groove])
			[grooves addObject:groove];
	}
	int	selected	= [grooves count];
	int history		= [fGrooveMenu numberOfItems]-2;
	while (history-- > 0) {
		NSString * groove = [fGrooveMenu itemTitleAtIndex:2];  	
		[fGrooveMenu removeItemAtIndex:2];
		if (![grooves containsObject:groove])
			[grooves addObject:groove];
	}
	[fGrooveMenu addItemsWithTitles:grooves];
	[fGrooveMenu selectItemAtIndex:2];
	if (selected > 1) 
		while (selected-- > 0)
			[[fGrooveMenu itemAtIndex:selected+2] setState:NSMixedState];
	[[NSUserDefaults standardUserDefaults] setObject:grooves forKey:@"VLGrooves"];	
}

- (void)updateMenus
{
	[self updateKeyMenu];
	[self updateTimeMenu];
	[self updateDivisionMenu];
	[self updateGrooveMenu];
}

- (void (^)()) willPlaySequence:(MusicSequence)music
{
    uint32_t    selStart    = fSelStart;
    uint32_t    selEnd      = fSelEnd;
    
	VLEditable * e = 
		[[VLPlaybackEditable alloc] initWithView:self];
	[self setEditTarget:e];
	MusicSequenceSetUserCallback(music, VLSequenceCallback, e);
    
    return [Block_copy(^{
        if (selEnd != kNoMeasure) {
            VLMIDIUtilities locator(music);
            VLLocation start = {selStart, VLFraction(0)};
            VLLocation end   = {selEnd, VLFraction(0)};
            VLSoundOut::Instance()->SetStart(locator.Find(start));
            if (selEnd > selStart) {
                VLSoundOut::Instance()->SetEnd(locator.Find(end));
                [self selectMeasure:selStart to:selEnd];
            }
        }
    }) autorelease];
}

@end
