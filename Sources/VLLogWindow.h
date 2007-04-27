//
// File: VLLogWindow.h - Manage output log window
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLLogWindow : NSWindowController {
	IBOutlet id			log;
	NSMutableString *	logText;
}

- (void) logFromFileHandle:(NSFileHandle *) h;

@end
