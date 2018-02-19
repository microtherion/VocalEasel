//
// File: VLSheetViewNotes.h - Melody editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2018 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLSheetView (Notes)

- (void) drawNotesForSystem:(int)system;
- (void) addNoteAtCursor;
- (void) drawNoteCursor:(int)vertPos at:(VLLocation)at visual:(uint16_t)visual;
- (void) playNoteAtCursor;
- (void) moveCursorToNextNote;
- (void) moveCursorToPrevNote;

- (IBAction) tieNoteWithPrev:(id)sender;
- (IBAction) tieNoteWithNext:(id)sender;
- (IBAction) addRest:(id)sender;
- (IBAction) deleteNote:(id)sender;

@end

// Local Variables:
// mode:ObjC
// End:
