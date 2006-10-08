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

const int kMidiChannelInUse = 0;

enum {
	kMidiMessage_ControlChange 		= 0xB,
	kMidiMessage_ProgramChange 		= 0xC,
	kMidiMessage_BankMSBControl 	= 0,
	kMidiMessage_BankLSBControl		= 32,
	kMidiMessage_NoteOn 			= 0x9,
	kMidiMessage_NoteOff			= 0x8
};

class VLAUSoundOut : public VLSoundOut {
public:
	VLAUSoundOut();

	virtual void PlayNote(const VLNote & note);
	virtual void PlayChord(const VLChord & chord); 

	virtual ~VLAUSoundOut();
private:
	AUGraph		fGraph;
	AudioUnit	fSynth;
	bool		fRunning;

	void		Run();
	void		Stop();
	void 		Play(const int8_t * note, size_t numNotes = 1);
protected:
	friend class VLAUSoundEvent;

	void 		Play(const int8_t * note, size_t numNotes, 
					 UInt32 msg, UInt32 velocity);
};

VLSoundEvent::~VLSoundEvent()
{
}

class VLAUSoundEvent : public VLSoundEvent {
public:
	VLAUSoundEvent(VLAUSoundOut * soundOut,
				   const int8_t * note, size_t numNotes,
				   UInt32 msg, UInt32 velocity)
	  : fSoundOut(soundOut), fNotes(note, note+numNotes), 
		fMsg(msg), fVelocity(velocity)
	{}

	virtual void Perform();
private:
	VLAUSoundOut *		fSoundOut;
	std::vector<int8_t>	fNotes;
	UInt32				fMsg;
	UInt32				fVelocity;
};

void VLAUSoundEvent::Perform()
{
	fSoundOut->Play(&fNotes[0], fNotes.size(), fMsg, fVelocity);

	delete this;
}

void VLSoundScheduler::Schedule(VLSoundEvent * what, float when)
{
	usleep((int)(1000000.0f*when));
	what->Perform();
}

static std::auto_ptr<VLSoundOut>		sSoundOut;
static std::auto_ptr<VLSoundScheduler>	sSoundScheduler;

VLSoundOut * VLSoundOut::Instance()
{
	if (!sSoundOut.get()) {
		sSoundOut.reset(new VLAUSoundOut);
		if (!sSoundScheduler.get())
			sSoundScheduler.reset(new VLSoundScheduler);
	}

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
	: fRunning(false)
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
	AUGraphGetNodeInfo(fGraph, synthNode, 0, 0, 0, &fSynth);

	AUGraphInitialize(fGraph);

	MusicDeviceMIDIEvent(fSynth, 
						 kMidiMessage_ControlChange << 4 | kMidiChannelInUse, 
						 kMidiMessage_BankMSBControl, 0,
						 0/*sample offset*/);
	MusicDeviceMIDIEvent(fSynth, 
						 kMidiMessage_ProgramChange << 4 | kMidiChannelInUse, 	
						 0/*prog change num*/, 0,
						 0/*sample offset*/);
}

VLAUSoundOut::~VLAUSoundOut()
{
	Stop();
	DisposeAUGraph(fGraph);
}

void VLAUSoundOut::Run()
{
	if (!fRunning) {
		AUGraphStart(fGraph);
		fRunning	= true;
	}
}

void VLAUSoundOut::Stop()
{
	if (fRunning) {
		AUGraphStop(fGraph);
		fRunning	= false;
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
	Run();

	const UInt32 kNoteOn  = kMidiMessage_NoteOn  << 4 | kMidiChannelInUse;
	const UInt32 kNoteOff = kMidiMessage_NoteOff << 4 | kMidiChannelInUse;
	const UInt32 kNoteVelocity= 127;

	Play(note, numNotes, kNoteOn, kNoteVelocity);
	sSoundScheduler.get()->Schedule(
		new VLAUSoundEvent(this, note, numNotes, kNoteOff, kNoteVelocity), 0.5f);
}

void VLAUSoundOut::Play(const int8_t * note, size_t numNotes, 
						UInt32 msg, UInt32 velocity)
{
	for (size_t i = 0; i<numNotes; ++i)
		MusicDeviceMIDIEvent(fSynth, msg, note[i], velocity, 0);	
}
