//
//  VLSheetViewLyrics.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 1/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLSheetView.h"
#import "VLSheetViewLyrics.h"
#import "VLSheetViewInternal.h"

#import "VLModel.h"
#import "VLSoundOut.h"

@implementation VLLyricsEditable

- (VLLyricsEditable *)initWithView:(VLSheetView *)view
							 song:(VLSong *)song 
						  measure:(int)measure
							   at:(VLFract)at
{
	self 	= [super init];
	fView	= view;
	fSong	= song;
	fMeasure= measure;
	fAt		= at;
	
	[fView setNeedsDisplay: YES];
	
	return self;
}

- (NSString *) stringValue
{
}

- (void) setStringValue:(NSString *)val
{
}

- (BOOL) validValue:(NSString *)val
{
	return YES;
}

- (void) moveToNext
{	
}

- (void) moveToPrev
{
}

- (void) highlightCursor
{
	[fView highlightLyricsInMeasure:fMeasure at:fAt];
}

@end

@implementation VLSheetView (Lyrics)

- (void) drawLyricsForSystem:(int)system stanza:(size_t)stanza
{
	static NSDictionary * sLyricsFont 	 = nil;
	if (!sLyricsFont)
		sLyricsFont =
			[[NSDictionary alloc] initWithObjectsAndKeys:
				[NSFont fontWithName: @"Helvetica" size: 12],
                NSFontAttributeName,
				nil];

	const VLSong * 	song 		= [self song];
	const float 	kSystemY	= [self systemY:system];
	
	//
	// Build new list
	//
	for (int m = 0; m<fMeasPerSystem; ++m) {
		int	measIdx = m+system*fMeasPerSystem;
		if (measIdx >= song->CountMeasures())
			break;
		const VLMeasure		measure = song->fMeasures[measIdx];
		const VLNoteList &	notes	= measure.fMelody;
		VLFraction at(0);
		for (VLNoteList::const_iterator note = notes.begin();
			 note != notes.end();
			 ++note
		) {
			if (note->fLyrics.size() < stanza 
             || !note->fLyrics[stanza-1].fText.size()
			) {
				;
			} else {
				NSString * syll 	= 
					[NSString stringWithUTF8String:
								  note->fLyrics[stanza-1].fText.c_str()];
				NSSize		sz			= 
					[syll sizeWithAttributes:sLyricsFont];
				NSPoint 	syllLoc  	=
					NSMakePoint(fClefKeyW+(m+at)*fMeasureW
							  + 0.5f*(kNoteW-sz.width), 
								kSystemY+kLyricsY-stanza*kLyricsH);
				if (note->fLyrics[stanza-1].fKind & VLSyllable::kHasNext)
					syll = [syll stringByAppendingString:@" -"];
				[syll drawAtPoint:syllLoc withAttributes:sLyricsFont];
			}
			at += note->fDuration;
		}
	}
}

- (void) editLyrics
{
	VLEditable * e	= 
		[[VLLyricsEditable alloc]
			initWithView:self
			song:[self song]
			measure:fCursorMeasure
			at:fCursorAt];
	[self setEditTarget:e];
	[fFieldEditor selectText:self];
}

- (void) highlightLyricsInMeasure:(int)measure at:(VLFraction)at stanza:(size_t)stanza
{
	const VLProperties & 	prop = [self song]->fProperties.front();
	const float 	   	kSystemY = [self systemY:measure / fMeasPerSystem];
	NSRect 				r 	   	 =
		NSMakeRect([self noteXInMeasure:measure at:at]-kNoteW*0.5f,
				   kSystemY+kChordY, prop.fDivisions*kNoteW, kChordH);
	[[NSColor colorWithCalibratedWhite:0.8f alpha:1.0f] setFill];
	NSRectFillUsingOperation(r, NSCompositePlusDarker);
}

@end
