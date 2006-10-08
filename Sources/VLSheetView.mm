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
	@"notecursor"
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
		fIsRest				= NO;
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

- (float) noteYWithPitch:(int)pitch
{
	int 	semi 		= pitch % 12;
	int		octave  	= (pitch / 12) - 5;
	bool 	useSharps	= [self song]->fProperties.front().fKey >= 0;

	float y 	= octave*3.5f*kLineH;
	float sharp = useSharps ? 0.0f : 0.5f*kLineH;

	switch (semi) {
	case 0: // C
		return y-1.0f*kLineH;
	case 1: // C# / Db
		return y-1.0f*kLineH+sharp;
	case 2: // D
		return y-0.5f*kLineH;
	case 3: // D# / Eb
		return y-0.5f*kLineH+sharp;
	case 4: // E
		return y;
	case 5: // F
		return y+0.5f*kLineH;
	case 6: // F# / Gb
		return y+0.5f*kLineH+sharp;
	case 7: // G
		return y+1.0f*kLineH;
	case 8: // G# / Ab
		return y+1.0f*kLineH+sharp;
	case 9: // A
		return y+1.5f*kLineH;
	case 10: // A# / Bb
		return y+1.5f*kLineH+sharp;
	case 11: // B
	default:
		return y+2.0f*kLineH;
	}
}

- (float) noteYInMeasure:(int)measure withPitch:(int)pitch
{
	return [self systemY:measure/fMeasPerSystem]+[self noteYWithPitch:pitch];
}

- (float) noteXInMeasure:(int)measure at:(VLFraction)at
{
	const VLProperties & prop	= [self song]->fProperties.front();
	const float mx				= fClefKeyW+(measure%fMeasPerSystem)*fMeasureW;

	at 		/= prop.fTime / (4 * prop.fDivisions);
	int div	=  at.fNum / at.fDenom;

	return mx + (div + (div / fDivPerGroup) + 1)*kNoteW;
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

	NSRect	r		= [scroll bounds];
	NSPoint	mouse	= 
		[scroll convertPoint:[[self window] mouseLocationOutsideOfEventStream]
			  fromView: nil];
	BOOL within		= [scroll mouse:mouse inRect:r];
	
	[self removeTrackingRect:fCursorTracking];
	fCursorTracking = [self addTrackingRect:r owner:self
							userData:nil assumeInside:within];
	[[self window] setAcceptsMouseMovedEvents:within];
	[[self window] makeFirstResponder:self];

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
	int key = [[sender selectedItem] tag];
	[[self document] setKey: key transpose: YES];
	fNeedsRecalc = kRecalc;
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

const float kSemiFloor = -2.5f*kLineH;
static int sSemiToPitch[] = {
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

	loc.y		   -= kSystemY+kSemiFloor;
	int semi		= static_cast<int>(roundf(loc.y / (0.5f*kLineH)));
	fCursorPitch	= sSemiToPitch[semi];

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
		fIsRest = !fIsRest;
		break;
	}
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	VLDocument * doc      = [self document];
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
}

@end
