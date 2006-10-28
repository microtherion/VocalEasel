//
//  VLSheetViewChords.h
//  Vocalese
//
//  Created by Matthias Neeracher on 1/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLSheetWindow.h"

@interface VLChordEditable : VLEditable {
	VLSheetView *	fView;
	VLSong *		fSong;
	int				fMeasure;
	VLFract			fAt;
}

- (VLChordEditable *)initWithView:(VLSheetView *)view
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

@interface VLSheetView (Chords)

- (void) editChord;
- (void) drawChordsForSystem:(int)system;
- (void) highlightChordInMeasure:(int)measure at:(VLFraction)at;

@end

// Local Variables:
// mode:ObjC
// End:
