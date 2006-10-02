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

@interface VLSheetView : NSView {
	BOOL				fNeedsRecalc;
	float				fClefKeyW;
	float				fMeasureW;
	float				fLineH;
	int 				fGroups; 
	int 				fQuarterBeats;
	int 				fDivPerGroup;
	int					fMeasPerSystem;
	int					fNumSystems;
	float				fDisplayScale;
	NSImageRep *		fNoteCursorCache;
	NSPoint				fNoteCursorLocation;
	NSPoint				fLastNoteCenter;
	NSRect				fNoteRect;
	NSTrackingRectTag	fNoteRectTracker;
	int		  			fNoteCursorMeasure;
	VLFract 			fNoteCursorAt;
	int					fNoteCursorPitch;
	id					fFieldBeingEdited;

	BOOL				fShowFieldEditor;
	IBOutlet id			fChords;
	IBOutlet id			fFieldEditor;
}

- (IBAction) setKey:(id)sender;
- (IBAction) setTime:(id)sender;
- (IBAction) setDivisions:(id)sender;
- (IBAction) showFieldEditor:(id)sender withAction:(SEL)selector;
- (IBAction) hideFieldEditor:(id)sender;

- (VLDocument *) document;
- (VLSong *) song;
- (NSImage *) musicElement:(VLMusicElement)elt;

- (float) systemY:(int)system;
- (float) noteYWithPitch:(int)pitch;
- (float) noteXInMeasure:(int)measure at:(VLFraction)at;

@end

// Local Variables:
// mode:ObjC
// End:
