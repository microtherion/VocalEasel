//
//  VLSheetViewNotes.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 1/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLSheetView.h"
#import "VLSheetViewNotes.h"
#import "VLSheetViewInternal.h"
#import "VLSoundOut.h"

#include <algorithm>

@implementation VLSheetView (Notes)

- (void) addNoteAtCursor
{	
	if (fCursorMeasure > -1) {
		VLNote	newNote(1, fClickMode==' ' ? fCursorActualPitch : VLNote::kNoPitch);

		[[self document] willChangeSong];
		if (fClickMode == 'k')
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

- (void) drawNoteCursor
{
	int 			cursorX;
	int				cursorY;
	VLMusicElement	accidental;
	VLMusicElement	cursorElt;
	
	cursorX = [self noteXInMeasure:fCursorMeasure at:fCursorAt]-kNoteX;
	switch (fClickMode) {
	default:
		cursorY 	= 
			[self noteYInMeasure:fCursorMeasure 
				  withPitch:fCursorPitch
				  accidental:&accidental]
			-kNoteY;
		cursorElt 	= kMusicNoteCursor;
		break;
	case 'r':
		cursorY 	= [self noteYInMeasure:fCursorMeasure 
							withPitch:65 
							accidental:&accidental];
		cursorElt	= kMusicRestCursor;
		break;
	case 'k':
		cursorY 	= [self noteYInMeasure:fCursorMeasure 
							withPitch:fCursorPitch
							accidental:&accidental];
		cursorElt	= kMusicKillCursor;
		break;
	}
	
	NSPoint	at = NSMakePoint(cursorX, cursorY);
	[[self musicElement:cursorElt] 
		compositeToPoint:at
		operation: NSCompositeSourceOver];
	if (fCursorAccidental) {
		at.y	+= kNoteY;
		switch (cursorElt= fCursorAccidental) {
		case kMusicFlatCursor:
			at.x	+= kFlatW;
			at.y	+= kFlatY;
			break;
		case kMusicSharpCursor:
			at.x	+= kSharpW;
			at.y	+= kSharpY;
			break;
		default:
			at.x	+= kNaturalW;
			at.y	+= kNaturalY;
			break;
		}
		[[self musicElement:cursorElt] 
			compositeToPoint:at
			operation: NSCompositeSourceOver];
	}
}

- (void) drawNote:(VLFraction)dur at:(NSPoint)p 
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
	switch (dur.fDenom) {
	case 1:
		head = [self musicElement:kMusicWholeNote];
		break;
	case 2:
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
	if (dur.fDenom > 1) {
		NSBezierPath * bz = [NSBezierPath bezierPath];		
		NSPoint s1 = NSMakePoint(s.x, s.y+kStemH);
		NSImage * flag = nil;	
		switch (dur.fDenom) {
		case 8:
			flag = [self musicElement:kMusicEighthFlag];
			break;
		case 16:
			flag = [self musicElement:kMusicSixteenthFlag];
			s1.y += 5.0f;
			break;
		case 32:
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

- (void) drawRest:(VLFraction)dur at:(NSPoint)p
{
	//
	// Draw rest
	//
	NSImage * head = nil;
	switch (dur.fDenom) {
	case 1:
		head = [self musicElement:kMusicWholeRest];
		p.y	+= kWholeRestY;
		break;
	case 2:
		head = [self musicElement:kMusicHalfRest];
		p.y	+= kHalfRestY;
		break;
	case 4:
		head = [self musicElement:kMusicQuarterRest];
		p.x -= kNoteX;
		break;
	case 8:
		head = [self musicElement:kMusicEighthRest];
		p.x -= kNoteX;
		break;
	case 16:
		head = [self musicElement:kMusicSixteenthRest];
		p.x -= kNoteX;
		break;
	case 32:
		head = [self musicElement:kMusicThirtysecondthRest];
		p.x -= kNoteX;
		break;
	}
	[head compositeToPoint:p
		  operation: NSCompositeSourceOver];
}

- (void) drawNotesForSystem:(int)system
{
	const VLSong 		*	song = [self song];
	const VLProperties & 	prop = song->fProperties.front();

	float kSystemY = [self systemY:system];
	for (int m = 0; m<fMeasPerSystem; ++m) {
		VLMusicElement accidentals[7];
		memset(accidentals, 0, 7*sizeof(VLMusicElement));
		int	measIdx = m+system*fMeasPerSystem;
		if (measIdx >= song->CountMeasures())
			break;
		const VLMeasure		measure = song->fMeasures[measIdx];
		const VLNoteList &	melody	= measure.fMelody;
		VLFraction 			at(0);
		for (VLNoteList::const_iterator note = melody.begin(); 
			 note != melody.end(); 
			 ++note
		) {
			VLFraction 	dur 	= note->fDuration;
			BOOL       	first	= !m || !note->fTied;
			int			pitch	= note->fPitch;
			while (dur > 0) {
				VLFraction partialDur; // Actual value of note drawn
				VLFraction noteDur; 	// Visual value of note
				bool triplet;
				prop.PartialNote(at, dur, &partialDur);
				prop.VisualNote(at, partialDur, &noteDur, &triplet);
				
				if (pitch != VLNote::kNoPitch) {
					VLMusicElement		accidental;
					NSPoint pos = 
						NSMakePoint([self noteXInMeasure:m at:at],
									kSystemY+[self noteYWithPitch:pitch 
												   accidental:&accidental]);
					VLMusicElement 	acc = accidental;
					int				step= [self stepWithPitch:pitch];
					if (acc == accidentals[step])
						acc = kMusicNothing; 	// Don't repeat accidentals
					else if (acc == kMusicNothing) 
						if (accidentals[step] == kMusicNatural) // Resume signature
							acc = prop.fKey < 0 ? kMusicFlat : kMusicSharp;
						else 
							acc = kMusicNatural;
					[self drawNote:noteDur 
						  at: pos
						  accidental: acc
						  tied:!first];
					accidentals[step] = accidental;
				} else {
					VLMusicElement		accidental;
					NSPoint pos = 
						NSMakePoint([self noteXInMeasure:m at:at],
									kSystemY+[self noteYWithPitch:65 
												   accidental:&accidental]);
					[self drawRest:noteDur at: pos];
				}
				dur	   -= partialDur;
				at	   += partialDur;
				first	= NO;
			}
		}
	}
	if (fCursorPitch != VLNote::kNoPitch && fCursorMeasure/fMeasPerSystem == system)
		[self drawNoteCursor];
}

@end
