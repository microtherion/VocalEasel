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

#import "VLDocument.h"

#include <cmath>

@implementation VLSheetView

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
		fCursorPitch		= VLNote::kNoPitch;
		fSelStart			= 0;
		fSelEnd				= -1;
		fNumTopLedgers 		= 0;
		fNumBotLedgers 		= 2;
		fNumStanzas    		= 2;
		fLastMeasures		= 0;
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

- (VLEditable *) editTarget
{
	return [[[self window] windowController] editTarget];
}

- (void) setEditTarget:(VLEditable *)editable
{
	[[[self window] windowController] setEditTarget:editable];
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
	{_ F _ F _ _ F _ F _ F _}, // C major
 //  C C#D D#E F F#G G#A A#B 	
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
	bool 	useSharps	= key > 0;
	
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
	return [self systemY:fLayout->SystemForMeasure(measure)]
		+ [self noteYWithPitch:pitch accidental:accidental];
}

- (float) noteXInMeasure:(int)measure at:(VLFraction)at
{
	return fLayout->NotePosition(measure, at);
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
	sz.height	= std::max(2, fLayout->NumSystems())*kSystemH*fDisplayScale;

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

- (void)drawBackgroundForSystem:(int)system
{
	const VLSong * 	song	   	= [self song];
	const float 	kSystemY 	= [self systemY:system];
	const float 	kLineW		= (*fLayout)[system].SystemWidth();
	const bool		kAltColors  = song->fMeasures[fLayout->FirstMeasure(system)].fPropIdx & 1;

	NSArray * colors = [NSColor controlAlternatingRowBackgroundColors];
	NSColor * bgColor= [colors objectAtIndex:0];
	NSColor * fgColor= [colors objectAtIndex:1];
	if (kAltColors) {
		float hue, saturation, brightness, alpha;
		
		[[fgColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getHue:&hue saturation:&saturation 
				 brightness:&brightness alpha:&alpha];

		if (saturation) // Color
			hue = fmod(hue-0.5f, 1.0f);
		else 			// Black & white
			brightness -= 0.05f;

		fgColor = [NSColor colorWithCalibratedHue:hue saturation:saturation 
						   brightness:brightness alpha:alpha];
	}
	[NSGraphicsContext saveGraphicsState];
	[fgColor setFill];
	[NSBezierPath fillRect:
	   NSMakeRect(kLineX, kSystemY-kSystemBaseline, 
				  kLineW, fNumStanzas*kLyricsH)];
	[NSBezierPath fillRect:
	   NSMakeRect(kLineX, kSystemY+kChordY, kLineW, kChordH)];
	[bgColor setFill];
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
			&& fLayout->FirstMeasure(system+1) > fSelStart 
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

const float kSemiFloor = -5.0f*kLineH;
static int8_t sSemiToPitch[] = {
	47,     // B
	48, 50, // D
	52, 53, // F
	55,	57, // A
	59, 60, // Middle C
	62, 64, // E
	65, 67, // G
	69, 71, // B
	72, 74, // D
	76, 77, // F
	79, 81, // A
	83, 84, // C
	86, 88, // E
	89, 91, // G
	93, 95, // B
	96, 98  // D
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
	fCursorAccidental	= (VLMusicElement)0;

	//
	// Extension
	//
	if ([event modifierFlags] & NSShiftKeyMask) {
		fCursorAccidental = kMusicExtendCursor;
		return;
	}
	const VLProperties & 	prop = [self song]->fProperties.front();

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

	NSPoint loc 			= [event locationInWindow];
	loc 					= [self convertPoint:loc fromView:nil];
	const int kNumSystems	= std::max(2, fLayout->NumSystems());

	if (loc.y < 0.0f || loc.y >= kNumSystems*kSystemH)
		return fCursorRegion = kRegionNowhere;

	const VLSong * 			song  		= [self song];
	int 					system 		= 
		kNumSystems - static_cast<int>(loc.y / kSystemH) - 1;
	if (system >= fLayout->NumSystems())
		return fCursorRegion = kRegionNowhere;
		
	const VLSystemLayout &	kLayout		= (*fLayout)[system];
	const float				kMeasureW	= kLayout.MeasureWidth();
	loc.y      = fmodf(loc.y, kSystemH);

	loc.x -= kLayout.ClefKeyWidth();

	if (loc.y > kSystemBaseline && loc.y < kSystemBaseline+4.0f*kLineH
	 && fmodf(loc.x+kMeasTol, kMeasureW) < 2*kMeasTol
	) {
		int measure = static_cast<int>((loc.x+kMeasTol)/kMeasureW);

		if (measure < 0 || measure > kLayout.NumMeasures())
			return fCursorRegion = kRegionNowhere;

		fCursorMeasure	= measure+fLayout->FirstMeasure(system);
			
		if (fCursorMeasure > [self song]->fMeasures.size())
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
	fCursorMeasure	= measure+fLayout->FirstMeasure(system);
	if (fCursorMeasure > [self song]->fMeasures.size())
		return fCursorRegion = kRegionNowhere;
		
	fCursorAt 		= VLFraction(div+group*kLayout.DivPerGroup(), 4*song->Properties(fCursorMeasure).fDivisions);

	if (loc.y >= kSystemBaseline+kChordY) {
		//
		// Chord, round to quarters
		//
		int scale = fCursorAt.fDenom / 4;
		fCursorAt = VLFraction(fCursorAt.fNum / scale, 4);
		return fCursorRegion = kRegionChord;
	} else if (loc.y < kSystemBaseline+kLyricsY) {
		fCursorStanza = static_cast<size_t>((kSystemBaseline+kLyricsY-loc.y) / kLyricsH)
			+ 1;
		return fCursorRegion = kRegionLyrics;
	}

	loc.y		   	   -= kSystemBaseline+kSemiFloor;
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
	fCursorPitch = VLNote::kNoPitch;
	[[self window] setAcceptsMouseMovedEvents:NO];
	[self setNeedsDisplay:YES];
}

- (void) mouseDown:(NSEvent *)event
{
	fSelEnd		= -1;
	switch ([self findRegionForEvent:event]) {
	case kRegionNote:
		[self addNoteAtCursor];
		break;
	case kRegionChord:
		[self editChord];
		break;
	case kRegionLyrics:
		[self editLyrics];
		break;
	case kRegionMeasure:
		[self editSelection];
		break;
	default:
		break;
	}
}

- (void) mouseDragged:(NSEvent *)event
{
	bool inMeasureSelection = fCursorRegion == kRegionMeasure;

	if (!inMeasureSelection)
		[super mouseDragged:event];
	[self autoscroll:event];
	if (inMeasureSelection)
		[self adjustSelection:event];
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
	return [[self editTarget] validValue:[fFieldEditor stringValue]];
}

- (void)updateFirstResponder
{
	NSWindow * 		win 			= [self window];
	NSResponder * 	hasResponder	= [win firstResponder];
	if ([self editTarget]) 
		if (hasResponder != [win fieldEditor:NO forObject:nil] 
		 || [hasResponder delegate] != fFieldEditor
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
	default:
		[editable autorelease];
		editable = nil;
	}
	[self setEditTarget:editable];
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

	[doc addObserver:self];
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
	[[self document] setGroove:groove inSections:[self sectionsInSelection]];
}

- (void)playWithGroove:(NSString *)groove
{
	[[self document] playWithGroove:groove inSections:[self sectionsInSelection]];
}

- (IBAction)editDisplayOptions:(id)sender
{
	NSUndoManager * undoMgr = [[self document] undoManager];	
	[undoMgr setGroupsByEvent:NO];
	[undoMgr beginUndoGrouping];

	VLSheetWindow * wc = [[self window] windowController];
	[wc setValue:[NSNumber numberWithInt:fNumTopLedgers] 
		forKey:@"editNumTopLedgers"];
	[wc setValue:[NSNumber numberWithInt:fNumBotLedgers] 
		forKey:@"editNumBotLedgers"];
	[wc setValue:[NSNumber numberWithInt:fNumStanzas] 
		forKey:@"editNumStanzas"];

	[NSApp beginSheet:fDisplaySheet modalForWindow:[self window]
		   modalDelegate:self 
		   didEndSelector:@selector(didEndDisplaySheet:returnCode:contextInfo:)
		   contextInfo:nil];
}

- (void)didEndDisplaySheet:(NSWindow *)sheet returnCode:(int)returnCode 
			  contextInfo:(void *)ctx
{
	NSUndoManager * undoMgr = [[self document] undoManager];
	[undoMgr setActionName:@"Display Options"];
	[undoMgr endUndoGrouping];
	[undoMgr setGroupsByEvent:YES];

	switch (returnCode) {
	case NSAlertFirstButtonReturn: {
		VLSheetWindow * wc = [[self window] windowController];
		fNumTopLedgers = [[wc valueForKey:@"editNumTopLedgers"] intValue];
		fNumBotLedgers = [[wc valueForKey:@"editNumBotLedgers"] intValue];
		fNumStanzas    = [[wc valueForKey:@"editNumStanzas"] intValue];
		fNeedsRecalc   = kRecalc;
		[self setNeedsDisplay:YES];
	    } break;
	default:
		[undoMgr undo];
		break;
	}	
	[sheet orderOut:self];
}

@end
	
