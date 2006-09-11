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

- (void) mouseMoved:(NSEvent *)event
{
   	if ([event modifierFlags] & NSAlphaShiftKeyMask)
		return; // Keyboard mode, ignore mouse
	const VLProperties & 	prop = [self song]->fProperties.front();
	NSPoint loc 	= [event locationInWindow];
	loc 			= [self convertPoint:loc fromView:nil];

	loc.x	   	   -= noteRect.origin.x;
	int measure 	= static_cast<int>(loc.x / measureW)+firstMeasure;
	loc.x	   	   -= (measure-firstMeasure)*measureW;
	int group	  	= static_cast<int>(loc.x / ((divPerGroup+1)*kNoteW));
	loc.x		   -= group*(divPerGroup+1)*kNoteW;
	int div			= static_cast<int>(roundf(loc.x / kNoteW))-1;
	div				= std::min(std::max(div, 0), divPerGroup-1);
	VLFraction at(div+group*divPerGroup, 4*prop.fDivisions);

	loc.y		   -= noteRect.origin.y;
	int semi		= static_cast<int>(roundf(loc.y / (0.5f*kLineH)));
	int pitch 		= sSemiToPitch[semi];

	[self setNoteCursorMeasure:measure at:at pitch:pitch];
}

- (void) addNoteAtCursor:(BOOL)isRest
{	
	if (noteCursorMeasure > -1) {
		VLNote	newNote(1, !isRest ? noteCursorPitch : VLNote::kNoPitch);

		[self song]->AddNote(newNote, noteCursorMeasure, noteCursorAt);

		[self setNeedsDisplay:YES];

		VLSoundOut::Instance()->PlayNote(newNote);
	}
}

- (void) mouseDown:(NSEvent *)event
{
	[self mouseMoved:event];
	[self addNoteAtCursor: ([event modifierFlags] & NSShiftKeyMask) != 0];
}

- (void) mouseEntered:(NSEvent *)event
{
	[[self window] setAcceptsMouseMovedEvents:YES];
	[self mouseMoved:event];
}

- (void) mouseExited:(NSEvent *)event
{
	[[self window] setAcceptsMouseMovedEvents:NO];
   	if (!([event modifierFlags] & NSAlphaShiftKeyMask))
		[self hideNoteCursor];
}

- (void) startKeyboardCursor
{
	if (noteCursorMeasure < 0) {
		noteCursorMeasure	= firstMeasure;
		noteCursorPitch		= VLNote::kMiddleC;
		noteCursorAt		= VLFraction(0);
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
		VLSoundOut::Instance()->PlayNote(VLNote(1, noteCursorPitch));
		break;
	}
}

- (void) hideNoteCursor
{
	noteCursorMeasure = -1;
	[self setNeedsDisplay:YES];
}

- (void) drawNoteCursor
{
	NSPoint note = 
		NSMakePoint([self noteXInMeasure:noteCursorMeasure at:noteCursorAt],
					[self noteYWithPitch:noteCursorPitch]);
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
			NSMakePoint(0.5f*(lastNoteCenter.x+c.x),
						0.5f*(lastNoteCenter.y+c.y));
		NSPoint dir = NSMakePoint(c.y-mid.y, c.x-mid.x);
		float   n   = dir.x*dir.x+dir.y*dir.y;
		float 	r	= (kTieDepth*kTieDepth+n) / (2.0f*kTieDepth);
		float   l	= (r-kTieDepth) / sqrtf(n);
		mid.x      += dir.x*l;
		mid.y      += dir.y*l;
		float a1	= atan2(lastNoteCenter.y-mid.y, lastNoteCenter.x-mid.x);
		float a2	= atan2(c.y-mid.y, c.x-mid.x);
		NSBezierPath * bz = [NSBezierPath bezierPath];		
		[bz appendBezierPathWithArcWithCenter:mid radius:r
			startAngle:a1*180.0f/M_PI endAngle:a2*180.0f/M_PI];
		[bz stroke];
	}
	lastNoteCenter	= c;
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

- (void) drawNotes
{
	const VLSong 		*	song = [self song];
	const VLProperties & 	prop = song->fProperties.front();
	BOOL 					swing= !(prop.fDivisions % 3);		// In swing mode?
	VLFraction				swung(3, prop.fDivisions*8, true);	// Which notes to swing
	VLFraction				swingGrid(2*swung);					// Alignment of swing notes

	for (int m = 0; m<visibleMeasures; ++m) {
 		int 				measIdx = m+firstMeasure;
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
							[self noteXInMeasure:measIdx at:at],
							[self noteYWithPitch:pitch])
						tied:!first];
				else 
					[self drawRest:noteDur 
						at: NSMakePoint(
							[self noteXInMeasure:measIdx at:at],
							[self noteYWithPitch:65])];
				dur	   -= partialDur;
				at	   += partialDur;
				first	= NO;
			}
		}
	}
	if (noteCursorMeasure > -1)
		[self drawNoteCursor];
}

- (void) setNoteCursorMeasure:(int)measure at:(VLFraction)at pitch:(int)pitch
{
	if (measure != noteCursorMeasure || at != noteCursorAt
	 || pitch != noteCursorPitch
	) {
		noteCursorMeasure 	= measure;
		noteCursorAt	  	= at;
		noteCursorPitch		= pitch;

		[self setNeedsDisplay:YES];
	}
}

@end
