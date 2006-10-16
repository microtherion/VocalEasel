/*
 *  VLSoundOut.cpp
 *  Vocalese
 *
 *  Created by Matthias Neeracher on 12/18/05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#include "VLSoundOut.h"

#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>

#include <memory>
#include <vector>

class VLAUSoundOut : public VLSoundOut {
public:
	VLAUSoundOut();

	virtual void PlayNote(const VLNote & note);
	virtual void PlayChord(const VLChord & chord); 
	
	virtual ~VLAUSoundOut();

	void		Stop();
private:
	AUGraph			fGraph;
	MusicPlayer		fPlayer;
	MusicSequence	fMusic;
	bool			fRunning;

	void		PlaySequence(MusicSequence music);
	void 		Play(const int8_t * note, size_t numNotes = 1);
};

VLSoundEvent::~VLSoundEvent()
{
}

void VLSoundScheduler::Schedule(VLSoundEvent * what, float when)
{
	usleep((int)(1000000.0f*when));
    what->Perform();
}

static std::auto_ptr<VLSoundOut>		sSoundOut;
static std::auto_ptr<VLSoundScheduler> sSoundScheduler;

VLSoundOut * VLSoundOut::Instance()
{
	if (!sSoundOut.get()) {
		sSoundOut.reset(new VLAUSoundOut);
		if (!sSoundScheduler.get())
			sSoundScheduler.reset(new VLSoundScheduler);
	}
}

VLSoundOut * VLSoundOut::Instance()
{
	if (!sSoundOut.get()) 
		sSoundOut.reset(new VLAUSoundOut);

	return sSoundOut.get();
}

void VLSoundOut::SetScheduler(VLSoundScheduler * scheduler)
{
	sSoundScheduler.reset(scheduler);
}

VLSoundOut::~VLSoundOut()
{
}

VLAUSoundOut::VLAUSoundOut()
	: fRunning(false), fMusic(0)
{
	AUNode synthNode, limiterNode, outNode;
   	ComponentDescription cd;

	cd.componentManufacturer = kAudioUnitManufacturer_Apple;
	cd.componentFlags = 0;
	cd.componentFlagsMask = 0;

	NewAUGraph(&fGraph);

	cd.componentType = kAudioUnitType_MusicDevice;
	cd.componentSubType = kAudioUnitSubType_DLSSynth;

	AUGraphNewNode(fGraph, &cd, 0, NULL, &synthNode);

	cd.componentType = kAudioUnitType_Effect;
	cd.componentSubType = kAudioUnitSubType_PeakLimiter;  

	AUGraphNewNode (fGraph, &cd, 0, NULL, &limiterNode);

	cd.componentType = kAudioUnitType_Output;
	cd.componentSubType = kAudioUnitSubType_DefaultOutput;  

	AUGraphNewNode(fGraph, &cd, 0, NULL, &outNode);
	
	AUGraphOpen(fGraph);
	AUGraphConnectNodeInput(fGraph, synthNode, 0, limiterNode, 0);
	AUGraphConnectNodeInput(fGraph, limiterNode, 0, outNode, 0);

	AUGraphInitialize(fGraph);
	
	NewMusicPlayer(&fPlayer);
}

VLAUSoundOut::~VLAUSoundOut()
{
	DisposeMusicPlayer(fPlayer);
	Stop();
	DisposeAUGraph(fGraph);
}

void VLAUSoundOut::PlaySequence(MusicSequence music)
{
	Stop();

	fMusic	= music;

	MusicSequenceSetAUGraph(fMusic, fGraph);
	MusicPlayerSetSequence(fPlayer, fMusic);
	MusicPlayerStart(fPlayer);

	fRunning	= true;
}

void VLAUSoundOut::Stop()
{
	MusicPlayerStop(fPlayer);
	if (fRunning) {
		fRunning	= false;
		if (fMusic) {
			MusicPlayerSetSequence(fPlayer, NULL);
			DisposeMusicSequence(fMusic);
			fMusic = 0;
		}
	}
}

void VLAUSoundOut::PlayNote(const VLNote & note)
{
	Play(&note.fPitch);
}

void VLAUSoundOut::PlayChord(const VLChord & chord)
{
	std::vector<int8_t>	notes;

	for (int i = 0; i < 32; ++i)
		if (chord.fSteps & (1 << i))
			notes.push_back(chord.fPitch+i);
	if (chord.fRootPitch != VLNote::kNoPitch)
		notes.push_back(chord.fRootPitch);
	Play(&notes[0], notes.size());
}

void VLAUSoundOut::Play(const int8_t * note, size_t numNotes)
{
	MusicSequence	music;
	MusicTrack		track;
	
	NewMusicSequence(&music);
	MusicSequenceNewTrack(music, &track);
	
	const int8_t kNoteVelocity = 127;
	for (int i=0; i<numNotes; ++i) {
		MIDINoteMessage	n = {0, note[i], kNoteVelocity, 0, 1.0}; 
		MusicTrackNewMIDINoteEvent(track, 0.0, &n);
	}
		
	PlaySequence(music);
}
