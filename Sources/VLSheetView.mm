//
// File: VLSheetView.mm - Lead sheet editing view
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2008 Matthias Neeracher
//

#import "VLSheetView.h"
#import "VLSheetViewInternal.h"
#import "VLSheetViewChords.h"
#import "VLSheetViewNotes.h"
#import "VLSheetViewLyrics.h"
#import "VLSheetViewSelection.h"
#import "VLSoundOut.h"
#import "VLGrooveController.h"

#import "VLPitchGrid.h"

#import "VLDocument.h"

#include <cmath>

@implementation VLSheetView

@synthesize 
    numTopLedgers   = fNumTopLedgers,
    numBotLedgers   = fNumBotLedgers,
    numStanzas      = fNumStanzas;

static NSString * sElementNames[kMusicElements] = {
	@"g-clef",
	@"flat",
	@"sharp",
	@"natural",
    @"doubleflat",
    @"doublesharp",
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
	@"doubleflatcursor",
	@"doublesharpcursor",
	@"restcursor",
	@"killcursor",
	@"extendcursor",
	@"coda"
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
		NSBundle * b = [NSBundle mainBundle];
		fMusic	= new NSImage * [kMusicElements];
		for (int i=0; i<kMusicElements; ++i) {
			NSString * name =
				[b pathForResource:sElementNames[i] ofType:@"eps"
				   inDirectory:@"Music"];
			fMusic[i] = [[NSImage alloc] initByReferencingFile: name];
			NSSize sz = [fMusic[i] size];
			sz.width *= kImgScale;
			sz.height*= kImgScale;
			[fMusic[i] setScalesWhenResized:YES];
			[fMusic[i] setSize:sz];
		}
		fNeedsRecalc		= kFirstRecalc;
		fClickMode			= ' ';
		fDisplayScale		= 1.0f;
        fCursorVertPos      = 0;
        fCursorVisual       = 0;
		fSelStart			= 0;
		fSelEnd				= -1;
		fNumTopLedgers 		= 0;
		fNumBotLedgers 		= 2;
		fNumStanzas    		= 2;
		fLastMeasures		= 0;
        fUndo               = [[VLKeyValueUndo alloc] 
            initWithOwner:self 
            keysAndNames:[NSDictionary dictionaryWithObjectsAndKeys:
                @"", @"numTopLedgers",
                @"", @"numBotLedgers",
                @"", @"numStanzas",
                nil]];
	}
    return self;
}

- (void)dealloc
{
    [self removeObservers:[self document]];
    delete [] fMusic;
    [fUndo release];
    [super dealloc];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (VLDocument *) document
{
	return [[[self window] windowController] document];
}

- (VLEditable *) editTarget
{
	return [[[self window] windowController] editTarget];
}

- (void) setEditTarget:(VLEditable *)editable
{
	[[[self window] windowController] setEditTarget:editable];
}

- (void) updateEditTarget
{
    [fFieldEditor takeStringValueFrom:[self editTarget]];
}

- (VLSong *) song
{
	return [[self document] song];
}

- (NSImage *) musicElement:(VLMusicElement)elt
{
	return fMusic[elt];
}

- (float) systemY:(int)system
{
	NSRect b = [self bounds];

	return kSystemBaseline+b.origin.y+b.size.height-(system+1)*kSystemH;
}

- (int) systemForPoint:(NSPoint *)loc
{
	NSRect  b       = [self bounds];
    CGFloat top     = b.origin.y+b.size.height;
    int     system  = (top-loc->y) / kSystemH;
    loc->y         -= top-(system+1)*kSystemH;
    
    return system;
}

- (int) gridInSection:(int)section withPitch:(int)pitch visual:(uint16_t)visual
{
	int key     = [self song]->fProperties[section].fKey;
    
    return VLPitchToGrid(pitch, visual, key);
}

- (float) noteYInGrid:(int)vertPos
{
    return (vertPos*0.5f - 1.0) * kLineH;
}

- (float) noteYInSection:(int)section withPitch:(int)pitch visual:(uint16_t *)visual
{
	int key     = [self song]->fProperties[section].fKey;
    int grid    = VLPitchToGrid(pitch, *visual, key);

	return [self noteYInGrid:grid];
}

- (float) noteYInSection:(int)section withPitch:(int)pitch
{
	int         key     = [self song]->fProperties[section].fKey;
    uint16_t    visual  = 0;
    int         grid    = VLPitchToGrid(pitch, visual, key);
    
	return [self noteYInGrid:grid];
}

- (VLMusicElement)accidentalForVisual:(uint16_t)visual
{
    switch (visual & VLNote::kAccidentalsMask) {
    case VLNote::kWantSharp:
        return kMusicSharp;
    case VLNote::kWantFlat:
        return kMusicFlat;
    case VLNote::kWant2Sharp: 
        return kMusic2Sharp;
    case VLNote::kWant2Flat: 
        return kMusic2Flat;
    case VLNote::kWantNatural:
        return kMusicNatural;
    default:
        return kMusicNothing;
    }
}

- (float) noteYInMeasure:(int)measure withGrid:(int)vertPos
{
	return [self systemY:fLayout->SystemForMeasure(measure)]
		+ [self noteYInGrid:vertPos];
}

- (float) noteXAt:(VLLocation)at
{
	return fLayout->NotePosition(at);
}

- (void) scrollMeasureToVisible:(int)measure
{
	const int				system	= fLayout->SystemForMeasure(measure);
	const VLSystemLayout &	kLayout	= (*fLayout)[system];
	NSRect r = NSMakeRect(
      fLayout->MeasurePosition(measure),
	  [self systemY:system]-kSystemBaseline,
	  kLayout.MeasureWidth(), kSystemH);
	[self scrollRectToVisible:r];
}

- (void) setTrackingRect
{
	NSRect	r		= [self visibleRect];
	NSPoint	mouse	= 
		[self convertPoint:[[self window] mouseLocationOutsideOfEventStream]
			  fromView: nil];
	BOOL within		= [self mouse:mouse inRect:r];
	
	fCursorTracking = [self addTrackingRect:r owner:self
							userData:nil assumeInside:within];
	[[self window] setAcceptsMouseMovedEvents:within];
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
	if (!win && [self window])
		[self clearTrackingRect];
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

	delete fLayout;
	fLayout 	= new VLLayout(*[self song], sz.width / fDisplayScale);
	sz.height	= std::max(2.0f, fLayout->NumSystems()+0.25f)*kSystemH*fDisplayScale;

	NSSize boundsSz	= {sz.width / fDisplayScale, sz.height / fDisplayScale};

	[self setFrameSize:sz];
	[self setBoundsSize:boundsSz];
	[self setNeedsDisplay:YES];

	if (fNeedsRecalc == kFirstRecalc) {
		NSView *dv = [scroll documentView];
		NSView *cv = [scroll contentView];
 
		[dv scrollPoint:
			NSMakePoint(0.0, NSMaxY([dv frame])-NSHeight([cv bounds]))];
	}

	fLastMeasures	= [self song]->CountMeasures();
	fNeedsRecalc	= kNoRecalc;	
}

- (void)needsRecalculation
{
    fNeedsRecalc    = kRecalc;
    [self setNeedsDisplay:YES];
}

const char * sBreak[3] = {"", "\xE2\xA4\xBE", "\xE2\x8E\x98"};

- (void)drawGridForSystem:(int)system
{
	static NSDictionary * sMeasNoFont 	 = nil;
	static NSDictionary * sBreakFont	 = nil;
	if (!sMeasNoFont)
		sMeasNoFont =
			[[NSDictionary alloc] initWithObjectsAndKeys:
				[NSFont fontWithName: @"Helvetica" size: 10],
                NSFontAttributeName,
				nil];
	if (!sBreakFont)
		sBreakFont =
			[[NSDictionary alloc] initWithObjectsAndKeys:
				[NSFont fontWithName: @"Symbol" size: 30],
                NSFontAttributeName,
				nil];		

	const VLSystemLayout &  kLayout = (*fLayout)[system];
	const VLSong * 			song  	= [self song];
	const VLProperties & 	kProp 	= song->Properties(fLayout->FirstMeasure(system));

	const float kSystemY 	= [self systemY:system];
	const float kLineW 		= (*fLayout)[system].SystemWidth();
	const float kMeasureW	= kLayout.MeasureWidth();

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
	int m = fLayout->FirstMeasure(system);
	for (int measure = 0; measure<=kLayout.NumMeasures(); ++measure, ++m) {
		const float kDblLineOff = 1.5f;
		const float kThick		= 2.5f;
		const float kThin		= 1.0f;
		const float kDotOff		= 4.5f;
		const float kDotRadius	= 2.0f;
		const float kVoltaTextOff = 7.0f;
		const float x	= kLayout.MeasurePosition(measure);
		const float yy	= kSystemY+4.0f*kLineH;
		bool repeat;
		size_t volta;
		bool dotsPrecede= measure != 0 && 
			(song->DoesEndRepeat(m) 
			 || (song->DoesEndEnding(m, &repeat) && repeat));
		bool dotsFollow = measure<kLayout.NumMeasures() && song->DoesBeginRepeat(m);
		if (!dotsPrecede && !dotsFollow) {
			//
			// Regular
			//
			[bz moveToPoint: NSMakePoint(x, kSystemY)];
			[bz lineToPoint: NSMakePoint(x, yy)];
			[bz stroke];
			[bz removeAllPoints];
		} else {
			[bz stroke];
			[bz removeAllPoints];
			[bz setLineWidth: dotsFollow ? kThick : kThin];
			[bz moveToPoint: NSMakePoint(x-kDblLineOff, kSystemY)];
			[bz lineToPoint: NSMakePoint(x-kDblLineOff, yy)];
			[bz stroke];
			[bz removeAllPoints];
			[bz setLineWidth: dotsPrecede ? kThick : kThin];
			[bz moveToPoint: NSMakePoint(x+kDblLineOff, kSystemY)];
			[bz lineToPoint: NSMakePoint(x+kDblLineOff, yy)];
			[bz stroke];
			[bz removeAllPoints];
			[bz setLineWidth:2.0];
			if (dotsPrecede) {
				[bz appendBezierPathWithOvalInRect:
						NSMakeRect(x-kDotOff-kDotRadius, 
								   kSystemY+1.5*kLineH-kDotRadius,
								   2.0f*kDotRadius, 2.0f*kDotRadius)];
				[bz appendBezierPathWithOvalInRect:
						NSMakeRect(x-kDotOff-kDotRadius, 
								   kSystemY+2.5*kLineH-kDotRadius,
								   2.0f*kDotRadius, 2.0f*kDotRadius)];
			}
			if (dotsFollow) {
				[bz appendBezierPathWithOvalInRect:
						NSMakeRect(x+kDotOff-kDotRadius, 
								   kSystemY+1.5*kLineH-kDotRadius,
								   2.0f*kDotRadius, 2.0f*kDotRadius)];
				[bz appendBezierPathWithOvalInRect:
						NSMakeRect(x+kDotOff-kDotRadius, 
								   kSystemY+2.5*kLineH-kDotRadius,
								   2.0f*kDotRadius, 2.0f*kDotRadius)];
			}
			[bz fill];
			[bz removeAllPoints];
		}
		if (measure<kLayout.NumMeasures()) {
			if (song->DoesBeginEnding(m, 0, &volta)) {
				[bz setLineWidth:kThin];
				[bz moveToPoint: NSMakePoint(x+kDblLineOff, yy+0.5f*kLineH)];
				[bz lineToPoint: NSMakePoint(x+kDblLineOff, yy+2.0f*kLineH)];
				[bz lineToPoint: NSMakePoint(x+0.5f*kMeasureW, yy+2.0f*kLineH)];
				[bz stroke];
				[bz removeAllPoints];			
				[bz setLineWidth:2.0];
				NSString * vs = nil;
				for (size_t v=0; v<8; ++v)
					if (volta & (1<<v))
						if (vs)
							vs = [NSString stringWithFormat:@"%@, %d", vs, v+1];
						else
							vs = [NSString stringWithFormat:@"%d", v+1];
				[vs drawAtPoint: NSMakePoint(x+kVoltaTextOff, kSystemY+kMeasNoY)
					withAttributes: sMeasNoFont];
			}
			if (song->DoesEndEnding(m+1, &repeat)) {
				[bz setLineWidth:kThin];
				[bz moveToPoint: NSMakePoint(x+0.5f*kMeasureW, yy+2.0f*kLineH)];
				[bz lineToPoint: NSMakePoint(x+kMeasureW-kDblLineOff, yy+2.0f*kLineH)];
				if (repeat)
					[bz lineToPoint: NSMakePoint(x+kMeasureW-kDblLineOff, yy+0.5f*kLineH)];
				[bz stroke];
				[bz removeAllPoints];			
				[bz setLineWidth:2.0];
			}
			if (song->fGoToCoda == m || song->fCoda == m) 
				[[self musicElement:kMusicCoda] 
					compositeToPoint: NSMakePoint(x+kCodaX, yy+kCodaY)
					operation: NSCompositeSourceOver];
		}
	}

	//
	// Draw division lines
	//
	[bz setLineWidth:0.0];
	[[NSColor colorWithDeviceWhite:0.8f alpha:1.0f] set];
	for (int measure = 0; measure<kLayout.NumMeasures(); ++measure) {
		const float mx	= kLayout.MeasurePosition(measure);
		const float y0	= kSystemY-(fNumBotLedgers+1)*kLineH;
		const float yy	= kSystemY+(fNumTopLedgers+5)*kLineH;
		for (int group = 0; group < kLayout.NumGroups(); ++group) {
			for (int div = 0; div < kLayout.DivPerGroup(); ++div) {
				const float x = mx+(group*(kLayout.DivPerGroup()+1)+div+1)*kNoteW;
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
	[[NSString stringWithFormat:@"%d", fLayout->FirstMeasure(system)+1]
		drawAtPoint: NSMakePoint(kMeasNoX, kSystemY+kMeasNoY)
		withAttributes: sMeasNoFont];
	//
	// Draw key (sharps & flats)
	//
	if (kProp.fKey > 0) {
		float x = kClefX+kClefW;
		for (int i=0; i<kProp.fKey; ++i) {
			[[self musicElement:kMusicSharp] 
				compositeToPoint: 
					NSMakePoint(x, kSystemY+sSharpPos[i]+kSharpY)
				operation: NSCompositeSourceOver];
			x += kAccW;
		}
	} else if (kProp.fKey < 0) {
		float x = kClefX+kClefW;
		for (int i=0; -i>kProp.fKey; ++i) {
			[[self musicElement: kMusicFlat] 
				compositeToPoint: 
					NSMakePoint(x, kSystemY+sFlatPos[i]+kFlatY)
				operation: NSCompositeSourceOver];
			x += kAccW;
		}
	}
	//
	// Draw break character
	//
	int breakType 	= 0;
	int nextMeasure	= fLayout->FirstMeasure(system+1);
	if (nextMeasure < song->fMeasures.size())
		breakType = song->fMeasures[nextMeasure].fBreak;
	if (breakType)
		[[NSString stringWithUTF8String:sBreak[breakType]]
			drawAtPoint: NSMakePoint(kLineX+kLineW+kBreakX, kSystemY+kBreakY)
			withAttributes: sBreakFont];
}

- (NSColor *)notesBackgroundColorForSystem:(int)system
{
	NSArray * colors = [NSColor controlAlternatingRowBackgroundColors];
	
	return [colors objectAtIndex:0];
}

- (NSColor *)textBackgroundColorForSystem:(int)system
{
	const VLSong * 	song	   	= [self song];
	const bool		kAltColors  = song->fMeasures[fLayout->FirstMeasure(system)].fPropIdx & 1;

	NSArray * colors = [NSColor controlAlternatingRowBackgroundColors];
	NSColor * color= [colors objectAtIndex:1];
	if (kAltColors) {
		CGFloat hue, saturation, brightness, alpha;
		
		[[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getHue:&hue saturation:&saturation 
				 brightness:&brightness alpha:&alpha];

		if (saturation) // Color
			hue = fmod(hue-0.5f, 1.0f);
		else 			// Black & white
			brightness -= 0.05f;

		color = [NSColor colorWithCalibratedHue:hue saturation:saturation 
						 brightness:brightness alpha:alpha];
	}
	return color;
}

- (void)drawBackgroundForSystem:(int)system
{
	const float 	kSystemY 	= [self systemY:system];
	const float 	kLineW		= (*fLayout)[system].SystemWidth();

	[NSGraphicsContext saveGraphicsState];
	[[self textBackgroundColorForSystem:system] setFill];
	[NSBezierPath fillRect:
	   NSMakeRect(kLineX, kSystemY-kSystemBaseline, 
				  kLineW, fNumStanzas*kLyricsH)];
	[NSBezierPath fillRect:
	   NSMakeRect(kLineX, kSystemY+kChordY, kLineW, kChordH)];
	[[self notesBackgroundColorForSystem:system] setFill];
	[NSBezierPath fillRect:
	   NSMakeRect(kLineX, kSystemY-kSystemBaseline+fNumStanzas*kLyricsH, 
				  kLineW, kSystemBaseline+kChordY-fNumStanzas*kLyricsH)];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)highlightSelectionForSystem:(int)system
{
	int startMeas = std::max(fSelStart-fLayout->FirstMeasure(system), 0);
	int endMeas	  = std::min(fSelEnd-fLayout->FirstMeasure(system), (*fLayout)[system].NumMeasures());
	const float kRawSystemY = [self systemY:system]-kSystemBaseline;
	const VLSystemLayout & kLayout = (*fLayout)[system];

	[NSGraphicsContext saveGraphicsState];
	[[NSColor selectedTextBackgroundColor] setFill];
	if (fSelStart == fSelEnd) 
		[NSBezierPath fillRect:
		   NSMakeRect(kLayout.MeasurePosition(startMeas)-kMeasTol, kRawSystemY, 
					  2.0f*kMeasTol, kSystemH)];  
	else
		[NSBezierPath fillRect:
		   NSMakeRect(kLayout.MeasurePosition(startMeas), kRawSystemY, 
					  (endMeas-startMeas)*kLayout.MeasureWidth(), kSystemH)];  
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawRect:(NSRect)rect
{
    if (![self song])
        return;
    
	if (fNeedsRecalc || [self inLiveResize] || [self song]->CountMeasures() != fLastMeasures) {
		[self recalculateDimensions];
		rect = [self bounds];
	}
	[NSGraphicsContext saveGraphicsState];
	[[NSColor whiteColor] setFill];
	[NSBezierPath fillRect:rect];
	[NSGraphicsContext restoreGraphicsState];

	size_t stanzas = [self song]->CountStanzas();
	for (int system = 0; system<fLayout->NumSystems(); ++system) {
		const float kSystemY = [self systemY:system];
		NSRect systemRect	 = NSMakeRect(kLineX, kSystemY-kSystemBaseline, (*fLayout)[system].SystemWidth(), kSystemH);
		if (!NSIntersectsRect(rect, systemRect)) 
			continue; // This system does not need to be drawn

		[self drawBackgroundForSystem:system];
		//
		// When highlighting, draw highlight FIRST and then draw our stuff
		// on top.
		//
		if (fSelStart <= fSelEnd 
			&& fLayout->FirstMeasure(system+1) > fSelStart-(fSelStart==fSelEnd) 
			&& fLayout->FirstMeasure(system) < fSelEnd+(fSelStart==fSelEnd)
		)
			[self highlightSelectionForSystem:system];
		[self drawGridForSystem:system];
		[self drawNotesForSystem:system];
		[self drawChordsForSystem:system];
		for (size_t stanza=0; stanza++<stanzas;)
			[self drawLyricsForSystem:system stanza:stanza];
	}	
	[[self editTarget] highlightCursor];
}

- (void)setKey:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(id)sender
{
	if (returnCode == NSAlertAlternateReturn)
		return;

	int key = [[sender selectedItem] tag];
	[[self document] setKey:key transpose:returnCode==NSAlertDefaultReturn
					 inSections:[self sectionsInSelection]];
	fNeedsRecalc = kRecalc;
	[self setNeedsDisplay: YES];	
}

- (IBAction) setKey:(id)sender
{
	if ([self song]->IsNonEmpty()) {
		int 	newKey 	= [[sender selectedItem] tag] >> 8;
		NSRange	sections= [self sectionsInSelection];
		VLSong *song	= [self song];
		bool	plural  = sections.length > 1;

		while (sections.length-- > 0)
			if (song->fProperties[sections.location++].fKey != newKey) {
				[[NSAlert alertWithMessageText:@"Transpose Song?"
						  defaultButton:@"Transpose"
						  alternateButton:@"Cancel"
						  otherButton:@"Change Key"
						  informativeTextWithFormat:
							  @"Do you want to transpose the %@ into the new key?",
						  (fSelEnd > -1 && song->fProperties.size() > 1)
						  ? (plural ? @"sections" : @"section") : @"song"
				  ]
					beginSheetModalForWindow:[self window]
					modalDelegate:self 
					didEndSelector:@selector(setKey:returnCode:contextInfo:)
					contextInfo:sender];
				return;
			}
	}
	[self setKey:nil returnCode:NSAlertOtherReturn contextInfo:sender];
}

- (IBAction) transposeOctave:(id)sender
{
	[[self document] changeOctave:[sender tag] > 0 
					 inSections:[self sectionsInSelection]];
}

- (IBAction) setTime:(id)sender
{
	int time = [[sender selectedItem] tag];

	[[self document] setTimeNum: time >> 8 denom: time & 0xFF
					 inSections:[self sectionsInSelection]];
	fNeedsRecalc = kRecalc;
	[self setNeedsDisplay: YES];	
}

- (IBAction) setDivisions:(id)sender
{
	int div = [[sender selectedItem] tag];

	[[self document] setDivisions: div inSections:[self sectionsInSelection]];
	fNeedsRecalc = kRecalc;
	[self setNeedsDisplay: YES];	
}

- (IBAction)hideFieldEditor:(id)sender
{
	[fFieldEditor setAction:nil];
}

const float kSemiFloor = -1.0f*kLineH;

- (void) accidentalFromEvent:(NSEvent *)event
{
    switch ([event modifierFlags] & (NSShiftKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) {
    case NSShiftKeyMask:
        fCursorVisual       = kCursorExtend;
        break;
    case NSShiftKeyMask|NSAlternateKeyMask:
        fCursorVisual       = VLNote::kWant2Flat;    // Gbb
        break;
    case NSAlternateKeyMask:
        fCursorVisual       = VLNote::kWantFlat;     // Gb
        break;
    case NSShiftKeyMask|NSCommandKeyMask:
        fCursorVisual       = VLNote::kWant2Sharp;   // G##
        break;				  
    case NSCommandKeyMask:
        fCursorVisual       = VLNote::kWantSharp;    // G#
        break;
    case NSAlternateKeyMask|NSCommandKeyMask:
        fCursorVisual       = VLNote::kWantNatural;  // G
        break;
    default:
        fCursorVisual       = 0;
        break;
    }
}

- (VLRegion) findRegionForEvent:(NSEvent *) event
{
	fCursorVertPos          = kCursorNoPitch;

	NSPoint loc 			= [event locationInWindow];
	loc 					= [self convertPoint:loc fromView:nil];
    int system              = [self systemForPoint:&loc];

	if (system < 0 || system > fLayout->NumSystems())
		return fCursorRegion = kRegionNowhere;

	const VLSong * 			song  		= [self song];		
	const VLSystemLayout &	kLayout		= (*fLayout)[system];
	const float				kMeasureW	= kLayout.MeasureWidth();

	loc.x -= kLayout.ClefKeyWidth();

	if (loc.y > kSystemBaseline && loc.y < kSystemBaseline+4.0f*kLineH
	 && fmodf(loc.x+kMeasTol, kMeasureW) < 2*kMeasTol
	) {
		int measure = static_cast<int>((loc.x+kMeasTol)/kMeasureW);

		if (measure < 0 || measure > kLayout.NumMeasures())
			return fCursorRegion = kRegionNowhere;

		fCursorLocation.fMeasure	= measure+fLayout->FirstMeasure(system);
			
		if (fCursorLocation.fMeasure > [self song]->fMeasures.size())
			return fCursorRegion = kRegionNowhere;
		else
			return fCursorRegion = kRegionMeasure;
	}
	if (loc.x < 0.0f || loc.x >= kLayout.NumMeasures()*kMeasureW)
		return fCursorRegion = kRegionNowhere;
	
	int measure 	= static_cast<int>(loc.x / kMeasureW);
	loc.x	   	   -= measure*kMeasureW;
	int group	  	= static_cast<int>(loc.x / ((kLayout.DivPerGroup()+1)*kNoteW));
	loc.x		   -= group*(kLayout.DivPerGroup()+1)*kNoteW;
	int div			= static_cast<int>(roundf(loc.x / kNoteW))-1;
	div				= std::min(std::max(div, 0), kLayout.DivPerGroup()-1);
	fCursorLocation.fMeasure	= measure+fLayout->FirstMeasure(system);
	if (fCursorLocation.fMeasure > [self song]->fMeasures.size())
		return fCursorRegion = kRegionNowhere;
		
	fCursorLocation.fAt 		= VLFraction(div+group*kLayout.DivPerGroup(), 4*song->Properties(fCursorLocation.fMeasure).fDivisions);

	if (loc.y >= kSystemBaseline+kChordY) {
		//
		// Chord, round to quarters
		//
		int scale = fCursorLocation.fAt.fDenom / 4;
		fCursorLocation.fAt = VLFraction(fCursorLocation.fAt.fNum / scale, 4);
		return fCursorRegion = kRegionChord;
	} else if (loc.y < kSystemBaseline+kLyricsY) {
		fCursorStanza = static_cast<size_t>((kSystemBaseline+kLyricsY-loc.y) / kLyricsH)
			+ 1;
		return fCursorRegion = kRegionLyrics;
	}

	loc.y		   	   -= kSystemBaseline+kSemiFloor;
	fCursorVertPos      = static_cast<int>(roundf(loc.y / (0.5f*kLineH)));

	[self accidentalFromEvent:event];

	return fCursorRegion = kRegionNote;
}

- (void) mouseMoved:(NSEvent *)event
{
   	if ([event modifierFlags] & NSAlphaShiftKeyMask)
		return; // Keyboard mode, ignore mouse

	bool hadCursor = fCursorRegion == kRegionNote;
	[self findRegionForEvent:event];
	bool hasCursor = fCursorRegion == kRegionNote;

	[self setNeedsDisplay:(hadCursor || hasCursor)];
}

- (void)flagsChanged:(NSEvent *)event
{
	if (fCursorRegion == kRegionNote) {
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
	fCursorRegion = kRegionNowhere;
	[[self window] setAcceptsMouseMovedEvents:NO];
	[self setNeedsDisplay:YES];
}

- (void) mouseDown:(NSEvent *)event
{
    BOOL extend = ([event modifierFlags] & NSShiftKeyMask) != 0;
	switch ([self findRegionForEvent:event]) {
	case kRegionNote:
        [self setEditTarget:nil];
        fSelEnd		= -1;
        [self addNoteAtCursor];
		break;
	case kRegionChord:
        fSelEnd		= -1;
		[self editChord];
		break;
	case kRegionLyrics:
        if (extend && [[self editTarget] canExtendSelection:kRegionLyrics]) {
            [[self editTarget] extendSelection:fCursorLocation];
        } else {
            fSelEnd		= -1;
            [self editLyrics];
        }
		break;
	case kRegionMeasure:
        [self setEditTarget:nil];
        [self editSelection:extend];
		break;
	default:
        [self setEditTarget:nil];
        fSelEnd		= -1;
		break;
	}
}

- (void) mouseDragged:(NSEvent *)event
{
    VLRegion prevRegion = fCursorRegion;
    
    [super mouseDragged:event];
	[self autoscroll:event];
	if (prevRegion == kRegionMeasure)
		[self adjustSelection:event];
    else if ([[self editTarget] canExtendSelection:[self findRegionForEvent:event]])
        [[self editTarget] extendSelection:fCursorLocation];
}

- (void) keyDown:(NSEvent *)event
{
	NSString * k = [event charactersIgnoringModifiers];
	
	switch ([k characterAtIndex:0]) {
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
		[self setNeedsDisplay:YES];
        break;
	}
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	return [[self editTarget] validValue:[fFieldEditor stringValue]];
}

- (void)updateFirstResponder
{
	NSWindow * 		win 			= [self window];
	NSResponder * 	hasResponder	= [win firstResponder];
	if ([self editTarget]) 
		if (hasResponder != [win fieldEditor:NO forObject:nil] 
		 || [(id)hasResponder delegate] != fFieldEditor
		)
			[win makeFirstResponder:fFieldEditor];
}

- (void)controlTextDidEndEditing:(NSNotification *)note
{
	VLEditable * editable = [self editTarget];
	switch ([[[note userInfo] objectForKey:@"NSTextMovement"] intValue]) {
	case NSTabTextMovement:
		[editable moveToNext];
		break;
	case NSBacktabTextMovement:
		[editable moveToPrev];
		break;
    case NSReturnTextMovement:
        [self setEditTarget:nil];
        // Fall through
	default:
		fHighlightStanza = 0xFFFFFFFF;
        editable         = nil;
	}
	if (editable) 
		[fFieldEditor selectText:self];
	else 
		[[self window] makeFirstResponder:self];
	[self performSelectorOnMainThread:@selector(updateFirstResponder)
		  withObject:nil waitUntilDone:NO];
	[self setNeedsDisplay: YES];
}

- (void) setScaleFactor:(float)scale
{
	float ratio = scale/fDisplayScale;
	for (int i=0; i<kMusicElements; ++i) {
		NSSize sz = [fMusic[i] size];
		sz.width *= ratio;
		sz.height*= ratio;
		[fMusic[i] setSize:sz];
	}
	fDisplayScale= scale;
	fNeedsRecalc = kRecalc;
	[self setNeedsDisplay: YES];	
}

- (IBAction) zoomIn: (id) sender
{
	[self setScaleFactor: fDisplayScale * sqrt(sqrt(2.0))];
}

- (IBAction) zoomOut: (id) sender
{
	[self setScaleFactor: fDisplayScale / sqrt(sqrt(2.0))];
}

- (void)awakeFromNib
{
	VLDocument * doc = [self document];

	[doc addObserver:self forKeyPath:@"song" options:0 context:nil];
	[doc addObserver:self forKeyPath:@"songKey" options:0 context:nil];	
	[doc addObserver:self forKeyPath:@"songTime" options:0 context:nil];	
	[doc addObserver:self forKeyPath:@"songDivisions" options:0 context:nil];	
	[doc addObserver:self forKeyPath:@"songGroove" options:0 context:nil];	

	VLSong * song 	= [self song];
	fNumTopLedgers 	= std::max<int>(song->CountTopLedgers(), 1);
	fNumBotLedgers 	= std::max<int>(song->CountBotLedgers(), 1);
	fNumStanzas    	= std::max<int>(song->CountStanzas(), 2);

	[fGrooveMenu addItemsWithTitles:
	   [[NSUserDefaults standardUserDefaults] arrayForKey:@"VLGrooves"]];	

	[self updateMenus];
    [self recalculateDimensions];
    fNeedsRecalc = kFirstRecalc;
}

- (void)removeObservers:(id)target
{
	[target removeObserver:self forKeyPath:@"song"];
	[target removeObserver:self forKeyPath:@"songKey"];	
	[target removeObserver:self forKeyPath:@"songTime"];	
	[target removeObserver:self forKeyPath:@"songDivisions"];	
	[target removeObserver:self forKeyPath:@"songGroove"];	
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)o change:(NSDictionary *)c context:(id)ctx
{
	if ([keyPath isEqual:@"songKey"]) {
		fNeedsRecalc = kRecalc;
		[self setNeedsDisplay: YES];
		[self updateKeyMenu];
	} else if ([keyPath isEqual:@"song"]) {
		[self setNeedsDisplay: YES];
	} else if ([keyPath isEqual:@"songTime"]) {
		[self updateTimeMenu];
	} else if ([keyPath isEqual:@"songDivisions"]) {
		[self updateDivisionMenu];
	} else if ([keyPath isEqual:@"songGroove"]) {
		[self updateGrooveMenu];
	}					
}

- (IBAction)endSheetWithButton:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
}

- (IBAction)selectGroove:(id)sender
{
	if ([sender tag]) 
		[[VLGrooveController alloc] initWithSheetView:self];
	else	
		[self setGroove:[sender title]];
}

- (void)setGroove:(NSString *)groove
{
    if (groove)
        [[self document] setGroove:groove inSections:[self sectionsInSelection]];
}

- (void)playWithGroove:(NSString *)groove
{
	[[self document] playWithGroove:groove inSections:[self sectionsInSelection]];
}

@end
	
