//
// File: VLSheetViewLyrics.h - Lyrics editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import "VLSheetWindow.h"

@interface VLLyricsEditable : VLEditable {
	VLSheetView *	fView;
	VLSong * 		fSong;
	size_t 			fStanza;
	size_t 			fMeasure;
	VLFract 		fAt;
	size_t			fNextMeas;
	VLFract			fNextAt;
}

- (VLLyricsEditable *)initWithView:(VLSheetView *)view
							 song:(VLSong *)song 
							stanza:(int)stanza
						  measure:(int)measure
							   at:(VLFract)at;
- (NSString *) stringValue;
- (void) setStringValue:(NSString*)val;
- (BOOL) validValue:(NSString*)val;
- (void) moveToNext;
- (void) moveToPrev;
- (void) highlightCursor;

@end

@interface VLSheetView (Lyrics)

- (void) editLyrics;
- (void) drawLyricsForSystem:(int)system stanza:(size_t)stanza;
- (void) highlightLyricsInStanza:(size_t)stanza measure:(int)measure at:(VLFraction)at;
- (void) highlightTextInStanza:(size_t)stanza measure:(int)measure at:(VLFraction)at one:(BOOL)one;

@end

// Local Variables:
// mode:ObjC
// End:
