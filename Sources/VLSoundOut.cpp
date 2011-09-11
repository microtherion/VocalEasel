//
// File: VLSoundOut.cpp - Sound output and file playing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#include "VLSoundOut.h"
#include "VLMIDIWriter.h"

#include <AudioUnit/AudioUnit.h>

#include "CAAudioFileFormats.h"
#include "AUOutputBL.h"

#include <memory>
#include <vector>
#include <dispatch/dispatch.h>

#define R(x) if (OSStatus r = (x)) fprintf(stderr, "%s -> %d\n", #x, r);

CFStringRef  kVLSoundStartedNotification    =   CFSTR("VLSoundStarted");
CFStringRef  kVLSoundStoppedNotification    =   CFSTR("VLSoundStopped");

class VLAUSoundOut : public VLSoundOut {
public:
	VLAUSoundOut();

	virtual void 	PlayNote(const VLNote & note);
	virtual void 	PlayChord(const VLChord & chord); 
	virtual void   	PlaySequence(MusicSequence music);
    virtual void    SetStart(MusicTimeStamp start);
    virtual void    SetEnd(MusicTimeStamp end);
	virtual void	Stop(bool pause);
	virtual bool	Playing();
	virtual bool	AtEnd();
	virtual bool	AtBeginning();
	virtual void 	SetPlayRate(float rate);
	virtual void 	Fwd();
	virtual void 	Bck();
    virtual void    Slow(float rate);
	virtual void    SetMelodyState(MelodyState state);
    
	virtual 	   ~VLAUSoundOut();
    void            PollMusic();
protected:
	VLAUSoundOut(bool fileOutput);

	void			InitSoundOutput(bool fileOutput);
	virtual void 	SetupOutput(AUNode outputNode);
    void            SkipTimeInterval();

	AUGraph             fGraph;
	MusicPlayer         fPlayer;
private:
	MusicSequence       fMusic;
	MusicTimeStamp      fMusicEnd;
	bool                fRunning;
	bool                fForward;
    bool                fWasAtEnd;
    float               fPlayRate;
    dispatch_source_t   fMusicPoll;

	void                Play(const int8_t * note, size_t numNotes = 1);
};

class VLAUFileSoundOut : public VLAUSoundOut {
public:
	VLAUFileSoundOut(CFURLRef file, OSType dataFormat);
	~VLAUFileSoundOut();
protected:
	virtual void 	SetupOutput(AUNode outputNode);
	virtual void   	PlaySequence(MusicSequence music);
    virtual void    SetMelodyState(MelodyState state) {}
private:
	AudioUnit		fOutput;
	CFURLRef		fFile;
	OSType			fDataFormat;
};

class VLResetTimer {
public:
    VLResetTimer(int64_t interval, void (^block)());
    ~VLResetTimer();
    
    void    Prime();
private:
    dispatch_source_t   fTimer;
    int64_t             fInterval;
    void              (^fBlock)();
};

VLResetTimer::VLResetTimer(int64_t interval, void (^block)())
    : fInterval(interval), fBlock(Block_copy(block))
{
    fTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, 
                dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_event_handler(fTimer, fBlock);
    dispatch_source_set_timer(fTimer, DISPATCH_TIME_FOREVER, INT64_MAX, 1000*NSEC_PER_USEC);
    dispatch_resume(fTimer);
}

VLResetTimer::~VLResetTimer()
{
    Block_release(fBlock);
}

void VLResetTimer::Prime()
{
    dispatch_source_set_timer(fTimer, dispatch_time(DISPATCH_TIME_NOW, fInterval), 
                              INT64_MAX, 10*NSEC_PER_MSEC);
}

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
	MusicSequenceFileLoadData(music, file, 0, 0);
	PlaySequence(music);
}

VLSoundOut::~VLSoundOut()
{
}

VLAUSoundOut::VLAUSoundOut()
	: fMusic(0), fRunning(false), fForward(true), fWasAtEnd(true)
{
	InitSoundOutput(false);
    fMusicPoll = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(fMusicPoll, ^{
        this->PollMusic();
    });
    dispatch_source_set_timer(fMusicPoll, DISPATCH_TIME_FOREVER, INT64_MAX, 1000*NSEC_PER_USEC);
    dispatch_resume(fMusicPoll);
}

VLAUSoundOut::VLAUSoundOut(bool)
	: fRunning(false), fMusic(0)
{
}

VLAUSoundOut::~VLAUSoundOut()
{
	Stop(false);
    dispatch_release(fMusicPoll);
	DisposeMusicPlayer(fPlayer);
	DisposeAUGraph(fGraph);
}

void VLAUSoundOut::InitSoundOutput(bool fileOutput)
{
	AUNode synthNode, limiterNode, outNode;
   	AudioComponentDescription cd;

	cd.componentManufacturer = kAudioUnitManufacturer_Apple;
	cd.componentFlags = 0;
	cd.componentFlagsMask = 0;

	NewAUGraph(&fGraph);

	cd.componentType = kAudioUnitType_MusicDevice;
	cd.componentSubType = kAudioUnitSubType_DLSSynth;

	AUGraphAddNode(fGraph, &cd, &synthNode);

	cd.componentType = kAudioUnitType_Effect;
	cd.componentSubType = kAudioUnitSubType_PeakLimiter;  

	AUGraphAddNode (fGraph, &cd, &limiterNode);

	cd.componentType = kAudioUnitType_Output;
	if (fileOutput)
		cd.componentSubType	= kAudioUnitSubType_GenericOutput;
	else
		cd.componentSubType = kAudioUnitSubType_DefaultOutput;  

	AUGraphAddNode(fGraph, &cd, &outNode);

	R(AUGraphOpen(fGraph));
	AUGraphConnectNodeInput(fGraph, synthNode, 0, limiterNode, 0);
	AUGraphConnectNodeInput(fGraph, limiterNode, 0, outNode, 0);

	if (fileOutput) {
		UInt32 		value = 1;
		AudioUnit	synth;
		R(AUGraphNodeInfo(fGraph, synthNode, NULL, &synth));
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
		fMusicEnd       = VLMIDIUtilities(music).Length();
        fPlayRate       = 1.0;
        fWasAtEnd       = true;

		R(MusicSequenceSetAUGraph(fMusic, fGraph));
		R(MusicPlayerSetSequence(fPlayer, fMusic));
	}
	R(MusicPlayerStart(fPlayer));

	fRunning	= true;
    CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), kVLSoundStartedNotification, 
                                         NULL, NULL, false);
    dispatch_source_set_timer(fMusicPoll, DISPATCH_TIME_NOW, 10*NSEC_PER_MSEC, 200*NSEC_PER_MSEC);
}

void VLAUSoundOut::SetStart(MusicTimeStamp start)
{
    if (fWasAtEnd)
        MusicPlayerSetTime(fPlayer, start);
}

void VLAUSoundOut::SetEnd(MusicTimeStamp end)
{
    if (fWasAtEnd)
        fMusicEnd = end;
}

void VLAUSoundOut::SetMelodyState(VLSoundOut::MelodyState state)
{
    if (fMusic) {
        UInt32      numTracks;
        MusicTrack  curTrack;
        MusicSequenceGetTrackCount(fMusic, &numTracks);
        MusicSequenceGetIndTrack(fMusic, numTracks-2, &curTrack);
            
        Boolean mute = state==kMelodyMute;
        Boolean solo = state==kMelodySolo;
        
        MusicTrackSetProperty(curTrack, kSequenceTrackProperty_MuteStatus, &mute, sizeof(mute));
        MusicTrackSetProperty(curTrack, kSequenceTrackProperty_SoloStatus, &solo, sizeof(solo));
    }
}
void VLAUSoundOut::SetPlayRate(float rate)
{
	if ((rate < 0) != fForward) {
		fForward = !fForward;
		
		MusicTimeStamp rightNow;
		MusicPlayerGetTime(fPlayer, &rightNow);
		MusicSequenceReverse(fMusic);
		MusicPlayerSetTime(fPlayer, fMusicEnd - rightNow);
	}
    fPlayRate   = fabsf(rate);
	MusicPlayerSetPlayRateScalar(fPlayer, fPlayRate);
}

const MusicTimeStamp    kInitialSkip= 0.15;
const MusicTimeStamp    kMaxSkip    = 1.0;
const MusicTimeStamp    kSkipFactor = 0.5;
static MusicTimeStamp   sSkipSign   = 0;
static int              sSkipSteps  = 0;
static VLResetTimer *   sSkipResetTimer;

void VLAUSoundOut::SkipTimeInterval()
{
    MusicTimeStamp  time;
    MusicPlayerGetTime(fPlayer, &time);
    ++sSkipSteps;
    MusicTimeStamp  delta   = kInitialSkip+(kMaxSkip-kInitialSkip)
        *sSkipSign*(1.0-exp(-sSkipSteps*kSkipFactor));
    time     += delta;
    if (!sSkipResetTimer) 
        sSkipResetTimer = new VLResetTimer(500*NSEC_PER_MSEC, ^{
            sSkipSteps  = 0;
        });
    sSkipResetTimer->Prime();
    MusicPlayerSetTime(fPlayer, time);
}

void VLAUSoundOut::Fwd()
{
    if (sSkipSign <= 0.0) {
        sSkipSign   = 1.0;
        sSkipSteps  = 0;
    }
    SkipTimeInterval();
}

void VLAUSoundOut::Bck()
{
    if (sSkipSign >= 0.0) {
        sSkipSign  = -1.0;
        sSkipSteps = 0;
    }
    SkipTimeInterval();
}

static VLResetTimer *   sSlowResetTimer;

void VLAUSoundOut::Slow(float rate)
{
    if (!sSlowResetTimer) 
        sSlowResetTimer = new VLResetTimer(500*NSEC_PER_MSEC, ^{
            MusicPlayerSetPlayRateScalar(fPlayer, fPlayRate);
        });
    sSlowResetTimer->Prime();
    MusicPlayerSetPlayRateScalar(fPlayer, fPlayRate*rate);
}

void VLAUSoundOut::Stop(bool pause)
{
    if (!fRunning)
        return;
    
	MusicPlayerStop(fPlayer);
	fRunning	= false;
    fWasAtEnd   = false;
	if (!pause && fMusic) {
		MusicPlayerSetSequence(fPlayer, NULL);
		DisposeMusicSequence(fMusic);
		fMusic = 0;
	}
    CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), kVLSoundStoppedNotification, 
                                         NULL, NULL, false);
    dispatch_source_set_timer(fMusicPoll, DISPATCH_TIME_FOREVER, INT64_MAX, 200*NSEC_PER_MSEC);
}

bool VLAUSoundOut::Playing()
{
	return fRunning;
}

bool VLAUSoundOut::AtEnd()
{
	MusicTimeStamp time;

	return !MusicPlayerGetTime(fPlayer, &time) && time >= fMusicEnd;
}

bool VLAUSoundOut::AtBeginning()
{
	MusicTimeStamp time;
    
	return MusicPlayerGetTime(fPlayer, &time) || !time;
}

void VLAUSoundOut::PollMusic()
{
    if (fRunning && AtEnd()) {
        MusicPlayerSetTime(fPlayer, 0); 
        Stop(true);
        fWasAtEnd   = true;
    }
}

void VLAUSoundOut::PlayNote(const VLNote & note)
{
	Play(&note.fPitch);
}

void VLAUSoundOut::PlayChord(const VLChord & chord)
{
    //
    // TODO: The voicings here are not very realistic
    //
	std::vector<int8_t>	notes;

	for (int i = 0; i < 32; ++i)
		if (chord.fSteps & (1 << i))
			notes.push_back(chord.fPitch+i%12);
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
	R(AUGraphNodeInfo(fGraph, outputNode, NULL, &fOutput));
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
	MusicTimeStamp	musicLen	= VLMIDIUtilities(music).Length()+8;
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
	CFRelease(name);

	ExtAudioFileRef outfile;
    R(ExtAudioFileCreateWithURL(fFile, fileType, &outputFormat, NULL, 
                                kAudioFileFlags_EraseFile, &outfile));

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


