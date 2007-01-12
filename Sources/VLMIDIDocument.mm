//
//  VLLilypondDocument.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 10/20/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLMMADocument.h"

@implementation VLDocument (MIDI)

- (NSFileWrapper *)midiFileWrapperWithError:(NSError **)outError
{
	NSBundle *	mainBundle	= [NSBundle mainBundle];

	//
	// Convert to MMA format
	//
	NSError *	err;
	NSURL *		mmaURL = [self fileURLWithExtension:@"mma"];
	[self writeToURL: mmaURL ofType:@"VLMMAType" error:&err];	
	[self changedFileWrapper];

	NSString *	launch	=
		[mainBundle pathForResource:@"mmaWrapper" ofType:@""
					inDirectory:@"bin"];
	NSArray *	args	= [NSArray arrayWithObject: [mmaURL path]];
	NSTask *	task	= [self taskWithLaunchPath:launch arguments:args];

	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(mmaDone:)
		name:NSTaskDidTerminateNotification object:task];
	
	[task launch];
	[task waitUntilExit];
    int status = [task terminationStatus];
    if (!status) {
		return [[[NSFileWrapper alloc] 
					initWithPath:[[self fileURLWithExtension:@"mid"] path]]
				   autorelease];
	} else {
		NSBeep();

		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
								 code:NSPersistentStoreSaveError
								 userInfo:nil];

		return nil;
	}
}


- (void)mmaDone:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    int status = [[notification object] terminationStatus];
    if (!status) {
		;
	} else {
		NSBeep();
	}
}

@end
