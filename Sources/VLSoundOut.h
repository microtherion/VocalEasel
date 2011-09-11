//
// File: VLSoundOut.h - Sound output and file conversion
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#include "VLModel.h"
#import <CoreFoundation/CoreFoundation.h>
#include <AudioToolbox/AudioToolbox.h>

extern CFStringRef  kVLSoundStartedNotification;
extern CFStringRef  kVLSoundStoppedNotification;

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
    virtual void SetStart(MusicTimeStamp start) = 0;
    virtual void SetEnd(MusicTimeStamp end) = 0;
	virtual void Stop(bool pause=true) = 0;
	virtual bool Playing() = 0;
	virtual bool AtEnd() = 0;
    virtual bool AtBeginning() = 0;
    virtual void ResetSelection() = 0;
	virtual void SetPlayRate(float rate) = 0;
    virtual void Fwd() = 0;
    virtual void Bck() = 0;
    virtual void Slow(float rate) = 0;
    enum MelodyState {
        kMelodyMute,
        kMelodyRegular,
        kMelodySolo
    };
    virtual void SetMelodyState(MelodyState state) = 0;

	virtual ~VLSoundOut();
};

// Local Variables:
// mode:C++
// End:
