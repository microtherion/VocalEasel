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

int main(int, char *const [])
{
	std::string chordName;
	VLSoundOut * soundOut = VLSoundOut::Instance();
	
	while (std::cin >> chordName) {
		VLChord chord(chordName);

		soundOut->PlayNote(chord);
		usleep(250*1000);
		soundOut->PlayChord(chord);
	}

	exit(0);
}
