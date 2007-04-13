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
#import "VLDocument.h"

#import "VLModel.h"
#import "VLSoundOut.h"

@implementation VLLyricsEditable

- (VLLyricsEditable *)initWithView:(VLSheetView *)view
							 song:(VLSong *)song 
							stanza:(int)stanza
						  measure:(int)measure
							   at:(VLFract)at
{
	self 		= [super init];
	fView		= view;
	fSong		= song;
	fStanza		= stanza;
	fMeasure	= measure;
	fAt 		= at;
	fNextMeas	= fMeasure;
	fNextAt		= fAt;
	
	VLFraction At = fAt;
	fSong->FindWord(fStanza, fMeasure, At);
	fAt = At;

	[fView setNeedsDisplay: YES];
	
	return self;
}

- (NSString *) stringValue
{
	std::string word = fSong->GetWord(fStanza, fMeasure, fAt);
	return [NSString stringWithUTF8String:word.c_str()];
}

- (void) setStringValue:(NSString *)val
{
	[[fView document] willChangeSong];
	fSong->SetWord(fStanza, fMeasure, fAt, [val UTF8String], &fNextMeas, &fNextAt);
	[[fView document] didChangeSong];
}

- (BOOL) validValue:(NSString *)val
{
	return YES;
}

- (void) moveToNext
{
	if (fNextMeas != fMeasure || fNextAt != fAt) {
		fMeasure = fNextMeas;
		VLFraction at = fNextAt;
		fSong->FindWord(fStanza, fMeasure, at);
		fAt	 = at;
	} else {
		VLFraction at = fAt;
		if (!fSong->NextWord(fStanza, fMeasure, at)) {
			fMeasure	= 0;
			at			= 0;
			fSong->FindWord(fStanza, fMeasure, at);
		}
		fAt = at;
	}
	fNextMeas = fMeasure;
	fNextAt	  = fAt;
}

- (void) moveToPrev
{
	VLFraction at = fAt;
	if (!fSong->PrevWord(fStanza, fMeasure, at)) {
		fMeasure = fSong->CountMeasures()-1;
		at		 = fSong->fProperties.front().fTime;
		fSong->PrevWord(fStanza, fMeasure, at);
	}
	fAt = at;
	fNextMeas = fMeasure;
	fNextAt	  = fAt;
}

- (void) highlightCursor
{
	[fView highlightLyricsInStanza:fStanza measure:fMeasure at:fAt];
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
			stanza:fCursorStanza
			measure:fCursorMeasure
			at:fCursorAt];
	[self setEditTarget:e];
	[fFieldEditor selectText:self];
}

- (void) highlightLyricsInStanza:(size_t)stanza measure:(int)measure at:(VLFraction)at
{
}

@end
