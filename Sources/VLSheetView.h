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
	BOOL				needsRecalc;
	float				clefKeyW;
	float				measureW;
	int 				groups; 
	int 				quarterBeats;
	int 				divPerGroup;
	int					firstMeasure;
	int					lastMeasure;
	int					visibleMeasures;
	NSImageRep *		noteCursorCache;
	NSPoint				noteCursorLocation;
	NSPoint				lastNoteCenter;
	NSRect				noteRect;
	NSTrackingRectTag	noteRectTracker;
	int		  			noteCursorMeasure;
	VLFract 			noteCursorAt;
	int					noteCursorPitch;

	IBOutlet id	chords;
}

- (IBAction) setKey:(id)sender;
- (IBAction) setTime:(id)sender;
- (IBAction) setDivisions:(id)sender;

- (void) setFirstMeasure: (NSNumber *)measure;

- (VLDocument *) document;
- (VLSong *) song;
- (NSImage *) musicElement:(VLMusicElement)elt;

- (float) noteYWithPitch:(int)pitch;
- (float) noteXInMeasure:(int)measure at:(VLFraction)at;

@end

// Local Variables:
// mode:ObjC
// End:
