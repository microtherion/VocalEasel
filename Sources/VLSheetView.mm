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
		needsRecalc			= YES;
		showFieldEditor		= NO;
		displayScale		= 1.0f;
		firstMeasure		= 0;
		noteRectTracker 	= 0;
		noteCursorCache 	= nil;
		noteCursorMeasure	= -1;
	}
    return self;
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

- (float) noteXInMeasure:(int)measure at:(VLFraction)at
{
	const VLProperties & prop	= [self song]->fProperties.front();
	const float mx				= clefKeyW+(measure-firstMeasure)*measureW;

	at 		/= prop.fTime / (4 * prop.fDivisions);
	int div	=  at.fNum / at.fDenom;

	return mx + (div + (div / divPerGroup) + 1)*kNoteW;
}

- (void) recalculateDimensions 
{
	needsRecalc	= NO;	

	NSSize contentSz =  [[self enclosingScrollView] contentSize];
	contentSz.width	/=	displayScale;
	contentSz.height/= 	displayScale;

	const VLSong * 			song = [self song];
	const VLProperties & 	prop = song->fProperties.front();

	groups 				= prop.fTime.fNum / std::max(prop.fTime.fDenom / 4, 1); 
	quarterBeats 		= (prop.fTime.fNum*4) / prop.fTime.fDenom;
	divPerGroup			= prop.fDivisions * (quarterBeats / groups);
	clefKeyW			= kClefX+kClefW+(std::labs(prop.fKey)+1)*kKeyW;
	measureW			= groups*(divPerGroup+1)*kNoteW;
	measuresPerSystem	=
		(int)std::floor((contentSz.width - clefKeyW) / measureW);
	numSystems 			= (song->CountMeasures()+measuresPerSystem-1)/measuresPerSystem;
	contentSz.height	= numSystems*kSystemH;

#if 0
	noteRect		= NSMakeRect(clefKeyW, kLineY-kMaxLedgers*kLineH, 
								 visibleMeasures*measureW, 
								 (4.0f+2.0f*kMaxLedgers)*kLineH);
	NSPoint	mouse	= 
		[self convertPoint:[[self window] mouseLocationOutsideOfEventStream]
			  fromView: nil];
	BOOL inNoteRect	= [self mouse:mouse inRect:noteRect];
	
	[self removeTrackingRect:noteRectTracker];
	noteRectTracker = [self addTrackingRect:noteRect owner:self
							userData:nil assumeInside:inNoteRect];
	[[self window] setAcceptsMouseMovedEvents:inNoteRect];
#endif

	[[self window] makeFirstResponder:self];

	NSSize frameSz	= {contentSz.width * displayScale, contentSz.height * displayScale};

	[self setFrameSize:frameSz];
	[self setBoundsSize:contentSz];
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	static NSDictionary * sMeasNoFont 	 = nil;
	if (!sMeasNoFont)
		sMeasNoFont =
			[[NSDictionary alloc] initWithObjectsAndKeys:
				[NSFont fontWithName: @"Helvetica" size: 10],
                NSFontAttributeName,
				nil];

	const VLSong * 			song = [self song];
	const VLProperties & 	prop = song->fProperties.front();

	NSBezierPath * bz = [NSBezierPath bezierPath];
	
	//
	// Draw lines
	//
	[bz setLineWidth:0.0];
	if (needsRecalc)
		[self recalculateDimensions];
	for (int system = 0; system<numSystems; ++system) {
		float kLineY = [self systemY:system];
		for (int line = 0; line<5; ++line) {
			const float x0	= kLineX;
			const float xx	= x0 + clefKeyW + measuresPerSystem*measureW;
			const float y	= kLineY+line*kLineH;
			[bz moveToPoint: NSMakePoint(x0, y)];
			[bz lineToPoint: NSMakePoint(xx, y)];
		}
	}
	[bz stroke];
	[bz removeAllPoints];
	//
	// Draw measure lines
	//
	[bz setLineWidth:2.0];
	for (int system = 0; system<numSystems; ++system) {
		float kLineY = [self systemY:system];
		for (int measure = 0; measure<=measuresPerSystem; ++measure) {
			const float x	= clefKeyW+measure*measureW;
			const float yy	= kLineY+4.0f*kLineH;
			[bz moveToPoint: NSMakePoint(x, kLineY)];
			[bz lineToPoint: NSMakePoint(x, yy)];
		}
	}
	[bz stroke];
	[bz removeAllPoints];

	//
	// Draw division lines
	//
	[bz setLineWidth:0.0];
	[[NSColor colorWithDeviceWhite:0.8f alpha:1.0f] set];
	for (int system = 0; system<numSystems; ++system) {
		float kLineY = [self systemY:system];
		for (int measure = 0; measure<measuresPerSystem; ++measure) {
			const float mx	= clefKeyW+measure*measureW;
			const float y0	= kLineY-2.0f*kLineH;
			const float yy	= kLineY+6.0f*kLineH;
			for (int group = 0; group < groups; ++group) {
				for (int div = 0; div < divPerGroup; ++div) {
					const float x = mx+(group*(divPerGroup+1)+div+1)*kNoteW;
					[bz moveToPoint: NSMakePoint(x, y0)];
					[bz lineToPoint: NSMakePoint(x, yy)];
				}
			}
		}
	}	
	[bz stroke];

	for (int system = 0; system<numSystems; ++system) {
		float kLineY = [self systemY:system];
		//
		// Draw clef
		//
		[[self musicElement:kMusicGClef] 
			compositeToPoint: NSMakePoint(kClefX, kLineY+kClefY)
			operation: NSCompositeSourceOver];
		//
		// Draw measure #
		//
		[[NSString stringWithFormat:@"%d", system*measuresPerSystem+1]
			drawAtPoint: NSMakePoint(kMeasNoX, kLineY+kMeasNoY)
			withAttributes: sMeasNoFont];
		//
		// Draw key (sharps & flats)
		//
		if (prop.fKey > 0) {
			float x = kClefX+kClefW;
			for (int i=0; i<prop.fKey; ++i) {
				[[self musicElement:kMusicSharp] 
					compositeToPoint: NSMakePoint(x, kLineY+sSharpPos[i]+kSharpY)
					operation: NSCompositeSourceOver];
				x += kAccW;
			}
		} else if (prop.fKey < 0) {
			float x = kClefX+kClefW;
			for (int i=0; -i>prop.fKey; ++i) {
				[[self musicElement: kMusicFlat] 
					compositeToPoint: NSMakePoint(x, kLineY+sFlatPos[i]+kFlatY)
					operation: NSCompositeSourceOver];
				x += kAccW;
			}
		}
	}

	//
	// Draw notes	
	//
	[self drawNotes];
}

- (IBAction) setKey:(id)sender
{
	int key = [[sender selectedItem] tag];
	[[self document] setKey: key transpose: YES];
	needsRecalc = YES;
	[self setNeedsDisplay: YES];
}

- (IBAction) setTime:(id)sender
{
	int time = [[sender selectedItem] tag];

	[[self document] setTimeNum: time >> 8 denom: time & 0xFF];
	needsRecalc = YES;
	[self setNeedsDisplay: YES];	
}

- (IBAction) setDivisions:(id)sender
{
	int div = [[sender selectedItem] tag];

	[[self document] setDivisions: div];
	needsRecalc = YES;
	[self setNeedsDisplay: YES];	
}

- (void) setFirstMeasure: (NSNumber *)measure
{
	firstMeasure = [measure intValue];

	[self setupChords];
	[self setNeedsDisplay: YES];	
}

- (IBAction)showFieldEditor:(id)sender withAction:(SEL)selector
{
	fieldBeingEdited = sender;
	[fieldEditor setObjectValue:[sender title]];
	[fieldEditor setAction:selector];
	[self setValue: [NSNumber numberWithBool:YES] 
			  forKey: @"showFieldEditor"];
}

- (IBAction)hideFieldEditor:(id)sender
{
	[fieldEditor setAction:nil];
	[self setValue: [NSNumber numberWithBool:NO] 
			  forKey: @"showFieldEditor"];
}

@end
