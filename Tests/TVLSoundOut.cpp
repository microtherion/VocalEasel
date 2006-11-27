/*
 *  TVLSoundOut.cpp
 *  Vocalese
 *
 *  Created by Matthias Neeracher on 12/19/05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#include "VLSoundOut.h"

#include <iostream>
#include <CoreFoundation/CoreFoundation.h>

int main(int argc, char *const argv[])
{
	VLSoundOut * 	soundOut = NULL;

	if (argc > 2) {
		CFStringRef outFile	= 
			CFStringCreateWithCString(NULL, argv[2], kCFStringEncodingUTF8);
		CFURLRef	outURL 	= 
			CFURLCreateWithFileSystemPath(NULL, outFile, kCFURLPOSIXPathStyle, false);
		soundOut			= VLSoundOut::FileWriter(outURL, 0);
		CFRelease(outURL);
		CFRelease(outFile);
	} else {
		soundOut 			= VLSoundOut::Instance();
	}

	if (argc > 1) {
		CFStringRef inFile	= 
			CFStringCreateWithCString(NULL, argv[1], kCFStringEncodingUTF8);
		CFURLRef	inURL 	= 
			CFURLCreateWithFileSystemPath(NULL, inFile, kCFURLPOSIXPathStyle, false);
		CFDataRef	inData;
		CFURLCreateDataAndPropertiesFromResource(NULL, inURL, &inData, 
												 NULL, NULL, NULL);
		soundOut->PlayFile(inData);
		CFRelease(inData);
		CFRelease(inURL);
		CFRelease(inFile);
	} else {
		std::string 	chordName;

		while (std::cin >> chordName) {
			VLChord chord(chordName);

			soundOut->PlayNote(chord);
			usleep(250*1000);
			soundOut->PlayChord(chord);
		}
	}

	exit(0);
}
