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
	kMusicGClef,
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
	kMusicElements
};

enum VLRegion {
	kRegionNowhere,
	kRegionNote,
	kRegionChord,
	kRegionLyrics
};

@interface VLSheetView : NSView {
	BOOL				fNeedsRecalc;
	BOOL				fIsRest;
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

	BOOL				fShowFieldEditor;
	IBOutlet id			fFieldEditor;
}

- (IBAction) setKey:(id)sender;
- (IBAction) setTime:(id)sender;
- (IBAction) setDivisions:(id)sender;
- (IBAction) hideFieldEditor:(id)sender;

- (VLDocument *) document;
- (VLSong *) song;
- (NSImage *) musicElement:(VLMusicElement)elt;

- (float) systemY:(int)system;
- (float) noteYWithPitch:(int)pitch;
- (float) noteYInMeasure:(int)measure withPitch:(int)pitch;
- (float) noteXInMeasure:(int)measure at:(VLFraction)at;

- (void) mouseMoved:(NSEvent *)event;
- (void) mouseDown:(NSEvent *)event;
- (void) mouseEntered:(NSEvent *)event;
- (void) mouseExited:(NSEvent *)event;

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor;

@end

// Local Variables:
// mode:ObjC
// End:
