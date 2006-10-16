//
//  VLSheetViewNotes.h
//  Vocalese
//
//  Created by Matthias Neeracher on 1/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VLSheetView (Notes)

- (void) drawNotesForSystem:(int)system;
- (void) addNoteAtCursor;
- (void) startKeyboardCursor;

@end

// Local Variables:
// mode:ObjC
// End:
