//
//  VLDocument.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 12/17/05.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.
//

#import "VLDocument.h"
#import "VLXMLDocument.h"
#import "VLLilypondDocument.h"
#import "VLMMADocument.h"
#import "VLMIDIDocument.h"
#import "VLPDFWindow.h"
#import "VLLogWindow.h"
#import "VLSheetWindow.h"
#import "VLSoundOut.h"

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
		sheetWin			= nil;
		pdfWin				= nil;	
		logWin				= nil;
		tmpPath				= nil;
		vcsWrapper			= nil;
    }
    return self;
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

- (void) setKey:(int)key transpose:(BOOL)transpose
{
	VLProperties & prop = song->fProperties.front();

	if (transpose)
		song->Transpose((7*((key>>8)-prop.fKey) % 12));

	prop.fKey = key >> 8;
	prop.fMode= key & 0xFF;

	[self updateChangeCount:NSChangeDone];
}

- (NSNumber *)  songTime
{
	const VLProperties & prop = song->fProperties.front();

	return [NSNumber numberWithInt: (prop.fTime.fNum << 8) | prop.fTime.fDenom];
}

- (void) setTimeNum:(int)num denom:(int)denom
{
	VLProperties & prop = song->fProperties.front();

	prop.fTime = VLFraction(num, denom);

	[self updateChangeCount:NSChangeDone];
}

- (NSNumber *) songDivisions
{
	const VLProperties & prop = song->fProperties.front();

	return [NSNumber numberWithInt: prop.fDivisions];	
}

- (void) setDivisions:(int)divisions
{
	VLProperties & prop = song->fProperties.front();

	prop.fDivisions	= divisions;

	[self updateChangeCount:NSChangeDone];
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
	if ([typeName isEqual:@"VLNativeType"]) {
		return [self readFromXMLFileWrapper:wrapper error:outError];
	} else {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
								 code:NSPersistentStoreInvalidTypeError
								 userInfo:nil];
		return NO;
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

	[[self logWin] showWindow: self];
	
	[NSThread detachNewThreadSelector:@selector(logFromFileHandle:) toTarget:logWin 
		withObject:[pipe fileHandleForReading]];
		
	return task;
}

- (IBAction) engrave:(id)sender
{
	NSString *  base			= [self baseName];
	NSBundle *	mainBundle		= [NSBundle mainBundle];

	//
	// Convert to Lilypond format
	//
	NSError *			err;
	[self writeToURL:[self fileURLWithExtension:@"ly"]
		  ofType:@"VLLilypondType" error:&err];
	NSString *	launch	=
		[mainBundle pathForResource:@"lilyWrapper" ofType:@""
					inDirectory:@"bin"];
	NSString *	tool	= 
		[[NSUserDefaults standardUserDefaults] 
			stringForKey:@"VLLilypondPath"];
	NSArray *	args	= [NSArray arrayWithObjects:tool, base, nil];
	NSTask *	task	= [self taskWithLaunchPath:launch arguments:args];

	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(engraveDone:)
		name:NSTaskDidTerminateNotification object:task];
	
	[task launch];
}

- (void)engraveDone:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    int status = [[notification object] terminationStatus];
    if (!status) {
		[[self pdfWin] showWindow: self];
		[pdfWin reloadPDF];
	} else {
		NSBeep();
	}
}

- (IBAction) play:(id)sender
{
	NSError * err;
	[self writeToURL:[self fileURLWithExtension:@"mid"]
		  ofType:@"VLMIDIType" error:&err];
	VLSoundOut::Instance()->PlayFile(
	  CFDataRef([NSData dataWithContentsOfURL: 
							[self fileURLWithExtension:@"mid"]]));
}

- (IBAction) showOutput:(id)sender
{
	[[self pdfWin] showWindow:sender];
}

- (IBAction) showLog:(id)sender
{
	[[self logWin] showWindow:sender];
}

@end
