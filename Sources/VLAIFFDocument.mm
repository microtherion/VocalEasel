//
// File: VLAIFFDocument.mm - Export document in AIFF format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2008 Matthias Neeracher
//

#import "VLAIFFDocument.h"
#import "VLSoundOut.h"

#import <CoreAudio/CoreAudio.h>

@implementation VLDocument (AIFF)

- (NSFileWrapper *)aiffFileWrapperWithError:(NSError **)outError
{
	[self createTmpFileWithExtension:@"mid" ofType:@"VLMIDIType"];

	NSURL *		midiURL  = [self fileURLWithExtension:@"mid"];
	NSURL * 	aiffURL  = [self fileURLWithExtension:@"aiff"];
	VLSoundOut *writer	 = 
		VLSoundOut::FileWriter((CFURLRef)aiffURL, kAudioFormatLinearPCM);
	writer->PlayFile(CFDataRef([NSData dataWithContentsOfURL:midiURL]));
	delete writer;

	return [[[NSFileWrapper alloc] 
				initWithPath:[[self fileURLWithExtension:@"aiff"] path]]
			   autorelease];
}

@end
