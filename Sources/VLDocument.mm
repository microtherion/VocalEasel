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

- (void) close
{
	[logWin close];
	[pdfWin close];

	[super close];
}

- (void) dealloc
{
	delete song;

	[super dealloc];
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

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if ([typeName isEqual:@"VLNativeType"]) {
		return [self XMLDataWithError:outError];
	} else if ([typeName isEqual:@"VLLilypondType"]) {
		return [self lilypondDataWithError:outError];
	} else {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
								 code:NSPersistentStoreInvalidTypeError
								 userInfo:nil];
		return nil;
	}
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	if ([typeName isEqual:@"VLNativeType"]) {
		return [self readFromXMLData:data error:outError];
	} else {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
								 code:NSPersistentStoreInvalidTypeError
								 userInfo:nil];
		return NO;
	}
}


- (IBAction) engrave:(id)sender
{
	NSTask *	lilypondTask	= [[NSTask alloc] init];
	NSString *	path			= [[self fileURL] path];
	NSString *  root			= 
		[[path lastPathComponent] stringByDeletingPathExtension];
    NSString *  tmpDir			= @"/var/tmp";
	NSBundle *	mainBundle		= [NSBundle mainBundle];

	//
	// Convert to Lilypond format
	//
	NSError *			err;
	[self writeToURL:
		[NSURL fileURLWithPath:
			[[tmpDir stringByAppendingPathComponent:root]
				stringByAppendingPathExtension:@"ly"]]
		  ofType:@"VLLilypondType" error:&err];
	NSPipe *	pipe			= [NSPipe pipe];
	NSString *	tool			= 
		[[NSUserDefaults standardUserDefaults] 
			stringForKey:@"VLLilypondPath"];
	NSArray *	arguments		= [NSArray arrayWithObjects:tool, root, nil];

	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(engraveDone:)
		name:NSTaskDidTerminateNotification object:lilypondTask];
	
	[lilypondTask setCurrentDirectoryPath:tmpDir];
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
		NSFileManager * fileManager = [NSFileManager defaultManager];
		NSString *	path			= [[self fileURL] path];
		NSString *  root			= 
			[[path lastPathComponent] stringByDeletingPathExtension];
		NSString *  tmpDir			= @"/var/tmp";
		NSString * 	dstDir			= [path stringByDeletingLastPathComponent];
		NSString * 	pdf				= 
			[root stringByAppendingPathExtension:@"pdf"];
		[fileManager
			removeFileAtPath:[dstDir stringByAppendingPathComponent:pdf]
			handler:nil];
		[fileManager 
			movePath:[tmpDir stringByAppendingPathComponent:pdf]
			toPath:[dstDir stringByAppendingPathComponent:pdf]
			handler:nil];
		[[self pdfWin] showWindow: self];
		[pdfWin reloadPDF];
	} 
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
