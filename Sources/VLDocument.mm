//
// File: VLDocument.mm - VocalEasel document
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2018 Matthias Neeracher
//

#import "VLDocument.h"
#import "VLXMLDocument.h"
#import "VLLilypondDocument.h"
#import "VLMMADocument.h"
#import "VLMIDIDocument.h"
#import "VLAIFFDocument.h"
#import "VLMP3Document.h"
#import "VLPDFDocument.h"
#import "VLPListDocument.h"
#import "VLPDFWindow.h"
#import "VLLogWindow.h"
#import "VLSheetWindow.h"
#import "VLSoundOut.h"
#import "VLMIDIWriter.h"

#import <Quartz/Quartz.h>

@interface PDFDocument (PDFKitSecretsIKnow)
- (NSPrintOperation *)getPrintOperationForPrintInfo:(NSPrintInfo *)printInfo autoRotate:(BOOL)doRotate;
@end

@interface VLSongWrapper : NSObject {
	VLSong * wrappedSong;
}

+ (VLSongWrapper *)wrapperWithSong:(VLSong *)song;
- (VLSong *)song;

@end

@implementation VLSongWrapper

- (id)initWithSong:(VLSong *)song
{
	if (self = [super init])
		wrappedSong = new VLSong(*song);
	return self;
}

- (void) dealloc
{
	delete wrappedSong;
	
	[super dealloc];
}

+ (VLSongWrapper *)wrapperWithSong:(VLSong *)song
{
	return [[[VLSongWrapper alloc] initWithSong:song] autorelease];
}

- (VLSong *)song
{
	return wrappedSong;
}

@end

@implementation VLDocument

@synthesize songTempo, playElements;

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (id)init
{
    self = [super init];
    if (self) {
		song 				= new VLSong;
		lilypondTemplate	= @"default";
		songTitle			= @"";
		songLyricist		= @"";
		songComposer		= @"";
		songArranger		= @"";
		songGroove			= @"Swing";
		playElements		= kVLPlayAccompaniment|kVLPlayMelody|kVLPlayCountIn;
		songTempo			= 120.0f;
		baseTempo			= 120.0f;
		chordSize			= 6.0f;
		lyricSize			= 0.0f;
		staffSize			= 20.0f;
        topPadding          = 2.0f;
        titlePadding        = 4.0f;
        staffPadding        = 3.0f;
        chordPadding        = 1.5f;
        lyricPadding        = 1.0f;
		sheetWin			= nil;
		tmpURL				= nil;
		vcsWrapper			= nil;
		repeatVolta			= 2;
		brandNew			= true;
		musicSequence       = nil;
		playRate			= 1.0;
		validTmpFiles		= [[NSMutableDictionary alloc] initWithCapacity:10];
		[self setHasUndoManager:YES];
		undo				=
			[[VLKeyValueUndo alloc] initWithOwner:self
				keysAndNames: [NSDictionary dictionaryWithObjectsAndKeys:
					@"", @"songTitle",
					@"", @"songLyricist",
					@"", @"songComposer",
					@"", @"songArranger",
					@"", @"songGroove",
					@"", @"songTempo",
					nil]];
        staffMetrics        =
            [[VLKeyValueUndo alloc] initWithOwner:self
                keysAndNames:[NSDictionary dictionaryWithObjectsAndKeys:
                    @"", @"chordSize",
                    @"", @"lyricSize",
                    @"", @"staffSize",
                    @"", @"topPadding",
                    @"", @"titlePadding",
                    @"", @"staffPadding",
                    @"", @"chordPadding",
                    @"", @"lyricPadding",
                    nil]
                update:^(NSString *keyPath) {
                    [validTmpFiles removeObjectForKey:@"ly"]; 
                    [validTmpFiles removeObjectForKey:@"pdf"]; 
                }];
    }
    return self;
}

- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
	musicSequence   = nil;
	[validTmpFiles removeAllObjects];
	[super updateChangeCount:changeType];
}

- (void) close
{
    VLSoundOut::Instance()->Stop(false);

    [super close];
}

- (void) dealloc
{
	VLSoundOut::Instance()->Stop(false);

	delete song;

	[lilypondTemplate release];
	[songTitle release];
	[songLyricist release];
	[songComposer release];
	[songArranger release];
	[vcsWrapper release];
    [staffMetrics release];
	[undo release];
		
	if (tmpURL) {
		[[NSFileManager defaultManager] removeItemAtURL:tmpURL error:nil];
		[tmpURL release];
	}

	[super dealloc];
}

- (void)makeWindowControllers
{
	sheetWin = [[VLSheetWindow alloc] initWithWindowNibName: @"VLDocument"];
	[self addWindowController: sheetWin];
	[sheetWin setShouldCloseDocument:YES];
	[sheetWin release];
}

- (VLSong *) song
{
	return song;
}

- (void) setSongTitle:(NSString *)newTitle
{
	if (newTitle != songTitle) {
		[songTitle release];
		songTitle = [newTitle retain];
	}
	[[self windowControllers] makeObjectsPerformSelector:
		         @selector(synchronizeWindowTitleWithDocumentName)];
}

- (NSNumber *)	songKey
{
	const VLProperties & prop = song->fProperties.front();

	return [NSNumber numberWithInt: (prop.fKey << 8) | (prop.fMode & 0xFF)];
}

- (void) setKey:(int)key transpose:(BOOL)transpose inSections:(NSRange)sections
{
	[self willChangeSong];
	[self willChangeValueForKey:@"songKey"];
	while (sections.length-- > 0)
		song->ChangeKey(sections.location++, key>>8, key & 0xFF, transpose);
	[self didChangeValueForKey:@"songKey"];
	[self didChangeSong];
}

- (NSNumber *)  songTime
{
	const VLProperties & prop = song->fProperties.front();

	return [NSNumber numberWithInt: (prop.fTime.fNum << 8) | prop.fTime.fDenom];
}

- (void) setTimeNum:(int)num denom:(int)denom inSections:(NSRange)sections
{
	[self willChangeSong];
	[self willChangeValueForKey:@"songTime"];
	while (sections.length-- > 0)
		song->ChangeTime(sections.location++, VLFraction(num, denom));
	[self didChangeValueForKey:@"songTime"];
	[self didChangeSong];
}

- (NSNumber *) songDivisions
{
	const VLProperties & prop = song->fProperties.front();

	return [NSNumber numberWithInt: prop.fDivisions];	
}

- (void) setDivisions:(int)divisions inSections:(NSRange)sections
{
	[self willChangeSong];
	[self willChangeValueForKey:@"songDivisions"];
	while (sections.length-- > 0)
		song->ChangeDivisions(sections.location++, divisions);
	[self didChangeValueForKey:@"songDivisions"];
	[self didChangeSong];
}

- (void) setSongTempo:(float)tempo
{
	if (tempo == songTempo)
		return;
	
	songTempo = tempo;
	if (VLSoundOut::Instance()->Playing()) 
		VLSoundOut::Instance()->SetPlayRate(playRate*tempo/baseTempo);
}

- (void) setGroove:(NSString *)groove inSections:(NSRange)sections
{
	const char * grv = [groove UTF8String];
	[self willChangeSong];
	[self willChangeValueForKey:@"songGroove"];
	while (sections.length-- > 0)
		song->fProperties[sections.location++].fGroove = grv;
	[self didChangeValueForKey:@"songGroove"];
	[self didChangeSong];
}

- (void) changeOctave:(BOOL)up inSections:(NSRange)sections
{
	[self willChangeSong];
	while (sections.length-- > 0)
		song->ChangeOctave(sections.location++, up);
	[self didChangeSong];
}

- (void)setPlayElements:(int)elements
{
    [self willChangeValueForKey:@"playElements"];
    playElements    = elements;
    if (!(playElements & (kVLPlayMelody|kVLPlayAccompaniment)))
        playElements |= kVLPlayAccompaniment;
    if ((playElements & (kVLPlayMelody|kVLPlayGroovePreview)) != kVLPlayMelody)
        VLSoundOut::Instance()->SetMelodyState(VLSoundOut::kMelodyMute);
    else if (!(playElements & (kVLPlayAccompaniment|kVLPlayGroovePreview)))
        VLSoundOut::Instance()->SetMelodyState(VLSoundOut::kMelodySolo);
    else
        VLSoundOut::Instance()->SetMelodyState(VLSoundOut::kMelodyRegular);
    [self didChangeValueForKey:@"playElements"];
}

- (int) repeatVolta
{	
	return repeatVolta;
}

- (bool) brandNew
{
	return brandNew && ![self isDocumentEdited];
}

- (void) setRepeatVolta:(int)volta
{
	repeatVolta = volta;
}

- (NSURL *) tmpURL
{
	if (!tmpURL) {
        NSString * tmpPath = [NSString stringWithFormat:@"/var/tmp/VocalEasel.%08x", self];
		tmpURL = [[NSURL alloc] initFileURLWithPath:tmpPath];
		[[NSFileManager defaultManager] createDirectoryAtURL:tmpURL withIntermediateDirectories:NO attributes:nil error:nil];
	}
	return tmpURL;
}

- (NSURL *) workURL
{
	if (NSURL * url = [self fileURL]) // Prefer our wrapper directory
		return url;
	else
		return [self tmpURL];
}

- (NSString *) baseName
{
	return [[[self workURL] lastPathComponent] stringByDeletingPathExtension];
}

- (NSURL *) fileURLWithExtension:(NSString*)extension
{
    return [[[self workURL] URLByAppendingPathComponent:[self baseName]]
            URLByAppendingPathExtension:extension];
}

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
	NSFileWrapper * preservedVCSWrapper = nil;
	switch (saveOperation) {
	case NSSaveToOperation:
	case NSAutosaveOperation:
		preservedVCSWrapper = vcsWrapper;
		[preservedVCSWrapper retain];
		// Fall through
	case NSSaveAsOperation:
		[vcsWrapper release];
		vcsWrapper = nil;
		// Fall through
	case NSSaveOperation:
		break;
	}
	BOOL res = [super saveToURL:absoluteURL ofType:typeName
					  forSaveOperation:saveOperation error:outError];
	if (!vcsWrapper)
		vcsWrapper = preservedVCSWrapper;
	if ([typeName isEqual:VLNativeType])
		[validTmpFiles removeAllObjects];
	
	return res;
}

- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError
{
	if ([typeName isEqual:VLNativeType]) {
		return [self XMLFileWrapperWithError:outError flat:NO];
	} else if ([typeName isEqual:VLMusicXMLType]) {
		return [self XMLFileWrapperWithError:outError flat:YES];
	} else if ([typeName isEqual:VLLilypondType]) {
		return [self lilypondFileWrapperWithError:outError];
	} else if ([typeName isEqual:VLMMAType]) {
		return [self mmaFileWrapperWithError:outError];
	} else if ([typeName isEqual:VLMIDIType]) {
		return [self midiFileWrapperWithError:outError];
	} else if ([typeName isEqual:VLAIFFType]) {
		return [self aiffFileWrapperWithError:outError];
	} else if ([typeName isEqual:VLMP3Type]) {
		return [self mp3FileWrapperWithError:outError];
	} else if ([typeName isEqual:VLPDFType]) {
		return [self pdfFileWrapperWithError:outError];
	} else {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
								 code:NSPersistentStoreInvalidTypeError
								 userInfo:nil];
		return nil;
	}
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)wrapper ofType:(NSString *)typeName error:(NSError **)outError
{
	brandNew	= false;
	//
	// On opening a document, close all unchanged empty documents
	//
	NSEnumerator * docs = [[[NSDocumentController sharedDocumentController] 
							  documents] objectEnumerator];
	while (VLDocument * doc = [docs nextObject])
		if ([doc brandNew]) 
			[[doc windowControllers] 
				makeObjectsPerformSelector:@selector(close)];

	if ([typeName isEqual:VLNativeType] || [typeName isEqual:VLMusicXMLType]) {
		return [self readFromXMLFileWrapper:wrapper error:outError];
	} else if ([typeName isEqual:VLLilypondType] || [typeName isEqual:VLBIABType]) {
		if ([self readFromFileWrapper:wrapper withFilter:typeName error:outError]) {
			[self setFileURL:nil];
			return YES;
		} else
			return NO;
	} else {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
								 code:NSPersistentStoreInvalidTypeError
								 userInfo:nil];
		return NO;
	}
}

- (void) changedFileWrapper
{
	if (NSURL * url = [self workURL]) {
        NSDate * modDate;
        if ([url getResourceValue:&modDate forKey:NSURLAttributeModificationDateKey error:nil])
			[self setFileModificationDate:modDate];            
    }
}

- (void) createTmpFileWithExtension:(NSString*)ext ofType:(NSString*)type
{
	if (![validTmpFiles objectForKey:ext]) {
		NSError * err;
		if ([self writeToURL:[self fileURLWithExtension:ext] 
				  ofType:type error:&err]
		) {
			[validTmpFiles setObject:type forKey:ext];
			[self changedFileWrapper];
		}
	}
}

- (NSTask *) taskWithLaunchPath:(NSString *)launch arguments:(NSArray *)args;
{
	NSTask *	task	= [[NSTask alloc] init];
	NSString *	path 	= [[self workURL] path];
	NSPipe *	pipe	= [NSPipe pipe];
	
	[task setCurrentDirectoryPath: path];
	[task setStandardOutput: pipe];
	[task setStandardError: pipe];
	[task setArguments: args];
	[task setLaunchPath: launch]; 
	
	[NSThread detachNewThreadSelector:@selector(logFromFileHandle:) toTarget:[sheetWin logWin]
		withObject:[pipe fileHandleForReading]];
		
	return task;
}

- (void) playSong
{
	if (musicSequence) {
		void (^finalizer)() = [sheetWin willPlaySequence:musicSequence];
		VLSoundOut::Instance()->PlaySequence(NULL);
        finalizer();
	} else {
		[self createTmpFileWithExtension:@"mid" ofType:VLMIDIType];

		NewMusicSequence(&musicSequence);

        MusicSequenceFileLoad(musicSequence, (CFURLRef)[self fileURLWithExtension:@"mid"], 
                              kMusicSequenceFile_MIDIType, 0);

		size_t countIn = 0;
		if (playElements & kVLPlayCountIn) 
			switch ([[self songTime] intValue]) {
			case 0x404:
			case 0x304:
			case 0x608:
				countIn = 2;
			}
		VLMIDIWriter annotate(musicSequence, countIn);
		annotate.Visit(*song);
	
		baseTempo			= songTempo;
		void (^finalizer)() = [sheetWin willPlaySequence:musicSequence];
 		VLSoundOut::Instance()->SetPlayRate(playRate);
		VLSoundOut::Instance()->PlaySequence(musicSequence);
        finalizer();
 	}
    [self setPlayElements:[self playElements]];
}

- (void) endSong
{
    musicSequence = nil;
}

- (void) playWithGroove:(NSString *)groove inSections:(NSRange)sections
{
	NSString * savedGroove	= songGroove;
	[validTmpFiles removeObjectForKey:@"mma"]; 
	[validTmpFiles removeObjectForKey:@"mid"]; 
	musicSequence    = nil;
	songGroove	   	 = groove;
	previewRange	 = sections;
	playElements	|= kVLPlayGroovePreview;
	[self playSong];
	playElements	&= ~kVLPlayGroovePreview;
	songGroove		 = savedGroove;
	[validTmpFiles removeObjectForKey:@"mma"]; 
	[validTmpFiles removeObjectForKey:@"mid"]; 
	musicSequence    = nil;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings 
										   error:(NSError **)outError 
{
	[self createTmpFileWithExtension:@"pdf" ofType:VLPDFType];
	PDFDocument * printDoc = [[PDFDocument alloc] initWithURL:[self fileURLWithExtension:@"pdf"]];
    [printDoc autorelease];

    NSPrintOperation *printOperation = [printDoc getPrintOperationForPrintInfo:[self printInfo] autoRotate:NO];

    // Specify that the print operation can run in a separate thread. This will cause the print progress panel to appear as a sheet on the document window.
    [printOperation setCanSpawnSeparateThread:YES];
    
    // Set any print settings that might have been specified in a Print Document Apple event. 
    [[[printOperation printInfo] dictionary] addEntriesFromDictionary:printSettings];
    
    return printOperation;    
}

- (void) willChangeSong
{
	[self willChangeValueForKey:@"song"];
	[[self undoManager] registerUndoWithTarget:self 
						selector:@selector(restoreSong:)
						object:[VLSongWrapper wrapperWithSong:song]];
}

- (void) didChangeSong
{
	[self didChangeValueForKey:@"song"];
	[self updateChangeCount:NSChangeDone];
}

- (void) restoreSong:(VLSongWrapper *)savedSong
{
	[self willChangeSong];
	[self willChangeValueForKey:@"songKey"];
	[self willChangeValueForKey:@"songTime"];
	[self willChangeValueForKey:@"songDivisions"];
	[self willChangeValueForKey:@"songGroove"];
	song->swap(*[savedSong song]);
	[self didChangeValueForKey:@"songKey"];
	[self didChangeValueForKey:@"songTime"];
	[self didChangeValueForKey:@"songDivisions"];
	[self didChangeValueForKey:@"songGroove"];
	[self didChangeSong];
}

- (NSString *) displayName
{
	if ([songTitle isEqual:@""])
		return [super displayName];
	else
		return songTitle;
}

@end

