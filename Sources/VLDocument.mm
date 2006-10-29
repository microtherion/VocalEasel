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
#import "VLPDFWindow.h"
#import "VLLogWindow.h"
#import "VLSheetWindow.h"

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
		sheetWin			= nil;
		pdfWin				= nil;	
		logWin				= nil;
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

- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError
{
	if ([typeName isEqual:@"VLNativeType"]) {
		return [self XMLFileWrapperWithError:outError flat:NO];
	} else if ([typeName isEqual:@"VLMusicXMLType"]) {
		return [self XMLFileWrapperWithError:outError flat:YES];
	} else if ([typeName isEqual:@"VLLilypondType"]) {
		return [self lilypondFileWrapperWithError:outError];
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

- (IBAction) performEngrave:(id)sender
{
	NSTask *	lilypondTask	= [[NSTask alloc] init];
	NSString *	path			= [[self fileURL] path];
	NSString *  base			= [[path lastPathComponent]
									  stringByDeletingPathExtension];
	NSBundle *	mainBundle		= [NSBundle mainBundle];

	//
	// Convert to Lilypond format
	//
	NSError *			err;
	[self writeToURL:
		[NSURL fileURLWithPath:[[path stringByAppendingPathComponent:base]
								   stringByAppendingPathExtension:@"ly"]]
		  ofType:@"VLLilypondType" error:&err];
	NSPipe *	pipe			= [NSPipe pipe];
	NSString *	tool			= 
		[[NSUserDefaults standardUserDefaults] 
			stringForKey:@"VLLilypondPath"];
	NSArray *	arguments		= [NSArray arrayWithObjects:tool, base, nil];

	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(engraveDone:)
		name:NSTaskDidTerminateNotification object:lilypondTask];
	
	[lilypondTask setCurrentDirectoryPath:path];
	[lilypondTask setStandardOutput: pipe];
	[lilypondTask setStandardError: pipe];
	[lilypondTask setArguments: arguments];
	[lilypondTask setLaunchPath: 
					  [mainBundle pathForResource:@"lilyWrapper" ofType:@""]];
	[lilypondTask launch];

	[[self logWin] showWindow: self];
	
	[NSThread detachNewThreadSelector:@selector(logFromFileHandle:) toTarget:logWin 
		withObject:[pipe fileHandleForReading]];
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

- (void) engrave:(NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void  *)contextInfo
{
	if (didSave)
		[self performEngrave:(id)contextInfo];
}

- (void)engrave:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(id)sender
{
	if (returnCode == NSAlertDefaultReturn) {
		[[alert window] orderOut:self];
		[self saveDocumentWithDelegate:self
			  didSaveSelector:@selector(engrave:didSave:contextInfo:) 
			  contextInfo:sender];
	}
}

- (IBAction) engrave:(id)sender
{
	if ([self isDocumentEdited]) {
		NSAlert * alert = 
			[NSAlert alertWithMessageText:@"Do you want to save your changes?"
					 defaultButton:[self fileURL] ? @"Save" : @"Save..."
					 alternateButton:@"Cancel" otherButton:nil 
					 informativeTextWithFormat:@"You need to save your document before typesetting."];
		[alert beginSheetModalForWindow:[sheetWin window]
			   modalDelegate:self 
			   didEndSelector:@selector(engrave:returnCode:contextInfo:)
			   contextInfo:sender];
	} else
		[self performEngrave:sender];
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
