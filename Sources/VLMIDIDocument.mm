//
//  VLMIDIDocument.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 10/20/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLMIDIDocument.h"

@implementation VLDocument (MIDI)

- (NSFileWrapper *)midiFileWrapperWithError:(NSError **)outError
{
	NSBundle *	mainBundle	= [NSBundle mainBundle];

	[self createTmpFileWithExtension:@"mma" ofType:@"VLMMAType"];

	NSURL *		mmaURL  = [self fileURLWithExtension:@"mma"];
	NSString *	launch	=
		[mainBundle pathForResource:@"mmaWrapper" ofType:@""
					inDirectory:@"bin"];
	NSArray *	args	= [NSArray arrayWithObject: [mmaURL path]];
	NSTask *	task	= [self taskWithLaunchPath:launch arguments:args];

	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(mmaDone:)
		name:NSTaskDidTerminateNotification object:task];
	
	[sheetWin startAnimation];
	[task launch];
	[task waitUntilExit];
	[sheetWin stopAnimation];
    int status = [task terminationStatus];
    if (!status) {
		return [[[NSFileWrapper alloc] 
					initWithPath:[[self fileURLWithExtension:@"mid"] path]]
				   autorelease];
	} else {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
								 code:NSPersistentStoreSaveError
								 userInfo:nil];

		return nil;
	}
}


- (void)mmaDone:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver: self 
		name:NSTaskDidTerminateNotification object:[notification object]];
    int status = [[notification object] terminationStatus];
    if (!status) {
		;
	} else {
		[logWin showWindow: self];		
		NSBeep();
	}
}

@end
