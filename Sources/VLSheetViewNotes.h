//
// File: VLSheetViewNotes.h - Melody editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLSheetView (Notes)

- (void) drawNotesForSystem:(int)system;
- (void) addNoteAtCursor;
- (void) startKeyboardCursor;
- (void) drawNoteCursor:(int)pitch inMeasure:(size_t)measure at:(VLFract)at;

@end

// Local Variables:
// mode:ObjC
// End:
