//
// File: VLSheetView.h - Lead sheet editing view
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2018 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>

#import "VLModel.h"
#import "VLLayout.h"
#import "VLKeyValueUndo.h"

@class VLDocument;

enum VLMusicElement {
	kMusicNothing = 0,
	kMusicGClef = 0,
	kMusicFlat,
	kMusicSharp,
	kMusicNatural,
    kMusic2Flat,
    kMusic2Sharp,
	kMusicWholeNote,
	kMusicHalfNote,
	kMusicNote,
	kMusicWholeRest,
	kMusicHalfRest,
	kMusicQuarterRest,
	kMusicEighthRest,
	kMusicSixteenthRest,
	kMusicThirtysecondthRest,
	kMusicEighthFlag,
	kMusicSixteenthFlag,
	kMusicThirtysecondthFlag,
	kMusicNoteCursor,
	kMusicFlatCursor,
	kMusicSharpCursor,
	kMusicNaturalCursor,
    kMusic2FlatCursor,
    kMusic2SharpCursor,
	kMusicRestCursor,
	kMusicKillCursor,
	kMusicExtendCursor,
	kMusicCoda,
	kMusicElements
};

enum VLRegion {
	kRegionNowhere,
	kRegionNote,
	kRegionChord,
	kRegionLyrics,
	kRegionMeasure
};

enum VLRecalc {
	kNoRecalc,
	kRecalc,
	kFirstRecalc
};

enum VLCursorVisual {
    kCursorExtend   = 1<<15,
    kCursorFlagsMask= 0x8000,
    kCursorNoPitch  = -128
};

const uint32_t kNoMeasure = (uint32_t)-1;

@class VLEditable;

@interface VLSheetView : NSView {
	NSImage **			fMusic;
	VLRecalc			fNeedsRecalc;
	char				fClickMode;
	size_t				fLastMeasures;
	float				fDisplayScale;
	NSPoint				fLastNoteCenter;
	NSTrackingRectTag	fCursorTracking;
	VLRegion			fCursorRegion;
	VLLocation          fCursorLocation;
    int                 fCursorVertPos;
    uint16_t            fCursorVisual;
	size_t				fCursorStanza;
	uint32_t			fSelStart;
	uint32_t			fSelEnd;
	int 				fNumTopLedgers;
	int					fNumBotLedgers;
	int					fNumStanzas;
	size_t				fVolta;
	size_t				fVoltaOK;
	VLLayout *			fLayout;
	VLLocation			fHighlightStart;
	VLLocation			fHighlightEnd;
	size_t				fHighlightStanza;
    VLKeyValueUndo *    fUndo;

	IBOutlet id			fFieldEditor;
	IBOutlet id			fRepeatSheet;
	IBOutlet id			fEndingSheet;
	IBOutlet id			fRepeatMsg;
	IBOutlet id			fEndingMsg;
	IBOutlet id			fGrooveMenu;
	IBOutlet id			fKeyMenu;
	IBOutlet id			fTimeMenu;
	IBOutlet id			fDivisionMenu;
    IBOutlet NSMenu    *fNoteActionMenu;
}

@property (nonatomic) int   numTopLedgers;
@property (nonatomic) int   numBotLedgers;
@property (nonatomic) int   numStanzas;

- (IBAction) setKey:(id)sender;
- (IBAction) setTime:(id)sender;
- (IBAction) setDivisions:(id)sender;
- (IBAction) hideFieldEditor:(id)sender;
- (IBAction) endSheetWithButton:(id)sender;
- (IBAction) selectGroove:(id)sender;
- (IBAction) transposeOctave:(id)sender;
- (IBAction) zoomIn: (id) sender;
- (IBAction) zoomOut: (id) sender;

- (VLDocument *) document;
- (VLSong *) song;
- (NSImage *) musicElement:(VLMusicElement)elt;

- (float) systemY:(int)system;
- (int) gridInSection:(int)section withPitch:(int)pitch visual:(uint16_t)visual;
- (float) noteYInGrid:(int)vertPos;
- (float) noteYInSection:(int)section withPitch:(int)pitch visual:(uint16_t *)visual;
- (float) noteYInSection:(int)section withPitch:(int)pitch;
- (VLMusicElement)accidentalForVisual:(uint16_t)visual;
- (float) noteYInMeasure:(int)measure withGrid:(int)vertPos;
- (float) noteXAt:(VLLocation)at;
- (void)  needsRecalculation;

- (void) scrollMeasureToVisible:(int)measure;

- (void) mouseMoved:(NSEvent *)event;
- (void) mouseDown:(NSEvent *)event;
- (void) mouseEntered:(NSEvent *)event;
- (void) mouseExited:(NSEvent *)event;

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor;

- (VLEditable *) editTarget;
- (void) setEditTarget:(VLEditable *)editable;
- (void) updateEditTarget;
- (VLRegion) findRegionForEvent:(NSEvent *) event;

- (void) setGroove:(NSString *)groove;
- (void) playWithGroove:(NSString *)groove;

- (NSColor *)textBackgroundColorForSystem:(int)system;
- (void)removeObservers:(id)target;

@end

@interface NSImage (VLSheetViewDrawing)

- (void) drawAllAtPoint:(NSPoint)p operation:(NSCompositingOperation)op;
- (void) drawAllAtPoint:(NSPoint)p;

@end

// Local Variables:
// mode:ObjC
// End:
