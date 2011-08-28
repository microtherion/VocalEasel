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
- (void) drawNoteCursor:(int)vertPos inMeasure:(size_t)measure at:(VLFract)at visual:(uint16_t)visual;

@end

// Local Variables:
// mode:ObjC
// End:
