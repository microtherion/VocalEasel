//
// File: VLSheetWindow.h - Control lead sheet editing window
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2008 Matthias Neeracher
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

@interface VLSheetWindow : NSWindowController <NSToolbarDelegate> {
	VLEditable *	editTarget;

	IBOutlet id 	outputToolItem;
	IBOutlet id 	logToolItem;
	IBOutlet id		playToolItem;
	IBOutlet id		stopToolItem;
	IBOutlet id		fwdToolItem;
	IBOutlet id		bckToolItem;
	IBOutlet id		tobegToolItem;
	IBOutlet id		toendToolItem;
	IBOutlet id		zoomInToolItem;
	IBOutlet id		zoomOutToolItem;
	IBOutlet id		progressToolItem;
	IBOutlet id		displayToolItem;

	IBOutlet id		sheetView;

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
