//
// File: VLDocument.mm - VocalEasel document
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
//

#import "VLDocument.h"
#import "VLXMLDocument.h"
#import "VLLilypondDocument.h"
#import "VLMMADocument.h"
#import "VLMIDIDocument.h"
#import "VLPDFDocument.h"
#import "VLPListDocument.h"
#import "VLPDFWindow.h"
#import "VLLogWindow.h"
#import "VLSheetWindow.h"
#import "VLSoundOut.h"

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
		songTempo			= [[NSNumber numberWithInt:120] retain];
		playElements		= kVLPlayAccompaniment|kVLPlayMelody|kVLPlayCountIn;
		sheetWin			= nil;
		pdfWin				= nil;	
		logWin				= nil;
		tmpPath				= nil;
		vcsWrapper			= nil;
		repeatVolta			= 2;
		brandNew			= true;
		observers			= [[NSMutableArray alloc] init];
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
		printDoc			= nil;
    }
    return self;
}

- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
	[validTmpFiles removeAllObjects];
	[super updateChangeCount:changeType];
}

- (void) addObserver:(id)observer
{
	[observers addObject:observer];
}

- (void) close
{
	[observers makeObjectsPerformSelector:@selector(removeObservers:) withObject:self];
	[observers removeAllObjects];
	[super close];
}

- (void) dealloc
{
	delete song;

	[lilypondTemplate release];
	[songTitle release];
	[songLyricist release];
	[songComposer release];
	[songArranger release];
	[vcsWrapper release];
	[undo release];
	[observers release];
		
	if (tmpPath) {
		[[NSFileManager defaultManager] removeFileAtPath:tmpPath handler:nil];
		[tmpPath release];
	}

	[super dealloc];
}

- (void)removeWindowController:(NSWindowController *)win
{
	if (win == logWin)
		logWin = nil;	
	else if (win == pdfWin)
		pdfWin = nil;
	else if (win == sheetWin)
		sheetWin = nil;

	[super removeWindowController:win];
}

- (VLLogWindow *)logWin
{
	if (!logWin) {
		logWin = [[VLLogWindow alloc] initWithWindowNibName: @"VLLogWindow"];
		[self addWindowController: logWin];
		[logWin release];
	}
	return logWin;
}

- (VLPDFWindow *)pdfWin
{
	if (!pdfWin) {
		pdfWin = [[VLPDFWindow alloc] initWithWindowNibName: @"VLPDFWindow"];
		[self addWindowController: pdfWin];
		[pdfWin release];
	}
	return pdfWin;
}

- (void)makeWindowControllers
{
	sheetWin = [[VLSheetWindow alloc] initWithWindowNibName: @"VLDocument"];
	[self addWindowController: sheetWin];
	[sheetWin setShouldCloseDocument:YES];
	[sheetWin release];
}

- (void)showWindows
{
	[sheetWin showWindow: self];
	if ([pdfWin isWindowLoaded])
		[pdfWin showWindow: self];
	if ([logWin isWindowLoaded])
		[logWin showWindow: self];
}

- (VLSong *) song
{
	return song;
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
	[self willChangeSong];
	while (sections.length-- > 0)
		song->ChangeDivisions(sections.location++, divisions);
	[self didChangeValueForKey:@"songDivisions"];
	[self didChangeSong];
}

- (int) repeatVolta
{	
	return repeatVolta;
}

- (IBAction) togglePlayElements:(id)sender
{
	playElements ^= [sender tag];
	[validTmpFiles removeObjectForKey:@"mma"]; 
	[validTmpFiles removeObjectForKey:@"mid"]; 
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (int tag = [menuItem tag])
		[menuItem setState:(playElements & tag) != 0];

	return YES;
}

- (bool) brandNew
{
	return brandNew && ![self isDocumentEdited];
}

- (void) setRepeatVolta:(int)volta
{
	repeatVolta = volta;
}

- (NSString *) tmpPath
{
	if (!tmpPath) {
		tmpPath = [[NSString alloc] initWithFormat:@"/var/tmp/VocalEasel.%08x",
									self];
		[[NSFileManager defaultManager] createDirectoryAtPath:tmpPath attributes:nil];
	}
	return tmpPath;
}

- (NSString *) workPath
{
	if ([self fileURL]) // Prefer our wrapper directory
		return [[self fileURL] path];
	else
		return [self tmpPath];
}

- (NSString *) baseName
{
	return [[[self workPath] lastPathComponent] stringByDeletingPathExtension];
}

- (NSURL *) fileURLWithExtension:(NSString*)extension
{
	return [NSURL fileURLWithPath:
			  [[[self workPath] stringByAppendingPathComponent:[self baseName]]
				  stringByAppendingPathExtension:extension]];
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
	if ([typeName isEqual:@"VLNativeType"])
		[validTmpFiles removeAllObjects];
	
	return res;
}

- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError
{
	if ([typeName isEqual:@"VLNativeType"]) {
		return [self XMLFileWrapperWithError:outError flat:NO];
	} else if ([typeName isEqual:@"VLMusicXMLType"]) {
		return [self XMLFileWrapperWithError:outError flat:YES];
	} else if ([typeName isEqual:@"VLLilypondType"]) {
		return [self lilypondFileWrapperWithError:outError];
	} else if ([typeName isEqual:@"VLMMAType"]) {
		return [self mmaFileWrapperWithError:outError];
	} else if ([typeName isEqual:@"VLMIDIType"]) {
		return [self midiFileWrapperWithError:outError];
	} else if ([typeName isEqual:@"VLPDFType"]) {
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

	if ([typeName isEqual:@"VLNativeType"] || [typeName isEqual:@"VLMusicXMLType"]) {
		return [self readFromXMLFileWrapper:wrapper error:outError];
	} else if ([typeName isEqual:@"VLLilypondType"] || [typeName isEqual:@"VLBIABType"]) {
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
	if (NSURL * url = [self fileURL]) 
		if (NSDate * modDate = 
			[[[NSFileManager defaultManager] fileAttributesAtPath:[url path] 
											traverseLink:YES]
				objectForKey:NSFileModificationDate])
			[self setFileModificationDate:modDate];
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
	NSString *	path 	= [self workPath];
	NSPipe *	pipe	= [NSPipe pipe];
	
	[task setCurrentDirectoryPath: path];
	[task setStandardOutput: pipe];
	[task setStandardError: pipe];
	[task setArguments: args];
	[task setLaunchPath: launch]; 
	[[self logWin] window]; // Load but don't show
	
	[NSThread detachNewThreadSelector:@selector(logFromFileHandle:) toTarget:logWin 
		withObject:[pipe fileHandleForReading]];
		
	return task;
}

- (IBAction) play:(id)sender
{
	[self createTmpFileWithExtension:@"mid" ofType:@"VLMIDIType"];
	VLSoundOut::Instance()->PlayFile(
	  CFDataRef([NSData dataWithContentsOfURL: 
							[self fileURLWithExtension:@"mid"]]));
}

- (void) playWithGroove:(NSString *)groove
{
	NSString * savedGroove	= songGroove;
	songGroove				= groove;
	[validTmpFiles removeObjectForKey:@"mma"]; 
	[validTmpFiles removeObjectForKey:@"mid"]; 
	[self play:groove];
	songGroove				= savedGroove;
	[validTmpFiles removeObjectForKey:@"mma"]; 
	[validTmpFiles removeObjectForKey:@"mid"]; 
}

- (IBAction) stop:(id)sender
{
	VLSoundOut::Instance()->Stop();
}

- (IBAction) playStop:(id)sender
{	
	if (VLSoundOut::Instance()->Playing()) {
		[self stop:sender];
		[sender setTitle:@"Play"];
	} else {
		[self play:sender];
		[sender setTitle:@"Stop"];
	}
}

- (IBAction) showOutput:(id)sender
{
	[self createTmpFileWithExtension:@"pdf" ofType:@"VLPDFType"];
	[[self pdfWin] showWindow:sender];
	[pdfWin reloadPDF];
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings 
										   error:(NSError **)outError 
{
	[self createTmpFileWithExtension:@"pdf" ofType:@"VLPDFType"];
	[printDoc autorelease];
	printDoc = [[PDFDocument alloc] initWithURL:[self fileURLWithExtension:@"pdf"]];

    NSPrintOperation *printOperation = [printDoc getPrintOperationForPrintInfo:[self printInfo] autoRotate:NO];

    // Specify that the print operation can run in a separate thread. This will cause the print progress panel to appear as a sheet on the document window.
    [printOperation setCanSpawnSeparateThread:YES];
    
    // Set any print settings that might have been specified in a Print Document Apple event. 
    [[[printOperation printInfo] dictionary] addEntriesFromDictionary:printSettings];
    
    return printOperation;    
}

- (IBAction) showLog:(id)sender
{
	[[self logWin] showWindow:sender];
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

@end
