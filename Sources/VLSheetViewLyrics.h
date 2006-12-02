//
//  VLSheetViewLyrics.h
//  Vocalese
//
//  Created by Matthias Neeracher on 1/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLSheetWindow.h"

@interface VLLyricsEditable : VLEditable {
	VLSheetView *			fView;
	VLSong *				fSong;
	int						fMeasure;
	VLFract					fAt;
}

- (VLLyricsEditable *)initWithView:(VLSheetView *)view
							 song:(VLSong *)song 
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
- (void) highlightLyricsInMeasure:(int)measure at:(VLFraction)at stanza:(size_t)stanza;

@end

// Local Variables:
// mode:ObjC
// End:
