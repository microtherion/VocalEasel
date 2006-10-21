/*
 *  TVLChord.cpp
 *  Vocalese
 *
 *  Created by Matthias Neeracher on 12/19/05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#include "VLModel.h"

#include <iostream>

int main(int, char *const [])
{
	std::string chordName;
	
	while (std::cin >> chordName) {
		VLChord chord(chordName);
	
		std::string baseS, extS, rootS, baseF, extF, rootF, lilyS, lilyF;
	
		chord.Name(baseS, extS, rootS, true);
		chord.Name(baseF, extF, rootF, false);
		chord.LilypondName(lilyS, true);
		chord.LilypondName(lilyF, false);

		std::cout << baseS << "[" << extS << "]" << rootS << " "
				  << baseF << "[" << extF << "]" << rootF << " "
				  << lilyS << " " << lilyF
				  << std::endl;

	}
	exit(0);
}
