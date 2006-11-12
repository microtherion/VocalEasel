//
//  MyDocument.h
//  Vocalese
//
//  Created by Matthias Neeracher on 12/17/05.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.
//

#import "VLModel.h"
#import <Cocoa/Cocoa.h>

@class VLSheetWindow;
@class VLPDFWindow;
@class VLLogWindow;

@interface VLDocument : NSDocument
{
	VLSong *		song;
	NSString *		lilypondTemplate;
	NSString * 		songTitle;
	NSString *		songLyricist;
	NSString *		songComposer;
	NSString *		songArranger;
	NSString *		songGroove;
	NSNumber *		songTempo;
	NSString *		tmpPath;

	VLSheetWindow *	sheetWin;
	VLLogWindow *	logWin;
	VLPDFWindow *	pdfWin;
}

- (VLSong *)	song;
- (NSNumber *)	songKey;
- (NSNumber *)  songTime;
- (NSNumber *)  songDivisions;

- (void)		setKey:(int)key transpose:(BOOL)transpose;
- (void)		setTimeNum:(int)num denom:(int)denom;
- (void)		setDivisions:(int)divisions;

- (IBAction) engrave:(id)sender;
- (IBAction) showOutput:(id)sender;
- (IBAction) showLog:(id)sender;

- (NSString *) tmpPath;
- (NSString *) workPath;
- (NSString *) baseName;
- (NSURL *)    fileURLWithExtension:(NSString*)extension;
- (NSTask *)   taskWithLaunchPath:(NSString *)path arguments:(NSArray *)args;

@end

// Local Variables:
// mode:ObjC
// End:
