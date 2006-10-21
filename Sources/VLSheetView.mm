//
//  VLSheetView.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 12/17/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "VLSheetView.h"
#import "VLSheetViewInternal.h"
#import "VLSheetViewChords.h"
#import "VLSheetViewNotes.h"
#import "VLSoundOut.h"

#import "VLDocument.h"

#include <cmath>

@implementation VLSheetView

static NSImage **	sMusic;

static NSString * sElementNames[kMusicElements] = {
	@"g-clef",
	@"flat",
	@"sharp",
	@"natural",
	@"whole-notehead",
	@"half-notehead",
	@"notehead",
	@"whole-rest",
	@"half-rest",
	@"quarter-rest",
	@"eighth-rest",
	@"sixteenth-rest",
	@"thirtysecondth-rest",
	@"eighth-flag",
	@"sixteenth-flag",
	@"thirtysecondth-flag",
	@"notecursor",
	@"flatcursor",
	@"sharpcursor",
	@"naturalcursor",
	@"restcursor",
	@"killcursor"
};

static float sSharpPos[] = {
	4.0f*kLineH, // F#
	2.5f*kLineH, // C#
	4.5f*kLineH, // G#
	3.0f*kLineH, // D#
	1.5f*kLineH, // A#
	3.5f*kLineH, // E#
	2.0f*kLineH, // B#
};

static float sFlatPos[] = {
	2.0f*kLineH, // Bb
	3.5f*kLineH, // Eb
	1.5f*kLineH, // Ab
	3.0f*kLineH, // Db
	1.0f*kLineH, // Gb
	2.5f*kLineH, // Cb
	0.5f*kLineH, // Fb
};

- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) {
		if (!sMusic) {
			NSBundle * b = [NSBundle mainBundle];
			sMusic	= new NSImage * [kMusicElements];
			for (int i=0; i<kMusicElements; ++i) {
				NSString * name =
					[b pathForResource:sElementNames[i] ofType:@"eps"
					   inDirectory:@"Music"];
				sMusic[i] = [[NSImage alloc] initWithContentsOfFile: name];
				NSSize sz = [sMusic[i] size];
				sz.width *= kImgScale;
				sz.height*= kImgScale;
				[sMusic[i] setScalesWhenResized:YES];
				[sMusic[i] setSize:sz];
			}
		}
		fNeedsRecalc		= kFirstRecalc;
		fClickMode			= ' ';
		fDisplayScale		= 1.0f;
		fCursorPitch		= VLNote::kNoPitch;
	}
    return self;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (VLDocument *) document
{
	return [[[self window] windowController] document];
}

- (VLSong *) song
{
	return [[self document] song];
}

- (NSImage *) musicElement:(VLMusicElement)elt
{
	return sMusic[elt];
}

- (float) systemY:(int)system
{
	NSRect b = [self bounds];

	return kSystemY+b.origin.y+b.size.height-(system+1)*kSystemH;
}

int8_t sSemi2Pitch[2][12] = {{
 // C  Db D  Eb E  F  Gb G  Ab A  Bb B 
	0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6,
},{
 // C  C# D  D# E  F  F# G  G# A  A# B 
	0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6,
}};

#define S	kMusicSharp,
#define F	kMusicFlat,
#define N	kMusicNatural,
#define _	kMusicNothing,

VLMusicElement sSemi2Accidental[12][12] = {
 //  C DbD EbE F GbG AbA BbB 
	{N _ N _ N _ _ N _ N _ N}, // Gb major - 6 flats
	{_ _ N _ N _ _ N _ N _ N}, // Db major - 5 flats
	{_ _ N _ N _ F _ _ N _ N}, // Ab major - 4 flats
	{_ F _ _ N _ F _ _ N _ N}, // Eb major - 3 flats
	{_ F _ _ N _ F _ F _ _ N}, // Bb major - 2 flats
	{_ F _ F _ _ F _ F _ _ N}, // F major  - 1 flat
 //  C C#D D#E F F#G G#A A#B 	
	{_ S _ S _ _ S _ S _ S _}, // C major
	{_ S _ S _ N _ _ S _ S _}, // G major - 1 sharp
	{N _ _ S _ N _ _ S _ S _}, // D major - 2 sharps
	{N _ _ S _ N _ N _ _ S _}, // A major - 3 sharps
	{N _ N _ _ N _ N _ _ S _}, // E major - 4 sharps
	{N _ N _ _ N _ N _ N _ _}, // B major - 5 sharps
};

#undef S
#undef F
#undef N
#undef _

- (int) stepWithPitch:(int)pitch
{
	int 	semi 		= pitch % 12;
	int		key			= [self song]->fProperties.front().fKey;
	bool 	useSharps	= key >= 0;
	
	return	sSemi2Pitch[useSharps][semi];
}

- (float) noteYWithPitch:(int)pitch accidental:(VLMusicElement*)accidental
{
	int 	semi 		= pitch % 12;
	int		octave  	= (pitch / 12) - 5;
	int		key			= [self song]->fProperties.front().fKey;

	*accidental = sSemi2Accidental[key+6][semi];

	return (octave*3.5f+[self stepWithPitch:pitch]*0.5f-1.0f)*kLineH;
}

- (float) noteYInMeasure:(int)measure withPitch:(int)pitch accidental:(VLMusicElement*)accidental
{
	return [self systemY:measure/fMeasPerSystem]
		+ [self noteYWithPitch:pitch accidental:accidental];
}

- (float) noteXInMeasure:(int)measure at:(VLFraction)at
{
	const VLProperties & prop	= [self song]->fProperties.front();
	const float mx				= fClefKeyW+(measure%fMeasPerSystem)*fMeasureW;

	at 		*= 4 * prop.fDivisions;
	int div	=  at.fNum / at.fDenom;

	return mx + (div + (div / fDivPerGroup) + 1)*kNoteW;
}

- (void) scrollMeasureToVisible:(int)measure
{
	NSRect r = NSMakeRect(fClefKeyW+(measure%fMeasPerSystem)*fMeasureW,
						  [self systemY:measure/fMeasPerSystem]-kSystemY,
						  fMeasureW, kSystemH);
	[self scrollRectToVisible:r];
}

- (void) setTrackingRect
{
	NSRect	r		= [self bounds];
	NSPoint	mouse	= 
		[self convertPoint:[[self window] mouseLocationOutsideOfEventStream]
			  fromView: nil];
	BOOL within		= [self mouse:mouse inRect:r];
	
	fCursorTracking = [self addTrackingRect:r owner:self
							userData:nil assumeInside:within];
	[[self window] setAcceptsMouseMovedEvents:within];
	if (within && ![[self document] valueForKey: @"editTarget"])
		[[self window] makeFirstResponder:self];
}

- (void) clearTrackingRect
{
	[self removeTrackingRect:fCursorTracking];
}

-(void)resetCursorRects
{
	[super resetCursorRects];
	[self clearTrackingRect];
	[self setTrackingRect];
}

-(void)viewWillMoveToWindow:(NSWindow *)win
{
	if (!win && [self window]) [self clearTrackingRect];
}

-(void)viewDidMoveToWindow
{
	if ([self window]) {
		[self setTrackingRect];
		[[self window] makeFirstResponder:self];
	}
}

- (void) recalculateDimensions 
{
	NSScrollView * scroll = [self enclosingScrollView];

	NSSize sz 	=  [scroll contentSize];
	sz.width   /=	fDisplayScale;
	sz.height  /= 	fDisplayScale;

	const VLSong * 			song = [self song];
	const VLProperties & 	prop = song->fProperties.front();

	fGroups 		= prop.fTime.fNum / std::max(prop.fTime.fDenom / 4, 1); 
	fQuarterBeats 	= (prop.fTime.fNum*4) / prop.fTime.fDenom;
	fDivPerGroup	= prop.fDivisions * (fQuarterBeats / fGroups);
	fClefKeyW		= kClefX+kClefW+(std::labs(prop.fKey)+1)*kKeyW;
	fMeasureW		= fGroups*(fDivPerGroup+1)*kNoteW;
	fMeasPerSystem	= (int)std::floor((sz.width-fClefKeyW) / fMeasureW);
	fNumSystems 	= (song->CountMeasures()+fMeasPerSystem-1)/fMeasPerSystem;
	sz.height		= fNumSystems*kSystemH;

	NSSize frameSz	= {sz.width * fDisplayScale, sz.height * fDisplayScale};

	[self setFrameSize:frameSz];
	[self setBoundsSize:sz];
	[self setNeedsDisplay:YES];

	if (fNeedsRecalc == kFirstRecalc) {
		NSView *dv = [scroll documentView];
		NSView *cv = [scroll contentView];
 
		[dv scrollPoint:
			NSMakePoint(0.0, NSMaxY([dv frame])-NSHeight([cv bounds]))];
	}

	fNeedsRecalc	= kNoRecalc;	
}

- (void)drawGridForSystem:(int)system
{
	static NSDictionary * sMeasNoFont 	 = nil;
	if (!sMeasNoFont)
		sMeasNoFont =
			[[NSDictionary alloc] initWithObjectsAndKeys:
				[NSFont fontWithName: @"Helvetica" size: 10],
                NSFontAttributeName,
				nil];

	const float kSystemY 	= [self systemY:system];
	const float kLineW 		= fClefKeyW + fMeasPerSystem*fMeasureW;

	const VLSong * 			song = [self song];
	const VLProperties & 	prop = song->fProperties.front();

	NSBezierPath * bz = [NSBezierPath bezierPath];
	
	//
	// Draw lines
	//
	[bz setLineWidth:0.0];
	for (int line = 0; line<5; ++line) {
		const float y	= kSystemY+line*kLineH;
		[bz moveToPoint: NSMakePoint(kLineX, y)];
		[bz lineToPoint: NSMakePoint(kLineX+kLineW, y)];
	}
	[bz stroke];
	[bz removeAllPoints];
	//
	// Draw measure lines
	//
	[bz setLineWidth:2.0];
	for (int measure = 0; measure<=fMeasPerSystem; ++measure) {
		const float x	= fClefKeyW+measure*fMeasureW;
		const float yy	= kSystemY+4.0f*kLineH;
		[bz moveToPoint: NSMakePoint(x, kSystemY)];
		[bz lineToPoint: NSMakePoint(x, yy)];
	}
	[bz stroke];
	[bz removeAllPoints];

	//
	// Draw division lines
	//
	[bz setLineWidth:0.0];
	[[NSColor colorWithDeviceWhite:0.8f alpha:1.0f] set];
	for (int measure = 0; measure<fMeasPerSystem; ++measure) {
		const float mx	= fClefKeyW+measure*fMeasureW;
		const float y0	= kSystemY-2.0f*kLineH;
		const float yy	= kSystemY+6.0f*kLineH;
		for (int group = 0; group < fGroups; ++group) {
			for (int div = 0; div < fDivPerGroup; ++div) {
				const float x = mx+(group*(fDivPerGroup+1)+div+1)*kNoteW;
				[bz moveToPoint: NSMakePoint(x, y0)];
				[bz lineToPoint: NSMakePoint(x, yy)];
			}
		}
	}
	[bz stroke];

	//
	// Draw clef
	//
	[[self musicElement:kMusicGClef] 
		compositeToPoint: NSMakePoint(kClefX, kSystemY+kClefY)
		operation: NSCompositeSourceOver];
	//
	// Draw measure #
	//
	[[NSString stringWithFormat:@"%d", system*fMeasPerSystem+1]
		drawAtPoint: NSMakePoint(kMeasNoX, kSystemY+kMeasNoY)
		withAttributes: sMeasNoFont];
	//
	// Draw key (sharps & flats)
	//
	if (prop.fKey > 0) {
		float x = kClefX+kClefW;
		for (int i=0; i<prop.fKey; ++i) {
			[[self musicElement:kMusicSharp] 
				compositeToPoint: 
					NSMakePoint(x, kSystemY+sSharpPos[i]+kSharpY)
				operation: NSCompositeSourceOver];
			x += kAccW;
		}
	} else if (prop.fKey < 0) {
		float x = kClefX+kClefW;
		for (int i=0; -i>prop.fKey; ++i) {
			[[self musicElement: kMusicFlat] 
				compositeToPoint: 
					NSMakePoint(x, kSystemY+sFlatPos[i]+kFlatY)
				operation: NSCompositeSourceOver];
			x += kAccW;
		}
	}
}

- (void)drawRect:(NSRect)rect
{
	if (fNeedsRecalc)
		[self recalculateDimensions];

	const float kLineW = fClefKeyW + fMeasPerSystem*fMeasureW;
	for (int system = 0; system<fNumSystems; ++system) {
		const float kSystemY = [self systemY:system];
		if (!NSIntersectsRect(rect, 
							  NSMakeRect(kLineX, kSystemY+kClefY, 
										 kLineW, kSystemH-kClefY)
		))
			continue; // This system does not need to be drawn
		[self drawGridForSystem:system];
		[self drawNotesForSystem:system];
		[self drawChordsForSystem:system];
	}	
	VLEditable * editable = [[self document] valueForKey: @"editTarget"];
	[editable highlightCursor];
}

- (IBAction) setKey:(id)sender
{
	[[NSAlert alertWithMessageText:@"Transpose Song?"
			 defaultButton:@"Transpose"
			 alternateButton:@"Cancel"
			 otherButton:@"Change Key"
			 informativeTextWithFormat:
				 @"Do you want to transpose the song into the new key?"]
		beginSheetModalForWindow:[self window]
		modalDelegate:self didEndSelector:@selector(setKey:returnCode:contextInfo:)
		contextInfo:sender];
}

- (void)setKey:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(id)sender
{
	if (returnCode == NSAlertAlternateReturn)
		return;

	int key = [[sender selectedItem] tag];
	[[self document] setKey:key transpose:returnCode==NSAlertDefaultReturn];
	fNeedsRecalc = kRecalc;
	[self setNeedsDisplay: YES];	
}

- (IBAction) setTime:(id)sender
{
	int time = [[sender selectedItem] tag];

	[[self document] setTimeNum: time >> 8 denom: time & 0xFF];
	fNeedsRecalc = kRecalc;
	[self setNeedsDisplay: YES];	
}

- (IBAction) setDivisions:(id)sender
{
	int div = [[sender selectedItem] tag];

	[[self document] setDivisions: div];
	fNeedsRecalc = kRecalc;
	[self setNeedsDisplay: YES];	
}

- (IBAction)hideFieldEditor:(id)sender
{
	[fFieldEditor setAction:nil];
}

const float kSemiFloor = -3.0f*kLineH;
static int8_t sSemiToPitch[] = {
	53, // F
	55,	57, // A
	59, 60, // Middle C
	62, 64, // E
	65, 67, // G
	69, 71, // B
	72, 74, // D
	76, 77, // F
	79, 81, // A
	83, 84, // C
	86, 88  // E
};

static int8_t sFlatAcc[] = {
	6,	// Cb
   11,	
	4,	// Db
	9,
	2,	// Eb
	7,	// Fb
   12,
	5, 	// Gb
   10,
	3,	// Ab
	8,	
	1,	// Bb
};

static int8_t sSharpAcc[] = {
	2,	// C# is the 2nd sharp
	9,
	4,	// D#
   11,
	6,	// E#
	1,	// F#
	8,
	3,	// G#
   10,
	5,	// A#
   12,
	7,	// B#
};

- (void) accidentalFromEvent:(NSEvent *)event
{
	const VLProperties & 	prop = [self song]->fProperties.front();

	fCursorAccidental	= (VLMusicElement)0;
	if (prop.fKey >= 0) {
		if (prop.fKey >= sSharpAcc[fCursorPitch % 12]) { // Sharp in Key
			switch ([event modifierFlags] & (NSAlternateKeyMask|NSCommandKeyMask)) {
			case NSAlternateKeyMask:
				fCursorAccidental	= kMusicFlatCursor; // G# -> Gb
				fCursorActualPitch  = fCursorPitch-1;
				break;
			default:
			case NSCommandKeyMask:
				fCursorActualPitch  = fCursorPitch+1;
				break;				  // G# -> G#
			case NSAlternateKeyMask|NSCommandKeyMask:
				fCursorAccidental	= kMusicNaturalCursor; // G# -> G
				fCursorActualPitch	= fCursorPitch;
				break;
			}
			return;
		}
	} else {
		if (prop.fKey <= -sFlatAcc[fCursorPitch % 12]) { // Flat in Key
			switch ([event modifierFlags] & (NSAlternateKeyMask|NSCommandKeyMask)) {
			default:
			case NSAlternateKeyMask:
				fCursorActualPitch  = fCursorPitch-1;
				break;				  // Gb -> Gb
			case NSCommandKeyMask:
				fCursorAccidental	= kMusicSharpCursor; // Gb -> G#
				fCursorActualPitch  = fCursorPitch+1;
				break;				  
			case NSAlternateKeyMask|NSCommandKeyMask:
				fCursorAccidental	= kMusicNaturalCursor; // Gb -> G
				fCursorActualPitch	= fCursorPitch;
				break;
			}
			return;
		}
	}
	//
	// Natural
	//
	switch ([event modifierFlags] & (NSAlternateKeyMask|NSCommandKeyMask)) {
	case NSAlternateKeyMask:
		fCursorAccidental	= kMusicFlatCursor; // G -> Gb
		fCursorActualPitch	= fCursorPitch-1;
		break;
	case NSCommandKeyMask:
		fCursorAccidental	= kMusicSharpCursor; // G -> G#
		fCursorActualPitch	= fCursorPitch+1;
		break;
	default:
	case NSAlternateKeyMask|NSCommandKeyMask:
		fCursorActualPitch	= fCursorPitch;
		break;				  					 // G -> G
	}
}

- (VLRegion) findRegionForEvent:(NSEvent *) event
{
	fCursorPitch = VLNote::kNoPitch;

	const VLProperties & 	prop = [self song]->fProperties.front();
	NSPoint loc 	= [event locationInWindow];
	loc 			= [self convertPoint:loc fromView:nil];

	if (loc.y < 0.0f || loc.y >= fNumSystems*kSystemH)
		return fCursorRegion = kRegionNowhere;

	int system = fNumSystems - static_cast<int>(loc.y / kSystemH) - 1;
	loc.y      = fmodf(loc.y, kSystemH);

	loc.x -= fClefKeyW;
	if (loc.x < 0.0f || loc.x >= fMeasPerSystem*fMeasureW)
		return fCursorRegion = kRegionNowhere;
	
	int measure 	= static_cast<int>(loc.x / fMeasureW);
	loc.x	   	   -= measure*fMeasureW;
	int group	  	= static_cast<int>(loc.x / ((fDivPerGroup+1)*kNoteW));
	loc.x		   -= group*(fDivPerGroup+1)*kNoteW;
	int div			= static_cast<int>(roundf(loc.x / kNoteW))-1;
	div				= std::min(std::max(div, 0), fDivPerGroup-1);
	fCursorAt 		= VLFraction(div+group*fDivPerGroup, 4*prop.fDivisions);
	fCursorMeasure	= measure+system*fMeasPerSystem;

	if (fCursorMeasure > [self song]->fMeasures.size())
		return fCursorRegion = kRegionNowhere;
		
	if (loc.y >= kSystemY+kChordY) {
		//
		// Chord, round to quarters
		//
		int scale = fCursorAt.fDenom / 4;
		fCursorAt = VLFraction(fCursorAt.fNum / scale, 4);
		return fCursorRegion = kRegionChord;
	} else if (loc.y < kSystemY+kLyricsY) {
		return fCursorRegion = kRegionLyrics;
	}

	loc.y		   	   -= kSystemY+kSemiFloor;
	int semi			= static_cast<int>(roundf(loc.y / (0.5f*kLineH)));
	fCursorPitch		= sSemiToPitch[semi];

	[self accidentalFromEvent:event];

	return fCursorRegion = kRegionNote;
}

- (void) mouseMoved:(NSEvent *)event
{
   	if ([event modifierFlags] & NSAlphaShiftKeyMask)
		return; // Keyboard mode, ignore mouse

	bool hadCursor = fCursorPitch != VLNote::kNoPitch;
	[self findRegionForEvent:event];
	bool hasCursor = fCursorPitch != VLNote::kNoPitch;

	[self setNeedsDisplay:(hadCursor || hasCursor)];
}

- (void)flagsChanged:(NSEvent *)event
{
	if (fCursorPitch != VLNote::kNoPitch) {
		[self accidentalFromEvent:event];
		[self setNeedsDisplay:YES];
	}
}

- (void) mouseEntered:(NSEvent *)event
{
	[[self window] setAcceptsMouseMovedEvents:YES];
	[self mouseMoved:event];
}

- (void) mouseExited:(NSEvent *)event
{
	[[self window] setAcceptsMouseMovedEvents:NO];
	[self mouseMoved:event];
}

- (void) mouseDown:(NSEvent *)event
{
	switch ([self findRegionForEvent:event]) {
	case kRegionNote:
		[self addNoteAtCursor];
		break;
	case kRegionChord:
		[self editChord];
		break;
	default:
		break;
	}
}

- (void) keyDown:(NSEvent *)event
{
	NSString * k = [event charactersIgnoringModifiers];
	
	switch ([k characterAtIndex:0]) {
	case '\r':
		[self startKeyboardCursor];
		[self addNoteAtCursor];
		break;
	case ' ':
		[self startKeyboardCursor];
		VLSoundOut::Instance()->PlayNote(VLNote(1, fCursorPitch));
		break;
	case 'r':
		if (fClickMode == 'r')
			fClickMode = ' ';
		else
			fClickMode = 'r';
		[self setNeedsDisplay:YES];
		break;
	case 'k':
		if (fClickMode == 'k')
			fClickMode = ' ';
		else
			fClickMode = 'k';
		break;
		[self setNeedsDisplay:YES];
	}
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	VLEditable * editable = [[self document] valueForKey: @"editTarget"];
	return [editable validValue:[fFieldEditor stringValue]];
}

- (void)controlTextDidEndEditing:(NSNotification *)note
{
	VLEditable * editable = [[self document] valueForKey: @"editTarget"];
	switch ([[[note userInfo] objectForKey:@"NSTextMovement"] intValue]) {
	case NSTabTextMovement:
		[editable moveToNext];
		break;
	case NSBacktabTextMovement:
		[editable moveToPrev];
		break;
	default:
		[editable autorelease];
		editable = nil;
	}
	[[self document] setValue:editable forKey: @"editTarget"];
	if (editable) 
		[fFieldEditor selectText:self];
    [[self window] performSelectorOnMainThread:@selector(makeFirstResponder:)
				   withObject:(editable ? fFieldEditor : self)
				   waitUntilDone:NO];
	[self setNeedsDisplay: YES];
}

@end
