//
// File: VLSheetViewNotes.h - Melody editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLSheetView (Notes)

- (void) drawNotesForSystem:(int)system;
- (void) addNoteAtCursor;
- (void) drawNoteCursor:(int)vertPos at:(VLLocation)at visual:(uint16_t)visual;
- (void) playNoteAtCursor;
- (void) moveCursorToNextNote;
- (void) moveCursorToPrevNote;

@end

// Local Variables:
// mode:ObjC
// End:
