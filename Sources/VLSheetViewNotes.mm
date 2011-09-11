//
// File: VLSheetViewNotes.mm - Melody editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#import "VLSheetView.h"
#import "VLSheetViewNotes.h"
#import "VLSheetViewInternal.h"
#import "VLDocument.h"
#import "VLSoundOut.h"
#import "VLPitchGrid.h"

#include <algorithm>

@implementation VLSheetView (Notes)

- (void) addNoteAtCursor
{	
	if (fCursorLocation.fMeasure > -1 && fCursorVertPos != kCursorNoPitch) {
		[[self document] willChangeSong];
		if (fCursorVisual == kCursorExtend) {
			VLNote oldNote = [self song]->ExtendNote(fCursorLocation);
			VLSoundOut::Instance()->PlayNote(oldNote);
		} else if (fClickMode == 'k') {
			[self song]->DelNote(fCursorLocation);
		} else {
            int pitch   = VLNote::kNoPitch;
            if (fClickMode == ' ')
                pitch = VLGridToPitch(fCursorVertPos, fCursorVisual, 
                                      [self song]->Properties(fCursorLocation.fMeasure).fKey);
            VLNote	newNote(1, pitch, fCursorVisual & ~kCursorFlagsMask);
			[self song]->AddNote(VLLyricsNote(newNote), fCursorLocation);
			VLSoundOut::Instance()->PlayNote(newNote);
        }
        fClickMode = ' ';
		[[self document] didChangeSong];
	}
}

- (void) drawLedgerLines:(int)vertPos at:(NSPoint)p
{
	p.x        += kLedgerX;
    
    int step = (vertPos-2) / 2;
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

- (void) drawLedgerLinesInSection:(int)section withPitch:(int)pitch visual:(uint16_t)visual at:(NSPoint)p
{
    [self drawLedgerLines:[self gridInSection:section withPitch:pitch visual:visual] at:p];
}

- (void) drawNoteCursor:(int)vertPos at:(VLLocation)at
                 visual:(uint16_t)visual mode:(char)mode
{
	int 			cursorX;
	int				cursorY;
	VLMusicElement	cursorElt;
    VLMusicElement  accidental = mode ? [self accidentalForVisual:visual] : kMusicNothing;
	
	cursorX = [self noteXAt:at];
	if (visual == kCursorExtend) {
		cursorY 	= [self noteYInMeasure:at.fMeasure withGrid:vertPos];
		cursorElt	= kMusicExtendCursor;
	} else {
		switch (mode) {
		default:
            cursorY 	= [self noteYInMeasure:at.fMeasure withGrid:vertPos] - kNoteY;
            [self drawLedgerLines:vertPos at:NSMakePoint(cursorX, 
                [self systemY:fLayout->SystemForMeasure(at.fMeasure)])];
			cursorElt 	= kMusicNoteCursor;
			break;
		case 'r':
            cursorY 	= [self noteYInMeasure:at.fMeasure withGrid:3];
			cursorElt	= kMusicRestCursor;
			break;
		case 'k':
            cursorY 	= [self noteYInMeasure:at.fMeasure withGrid:vertPos] - kNoteY;
			cursorElt	= kMusicKillCursor;
			break;
		}
    }
	
	NSPoint	xy = NSMakePoint(cursorX-kNoteX, cursorY);
	[[self musicElement:cursorElt] 
		compositeToPoint:xy
		operation: NSCompositeSourceOver];
    
	if (accidental) {
		xy.y               += kNoteY;
        (int &)accidental  += kMusicFlatCursor-kMusicFlat;
		switch (accidental) {
		case kMusicFlatCursor:
			xy.x	+= kFlatW;
			xy.y	+= kFlatY;
			break;
		case kMusicSharpCursor:
			xy.x	+= kSharpW;
			xy.y	+= kSharpY;
			break;
        case kMusic2FlatCursor:
            xy.x	+= k2FlatW;
            xy.y	+= k2FlatY;
            break;
        case kMusic2SharpCursor:
            xy.x	+= k2SharpW;
            xy.y	+= k2SharpY;
            break;
		default:
			xy.x	+= kNaturalW;
			xy.y	+= kNaturalY;
			break;
		}
		[[self musicElement:accidental] 
			compositeToPoint:xy
			operation: NSCompositeSourceOver];
	}
}

- (void) drawNoteCursor:(int)vertPos at:(VLLocation)at visual:(uint16_t)visual
{
    [self drawNoteCursor:vertPos at:at visual:visual mode:0];
}

- (void) drawNoteCursor
{
	[self drawNoteCursor:fCursorVertPos at:fCursorLocation visual:fCursorVisual mode:fClickMode];
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
	switch (visual & VLNote::kNoteHeadMask) {
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
        case kMusic2Sharp:
            at.x	+= k2SharpW;
            at.y	+= k2SharpY;
            break;
        case kMusic2Flat:
            at.x	+= k2FlatW;
            at.y	+= k2FlatY;
            break;
		case kMusicNatural:
			at.x	+= kNaturalW;
			at.y	+= kNaturalY;
			break;
        default:
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

- (void) drawTuplet:(uint16_t)tuplet bracketFrom:(int)startX to:(int)endX atY:(int)y
{
	static NSDictionary * sTripletFont 	 = nil;
	if (!sTripletFont)
		sTripletFont =
			[[NSDictionary alloc] initWithObjectsAndKeys:
				[NSFont fontWithName: @"Helvetica" size: 12],
                NSFontAttributeName,
				nil];

	NSBezierPath * bz = [NSBezierPath bezierPath];

	[bz moveToPoint: NSMakePoint(startX, y-kTupletH)];
	[bz lineToPoint: NSMakePoint(startX, y)];
	[bz lineToPoint: NSMakePoint(endX, y)];
	[bz lineToPoint: NSMakePoint(endX, y-kTupletH)];
	[bz stroke];

    NSString * tupletText = tuplet == VLNote::kTriplet ? @"3"
        : [NSString stringWithFormat:@"%d:%d", VLNote::TupletNum(tuplet), VLNote::TupletDenom(tuplet)];
	[tupletText drawAtPoint: NSMakePoint((startX+endX)*0.5f, y+kTupletH)
	   withAttributes: sTripletFont];
}

- (void) drawNotesForSystem:(int)system
{
	const int   			kFirstMeas	= fLayout->FirstMeasure(system);
	const VLSong 		*	song 	  	= [self song];
	const VLProperties & 	kProp 	  	= song->Properties(kFirstMeas);
	const VLSystemLayout & 	kLayout 	= (*fLayout)[system];
	const CGFloat 			kSystemY 	= [self systemY:system];

	for (int m = 0; m<kLayout.NumMeasures(); ++m) {
		VLVisualFilter  filterVisuals(kProp.fKey);
		int	measIdx = m+kFirstMeas;
		if (measIdx >= song->CountMeasures())
			break;
		const VLMeasure	&	measure = song->fMeasures[measIdx];
		VLNoteList 			melody;
		measure.DecomposeNotes(kProp, melody);
		VLLocation 			at  = {measIdx, VLFraction(0)};
        float               tupletStartX;
        float               tupletEndX;
        CGFloat             tupletY;
        int                 inTuplet	= 0;
        uint16_t            tuplet;
        VLFraction          tupletDur;
        
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
					  at:NSMakePoint([self noteXAt:at], 
									 kSystemY)];
                uint16_t    visual  = VLPitchAccidental(note->fPitch, note->fVisual, kProp.fKey);
				pos                 = 
                    NSMakePoint([self noteXAt:at],
                                kSystemY+[self noteYInSection:measure.fPropIdx
                                                    withPitch:pitch visual:&visual]);
				int			step    = [self gridInSection:measure.fPropIdx
                                                withPitch:pitch visual:note->fVisual];
				[self drawNote:note->fVisual & VLNote::kNoteHeadMask
					  at: pos
					  accidental:[self accidentalForVisual:filterVisuals(step, visual)]
					  tied:tied];
			} else {
				pos = NSMakePoint([self noteXAt:at],
								  kSystemY+[self noteYInSection:measure.fPropIdx withPitch:65]);
				[self drawRest:note->fVisual & VLNote::kNoteHeadMask at: pos];
			}
			if (uint16_t newTuplet = note->fVisual & VLNote::kTupletMask) {
				tupletEndX	= pos.x+kNoteW*0.5f;
				if (inTuplet && newTuplet == tuplet) {
					tupletY = std::max(tupletY, pos.y+kLineH);
 				} else {
                    if (inTuplet)
                        [self drawTuplet:tuplet bracketFrom:tupletStartX to:tupletEndX atY:tupletY];                        
					tupletY 		= std::max(kSystemY+5.0f*kLineH, pos.y+kLineH);
					tupletStartX	= pos.x-kNoteW*0.5f;
                    tuplet          = newTuplet;
                    tupletDur       = 0;
                    inTuplet        = 0;
				}
                ++inTuplet;
                tupletDur   += note->fDuration / VLNote::TupletDenom(tuplet);
                if (tuplet == VLNote::kTriplet ? (tupletDur.fNum == 1 && !(tupletDur.fDenom & (tupletDur.fDenom-1)))
                    : inTuplet == VLNote::TupletNum(tuplet)
                ) {
                    //
                    // Tuplet adds up to power of two fraction
                    //
                    [self drawTuplet:tuplet bracketFrom:tupletStartX to:tupletEndX atY:tupletY];
                    inTuplet = 0;
                }
			} else if (inTuplet) {
				[self drawTuplet:tuplet bracketFrom:tupletStartX to:tupletEndX atY:tupletY];
				inTuplet    = 0;
			}

			at.fAt  = at.fAt+note->fDuration;
		}
        if (inTuplet)
            [self drawTuplet:tuplet bracketFrom:tupletStartX to:tupletEndX atY:tupletY];
	}
	if (fCursorRegion == kRegionNote && fLayout->SystemForMeasure(fCursorLocation.fMeasure) == system)
		[self drawNoteCursor];
}

@end
