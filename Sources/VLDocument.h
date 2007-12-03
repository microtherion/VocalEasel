//
// File: VLDocument.h - VocalEasel document
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
//

#import "VLModel.h"
#import <Cocoa/Cocoa.h>
#import "VLKeyValueUndo.h"

@class VLSheetWindow;
@class VLPDFWindow;
@class VLLogWindow;
@class PDFDocument;

enum {
	kVLPlayAccompaniment = 1,
	kVLPlayMelody		 = 2,
	kVLPlayMetronome	 = 4,
	kVLPlayCountIn		 = 8
};

@interface VLDocument : NSDocument
{
	VLSong *			song;
	NSString *			lilypondTemplate;
	NSString * 			songTitle;
	NSString *			songLyricist;
	NSString *			songComposer;
	NSString *			songArranger;
	NSString *			songGroove;
	NSNumber *			songTempo;
	int					playElements;
	NSString *			tmpPath;
	NSFileWrapper *		vcsWrapper;
	NSMutableArray* 	observers;
	NSMutableDictionary*validTmpFiles;
	int					repeatVolta;
	bool				brandNew;
	VLSheetWindow *		sheetWin;
	VLLogWindow *		logWin;
	VLPDFWindow *		pdfWin;
	VLKeyValueUndo*		undo;
	PDFDocument *		printDoc;
}

- (VLSong *)	song;
- (NSNumber *)	songKey;
- (NSNumber *)  songTime;
- (NSNumber *)  songDivisions;
- (int)			repeatVolta;
- (bool)		brandNew;

- (void)		setKey:(int)key transpose:(BOOL)transpose;
- (void)		setTimeNum:(int)num denom:(int)denom;
- (void)		setDivisions:(int)divisions;
- (void) 		setRepeatVolta:(int)repeatVolta;

- (IBAction) showOutput:(id)sender;
- (IBAction) showLog:(id)sender;
- (IBAction) play:(id)sender;
- (IBAction) stop:(id)sender;
- (IBAction) playStop:(id)sender;
- (IBAction) togglePlayElements:(id)sender;
- (IBAction) playStop:(id)sender;

- (NSString *) tmpPath;
- (NSString *) workPath;
- (NSString *) baseName;
- (NSURL *)    fileURLWithExtension:(NSString*)extension;
- (void)	   createTmpFileWithExtension:(NSString*)ext ofType:(NSString*)type;
- (NSTask *)   taskWithLaunchPath:(NSString *)path arguments:(NSArray *)args;
- (void)	   changedFileWrapper;
- (void)	   willChangeSong;
- (void)	   didChangeSong;
- (void)	   addObserver:(id)observer;
- (VLLogWindow *)logWin;
- (void)	   playWithGroove:(NSString *)groove;

@end

// Local Variables:
// mode:ObjC
// End:
