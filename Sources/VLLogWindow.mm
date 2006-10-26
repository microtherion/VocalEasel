//
//  VLLogWindow.m
//  Lilypond
//
//  Created by Matthias Neeracher on 5/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "VLLogWindow.h"

@implementation VLLogWindow

- (id)initWithWindow:(NSWindow *)window
{
	self	= [super initWithWindow:window];
	logText	= [[NSMutableString alloc] initWithCapacity:1000];
	
	return self;
}

- (void)dealloc
{
	[logText autorelease];
	[super dealloc];
}

- (IBAction)printDocument:(id)sender
{
	[log print: sender];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [displayName stringByAppendingString: @" - Log"];
}

- (void) logFromFileHandle:(NSFileHandle *) h
{
	NSAutoreleasePool * pool	= [[NSAutoreleasePool alloc] init];
	NSData *		   data;
	
	[logText setString: @""];
	[log setString: logText];
	while ((data = [h availableData]) && [data length]) {
		NSString * append = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
		[logText appendString: append];
		[log setString: logText];
		[log scrollRangeToVisible: NSMakeRange([logText length], 0)];
		
		[pool release];
		pool	= [[NSAutoreleasePool alloc] init];
	}
	[pool release];
}

@end
