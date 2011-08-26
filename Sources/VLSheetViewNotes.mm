//
// File: VLSheetViewNotes.mm - Melody editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2008 Matthias Neeracher
//

#import "VLSheetView.h"
#import "VLSheetViewNotes.h"
#import "VLSheetViewInternal.h"
#import "VLDocument.h"
#import "VLSoundOut.h"

#include <algorithm>

@implementation VLSheetView (Notes)

- (void) addNoteAtCursor
{	
	if (fCursorMeasure > -1 && fCursorActualPitch) {
		VLNote	newNote(1, fClickMode==' ' ? fCursorActualPitch : VLNote::kNoPitch);
		switch (fCursorAccidental) {
		case kMusicFlatCursor:
			newNote.fVisual |= VLNote::kWantFlat;
			break;
		case kMusicSharpCursor:
			newNote.fVisual |= VLNote::kWantSharp;
			break;
		}
		[[self document] willChangeSong];
		if (fCursorAccidental == kMusicExtendCursor) 
			[self song]->ExtendNote(fCursorMeasure, fCursorAt);
		else if (fClickMode == 'k')
			[self song]->DelNote(fCursorMeasure, fCursorAt);
		else	
			[self song]->AddNote(VLLyricsNote(newNote), fCursorMeasure, fCursorAt);
		[[self document] didChangeSong];

		if (fClickMode == ' ')
			VLSoundOut::Instance()->PlayNote(newNote);
		else
			fClickMode	= ' ';
	}
}

- (void) startKeyboardCursor
{
	if (fCursorMeasure < 0) {
		fCursorMeasure		= 0;
		fCursorPitch		= VLNote::kMiddleC;
		fCursorActualPitch	= fCursorPitch;
		fCursorAt			= VLFraction(0);
	}
}

- (void) drawLedgerLinesInSection:(int)section withPitch:(int)pitch visual:(int)visual at:(NSPoint)p
{
	p.x	   += kLedgerX;
	int	octave	= (pitch / 12) - 5;
	int step	= (octave*7
				   + [self stepInSection:section withPitch:pitch visual:visual]
				   - 2
				  ) / 2;
	
	for (int i=0; i-- > step; ) {
		NSPoint p0	= p;
		p0.y	   += i*kLineH;
		NSPoint p1	= p0;
		p1.x	   += kLedgerW;
		[NSBezierPath strokeLineFromPoint:p0 toPoint:p1];
	}
	for (int i=4; i++ < step; ) {
		NSPoint p0	= p;
		p0.y	   += i*kLineH;
		NSPoint p1	= p0;
		p1.x	   += kLedgerW;
		[NSBezierPath strokeLineFromPoint:p0 toPoint:p1];
	}
}

- (void) drawNoteCursor:(int)pitch inMeasure:(size_t)measure at:(VLFract)at
					  accidental:(VLMusicElement)accidental
							mode:(char)mode
{
	int 			cursorX;
	int				cursorY;
	int				cursorSect;
	int 			cursorVisual = 0;
	VLMusicElement	acc;
	VLMusicElement	cursorElt;
	
	cursorX = [self noteXInMeasure:measure at:at];
	if (accidental == kMusicExtendCursor) {
		cursorY 	= 
			[self noteYInMeasure:measure 
				  withPitch:pitch
				  visual:0
				  accidental:&acc];
		cursorElt	= accidental;
	} else
		switch (mode) {
		default:
			switch (accidental) {
			case kMusicSharp:
				cursorVisual = VLNote::kWantSharp;
				break;
			case kMusicFlat:
				cursorVisual = VLNote::kWantFlat;
				break;
			}
			cursorY 	= 
				[self noteYInMeasure:measure withPitch:pitch 
					  visual:cursorVisual accidental:&acc] - kNoteY;
			cursorSect  = [self song]->fMeasures[measure].fPropIdx;
			[self drawLedgerLinesInSection:cursorSect withPitch:pitch 
				  visual:cursorVisual at:NSMakePoint(cursorX, 
					 [self systemY:fLayout->SystemForMeasure(measure)])];
			cursorElt 	= kMusicNoteCursor;
			break;
		case 'r':
			cursorY 	= [self noteYInMeasure:measure 
								withPitch:65 visual:0 accidental:&acc];
			cursorElt	= kMusicRestCursor;
			break;
		case 'k':
			cursorY 	= [self noteYInMeasure:measure 
								withPitch:pitch visual:0 
								accidental:&acc];
			cursorElt	= kMusicKillCursor;
			break;
		}
	
	NSPoint	xy = NSMakePoint(cursorX-kNoteX, cursorY);
	[[self musicElement:cursorElt] 
		compositeToPoint:xy
		operation: NSCompositeSourceOver];
	if (accidental  && accidental != kMusicExtendCursor) {
		xy.y	+= kNoteY;
		switch (cursorElt= accidental) {
		case kMusicFlatCursor:
			xy.x	+= kFlatW;
			xy.y	+= kFlatY;
			break;
		case kMusicSharpCursor:
			xy.x	+= kSharpW;
			xy.y	+= kSharpY;
			break;
		default:
			xy.x	+= kNaturalW;
			xy.y	+= kNaturalY;
			break;
		}
		[[self musicElement:cursorElt] 
			compositeToPoint:xy
			operation: NSCompositeSourceOver];
	}
}

- (void) drawNoteCursor:(int)pitch inMeasure:(size_t)measure at:(VLFract)at
             accidental:(VLMusicElement)accidental
{
	[self drawNoteCursor:pitch inMeasure:measure at:at 
		  accidental:accidental mode:' '];
}

- (void) drawNoteCursor
{
	[self drawNoteCursor:fCursorPitch inMeasure:fCursorMeasure at:fCursorAt
		  accidental:fCursorAccidental mode:fClickMode];	
}

- (void) drawNote:(int)visual at:(NSPoint)p 
	   accidental:(VLMusicElement)accidental tied:(BOOL)tied
{
	NSPoint s = p;
	NSPoint c = p;
	p.x	-= kNoteX;
	p.y	-= kNoteY;
	s.x += kNoteX+kStemX;
	s.y += kStemY;
	//	
	// Draw note head
	//
	NSImage * head;
	switch (visual & VLNote::kNoteHead) {
	case VLNote::kWhole:
		head = [self musicElement:kMusicWholeNote];
		break;
	case VLNote::kHalf:
		head = [self musicElement:kMusicHalfNote];
		s.x -= 1.0f;
		break;
	default:
		head = [self musicElement:kMusicNote];
		s.x	-= 2.0f;
		break;
	}
	[head compositeToPoint:p
		  operation: NSCompositePlusDarker];	
	//
	// Draw accidental
	//
	if (accidental) {
		NSPoint at = p;
		at.y 	  += kNoteY;
		switch (accidental) {
		case kMusicSharp:
			at.x	+= kSharpW;
			at.y	+= kSharpY;
			break;
		case kMusicFlat:
			at.x	+= kFlatW;
			at.y	+= kFlatY;
			break;
		case kMusicNatural:
			at.x	+= kNaturalW;
			at.y	+= kNaturalY;
			break;
		}
		[[self musicElement:accidental] 
			compositeToPoint:at operation: NSCompositeSourceOver];
	}
	//
	// Draw stem
	//
	//
	//
	if (visual > 0) {
		NSBezierPath * bz = [NSBezierPath bezierPath];		
		NSPoint s1 = NSMakePoint(s.x, s.y+kStemH);
		NSImage * flag = nil;	
		switch (visual) {
		case VLNote::kEighth:
			flag = [self musicElement:kMusicEighthFlag];
			break;
		case VLNote::k16th:
			flag = [self musicElement:kMusicSixteenthFlag];
			s1.y += 5.0f;
			break;
		case VLNote::k32nd:
			flag = [self musicElement:kMusicThirtysecondthFlag];
			s1.y += 13.0f;
			break;
		}
		[[NSColor blackColor] set];
		[bz setLineWidth:2.0f];
		[bz moveToPoint:s];
		[bz lineToPoint:s1];
		[bz stroke];
		if (flag) 
			[flag compositeToPoint:s
				  operation: NSCompositePlusDarker];
	}
	//
	// Draw tie
	//
	if (tied) {
		NSPoint mid = 
			NSMakePoint(0.5f*(fLastNoteCenter.x+c.x),
						0.5f*(fLastNoteCenter.y+c.y));
		NSPoint dir = NSMakePoint(c.y-mid.y, c.x-mid.x);
		float   n   = dir.x*dir.x+dir.y*dir.y;
		float 	r	= (kTieDepth*kTieDepth+n) / (2.0f*kTieDepth);
		float   l	= (r-kTieDepth) / sqrtf(n);
		mid.x      += dir.x*l;
		mid.y      += dir.y*l;
		float a1	= atan2(fLastNoteCenter.y-mid.y, fLastNoteCenter.x-mid.x);
		float a2	= atan2(c.y-mid.y, c.x-mid.x);
		NSBezierPath * bz = [NSBezierPath bezierPath];		
		[bz appendBezierPathWithArcWithCenter:mid radius:r
			startAngle:a1*180.0f/M_PI endAngle:a2*180.0f/M_PI];
		[bz stroke];
	}
	fLastNoteCenter	= c;
}

- (void) drawRest:(int)visual at:(NSPoint)p
{
	//
	// Draw rest
	//
	NSImage * head = nil;
	switch (visual) {
	case VLNote::kWhole:
		head = [self musicElement:kMusicWholeRest];
		p.y	+= kWholeRestY;
		break;
	case VLNote::kHalf:
		head = [self musicElement:kMusicHalfRest];
		p.y	+= kHalfRestY;
		break;
	case VLNote::kQuarter:
		head = [self musicElement:kMusicQuarterRest];
		p.x -= kNoteX;
		break;
	case VLNote::kEighth:
		head = [self musicElement:kMusicEighthRest];
		p.x -= kNoteX;
		break;
	case VLNote::k16th:
		head = [self musicElement:kMusicSixteenthRest];
		p.x -= kNoteX;
		break;
	case VLNote::k32nd:
		head = [self musicElement:kMusicThirtysecondthRest];
		p.x -= kNoteX;
		break;
	}
	[head compositeToPoint:p
		  operation: NSCompositeSourceOver];
}

- (void) drawTripletBracketFrom:(int)startX to:(int)endX atY:(int)y
{
	static NSDictionary * sTripletFont 	 = nil;
	if (!sTripletFont)
		sTripletFont =
			[[NSDictionary alloc] initWithObjectsAndKeys:
				[NSFont fontWithName: @"Helvetica" size: 12],
                NSFontAttributeName,
				nil];

	NSBezierPath * bz = [NSBezierPath bezierPath];

	[bz moveToPoint: NSMakePoint(startX, y-kTripletH)];
	[bz lineToPoint: NSMakePoint(startX, y)];
	[bz lineToPoint: NSMakePoint(endX, y)];
	[bz lineToPoint: NSMakePoint(endX, y-kTripletH)];
	[bz stroke];

	[@"3" drawAtPoint: NSMakePoint((startX+endX)*0.5f, y+kTripletH)
	   withAttributes: sTripletFont];
}

- (void) drawNotesForSystem:(int)system
{
	const int   			kFirstMeas	= fLayout->FirstMeasure(system);
	const VLSong 		*	song 	  	= [self song];
	const VLProperties & 	kProp 	  	= song->Properties(kFirstMeas);
	const VLSystemLayout & 	kLayout 	= (*fLayout)[system];
	const float 			kSystemY 	= [self systemY:system];

	float	tripletStartX;
	float	tripletEndX;
	float	tripletY;
	bool	hasTriplets	= false;

	for (int m = 0; m<kLayout.NumMeasures(); ++m) {
		VLMusicElement accidentals[7];
		memset(accidentals, 0, 7*sizeof(VLMusicElement));
		int	measIdx = m+kFirstMeas;
		if (measIdx >= song->CountMeasures())
			break;
		const VLMeasure	&	measure = song->fMeasures[measIdx];
		VLNoteList 			melody;
		measure.DecomposeNotes(kProp, melody);
		VLFraction 			at(0);
		for (VLNoteList::const_iterator note = melody.begin(); 
			 note != melody.end(); 
			 ++note
		) {
			BOOL	tied  = (note != melody.begin() || m) 
				&& note->fTied & VLNote::kTiedWithPrev;
			int		pitch = note->fPitch;
			NSPoint pos;
			if (pitch != VLNote::kNoPitch) {
				[self drawLedgerLinesInSection:measure.fPropIdx withPitch:pitch 
					  visual:note->fVisual
					  at:NSMakePoint([self noteXInMeasure:measIdx at:at], 
									 kSystemY)];
				VLMusicElement		accidental;
				pos = NSMakePoint([self noteXInMeasure:measIdx at:at],
								  kSystemY+[self noteYInSection:measure.fPropIdx
												 withPitch:pitch 
												 visual:note->fVisual
												 accidental:&accidental]);
				VLMusicElement 	acc = accidental;
				int				step= [self stepInSection:measure.fPropIdx
											withPitch:pitch 	
											visual:note->fVisual];
				if (acc == accidentals[step])
					acc = kMusicNothing; 	// Don't repeat accidentals
				else if (acc == kMusicNothing) 
					if (accidentals[step] == kMusicNatural) // Resume signature
						acc = kProp.fKey < 0 ? kMusicFlat : kMusicSharp;
					else 
						acc = kMusicNatural;
				[self drawNote:note->fVisual & VLNote::kNoteHead
					  at: pos
					  accidental: acc
					  tied:tied];
				accidentals[step] = accidental;
			} else {
				VLMusicElement		accidental;
				pos = NSMakePoint([self noteXInMeasure:measIdx at:at],
								  kSystemY+[self noteYInSection:measure.fPropIdx
												 withPitch:65 visual:0
												 accidental:&accidental]);
				[self drawRest:note->fVisual & VLNote::kNoteHead at: pos];
			}
			if (note->fVisual & VLNote::kTriplet) {
				tripletEndX	= pos.x+kNoteW*0.5f;
				if (hasTriplets) {
					tripletY = std::max(tripletY, pos.y+kLineH);
				} else {
					tripletY 		= std::max(kSystemY+5.0f*kLineH, pos.y+kLineH);
					tripletStartX	= pos.x-kNoteW*0.5f;
					hasTriplets		= true;
				}
			} else if (hasTriplets) {
				[self drawTripletBracketFrom:tripletStartX to:tripletEndX atY:tripletY];
				hasTriplets	= false;
			}

			at	   += note->fDuration;
		}
	}
	if (hasTriplets) {
		[self drawTripletBracketFrom:tripletStartX to:tripletEndX atY:tripletY];
	}
	if (fCursorPitch != VLNote::kNoPitch && fLayout->SystemForMeasure(fCursorMeasure) == system)
		[self drawNoteCursor];
}

@end
