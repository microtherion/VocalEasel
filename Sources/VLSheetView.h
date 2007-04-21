//
//  VLSheetView.h
//  Vocalese
//
//  Created by Matthias Neeracher on 12/17/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "VLModel.h"

@class VLDocument;

enum VLMusicElement {
	kMusicNothing = 0,
	kMusicGClef = 0,
	kMusicFlat,
	kMusicSharp,
	kMusicNatural,
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
	kMusicRestCursor,
	kMusicKillCursor,
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

@class VLEditable;

@interface VLSheetView : NSView {
	NSImage **			fMusic;
	VLRecalc			fNeedsRecalc;
	char				fClickMode;
	float				fClefKeyW;
	float				fMeasureW;
	int 				fGroups; 
	int 				fQuarterBeats;
	int 				fDivPerGroup;
	int					fMeasPerSystem;
	int					fNumSystems;
	float				fDisplayScale;
	NSPoint				fLastNoteCenter;
	NSTrackingRectTag	fCursorTracking;
	VLRegion			fCursorRegion;
	int		  			fCursorMeasure;
	VLFract 			fCursorAt;
	int					fCursorPitch;
	int					fCursorActualPitch;
	VLMusicElement 		fCursorAccidental;
	size_t				fCursorStanza;
	int					fSelStart;
	int					fSelEnd;
	int 				fNumTopLedgers;
	int					fNumBotLedgers;
	int					fNumStanzas;
	size_t				fVolta;
	size_t				fVoltaOK;

	IBOutlet id			fFieldEditor;
	IBOutlet id			fRepeatSheet;
	IBOutlet id			fEndingSheet;
	IBOutlet id			fDisplaySheet;
	IBOutlet id			fRepeatMsg;
	IBOutlet id			fEndingMsg;
	IBOutlet id			fGrooveMenu;
}

- (IBAction) setKey:(id)sender;
- (IBAction) setTime:(id)sender;
- (IBAction) setDivisions:(id)sender;
- (IBAction) hideFieldEditor:(id)sender;
- (IBAction) endSheetWithButton:(id)sender;
- (IBAction) selectGroove:(id)sender;
- (IBAction) editDisplayOptions:(id)sender;

- (VLDocument *) document;
- (VLSong *) song;
- (NSImage *) musicElement:(VLMusicElement)elt;

- (int) stepWithPitch:(int)pitch;
- (float) systemY:(int)system;
- (float) noteYWithPitch:(int)pitch accidental:(VLMusicElement*)accidental;
- (float) noteYInMeasure:(int)measure withPitch:(int)pitch accidental:(VLMusicElement*)accidental;
- (float) noteXInMeasure:(int)measure at:(VLFraction)at;

- (void) scrollMeasureToVisible:(int)measure;

- (void) mouseMoved:(NSEvent *)event;
- (void) mouseDown:(NSEvent *)event;
- (void) mouseEntered:(NSEvent *)event;
- (void) mouseExited:(NSEvent *)event;

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor;

- (VLEditable *) editTarget;
- (void) setEditTarget:(VLEditable *)editable;
- (VLRegion) findRegionForEvent:(NSEvent *) event;

- (void) setGroove:(NSString *)groove;
- (void) setGrooveMenu:(NSString *)groove;

@end

// Local Variables:
// mode:ObjC
// End:
