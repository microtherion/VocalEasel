/*
 *  VLSoundOut.h
 *  Vocalese
 *
 *  Created by Matthias Neeracher on 12/18/05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#include "VLModel.h"

class VLSoundOut {
public:
	static VLSoundOut * Instance();

	virtual void PlayNote(const VLNote & note) = 0;
	virtual void PlayChord(const VLChord & chord) = 0; 

	virtual ~VLSoundOut();
};

// Local Variables:
// mode:C++
// End:
