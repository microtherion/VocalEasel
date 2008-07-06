//
// File: VLSoundOut.h - Sound output and file conversion
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2008 Matthias Neeracher
//

#include "VLModel.h"
#import <CoreFoundation/CoreFoundation.h>
#include <AudioToolbox/AudioToolbox.h>

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
	void		 PlayFile(CFDataRef file);
	virtual void PlaySequence(MusicSequence music) = 0;
	virtual void Stop(bool pause=true) = 0;
	virtual bool Playing() = 0;
	virtual bool AtEnd() = 0;
	virtual void SetPlayRate(float rate) = 0;
	virtual void SetTime(MusicTimeStamp time) = 0;

	virtual ~VLSoundOut();
};

// Local Variables:
// mode:C++
// End:
