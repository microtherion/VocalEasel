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
		VLNote	newNote(1, !fIsRest ? fCursorPitch : VLNote::kNoPitch);

		[self song]->AddNote(newNote, fCursorMeasure, fCursorAt);

		[self setNeedsDisplay:YES];

		VLSoundOut::Instance()->PlayNote(newNote);

		fIsRest	= NO;
	}
}

- (void) startKeyboardCursor
{
	if (fCursorMeasure < 0) {
		fCursorMeasure	= 0;
		fCursorPitch	= VLNote::kMiddleC;
		fCursorAt		= VLFraction(0);
	}
}

- (void) drawNoteCursor
{
	NSPoint note = 
		NSMakePoint([self noteXInMeasure:fCursorMeasure at:fCursorAt],
					[self noteYInMeasure:fCursorMeasure withPitch:fCursorPitch]);
	NSRect 	noteCursorRect =
		NSMakeRect(note.x-kNoteX, note.y-kNoteY, 2.0f*kNoteX, 2.0f*kNoteY);
	[[self musicElement:kMusicNoteCursor] 
		compositeToPoint:NSMakePoint(note.x-kNoteX, note.y-kNoteY)
		operation: NSCompositeSourceOver];
}

- (void) drawNote:(VLFraction)dur at:(NSPoint)p tied:(BOOL)tied
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
	BOOL 					swing= !(prop.fDivisions % 3);		// In swing mode?
	VLFraction				swung(3, prop.fDivisions*8, true);	// Which notes to swing
	VLFraction				swingGrid(2*swung);					// Alignment of swing notes

	float kSystemY = [self systemY:system];
	for (int m = 0; m<fMeasPerSystem; ++m) {
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
				measure.fProperties->PartialNote(at, dur, &partialDur);
				
				BOOL triplet = !(partialDur.fDenom % 3);
				VLFraction noteDur(1); // Visual value of note
				
				if (triplet) {
					if (swing) {	// Swing 8ths / 16ths are written as straight 8ths	
						if (partialDur == 4*swung/3 && (at % swingGrid) == 0) {	
							noteDur	= swung;
							triplet	= NO;
						} else if (partialDur == 2*swung/3 && ((at+partialDur) % swingGrid) == 0) {
							noteDur	= swung;
							triplet	= NO;
						} else {
							noteDur = 4*partialDur/3;
						}
					} else {
						noteDur = 4*partialDur/3;
					}
				} else {
					noteDur = partialDur;
				}
				if (pitch != VLNote::kNoPitch) 
					[self drawNote:noteDur 
						  at: NSMakePoint(
								[self noteXInMeasure:m at:at],
								kSystemY+[self noteYWithPitch:pitch])
						  tied:!first];
				else 
					[self drawRest:noteDur 
						  at: NSMakePoint(
							    [self noteXInMeasure:m at:at],
								kSystemY+[self noteYWithPitch:65])];
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
