//
// File: VLSheetWindow.h - Control lead sheet editing window
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>

@interface VLEditable : NSObject 
{
}

- (NSString *) stringValue;
- (void) setStringValue:(NSString*)val;
- (BOOL) validValue:(NSString*)val;
- (void) moveToNext;
- (void) moveToPrev;
- (void) highlightCursor;

@end

@class VLSheetView;

@interface VLSheetWindow : NSWindowController <NSToolbarDelegate> {
	IBOutlet VLSheetView *          sheetView;
    IBOutlet NSProgressIndicator *  progressIndicator;
    
	VLEditable *            editTarget;

	int					editNumTopLedgers;
	int					editNumBotLedgers;
	int					editNumStanzas;
}

- (VLEditable *) editTarget;
- (void) setEditTarget:(VLEditable *)editable;
- (void) startAnimation;
- (void) stopAnimation;
- (void) willPlaySequence:(MusicSequence)music;

@end
