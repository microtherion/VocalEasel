//
// File: VLSoundOut.cpp - Sound output and file playing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
//

#include "VLSoundOut.h"

#include <AudioUnit/AudioUnit.h>

#include "CAAudioFileFormats.h"
#include "AUOutputBL.h"

#include <memory>
#include <vector>

#define R(x) if (OSStatus r = (x)) fprintf(stderr, "%s -> %ld\n", #x, r);

class VLAUSoundOut : public VLSoundOut {
public:
	VLAUSoundOut();

	virtual void 	PlayNote(const VLNote & note);
	virtual void 	PlayChord(const VLChord & chord); 
	virtual void   	PlaySequence(MusicSequence music);
	virtual void	Stop(bool pause);
	virtual bool	Playing();
	virtual void 	SetPlayRate(float rate);
	virtual void 	SetTime(MusicTimeStamp time);
	
	virtual 	   ~VLAUSoundOut();
protected:
	VLAUSoundOut(bool fileOutput);

	void			InitSoundOutput(bool fileOutput);
	virtual void 	SetupOutput(AUNode outputNode);
	MusicTimeStamp	SequenceLength(MusicSequence music);

	AUGraph			fGraph;
	MusicPlayer		fPlayer;
private:
	MusicSequence	fMusic;
	MusicTimeStamp	fMusicLength;
	bool			fRunning;
	bool			fForward;

	void 			Play(const int8_t * note, size_t numNotes = 1);
};

class VLAUFileSoundOut : public VLAUSoundOut {
public:
	VLAUFileSoundOut(CFURLRef file, OSType dataFormat);
	~VLAUFileSoundOut();
protected:
	virtual void 	SetupOutput(AUNode outputNode);
	virtual void   	PlaySequence(MusicSequence music);
private:
	AudioUnit		fOutput;
	CFURLRef		fFile;
	OSType			fDataFormat;
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

VLSoundOut * VLSoundOut::FileWriter(CFURLRef file, OSType dataFormat)
{
	return new VLAUFileSoundOut(file, dataFormat);
}

void VLSoundOut::PlayFile(CFDataRef file)
{
	MusicSequence	music;
	
	NewMusicSequence(&music);
	MusicSequenceLoadSMFDataWithFlags(music, file,
									  kMusicSequenceLoadSMF_ChannelsToTracks);
	PlaySequence(music);
}

VLSoundOut::~VLSoundOut()
{
}

VLAUSoundOut::VLAUSoundOut()
	: fMusic(0), fRunning(false), fForward(true)
{
	InitSoundOutput(false);
}

VLAUSoundOut::VLAUSoundOut(bool)
	: fRunning(false), fMusic(0)
{
}

VLAUSoundOut::~VLAUSoundOut()
{
	DisposeMusicPlayer(fPlayer);
	Stop(false);
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

	R(AUGraphOpen(fGraph));
	AUGraphConnectNodeInput(fGraph, synthNode, 0, limiterNode, 0);
	AUGraphConnectNodeInput(fGraph, limiterNode, 0, outNode, 0);

	if (fileOutput) {
		UInt32 		value = 1;
		AudioUnit	synth;
		R(AUGraphGetNodeInfo(fGraph, synthNode, 0, 0, 0, &synth));
		R(AudioUnitSetProperty(synth,
							   kAudioUnitProperty_OfflineRender,
							   kAudioUnitScope_Global, 0,
							   &value, sizeof(value)));
		value = 512;
		R(AudioUnitSetProperty(synth,
							   kAudioUnitProperty_OfflineRender,
							   kAudioUnitScope_Global, 0,
							   &value, sizeof(value)));
	}
	SetupOutput(outNode);

	R(AUGraphInitialize(fGraph));
	
	NewMusicPlayer(&fPlayer);
}

void VLAUSoundOut::SetupOutput(AUNode)
{
}

void VLAUSoundOut::PlaySequence(MusicSequence music)
{
	if (music) {
		Stop(false);
	
		fMusic			= music;
		fMusicLength	= SequenceLength(music);

		R(MusicSequenceSetAUGraph(fMusic, fGraph));
		R(MusicPlayerSetSequence(fPlayer, fMusic));
	}
	R(MusicPlayerStart(fPlayer));

	fRunning	= true;
}

void VLAUSoundOut::SetPlayRate(float rate)
{
	if ((rate < 0) != fForward) {
		fForward = !fForward;
		
		MusicTimeStamp rightNow;
		MusicPlayerGetTime(fPlayer, &rightNow);
		MusicSequenceReverse(fMusic);
		MusicPlayerSetTime(fPlayer, fMusicLength - rightNow);
	}
	MusicPlayerSetPlayRateScalar(fPlayer, fabsf(rate));
}

void VLAUSoundOut::SetTime(MusicTimeStamp time)
{
	SetPlayRate(1.0f);
	MusicPlayerSetTime(fPlayer, time);
}

void VLAUSoundOut::Stop(bool pause)
{
	MusicPlayerStop(fPlayer);
	fRunning	= false;
	if (!pause && fMusic) {
		MusicPlayerSetSequence(fPlayer, NULL);
		DisposeMusicSequence(fMusic);
		fMusic = 0;
	}
}

bool VLAUSoundOut::Playing()
{
	return fRunning;
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

MusicTimeStamp VLAUSoundOut::SequenceLength(MusicSequence music)
{	
	UInt32 ntracks;
	MusicSequenceGetTrackCount(music, &ntracks);
	MusicTimeStamp sequenceLength = 0;
	for (UInt32 i = 0; i < ntracks; ++i) {
		MusicTrack track;
		MusicTimeStamp trackLength;
		UInt32 propsize = sizeof(MusicTimeStamp);
		MusicSequenceGetIndTrack(music, i, &track);
		MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength,
							  &trackLength, &propsize);
		sequenceLength = std::max(sequenceLength, trackLength);
	}
	return sequenceLength;
}

VLAUFileSoundOut::VLAUFileSoundOut(CFURLRef file, OSType dataFormat)
	: VLAUSoundOut(true), fFile(file), fDataFormat(dataFormat)
{
	InitSoundOutput(true);

	CFRetain(fFile);
}

VLAUFileSoundOut::~VLAUFileSoundOut()
{
	CFRelease(fFile);
}

void VLAUFileSoundOut::SetupOutput(AUNode outputNode)
{
	R(AUGraphGetNodeInfo(fGraph, outputNode, 0, 0, 0, &fOutput));
	Float64 sampleRate = 22050.0;
	R(AudioUnitSetProperty(fOutput,
						   kAudioUnitProperty_SampleRate,
						   kAudioUnitScope_Output, 0,
						   &sampleRate, sizeof(sampleRate)));
}	

void VLAUFileSoundOut::PlaySequence(MusicSequence music)
{
	SInt32 			urlErr;
	CFURLDestroyResource(fFile, &urlErr);

	UInt32 			size;
	UInt32			numFrames	= 512;
	MusicTimeStamp	musicLen	= SequenceLength(music)+8;
	CFStringRef		name		= 
		CFURLCopyLastPathComponent(fFile);
	CAAudioFileFormats * formats = CAAudioFileFormats::Instance();
	
	AudioFileTypeID fileType;
	formats->InferFileFormatFromFilename(name, fileType);

	CAStreamBasicDescription outputFormat;
	if (fDataFormat)
		outputFormat.mFormatID		= fDataFormat;
	else if (!formats->InferDataFormatFromFileFormat(fileType, outputFormat))
		switch (fileType) {
		case kAudioFileM4AType:
			outputFormat.mFormatID = kAudioFormatMPEG4AAC;
			break;
		default:
			outputFormat.mFormatID = kAudioFormatLinearPCM;
			break;
		}
	outputFormat.mChannelsPerFrame	= 2;
	outputFormat.mSampleRate		= 22050.0;
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
		R(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL,
								 &size, &outputFormat));
	}
	
	CFURLRef		dir			= 
		CFURLCreateCopyDeletingLastPathComponent(NULL, fFile);
	FSRef parentDir;
	CFURLGetFSRef(dir, &parentDir);
	CFRelease(dir);

	ExtAudioFileRef outfile;
	R(ExtAudioFileCreateNew(&parentDir, name, 
							fileType, &outputFormat, NULL, &outfile));
	CFRelease(name);

	CAStreamBasicDescription clientFormat;
	size = sizeof(clientFormat);
	R(AudioUnitGetProperty(fOutput, kAudioUnitProperty_StreamFormat,
						   kAudioUnitScope_Output, 0, &clientFormat, &size));
	clientFormat.Print(stderr);
	outputFormat.Print(stderr);
	R(ExtAudioFileSetProperty(outfile, kExtAudioFileProperty_ClientDataFormat, 
							  size, &clientFormat));

	VLAUSoundOut::PlaySequence(music);

	MusicTimeStamp currentTime;
	AUOutputBL outputBuffer (clientFormat, numFrames);
	AudioTimeStamp tStamp;
	memset (&tStamp, 0, sizeof(AudioTimeStamp));
	tStamp.mFlags = kAudioTimeStampSampleTimeValid;
	do {
		outputBuffer.Prepare();
		AudioUnitRenderActionFlags actionFlags = 0;
		R(AudioUnitRender(fOutput, &actionFlags, &tStamp, 0, numFrames, 
						  outputBuffer.ABL()));

		tStamp.mSampleTime += numFrames;
				
		R(ExtAudioFileWrite(outfile, numFrames, outputBuffer.ABL()));

		MusicPlayerGetTime (fPlayer, &currentTime);
	} while (currentTime < musicLen);
	
	ExtAudioFileDispose(outfile);
}


