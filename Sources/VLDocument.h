//
// File: VLDocument.h - VocalEasel document
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#import "VLModel.h"
#import <Cocoa/Cocoa.h>
#import "VLKeyValueUndo.h"

@class VLSheetWindow;

#define VLBIABType      @"VLBIABType"
#define VLNativeType    @"org.aereperennius.vocaleasel-song"
#define VLLilypondType  @"org.lilypond.lilypond-source"
#define VLMusicXMLType  @"VLMusicXMLType"
#define VLMMAType       @"VLMMAType"
#define VLMIDIType      @"public.midi"
#define VLPDFType       @"com.adobe.pdf"
#define VLAIFFType      @"public.aifc-audio"
#define VLMP3Type       @"public.mp3"

enum {
	kVLPlayAccompaniment = 1,
	kVLPlayMelody		 = 2,
	kVLPlayMetronome	 = 4,
	kVLPlayCountIn		 = 8,
	kVLPlayGroovePreview = 32768
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
	float               songTempo;
	float				chordSize;
	float				lyricSize;
	float				staffSize;
    float               topPadding;
    float               titlePadding;
    float               staffPadding;
    float               chordPadding;
    float               lyricPadding;
    int                 playElements;
	NSURL *             tmpURL;
	NSFileWrapper *		vcsWrapper;
	NSMutableDictionary*validTmpFiles;
	int					repeatVolta;
	bool				brandNew;
	bool				hasMusicSequence;
	VLSheetWindow *		sheetWin;
	VLKeyValueUndo*		undo;
	VLKeyValueUndo*		staffMetrics;
	NSRange				previewRange;
	float				playRate;
	float				baseTempo;
}

@property (nonatomic) float songTempo;
@property (nonatomic) int playElements;

- (VLSong *)	song;
- (NSNumber *)	songKey;
- (NSNumber *)  songTime;
- (NSNumber *)  songDivisions;
- (int)			repeatVolta;
- (bool)		brandNew;

- (void) setKey:(int)key transpose:(BOOL)transpose inSections:(NSRange)sections;
- (void) setTimeNum:(int)num denom:(int)denom inSections:(NSRange)sections;
- (void) setDivisions:(int)divisions inSections:(NSRange)sections;
- (void) setGroove:(NSString *)groove inSections:(NSRange)sections; 
- (void) playWithGroove:(NSString *)groove inSections:(NSRange)sections; 
- (void) changeOctave:(BOOL)up inSections:(NSRange)sections;

- (void) setRepeatVolta:(int)repeatVolta;

- (void) playSong;

- (NSURL *)    tmpURL;
- (NSURL *)    workURL;
- (NSString *) baseName;
- (NSURL *)    fileURLWithExtension:(NSString*)extension;
- (void)	   createTmpFileWithExtension:(NSString*)ext ofType:(NSString*)type;
- (NSTask *)   taskWithLaunchPath:(NSString *)path arguments:(NSArray *)args;
- (void)	   changedFileWrapper;
- (void)	   willChangeSong;
- (void)	   didChangeSong;

@end

// Local Variables:
// mode:ObjC
// End:
