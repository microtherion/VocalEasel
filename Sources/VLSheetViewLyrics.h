//
// File: VLSheetViewLyrics.h - Lyrics editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2011 Matthias Neeracher
//

#import "VLSheetWindow.h"

@interface VLLyricsEditable : VLEditable {
	VLSheetView *	fView;
	VLSong * 		fSong;
	size_t 			fStanza;
	VLLocation 		fSelection;
    VLLocation      fAnchor;
	VLLocation		fNext;
    NSString *      fText;
}

- (VLLyricsEditable *)initWithView:(VLSheetView *)view
							 song:(VLSong *)song 
							stanza:(int)stanza
							   at:(VLLocation)at;
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
- (void) highlightLyricsInStanza:(size_t)stanza at:(VLLocation)at;
- (void) highlightTextInStanza:(size_t)stanza start:(VLLocation)start end:(VLLocation)end;

@end

// Local Variables:
// mode:ObjC
// End:
