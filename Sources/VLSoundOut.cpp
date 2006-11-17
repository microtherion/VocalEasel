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

	virtual void 	PlayNote(const VLNote & note);
	virtual void 	PlayChord(const VLChord & chord); 
	virtual void 	PlayFile(CFDataRef file);
	
	virtual 	   ~VLAUSoundOut();

	void			Stop();
protected:
	VLAUSoundOut(bool fileOutput);

	void			InitSoundOut(bool fileOutput);
	virtual void 	SetupOutput(AUNode outputNode);
	virtual void   	PlaySequence(MusicSequence music);
	MusicTimeStamp	SequenceLength(MusicSequence music);

	AUGraph			fGraph;
private:
	MusicPlayer		fPlayer;
	MusicSequence	fMusic;
	bool			fRunning;

	void 			Play(const int8_t * note, size_t numNotes = 1);
};

class VLAUFileSoundOut : public VLAUSoundOut {
public:
	VLAUFileSoundOut(CFURLRef file);
	~VLAUFileSoundOut();
protected:
	virtual void 	SetupOutput(AUNode outputNode);
	virtual void   	PlaySequence(MusicSequence music);
private:
	AudioUnit		fOutput;
	CFURLRef		fFile;
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
	return sSoundOut.get();
}

void VLSoundOut::SetScheduler(VLSoundScheduler * scheduler)
{
	sSoundScheduler.reset(scheduler);
}

VLSoundOut * VLSoundOut::FileWriter(CFURLRef file)
{
	return new VLAUFileSoundOut(file);
}

VLSoundOut::~VLSoundOut()
{
}

VLAUSoundOut::VLAUSoundOut()
	: fRunning(false), fMusic(0)
{
	InitSoundOutput(false);
}

VLAUSoundOut::VLAUSoundOut(bool fileOutput)
	: fRunning(false), fMusic(0)
{
	InitSoundOutput(fileOutput);
}

VLAUSoundOut::~VLAUSoundOut()
{
	DisposeMusicPlayer(fPlayer);
	Stop();
	DisposeAUGraph(fGraph);
}

void VLAUSoundOut::InitSoundOutput(bool fileOutput)
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
	if (fileOutput)
		cd.componentSubType	= kAudioUnitSubType_GenericOutput;
	else
		cd.componentSubType = kAudioUnitSubType_DefaultOutput;  

	AUGraphNewNode(fGraph, &cd, 0, NULL, &outNode);

	AUGraphOpen(fGraph);
	AUGraphConnectNodeInput(fGraph, synthNode, 0, limiterNode, 0);
	AUGraphConnectNodeInput(fGraph, limiterNode, 0, outNode, 0);

	if (fileOutput) {
		UInt32 		value = 1;
		AudioUnit	synth;
		AUGraphGetNodeInfo(fGraph, synthNode, 0, 0, 0, &synth)
		AudioUnitSetProperty(synth,
							 kAudioUnitProperty_OfflineRender,
							 kAudioUnitScope_Global, 0,
							 &value, sizeof(value));
	}
	SetupOutput(outNode);

	AUGraphInitialize(fGraph);
	
	NewMusicPlayer(&fPlayer);
}

void VLAUSoundOut::SetupOutput(AUNode)
{
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

void VLAUSoundOut::PlayFile(CFDataRef file)
{
	MusicSequence	music;
	MusicTrack		track;
	
	NewMusicSequence(&music);
	MusicSequenceNewTrack(music, &track);
	MusicSequenceLoadSMFDataWithFlags(music, file,
									  kMusicSequenceLoadSMF_ChannelsToTracks);
	PlaySequence(music);
}

MusicTimeStamp VLAUSoundOut::SequenceLength(MusicSequence music)
{	
	UInt32 ntracks;
	MusicSequenceGetTrackCount(sequence, &ntracks);
	MusicTimeStamp sequenceLength = 0;
	for (UInt32 i = 0; i < ntracks; ++i) {
		MusicTrack track;
		MusicTimeStamp trackLength;
		UInt32 propsize = sizeof(MusicTimeStamp);
		MusicSequenceGetIndTrack(sequence, i, &track);
		MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength,
							  &trackLength, &propsize);
		sequenceLength = std::max(sequenceLength, trackLength);
	}
	return sequenceLength;
}

VLAUFileSoundOut::VLAUFileSoundOut(CFURLRef file)
	: VLAUSoundOut(true), fFile(file)
{
	CFRetain(fFile);
}

VLAUFileSoundOut::~VLAUFileSoundOut()
{
	CFRelease(fFile);
}

void VLAUFileSoundOut::SetupOutput(AUNode outputNode)
{
	AUGraphGetNodeInfo(fGraph, outputNode, 0, 0, 0, &fOutput);
	Float64 sampleRate = 22050.0;
	AudioUnitSetProperty(fOutput,
						 kAudioUnitProperty_SampleRate,
						 kAudioUnitScope_Output, 0,
						 &sampleRate, sizeof(sampleRate));
}

void VLAUFileSoundOut::PlaySequence(MusicSequence music)
{
	SInt32 			urlErr;
	CFURLDestroyResource(fFile, &urlErr);

	OSStatus 		result = 0;
	UInt32 			size;
	MusicTimeStamp	musicLen	= SequenceLength(music)+8;
	CFStringRef		name		= 
		CFURLCopyLastPathComponent(fFile);
	CAAudioFileFormats	formats = CAAudioFileFormats::Instance();
	
	AudioFileTypeID fileType;
	formats->InferFileFormatFromFilename(name, fileType);

	CAStreamBasicDescription outputFormat;
	formats->InferDataFormatFromFileFormat(fileType, outputFormat);
	outputFormat.mChannelsPerFrame	= 2;

	if (outputFormat.mFormatID == kAudioFormatLinearPCM) {
		outputFormat.mBytesPerPacket = outputFormat.mChannelsPerFrame * 2;
		outputFormat.mFramesPerPacket = 1;
		outputFormat.mBytesPerFrame = outputFormat.mBytesPerPacket;
		outputFormat.mBitsPerChannel = 16;
		
		if (fileType == kAudioFileWAVEType)
			outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger
								| kLinearPCMFormatFlagIsPacked;
		else
			outputFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian
								| kLinearPCMFormatFlagIsSignedInteger
								| kLinearPCMFormatFlagIsPacked;
	} else {
		// use AudioFormat API to fill out the rest.
		size = sizeof(outputFormat);
		AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL,
							   &size, &outputFormat);
	}
	
	CFURLRef		dir			= 
		CFURLCreateCopyDeletingLastPathComponent(NULL, fFile);
	FSRef parentDir;
	CFURLGetFSRef(dir, &parentDir);
	CFRelease(dir);

	ExtAudioFileRef outfile;
	ExtAudioFileCreateNew(&parentDir, name, 
						  fileType, &outputFormat, NULL, &outfile);
	CFRelease(name);

	{
		CAStreamBasicDescription clientFormat;
		size = sizeof(clientFormat);
		require_noerr (result = AudioUnitGetProperty (outputUnit,
													kAudioUnitProperty_StreamFormat,
													kAudioUnitScope_Output, 0,
													&clientFormat, &size), fail);
		size = sizeof(clientFormat);
		require_noerr (result = ExtAudioFileSetProperty(outfile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat), fail);
		
		{
			MusicTimeStamp currentTime;
			AUOutputBL outputBuffer (clientFormat, numFrames);
			AudioTimeStamp tStamp;
			memset (&tStamp, 0, sizeof(AudioTimeStamp));
			tStamp.mFlags = kAudioTimeStampSampleTimeValid;
			int i = 0;
			int numTimesFor10Secs = (int)(10. / (numFrames / srate));
			do {
				outputBuffer.Prepare();
				AudioUnitRenderActionFlags actionFlags = 0;
				require_noerr (result = AudioUnitRender (outputUnit, &actionFlags, &tStamp, 0, numFrames, outputBuffer.ABL()), fail);

				tStamp.mSampleTime += numFrames;
				
				require_noerr (result = ExtAudioFileWrite(outfile, numFrames, outputBuffer.ABL()), fail);	

				require_noerr (result = MusicPlayerGetTime (player, &currentTime), fail);
				if (shouldPrint && (++i % numTimesFor10Secs == 0))
					printf ("current time: %6.2f beats\n", currentTime);
			} while (currentTime < sequenceLength);
		}
	}
	
// close
	ExtAudioFileDispose(outfile);

	return;

fail:
	printf ("Problem: %ld\n", result); 
	exit(1);
}


