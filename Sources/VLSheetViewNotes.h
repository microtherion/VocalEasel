//
//  VLSheetViewNotes.h
//  Vocalese
//
//  Created by Matthias Neeracher on 1/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VLSheetView (Notes)

- (void) mouseMoved:(NSEvent *)event;
- (void) mouseDown:(NSEvent *)event;
- (void) mouseEntered:(NSEvent *)event;
- (void) mouseExited:(NSEvent *)event;

- (void) drawNotes;

- (void) setNoteCursorMeasure:(int)measure at:(VLFraction)at pitch:(int)pitch;
- (void) hideNoteCursor;

@end
