//
// File: VLSheetViewChords.h - Chord editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import "VLSheetWindow.h"

@interface VLChordEditable : VLEditable {
	VLSheetView *	fView;
	VLSong *		fSong;
	VLLocation		fSelection;
}

- (VLChordEditable *)initWithView:(VLSheetView *)view
							 song:(VLSong *)song 
							   at:(VLLocation)at;
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
- (void) highlightChord:(VLLocation)at;

@end

// Local Variables:
// mode:ObjC
// End:
