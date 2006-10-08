/*
 *  VLSoundOut.h
 *  Vocalese
 *
 *  Created by Matthias Neeracher on 12/18/05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#include "VLModel.h"

class VLSoundEvent {
protected:
	VLSoundEvent() {}
public:
	virtual ~VLSoundEvent();

	virtual void Perform() {}
};

class VLSoundScheduler {
public:
	virtual void Schedule(VLSoundEvent * what, float when);
	
	virtual ~VLSoundScheduler() {}
};

class VLSoundOut {
public:
	static VLSoundOut * Instance();
	static void SetScheduler(VLSoundScheduler * scheduler);

	virtual void PlayNote(const VLNote & note) = 0;
	virtual void PlayChord(const VLChord & chord) = 0; 

	virtual ~VLSoundOut();
};

// Local Variables:
// mode:C++
// End:
