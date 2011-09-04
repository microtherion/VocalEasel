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
@class VLLogWindow;
@class VLPDFWindow;

@interface VLSheetWindow : NSWindowController <NSToolbarDelegate> {
	IBOutlet VLSheetView *          sheetView;
    IBOutlet NSProgressIndicator *  progressIndicator;
    IBOutlet VLLogWindow *          logWin;
	IBOutlet VLPDFWindow *          pdfWin;

    
	VLEditable *            editTarget;

	int					editNumTopLedgers;
	int					editNumBotLedgers;
	int					editNumStanzas;
}

@property (nonatomic,readonly) VLLogWindow * logWin;

- (IBAction) togglePlayElements:(id)sender;
- (IBAction) showOutput:(id)sender;

- (VLEditable *) editTarget;
- (void) setEditTarget:(VLEditable *)editable;
- (void) startAnimation;
- (void) stopAnimation;
- (void) willPlaySequence:(MusicSequence)music;
- (void) showLogAndBeep;

@end
