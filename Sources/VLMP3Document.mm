//
// File: VLMP3Document.mm - Export document in MP3 format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2008 Matthias Neeracher
//

#import "VLMP3Document.h"

@implementation VLDocument (MP3)

- (NSFileWrapper *)mp3FileWrapperWithError:(NSError **)outError
{
	if (![[NSApp delegate] lameIsInstalled]) {
		if (outError)
			*outError = [NSError errorWithDomain:NSPOSIXErrorDomain
								 code:ENOEXEC userInfo:nil];
		return nil;
	}
	NSBundle *	mainBundle	= [NSBundle mainBundle];
	
	[self createTmpFileWithExtension:@"aiff" ofType:@"VLAIFFType"];
	
	NSURL *		aiffURL  = [self fileURLWithExtension:@"aiff"];
	NSURL *     mp3URL   = [self fileURLWithExtension:@"mp3"];
	NSString *	launch	=
	[mainBundle pathForResource:@"lameWrapper" ofType:@""
					inDirectory:@"bin"];
	NSArray *	args	= [NSArray arrayWithObjects: @"--quiet", @"-h", [aiffURL path], [mp3URL path], nil];
	NSTask *	task	= [self taskWithLaunchPath:launch arguments:args];
	
	[[NSNotificationCenter defaultCenter] 
	 addObserver:self selector:@selector(lameDone:)
	 name:NSTaskDidTerminateNotification object:task];
	
	[sheetWin startAnimation];
	[task launch];
	[task waitUntilExit];
	[sheetWin stopAnimation];
    int status = [task terminationStatus];
    if (!status) {
		return [[[NSFileWrapper alloc] 
				 initWithPath:[[self fileURLWithExtension:@"mp3"] path]]
				autorelease];
	} else {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
											code:NSPersistentStoreSaveError
										userInfo:nil];
		
		return nil;
	}
}

- (void)lameDone:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver: self 
													name:NSTaskDidTerminateNotification object:[notification object]];
    int status = [[notification object] terminationStatus];
    if (!status) {
		;
	} else {
		NSBeep();
	}
}

@end
