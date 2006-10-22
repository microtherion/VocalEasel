/*
 *  TVLLilypond.mm
 *  Vocalese
 *
 *  Created by Matthias Neeracher on 12/19/05.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#include "VLModel.h"
#include "VLDocument.h"

int main(int, char *const argv[])
{
	NSAutoreleasePool *	pool	= [[NSAutoreleasePool alloc] init];
	VLDocument * 		doc 	= [[VLDocument alloc] init];
	NSString *			file	= [NSString stringWithUTF8String:argv[1]];
	NSError *			err;
	[doc readFromURL:[NSURL fileURLWithPath:file] ofType:@"Song" error:&err];
	[doc writeToURL:[NSURL fileURLWithPath:	
							   [[file stringByDeletingPathExtension]
								   stringByAppendingPathExtension:@"ly"]]
		 ofType:@"Lilypond" error:&err];
	[pool release];

	exit(0);
}
