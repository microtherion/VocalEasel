//
//  VLSheetViewLyrics.h
//  Vocalese
//
//  Created by Matthias Neeracher on 1/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLSheetWindow.h"

@interface VLLyricsEditable : VLEditable {
	VLSheetView *	fView;
	VLSong * 		fSong;
	size_t 			fStanza;
	size_t 			fMeasure;
	VLFraction 		fAt;
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

@end

// Local Variables:
// mode:ObjC
// End:
