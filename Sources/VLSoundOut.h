//
// File: VLSoundOut.h - Sound output and file conversion
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
//

#include "VLModel.h"
#import <CoreFoundation/CoreFoundation.h>

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
	static VLSoundOut * FileWriter(CFURLRef file, OSType dataFormat);

	static void SetScheduler(VLSoundScheduler * scheduler);

	virtual void PlayNote(const VLNote & note) = 0;
	virtual void PlayChord(const VLChord & chord) = 0; 
	virtual void PlayFile(CFDataRef file) = 0;
	virtual void Stop() = 0;
	virtual bool Playing() = 0;

	virtual ~VLSoundOut();
};

// Local Variables:
// mode:C++
// End:
