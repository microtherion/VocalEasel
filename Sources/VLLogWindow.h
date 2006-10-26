//
//  VLLogWindow.h
//  Vocalese
//
//  Created by Matthias Neeracher on 5/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VLLogWindow : NSWindowController {
	IBOutlet id			log;
	NSMutableString *	logText;
}

- (void) logFromFileHandle:(NSFileHandle *) h;

@end
