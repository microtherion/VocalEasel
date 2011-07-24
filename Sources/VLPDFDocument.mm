//
// File: VLPDFDocument.mm - Export document in PDF format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2011 Matthias Neeracher
//

#import "VLPDFDocument.h"

@implementation VLDocument (PDF)

- (NSFileWrapper *)pdfFileWrapperWithError:(NSError **)outError
{
	NSString *  base			= [self baseName];
	NSBundle *	mainBundle		= [NSBundle mainBundle];

	[self createTmpFileWithExtension:@"ly" ofType:VLLilypondType];

	NSString *	launch	=
		[mainBundle pathForResource:@"lilyWrapper" ofType:@""
					inDirectory:@"bin"];
	NSString *	tool	= 
		[[NSUserDefaults standardUserDefaults] 
			stringForKey:@"VLLilypondPath"];
	NSArray *	args	= [NSArray arrayWithObjects:tool, base, nil];
	NSTask *	task	= [self taskWithLaunchPath:launch arguments:args];

	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(pdfDone:)
		name:NSTaskDidTerminateNotification object:task];
	
	[sheetWin startAnimation];
	[task launch];
	[task waitUntilExit];
	[sheetWin stopAnimation];
    int status = [task terminationStatus];
    if (!status) {
		return [[[NSFileWrapper alloc] 
					initWithPath:[[self fileURLWithExtension:@"pdf"] path]]
				   autorelease];
	} else {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
								 code:NSPersistentStoreSaveError
								 userInfo:nil];

		return nil;
	}
}


- (void)pdfDone:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver: self 
		name:NSTaskDidTerminateNotification object:[notification object]];
    int status = [[notification object] terminationStatus];
    if (!status) {
		;
	} else {
		[[self logWin] showWindow: self];		
		NSBeep();
	}
}

@end
